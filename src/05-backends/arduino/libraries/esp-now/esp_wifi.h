// The part of the Wi-Fi driver of ESP-IDF that the package esp-now uses, on
// the host, implemented by esp_now_link_model.cpp: the radio starts at once
// but for esp_wifi_start, which takes 100 milliseconds, and every call
// succeeds.

#ifndef TEMPORE_HOST_ESP_WIFI_H
#define TEMPORE_HOST_ESP_WIFI_H

#include <stdint.h>

typedef int esp_err_t;
#define ESP_OK 0
#define ESP_FAIL -1
#define ESP_ERR_INVALID_STATE 0x103

typedef enum { WIFI_MODE_NULL = 0, WIFI_MODE_STA } wifi_mode_t;
typedef enum { WIFI_IF_STA = 0 } wifi_interface_t;
typedef enum { WIFI_STORAGE_FLASH = 0, WIFI_STORAGE_RAM } wifi_storage_t;
typedef enum { WIFI_PS_NONE = 0 } wifi_ps_type_t;
typedef enum { WIFI_SECOND_CHAN_NONE = 0 } wifi_second_chan_t;

typedef struct {
  int nvs_enable;
} wifi_init_config_t;
#define WIFI_INIT_CONFIG_DEFAULT() {1}

esp_err_t esp_event_loop_create_default();
esp_err_t esp_wifi_init(const wifi_init_config_t *config);
esp_err_t esp_wifi_set_storage(wifi_storage_t storage);
esp_err_t esp_wifi_set_mode(wifi_mode_t mode);
esp_err_t esp_wifi_start();
esp_err_t esp_wifi_set_ps(wifi_ps_type_t type);
esp_err_t esp_wifi_set_channel(uint8_t primary, wifi_second_chan_t second);

// The address of the station, 24:0A:C4:00:00:01 on the host.
esp_err_t esp_wifi_get_mac(wifi_interface_t interface, uint8_t mac[6]);

#endif
