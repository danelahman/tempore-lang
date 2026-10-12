// The physical world of a host simulation, which the device models observe
// and act on: a body that tilts about one axis on two wheels driven by two
// motors.
//
// The world is advanced in steps of tempore_world_step_us microseconds of
// simulated time, lazily: tempore_world_now advances it by the steps that end
// by the current time. Its state is the initial state set by world_start and
// the steps taken by world_advance, which the host model of an application
// defines; without them the default world of tempore_world.cpp applies.

#ifndef TEMPORE_HOST_WORLD_H
#define TEMPORE_HOST_WORLD_H

#include <stdint.h>

struct tempore_world {
  double time;           // the time of the state, in seconds
  double tilt;           // the angle of the body about its axis, in radians
  double tilt_rate;      // its rate, in radians per second
  double wheel[2];       // the angles of the wheels, in radians
  double wheel_rate[2];  // their rates, in radians per second
  double drive[2];       // the drives of the motors, from -1 to 1
};

// The length of a step.
const int64_t tempore_world_step_us = 100;

// The world at the last step that ends by the current simulated time.
tempore_world &tempore_world_now();

// Sets the initial state of the world, at time 0.
void world_start(tempore_world &w);

// Advances the world by dt seconds; the time is advanced by the caller.
void world_advance(tempore_world &w, double dt);

#endif
