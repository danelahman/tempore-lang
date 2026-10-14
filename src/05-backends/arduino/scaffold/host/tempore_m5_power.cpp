// The host model of the power management of an M5Stack core: a battery
// charged to 87 percent that does not charge. Each reading is a read of a
// register of the power management unit on the internal I2C bus, which takes
// 100 microseconds.

#include <Arduino.h>
#include <M5Unified.h>

int32_t m5::Power_Class::getBatteryLevel() {
  delayMicroseconds(100);
  return 87;
}

m5::Power_Class::is_charging_t m5::Power_Class::isCharging() {
  delayMicroseconds(100);
  return is_discharging;
}
