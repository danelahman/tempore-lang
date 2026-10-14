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

int64_t tempore_clock_us() { return esp_timer_get_time(); }

void tempore_log(const char *format, ...) {
  char message[160];
  va_list arguments;
  va_start(arguments, format);
  vsnprintf(message, sizeof message, format, arguments);
  va_end(arguments);
  char line[192];
  const long long t = tempore_clock_us();
  snprintf(line, sizeof line, "[%lld.%03lld ms] %s", t / 1000, t % 1000,
           message);
  Serial.println(line);
}

void tempore_stop_task() {
  tempore_trace("Task %s stopped", pcTaskGetName(nullptr));
  for (;;) vTaskSuspend(nullptr);
}

bool tempore_halted() { return tempore_halt.load(); }

void tempore_check_halt() {
  if (tempore_halt.load()) tempore_stop_task();
}

// Logs reason and, unless the tasks are already halted, enters the safe state
// and then draws the banner of the lines first and second, if first is not
// nullptr and the board has a screen; halts the tasks.
[[noreturn]] static void tempore_halt_tasks(const char *reason,
                                            const char *first,
                                            const char *second) {
  tempore_log("%s", reason);
  if (!tempore_halt.exchange(true)) {
    tempore_log("Safe state");
    tempore_safe_state();
    if (first != nullptr && tempore_monitor_screen != nullptr) {
      tempore_display_lock();
      tempore_monitor_screen->stop(first, second);
      tempore_display_unlock();
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

// The delay of numerator / denominator time units, rounded to the nearest
// microsecond: the whole milliseconds by vTaskDelay, in waits of at most
// tempore_delay_chunk_ms, which yields the processor, and the remainder by
// delayMicroseconds, which waits actively. vTaskDelay(k) returns at the k-th
// tick from now, after at least k - 1 milliseconds, so that the remainder is
// under one millisecond per wait and one more. The numerator and the
// denominator of the time unit are below 2^30, so that the arithmetic in 64
// bits does not overflow.
void tempore_delay(uint32_t numerator, uint32_t denominator) {
  tempore_check_halt();
  const uint64_t d = static_cast<uint64_t>(denominator) *
                     tempore_unit_denominator_us;
  const uint64_t us =
      (2 * static_cast<uint64_t>(numerator) * tempore_unit_numerator_us + d) /
      (2 * d);
  tempore_trace("Delay %llu us", static_cast<unsigned long long>(us));
  const int64_t target = tempore_clock_us() + static_cast<int64_t>(us);
  for (uint64_t ms = us / 1000; ms > 0;) {
    const uint64_t wait =
        ms < tempore_delay_chunk_ms ? ms : tempore_delay_chunk_ms;
    vTaskDelay(pdMS_TO_TICKS(static_cast<uint32_t>(wait)));
    ms -= wait;
    tempore_check_halt();
  }
  const int64_t rest = target - tempore_clock_us();
  if (rest > 0) delayMicroseconds(static_cast<uint32_t>(rest));
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
    tempore_display_lock();
    tempore_monitor_screen->warnings(line);
    tempore_display_unlock();
  }
}

void tempore_monitor_display_begin(const tempore_monitor_display *display) {
  tempore_monitor_screen = display;
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
  Serial.println(line);
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
