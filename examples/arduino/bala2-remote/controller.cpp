// The host model of the controller of balance_remote.tpe: the peer of the
// host model of the package esp-now, which sends a message every 20 ms of
// simulated time. It sends Beat until 1.5 s, Arm for 1 s, Drive (100, 0)
// until 3.5 s, Disarm until 3.6 s, Beat until 5 s, Arm for 1 s,
// Drive (-100, 0) until 6.3 s, nothing until 8.8 s, a loss of the link, and
// then Beat again. The tags are those of the package bala2-remote. The
// status packets of the robot are logged by the host model of esp-now.

#include <esp_now.h>

namespace {

enum : uint32_t { arm = 1, drive = 2, disarm = 3, beat = 4, none = 0 };

struct phase {
  uint32_t until_ms, tag;
  float speed;
};

const phase script[] = {{1500, beat, 0},  {2500, arm, 0},
                        {3500, drive, 100}, {3600, disarm, 0},
                        {5000, beat, 0},  {6000, arm, 0},
                        {6300, drive, -100}, {8800, none, 0},
                        {UINT32_MAX, beat, 0}};

}  // namespace

bool esp_now_model_peer(uint32_t time_ms, uint32_t *tag, float *first,
                        float *second) {
  for (const phase &p : script)
    if (time_ms < p.until_ms) {
      if (p.tag == none) return false;
      *tag = p.tag;
      *first = p.speed;
      *second = 0;
      return true;
    }
  return false;
}
