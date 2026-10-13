// The part of M5Unified that the scaffold and the packages use, on the host.
// The initialisation does nothing; the inertial measurement unit and the
// display are defined by the host models of the packages that use them.

#ifndef TEMPORE_HOST_M5UNIFIED_H
#define TEMPORE_HOST_M5UNIFIED_H

#include <stddef.h>
#include <stdint.h>

struct tempore_m5_config {};

namespace m5 {

// The components of a reading along the x, y and z axes.
struct imu_3d_t {
  float x, y, z;
};

// The readings of an update: the acceleration in g, the angular rate in
// degrees per second and the magnetic field, which the host does not model.
struct imu_data_t {
  uint32_t usec;
  imu_3d_t accel, gyro, mag;
};

}  // namespace m5

// The inertial measurement unit: update reads the sensors and getImuData
// gives the readings of the last update; the frequency of its bus is
// ignored.
class tempore_m5_imu {
 public:
  void setClock(uint32_t) {}
  int update();
  void getImuData(m5::imu_data_t *data);

 private:
  float accel[3] = {0, 0, 0};
  float gyro[3] = {0, 0, 0};
};

// The display, written line by line.
class tempore_m5_display {
 public:
  void setTextSize(float size);
  void setCursor(int32_t x, int32_t y);
  void clear();
  size_t println(const char *text);
};

class tempore_m5_unified {
 public:
  tempore_m5_config config() { return {}; }
  void begin(tempore_m5_config) {}
  void update() {}
  tempore_m5_imu Imu;
  tempore_m5_display Display;
};

extern tempore_m5_unified M5;

#endif
