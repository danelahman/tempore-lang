// The host model of the M5Stack BALA2 on a stand for wheels.tpe: the body
// upright and still, and wheels off the ground, each turning towards the
// rate STAND_WHEEL_RATE times the drive of its motor, in radians per second,
// with the time constant STAND_TIME_CONSTANT, in seconds, as a first-order
// lag integrated by the explicit Euler method. Under the build flag
// STAND_STALLED_WHEEL, the right wheel is stalled.

#include "tempore_world.h"

#ifndef STAND_WHEEL_RATE
#define STAND_WHEEL_RATE 20.0
#endif

#ifndef STAND_TIME_CONSTANT
#define STAND_TIME_CONSTANT 0.02
#endif

void world_start(tempore_world &w) { w.tilt = 0; }

void world_advance(tempore_world &w, double dt) {
  for (int i = 0; i < 2; ++i) {
#ifdef STAND_STALLED_WHEEL
    const double target = i == 1 ? 0 : STAND_WHEEL_RATE * w.drive[i];
#else
    const double target = STAND_WHEEL_RATE * w.drive[i];
#endif
    w.wheel_rate[i] += (target - w.wheel_rate[i]) * dt / STAND_TIME_CONSTANT;
    w.wheel[i] += w.wheel_rate[i] * dt;
  }
}
