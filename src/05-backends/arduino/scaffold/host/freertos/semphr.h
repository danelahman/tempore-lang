// The mutexes of FreeRTOS on the host, simulated by tempore_simulator.cpp.

#ifndef TEMPORE_HOST_FREERTOS_SEMPHR_H
#define TEMPORE_HOST_FREERTOS_SEMPHR_H

#include "FreeRTOS.h"

typedef void *SemaphoreHandle_t;

// Creates a mutex, not held.
SemaphoreHandle_t xSemaphoreCreateMutex();

// Takes the mutex, blocking the calling task while another task holds it; the
// time limit is ignored.
BaseType_t xSemaphoreTake(SemaphoreHandle_t mutex, TickType_t ticks);

// Releases the mutex, unblocking the tasks that wait for it.
BaseType_t xSemaphoreGive(SemaphoreHandle_t mutex);

#endif
