// The host model of the display of an M5Stack core: its lines are written to
// the log, those written at a position with the position. Clearing takes 31
// milliseconds, the transfer of 320 by 240 pixels of 16 bits at 40 MHz, a
// line 1 millisecond, and the filling of a band, which is not logged, the
// transfer of its pixels.

#include <Arduino.h>
#include <M5Unified.h>

#include "tempore_scaffold.h"

void tempore_m5_display::setTextSize(float) {}

void tempore_m5_display::setCursor(int32_t x, int32_t y) {
  cursor_x = x;
  cursor_y = y;
}

void tempore_m5_display::setTextColor(uint32_t, uint32_t) {}

void tempore_m5_display::fillRect(int32_t, int32_t, int32_t w, int32_t h,
                                  uint32_t) {
  delayMicroseconds(static_cast<uint32_t>(w * h * 16 / 40));
}

void tempore_m5_display::clear() {
  delayMicroseconds(31000);
  cursor_x = 0;
  cursor_y = 0;
  tempore_log("Display cleared");
}

size_t tempore_m5_display::println(const char *text) {
  delayMicroseconds(1000);
  tempore_log("Display: %s", text);
  return strlen(text) + 1;
}

size_t tempore_m5_display::print(const char *text) {
  delayMicroseconds(1000);
  tempore_log("Display at (%d, %d): %s", static_cast<int>(cursor_x),
              static_cast<int>(cursor_y), text);
  return strlen(text);
}
