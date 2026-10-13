// The bindings of the operations of wheels.tpe: the tilt published by the
// step and read by the check, in an atomic variable, and the safe state,
// which writes a line to the log.

#include <Arduino.h>

#include <atomic>

#include "tempore_bindings.h"

static std::atomic<float> wheels_tilt{0};

tempore_result_Publish binding_Publish(tempore_argument_Publish tilt) {
  wheels_tilt.store(tilt);
  return {};
}

tempore_result_Latest binding_Latest(tempore_argument_Latest) {
  return wheels_tilt.load();
}

void wheels_safe_state() { tempore_log("Wheel check stopped"); }
