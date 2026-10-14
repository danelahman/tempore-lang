// The host model of the touch screen of an M5Stack core: the point touched in
// the world. A reading takes 300 microseconds, the time of a read of a few
// bytes on the host model of an I2C bus at 400 kHz.

#include <Arduino.h>
#include <M5Unified.h>

#include "tempore_scaffold.h"
#include "tempore_world.h"

void tempore_m5_touch::update(uint32_t) {
  delayMicroseconds(300);
  const tempore_world &w = tempore_world_now();
  detail = {static_cast<int16_t>(w.touch[0]), static_cast<int16_t>(w.touch[1]),
            w.touched};
}
