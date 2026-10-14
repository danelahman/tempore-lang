// The package m5-display: lines of text and numbers on the display of an
// M5Stack core, through M5Unified, written below one another in text of size
// 2, or at a position in a given size over a band of the display filled with
// the background; buttons, bars and a bubble level. Each binding holds the lock
// of the display while it draws.

#include <M5Unified.h>
#include <math.h>
#include <stdio.h>

#include "tempore_bindings.h"

// The text size of the lines.
static const int m5_display_line_size = 2;

void m5_display_init() {
  M5.Display.setTextSize(m5_display_line_size);
  M5.Display.setCursor(0, 0);
}

// The colours of the text and of the background, the grey of the buttons and
// of the bars, and the grey of the centre of the bubble level.
enum : uint32_t {
  m5_display_white = 0xffffff,
  m5_display_black = 0x000000,
  m5_display_dark_grey = 0x303030,
  m5_display_grey = 0x808080
};

#if defined(TEMPORE_PERFORMS_ShowTextAt) ||   \
    defined(TEMPORE_PERFORMS_ShowNumberAt) || \
    defined(TEMPORE_PERFORMS_ShowTimeAt) ||   \
    defined(TEMPORE_PERFORMS_ShowColourTextAt)
// Writes text at (x, y) in text of size 1 to 4 (size clamped), in the colour
// foreground over the band from x to the right edge, 10 * size pixels high,
// filled with the colour background; the next line starts below the band.
static inline void m5_display_at(uint32_t x, uint32_t y, uint32_t size,
                                 uint32_t foreground, uint32_t background,
                                 const char *text) {
  const int32_t s = size < 1 ? 1 : size > 4 ? 4 : static_cast<int32_t>(size);
  const int32_t left = static_cast<int32_t>(x), top = static_cast<int32_t>(y);
  M5.Display.fillRect(left, top, M5.Display.width() - left, 10 * s, background);
  M5.Display.setTextColor(foreground, background);
  M5.Display.setTextSize(s);
  M5.Display.setCursor(left, top);
  M5.Display.print(text);
  M5.Display.setTextColor(m5_display_white, m5_display_black);
  M5.Display.setTextSize(m5_display_line_size);
  M5.Display.setCursor(0, top + 10 * s);
}
#endif

#ifdef TEMPORE_PERFORMS_ShowText
tempore_result_ShowText binding_ShowText(tempore_argument_ShowText text) {
  const tempore_display_guard guard;
  M5.Display.println(text);
  return {};
}
#endif

#ifdef TEMPORE_PERFORMS_ShowNumber
tempore_result_ShowNumber binding_ShowNumber(tempore_argument_ShowNumber x) {
  const tempore_display_guard guard;
  char line[24];
  snprintf(line, sizeof line, "%.3f", static_cast<double>(x));
  M5.Display.println(line);
  return {};
}
#endif

#ifdef TEMPORE_PERFORMS_ClearDisplay
tempore_result_ClearDisplay binding_ClearDisplay(tempore_argument_ClearDisplay) {
  const tempore_display_guard guard;
  M5.Display.clear();
  M5.Display.setCursor(0, 0);
  return {};
}
#endif

#ifdef TEMPORE_PERFORMS_ShowTextAt
tempore_result_ShowTextAt binding_ShowTextAt(tempore_argument_ShowTextAt a) {
  const tempore_display_guard guard;
  m5_display_at(a.c0, a.c1, a.c2, m5_display_white, m5_display_black, a.c3);
  return {};
}
#endif

#ifdef TEMPORE_PERFORMS_ShowNumberAt
tempore_result_ShowNumberAt binding_ShowNumberAt(
    tempore_argument_ShowNumberAt a) {
  const tempore_display_guard guard;
  char text[24];
  snprintf(text, sizeof text, "%.*f", static_cast<int>(a.c3 > 6 ? 6 : a.c3),
           static_cast<double>(a.c4));
  m5_display_at(a.c0, a.c1, a.c2, m5_display_white, m5_display_black, text);
  return {};
}
#endif

#ifdef TEMPORE_PERFORMS_ShowTimeAt
tempore_result_ShowTimeAt binding_ShowTimeAt(tempore_argument_ShowTimeAt a) {
  const tempore_display_guard guard;
  char text[96];
  snprintf(text, sizeof text, "%s%u:%02u", a.c3,
           static_cast<unsigned>(a.c4 / 60), static_cast<unsigned>(a.c4 % 60));
  m5_display_at(a.c0, a.c1, a.c2, m5_display_white, m5_display_black, text);
  return {};
}
#endif

