// The world of a host simulation, and the default world: a body that swings
// about its upright position with an amplitude of 0.1 radians and a period of
// 2 seconds, as a harmonic oscillator integrated by the semi-implicit Euler
// method, and wheels that turn at 20 radians per second times their drives.
// The default world is defined weakly, so that the host model of an
// application replaces it by defining world_start, world_advance and
// world_finish.

#include "tempore_world.h"

#include <esp_timer.h>

// Whether tempore_world_now has been called.
static bool tempore_world_observed = false;

tempore_world &tempore_world_now() {
  tempore_world_observed = true;
  static tempore_world w = [] {
    tempore_world initial{};
    initial.load = 1;
    world_start(initial);
    initial.time = 0;
    return initial;
  }();
  static int64_t t = 0;
  const int64_t now = esp_timer_get_time();
  while (t + tempore_world_step_us <= now) {
    world_advance(w, tempore_world_step_us * 1e-6);
    t += tempore_world_step_us;
    w.time = t * 1e-6;
  }
  return w;
}

__attribute__((weak)) void world_start(tempore_world &w) { w.tilt = 0.1; }

__attribute__((weak)) void world_advance(tempore_world &w, double dt) {
  const double omega = 3.14159265358979323846;
  w.tilt_rate -= omega * omega * w.tilt * dt;
  w.tilt += w.tilt_rate * dt;
  for (int i = 0; i < 2; ++i) {
    w.wheel_rate[i] = 20 * w.drive[i];
    w.wheel[i] += w.wheel_rate[i] * dt;
  }
}

__attribute__((weak)) void world_finish(const tempore_world &) {}

void tempore_world_finish() {
  if (tempore_world_observed) world_finish(tempore_world_now());
}
