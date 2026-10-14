#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void tempore_fault(const char *message) {
  fflush(stdout);
  fprintf(stderr, "Run-time error: %s\n", message);
  exit(1);
}

void tempore_delay(uint32_t, uint32_t) {}

inline void tempore_print_nat(uint32_t v, bool) {
  printf("%lu", static_cast<unsigned long>(v));
}

inline void tempore_print_int(int32_t v, bool) {
  printf("%ldi", static_cast<long>(v));
}

inline void tempore_print_bool(bool v, bool) { printf("%s", v ? "true" : "false"); }

// A float as OCaml's format %F prints it.
inline void tempore_print_float(float v, bool) {
  const double d = v;
  if (isnan(d)) {
    printf("nan");
  } else if (isinf(d)) {
    printf("%s", d > 0 ? "infinity" : "neg_infinity");
  } else {
    char buffer[32];
    snprintf(buffer, sizeof buffer, "%.12g", d);
    printf("%s%s", buffer, strpbrk(buffer, ".e") ? "" : ".");
  }
}

inline void tempore_print(tempore_unit, bool) { printf("()"); }
