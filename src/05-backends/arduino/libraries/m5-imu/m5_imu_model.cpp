// The host model of the inertial measurement unit of an M5Stack core: the
// readings of a unit whose x axis is the axis of the tilt of the world, from
// the state of the world, without noise. A read takes 383 microseconds, the
// transfer of 17 bytes over an I2C bus at 400 kHz.

#include <Arduino.h>
#include <M5Unified.h>
#include <math.h>

#include "tempore_scaffold.h"
#include "tempore_world.h"

static const double m5_imu_degrees = 180.0 / 3.14159265358979323846;

int tempore_m5_imu::update() {
  delayMicroseconds(383);
  const tempore_world &w = tempore_world_now();
  accel[0] = 0.0f;
  accel[1] = static_cast<float>(sin(w.tilt));
  accel[2] = static_cast<float>(cos(w.tilt));
  gyro[0] = static_cast<float>(w.tilt_rate * m5_imu_degrees);
  gyro[1] = 0.0f;
  gyro[2] = 0.0f;
  tempore_trace("IMU accel %.3f %.3f %.3f g, gyro %.2f %.2f %.2f deg/s",
                accel[0], accel[1], accel[2], gyro[0], gyro[1], gyro[2]);
  return 1;
}

bool tempore_m5_imu::getAccel(float *x, float *y, float *z) {
  *x = accel[0];
  *y = accel[1];
  *z = accel[2];
  return true;
}

bool tempore_m5_imu::getGyro(float *x, float *y, float *z) {
  *x = gyro[0];
  *y = gyro[1];
  *z = gyro[2];
  return true;
}
