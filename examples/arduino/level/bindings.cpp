// The bindings of level.tpe: the safe state, which writes a line to the log.
// The program performs only operations of its packages.

#include <Arduino.h>

#include "tempore_bindings.h"

void level_safe_state() { tempore_log("Digital level stopped"); }
