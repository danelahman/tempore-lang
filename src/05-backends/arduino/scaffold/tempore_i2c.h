// Register transactions with the devices on the I2C bus Wire, for the
// bindings of the packages. Each is called with the lock of the I2C buses
// held, by a tempore_i2c_guard.

#ifndef TEMPORE_I2C_H
#define TEMPORE_I2C_H

#include <Wire.h>
#include <stddef.h>
#include <stdint.h>

// Writes the length bytes of data to the registers of the device at address
// from reg on; whether the device acknowledged them.
inline bool tempore_i2c_write(int address, uint8_t reg, const uint8_t *data,
                              size_t length) {
  Wire.beginTransmission(address);
  Wire.write(reg);
  Wire.write(data, length);
  return Wire.endTransmission() == 0;
}

// Reads length bytes into data from the registers of the device at address
// from reg on, by a write of reg without a stop followed by a request;
// whether the device acknowledged both.
inline bool tempore_i2c_read(int address, uint8_t reg, uint8_t *data,
                             int length) {
  Wire.beginTransmission(address);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0 ||
      Wire.requestFrom(address, length) != length)
    return false;
  for (int i = 0; i < length; ++i) data[i] = static_cast<uint8_t>(Wire.read());
  return true;
}

#endif
