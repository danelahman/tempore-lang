// The peer of a host model of an application: until 160 ms it sends, every
// period of the model, a packet whose tag is the number of the period, and
// then nothing.

#include <esp_now.h>

bool esp_now_model_peer(uint32_t time_ms, uint32_t *tag, float *first,
                        float *second) {
  if (time_ms > 160) return false;
  *tag = time_ms / 20;
  *first = 0.5f;
  *second = -0.25f;
  return true;
}
