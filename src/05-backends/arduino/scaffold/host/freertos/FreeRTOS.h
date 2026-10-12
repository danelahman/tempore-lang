// The types and constants of FreeRTOS on the host, with a tick of one
// millisecond, as on the ESP32 under Arduino.

#ifndef TEMPORE_HOST_FREERTOS_H
#define TEMPORE_HOST_FREERTOS_H

#include <stdint.h>

typedef uint32_t TickType_t;
typedef int BaseType_t;
typedef unsigned int UBaseType_t;
typedef void *TaskHandle_t;
typedef void (*TaskFunction_t)(void *);

#define configTICK_RATE_HZ 1000
#define pdMS_TO_TICKS(ms) (static_cast<TickType_t>(ms))
#define portMAX_DELAY (static_cast<TickType_t>(0xffffffffUL))
#define pdPASS 1
#define pdTRUE 1
#define tskNO_AFFINITY 0x7fffffff

#endif
