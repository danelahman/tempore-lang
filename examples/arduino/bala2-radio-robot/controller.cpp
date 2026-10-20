// The host model of the controller of robot.tpe: the peer of the
// host model of the package esp-now, which sends a message every 20 ms of
// simulated time. It sends Beat until 1.5 s, Start for 1 s, Drive (100, 0)
// until 3.5 s, Stop until 3.6 s, Beat until 6.2 s, Start for 1 s,
// Drive (-100, 0) until 7.6 s, nothing until 10 s, a loss of the link, and
// then Beat again. The tags are those of the package bala2-radio. The
// status packets of the robot are logged by the host model of esp-now. The
// user stands the robot up again at 3.8 s, after it fell at the Stop, and
// holds it still until it is started and driven.

#include <esp_now.h>

namespace {

enum : uint32_t { start = 1, drive = 2, stop = 3, beat = 4, none = 0 };

struct phase {
  uint32_t until_ms, tag;
  float speed;
};

const phase script[] = {{1500, beat, 0},  {2500, start, 0},
                        {3500, drive, 100}, {3600, stop, 0},
                        {6200, beat, 0},  {7200, start, 0},
                        {7600, drive, -100}, {10000, none, 0},
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

bool plant_stand_up(double time) { return time >= 3.8 && time < 3.9; }
