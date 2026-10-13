// The package m5-display: lines of text and numbers on the display of an
// M5Stack core, through M5Unified, written below one another in text of size
// 2, or at a position in a given size over a band of the display filled with
// the background.

#include <M5Unified.h>
#include <stdio.h>

#include "tempore_bindings.h"

// The text size of the lines.
static const int m5_display_line_size = 2;

void m5_display_init() {
  M5.Display.setTextSize(m5_display_line_size);
  M5.Display.setCursor(0, 0);
}

#if defined(TEMPORE_PERFORMS_ShowTextAt) || defined(TEMPORE_PERFORMS_ShowNumberAt)
// Writes text at (x, y) in text of size 1 to 4 (size clamped), white on
// black, over the band from x to the right edge, 10 * size pixels high,
// filled with black; the next line starts below the band.
static inline void m5_display_at(uint32_t x, uint32_t y, uint32_t size,
                                 const char *text) {
  const int32_t s = size < 1 ? 1 : size > 4 ? 4 : static_cast<int32_t>(size);
  const int32_t left = static_cast<int32_t>(x), top = static_cast<int32_t>(y);
  M5.Display.fillRect(left, top, M5.Display.width() - left, 10 * s, 0);
  M5.Display.setTextColor(0xffffffu, 0);
  M5.Display.setTextSize(s);
  M5.Display.setCursor(left, top);
  M5.Display.print(text);
  M5.Display.setTextSize(m5_display_line_size);
  M5.Display.setCursor(0, top + 10 * s);
}
#endif

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

#ifdef TEMPORE_PERFORMS_ShowTextAt
tempore_result_ShowTextAt binding_ShowTextAt(tempore_argument_ShowTextAt a) {
  m5_display_at(a.c0, a.c1, a.c2, a.c3);
  return {};
}
#endif

#ifdef TEMPORE_PERFORMS_ShowNumberAt
tempore_result_ShowNumberAt binding_ShowNumberAt(
    tempore_argument_ShowNumberAt a) {
  char text[24];
  snprintf(text, sizeof text, "%.*f", static_cast<int>(a.c3 > 6 ? 6 : a.c3),
           static_cast<double>(a.c4));
  m5_display_at(a.c0, a.c1, a.c2, text);
  return {};
}
#endif
