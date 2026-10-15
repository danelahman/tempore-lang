// The host model of steps.tpe: a device at rest at 1 g but for five motions,
// each at least 2.5 s from the next: shaking at 5 Hz from 1 s to 3 s, by
// 0.8 g; a bump at 5.5 s, an oscillation at 25 Hz from 1.5 g decaying in
// 20 ms; the device picked up at 8 s and put down at 11 s, each a rise and a
// fall of 0.3 g over 0.8 s; and a walk from 14 s to 19 s of two steps a
// second, ten steps in all, during which the magnitude of the acceleration
// falls to 0.6 g and rises to 1.4 g in each step.

#include <math.h>

#include "tempore_world.h"

// The magnitude of the acceleration at the time t, in g.
static double steps_load(double t) {
  if (t >= 1.0 && t < 3.0)
    return 1.0 + 0.8 * sin(2.0 * M_PI * 5.0 * (t - 1.0));
  if (t >= 5.5 && t < 5.6)
    return 1.0 + 1.5 * exp(-(t - 5.5) / 0.02) *
                     sin(2.0 * M_PI * 25.0 * (t - 5.5));
  if (t >= 8.0 && t < 8.8)
    return 1.0 + 0.3 * sin(2.0 * M_PI * (t - 8.0) / 0.8);
  if (t >= 11.0 && t < 11.8)
    return 1.0 - 0.3 * sin(2.0 * M_PI * (t - 11.0) / 0.8);
  if (t >= 14.0 && t < 19.0)
    return 1.0 - 0.4 * sin(2.0 * M_PI * 2.0 * (t - 14.0));
  return 1.0;
}

void world_start(tempore_world &w) { w.tilt = 0; }

void world_advance(tempore_world &w, double) { w.load = steps_load(w.time); }
