// The I2C buses of the Arduino API on the host: buses without devices.

#ifndef TEMPORE_HOST_WIRE_H
#define TEMPORE_HOST_WIRE_H

#include <stdint.h>

class TwoWire {
 public:
  bool begin(int, int, uint32_t) { return true; }
};

extern TwoWire Wire;
extern TwoWire Wire1;

#endif
