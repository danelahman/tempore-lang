// The package m5-imu: the inertial measurement unit of an M5Stack core,
// through M5Unified, read under the I2C lock, since the internal bus may share
// its controller with Wire.

#include <M5Unified.h>

#include "tempore_bindings.h"

#ifdef TEMPORE_PERFORMS_ReadImu
tempore_result_ReadImu binding_ReadImu(tempore_argument_ReadImu) {
  float ax = 0, ay = 0, az = 0, gx = 0, gy = 0, gz = 0;
  tempore_i2c_lock();
  M5.Imu.update();
  M5.Imu.getAccel(&ax, &ay, &az);
  M5.Imu.getGyro(&gx, &gy, &gz);
  tempore_i2c_unlock();
  return {{ax, ay, az}, {gx, gy, gz}};
}
#endif
