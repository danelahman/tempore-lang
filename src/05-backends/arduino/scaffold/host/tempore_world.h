// The physical world of a host simulation, which the device models observe
// and act on: a body that tilts about two axes on two wheels driven by two
// motors, under a specific force, with a touch screen.
//
// The world is advanced in steps of tempore_world_step_us microseconds of
// simulated time, lazily: tempore_world_now advances it by the steps that end
// by the current time. Its state is the initial state set by world_start and
// the steps taken by world_advance, which the host model of an application
// defines; without them the default world of tempore_world.cpp applies. At
// the end of the simulation, world_finish receives the world at that time,
// if a device model has observed it.

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
  double roll;           // the angle of the body about its second axis, in
                         // radians
  double load;           // the magnitude of the specific force on the body,
                         // in g: 1 at rest, 0 in free fall
  bool touched;          // whether the touch screen is touched
  double touch[2];       // the point touched, in pixels
  bool accel_given;      // whether accel is the reading of the
                         // accelerometer
  double accel[3];       // that reading, in g, in place of the one of the
                         // load, the roll and the tilt
  double gyro_bias[3];   // the constant offset of the readings of the
                         // gyroscope, in radians per second
};

// The length of a step.
const int64_t tempore_world_step_us = 100;

// The world at the last step that ends by the current simulated time.
tempore_world &tempore_world_now();

// Sets the initial state of the world, at time 0, from the state at rest,
// zero but for the load of 1.
void world_start(tempore_world &w);

// Advances the world by dt seconds; the time is advanced by the caller.
void world_advance(tempore_world &w, double dt);

// Receives the world at the end of the simulation; by default nothing.
void world_finish(const tempore_world &w);

// Advances the world to the end of the simulation and passes it to
// world_finish, if tempore_world_now has been called; called by the
// simulator.
void tempore_world_finish();

#endif
