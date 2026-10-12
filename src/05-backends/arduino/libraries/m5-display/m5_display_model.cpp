// The host model of the display of an M5Stack core: its lines are written to
// the log. Clearing takes 31 milliseconds, the transfer of 320 by 240 pixels
// of 16 bits at 40 MHz, and a line 1 millisecond.

#include <Arduino.h>
#include <M5Unified.h>

#include "tempore_scaffold.h"

void tempore_m5_display::setTextSize(float) {}

void tempore_m5_display::setCursor(int32_t, int32_t) {}

void tempore_m5_display::clear() {
  delayMicroseconds(31000);
  tempore_log("Display cleared");
}

size_t tempore_m5_display::println(const char *text) {
  delayMicroseconds(1000);
  tempore_log("Display: %s", text);
  return strlen(text) + 1;
}
