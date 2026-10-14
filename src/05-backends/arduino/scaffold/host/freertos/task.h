// The tasks of FreeRTOS on the host, simulated by tempore_simulator.cpp.

#ifndef TEMPORE_HOST_FREERTOS_TASK_H
#define TEMPORE_HOST_FREERTOS_TASK_H

#include "FreeRTOS.h"

// Creates a task, which runs once the simulation starts; the stack size and
// the core are ignored.
BaseType_t xTaskCreatePinnedToCore(TaskFunction_t code, const char *name,
                                   uint32_t stack, void *parameter,
                                   UBaseType_t priority, TaskHandle_t *handle,
                                   BaseType_t core);

// The ticks since start-up.
TickType_t xTaskGetTickCount();

// Blocks the calling task until the ticks-th tick from now.
void vTaskDelay(TickType_t ticks);

// Blocks the calling task until the tick *previous + increment, which becomes
// the new *previous; returns at once if that tick has passed.
void vTaskDelayUntil(TickType_t *previous, TickType_t increment);

// Stops the calling task; only nullptr, the calling task, is supported.
void vTaskSuspend(TaskHandle_t task);
void vTaskDelete(TaskHandle_t task);

// Increments the notification value of the task, unblocking it if it waits
// for a notification.
BaseType_t xTaskNotifyGive(TaskHandle_t task);

// Blocks the calling task until its notification value is positive, and
// returns it, setting it to 0 if clear and else decrementing it; the time
// limit is ignored.
uint32_t ulTaskNotifyTake(BaseType_t clear, TickType_t ticks);

// The name of the calling task for nullptr.
char *pcTaskGetName(TaskHandle_t task);

#endif
