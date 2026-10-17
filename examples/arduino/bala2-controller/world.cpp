// The host model of controller.tpe: the hand that holds the CoreS3. It
// lies flat until 1.5 s, but for a tap on Arm at 1 s; it is pitched forwards
// by 20 degrees until 2.5 s, then pitched backwards by 10 degrees and rolled
// by 15 degrees until 3 s, and lies flat again, with a tap on Disarm at
// 3.5 s. Each tap lasts 100 ms.

#include <Arduino.h>
#include <math.h>

#include "tempore_world.h"

namespace {

const double degree = PI / 180;

bool within(double t, double start, double length) {
  return t >= start && t < start + length;
}

}  // namespace

void world_start(tempore_world &w) { w.accel_given = true; }

void world_advance(tempore_world &w, double) {
  const double t = w.time;
  const double pitch = within(t, 1.5, 1.0) ? 20 : within(t, 2.5, 0.5) ? -10 : 0;
  const double roll = within(t, 2.5, 0.5) ? 15 : 0;
  w.accel[0] = -sin(roll * degree);
  w.accel[1] = sin(pitch * degree) * cos(roll * degree);
  w.accel[2] = cos(pitch * degree) * cos(roll * degree);
  const bool arm = within(t, 1.0, 0.1), disarm = within(t, 3.5, 0.1);
  w.touched = arm || disarm;
  w.touch[0] = arm ? 78 : 242;
  w.touch[1] = 208;
}
