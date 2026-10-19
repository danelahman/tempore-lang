// The package esp-now: packets between two ESP32 boards over ESP-NOW, through
// the Wi-Fi driver of ESP-IDF.
//
// LinkStart starts the network interface, the default event loop, the radio
// as a station on a channel, with its power saving off, and ESP-NOW with the
// peer ESP_NOW_PEER, in a task pinned to core 0, which it waits for, so that
// the interrupt of the radio is allocated on core 0 whatever the core of the
// caller. The callbacks of ESP-NOW run in the task of the Wi-Fi driver.
//
// A peer ESP_NOW_PEER requires the key ESP_NOW_KEY, 32 hexadecimal digits,
// and the converse: the link to the peer is then encrypted and authenticated
// by ESP-NOW with CCMP (AES-128 in counter mode with CBC-MAC), the key being
// both the primary master key and the local master key of the peer. The
// link to the broadcast address, the default, is not encrypted.
//
// A packet is 16 bytes: the bytes 'T' and 'p', the version 1, a byte 0, then
// the tag, a 32-bit unsigned integer, and the two floats, each in IEEE 754
// single precision, all little-endian. The callback of reception keeps the
// latest packet from the peer and its time of arrival under a spinlock;
// Receive copies them under the same spinlock.

#include <Arduino.h>
#include <esp_netif.h>
#include <esp_now.h>
#include <esp_wifi.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <math.h>
#include <string.h>

#include <atomic>

#include "esp_now_link.h"
#include "tempore_bindings.h"

#if defined(ESP_NOW_PEER) && !defined(ESP_NOW_KEY)
#error "the peer ESP_NOW_PEER requires the key ESP_NOW_KEY"
#endif
#if defined(ESP_NOW_KEY) && !defined(ESP_NOW_PEER)
#error "the key ESP_NOW_KEY requires the peer ESP_NOW_PEER"
#endif

#ifndef ESP_NOW_PEER
#define ESP_NOW_PEER 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
#endif

#define ESP_NOW_STRING(x) #x
#define ESP_NOW_EXPANDED_STRING(x) ESP_NOW_STRING(x)

