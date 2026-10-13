// The package m5-imu: the inertial measurement unit of an M5Stack core,
// through M5Unified, read under the I2C lock, since the internal bus may share
// its controller with Wire.
//
// A unit of the MPU6886 family (MPU6886, MPU6050, MPU9250) in the axes of the
// sensor is read directly: the accelerometer, the temperature and the
// gyroscope in one transaction of 14 bytes from the register ACCEL_XOUT_H
// (0x3B) on the internal bus, converted as M5Unified converts them, with the
// full-scale ranges of the sensor and the offsets of M5Unified. Any other unit
// is read by one call of M5.Imu.update, which also reads the status of the
// sensor and the magnetometer of the board, if any, followed by
// M5.Imu.getImuData, which converts the readings of that update with the
// offsets and the axis order of M5Unified. M5.Imu.getAccel and M5.Imu.getGyro
// apply the same conversion but repeat the update when more than 256 us have
// passed since the last one; on the BMI270 of an M5Stack CoreS3 an update
// reads the status and 20 bytes of data, the magnetometer included through
// the auxiliary interface of the sensor.

#include <M5Unified.h>

#include "tempore_bindings.h"

#ifdef TEMPORE_HOST

void m5_imu_init() {}

#else

// The address of the units of the MPU6886 family, and their registers.
enum : uint8_t {
  m5_imu_address = 0x68,
  m5_imu_gyro_config = 0x1b,
  m5_imu_accel_config = 0x1c,
  m5_imu_accel_xout_h = 0x3b
};

// The frequency of the transactions with the unit, set by the member
// imu_frequency of the board profile, as for M5.Imu.setClock.
#ifndef TEMPORE_IMU_FREQUENCY
#define TEMPORE_IMU_FREQUENCY 400000
#endif

static const uint32_t m5_imu_frequency = TEMPORE_IMU_FREQUENCY;

// Whether the unit is read directly; the resolution of the accelerometer, in
// g, and of the gyroscope, in degrees per second, per unit of the readings
// shifted by 16 bits; and the offsets of M5Unified in the same units.
static bool m5_imu_direct = false;
static float m5_imu_resolution[2] = {0, 0};
static int32_t m5_imu_offset[6] = {0, 0, 0, 0, 0, 0};

// The last readings of the accelerometer and of the gyroscope.
static int16_t m5_imu_raw[6] = {0, 0, 0, 0, 0, 0};

void m5_imu_init() {
  const m5::imu_t type = M5.Imu.getType();
  m5_imu_direct = (type == m5::imu_mpu6886 || type == m5::imu_mpu6050 ||
                   type == m5::imu_mpu9250) &&
                  M5.getBoard() != m5::board_t::board_M5AtomMatrix;
  if (!m5_imu_direct) return;
  static const float accel[4] = {2.0f / 32768.0f, 4.0f / 32768.0f,
                                 8.0f / 32768.0f, 16.0f / 32768.0f};
  static const float gyro[4] = {250.0f / 32768.0f, 500.0f / 32768.0f,
                                1000.0f / 32768.0f, 2000.0f / 32768.0f};
  tempore_i2c_lock();
  const uint8_t accel_config = M5.In_I2C.readRegister8(
      m5_imu_address, m5_imu_accel_config, m5_imu_frequency);
  const uint8_t gyro_config = M5.In_I2C.readRegister8(
      m5_imu_address, m5_imu_gyro_config, m5_imu_frequency);
  tempore_i2c_unlock();
  m5_imu_resolution[0] = accel[(accel_config >> 3) & 3] * (1.0f / 65536.0f);
  m5_imu_resolution[1] = gyro[(gyro_config >> 3) & 3] * (1.0f / 65536.0f);
  for (int i = 0; i < 6; ++i) m5_imu_offset[i] = M5.Imu.getOffsetData(i);
}

// The reading r of the sensor s, 0 for the accelerometer and 1 for the
// gyroscope, along the axis j, converted.
static float m5_imu_convert(int s, int j, int16_t r) {
  const uint32_t shifted = static_cast<uint32_t>(static_cast<int32_t>(r)) << 16;
  const int32_t value = static_cast<int32_t>(
      shifted - static_cast<uint32_t>(m5_imu_offset[3 * s + j]));
  return m5_imu_resolution[s] * value;
}

#endif

#ifdef TEMPORE_PERFORMS_ReadImu
tempore_result_ReadImu binding_ReadImu(tempore_argument_ReadImu) {
#ifndef TEMPORE_HOST
  if (m5_imu_direct) {
    uint8_t data[14];
    tempore_i2c_lock();
    const bool read = M5.In_I2C.readRegister(
        m5_imu_address, m5_imu_accel_xout_h, data, sizeof data,
        m5_imu_frequency);
    tempore_i2c_unlock();
    if (read)
      for (int k = 0; k < 3; ++k) {
        m5_imu_raw[k] = static_cast<int16_t>((data[2 * k] << 8) | data[2 * k + 1]);
        m5_imu_raw[3 + k] =
            static_cast<int16_t>((data[8 + 2 * k] << 8) | data[9 + 2 * k]);
      }
    return {{m5_imu_convert(0, 0, m5_imu_raw[0]),
             m5_imu_convert(0, 1, m5_imu_raw[1]),
             m5_imu_convert(0, 2, m5_imu_raw[2])},
            {m5_imu_convert(1, 0, m5_imu_raw[3]),
             m5_imu_convert(1, 1, m5_imu_raw[4]),
             m5_imu_convert(1, 2, m5_imu_raw[5])}};
  }
#endif
  m5::imu_data_t data;
  tempore_i2c_lock();
  M5.Imu.update();
  M5.Imu.getImuData(&data);
  tempore_i2c_unlock();
  return {{data.accel.x, data.accel.y, data.accel.z},
          {data.gyro.x, data.gyro.y, data.gyro.z}};
}
#endif
