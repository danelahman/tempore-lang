// The bindings of the memory check: a report logs its number.

#include "tempore_bindings.h"

tempore_unit binding_Report(uint32_t n) {
  tempore_log("Report %lu", static_cast<unsigned long>(n));
  return {};
}

void memory_safe_state() { tempore_log("Memory check stopped"); }
