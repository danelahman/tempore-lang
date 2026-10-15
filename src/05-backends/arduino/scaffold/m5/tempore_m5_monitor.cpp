// The display of the events of the monitor on the screen of a board driven
// through M5Unified: the banner of a violation that stops the tasks, red
// across the middle of the screen, and the line of the warnings, yellow in
// text of size 1 above the footer of the examples at y = 230. Text is cut at
// the right edge of the screen; the line of the warnings leaves the cursor,
// the text size and the colours white on black as the bindings of the display
// expect them. The brightness of the display, set once at start-up, is
// TEMPORE_DISPLAY_BRIGHTNESS percent of the greatest, 24 when it is not
// defined, converted to the level from 0 to 255 of M5Unified; the host
// simulation ignores it.

#include <M5Unified.h>
#include <stdio.h>
#include <string.h>

#include "tempore_scaffold.h"

#ifndef TEMPORE_DISPLAY_BRIGHTNESS
#define TEMPORE_DISPLAY_BRIGHTNESS 24
#endif
static_assert(TEMPORE_DISPLAY_BRIGHTNESS >= 0 &&
                  TEMPORE_DISPLAY_BRIGHTNESS <= 100,
              "TEMPORE_DISPLAY_BRIGHTNESS is a percentage from 0 to 100");

namespace {

enum : uint32_t {
  white = 0xffffff,
  black = 0x000000,
  red = 0xc00000,
  yellow = 0xffd700
};

// The height of the banner and the top of the line of the warnings, in
// pixels.
const int32_t banner_height = 96;
const int32_t warnings_top = 218;

// Copies text into buffer, cut to the characters that fit in the width of the
// screen at the current text size.
void fit(char *buffer, size_t size, const char *text) {
  snprintf(buffer, size, "%s", text);
  const int32_t room = M5.Display.width();
  for (size_t n = strlen(buffer); n > 0 && M5.Display.textWidth(buffer) > room;)
    buffer[--n] = '\0';
}

// Writes text centred on the line at y, in white over background, in text of
// size 2, or 1 if it is wider than the screen less a margin of 8 pixels.
void centred(const char *text, int32_t y, uint32_t background) {
  M5.Display.setTextSize(2);
  if (M5.Display.textWidth(text) > M5.Display.width() - 16)
    M5.Display.setTextSize(1);
  char line[96];
  fit(line, sizeof line, text);
  M5.Display.setTextColor(white, background);
  M5.Display.setCursor((M5.Display.width() - M5.Display.textWidth(line)) / 2,
                       y);
  M5.Display.print(line);
}

// Sets the brightness of the display to TEMPORE_DISPLAY_BRIGHTNESS. The
// tasks created by the initialisations of the packages may be running, and
// some boards set the backlight over the internal I2C bus, through the power
// management chip, so the lock of the I2C buses is held.
void begin() {
#ifndef TEMPORE_HOST
  const tempore_i2c_guard guard;
  M5.Display.setBrightness((TEMPORE_DISPLAY_BRIGHTNESS * 255 + 50) / 100);
#endif
}

void stop(const char *first, const char *second) {
  const int32_t top = (M5.Display.height() - banner_height) / 2;
  M5.Display.fillRect(0, top, M5.Display.width(), banner_height, red);
  centred("Stopped by the monitor", top + 12, red);
  centred(first, top + 40, red);
  centred(second, top + 64, red);
}

void warnings(const char *text) {
  const int32_t x = M5.Display.getCursorX(), y = M5.Display.getCursorY();
  const float size = M5.Display.getTextSizeX();
  M5.Display.fillRect(0, warnings_top, M5.Display.width(), 10, black);
  M5.Display.setTextSize(1);
  char line[96];
  fit(line, sizeof line, text);
  M5.Display.setTextColor(yellow, black);
  M5.Display.setCursor(0, warnings_top);
  M5.Display.print(line);
  M5.Display.setTextColor(white, black);
  M5.Display.setTextSize(size);
  M5.Display.setCursor(x, y);
}

}  // namespace

extern const tempore_monitor_display tempore_m5_monitor_display;

const tempore_monitor_display tempore_m5_monitor_display = {begin, stop,
                                                            warnings};
