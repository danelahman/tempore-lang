// The I2C buses of the Arduino API on the host, on which the device models of
// tempore_i2c_model.h answer at their addresses.
//
// A transaction takes the simulated time of its bits at the frequency of the
// bus, nine per byte, the address included, and TEMPORE_I2C_MODEL_PHASE_US
// microseconds (110 unless the build flag sets it) for each address phase:
// the time beyond the transfer of the bytes measured on an M5Stack Gray core
// at 400 kHz, 85 to 157 microseconds for a write of 6 bytes, of one phase,
// and 107 to 203 per phase for a read of 8 bytes, of two. A transmission
// ended without a stop is charged with the request that follows it, so that
// a write of a register address and the read after it take place at once for
// the other tasks. With TEMPORE_TRACE defined, each transaction is logged.

#ifndef TEMPORE_HOST_WIRE_H
#define TEMPORE_HOST_WIRE_H

#include <stddef.h>
#include <stdint.h>

class TwoWire {
 public:
  bool begin(int sda, int scl, uint32_t frequency);
  void setClock(uint32_t frequency);
  void beginTransmission(int address);
  size_t write(uint8_t byte);
  size_t write(const uint8_t *data, size_t length);
  // 0 if the device acknowledged the transmission, 2 if no device answers at
  // its address.
  uint8_t endTransmission(bool stop = true);
  // The number of bytes received, 0 if no device answers at the address.
  uint8_t requestFrom(int address, int quantity);
  int available();
  int read();

 private:
  static const size_t capacity = 128;
  uint32_t frequency_ = 100000;
  int address_ = 0;
  uint8_t sent_[capacity] = {};
  size_t sent_length_ = 0;
  uint8_t received_[capacity] = {};
  size_t received_length_ = 0;
  size_t received_position_ = 0;
  uint64_t pending_bits_ = 0;
  uint32_t pending_phases_ = 0;

  void elapse(uint64_t bits);
};

extern TwoWire Wire;
extern TwoWire Wire1;

#endif