#ifdef TEMPORE_PERFORMS_ShowColourTextAt
tempore_result_ShowColourTextAt binding_ShowColourTextAt(
    tempore_argument_ShowColourTextAt a) {
  const tempore_display_guard guard;
  m5_display_at(a.c0, a.c1, a.c2, a.c3, a.c4, a.c5);
  return {};
}
#endif

#ifdef TEMPORE_PERFORMS_DrawButton
// The radius of the corners of a button, in pixels.
static const int32_t m5_display_corner = 6;

tempore_result_DrawButton binding_DrawButton(tempore_argument_DrawButton a) {
  const tempore_display_guard guard;
  const int32_t x = static_cast<int32_t>(a.c0), y = static_cast<int32_t>(a.c1);
  const int32_t w = static_cast<int32_t>(a.c2), h = static_cast<int32_t>(a.c3);
  M5.Display.fillRoundRect(x, y, w, h, m5_display_corner, m5_display_dark_grey);
  M5.Display.drawRoundRect(x, y, w, h, m5_display_corner, m5_display_white);
  static const float sizes[] = {2.0f, 1.5f, 1.0f};
  for (const float size : sizes) {
    M5.Display.setTextSize(size);
    if (M5.Display.textWidth(a.c4) <= w - 8) break;
  }
  M5.Display.setTextColor(m5_display_white, m5_display_dark_grey);
  M5.Display.setCursor(x + (w - M5.Display.textWidth(a.c4)) / 2,
                       y + (h - M5.Display.fontHeight()) / 2);
  M5.Display.print(a.c4);
  M5.Display.setTextColor(m5_display_white, m5_display_black);
  M5.Display.setTextSize(m5_display_line_size);
  M5.Display.setCursor(0, y + h);
  return {};
}
#endif

#ifdef TEMPORE_PERFORMS_DrawBar
tempore_result_DrawBar binding_DrawBar(tempore_argument_DrawBar a) {
  const tempore_display_guard guard;
  const int32_t x = static_cast<int32_t>(a.c0), y = static_cast<int32_t>(a.c1);
  const int32_t w = static_cast<int32_t>(a.c2), h = static_cast<int32_t>(a.c3);
  const int32_t n = a.c4 > a.c2 ? w : static_cast<int32_t>(a.c4);
  if (n > 0) M5.Display.fillRect(x, y, n, h, a.c5);
  if (n < w) M5.Display.fillRect(x + n, y, w - n, h, m5_display_dark_grey);
  return {};
}
#endif

#ifdef TEMPORE_PERFORMS_DrawLevel
// The bubble level last drawn: its centre, radius, bubble and colour, if any.
struct m5_display_level {
  bool drawn;
  int32_t x, y, r, bx, by;
  uint32_t colour;
};

static m5_display_level m5_display_last_level = {false, 0, 0, 0, 0, 0, 0};

tempore_result_DrawLevel binding_DrawLevel(tempore_argument_DrawLevel a) {
  const tempore_display_guard guard;
  const int32_t x = static_cast<int32_t>(a.c0), y = static_cast<int32_t>(a.c1);
  const int32_t r = static_cast<int32_t>(a.c2), rb = r / 6;
  // The offset of the bubble, scaled towards the centre to the greatest
  // distance at which the bubble lies within the vial.
  const float limit = static_cast<float>(r - rb - 1 > 0 ? r - rb - 1 : 0);
  float dx = static_cast<float>(a.c3), dy = static_cast<float>(a.c4);
  const float d = sqrtf(dx * dx + dy * dy);
  if (d > limit) {
    dx *= limit / d;
    dy *= limit / d;
  }
  const int32_t bx = x + static_cast<int32_t>(lroundf(dx));
  const int32_t by = y + static_cast<int32_t>(lroundf(dy));
  m5_display_level &last = m5_display_last_level;
  const bool same_vial = last.drawn && last.x == x && last.y == y && last.r == r;
  if (same_vial && last.bx == bx && last.by == by && last.colour == a.c5)
    return {};
  if (same_vial) M5.Display.fillCircle(last.bx, last.by, rb, m5_display_black);
  M5.Display.drawCircle(x, y, r, m5_display_white);
  M5.Display.drawCircle(x, y, r / 4, m5_display_grey);
  M5.Display.fillCircle(bx, by, rb, a.c5);
  last = {true, x, y, r, bx, by, a.c5};
  return {};
}
#endif
