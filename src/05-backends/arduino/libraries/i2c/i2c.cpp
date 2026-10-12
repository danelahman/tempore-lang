// The package i2c: register transactions with devices on the I2C bus Wire,
// each under the lock of the I2C buses of the scaffold.

#include <Arduino.h>
#include <Wire.h>

#include "tempore_bindings.h"

// Checks the addresses of a device and of a register.
static inline void i2c_check(uint32_t device, uint32_t reg) {
  if (device > 0x7f) tempore_fault("I2C: device address beyond 7 bits");
  if (reg > 0xff) tempore_fault("I2C: register address beyond 8 bits");
}

// Writes the bytes big-endian of the value, modulo 2^(8 * bytes), to the
// registers of device from reg on.
static inline void i2c_write(uint32_t device, uint32_t reg, uint32_t value,
                             int bytes) {
  i2c_check(device, reg);
  tempore_i2c_lock();
  Wire.beginTransmission(static_cast<int>(device));
  Wire.write(static_cast<uint8_t>(reg));
  for (int i = bytes - 1; i >= 0; --i)
    Wire.write(static_cast<uint8_t>(value >> (8 * i)));
  const bool acknowledged = Wire.endTransmission() == 0;
  tempore_i2c_unlock();
  if (!acknowledged) tempore_fault("I2C: write not acknowledged");
}

// Reads bytes big-endian from the registers of device from reg on.
static inline uint32_t i2c_read(uint32_t device, uint32_t reg, int bytes) {
  i2c_check(device, reg);
  tempore_i2c_lock();
  Wire.beginTransmission(static_cast<int>(device));
  Wire.write(static_cast<uint8_t>(reg));
  const bool acknowledged =
      Wire.endTransmission(false) == 0 &&
      Wire.requestFrom(static_cast<int>(device), bytes) == bytes;
  uint32_t value = 0;
  for (int i = 0; acknowledged && i < bytes; ++i)
    value = (value << 8) | static_cast<uint8_t>(Wire.read());
  tempore_i2c_unlock();
  if (!acknowledged) tempore_fault("I2C: read not acknowledged");
  return value;
}

#ifdef TEMPORE_PERFORMS_I2cWrite8
tempore_result_I2cWrite8 binding_I2cWrite8(tempore_argument_I2cWrite8 a) {
  i2c_write(a.c0, a.c1, a.c2, 1);
  return {};
}
#endif

#ifdef TEMPORE_PERFORMS_I2cWrite16
tempore_result_I2cWrite16 binding_I2cWrite16(tempore_argument_I2cWrite16 a) {
  i2c_write(a.c0, a.c1, a.c2, 2);
  return {};
}
#endif

#ifdef TEMPORE_PERFORMS_I2cWrite32
tempore_result_I2cWrite32 binding_I2cWrite32(tempore_argument_I2cWrite32 a) {
  i2c_write(a.c0, a.c1, a.c2, 4);
  return {};
}
#endif

#ifdef TEMPORE_PERFORMS_I2cRead8
tempore_result_I2cRead8 binding_I2cRead8(tempore_argument_I2cRead8 a) {
  return i2c_read(a.c0, a.c1, 1);
}
#endif

#ifdef TEMPORE_PERFORMS_I2cRead16
tempore_result_I2cRead16 binding_I2cRead16(tempore_argument_I2cRead16 a) {
  return i2c_read(a.c0, a.c1, 2);
}
#endif

#ifdef TEMPORE_PERFORMS_I2cRead32
tempore_result_I2cRead32 binding_I2cRead32(tempore_argument_I2cRead32 a) {
  return i2c_read(a.c0, a.c1, 4);
}
#endif
