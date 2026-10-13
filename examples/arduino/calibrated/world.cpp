// The host model of calibrated.tpe: the unit at rest at a tilt of 0.1 rad,
// whose gyroscope reads a bias of 2 degrees per second about the x axis. The
// host model of the inertial unit reads the rate of the tilt of the world,
// which the world holds at the bias without advancing the tilt.

#include "tempore_world.h"

void world_start(tempore_world &w) {
  w.tilt = 0.1;
  w.tilt_rate = 2.0 * 3.14159265358979323846 / 180.0;
}

void world_advance(tempore_world &, double) {}
