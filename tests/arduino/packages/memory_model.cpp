// The host model of a memory of 256 registers at the I2C address 0x50.

#include <Wire.h>

#include "tempore_i2c_model.h"

namespace {

tempore_i2c_registers memory;
tempore_i2c_attachment attachment(Wire, 0x50, memory);

}  // namespace
