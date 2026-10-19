// The part of ESP-NOW of ESP-IDF that the package esp-now uses, on the host,
// implemented by esp_now_link_model.cpp, with the peer of the host model.

#ifndef TEMPORE_HOST_ESP_NOW_H
#define TEMPORE_HOST_ESP_NOW_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#include "esp_wifi.h"

#define ESP_NOW_KEY_LEN 16

typedef enum {
  ESP_NOW_SEND_SUCCESS = 0,
  ESP_NOW_SEND_FAIL
} esp_now_send_status_t;

typedef struct {
  uint8_t peer_addr[6];
  uint8_t lmk[ESP_NOW_KEY_LEN];
  uint8_t channel;
  wifi_interface_t ifidx;
  bool encrypt;
} esp_now_peer_info_t;

typedef void (*esp_now_recv_cb_t)(const uint8_t *mac_addr, const uint8_t *data,
                                  int data_len);
typedef void (*esp_now_send_cb_t)(const uint8_t *mac_addr,
                                  esp_now_send_status_t status);

esp_err_t esp_now_init();
esp_err_t esp_now_set_pmk(const uint8_t *pmk);
esp_err_t esp_now_add_peer(const esp_now_peer_info_t *peer);

// Registers the callback of reception and starts the peer of the host model.
esp_err_t esp_now_register_recv_cb(esp_now_recv_cb_t callback);

esp_err_t esp_now_register_send_cb(esp_now_send_cb_t callback);

// Logs the packet and calls the callback of sending with success; takes 100
// microseconds.
esp_err_t esp_now_send(const uint8_t *peer_addr, const uint8_t *data,
                       size_t len);

// The packets of the peer of the host model, defined weakly to send none,
// which the host model of an application may define. Every
// ESP_NOW_MODEL_PERIOD_MS milliseconds (default 20) of simulated time from
// the registration of the callback of reception, it is called with the time
// in milliseconds and returns whether the peer then sends a packet, of the
// tag and the floats it sets. The packet arrives ESP_NOW_MODEL_LATENCY_MS
// milliseconds later (default 2, below the period), from the address
// ESP_NOW_PEER, or 24:0A:C4:00:00:02 if that is the broadcast address, and
// every ESP_NOW_MODEL_LOSS-th packet is lost (never by default, 0).
bool esp_now_model_peer(uint32_t time_ms, uint32_t *tag, float *first,
                        float *second);

#endif
