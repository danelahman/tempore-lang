// The runtime of programs compiled from Tempore to C++ (C++17, without heap
// allocation, exceptions or run-time type information).
//
// The scaffold of the program implements tempore_fault and tempore_delay.

#ifndef TEMPORE_ARDUINO_H
#define TEMPORE_ARDUINO_H

#include <math.h>
#include <stdint.h>

// Ends the program at a run-time error, described by message.
[[noreturn]] void tempore_fault(const char *message);

// Delays for numerator / denominator units of time of the program.
void tempore_delay(uint32_t numerator, uint32_t denominator);

// The unit value.
struct tempore_unit {};

inline int tempore_compare(tempore_unit, tempore_unit) { return 0; }

inline int tempore_compare_nat(uint32_t a, uint32_t b) {
  return a < b ? -1 : (a > b ? 1 : 0);
}

inline int tempore_compare_bool(bool a, bool b) {
  return a == b ? 0 : (a ? 1 : -1);
}

// The total order of floats in which NaN is equal to itself and below every
// other float.
inline int tempore_compare_float(float a, float b) {
  if (a < b) return -1;
  if (a > b) return 1;
  if (a == b) return 0;
  if (a != a) return b != b ? 0 : -1;
  return 1;
}

// Subtraction of natural numbers, truncated at zero.
inline uint32_t tempore_nat_sub(uint32_t a, uint32_t b) {
  return a > b ? a - b : 0;
}

inline uint32_t tempore_nat_div(uint32_t a, uint32_t b) {
  if (b == 0) tempore_fault("Division by zero");
  return a / b;
}

inline uint32_t tempore_nat_mod(uint32_t a, uint32_t b) {
  if (b == 0) tempore_fault("Modulo by zero");
  return a % b;
}

inline float tempore_float_pow(float a, float b) { return powf(a, b); }

#endif
