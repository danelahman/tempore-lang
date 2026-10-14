// The host model of steps.tpe: a walker at rest but for a walk from 1 s to
// 6 s of two steps a second, ten steps in all, during which the magnitude of
// the acceleration falls to 0.6 g and rises to 1.4 g in each step.

#include <math.h>

#include "tempore_world.h"

void world_start(tempore_world &w) { w.tilt = 0; }

void world_advance(tempore_world &w, double) {
  const double t = w.time;
  const bool walking = t >= 1.0 && t < 6.0;
  w.load = walking ? 1.0 - 0.4 * sin(2.0 * M_PI * 2.0 * (t - 1.0)) : 1.0;
}
