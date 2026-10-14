// The bindings of steps.tpe: the safe state, which writes a line to the log.
// The program performs only operations of its packages.

#include <Arduino.h>

#include "tempore_bindings.h"

void steps_safe_state() { tempore_log("Step counter stopped"); }
