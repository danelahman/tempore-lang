// The package bala2-base: the motors and the wheel encoders of the base of the
// M5Stack BALA2, an STM32 at I2C address 0x3A on the bus Wire, by its register
// map: the drives of the two motors at 0x00, two big-endian 16-bit signed
// integers from -1023 to 1023, and the counts of the two encoders at 0x10, two
// big-endian 32-bit signed integers.
//
// A watchdog task checks every BALA2_WATCHDOG_CHECK_MS milliseconds whether
// the motors are driven and no setpoint has come for BALA2_WATCHDOG_MS
// milliseconds, and then stops them. On two cores, a setpoint written while
// the watchdog stops the motors may be overwritten by the stop until the next
// setpoint.

#include <Arduino.h>
#include <Wire.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <atomic>

#include "tempore_bindings.h"

#ifndef BALA2_WATCHDOG_MS
#define BALA2_WATCHDOG_MS 200
#endif

#ifndef BALA2_WATCHDOG_CHECK_MS
#define BALA2_WATCHDOG_CHECK_MS 10
#endif

// The address of the base and of its registers.
enum : int { bala2_address = 0x3a };
enum : uint8_t { bala2_motors = 0x00, bala2_encoders = 0x10 };

// The time of the last setpoint, and whether it drives a motor.
static std::atomic<int64_t> bala2_setpoint_us{0};
static std::atomic<bool> bala2_driven{false};

// Writes the bytes data to the registers from reg on, under the I2C lock;
// whether the base acknowledged them.
static bool bala2_transmit(uint8_t reg, const uint8_t *data, size_t length) {
  Wire.beginTransmission(bala2_address);
  Wire.write(reg);
  Wire.write(data, length);
  return Wire.endTransmission() == 0;
}

// Writes the bytes data to the registers from reg on; whether the base
// acknowledged them.
static bool bala2_write(uint8_t reg, const uint8_t *data, size_t length) {
  tempore_i2c_lock();
  const bool acknowledged = bala2_transmit(reg, data, length);
  tempore_i2c_unlock();
  return acknowledged;
}

// Sets the drives of the motors, or stops them if the tasks are halted, so
// that a setpoint does not follow the stop of the safe state.
static bool bala2_set(int16_t left, int16_t right) {
  tempore_i2c_lock();
  if (tempore_halted()) left = right = 0;
  const uint8_t data[4] = {
      static_cast<uint8_t>(static_cast<uint16_t>(left) >> 8),
      static_cast<uint8_t>(left),
      static_cast<uint8_t>(static_cast<uint16_t>(right) >> 8),
      static_cast<uint8_t>(right)};
  const bool acknowledged = bala2_transmit(bala2_motors, data, sizeof data);
  tempore_i2c_unlock();
  return acknowledged;
}

// Stops the motors, logging a failure.
static void bala2_stop() {
  bala2_driven.store(false);
  if (!bala2_set(0, 0)) tempore_log("BALA2 base: the motors did not stop");
}

// A drive, from -1023 to 1023; a run-time error outside that range.
static inline int16_t bala2_drive(int32_t d) {
  if (d < -1023 || d > 1023)
    tempore_fault("BALA2 base: motor drive outside -1023 to 1023");
  return static_cast<int16_t>(d);
}

static void bala2_watchdog(void *) {
  for (;;) {
    vTaskDelay(pdMS_TO_TICKS(BALA2_WATCHDOG_CHECK_MS));
    const int64_t silent = tempore_clock_us() - bala2_setpoint_us.load();
    if (bala2_driven.load() && silent > BALA2_WATCHDOG_MS * 1000LL) {
      tempore_log("BALA2 base: no motor setpoint for %d ms; motors stopped",
                  BALA2_WATCHDOG_MS);
      bala2_stop();
    }
  }
}

void bala2_base_init() {
  bala2_stop();
  xTaskCreatePinnedToCore(bala2_watchdog, "bala2-watchdog", 3072, nullptr, 24,
                          nullptr, tskNO_AFFINITY);
}

void bala2_base_safe_state() { bala2_stop(); }

#ifdef TEMPORE_PERFORMS_SetMotors
tempore_result_SetMotors binding_SetMotors(tempore_argument_SetMotors a) {
  const int16_t left = bala2_drive(a.c0), right = bala2_drive(a.c1);
  bala2_setpoint_us.store(tempore_clock_us());
  bala2_driven.store(left != 0 || right != 0);
  if (!bala2_set(left, right))
    tempore_fault("BALA2 base: motor setpoint not acknowledged");
  return {};
}
#endif

#ifdef TEMPORE_PERFORMS_ReadEncoders
tempore_result_ReadEncoders binding_ReadEncoders(
    tempore_argument_ReadEncoders) {
  tempore_i2c_lock();
  Wire.beginTransmission(bala2_address);
  Wire.write(static_cast<uint8_t>(bala2_encoders));
  const bool acknowledged = Wire.endTransmission(false) == 0 &&
                            Wire.requestFrom(bala2_address, 8) == 8;
  int32_t counts[2] = {0, 0};
  for (int32_t &count : counts) {
    uint32_t u = 0;
    for (int i = 0; acknowledged && i < 4; ++i)
      u = (u << 8) | static_cast<uint8_t>(Wire.read());
    count = tempore_int_of_bits(u);
  }
  tempore_i2c_unlock();
  if (!acknowledged) tempore_fault("BALA2 base: encoder read not acknowledged");
  return {counts[0], counts[1]};
}
#endif

#ifdef TEMPORE_PERFORMS_ResetEncoders
tempore_result_ResetEncoders binding_ResetEncoders(
    tempore_argument_ResetEncoders) {
  const uint8_t zeros[8] = {};
  if (!bala2_write(bala2_encoders, zeros, sizeof zeros))
    tempore_fault("BALA2 base: encoder reset not acknowledged");
  return {};
}
#endif
