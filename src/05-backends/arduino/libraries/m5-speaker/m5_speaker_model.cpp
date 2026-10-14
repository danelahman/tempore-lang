// The host model of the speaker of an M5Stack core: each tone is logged, and
// starting it takes 50 microseconds.

#include <Arduino.h>
#include <M5Unified.h>

#include "tempore_scaffold.h"

bool tempore_m5_speaker::tone(float frequency, uint32_t duration) {
  delayMicroseconds(50);
  tempore_log("Speaker: %u Hz for %u ms", static_cast<unsigned>(frequency),
              static_cast<unsigned>(duration));
  return true;
}
