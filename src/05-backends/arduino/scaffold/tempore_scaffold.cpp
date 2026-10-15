// The scaffold of a device programmed in Tempore, over Arduino, FreeRTOS and
// the timer of the ESP32.

#include "tempore_scaffold.h"

#include <Arduino.h>
#include <esp_timer.h>
#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>
#include <freertos/task.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

#include <algorithm>
#include <atomic>

static_assert(configTICK_RATE_HZ == 1000,
              "the scaffold takes a tick of FreeRTOS to be a millisecond");

static std::atomic<bool> tempore_halt{false};

static SemaphoreHandle_t tempore_i2c_mutex = xSemaphoreCreateMutex();

void tempore_i2c_lock() { xSemaphoreTake(tempore_i2c_mutex, portMAX_DELAY); }

void tempore_i2c_unlock() { xSemaphoreGive(tempore_i2c_mutex); }

static SemaphoreHandle_t tempore_display_mutex = xSemaphoreCreateMutex();

void tempore_display_lock() {
  xSemaphoreTake(tempore_display_mutex, portMAX_DELAY);
}

void tempore_display_unlock() { xSemaphoreGive(tempore_display_mutex); }

// The display of the events of the monitor, if any.
static const tempore_monitor_display *tempore_monitor_screen = nullptr;

// The overlay of the display: its rectangle and the task to notify, if any.
static int32_t tempore_overlay_x = 0, tempore_overlay_y = 0;
static int32_t tempore_overlay_w = 0, tempore_overlay_h = 0;
static TaskHandle_t tempore_overlay_task = nullptr;

void tempore_display_overlay_begin(int32_t x, int32_t y, int32_t w, int32_t h,
                                   TaskHandle_t task) {
  tempore_overlay_x = x;
  tempore_overlay_y = y;
  tempore_overlay_w = w;
  tempore_overlay_h = h;
  tempore_overlay_task = task;
}

void tempore_display_drawn(int32_t x, int32_t y, int32_t w, int32_t h) {
  if (tempore_overlay_task != nullptr &&
      x < tempore_overlay_x + tempore_overlay_w && tempore_overlay_x < x + w &&
      y < tempore_overlay_y + tempore_overlay_h && tempore_overlay_y < y + h)
    xTaskNotifyGive(tempore_overlay_task);
}

int64_t tempore_clock_us() { return esp_timer_get_time(); }

#ifndef TEMPORE_LOG_LINES
#ifdef TEMPORE_HOST
#define TEMPORE_LOG_LINES 4096
#else
#define TEMPORE_LOG_LINES 32
#endif
#endif

#ifndef TEMPORE_SERIAL_TX_BUFFER
#define TEMPORE_SERIAL_TX_BUFFER 1024
#endif

// The length of a line of the log, with its terminating null character.
static const size_t tempore_log_line_size = 192;

// The lines of the log not yet written, a ring buffer of TEMPORE_LOG_LINES
// lines from the index tempore_log_first, and the number of lines dropped
// while it was full, updated in a critical section.
static portMUX_TYPE tempore_log_lock = portMUX_INITIALIZER_UNLOCKED;
static char tempore_log_lines[TEMPORE_LOG_LINES][tempore_log_line_size];
static size_t tempore_log_first = 0;
static size_t tempore_log_count = 0;
static uint32_t tempore_log_dropped = 0;

// The task that writes the log, and whether the lines are written at once,
// as before tempore_log_begin and after tempore_log_end.
static TaskHandle_t tempore_log_writer = nullptr;
static std::atomic<bool> tempore_log_direct{true};

// Removes the first line of the buffer into line; false if it is empty.
static bool tempore_log_take(char *line) {
  portENTER_CRITICAL(&tempore_log_lock);
  const bool taken = tempore_log_count > 0;
  if (taken) {
    memcpy(line, tempore_log_lines[tempore_log_first], tempore_log_line_size);
    tempore_log_first = (tempore_log_first + 1) % TEMPORE_LOG_LINES;
    --tempore_log_count;
  }
  portEXIT_CRITICAL(&tempore_log_lock);
  return taken;
}

// Writes the lines of the buffer to the serial port, and then the number of
// the lines dropped since the last report, if any.
static void tempore_log_drain() {
  char line[tempore_log_line_size];
  while (tempore_log_take(line)) Serial.println(line);
  portENTER_CRITICAL(&tempore_log_lock);
  const uint32_t dropped = tempore_log_dropped;
  tempore_log_dropped = 0;
  portEXIT_CRITICAL(&tempore_log_lock);
  if (dropped > 0) {
    const long long t = tempore_clock_us();
    snprintf(line, sizeof line, "[%lld.%03lld ms] Log: %lu lines dropped",
             t / 1000, t % 1000, static_cast<unsigned long>(dropped));
    Serial.println(line);
  }
}

