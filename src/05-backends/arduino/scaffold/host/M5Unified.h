// The part of M5Unified that the scaffold and the packages use, on the host.
// The initialisation does nothing; the display is defined by
// tempore_m5_display.cpp, and the inertial measurement unit, the touch screen
// and the speaker by the host models of the packages that use them.

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

// A point of the touch screen, in pixels, and whether it is touched.
struct touch_detail_t {
  int16_t x, y;
  bool pressed;
  bool isPressed() const { return pressed; }
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
  // Sets the output data rate of the accelerometer, in hertz; the host model
  // logs it.
  void configureAccel(uint32_t rate);

 private:
  float accel[3] = {0, 0, 0};
  float gyro[3] = {0, 0, 0};
};

// The display, written line by line or at a position, with rectangles and
// circles; colours are of 24 bits, 0xRRGGBB. The text is in a font of 6 by 8
// pixels scaled by the text size.
class tempore_m5_display {
 public:
  void setTextSize(float size);
  void setCursor(int32_t x, int32_t y);
  void setTextColor(uint32_t foreground, uint32_t background);
  int32_t getCursorX() const { return cursor_x; }
  int32_t getCursorY() const { return cursor_y; }
  float getTextSizeX() const { return text_size; }
  int32_t width() const { return 320; }
  int32_t height() const { return 240; }
  int32_t textWidth(const char *text) const;
  int32_t fontHeight() const;
  void fillRect(int32_t x, int32_t y, int32_t w, int32_t h, uint32_t color);
  void fillRoundRect(int32_t x, int32_t y, int32_t w, int32_t h, int32_t r,
                     uint32_t color);
  void drawRoundRect(int32_t x, int32_t y, int32_t w, int32_t h, int32_t r,
                     uint32_t color);
  void fillCircle(int32_t x, int32_t y, int32_t r, uint32_t color);
  void drawCircle(int32_t x, int32_t y, int32_t r, uint32_t color);
  void clear();
  size_t print(const char *text);
  size_t println(const char *text);

 private:
  float text_size = 1;
  int32_t cursor_x = 0;
  int32_t cursor_y = 0;
};

// The touch screen: update reads the touch controller, getCount gives the
// number of points touched and getDetail the first of them.
class tempore_m5_touch {
 public:
  void update(uint32_t msec);
  uint8_t getCount() const { return detail.pressed ? 1 : 0; }
  const m5::touch_detail_t &getDetail(size_t = 0) const { return detail; }

 private:
  m5::touch_detail_t detail = {0, 0, false};
};

// The speaker: tone starts a tone of the given frequency, in hertz, and
// duration, in milliseconds, and returns at once.
class tempore_m5_speaker {
 public:
  bool begin() { return true; }
  bool tone(float frequency, uint32_t duration);
};

class tempore_m5_unified {
 public:
  tempore_m5_config config() { return {}; }
  void begin(tempore_m5_config) {}
  void update() {}
  tempore_m5_imu Imu;
  tempore_m5_display Display;
  tempore_m5_touch Touch;
  tempore_m5_speaker Speaker;
};

extern tempore_m5_unified M5;

#endif
