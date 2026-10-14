// The scaffold of a device programmed in Tempore: the clock, the log, the
// monitors of the running times of operations and of the periods of tasks, the
// profile of these, and the halt of the tasks. The generated main.cpp defines
// the configuration.

#ifndef TEMPORE_SCAFFOLD_H
#define TEMPORE_SCAFFOLD_H

#include <freertos/FreeRTOS.h>
#include <stdint.h>

#include "tempore_arduino.h"

// What a monitor does when a running time is outside its bounds.
enum class tempore_monitor_policy : uint8_t {
  abort,  // the safe state is entered and the tasks halt
  warn,   // the violation is logged
  off     // nothing is checked
};

// The configuration, defined by main.cpp: the monitor policy, and the length
// of one time unit of the program, numerator / denominator microseconds.
extern const tempore_monitor_policy tempore_monitor;
extern const uint64_t tempore_unit_numerator_us;
extern const uint64_t tempore_unit_denominator_us;

// Enters the safe state of the application, defined by main.cpp.
void tempore_safe_state();

// The time since start-up, in microseconds.
int64_t tempore_clock_us();

// Writes a line to the log, preceded by the time in milliseconds, the message
// truncated to 159 characters. From tempore_log_begin on, the line is added to a buffer of
// TEMPORE_LOG_LINES lines (32 on the device, 4096 on the host) without
// waiting, and a task of priority 1 writes the buffer to the serial port; a
// line logged while the buffer is full is dropped, and the number of the
// lines dropped is logged once the buffer is written.
void tempore_log(const char *format, ...)
    __attribute__((format(printf, 1, 2)));

// Sets the transmit buffer of the serial port to TEMPORE_SERIAL_TX_BUFFER
// bytes (default 1024), starts the port at baud and creates the task that
// writes the log, called by setup() first.
void tempore_log_begin(unsigned long baud);

// Writes the lines of the buffer, and the later lines at once, called by the
// host simulation at its end.
void tempore_log_end();

// The events of the tasks are logged when TEMPORE_TRACE is defined.
#ifdef TEMPORE_TRACE
#define tempore_trace(...) tempore_log(__VA_ARGS__)
#else
#define tempore_trace(...) ((void)0)
#endif

// The bounds of the running time of an operation, in microseconds, each end
// closed or open; the upper end may be infinite.
struct tempore_bounds {
  int64_t lower;
  bool lower_open;
  int64_t upper;
  bool upper_open;
  bool upper_finite;
};

// The statistics of a sequence of times in microseconds: their number, least,
// greatest and sum.
struct tempore_statistics {
  uint32_t count = 0;
  int64_t min = 0;
  int64_t max = 0;
  int64_t sum = 0;
};

// An operation: its name and the bounds of its running time, if any, and the
// statistics of its running times, collected when TEMPORE_PROFILE is defined.
struct tempore_operation_monitor {
  constexpr tempore_operation_monitor(const char *name,
                                      const tempore_bounds *bounds)
      : name(name), bounds(bounds) {}
  const char *name;
  const tempore_bounds *bounds;
  tempore_statistics running_time;
};

// A periodic task: its name and period, and, collected when TEMPORE_PROFILE is
// defined, the statistics of the running times of its steps and of the
// intervals between the starts of consecutive steps, the number of its
// overruns and the start of its last step.
struct tempore_task_monitor {
  constexpr tempore_task_monitor(const char *name, int64_t period_us)
      : name(name), period_us(period_us) {}
  const char *name;
  int64_t period_us;
  tempore_statistics step;
  tempore_statistics interval;
  uint32_t overruns = 0;
  int64_t last_start = 0;
};

// The operations and the periodic tasks of the device, each array ended by
// nullptr, defined by tempore_operations.cpp and by main.cpp.
extern tempore_operation_monitor *const tempore_operation_monitors[];
extern tempore_task_monitor *const tempore_task_monitors[];

// Whether the tasks are halted.
bool tempore_halted();

// Stops the calling task if the tasks are halted.
void tempore_check_halt();

// Stops the calling task.
[[noreturn]] void tempore_stop_task();

// Enters the safe state unless the tasks are already halted, then logs
// reason, and halts the tasks: the calling task stops at once, the others at
// their next release, delay or operation call.
[[noreturn]] void tempore_abort(const char *reason);

// Checks the running time of a call of the operation against its bounds, if
// any, under the monitor policy, and adds it to the profile.
void tempore_monitor_operation(tempore_operation_monitor *operation,
                               int64_t elapsed_us);

// Checks the running time of a step of the periodic task, from start_us to
// end_us, against its period under the monitor policy, and adds it to the
// profile: an overrun is a step that takes the period or longer.
void tempore_monitor_period(tempore_task_monitor *task, int64_t start_us,
                            int64_t end_us);

// Blocks the calling periodic task until its next release, period ticks after
// the release *release, which becomes the new *release. If the tick of that
// release has passed, the task is resynchronised: the current tick becomes
// *release, and the next release follows a period after it, so that missed
// releases are not made up by steps that follow one another at once.
void tempore_wait_release(TickType_t *release, TickType_t period);

// The profile, when TEMPORE_PROFILE is defined: the statistics of the running
// times of the operations, and of the steps of the periodic tasks, the
// intervals between their starts and their overruns, since start-up. The
// statistics are updated in a critical section after the time of each call
// or step is read. tempore_profile_begin, called by setup(), creates a task of
// the lowest priority that logs the profile every TEMPORE_PROFILE_INTERVAL_MS
// milliseconds (default 5000): a line that starts with "Profile since
// start-up", a row per line, indented by two spaces, and the line "End of the
// profile"; otherwise it does nothing. tempore_profile_report logs the
// profile at once.
void tempore_profile_begin();
void tempore_profile_report();

// Excludes the other tasks from the I2C buses, from the start of a
// transaction to the last byte read of it, until tempore_i2c_unlock. The
// bindings that use an I2C bus enclose each transaction in these calls and do
// not end a task, by tempore_fault, between them.
void tempore_i2c_lock();
void tempore_i2c_unlock();

// Excludes the other tasks from the display, from the start of a drawing to
// its end, until tempore_display_unlock. The bindings that draw on the display
// enclose each drawing in these calls.
void tempore_display_lock();
void tempore_display_unlock();

// The display of the events of the monitor on the screen of the board: stop
// draws a banner that states that the monitor stopped the tasks, with the two
// lines first and second of the violation; warnings draws the line of the
// warnings. Each is called with the lock of the display held.
struct tempore_monitor_display {
  void (*stop)(const char *first, const char *second);
  void (*warnings)(const char *line);
};

// Shows the events of the monitor on display, called by setup() on a board
// with a screen before the tasks are created. Under the policy abort the
// banner of the violation is drawn once the safe state is entered; under the
// policy warn a task of the lowest priority draws the number of the warnings
// and the last of them, once there is one, every
// TEMPORE_MONITOR_DISPLAY_INTERVAL_MS milliseconds (default 500), the monitors
// only recording them.
void tempore_monitor_display_begin(const tempore_monitor_display *display);

// Declares the nominal duration of the action of a binding function. Under
// host simulation the simulated clock advances by it; on the device nothing
// happens, the action taking its own time.
void tempore_elapse_us(uint32_t us);

#endif