// Adds line to the log: written at once before tempore_log_begin and after
// tempore_log_end, and else added to the buffer, and the writer notified. If
// the buffer is full, the line is dropped, or, if wait, added once a place is
// free.
static void tempore_log_line(const char *line, bool wait) {
  if (tempore_log_direct.load()) {
    Serial.println(line);
    return;
  }
  const size_t length = strnlen(line, tempore_log_line_size - 1);
  for (;;) {
    portENTER_CRITICAL(&tempore_log_lock);
    const bool added = tempore_log_count < TEMPORE_LOG_LINES;
    if (added) {
      char *slot = tempore_log_lines[(tempore_log_first + tempore_log_count) %
                                     TEMPORE_LOG_LINES];
      memcpy(slot, line, length);
      slot[length] = '\0';
      ++tempore_log_count;
    } else if (!wait)
      ++tempore_log_dropped;
    portEXIT_CRITICAL(&tempore_log_lock);
    if (added || !wait) break;
    vTaskDelay(1);
  }
  xTaskNotifyGive(tempore_log_writer);
}

// The task that writes the log, woken by each line added.
static void tempore_log_write(void *) {
  for (;;) {
    ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
    tempore_log_drain();
  }
}

void tempore_log_begin(unsigned long baud) {
  Serial.setTxBufferSize(TEMPORE_SERIAL_TX_BUFFER);
  Serial.begin(baud);
  xTaskCreatePinnedToCore(tempore_log_write, "tempore-log", 4096, nullptr,
                          tskIDLE_PRIORITY + 1, &tempore_log_writer,
                          tskNO_AFFINITY);
  tempore_log_direct.store(false);
}

void tempore_log_end() {
  tempore_log_direct.store(true);
  tempore_log_drain();
}

void tempore_log(const char *format, ...) {
  char message[160];
  va_list arguments;
  va_start(arguments, format);
  vsnprintf(message, sizeof message, format, arguments);
  va_end(arguments);
  char line[tempore_log_line_size];
  const long long t = tempore_clock_us();
  snprintf(line, sizeof line, "[%lld.%03lld ms] %s", t / 1000, t % 1000,
           message);
  tempore_log_line(line, false);
}

void tempore_stop_task() {
  tempore_trace("Task %s stopped", pcTaskGetName(nullptr));
  for (;;) vTaskSuspend(nullptr);
}

bool tempore_halted() { return tempore_halt.load(); }

void tempore_check_halt() {
  if (tempore_halt.load()) tempore_stop_task();
}

// Enters the safe state unless the tasks are already halted, logs reason,
// and, if it entered the safe state, logs it and draws the banner of the
// lines first and second, if first is not nullptr and the board has a screen;
// halts the tasks.
[[noreturn]] static void tempore_halt_tasks(const char *reason,
                                            const char *first,
                                            const char *second) {
  const bool halted = tempore_halt.exchange(true);
  if (!halted) tempore_safe_state();
  tempore_log("%s", reason);
  if (!halted) {
    tempore_log("Safe state entered");
    if (first != nullptr && tempore_monitor_screen != nullptr) {
      const tempore_display_guard guard;
      tempore_monitor_screen->stop(first, second);
    }
  }
  tempore_stop_task();
}

void tempore_abort(const char *reason) {
  tempore_halt_tasks(reason, nullptr, nullptr);
}

void tempore_fault(const char *message) {
  char reason[128];
  snprintf(reason, sizeof reason, "Run-time error: %s", message);
  tempore_abort(reason);
}

// The longest wait of one call of vTaskDelay, in milliseconds: one hour, so
// that pdMS_TO_TICKS, computed in 32 bits, does not overflow.
static const uint64_t tempore_delay_chunk_ms = 3600000;

void tempore_wait_until(int64_t start_us, int64_t target_us,
                        uint32_t early_ticks) {
  for (int64_t ms = (target_us - start_us) / 1000 - early_ticks; ms > 0;) {
    const int64_t wait = ms < static_cast<int64_t>(tempore_delay_chunk_ms)
                             ? ms
                             : static_cast<int64_t>(tempore_delay_chunk_ms);
    vTaskDelay(pdMS_TO_TICKS(static_cast<uint32_t>(wait)));
    ms -= wait;
    tempore_check_halt();
  }
  const int64_t rest = target_us - tempore_clock_us();
  if (rest > 0) delayMicroseconds(static_cast<uint32_t>(rest));
}

