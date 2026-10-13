// The host model of the inertial measurement unit of an M5Stack core: the
// readings of a unit whose x axis is the axis of the tilt of the world and
// whose y axis that of its roll, from the state of the world, without noise:
// the acceleration is the load of the world along the vertical, and the
// gyroscope reads the rate of the tilt. A read takes 603 microseconds, the
// time of a read of 14 bytes on the host model of an I2C bus at 400 kHz: the
// transfer of 17 bytes and two address phases. A reconfiguration takes 200
// microseconds and is logged.

#include <Arduino.h>
#include <M5Unified.h>
#include <math.h>

#include "tempore_scaffold.h"
#include "tempore_world.h"

static const double m5_imu_degrees = 180.0 / 3.14159265358979323846;

int tempore_m5_imu::update() {
  delayMicroseconds(603);
  const tempore_world &w = tempore_world_now();
  accel[0] = static_cast<float>(w.load * sin(w.roll));
  accel[1] = static_cast<float>(w.load * sin(w.tilt) * cos(w.roll));
  accel[2] = static_cast<float>(w.load * cos(w.tilt) * cos(w.roll));
  gyro[0] = static_cast<float>(w.tilt_rate * m5_imu_degrees);
  gyro[1] = 0.0f;
  gyro[2] = 0.0f;
  tempore_trace("IMU accel %.3f %.3f %.3f g, gyro %.2f %.2f %.2f deg/s",
                accel[0], accel[1], accel[2], gyro[0], gyro[1], gyro[2]);
  return 1;
}

void tempore_m5_imu::getImuData(m5::imu_data_t *data) {
  data->usec = 0;
  data->accel = {accel[0], accel[1], accel[2]};
  data->gyro = {gyro[0], gyro[1], gyro[2]};
  data->mag = {0.0f, 0.0f, 0.0f};
}

void tempore_m5_imu::configureAccel(uint32_t rate) {
  delayMicroseconds(200);
  tempore_log("IMU: accelerometer at %u Hz", static_cast<unsigned>(rate));
}
