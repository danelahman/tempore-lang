// The part of the Arduino API that the scaffold and the bindings use, on the
// host, over the simulated clock of tempore_simulator.cpp.

#ifndef TEMPORE_HOST_ARDUINO_H
#define TEMPORE_HOST_ARDUINO_H

#include <math.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

// Waits for ms milliseconds of simulated time.
void delay(uint32_t ms);

// Waits for us microseconds of simulated time.
void delayMicroseconds(uint32_t us);

// The simulated time since start-up, in milliseconds and in microseconds.
unsigned long millis();
unsigned long micros();

// The serial port, written to the standard output.
class HardwareSerial {
 public:
  void begin(unsigned long) {}
  size_t print(const char *text);
  size_t println(const char *text);
  void flush();
};

extern HardwareSerial Serial;

#endif
