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

#include <atomic>

static std::atomic<bool> tempore_halt{false};

static SemaphoreHandle_t tempore_i2c_mutex = xSemaphoreCreateMutex();

void tempore_i2c_lock() { xSemaphoreTake(tempore_i2c_mutex, portMAX_DELAY); }

void tempore_i2c_unlock() { xSemaphoreGive(tempore_i2c_mutex); }

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

void tempore_check_halt() {
  if (tempore_halt.load()) tempore_stop_task();
}

void tempore_abort(const char *reason) {
  tempore_log("%s", reason);
  if (!tempore_halt.exchange(true)) {
    tempore_log("Safe state");
    tempore_safe_state();
  }
  tempore_stop_task();
}

void tempore_fault(const char *message) {
  char reason[128];
  snprintf(reason, sizeof reason, "Run-time error: %s", message);
  tempore_abort(reason);
}

// The delay of numerator / denominator time units, rounded to the nearest
// microsecond: the whole milliseconds by vTaskDelay, which yields the
// processor, and the remainder by delayMicroseconds, which waits actively.
// vTaskDelay(k) returns at the k-th tick from now, after at least k - 1
// milliseconds, so that the remainder is under two milliseconds.
void tempore_delay(uint32_t numerator, uint32_t denominator) {
  tempore_check_halt();
  const uint64_t d = static_cast<uint64_t>(denominator) *
                     tempore_unit_denominator_us;
  const uint64_t us =
      (2 * static_cast<uint64_t>(numerator) * tempore_unit_numerator_us + d) /
      (2 * d);
  tempore_trace("Delay %llu us", static_cast<unsigned long long>(us));
  const int64_t target = tempore_clock_us() + static_cast<int64_t>(us);
  if (us >= 1000) vTaskDelay(pdMS_TO_TICKS(us / 1000));
  const int64_t rest = target - tempore_clock_us();
  if (rest > 0) delayMicroseconds(static_cast<uint32_t>(rest));
  tempore_check_halt();
}

// An end of an interval of microseconds, as text.
static void tempore_print_end(char *buffer, size_t size, int64_t value) {
  snprintf(buffer, size, "%lld", static_cast<long long>(value));
}

void tempore_monitor_operation(const char *name, int64_t elapsed_us,
                               const tempore_bounds *bounds) {
  tempore_trace("Operation %s took %lld us", name,
                static_cast<long long>(elapsed_us));
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
  if (tempore_monitor == tempore_monitor_policy::abort)
    tempore_abort(reason);
  else
    tempore_log("%s", reason);
}

void tempore_monitor_period(const char *name, int64_t elapsed_us,
                            int64_t period_us) {
  if (tempore_monitor == tempore_monitor_policy::off ||
      elapsed_us < period_us)
    return;
  char reason[160];
  snprintf(reason, sizeof reason,
           "Monitor: a step of the task %s took %lld us, not below its "
           "period %lld us",
           name, static_cast<long long>(elapsed_us),
           static_cast<long long>(period_us));
  if (tempore_monitor == tempore_monitor_policy::abort)
    tempore_abort(reason);
  else
    tempore_log("%s", reason);
}

void tempore_elapse_us(uint32_t us) {
#ifdef TEMPORE_HOST
  delayMicroseconds(us);
#else
  (void)us;
#endif
}
