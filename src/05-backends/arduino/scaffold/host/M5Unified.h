// The part of M5Unified that the scaffold and the packages use, on the host.
// The initialisation does nothing; the inertial measurement unit and the
// display are defined by the host models of the packages that use them.

#ifndef TEMPORE_HOST_M5UNIFIED_H
#define TEMPORE_HOST_M5UNIFIED_H

#include <stddef.h>
#include <stdint.h>

struct tempore_m5_config {};

// The inertial measurement unit: update reads the sensors, getAccel the
// acceleration in g and getGyro the angular rate in degrees per second read
// last; the frequency of its bus is ignored.
class tempore_m5_imu {
 public:
  void setClock(uint32_t) {}
  int update();
  bool getAccel(float *x, float *y, float *z);
  bool getGyro(float *x, float *y, float *z);

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
