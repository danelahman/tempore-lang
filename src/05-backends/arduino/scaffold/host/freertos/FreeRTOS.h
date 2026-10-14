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
#define pdMS_TO_TICKS(ms)                                     \
  (static_cast<TickType_t>(static_cast<TickType_t>(ms) *    \
                           static_cast<TickType_t>(configTICK_RATE_HZ) / \
                           1000U))
#define portMAX_DELAY (static_cast<TickType_t>(0xffffffffUL))
#define pdPASS 1
#define pdTRUE 1
#define pdFALSE 0
#define tskNO_AFFINITY 0x7fffffff
#define tskIDLE_PRIORITY 0

// The spinlocks of the critical sections of FreeRTOS on the ESP32, which do
// nothing on the host, where one task runs at a time.
typedef int portMUX_TYPE;
#define portMUX_INITIALIZER_UNLOCKED 0
#define portENTER_CRITICAL(mux) ((void)(mux))
#define portEXIT_CRITICAL(mux) ((void)(mux))

#endif
