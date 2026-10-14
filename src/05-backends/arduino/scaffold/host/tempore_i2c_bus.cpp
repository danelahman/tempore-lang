// The I2C buses of a host simulation and their device models.

#include <Arduino.h>
#include <Wire.h>

#include <vector>

#include "tempore_i2c_model.h"
#include "tempore_scaffold.h"

#ifndef TEMPORE_I2C_MODEL_PHASE_US
#define TEMPORE_I2C_MODEL_PHASE_US 110
#endif

namespace {

struct attached {
  TwoWire *bus;
  uint8_t address;
  tempore_i2c_device *device;
};

std::vector<attached> &devices() {
  static std::vector<attached> list;
  return list;
}

tempore_i2c_device *find(TwoWire *bus, int address) {
  for (const attached &a : devices())
    if (a.bus == bus && a.address == address) return a.device;
  return nullptr;
}

#ifdef TEMPORE_TRACE
// The bytes data as hexadecimal text.
void hex(char *text, size_t size, const uint8_t *data, size_t length) {
  size_t used = 0;
  text[0] = '\0';
  for (size_t i = 0; i < length && used + 4 < size; ++i)
    used += static_cast<size_t>(
        snprintf(text + used, size - used, " %02x", data[i]));
}
#endif

}  // namespace

void tempore_i2c_attach(TwoWire &bus, uint8_t address,
                        tempore_i2c_device &device) {
  devices().push_back({&bus, address, &device});
}

bool TwoWire::begin(int, int, uint32_t frequency) {
  frequency_ = frequency;
  return true;
}

void TwoWire::setClock(uint32_t frequency) { frequency_ = frequency; }

void TwoWire::beginTransmission(int address) {
  address_ = address;
  sent_length_ = 0;
}

size_t TwoWire::write(uint8_t byte) {
  if (sent_length_ == capacity) return 0;
  sent_[sent_length_++] = byte;
  return 1;
}

size_t TwoWire::write(const uint8_t *data, size_t length) {
  size_t n = 0;
  while (n < length && write(data[n]) == 1) ++n;
  return n;
}

void TwoWire::elapse(uint64_t bits) {
  const uint64_t total = pending_bits_ + bits;
  const uint32_t phases = pending_phases_ + 1;
  pending_bits_ = 0;
  pending_phases_ = 0;
  delayMicroseconds(
      static_cast<uint32_t>((total * 1000000 + frequency_ - 1) / frequency_) +
      phases * TEMPORE_I2C_MODEL_PHASE_US);
}

uint8_t TwoWire::endTransmission(bool stop) {
  tempore_i2c_device *device = find(this, address_);
#ifdef TEMPORE_TRACE
  char text[3 * capacity + 1];
  hex(text, sizeof text, sent_, sent_length_);
  tempore_trace("I2C 0x%02x write%s%s", address_, text,
                device == nullptr ? ": not acknowledged" : "");
#endif
  if (device != nullptr) device->receive(sent_, sent_length_);
  const uint64_t bits = 9 * (1 + (device != nullptr ? sent_length_ : 0));
  if (stop || device == nullptr)
    elapse(bits);
  else {
    pending_bits_ += bits;
    ++pending_phases_;
  }
  return device != nullptr ? 0 : 2;
}

uint8_t TwoWire::requestFrom(int address, int quantity) {
  tempore_i2c_device *device = find(this, address);
  const size_t wanted =
      quantity < 0 ? 0
                   : (static_cast<size_t>(quantity) < capacity
                          ? static_cast<size_t>(quantity)
                          : capacity);
  received_length_ =
      device != nullptr ? device->transmit(received_, wanted) : 0;
  received_position_ = 0;
#ifdef TEMPORE_TRACE
  char text[3 * capacity + 1];
  hex(text, sizeof text, received_, received_length_);
  tempore_trace("I2C 0x%02x read%s%s", address, text,
                device == nullptr ? ": not acknowledged" : "");
#endif
  elapse(9 * (1 + received_length_));
  return static_cast<uint8_t>(received_length_);
}


int TwoWire::read() {
  return received_position_ < received_length_
             ? received_[received_position_++]
             : -1;
}

void tempore_i2c_registers::receive(const uint8_t *data, size_t length) {
  if (length == 0) return;
  pointer_ = data[0];
  const uint8_t first = pointer_;
  for (size_t i = 1; i < length; ++i) registers[pointer_++] = data[i];
  if (length > 1) written(first, length - 1);
}

size_t tempore_i2c_registers::transmit(uint8_t *data, size_t length) {
  reading(pointer_, length);
  for (size_t i = 0; i < length; ++i) data[i] = registers[pointer_++];
  return length;
}

void tempore_i2c_registers::written(uint8_t, size_t) {}

void tempore_i2c_registers::reading(uint8_t, size_t) {}
