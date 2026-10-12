// The scaffold of a device programmed in Tempore: the clock, the log, the
// monitors of the running times of operations and of the periods of tasks, and
// the halt of the tasks. The generated main.cpp defines the configuration.

#ifndef TEMPORE_SCAFFOLD_H
#define TEMPORE_SCAFFOLD_H

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

// Writes a line to the log, preceded by the time in milliseconds.
void tempore_log(const char *format, ...)
    __attribute__((format(printf, 1, 2)));

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

// Stops the calling task if the tasks are halted.
void tempore_check_halt();

// Stops the calling task.
[[noreturn]] void tempore_stop_task();

// Logs reason, enters the safe state unless the tasks are already halted, and
// halts the tasks: the calling task stops at once, the others at their next
// release, delay or operation call.
[[noreturn]] void tempore_abort(const char *reason);

// Checks the running time of a call of the operation name against its bounds,
// if any, under the monitor policy.
void tempore_monitor_operation(const char *name, int64_t elapsed_us,
                               const tempore_bounds *bounds);

// Checks the running time of a step of the periodic task name against its
// period under the monitor policy: an overrun is a step that takes the period
// or longer.
void tempore_monitor_period(const char *name, int64_t elapsed_us,
                            int64_t period_us);

// Declares the nominal duration of the action of a binding function. Under
// host simulation the simulated clock advances by it; on the device nothing
// happens, the action taking its own time.
void tempore_elapse_us(uint32_t us);

#endif
