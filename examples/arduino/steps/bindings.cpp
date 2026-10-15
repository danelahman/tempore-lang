// The bindings of the operations of steps.tpe: the steps counted, kept in a
// variable, each count and reset logged; the time since start-up; a button
// on the display, drawn with the lock of the display held; and the safe
// state, which writes a line to the log.

#include <Arduino.h>
#include <M5Unified.h>

#include "tempore_bindings.h"

static uint32_t steps_counted = 0;

tempore_result_CountStep binding_CountStep(tempore_argument_CountStep added) {
  steps_counted += static_cast<uint32_t>(added);
  tempore_log("Steps: %u counted, %u in all", static_cast<unsigned>(added),
              static_cast<unsigned>(steps_counted));
  return {};
}

tempore_result_ResetSteps binding_ResetSteps(tempore_argument_ResetSteps) {
  steps_counted = 0;
  tempore_log("Steps: reset");
  return {};
}

tempore_result_ReadClock binding_ReadClock(tempore_argument_ReadClock) {
  return millis();
}

// The colours of a button: the border, and the fill and the label of a
// button and of an active one; the radius of its corners, in pixels.
enum : uint32_t {
  steps_white = 0xffffff,
  steps_black = 0x000000,
  steps_dark_grey = 0x303030,
  steps_yellow = 0xffd000
};
static const int32_t steps_corner = 6;

tempore_result_ShowButton binding_ShowButton(tempore_argument_ShowButton a) {
  const tempore_display_guard guard;
  const int32_t x = static_cast<int32_t>(a.c0), y = static_cast<int32_t>(a.c1);
  const int32_t w = static_cast<int32_t>(a.c2), h = static_cast<int32_t>(a.c3);
  const uint32_t fill = a.c4 ? steps_yellow : steps_dark_grey;
  const uint32_t label = a.c4 ? steps_black : steps_white;
  tempore_display_drawn(x, y, w, h);
  M5.Display.fillRoundRect(x, y, w, h, steps_corner, fill);
  M5.Display.drawRoundRect(x, y, w, h, steps_corner, steps_white);
  M5.Display.setTextSize(2);
  M5.Display.setTextColor(label, fill);
  M5.Display.setCursor(x + (w - M5.Display.textWidth(a.c5)) / 2,
                       y + (h - M5.Display.fontHeight()) / 2);
  M5.Display.print(a.c5);
  M5.Display.setTextColor(steps_white, steps_black);
  return {};
}

void steps_safe_state() { tempore_log("Step counter stopped"); }
