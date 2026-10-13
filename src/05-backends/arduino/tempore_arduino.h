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

inline int tempore_compare_int(int32_t a, int32_t b) {
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

// The natural number of a float, truncated toward zero and reduced modulo
// 2^32; zero for a negative float and for NaN, and a run-time error for
// infinity.
inline uint32_t tempore_nat_of_float(float x) {
  if (!(x > 0.0f)) return 0;
  if (x == INFINITY) tempore_fault("Conversion of infinity to a natural number");
  return static_cast<uint32_t>(fmodf(truncf(x), 4294967296.0f));
}

// The integer of 32 bits in two's complement of the bits a, as a natural
// number of 32 bits: a reduced modulo 2^32 into [-2^31, 2^31).
inline int32_t tempore_int_of_bits(uint32_t a) {
  return a < 0x80000000u ? static_cast<int32_t>(a)
                         : static_cast<int32_t>(a - 0x80000000u) + INT32_MIN;
}

// Arithmetic on integers modulo 2^32, computed on natural numbers of 32 bits,
// whose overflow is defined.
inline int32_t tempore_int_add(int32_t a, int32_t b) {
  return tempore_int_of_bits(static_cast<uint32_t>(a) + static_cast<uint32_t>(b));
}

inline int32_t tempore_int_sub(int32_t a, int32_t b) {
  return tempore_int_of_bits(static_cast<uint32_t>(a) - static_cast<uint32_t>(b));
}

inline int32_t tempore_int_mul(int32_t a, int32_t b) {
  return tempore_int_of_bits(static_cast<uint32_t>(a) * static_cast<uint32_t>(b));
}

inline int32_t tempore_int_neg(int32_t a) {
  return tempore_int_of_bits(0u - static_cast<uint32_t>(a));
}

// Division and modulo truncated toward zero, the remainder of the sign of the
// dividend; the quotient of INT32_MIN by -1 is INT32_MIN, modulo 2^32.
inline int32_t tempore_int_div(int32_t a, int32_t b) {
  if (b == 0) tempore_fault("Division by zero");
  if (b == -1) return tempore_int_neg(a);
  return a / b;
}

inline int32_t tempore_int_mod(int32_t a, int32_t b) {
  if (b == 0) tempore_fault("Modulo by zero");
  if (b == -1) return 0;
  return a % b;
}

// The natural number of an integer; zero for a negative integer.
inline uint32_t tempore_nat_of_int(int32_t a) {
  return a < 0 ? 0 : static_cast<uint32_t>(a);
}

// The integer of a float, truncated toward zero and reduced modulo 2^32 into
// [-2^31, 2^31); zero for NaN, and a run-time error for infinity.
inline int32_t tempore_int_of_float(float x) {
  if (x != x) return 0;
  if (x == INFINITY || x == -INFINITY)
    tempore_fault("Conversion of infinity to an integer");
  const float t = fmodf(truncf(x), 4294967296.0f);
  const uint32_t m = static_cast<uint32_t>(fabsf(t));
  return tempore_int_of_bits(t < 0.0f ? 0u - m : m);
}

#endif
