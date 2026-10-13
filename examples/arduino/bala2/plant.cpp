// The host model of the M5Stack BALA2 for balance.tpe and
// ../bala2-regex/balance_regex.tpe: an inverted pendulum on two wheels driven
// by two DC motors, as a world of the host simulation.
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
// A motor at drive d, from -1 to 1, exerts the torque T (d - w / W) on its
// wheel, w being the rate of the wheel relative to the body, T the stall
// torque and W the free speed. The two wheels move in common by the model
// above, under the sum of the torques, and in difference by a rotation of
// the inertia of half of the common motion under half of the difference of
// the torques. The body rests on the ground at a tilt of PLANT_GROUND radians.
//
// The parameters are approximate values for the BALA2, not measurements:
// body 0.24 kg with its centre of mass 0.04 m above the axle and a moment of
// inertia of 1.5e-4 kg m^2; wheels of 0.015 kg each and of radius 0.033 m;
// motors of stall torque 0.1 N m and free speed 30 rad/s at the wheel.
//
// The body is held at the initial tilt PLANT_TILT, in radians, as by a hand,
// and released when a motor is first driven or at PLANT_RELEASE_MS
// milliseconds, whichever comes first. At the end
// of the simulation the model logs the time of the release, the final tilt,
// the largest tilt from one second after the release on, and the largest
// drive of the motors.

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

namespace {

const double body_mass = 0.24;
const double body_height = 0.04;
const double body_inertia = 1.5e-4;
const double wheel_mass = 2 * 0.015;
const double wheel_radius = 0.033;
const double wheel_inertia = 2 * 0.5 * 0.015 * wheel_radius * wheel_radius;
const double stall_torque = 0.1;
const double free_speed = 30;
const double gravity = 9.81;
const double degrees = 180 / 3.14159265358979323846;

// The time of the release.
double release = PLANT_RELEASE_MS * 1e-3;

// The largest tilt from one second after the release on, the largest drive,
// and the time of the last step with a motor driven, if any.
double largest_tilt = 0;
double largest_drive = 0;
double last_driven = -1;

// The torque of a motor at drive d on a wheel turning at rate w relative to
// the body.
double torque(double d, double w) {
  return stall_torque * (d - w / free_speed);
}

}  // namespace

void world_start(tempore_world &w) { w.tilt = PLANT_TILT; }

void world_advance(tempore_world &w, double dt) {
  const double phi_rate = (w.wheel_rate[0] + w.wheel_rate[1]) / 2;
  const double psi_rate = (w.wheel_rate[0] - w.wheel_rate[1]) / 2;
  const double tau0 = torque(w.drive[0], w.wheel_rate[0] - w.tilt_rate);
  const double tau1 = torque(w.drive[1], w.wheel_rate[1] - w.tilt_rate);
  const double tau = tau0 + tau1;
  const double a11 =
      wheel_inertia + (wheel_mass + body_mass) * wheel_radius * wheel_radius;
  const double a12 = body_mass * wheel_radius * body_height * cos(w.tilt);
  const double a22 = body_inertia + body_mass * body_height * body_height;
  const double b1 = tau + body_mass * wheel_radius * body_height *
                              sin(w.tilt) * w.tilt_rate * w.tilt_rate;
  const double b2 = -tau + body_mass * gravity * body_height * sin(w.tilt);
  if (w.time < release && (w.drive[0] != 0 || w.drive[1] != 0))
    release = w.time;
  const bool held = w.time < release;
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
