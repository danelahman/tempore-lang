// The device models of the I2C buses of a host simulation.

#ifndef TEMPORE_HOST_I2C_MODEL_H
#define TEMPORE_HOST_I2C_MODEL_H

#include <Wire.h>
#include <stddef.h>
#include <stdint.h>

// A device on a bus.
class tempore_i2c_device {
 public:
  virtual ~tempore_i2c_device() = default;
  // Receives the bytes of a transmission to the device.
  virtual void receive(const uint8_t *data, size_t length) = 0;
  // Writes at most length bytes requested from the device to data; the number
  // written.
  virtual size_t transmit(uint8_t *data, size_t length) = 0;
};

// Attaches device at the 7-bit address on bus.
void tempore_i2c_attach(TwoWire &bus, uint8_t address,
                        tempore_i2c_device &device);

// The attachment of a device by the construction of a static object.
struct tempore_i2c_attachment {
  tempore_i2c_attachment(TwoWire &bus, uint8_t address,
                         tempore_i2c_device &device) {
    tempore_i2c_attach(bus, address, device);
  }
};

// A device of 256 registers of 8 bits with an address pointer: the first byte
// of a transmission sets the pointer, and the following bytes are written to
// the registers from it on; a request reads the registers from the pointer on.
// The pointer advances by each byte written or read. A subclass observes the
// registers written by written and updates those to be read by reading.
class tempore_i2c_registers : public tempore_i2c_device {
 public:
  void receive(const uint8_t *data, size_t length) override;
  size_t transmit(uint8_t *data, size_t length) override;

 protected:
  uint8_t registers[256] = {};
  // Called after length registers from first on have been written.
  virtual void written(uint8_t first, size_t length);
  // Called before length registers from first on are read.
  virtual void reading(uint8_t first, size_t length);

 private:
  uint8_t pointer_ = 0;
};

#endif
