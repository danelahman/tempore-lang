// The peer of a host model of an application: in its first five periods it
// sends the packets of Start, Drive (0.5, -0.25), a packet of the unknown tag
// 9, Stop and Beat, in this order, and then nothing.

#include <esp_now.h>

bool esp_now_model_peer(uint32_t, uint32_t *tag, float *first,
                        float *second) {
  static uint32_t sent = 0;
  static const uint32_t tags[] = {1, 2, 9, 3, 4};
  if (sent == sizeof tags / sizeof tags[0]) return false;
  *tag = tags[sent++];
  *first = *tag == 2 ? 0.5f : 0.0f;
  *second = *tag == 2 ? -0.25f : 0.0f;
  return true;
}
