// The bindings of the operations of steps.tpe: the steps counted, kept in a
// variable, each count and reset logged; the time since start-up; and the
// safe state, which writes a line to the log.

#include <Arduino.h>

#include "tempore_bindings.h"

static uint32_t steps_counted = 0;

tempore_result_CountStep binding_CountStep(tempore_argument_CountStep added) {
  steps_counted += static_cast<uint32_t>(added);
  tempore_log("Steps: %u counted, %u in all", static_cast<unsigned>(added),
              static_cast<unsigned>(steps_counted));
  return {};
}

tempore_result_ResetSteps binding_ResetSteps(tempore_argument_ResetSteps) {
  steps_counted = 0;
  tempore_log("Steps: reset");
  return {};
}

tempore_result_ReadClock binding_ReadClock(tempore_argument_ReadClock) {
  return millis();
}

void steps_safe_state() { tempore_log("Step counter stopped"); }
