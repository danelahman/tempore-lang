// The host model of the radio of an ESP32 under ESP-NOW: the calls of the
// Wi-Fi driver succeed, a packet sent is logged and acknowledged, and a peer
// task sends the packets of esp_now_model_peer to the callback of reception
// after the latency of the link, losing every ESP_NOW_MODEL_LOSS-th packet.

#include <Arduino.h>
#include <esp_netif.h>
#include <esp_now.h>
#include <esp_wifi.h>
#include <string.h>

#include "esp_now_link.h"
#include "tempore_scaffold.h"

#ifndef ESP_NOW_PEER
#define ESP_NOW_PEER 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
#endif

#ifndef ESP_NOW_MODEL_PERIOD_MS
#define ESP_NOW_MODEL_PERIOD_MS 20
#endif

#ifndef ESP_NOW_MODEL_LATENCY_MS
#define ESP_NOW_MODEL_LATENCY_MS 2
#endif

#ifndef ESP_NOW_MODEL_LOSS
#define ESP_NOW_MODEL_LOSS 0
#endif

static_assert(ESP_NOW_MODEL_LATENCY_MS < ESP_NOW_MODEL_PERIOD_MS,
              "the latency of the model of the link is below its period");

namespace {

const uint8_t peer[6] = {ESP_NOW_PEER};
const uint8_t own_address[6] = {0x24, 0x0a, 0xc4, 0x00, 0x00, 0x01};
const uint8_t model_address[6] = {0x24, 0x0a, 0xc4, 0x00, 0x00, 0x02};

esp_now_recv_cb_t on_receive = nullptr;
esp_now_send_cb_t on_sent = nullptr;

// The address of the peer of the model.
const uint8_t *peer_address() {
  for (uint8_t b : peer)
    if (b != 0xff) return peer;
  return model_address;
}

uint32_t word_at(const uint8_t *bytes) {
  uint32_t w = 0;
  for (int i = 3; i >= 0; --i) w = (w << 8) | bytes[i];
  return w;
}

float float_at(const uint8_t *bytes) {
  const uint32_t w = word_at(bytes);
  float x;
  memcpy(&x, &w, sizeof x);
  return x;
}

void peer_task(void *) {
  const uint32_t loss = ESP_NOW_MODEL_LOSS;
  TickType_t release = xTaskGetTickCount();
  uint32_t packets = 0;
  for (;;) {
    vTaskDelayUntil(&release, pdMS_TO_TICKS(ESP_NOW_MODEL_PERIOD_MS));
    uint32_t tag = 0;
    float first = 0, second = 0;
    if (!esp_now_model_peer(millis(), &tag, &first, &second)) continue;
    ++packets;
    if (loss > 0 && packets % loss == 0) {
      tempore_log("ESP-NOW model: packet of tag %u lost",
                  static_cast<unsigned>(tag));
      continue;
    }
    uint8_t bytes[esp_now_link_packet_size];
    esp_now_link_encode(tag, first, second, bytes);
    delay(ESP_NOW_MODEL_LATENCY_MS);
    tempore_log("ESP-NOW model: packet of tag %u arrives",
                static_cast<unsigned>(tag));
    on_receive(peer_address(), bytes, static_cast<int>(sizeof bytes));
  }
}

}  // namespace

__attribute__((weak)) bool esp_now_model_peer(uint32_t, uint32_t *, float *,
                                              float *) {
  return false;
}

esp_err_t esp_netif_init() { return ESP_OK; }
esp_err_t esp_event_loop_create_default() { return ESP_OK; }
esp_err_t esp_wifi_init(const wifi_init_config_t *) { return ESP_OK; }
esp_err_t esp_wifi_set_storage(wifi_storage_t) { return ESP_OK; }
esp_err_t esp_wifi_set_mode(wifi_mode_t) { return ESP_OK; }

esp_err_t esp_wifi_start() {
  delay(100);
  return ESP_OK;
}

esp_err_t esp_wifi_set_ps(wifi_ps_type_t) { return ESP_OK; }
esp_err_t esp_wifi_set_channel(uint8_t, wifi_second_chan_t) { return ESP_OK; }

esp_err_t esp_wifi_get_mac(wifi_interface_t, uint8_t mac[6]) {
  memcpy(mac, own_address, sizeof own_address);
  return ESP_OK;
}

esp_err_t esp_now_init() { return ESP_OK; }
esp_err_t esp_now_add_peer(const esp_now_peer_info_t *) { return ESP_OK; }

esp_err_t esp_now_register_recv_cb(esp_now_recv_cb_t callback) {
  on_receive = callback;
  xTaskCreatePinnedToCore(peer_task, "esp-now-peer", 4096, nullptr, 23,
                          nullptr, 0);
  return ESP_OK;
}

esp_err_t esp_now_register_send_cb(esp_now_send_cb_t callback) {
  on_sent = callback;
  return ESP_OK;
}

esp_err_t esp_now_send(const uint8_t *peer_addr, const uint8_t *data,
                       size_t len) {
  delayMicroseconds(100);
  if (len == esp_now_link_packet_size)
    tempore_log("ESP-NOW: sent tag %u, %.3f, %.3f",
                static_cast<unsigned>(word_at(data + 4)),
                static_cast<double>(float_at(data + 8)),
                static_cast<double>(float_at(data + 12)));
  if (on_sent != nullptr) on_sent(peer_addr, ESP_NOW_SEND_SUCCESS);
  return ESP_OK;
}