namespace {

constexpr uint8_t peer[6] = {ESP_NOW_PEER};

// Whether the link is encrypted, and the digits of its key, empty for none.
#ifdef ESP_NOW_KEY
constexpr bool encrypted = true;
constexpr char key_digits[] = ESP_NOW_EXPANDED_STRING(ESP_NOW_KEY);
#else
constexpr bool encrypted = false;
constexpr char key_digits[] = "";
#endif

// The value of a hexadecimal digit, or -1.
constexpr int hex_value(char c) {
  return c >= '0' && c <= '9'   ? c - '0'
         : c >= 'a' && c <= 'f' ? c - 'a' + 10
         : c >= 'A' && c <= 'F' ? c - 'A' + 10
                                : -1;
}

// Whether digits are 2 * ESP_NOW_KEY_LEN hexadecimal digits.
constexpr bool valid_key(const char *digits) {
  size_t n = 0;
  for (; digits[n] != '\0'; ++n)
    if (hex_value(digits[n]) < 0) return false;
  return n == 2 * ESP_NOW_KEY_LEN;
}

// Whether the peer is the broadcast address.
constexpr bool broadcast() {
  for (uint8_t b : peer)
    if (b != 0xff) return false;
  return true;
}

static_assert(!encrypted || valid_key(key_digits),
              "the key ESP_NOW_KEY is 32 hexadecimal digits");
static_assert(!(encrypted && broadcast()),
              "the link to the broadcast address is not encrypted");

// The bytes of the key, of its digits read in pairs, most significant first.
void key_bytes(uint8_t key[ESP_NOW_KEY_LEN]) {
  for (size_t i = 0; i < ESP_NOW_KEY_LEN; ++i)
    key[i] = static_cast<uint8_t>(hex_value(key_digits[2 * i]) * 16 +
                                  hex_value(key_digits[2 * i + 1]));
}

const size_t packet_size = esp_now_link_packet_size;
const uint8_t version = 1;

struct packet {
  uint32_t tag;
  float first, second;
};

// The 32-bit words and floats of a packet, little-endian.
void put_word(uint8_t *bytes, uint32_t w) {
  for (int i = 0; i < 4; ++i) bytes[i] = static_cast<uint8_t>(w >> (8 * i));
}

uint32_t get_word(const uint8_t *bytes) {
  uint32_t w = 0;
  for (int i = 3; i >= 0; --i) w = (w << 8) | bytes[i];
  return w;
}

uint32_t float_bits(float x) {
  uint32_t w;
  memcpy(&w, &x, sizeof w);
  return w;
}

float bits_float(uint32_t w) {
  float x;
  memcpy(&x, &w, sizeof x);
  return x;
}

// Whether bytes is a packet of this format with finite floats, then in p.
bool decode(const uint8_t *bytes, int length, packet *p) {
  if (length != static_cast<int>(packet_size) || bytes[0] != 'T' ||
      bytes[1] != 'p' || bytes[2] != version)
    return false;
  p->tag = get_word(bytes + 4);
  p->first = bits_float(get_word(bytes + 8));
  p->second = bits_float(get_word(bytes + 12));
  return isfinite(p->first) && isfinite(p->second);
}

// The state of the link: not started, starting, started, or failed.
enum link_state : int { stopped, starting, started, failed };
std::atomic<int> state{stopped};
uint8_t channel = 0;
const char *failure = nullptr;

// The latest packet from the peer and its time of arrival, in microseconds.
portMUX_TYPE latest_lock = portMUX_INITIALIZER_UNLOCKED;
packet latest = {0, 0, 0};
int64_t latest_us = 0;
bool latest_valid = false;

std::atomic<uint32_t> queued{0}, dropped{0}, failed_sends{0}, received{0},
    discarded{0};

void on_receive(const uint8_t *address, const uint8_t *bytes, int length) {
  packet p;
  if ((!broadcast() && memcmp(address, peer, sizeof peer) != 0) ||
      !decode(bytes, length, &p)) {
    discarded.fetch_add(1);
    return;
  }
  const int64_t now = tempore_clock_us();
  portENTER_CRITICAL(&latest_lock);
  latest = p;
  latest_us = now;
  latest_valid = true;
  portEXIT_CRITICAL(&latest_lock);
  received.fetch_add(1);
}

void on_sent(const uint8_t *, esp_now_send_status_t status) {
  if (status != ESP_NOW_SEND_SUCCESS) failed_sends.fetch_add(1);
}

bool succeeded(esp_err_t e) { return e == ESP_OK; }

// Whether e succeeded or reports a component already initialised.
bool initialised(esp_err_t e) { return e == ESP_OK || e == ESP_ERR_INVALID_STATE; }

// Starts the radio and ESP-NOW on channel; a message on failure.
const char *begin() {
  if (!initialised(esp_netif_init()))
    return "ESP-NOW: the network interface did not start";
  if (!initialised(esp_event_loop_create_default()))
    return "ESP-NOW: the event loop did not start";
  wifi_init_config_t config = WIFI_INIT_CONFIG_DEFAULT();
  if (!succeeded(esp_wifi_init(&config)) ||
      !succeeded(esp_wifi_set_storage(WIFI_STORAGE_RAM)) ||
      !succeeded(esp_wifi_set_mode(WIFI_MODE_STA)) ||
      !succeeded(esp_wifi_start()) ||
      !succeeded(esp_wifi_set_ps(WIFI_PS_NONE)) ||
      !succeeded(esp_wifi_set_channel(channel, WIFI_SECOND_CHAN_NONE)))
    return "ESP-NOW: the radio did not start";
  if (!succeeded(esp_now_init()) ||
      !succeeded(esp_now_register_recv_cb(on_receive)) ||
      !succeeded(esp_now_register_send_cb(on_sent)))
    return "ESP-NOW: ESP-NOW did not start";
  esp_now_peer_info_t info = {};
  memcpy(info.peer_addr, peer, sizeof peer);
  info.channel = channel;
  info.ifidx = WIFI_IF_STA;
  info.encrypt = encrypted;
  if (encrypted) {
    key_bytes(info.lmk);
    if (!succeeded(esp_now_set_pmk(info.lmk)))
      return "ESP-NOW: the primary master key was not set";
  }
  if (!succeeded(esp_now_add_peer(&info)))
    return encrypted ? "ESP-NOW: the encrypted peer was not added"
                     : "ESP-NOW: the peer was not added";
  uint8_t own[6] = {};
  esp_wifi_get_mac(WIFI_IF_STA, own);
  tempore_log(
      "ESP-NOW: started on channel %u, address "
      "%02X:%02X:%02X:%02X:%02X:%02X, peer %02X:%02X:%02X:%02X:%02X:%02X, %s",
      channel, own[0], own[1], own[2], own[3], own[4], own[5], peer[0],
      peer[1], peer[2], peer[3], peer[4], peer[5],
      encrypted ? "encrypted (CCMP)" : "not encrypted");
  return nullptr;
}

void start_task(void *) {
  failure = begin();
  state.store(failure == nullptr ? started : failed);
  vTaskDelete(nullptr);
}

}  // namespace

