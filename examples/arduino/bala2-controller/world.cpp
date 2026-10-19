// The host model of controller.tpe: the hand that holds the CoreS3, and the
// robot at the other end of the link.
//
// The CoreS3 lies flat until 0.9 s, and is then held pitched forwards by 10
// degrees, the neutral tilt recorded at the tap on Arm at 1 s; it is
// pitched forwards by 30 degrees from 2.2 s, 20 beyond the neutral tilt,
// which drives the robot forwards and draws the bubble up, then flat and
// rolled to the right by 15 degrees from 3 s, 10 behind the neutral tilt,
// which drives it backwards, turns it to the right and draws the bubble down
// and right, and from 3.5 s held at the neutral tilt again, with a tap on
// Disarm at 4.6 s. Each tap lasts 100 ms. As on the device, the unit reads a
// tilt forwards as a negative pitch and a tilt to the right as a positive
// roll.
//
// The robot, the peer of the host model of the package esp-now, sends its
// status every 20 ms: ready for Arm until 1.5 s, armed at a tilt of 2.5
// degrees until 3.8 s, nothing until 4.2 s, a loss of the link, armed at a
// tilt of 1.5 degrees until 4.9 s, calibrating until 5.6 s, calibrating
// after a failed check at rest until 6.3 s, calibrating until 7 s, ready
// for Arm until 7.6 s, and nothing after, switched off. The phases are
// coded as by remote_phase_code of the package bala2-remote.

#include <Arduino.h>
#include <esp_now.h>
#include <math.h>

#include "tempore_world.h"

namespace {

const double degree = PI / 180;

bool within(double t, double start, double length) {
  return t >= start && t < start + length;
}

}  // namespace

void world_start(tempore_world &w) { w.accel_given = true; }

void world_advance(tempore_world &w, double) {
  const double t = w.time;
  const double pitch = t < 0.9                ? 0
                       : within(t, 2.2, 0.8)  ? 30
                       : within(t, 3.0, 0.5)  ? 0
                                              : 10;
  const double roll = within(t, 3.0, 0.5) ? 15 : 0;
  w.accel[0] = -sin(roll * degree);
  w.accel[1] = -sin(pitch * degree) * cos(roll * degree);
  w.accel[2] = cos(pitch * degree) * cos(roll * degree);
  const bool arm = within(t, 1.0, 0.1), disarm = within(t, 4.6, 0.1);
  w.touched = arm || disarm;
  w.touch[0] = arm ? 78 : 242;
  w.touch[1] = 208;
}

bool esp_now_model_peer(uint32_t time_ms, uint32_t *tag, float *first,
                        float *second) {
  enum : uint32_t { ready = 0, armed = 1, calibrating = 2, unsettled = 3 };
  if ((time_ms >= 3800 && time_ms < 4200) || time_ms >= 7600) return false;
  const uint32_t phase = time_ms < 1500   ? ready
                         : time_ms < 4900 ? armed
                         : time_ms < 5600 ? calibrating
                         : time_ms < 6300 ? unsettled
                         : time_ms < 7000 ? calibrating
                                          : ready;
  *tag = 5;
  *first = static_cast<float>(phase);
  *second = phase != armed ? 0.0f : time_ms < 3800 ? 2.5f : 1.5f;
  return true;
}