// The delay of numerator / denominator time units, rounded to the nearest
// microsecond, by tempore_wait_until. The numerator and the denominator of
// the time unit are below 2^30, so that the arithmetic in 64 bits does not
// overflow.
void tempore_delay(uint32_t numerator, uint32_t denominator) {
  tempore_check_halt();
  const uint64_t d = static_cast<uint64_t>(denominator) *
                     tempore_unit_denominator_us;
  const uint64_t us =
      (2 * static_cast<uint64_t>(numerator) * tempore_unit_numerator_us + d) /
      (2 * d);
  tempore_trace("Delay %llu us", static_cast<unsigned long long>(us));
  const int64_t start = tempore_clock_us();
  tempore_wait_until(start, start + static_cast<int64_t>(us), 0);
  tempore_check_halt();
}

// An end of an interval of microseconds, as text.
static void tempore_print_end(char *buffer, size_t size, int64_t value) {
  snprintf(buffer, size, "%lld", static_cast<long long>(value));
}

// A time of microseconds, not negative, as milliseconds with at most three
// decimals, without trailing zeros.
static void tempore_print_ms(char *buffer, size_t size, int64_t us) {
  const long long whole = us / 1000;
  long long fraction = us % 1000;
  if (fraction == 0) {
    snprintf(buffer, size, "%lld", whole);
    return;
  }
  int digits = 3;
  for (; fraction % 10 == 0; fraction /= 10) --digits;
  snprintf(buffer, size, "%lld.%0*lld", whole, digits, fraction);
}

#ifndef TEMPORE_MONITOR_DISPLAY_INTERVAL_MS
#define TEMPORE_MONITOR_DISPLAY_INTERVAL_MS 500
#endif

// The warnings of the monitor under the policy warn: their number and the
// last of them, updated in a critical section.
static portMUX_TYPE tempore_warning_lock = portMUX_INITIALIZER_UNLOCKED;
static uint32_t tempore_warning_count = 0;
static char tempore_last_warning[64] = "";

// Records the warning last, if the board has a screen.
static void tempore_record_warning(const char *last) {
  if (tempore_monitor_screen == nullptr) return;
  char copy[sizeof tempore_last_warning];
  snprintf(copy, sizeof copy, "%s", last);
  portENTER_CRITICAL(&tempore_warning_lock);
  ++tempore_warning_count;
  memcpy(tempore_last_warning, copy, sizeof copy);
  portEXIT_CRITICAL(&tempore_warning_lock);
}

// The task that draws the warnings, if any, every
// TEMPORE_MONITOR_DISPLAY_INTERVAL_MS milliseconds, so that the line is drawn
// again after the application clears the screen, until the tasks are halted.
static void tempore_warning_display(void *) {
  for (;;) {
    vTaskDelay(pdMS_TO_TICKS(TEMPORE_MONITOR_DISPLAY_INTERVAL_MS));
    tempore_check_halt();
    char last[sizeof tempore_last_warning];
    portENTER_CRITICAL(&tempore_warning_lock);
    const uint32_t count = tempore_warning_count;
    memcpy(last, tempore_last_warning, sizeof last);
    portEXIT_CRITICAL(&tempore_warning_lock);
    if (count == 0) continue;
    char line[128];
    snprintf(line, sizeof line, "Monitor: %lu warning%s, last %s",
             static_cast<unsigned long>(count), count == 1 ? "" : "s", last);
    const tempore_display_guard guard;
    tempore_monitor_screen->warnings(line);
  }
}

void tempore_monitor_display_begin(const tempore_monitor_display *display) {
  tempore_monitor_screen = display;
  display->begin();
  if (tempore_monitor == tempore_monitor_policy::warn)
    xTaskCreatePinnedToCore(tempore_warning_display, "tempore-monitor", 4096,
                            nullptr, tskIDLE_PRIORITY, nullptr,
                            tskNO_AFFINITY);
}

#ifdef TEMPORE_PROFILE
// The lock of the critical sections that update and read the statistics.
static portMUX_TYPE tempore_profile_lock = portMUX_INITIALIZER_UNLOCKED;

