// The bindings of the operations of calibrated.tpe: the tilt published by the
// step and read by the display, in an atomic variable, and the safe state,
// which writes a line to the log.

#include <Arduino.h>

#include <atomic>

#include "tempore_bindings.h"

static std::atomic<float> tilt_latest{0};

tempore_result_Publish binding_Publish(tempore_argument_Publish tilt) {
  tilt_latest.store(tilt);
  return {};
}

tempore_result_Latest binding_Latest(tempore_argument_Latest) {
  return tilt_latest.load();
}

void calibrated_safe_state() { tempore_log("Calibrated tilt display stopped"); }
