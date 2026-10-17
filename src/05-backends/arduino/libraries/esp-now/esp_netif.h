// The network interface of ESP-IDF on the host, which the package esp-now
// starts before the radio; implemented by esp_now_link_model.cpp.

#ifndef TEMPORE_HOST_ESP_NETIF_H
#define TEMPORE_HOST_ESP_NETIF_H

#include "esp_wifi.h"

esp_err_t esp_netif_init();

#endif
