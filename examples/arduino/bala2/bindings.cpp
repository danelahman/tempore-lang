// The bindings of the operations of balance.tpe: the exchange between the
// control step and the supervision, in atomic variables, and the safe state.
//
// The supervision arms the robot with the bias of the gyroscope and commands
// a speed and a turn; a command older than BALANCE_COMMAND_MS milliseconds
// (200 unless the build flag sets it) is replaced by zero setpoints, so that
// the robot holds its position. The control step publishes the tilt and the
// rate of the gyroscope. In the safe state the robot is disarmed.
//
// Under the build flag BALANCE_SLOW_FROM_MS, the publication of the attitude
// takes 3 ms from that time on, beyond the bounds of Publish, so that its
// monitor stops the device.

#include <Arduino.h>
#include <string.h>

#include <atomic>

#include "tempore_bindings.h"

#ifndef BALANCE_COMMAND_MS
#define BALANCE_COMMAND_MS 200
#endif

static std::atomic<bool> balance_armed{false};
static std::atomic<float> balance_bias{0};
static std::atomic<float> balance_speed{0};
static std::atomic<float> balance_turn{0};
static std::atomic<int64_t> balance_command_us{0};
static std::atomic<bool> balance_expired{false};
static std::atomic<float> balance_tilt{0};
static std::atomic<float> balance_rate{0};

tempore_result_Publish binding_Publish(tempore_argument_Publish a) {
#ifdef BALANCE_SLOW_FROM_MS
  if (tempore_clock_us() >= BALANCE_SLOW_FROM_MS * 1000LL)
    tempore_elapse_us(3000);
#endif
  balance_tilt.store(a.c0);
  balance_rate.store(a.c1);
  return {};
}

tempore_result_Setpoints binding_Setpoints(tempore_argument_Setpoints) {
  const bool armed = balance_armed.load();
  const bool expired =
      armed && tempore_clock_us() - balance_command_us.load() >
                   BALANCE_COMMAND_MS * 1000LL;
  if (expired && !balance_expired.exchange(true))
    tempore_log("Supervision: no command for %d ms; setpoints zero",
                BALANCE_COMMAND_MS);
  if (!expired) balance_expired.store(false);
  return {armed, balance_bias.load(), expired ? 0.0f : balance_speed.load(),
          expired ? 0.0f : balance_turn.load()};
}

tempore_result_Attitude binding_Attitude(tempore_argument_Attitude) {
  return {balance_tilt.load(), balance_rate.load()};
}

// The bias of a calibration: the float of its only constructor, the only
// member of the union arg of its structure, whose member name the compiler
// numbers.
static float balance_bias_of(const tempore_argument_Arm &calibration) {
  float bias;
  memcpy(&bias, &calibration.arg, sizeof bias);
  return bias;
}

tempore_result_Arm binding_Arm(tempore_argument_Arm calibration) {
  const float bias = balance_bias_of(calibration);
  balance_bias.store(bias);
  balance_command_us.store(tempore_clock_us());
  balance_armed.store(true);
  tempore_log("Armed, gyroscope bias %.3f deg/s", static_cast<double>(bias));
  return {};
}

tempore_result_Disarm binding_Disarm(tempore_argument_Disarm) {
  balance_armed.store(false);
  return {};
}

tempore_result_Command binding_Command(tempore_argument_Command a) {
  balance_speed.store(a.c0);
  balance_turn.store(a.c1);
  balance_command_us.store(tempore_clock_us());
  return {};
}

void balance_safe_state() { balance_armed.store(false); }
