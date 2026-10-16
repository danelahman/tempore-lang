// The bindings of starter.tpe: ReadClock, the time since start-up in
// microseconds, modulo 2^32, which wraps after 71.6 minutes; and the safe
// state, which writes a line to the log.

#include <Arduino.h>
#include <esp_timer.h>

#include "tempore_bindings.h"

tempore_result_ReadClock binding_ReadClock(tempore_argument_ReadClock) {
  return static_cast<uint32_t>(esp_timer_get_time());
}

void starter_safe_state() { tempore_log("Sprint start system stopped"); }
