// The host model of the base of the M5Stack BALA2, at address 0x3A on the bus
// Wire: its registers of the motors and the encoders over the wheels of the
// world. A drive d of a motor, clamped to -1023 to 1023, sets the drive of
// its wheel to d / 1023; the count of an encoder is the angle of its wheel
// times BALA2_MODEL_COUNTS_PER_REVOLUTION / (2 pi), rounded down, less its
// value at the last write of the encoders plus the value written.

#include <Wire.h>
#include <math.h>

#include "tempore_i2c_model.h"
#include "tempore_world.h"

#ifndef BALA2_MODEL_COUNTS_PER_REVOLUTION
#define BALA2_MODEL_COUNTS_PER_REVOLUTION 420
#endif

namespace {

const uint8_t motors = 0x00;
const uint8_t encoders = 0x10;

int64_t count(double angle) {
  return static_cast<int64_t>(floor(
      angle * BALA2_MODEL_COUNTS_PER_REVOLUTION / (2 * 3.14159265358979323846)));
}

class bala2_base_model : public tempore_i2c_registers {
 protected:
  void written(uint8_t first, size_t length) override {
    tempore_world &w = tempore_world_now();
    if (first == motors && length >= 4)
      for (int i = 0; i < 2; ++i) {
        const int16_t d = static_cast<int16_t>(
            (registers[motors + 2 * i] << 8) | registers[motors + 2 * i + 1]);
        w.drive[i] = (d < -1023 ? -1023 : d > 1023 ? 1023 : d) / 1023.0;
      }
    if (first == encoders && length >= 8)
      for (int i = 0; i < 2; ++i)
        offset[i] = count(w.wheel[i]) - static_cast<int32_t>(word(encoders + 4 * i));
  }

  void reading(uint8_t first, size_t length) override {
    if (first >= encoders + 8 || first + length <= encoders) return;
    const tempore_world &w = tempore_world_now();
    for (int i = 0; i < 2; ++i) {
      const uint32_t c = static_cast<uint32_t>(count(w.wheel[i]) - offset[i]);
      for (int k = 0; k < 4; ++k)
        registers[encoders + 4 * i + k] = static_cast<uint8_t>(c >> (24 - 8 * k));
    }
  }

 private:
  int64_t offset[2] = {0, 0};

  // The big-endian 32-bit word of the registers from r on.
  uint32_t word(int r) const {
    return (static_cast<uint32_t>(registers[r]) << 24) |
           (static_cast<uint32_t>(registers[r + 1]) << 16) |
           (static_cast<uint32_t>(registers[r + 2]) << 8) | registers[r + 3];
  }
};

bala2_base_model model;
tempore_i2c_attachment attachment(Wire, 0x3a, model);

}  // namespace
