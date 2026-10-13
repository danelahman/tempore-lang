// The host model of fall.tpe: a unit at rest but for two falls, each a free
// fall of 300 ms at 0.05 g followed by an impact of 40 ms at 3.5 g, at 2 s
// and at 25 s, and taps of 300 ms on the screen at 16 s, during the alarm of
// the first fall, and at 28 s, during the countdown of the second.

#include "tempore_world.h"

namespace {

// The load at the time t, in seconds, of a fall starting at start.
double fall(double t, double start) {
  if (t >= start && t < start + 0.3) return 0.05;
  if (t >= start + 0.3 && t < start + 0.34) return 3.5;
  return 1;
}

bool within(double t, double start) { return t >= start && t < start + 0.3; }

}  // namespace

void world_start(tempore_world &w) { w.tilt = 0; }

void world_advance(tempore_world &w, double) {
  const double t = w.time;
  w.load = fall(t, 2.0) * fall(t, 25.0);
  w.touched = within(t, 16.0) || within(t, 28.0);
  w.touch[0] = 160;
  w.touch[1] = 120;
}

void world_finish(const tempore_world &) {}
