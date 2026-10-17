// The host model of the M5Stack BALA2 for balance.tpe,
// ../bala2-regex/balance_regex.tpe and ../bala2-remote/balance_remote.tpe: an
// inverted pendulum on two wheels driven by two DC motors, as a world of the
// host simulation.
//
// The body, of mass M and moment of inertia I about its centre of mass at a
// distance l above the axle, tilts by theta from upright, positive forwards;
// the wheels, of total mass m, radius r and total moment of inertia J about
// the axle, turn by phi, positive forwards. With the total torque tau of the
// motors on the wheels and its reaction on the body, the Lagrange equations
// of the nonlinear model are
//
//   (J + (m + M) r^2) phi'' + M r l cos(theta) theta''
//       = tau + M r l sin(theta) theta'^2
//   M r l cos(theta) phi'' + (I + M l^2) theta''
//       = -tau + M g l sin(theta)
//
// A motor at drive d, from -1 to 1, exerts the torque T (e - w / W) on its
// wheel, w being the rate of the wheel relative to the body, T the stall
// torque, W the free speed and e the drive scaled by the strength of the
// motor less its dead band towards zero, or zero within the dead band. The
// two wheels move in common by the model
// above, under the sum of the torques, and in difference by a rotation of
// the inertia of half of the common motion under half of the difference of
// the torques. The body rests on the ground at a tilt of PLANT_GROUND radians.
//
// The centre of mass lies PLANT_OFFSET radians forwards of the axis of the
// body, along which the unit measures the tilt (0 unless the build flag sets
// it): the model above holds for the tilt theta + PLANT_OFFSET of the centre
// of mass, and the robot balances at a tilt of -PLANT_OFFSET.
//
// The parameters of the body and the wheels are approximate values for the
// BALA2, not measurements: body 0.24 kg with its centre of mass 0.04 m above
// the axle and a moment of inertia of 1.5e-4 kg m^2; wheels of 0.015 kg each
// and of radius 0.033 m. The motors have the stall torque PLANT_STALL_TORQUE,
// 0.1 N m, an approximate value, and the free speed PLANT_FREE_SPEED, 60
// rad/s at the wheel; the dead band of the left motor is PLANT_DEAD_BAND, 70
// units of drive of 1023, that of the right PLANT_RIGHT_DEAD_BAND, 180, and
// the strength of the right relative to the left PLANT_RIGHT_STRENGTH, 1. The
// free speed and the dead bands are estimated from measurements of a BALA2
// with its wheels off the ground: about 3700 counts per second of the left
// wheel at full drive, the onset of motion at a drive of about 70, and a
// right wheel half as fast as the left at a drive of 300.
//
// The body is held at the initial tilt PLANT_TILT, in radians, as by a hand,
// and released when a motor is first driven or at PLANT_RELEASE_MS
// milliseconds, whichever comes first, turning at PLANT_RELEASE_RATE radians
// per second (0 unless the build flag sets it). A hand stands the released
// body up again at the initial tilt and holds it still, until a motor is
// driven again, when plant_stand_up of the time returns true; it is defined
// weakly to return false, for the host model of an application to define.
// At the end
// of the simulation the model logs the time of the release, the final tilt,
// the largest tilt from one second after the release on, and the largest
// drive of the motors.

#include <Arduino.h>
#include <math.h>
#include <stdint.h>

#include "tempore_scaffold.h"
#include "tempore_world.h"

#ifndef PLANT_TILT
#define PLANT_TILT 0.1
#endif

#ifndef PLANT_RELEASE_MS
#define PLANT_RELEASE_MS 2000
#endif

#ifndef PLANT_GROUND
#define PLANT_GROUND 1.4
#endif

#ifndef PLANT_OFFSET
#define PLANT_OFFSET 0.0
#endif

#ifndef PLANT_RELEASE_RATE
#define PLANT_RELEASE_RATE 0.0
#endif

#ifndef PLANT_STALL_TORQUE
#define PLANT_STALL_TORQUE 0.1
#endif

#ifndef PLANT_FREE_SPEED
#define PLANT_FREE_SPEED 60.0
#endif

#ifndef PLANT_DEAD_BAND
#define PLANT_DEAD_BAND 70.0
#endif

#ifndef PLANT_RIGHT_DEAD_BAND
#define PLANT_RIGHT_DEAD_BAND 180.0
#endif

#ifndef PLANT_RIGHT_STRENGTH
#define PLANT_RIGHT_STRENGTH 1.0
#endif

