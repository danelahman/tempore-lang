// The bindings of the operations of names.tpe: each logs its name and its
// argument.

#include "tempore_bindings.h"

static tempore_unit show(const char *name, uint32_t n) {
  tempore_log("%s %lu", name, static_cast<unsigned long>(n));
  return {};
}

tempore_unit binding_Show_p_53686f7727_(uint32_t n) { return show("Show'", n); }
tempore_unit binding_Show_p(uint32_t n) { return show("Show_p", n); }
tempore_unit binding_A_b_415f5f62_(uint32_t n) { return show("A__b", n); }
tempore_unit binding_A_b(uint32_t n) { return show("A_b", n); }
tempore_unit binding_Count(uint32_t n) { return show("Count", n); }
tempore_unit binding_Count_monitor(uint32_t n) {
  return show("Count_monitor", n);
}
