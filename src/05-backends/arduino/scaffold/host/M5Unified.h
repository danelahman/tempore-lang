// The initialisation of M5Unified on the host, which does nothing.

#ifndef TEMPORE_HOST_M5UNIFIED_H
#define TEMPORE_HOST_M5UNIFIED_H

struct tempore_m5_config {};

class tempore_m5_unified {
 public:
  tempore_m5_config config() { return {}; }
  void begin(tempore_m5_config) {}
  void update() {}
};

extern tempore_m5_unified M5;

#endif