namespace {

const double body_mass = 0.24;
const double body_height = 0.04;
const double body_inertia = 1.5e-4;
const double wheel_mass = 2 * 0.015;
const double wheel_radius = 0.033;
const double wheel_inertia = 2 * 0.5 * 0.015 * wheel_radius * wheel_radius;
const double stall_torque = PLANT_STALL_TORQUE;
const double free_speed = PLANT_FREE_SPEED;
const double dead_band[2] = {PLANT_DEAD_BAND / 1023.0,
                             PLANT_RIGHT_DEAD_BAND / 1023.0};
const double strength[2] = {1.0, PLANT_RIGHT_STRENGTH};
const double gravity = 9.81;
const double degrees = 180 / PI;

// The time of the release, and whether the body is released.
double release = PLANT_RELEASE_MS * 1e-3;
bool released = false;

// The largest tilt from one second after the release on, the largest drive,
// and the time of the last step with a motor driven, if any.
double largest_tilt = 0;
double largest_drive = 0;
double last_driven = -1;

// The torque of motor i at drive d on a wheel turning at rate w relative to
// the body: the drive scaled by the strength of the motor, less the dead
// band towards zero.
double torque(int i, double d, double w) {
  const double e = strength[i] * d;
  const double v =
      fabs(e) <= dead_band[i] ? 0 : e - copysign(dead_band[i], e);
  return stall_torque * (v - w / free_speed);
}

}  // namespace

__attribute__((weak)) bool plant_stand_up(double) { return false; }

void world_start(tempore_world &w) { w.tilt = PLANT_TILT; }

void world_advance(tempore_world &w, double dt) {
  if (released && plant_stand_up(w.time)) {
    w.tilt = PLANT_TILT;
    w.tilt_rate = 0;
    release = INFINITY;
    released = false;
  }
  const double phi_rate = (w.wheel_rate[0] + w.wheel_rate[1]) / 2;
  const double psi_rate = (w.wheel_rate[0] - w.wheel_rate[1]) / 2;
  const double tau0 = torque(0, w.drive[0], w.wheel_rate[0] - w.tilt_rate);
  const double tau1 = torque(1, w.drive[1], w.wheel_rate[1] - w.tilt_rate);
  const double tau = tau0 + tau1;
  const double a11 =
      wheel_inertia + (wheel_mass + body_mass) * wheel_radius * wheel_radius;
  const double lean = w.tilt + PLANT_OFFSET;
  const double a12 = body_mass * wheel_radius * body_height * cos(lean);
  const double a22 = body_inertia + body_mass * body_height * body_height;
  const double b1 = tau + body_mass * wheel_radius * body_height *
                              sin(lean) * w.tilt_rate * w.tilt_rate;
  const double b2 = -tau + body_mass * gravity * body_height * sin(lean);
  if (w.time < release && (w.drive[0] != 0 || w.drive[1] != 0))
    release = w.time;
  const bool held = w.time < release;
  if (!held && !released) {
    w.tilt_rate = PLANT_RELEASE_RATE;
    released = true;
  }
  double phi_acceleration, tilt_acceleration;
  if (held) {
    phi_acceleration = b1 / a11;
    tilt_acceleration = 0;
  } else {
    const double det = a11 * a22 - a12 * a12;
    phi_acceleration = (b1 * a22 - a12 * b2) / det;
    tilt_acceleration = (a11 * b2 - a12 * b1) / det;
  }
  const double psi_acceleration = (tau0 - tau1) / 2 / (a11 / 2);
  // Semi-implicit Euler: the rates first, then the angles from the new rates.
  w.tilt_rate += tilt_acceleration * dt;
  w.tilt += w.tilt_rate * dt;
  if (fabs(w.tilt) >= PLANT_GROUND) {
    w.tilt = copysign(PLANT_GROUND, w.tilt);
    w.tilt_rate = 0;
  }
  const double phi_new = phi_rate + phi_acceleration * dt;
  const double psi_new = psi_rate + psi_acceleration * dt;
  w.wheel_rate[0] = phi_new + psi_new;
  w.wheel_rate[1] = phi_new - psi_new;
  for (int i = 0; i < 2; ++i) w.wheel[i] += w.wheel_rate[i] * dt;
  const double now = w.time + dt;
  if (now >= release + 1) largest_tilt = fmax(largest_tilt, fabs(w.tilt));
  const double drive = fmax(fabs(w.drive[0]), fabs(w.drive[1]));
  largest_drive = fmax(largest_drive, drive);
  if (drive > 0) last_driven = now;
}

void world_finish(const tempore_world &w) {
  tempore_log("Plant: released at %.1f ms", release * 1e3);
  tempore_log("Plant: tilt %.2f degrees, wheels at %.3f m", w.tilt * degrees,
              (w.wheel[0] + w.wheel[1]) / 2 * wheel_radius);
  tempore_log("Plant: largest tilt from 1 s after the release %.2f degrees",
              largest_tilt * degrees);
  if (last_driven < 0)
    tempore_log("Plant: the motors were never driven");
  else
    tempore_log("Plant: largest drive %.3f, last at %.1f ms", largest_drive,
                last_driven * 1e3);
}
