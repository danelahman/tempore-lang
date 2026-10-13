// The timer of the ESP32 on the host, over the simulated clock.

#ifndef TEMPORE_HOST_ESP_TIMER_H
#define TEMPORE_HOST_ESP_TIMER_H

#include <stdint.h>

// The simulated time since start-up, in microseconds.
int64_t esp_timer_get_time();

#endif