// Adds the time x to the statistics s.
static void tempore_add(tempore_statistics &s, int64_t x) {
  if (s.count == 0 || x < s.min) s.min = x;
  if (s.count == 0 || x > s.max) s.max = x;
  ++s.count;
  s.sum += x;
}
#endif

void tempore_monitor_operation(tempore_operation_monitor *operation,
                               int64_t elapsed_us) {
  const char *name = operation->name;
  const tempore_bounds *bounds = operation->bounds;
  tempore_trace("Operation %s took %lld us", name,
                static_cast<long long>(elapsed_us));
#ifdef TEMPORE_PROFILE
  portENTER_CRITICAL(&tempore_profile_lock);
  tempore_add(operation->running_time, elapsed_us);
  portEXIT_CRITICAL(&tempore_profile_lock);
#endif
  if (bounds == nullptr || tempore_monitor == tempore_monitor_policy::off)
    return;
  const bool below = bounds->lower_open ? elapsed_us <= bounds->lower
                                        : elapsed_us < bounds->lower;
  const bool above = bounds->upper_finite &&
                     (bounds->upper_open ? elapsed_us >= bounds->upper
                                         : elapsed_us > bounds->upper);
  if (!below && !above) return;
  char lower[24], upper[24];
  tempore_print_end(lower, sizeof lower, bounds->lower);
  if (bounds->upper_finite)
    tempore_print_end(upper, sizeof upper, bounds->upper);
  else
    snprintf(upper, sizeof upper, "\xe2\x88\x9e");
  char reason[160];
  snprintf(reason, sizeof reason,
           "Monitor: operation %s took %lld us, outside its running-time "
           "bounds %s%s, %s%s us",
           name, static_cast<long long>(elapsed_us),
           bounds->lower_open ? "(" : "[", lower, upper,
           bounds->upper_finite && !bounds->upper_open ? "]" : ")");
  char took[24], first[64], second[64];
  tempore_print_ms(took, sizeof took, elapsed_us);
  if (tempore_monitor == tempore_monitor_policy::abort) {
    char lower_ms[24], upper_ms[24];
    tempore_print_ms(lower_ms, sizeof lower_ms, bounds->lower);
    snprintf(first, sizeof first, "%s took %s ms", name, took);
    if (bounds->upper_finite) {
      tempore_print_ms(upper_ms, sizeof upper_ms, bounds->upper);
      snprintf(second, sizeof second, "bounds %s-%s ms", lower_ms, upper_ms);
    } else
      snprintf(second, sizeof second, "lower bound %s ms", lower_ms);
    tempore_halt_tasks(reason, first, second);
  }
  tempore_log("%s", reason);
  snprintf(first, sizeof first, "%s %s ms", name, took);
  tempore_record_warning(first);
}

void tempore_monitor_period(tempore_task_monitor *task, int64_t start_us,
                            int64_t end_us) {
  const int64_t elapsed_us = end_us - start_us;
#ifdef TEMPORE_PROFILE
  portENTER_CRITICAL(&tempore_profile_lock);
  if (task->step.count > 0)
    tempore_add(task->interval, start_us - task->last_start);
  task->last_start = start_us;
  tempore_add(task->step, elapsed_us);
  if (elapsed_us >= task->period_us) ++task->overruns;
  portEXIT_CRITICAL(&tempore_profile_lock);
#endif
  if (tempore_monitor == tempore_monitor_policy::off ||
      elapsed_us < task->period_us)
    return;
  char reason[160];
  snprintf(reason, sizeof reason,
           "Monitor: a step of the task %s took %lld us, not below its "
           "period %lld us",
           task->name, static_cast<long long>(elapsed_us),
           static_cast<long long>(task->period_us));
  char took[24], first[64], second[64];
  tempore_print_ms(took, sizeof took, elapsed_us);
  if (tempore_monitor == tempore_monitor_policy::abort) {
    char period_ms[24];
    tempore_print_ms(period_ms, sizeof period_ms, task->period_us);
    snprintf(first, sizeof first, "%s step took %s ms", task->name, took);
    snprintf(second, sizeof second, "period %s ms", period_ms);
    tempore_halt_tasks(reason, first, second);
  }
  tempore_log("%s", reason);
  snprintf(first, sizeof first, "%s step %s ms", task->name, took);
  tempore_record_warning(first);
}

void tempore_wait_release(TickType_t *release, TickType_t period) {
  const TickType_t now = xTaskGetTickCount();
  if (static_cast<TickType_t>(now - *release) > period) *release = now;
  vTaskDelayUntil(release, period);
}

