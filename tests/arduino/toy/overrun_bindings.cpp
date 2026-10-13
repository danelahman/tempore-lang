// The bindings of the toy device: each action logs its argument and takes
// its nominal duration; showing takes longer than its bounds and the period.

#include "tempore_bindings.h"

tempore_unit binding_Show(uint32_t n) {
  tempore_elapse_us(12000);
  tempore_log("Show %lu", static_cast<unsigned long>(n));
  return {};
}

tempore_unit binding_Blink(uint32_t n) {
  tempore_elapse_us(300);
  tempore_log("Blink %lu", static_cast<unsigned long>(n));
  return {};
}

void lights_off() { tempore_log("Lights off"); }
