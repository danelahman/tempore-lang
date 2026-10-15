// The host model of starter.tpe: a starting block at rest, its acceleration
// 1 g along z with a noise of 0.01 g, and seven taps of 150 ms, each 7 s
// after the last from 1 s: on Start for a legal start, the push 160 ms after
// the gun; for a false start, the push 60 ms after it; for a movement in Set,
// a twitch 800 ms after the Set command; for a start without a push; for a
// start abandoned by a tap on Stand up a second after the Set command; on
// Reset; and on Start for a start not still at the marks. The push is a rise
// of 0.6 g for 80 ms, the twitch of 0.3 g for 50 ms, and the unsettled
// block a rise of 0.3 g from 400 to 500 ms after the tap. The times of the
// Set command and of the gun are those of their tones, 1500 and 2500 Hz,
// observed through m5_speaker_observe.

#include <esp_timer.h>
#include <stdint.h>

#include "tempore_world.h"

namespace {

enum scenario { legal, reaction, moved, none, abandoned, reset, unsettled };

const int scenarios = 7;
const double first_tap = 1.0;
const double spacing = 7.0;

// The times of the last Set command and of the last gun, in seconds.
double set_time = -1;
double gun_time = -1;

// The scenario of the time t, in seconds, from the last tap before it.
int scenario_at(double t) {
  const int k = static_cast<int>((t - first_tap) / spacing);
  return k < 0 ? -1 : k < scenarios ? k : -1;
}

double tap_time(int k) { return first_tap + k * spacing; }

bool within(double t, double start, double length) {
  return start >= 0 && t >= start && t < start + length;
}

// A pseudo-random number in [-1, 1), by the 32-bit xorshift generator of
// Marsaglia (2003), so that the noise is the same on every platform.
uint32_t state = 2463534242u;

double uniform() {
  state ^= state << 13;
  state ^= state >> 17;
  state ^= state << 5;
  return static_cast<double>(state) / 2147483648.0 - 1.0;
}

}  // namespace

void m5_speaker_observe(float frequency, uint32_t) {
  const double now = esp_timer_get_time() * 1e-6;
  if (frequency == 1500.0f) set_time = now;
  if (frequency == 2500.0f) gun_time = now;
}

void world_start(tempore_world &w) { w.accel_given = true; }

void world_advance(tempore_world &w, double) {
  const double t = w.time;
  const int k = scenario_at(t);
  const double tap = k < 0 ? -1 : tap_time(k);
  const double set = set_time >= tap ? set_time : -1;
  const double gun = gun_time >= tap ? gun_time : -1;
  double rise = 0;
  if (k == legal && within(t, gun + 0.16, 0.08)) rise = 0.6;
  if (k == reaction && within(t, gun + 0.06, 0.08)) rise = 0.6;
  if (k == moved && within(t, set + 0.8, 0.05)) rise = 0.3;
  if (k == unsettled && within(t, tap + 0.4, 0.1)) rise = 0.3;
  const double noise = 0.01 * (uniform() + uniform() + uniform());
  w.accel[0] = 0;
  w.accel[1] = 0;
  w.accel[2] = 1 + rise + noise;
  const bool on_reset = k == reset;
  const bool stand_up = k == abandoned && within(t, set + 1.0, 0.15);
  w.touched = (k >= 0 && within(t, tap, 0.15)) || stand_up;
  w.touch[0] = on_reset ? 242 : 78;
  w.touch[1] = 208;
}
