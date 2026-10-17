// The host model of the controller of balance_remote.tpe: the peer of the
// host model of the package esp-now, which sends a message every 20 ms of
// simulated time. It sends Beat until 1.5 s, Arm until 1.6 s, Drive (100, 0)
// until 3 s, Disarm until 3.1 s, Beat until 4.7 s, Arm until 4.8 s,
// Drive (-100, 0) until 5.3 s, and then nothing. The tags are those of the
// package bala2-remote.

#include <esp_now.h>

namespace {

enum : uint32_t { arm = 1, drive = 2, disarm = 3, beat = 4 };

struct phase {
  uint32_t until_ms, tag;
  float speed;
};

const phase script[] = {{1500, beat, 0},     {1600, arm, 0},
                        {3000, drive, 100},  {3100, disarm, 0},
                        {4700, beat, 0},     {4800, arm, 0},
                        {5300, drive, -100}};

}  // namespace

bool esp_now_model_peer(uint32_t time_ms, uint32_t *tag, float *first,
                        float *second) {
  for (const phase &p : script)
    if (time_ms < p.until_ms) {
      *tag = p.tag;
      *first = p.speed;
      *second = 0;
      return true;
    }
  return false;
}
