// The package esp-now: the format of its packets, the sending of a packet,
// and the counts of the packets of the link, for logging by the application
// outside its timed bindings. Each count is read atomically; the counts of
// one reading may come from different moments.

#ifndef ESP_NOW_LINK_H
#define ESP_NOW_LINK_H

#include <stddef.h>
#include <stdint.h>

// The length of a packet, in bytes.
const size_t esp_now_link_packet_size = 16;

// Writes the packet of a tag and two floats to bytes.
void esp_now_link_encode(uint32_t tag, float first, float second,
                         uint8_t bytes[esp_now_link_packet_size]);

// Queues the packet of a tag and two floats to the peer, as Send does: a
// run-time error before LinkStart, and dropped and counted if the radio
// cannot queue it. For the bindings of other packages.
void esp_now_link_send(uint32_t tag, float first, float second);

struct esp_now_link_counts {
  uint32_t queued;     // packets queued by Send
  uint32_t dropped;    // packets Send could not queue
  uint32_t failed;     // packets queued whose transmission failed
  uint32_t received;   // packets received from the peer
  uint32_t discarded;  // packets discarded on reception
};

// The counts since start-up.
esp_now_link_counts esp_now_link_read_counts();

#endif
