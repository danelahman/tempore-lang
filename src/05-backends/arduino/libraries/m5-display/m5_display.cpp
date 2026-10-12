// The package m5-display: lines of text and numbers on the display of an
// M5Stack core, through M5Unified.

#include <M5Unified.h>
#include <stdio.h>

#include "tempore_bindings.h"

void m5_display_init() {
  M5.Display.setTextSize(2);
  M5.Display.setCursor(0, 0);
}

#ifdef TEMPORE_PERFORMS_ShowText
tempore_result_ShowText binding_ShowText(tempore_argument_ShowText text) {
  M5.Display.println(text);
  return {};
}
#endif

#ifdef TEMPORE_PERFORMS_ShowNumber
tempore_result_ShowNumber binding_ShowNumber(tempore_argument_ShowNumber x) {
  char line[24];
  snprintf(line, sizeof line, "%.3f", static_cast<double>(x));
  M5.Display.println(line);
  return {};
}
#endif

#ifdef TEMPORE_PERFORMS_ClearDisplay
tempore_result_ClearDisplay binding_ClearDisplay(tempore_argument_ClearDisplay) {
  M5.Display.clear();
  M5.Display.setCursor(0, 0);
  return {};
}
#endif
