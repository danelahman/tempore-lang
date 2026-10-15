// The host model of steps.tpe: a unit held at a fixed orientation, rotated
// by 0.5 rad about its x axis and 0.3 rad about its y axis, whose
// accelerometer reads 0.95 of the force, a scale error that the calibration
// removes. It is at rest at 1 g but for these motions, each at least 2 s
// from the next:
// - shaking at 5 Hz from 3 s to 5 s, by 0.8 g vertically and 0.5 g
//   horizontally;
// - a bump at 7 s, an oscillation at 25 Hz from 1.5 g decaying in 20 ms;
// - the unit picked up at 9 s and put down at 12 s, each a rise and a fall
//   of 0.3 g over 0.8 s;
// - bouncing on the spot from 15 s to 19 s, two bounces a second of 0.4 g,
//   vertical only;
// - a walk from 21 s to 26 s of two steps a second, ten steps, the vertical
//   acceleration swinging by 0.4 g and the horizontal one by 0.3 g a
//   quarter period later;
// - taps of 150 ms: on Calibrate at 28 s, on Reset at 31 s and at the
//   centre of the screen, outside the buttons, at 34 s; and two of 120 ms
//   on Reset at 36 s and 36.6 s;
// - a walk of six steps from 39 s to 42 s;
// - a tap of 150 ms on Calibrate at 44 s.
//
// When the environment variable STEPS_REPLAY names a recording written by
// the target arduino-steps-capture, the accelerometer reads its readings
// instead, from its first at time 0, each until the next, the last held, and
// the screen is not touched; its events are ignored. The readings are
// given to the accelerometer as they are, without trigonometry, so that the
// replay does not depend on the mathematical library. Under the build flag
// STEPS_RECORD the recordings are printed at the end of the simulation.

#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#include <vector>

#include "tempore_world.h"

#ifdef STEPS_RECORD
void steps_record_print();

void world_finish(const tempore_world &) { steps_record_print(); }
#endif

namespace {

// A reading of a recording: its time, in ms from the first, and the
// acceleration, in g.
struct reading {
  double t;
  double a[3];
};

std::vector<reading> replay;
size_t replayed = 0;

// The readings of the recording named by STEPS_REPLAY, if any: the rows of
// four numbers or more after the line of the columns.
void load_replay() {
  const char *path = getenv("STEPS_REPLAY");
  if (path == nullptr) return;
  FILE *f = fopen(path, "r");
  if (f == nullptr) {
    fprintf(stderr, "STEPS_REPLAY: cannot open %s\n", path);
    exit(1);
  }
  char line[160];
  while (fgets(line, sizeof line, f) != nullptr) {
    reading r;
    if (sscanf(line, "%lf,%lf,%lf,%lf", &r.t, &r.a[0], &r.a[1], &r.a[2]) == 4)
      replay.push_back(r);
  }
  fclose(f);
  for (size_t i = replay.size(); i-- > 0;) replay[i].t -= replay[0].t;
}

// The vertical and horizontal accelerations at the time t, in seconds, less
// gravity, in g.
void motion(double t, double &vertical, double &horizontal) {
  const double w = 2.0 * M_PI * 2.0;
  vertical = 0;
  horizontal = 0;
  if (t >= 3.0 && t < 5.0) {
    vertical = 0.8 * sin(2.0 * M_PI * 5.0 * (t - 3.0));
    horizontal = 0.5 * sin(2.0 * M_PI * 5.0 * (t - 3.0));
  } else if (t >= 7.0 && t < 7.1) {
    vertical =
        1.5 * exp(-(t - 7.0) / 0.02) * sin(2.0 * M_PI * 25.0 * (t - 7.0));
  } else if (t >= 9.0 && t < 9.8) {
    vertical = 0.3 * sin(2.0 * M_PI * (t - 9.0) / 0.8);
  } else if (t >= 12.0 && t < 12.8) {
    vertical = -0.3 * sin(2.0 * M_PI * (t - 12.0) / 0.8);
  } else if (t >= 15.0 && t < 19.0) {
    vertical = -0.4 * sin(w * (t - 15.0));
  } else if ((t >= 21.0 && t < 26.0) || (t >= 39.0 && t < 42.0)) {
    const double s = t < 30.0 ? t - 21.0 : t - 39.0;
    vertical = -0.4 * sin(w * s);
    horizontal = 0.3 * cos(w * s);
  }
}

// The point of the screen touched at the time t, in seconds, if any: on
// Calibrate (78, 208), on Reset (242, 208), or at the centre (160, 120).
bool tapped(double t, int &x, int &y) {
  const bool calibrate = (t >= 28.0 && t < 28.15) || (t >= 44.0 && t < 44.15);
  const bool reset = (t >= 31.0 && t < 31.15) || (t >= 36.0 && t < 36.12) ||
                     (t >= 36.6 && t < 36.72);
  const bool centre = t >= 34.0 && t < 34.15;
  x = calibrate ? 78 : reset ? 242 : 160;
  y = calibrate || reset ? 208 : 120;
  return calibrate || reset || centre;
}

}  // namespace

void world_start(tempore_world &w) {
  w.tilt = 0;
  load_replay();
}

// The reading a of a recording, given to the accelerometer.
static void replay_reading(tempore_world &w, const double *a) {
  w.accel_given = true;
  for (int k = 0; k < 3; ++k) w.accel[k] = a[k];
  w.touched = false;
}

// The reading of the unit is load (sin roll, sin tilt cos roll, cos tilt cos
// roll); the force (horizontal, 0, 1 + vertical), rotated into the frame of
// the unit and scaled by 0.95, gives the load, the roll and the tilt.
void world_advance(tempore_world &w, double) {
  if (!replay.empty()) {
    while (replayed + 1 < replay.size() &&
           replay[replayed + 1].t <= w.time * 1000.0)
      ++replayed;
    replay_reading(w, replay[replayed].a);
    return;
  }
  double vertical, horizontal;
  motion(w.time, vertical, horizontal);
  const double a = 0.5, b = 0.3;
  const double fx = horizontal, fy = 0, fz = 1 + vertical;
  const double y1 = cos(a) * fy - sin(a) * fz, z1 = sin(a) * fy + cos(a) * fz;
  const double x2 = cos(b) * fx + sin(b) * z1, z2 = -sin(b) * fx + cos(b) * z1;
  const double load = sqrt(x2 * x2 + y1 * y1 + z2 * z2);
  w.load = 0.95 * load;
  w.roll = asin(x2 / load);
  w.tilt = atan2(y1, z2);
  int x, y;
  w.touched = tapped(w.time, x, y);
  w.touch[0] = x;
  w.touch[1] = y;
}
