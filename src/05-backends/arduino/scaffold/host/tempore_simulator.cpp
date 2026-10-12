// A discrete-event simulation, on the host, of the FreeRTOS tasks of a device
// on a simulated clock.
//
// Each task runs on a thread of its own, and exactly one thread runs at a time:
// the simulator resumes the task whose wake-up time is the earliest, a higher
// priority and then an earlier creation breaking ties, sets the clock to that
// time and waits until the task blocks again, so that a simulation is
// deterministic. Computation takes no simulated time; an action that takes
// time (vTaskDelay, vTaskDelayUntil, delay, delayMicroseconds) blocks the task
// until its end, while the other tasks run, as if each task had a processor
// of its own.
//
// Usage: simulation [DURATION_US] runs setup() and then the tasks for the
// given simulated time in microseconds (default: one second), the events at
// times before it.

#include <Arduino.h>
#include <M5Unified.h>
#include <Wire.h>
#include <esp_timer.h>
#include <stdlib.h>

#include <condition_variable>
#include <memory>
#include <mutex>
#include <thread>
#include <vector>

void setup();

HardwareSerial Serial;
TwoWire Wire;
TwoWire Wire1;
tempore_m5_unified M5;

namespace {

struct Task {
  const char *name;
  TaskFunction_t code;
  void *parameter;
  UBaseType_t priority;
  size_t index;
  int64_t wake;
  bool stopped;
  bool resumed;
  std::condition_variable resume;
};

std::mutex mutex;
std::condition_variable yielded;
std::vector<std::unique_ptr<Task>> tasks;
Task *running = nullptr;
int64_t now = 0;
thread_local Task *self = nullptr;

// Whether task a runs before task b.
bool before(const Task &a, const Task &b) {
  if (a.wake != b.wake) return a.wake < b.wake;
  if (a.priority != b.priority) return a.priority > b.priority;
  return a.index < b.index;
}

// Waits, holding lock, until the simulator resumes the calling task.
void wait_resumed(std::unique_lock<std::mutex> &lock, Task *task) {
  task->resume.wait(lock, [task] { return task->resumed; });
  task->resumed = false;
}

// Blocks the calling task until the time wake, or for ever if stop. Outside
// the tasks, in setup(), the clock advances to wake at once.
void block(int64_t wake, bool stop) {
  Task *task = self;
  if (task == nullptr) {
    if (!stop && wake > now) now = wake;
    return;
  }
  std::unique_lock<std::mutex> lock(mutex);
  task->wake = wake;
  task->stopped = stop;
  running = nullptr;
  yielded.notify_one();
  wait_resumed(lock, task);
}

void run_task(Task *task) {
  self = task;
  {
    std::unique_lock<std::mutex> lock(mutex);
    wait_resumed(lock, task);
  }
  task->code(task->parameter);
  block(0, true);
}

}  // namespace

BaseType_t xTaskCreatePinnedToCore(TaskFunction_t code, const char *name,
                                   uint32_t, void *parameter,
                                   UBaseType_t priority, TaskHandle_t *handle,
                                   BaseType_t) {
  Task *task;
  {
    std::lock_guard<std::mutex> lock(mutex);
    tasks.push_back(std::unique_ptr<Task>(
        new Task{name, code, parameter, priority, tasks.size(), now, false,
                 false, {}}));
    task = tasks.back().get();
  }
  if (handle != nullptr) *handle = task;
  std::thread(run_task, task).detach();
  return pdPASS;
}

int64_t esp_timer_get_time() { return now; }

TickType_t xTaskGetTickCount() { return static_cast<TickType_t>(now / 1000); }

void vTaskDelay(TickType_t ticks) {
  block((now / 1000 + static_cast<int64_t>(ticks)) * 1000, false);
}

void vTaskDelayUntil(TickType_t *previous, TickType_t increment) {
  *previous += increment;
  const int64_t wake = static_cast<int64_t>(*previous) * 1000;
  if (wake > now) block(wake, false);
}

void vTaskSuspend(TaskHandle_t) { block(0, true); }

void vTaskDelete(TaskHandle_t) { block(0, true); }

char *pcTaskGetName(TaskHandle_t) {
  static char setup_name[] = "setup";
  return self != nullptr ? const_cast<char *>(self->name) : setup_name;
}

void delay(uint32_t ms) { block(now + static_cast<int64_t>(ms) * 1000, false); }

void delayMicroseconds(uint32_t us) {
  block(now + static_cast<int64_t>(us), false);
}

unsigned long millis() { return static_cast<unsigned long>(now / 1000); }

unsigned long micros() { return static_cast<unsigned long>(now); }

size_t HardwareSerial::print(const char *text) {
  return static_cast<size_t>(fputs(text, stdout) >= 0 ? strlen(text) : 0);
}

size_t HardwareSerial::println(const char *text) {
  const size_t n = print(text);
  fputc('\n', stdout);
  return n + 1;
}

void HardwareSerial::flush() { fflush(stdout); }

int main(int argc, char **argv) {
  const int64_t duration = argc > 1 ? strtoll(argv[1], nullptr, 10) : 1000000;
  setup();
  std::unique_lock<std::mutex> lock(mutex);
  for (;;) {
    Task *next = nullptr;
    for (const auto &task : tasks)
      if (!task->stopped && (next == nullptr || before(*task, *next)))
        next = task.get();
    if (next == nullptr || next->wake >= duration) break;
    if (next->wake > now) now = next->wake;
    running = next;
    next->resumed = true;
    next->resume.notify_one();
    yielded.wait(lock, [] { return running == nullptr; });
  }
  if (now < duration) now = duration;
  printf("[%lld.%03lld ms] End of the simulation\n",
         static_cast<long long>(now / 1000), static_cast<long long>(now % 1000));
  fflush(stdout);
  _Exit(0);
}