void esp_now_link_encode(uint32_t tag, float first, float second,
                         uint8_t bytes[esp_now_link_packet_size]) {
  bytes[0] = 'T';
  bytes[1] = 'p';
  bytes[2] = version;
  bytes[3] = 0;
  put_word(bytes + 4, tag);
  put_word(bytes + 8, float_bits(first));
  put_word(bytes + 12, float_bits(second));
}

void esp_now_link_send(uint32_t tag, float first, float second) {
  if (state.load() != started) tempore_fault("ESP-NOW: Send before LinkStart");
  uint8_t bytes[packet_size];
  esp_now_link_encode(tag, first, second, bytes);
  if (esp_now_send(peer, bytes, packet_size) == ESP_OK)
    queued.fetch_add(1);
  else
    dropped.fetch_add(1);
}

esp_now_link_counts esp_now_link_read_counts() {
  return {queued.load(), dropped.load(), failed_sends.load(), received.load(),
          discarded.load()};
}

#ifdef TEMPORE_PERFORMS_LinkStart
tempore_result_LinkStart binding_LinkStart(tempore_argument_LinkStart c) {
  if (c < 1 || c > 13) tempore_fault("ESP-NOW: channel outside 1 to 13");
  int expected = stopped;
  if (!state.compare_exchange_strong(expected, starting))
    tempore_fault("ESP-NOW: LinkStart performed twice");
  channel = static_cast<uint8_t>(c);
  xTaskCreatePinnedToCore(start_task, "esp-now-start", 4096, nullptr, 2,
                          nullptr, 0);
  while (state.load() == starting) vTaskDelay(1);
  if (state.load() == failed) tempore_fault(failure);
  return encrypted;
}
#endif

#ifdef TEMPORE_PERFORMS_Send
tempore_result_Send binding_Send(tempore_argument_Send a) {
  esp_now_link_send(a.c0, a.c1, a.c2);
  return {};
}
#endif

#ifdef TEMPORE_PERFORMS_Receive
tempore_result_Receive binding_Receive(tempore_argument_Receive age_ms) {
  portENTER_CRITICAL(&latest_lock);
  const packet p = latest;
  const int64_t arrival_us = latest_us;
  const bool valid = latest_valid;
  portEXIT_CRITICAL(&latest_lock);
  if (!valid ||
      tempore_clock_us() - arrival_us > static_cast<int64_t>(age_ms) * 1000)
    return {false, 0, 0.0f, 0.0f};
  return {true, p.tag, p.first, p.second};
}
#endif
