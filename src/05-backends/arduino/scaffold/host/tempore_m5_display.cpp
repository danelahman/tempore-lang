// The host model of the display of an M5Stack core: its lines are written to
// the log, those written at a position with the position, as are the fills of
// rectangles and discs in a colour other than black, with their positions,
// sizes and colours. Each transfer of pixels takes the time of 16 bits a
// pixel at 40 MHz: clearing takes 31 milliseconds, that of 320 by 240 pixels,
// and a fill or the outline of a shape the time of its pixels. A line takes 1
// millisecond, and a text at a position 1 millisecond and 20 microseconds a
// character, so that the footer of the examples, of 40 characters over a band
// of 240 by 10 pixels, takes 2.76 ms, near the least time of ShowTextAt
// measured on an M5Stack CoreS3 Lite (2026-10-14), 2.599 ms.

#include <Arduino.h>
#include <M5Unified.h>

#include "tempore_scaffold.h"

namespace {

const double pi = 3.14159265358979323846;

// Waits for the transfer of n pixels.
void transfer(double n) {
  delayMicroseconds(static_cast<uint32_t>(n > 0 ? n * 16 / 40 : 0));
}

}  // namespace

void tempore_m5_display::setTextSize(float size) { text_size = size; }

void tempore_m5_display::setCursor(int32_t x, int32_t y) {
  cursor_x = x;
  cursor_y = y;
}

void tempore_m5_display::setTextColor(uint32_t, uint32_t) {}

int32_t tempore_m5_display::textWidth(const char *text) const {
  return static_cast<int32_t>(6 * text_size * strlen(text));
}

int32_t tempore_m5_display::fontHeight() const {
  return static_cast<int32_t>(8 * text_size);
}

void tempore_m5_display::fillRect(int32_t x, int32_t y, int32_t w, int32_t h,
                                  uint32_t color) {
  transfer(static_cast<double>(w) * h);
  if (color != 0)
    tempore_log("Display fill at (%d, %d), %d by %d: 0x%06x",
                static_cast<int>(x), static_cast<int>(y), static_cast<int>(w),
                static_cast<int>(h), static_cast<unsigned>(color));
}

void tempore_m5_display::fillRoundRect(int32_t x, int32_t y, int32_t w,
                                       int32_t h, int32_t, uint32_t color) {
  fillRect(x, y, w, h, color);
}

void tempore_m5_display::drawRoundRect(int32_t, int32_t, int32_t w, int32_t h,
                                       int32_t, uint32_t) {
  transfer(2.0 * (w + h));
}

void tempore_m5_display::fillCircle(int32_t x, int32_t y, int32_t r,
                                    uint32_t color) {
  transfer(pi * r * r);
  if (color != 0)
    tempore_log("Display disc at (%d, %d), radius %d: 0x%06x",
                static_cast<int>(x), static_cast<int>(y), static_cast<int>(r),
                static_cast<unsigned>(color));
}

void tempore_m5_display::drawCircle(int32_t, int32_t, int32_t r, uint32_t) {
  transfer(2 * pi * r);
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
  delayMicroseconds(static_cast<uint32_t>(1000 + 20 * strlen(text)));
  tempore_log("Display at (%d, %d): %s", static_cast<int>(cursor_x),
              static_cast<int>(cursor_y), text);
  return strlen(text);
}