#ifdef TEMPORE_PROFILE

#ifndef TEMPORE_PROFILE_INTERVAL_MS
#define TEMPORE_PROFILE_INTERVAL_MS 5000
#endif

// Writes a row of the profile to the log, indented by two spaces.
static void tempore_profile_row(const char *format, ...)
    __attribute__((format(printf, 1, 2)));

static void tempore_profile_row(const char *format, ...) {
  char row[160];
  va_list arguments;
  va_start(arguments, format);
  vsnprintf(row, sizeof row, format, arguments);
  va_end(arguments);
  char line[164];
  snprintf(line, sizeof line, "  %s", row);
  tempore_log_line(line, true);
}

// The least, mean and greatest time of s as text, in columns, or dashes if s
// is empty.
static void tempore_print_statistics(char *buffer, size_t size,
                                     const tempore_statistics &s) {
  if (s.count == 0)
    snprintf(buffer, size, "%9s %10s %9s", "-", "-", "-");
  else
    snprintf(buffer, size, "%9lld %10.1f %9lld", static_cast<long long>(s.min),
             static_cast<double>(s.sum) / s.count,
             static_cast<long long>(s.max));
}

void tempore_profile_report() {
  int width = 9;
  for (tempore_operation_monitor *const *o = tempore_operation_monitors;
       *o != nullptr; ++o)
    width = std::max(width, static_cast<int>(strlen((*o)->name)));
  for (tempore_task_monitor *const *t = tempore_task_monitors; *t != nullptr;
       ++t)
    width = std::max(width, static_cast<int>(strlen((*t)->name)));
  tempore_log("Profile since start-up, times in microseconds");
  char columns[48];
  if (tempore_operation_monitors[0] != nullptr) {
    tempore_profile_row("%-*s %8s %9s %10s %9s", width, "operation", "calls",
                        "min", "mean", "max");
    for (tempore_operation_monitor *const *o = tempore_operation_monitors;
         *o != nullptr; ++o) {
      portENTER_CRITICAL(&tempore_profile_lock);
      const tempore_statistics s = (*o)->running_time;
      portEXIT_CRITICAL(&tempore_profile_lock);
      tempore_print_statistics(columns, sizeof columns, s);
      tempore_profile_row("%-*s %8lu %s", width, (*o)->name,
                          static_cast<unsigned long>(s.count), columns);
    }
  }
  if (tempore_task_monitors[0] != nullptr) {
    tempore_profile_row("%-*s %8s %9s %10s %9s %9s %13s %13s %9s", width,
                        "task", "steps", "min", "mean", "max", "period",
                        "min interval", "max interval", "overruns");
    for (tempore_task_monitor *const *t = tempore_task_monitors;
         *t != nullptr; ++t) {
      portENTER_CRITICAL(&tempore_profile_lock);
      const tempore_statistics s = (*t)->step, i = (*t)->interval;
      const uint32_t overruns = (*t)->overruns;
      portEXIT_CRITICAL(&tempore_profile_lock);
      tempore_print_statistics(columns, sizeof columns, s);
      char interval[32];
      if (i.count == 0)
        snprintf(interval, sizeof interval, "%13s %13s", "-", "-");
      else
        snprintf(interval, sizeof interval, "%13lld %13lld",
                 static_cast<long long>(i.min), static_cast<long long>(i.max));
      tempore_profile_row("%-*s %8lu %s %9lld %s %9lu", width, (*t)->name,
                          static_cast<unsigned long>(s.count), columns,
                          static_cast<long long>((*t)->period_us), interval,
                          static_cast<unsigned long>(overruns));
    }
  }
  tempore_log("End of the profile");
}

// The task that logs the profile periodically.
static void tempore_profile_reporter(void *) {
  TickType_t release = xTaskGetTickCount();
  for (;;) {
    vTaskDelayUntil(&release, pdMS_TO_TICKS(TEMPORE_PROFILE_INTERVAL_MS));
    tempore_profile_report();
  }
}

void tempore_profile_begin() {
  xTaskCreatePinnedToCore(tempore_profile_reporter, "tempore-profile", 4096,
                          nullptr, tskIDLE_PRIORITY, nullptr, tskNO_AFFINITY);
}

#else

void tempore_profile_begin() {}

void tempore_profile_report() {}

#endif

void tempore_elapse_us(uint32_t us) {
#ifdef TEMPORE_HOST
  delayMicroseconds(us);
#else
  (void)us;
#endif
}
