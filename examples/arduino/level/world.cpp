// The host model of level.tpe: a unit lying on a reference surface that
// tilts it by 1 degree about its x axis and by -0.7 degrees about its y axis,
// moved from 3 to 4.5 s onto a surface 3 degrees steeper and shaken, at a
// load of 1.3 g, from 7.25 to 7.45 s, and taps of 300 ms on the screen: on
// the button "Set reference" at 1 s, 6 s and 8 s, and on the button
// "Reconfigure sensor" at 5 s.

#include "tempore_world.h"

namespace {

const double radian = 3.14159265358979323846 / 180;

// Whether the time t, in seconds, lies within a tap starting at start.
bool within(double t, double start) { return t >= start && t < start + 0.3; }

}  // namespace

void world_start(tempore_world &w) {
  w.tilt = 1.0 * radian;
  w.roll = -0.7 * radian;
}

void world_advance(tempore_world &w, double) {
  const double t = w.time;
  w.tilt = (t >= 3.0 && t < 4.5 ? 4.0 : 1.0) * radian;
  w.load = t >= 7.25 && t < 7.45 ? 1.3 : 1.0;
  w.touched =
      within(t, 1.0) || within(t, 5.0) || within(t, 6.0) || within(t, 8.0);
  w.touch[0] = within(t, 5.0) ? 240 : 70;
  w.touch[1] = 210;
}

void world_finish(const tempore_world &) {}
