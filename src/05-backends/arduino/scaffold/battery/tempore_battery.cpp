// The battery indicator of a board driven through M5Unified with a screen and
// a battery gauge: the charge of the battery in percent, followed by "+" while
// it charges, in grey on black in text of size 1, right-aligned in the top
// right corner of the screen. A task of the idle priority, below every task of
// the application, reads the gauge at start-up and every
// TEMPORE_BATTERY_INTERVAL_MS milliseconds (default 5000), each read under the
// lock of the I2C buses, and draws the text, under the lock of
// the display, when it changes or when a drawing of the application
// intersects the corner (tempore_display_drawn), until the tasks are halted.
// The text is drawn over its own background and the rest of the corner
// filled with black, without a preceding fill of the corner; the cursor and
// the text size are restored and the colours left white on black, as the
// bindings of the display expect them.

#include <M5Unified.h>
#include <stdio.h>
#include <string.h>

#include "tempore_scaffold.h"

#ifndef TEMPORE_BATTERY_INTERVAL_MS
#define TEMPORE_BATTERY_INTERVAL_MS 5000
#endif

namespace {

enum : uint32_t { white = 0xffffff, black = 0x000000, grey = 0x808080 };

// The corner: the width of the longest text, "Battery 100%+", 13 characters
// of 6 pixels, and the height of a character, 8 pixels.
const int32_t corner_width = 78;
const int32_t corner_height = 8;

// The text of the charge of the battery, empty if the gauge reports none.
void read_battery(char *text, size_t size) {
  int32_t level;
  {
    const tempore_i2c_guard guard;
    level = M5.Power.getBatteryLevel();
  }
  if (level < 0) {
    text[0] = '\0';
    return;
  }
  bool charging;
  {
    const tempore_i2c_guard guard;
    charging = M5.Power.isCharging() == m5::Power_Class::is_charging;
  }
  snprintf(text, size, "Battery %d%%%s", static_cast<int>(level),
           charging ? "+" : "");
}

// Draws text right-aligned in the corner, the rest of the corner black,
// unless the tasks are halted; the notifications of the drawings before it are
// cleared.
void draw(const char *text) {
  const tempore_display_guard guard;
  ulTaskNotifyTake(pdTRUE, 0);
  if (tempore_halted()) return;
  const int32_t x = M5.Display.getCursorX(), y = M5.Display.getCursorY();
  const float size = M5.Display.getTextSizeX();
  M5.Display.setTextSize(1);
  const int32_t right = M5.Display.width();
  const int32_t left = right - corner_width;
  const int32_t start = right - M5.Display.textWidth(text);
  if (start > left)
    M5.Display.fillRect(left, 0, start - left, corner_height, black);
  if (text[0] != '\0') {
    M5.Display.setTextColor(grey, black);
    M5.Display.setCursor(start, 0);
    M5.Display.print(text);
  }
  M5.Display.setTextColor(white, black);
  M5.Display.setTextSize(size);
  M5.Display.setCursor(x, y);
}

// The task of the indicator, until the tasks are halted.
void indicator(void *) {
  const TickType_t interval = pdMS_TO_TICKS(TEMPORE_BATTERY_INTERVAL_MS);
  char text[24] = "";   // the text of the last reading
  char drawn[24] = "";  // the text drawn in the corner, empty if none
  read_battery(text, sizeof text);
  TickType_t read_at = xTaskGetTickCount();
  for (;;) {
    tempore_check_halt();
    if (strcmp(text, drawn) != 0) {
      draw(text);
      memcpy(drawn, text, sizeof drawn);
    }
    const TickType_t elapsed = xTaskGetTickCount() - read_at;
    if (ulTaskNotifyTake(pdTRUE, elapsed < interval ? interval - elapsed : 0) >
        0)
      drawn[0] = '\0';
    if (xTaskGetTickCount() - read_at >= interval) {
      read_battery(text, sizeof text);
      read_at = xTaskGetTickCount();
    }
  }
}

}  // namespace

void tempore_battery_begin() {
  TaskHandle_t task = nullptr;
  xTaskCreatePinnedToCore(indicator, "tempore-battery", 4096, nullptr,
                          tskIDLE_PRIORITY, &task, tskNO_AFFINITY);
  tempore_display_overlay_begin(M5.Display.width() - corner_width, 0,
                                corner_width, corner_height, task);
}
