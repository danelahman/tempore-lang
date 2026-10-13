// The world of a host model of an application: a body held still at a tilt
// of 0.5 radians.

#include "tempore_world.h"

void world_start(tempore_world &w) { w.tilt = 0.5; }

void world_advance(tempore_world &, double) {}
