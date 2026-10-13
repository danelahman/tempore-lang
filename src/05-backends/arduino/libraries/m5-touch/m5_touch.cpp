// The package m5-touch: the touch screen of an M5Stack core, through
// M5Unified. A reading updates the touch state of M5Unified alone, by
// M5.Touch.update, without the buttons and the power management of
// M5.update, under the I2C lock, since the touch controller of the CoreS3 and
// the Core2 is on the internal bus. M5Unified reads the controller at most
// once every 4 ms and otherwise keeps the last state.

#include <Arduino.h>
#include <M5Unified.h>

#include "tempore_bindings.h"

#ifdef TEMPORE_PERFORMS_Touched
tempore_result_Touched binding_Touched(tempore_argument_Touched) {
  tempore_i2c_lock();
  M5.Touch.update(millis());
  tempore_i2c_unlock();
  if (M5.Touch.getCount() == 0) return {false, 0, 0};
  const auto &point = M5.Touch.getDetail();
  if (!point.isPressed()) return {false, 0, 0};
  return {true, static_cast<uint32_t>(point.x < 0 ? 0 : point.x),
          static_cast<uint32_t>(point.y < 0 ? 0 : point.y)};
}
#endif
