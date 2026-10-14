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
//
// A direct read that fails is a run-time error, as is an update that brings
// no new reading of the accelerometer or the gyroscope more than
// TEMPORE_IMU_STALE_MS milliseconds (default 100) after the last update that
// did; an update that brings none earlier, before the next sample of the
// unit, gives the readings of the last one.
//
// ConfigureImu sets the output data rate of the accelerometer without
// changing its range, so that the conversion of M5Unified remains valid: on
// the BMI270 by its register ACC_CONF (0x40), in the filter performance mode
// with the normal bandwidth, and on a unit of the MPU6886 family by its
// sample rate divider SMPLRT_DIV (0x19). CheckAtRest reads the unit four
// times, the readings started 6 ms apart, and checks that it is at rest.

#include <Arduino.h>
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
  m5_imu_accel_xout_h = 0x3b,
  m5_imu_smplrt_div = 0x19
};

// The address of the BMI270 and its register ACC_CONF.
enum : uint8_t { m5_imu_bmi270_address = 0x69, m5_imu_bmi270_acc_conf = 0x40 };

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

#if defined(TEMPORE_PERFORMS_ReadImu) || defined(TEMPORE_PERFORMS_CheckAtRest)
// A reading of the unit: the acceleration, in g, and the angular rate, in
// degrees per second, along the x, y and z axes.
struct m5_imu_reading {
  float accel[3];
  float gyro[3];
};

// The longest time, in milliseconds, for which an update of a unit not read
// directly may bring no new reading of its accelerometer or gyroscope, as
// when a transaction fails, longer than the period of the least output data
// rate of the units, 25 Hz.
#ifndef TEMPORE_IMU_STALE_MS
#define TEMPORE_IMU_STALE_MS 100
#endif

// The time of the last update that brought a new reading, -1 before the
// first update, under the I2C lock.
static int64_t m5_imu_updated_us = -1;

// A reading of the unit, under the I2C lock. A failed direct read, and an
// update that brings no new reading TEMPORE_IMU_STALE_MS after the last one
// that did, are run-time errors.
static inline m5_imu_reading m5_imu_read() {
#ifndef TEMPORE_HOST
  if (m5_imu_direct) {
    uint8_t data[14];
    tempore_i2c_lock();
    const bool read = M5.In_I2C.readRegister(
        m5_imu_address, m5_imu_accel_xout_h, data, sizeof data,
        m5_imu_frequency);
    tempore_i2c_unlock();
    if (!read) tempore_fault("IMU: read not acknowledged");
    int16_t raw[6];
    for (int k = 0; k < 3; ++k) {
      raw[k] = static_cast<int16_t>((data[2 * k] << 8) | data[2 * k + 1]);
      raw[3 + k] =
          static_cast<int16_t>((data[8 + 2 * k] << 8) | data[9 + 2 * k]);
    }
    return {{m5_imu_convert(0, 0, raw[0]), m5_imu_convert(0, 1, raw[1]),
             m5_imu_convert(0, 2, raw[2])},
            {m5_imu_convert(1, 0, raw[3]), m5_imu_convert(1, 1, raw[4]),
             m5_imu_convert(1, 2, raw[5])}};
  }
#endif
  m5::imu_data_t data;
  tempore_i2c_lock();
  const bool updated =
      (M5.Imu.update() & (m5::IMU_Class::sensor_mask_accel |
                          m5::IMU_Class::sensor_mask_gyro)) != 0;
  M5.Imu.getImuData(&data);
  const int64_t now = tempore_clock_us();
  const bool stale = !updated && m5_imu_updated_us >= 0 &&
                     now - m5_imu_updated_us > TEMPORE_IMU_STALE_MS * 1000LL;
  if (updated || m5_imu_updated_us < 0) m5_imu_updated_us = now;
  tempore_i2c_unlock();
  if (stale) {
    char message[64];
    snprintf(message, sizeof message, "IMU: no new reading for %d ms",
             TEMPORE_IMU_STALE_MS);
    tempore_fault(message);
  }
  return {{data.accel.x, data.accel.y, data.accel.z},
          {data.gyro.x, data.gyro.y, data.gyro.z}};
}
#endif

#ifdef TEMPORE_PERFORMS_ReadImu
tempore_result_ReadImu binding_ReadImu(tempore_argument_ReadImu) {
  const m5_imu_reading r = m5_imu_read();
  return {{r.accel[0], r.accel[1], r.accel[2]},
          {r.gyro[0], r.gyro[1], r.gyro[2]}};
}
#endif

#ifdef TEMPORE_PERFORMS_ConfigureImu
tempore_result_ConfigureImu binding_ConfigureImu(
    tempore_argument_ConfigureImu rate) {
#ifdef TEMPORE_HOST
  M5.Imu.configureAccel(rate);
#else
  if (m5_imu_direct) {
    // The sample rate of 1 kHz divided by 1 + SMPLRT_DIV: the greatest not
    // above rate, the divider rounded up, and 1000 / 256 Hz below that.
    const uint32_t divider =
        rate == 0 ? 255 : rate >= 1000 ? 0 : (1000 + rate - 1) / rate - 1;
    tempore_i2c_lock();
    M5.In_I2C.writeRegister8(m5_imu_address, m5_imu_smplrt_div,
                             static_cast<uint8_t>(divider > 255 ? 255 : divider),
                             m5_imu_frequency);
    tempore_i2c_unlock();
  } else if (M5.Imu.getType() == m5::imu_bmi270) {
    // The output data rate 25 * 2^(n - 6) Hz of the code n, from 6 (25 Hz)
    // to 12 (1600 Hz): the greatest not above rate.
    uint8_t code = 6;
    while (code < 12 && (25u << (code - 5)) <= rate) ++code;
    tempore_i2c_lock();
    M5.In_I2C.writeRegister8(m5_imu_bmi270_address, m5_imu_bmi270_acc_conf,
                             static_cast<uint8_t>(0xa0 | code),
                             m5_imu_frequency);
    tempore_i2c_unlock();
  }
#endif
  return {};
}
#endif

#ifdef TEMPORE_PERFORMS_CheckAtRest
// The interval between the starts of the readings of CheckAtRest, in
// microseconds.
static const int64_t m5_imu_check_interval_us = 6000;

// Whether the unit is at rest in four readings started 6 ms apart: the
// magnitude of the acceleration between 0.9 and 1.1 g, and that of the
// angular rate below 20 degrees per second. Each wait yields the processor
// by vTaskDelay for one tick less than the whole milliseconds left, so that
// it returns before the start of the next reading, and waits the rest by
// delayMicroseconds.
tempore_result_CheckAtRest binding_CheckAtRest(tempore_argument_CheckAtRest) {
  const int64_t start = tempore_clock_us();
  bool rest = true;
  for (int i = 0; i < 4; ++i) {
    const int64_t next = start + i * m5_imu_check_interval_us;
    const int64_t ms = (next - tempore_clock_us()) / 1000;
    if (ms > 1) vTaskDelay(pdMS_TO_TICKS(static_cast<uint32_t>(ms - 1)));
    const int64_t us = next - tempore_clock_us();
    if (us > 0) delayMicroseconds(static_cast<uint32_t>(us));
    const m5_imu_reading r = m5_imu_read();
    float a = 0, g = 0;
    for (int k = 0; k < 3; ++k) {
      a += r.accel[k] * r.accel[k];
      g += r.gyro[k] * r.gyro[k];
    }
    rest = rest && a >= 0.81f && a <= 1.21f && g < 400.0f;
  }
  return rest;
}
#endif
