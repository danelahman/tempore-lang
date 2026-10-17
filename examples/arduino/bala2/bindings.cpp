// The bindings of the operations of balance.tpe,
// ../bala2-regex/balance_regex.tpe and ../bala2-remote/balance_remote.tpe: the
// exchange between the control step and the supervision, in atomic variables,
// and the safe state; and Report, of ../bala2-remote/balance_remote.tpe only,
// compiled only for a program that performs it.
//
// The supervision arms the robot with the bias of the gyroscope and commands
// a speed and a turn; a command older than BALANCE_COMMAND_MS milliseconds
// (200 unless the build flag sets it) is replaced by zero setpoints, so that
// the robot holds its position. The control step publishes the tilt, the rate
// of the gyroscope, the filtered speed of the wheels and the reference tilt of
// the speed loop. In the safe state the robot is disarmed.
//
// Under the build flag BALANCE_SLOW_FROM_MS, in the host simulation, the
// publication of the attitude takes 3 ms from that time on, beyond the bounds
// of Publish, so that its monitor stops the device; on the device the flag has
// no effect, since tempore_elapse_us does not wait there.
//
// Under the build flag BALANCE_LOG, an interval in milliseconds, the first
// publication starts a task of the lowest priority on core 0, which logs at
// that interval the tilt and the rate of the gyroscope last published, the
// drives last written to the motors and the counts last read from the
// encoders, and logs each arming with its bias of the gyroscope. The timed
// bindings themselves do not log, except for the expiry of a command. The
// start of the task lies outside the bounds of Publish, so that the target
// -log of the examples monitors under the policy warn, which logs that call.
//
// The make targets arduino-bala2-log and arduino-bala2-regex-log build with
// BALANCE_LOG, and arduino-bala2-record and arduino-bala2-regex-record with
// BALANCE_RECORD, whose recordings the targets -capture read
// (src/05-backends/arduino/README.md: Recording a run).
//
// Under the build flag BALANCE_RECORD, an interval in milliseconds, the first
// publication starts two tasks on core 0, which record and print the run:
//
// - The recorder, of priority 1, takes from the first arming after start-up
//   one sample every BALANCE_RECORD milliseconds, BALANCE_RECORD_SAMPLES
//   samples (3000 unless the build flag sets it), and then stops: the values
//   last published by the step, the drives last written and the counts last
//   read, in 16 bytes. The tilt and the reference tilt are kept in hundredths
//   of a degree, the rate in tenths of a degree per second, the speed in
//   counts per second, each saturated to 16 bits, and the counts by their low
//   16 bits, from which the printer restores them by the differences of
//   consecutive samples.
// - The printer, of the lowest priority, prints every complete recording, and
//   every recording kept from before the last start-up, as CSV with a header,
//   every BALANCE_RECORD_REPEAT_MS milliseconds (10000 unless the build flag
//   sets it); a recording begins with a line "# Recording", which gives its
//   sequence number, the identifier of its run, a random number drawn at its
//   arming, and its number of samples, and ends with "# End of recording".
//
// The two recordings of the last two start-ups are kept in two slots of
// memory that is not initialised at start-up; a slot whose check word is that
// of the build holds a recording, which therefore survives a reset of the
// processor, such as a reset by the serial port or a brownout, but not a loss
// of power. Each start-up records into the slot of the older recording and
// keeps the other. The timed bindings only store the published values.

#include <Arduino.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

#include <atomic>

#include "tempore_bindings.h"

#ifdef TEMPORE_PERFORMS_Report
#include "bala2_remote.h"
#endif

#if defined(BALANCE_LOG) || defined(BALANCE_RECORD)
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

#include "bala2_base.h"
#endif

#if defined(BALANCE_RECORD) && !defined(TEMPORE_HOST)
#include <esp_attr.h>
#include <esp_random.h>
#endif

#ifndef BALANCE_COMMAND_MS
#define BALANCE_COMMAND_MS 200
#endif

static std::atomic<bool> balance_armed{false};
static std::atomic<float> balance_bias{0};
static std::atomic<float> balance_speed{0};
static std::atomic<float> balance_turn{0};
static std::atomic<int64_t> balance_command_us{0};
static std::atomic<bool> balance_expired{false};
static std::atomic<float> balance_tilt{0};
static std::atomic<float> balance_rate{0};
static std::atomic<float> balance_wheel_speed{0};
static std::atomic<float> balance_reference{0};

#ifdef BALANCE_LOG
static std::atomic<bool> balance_logging{false};

static void balance_log(void *) {
  bool armed = false;
  for (;;) {
    vTaskDelay(pdMS_TO_TICKS(BALANCE_LOG));
    if (balance_armed.load() != armed) {
      armed = !armed;
      if (armed)
        tempore_log("Armed, gyroscope bias %.3f deg/s",
                    static_cast<double>(balance_bias.load()));
      else
        tempore_log("Disarmed");
    }
    int16_t left_drive, right_drive;
    int32_t left_count, right_count;
    bala2_last_drives(&left_drive, &right_drive);
    bala2_last_counts(&left_count, &right_count);
    tempore_log("Tilt %.2f deg, rate %.1f deg/s, drives %d %d, counts %ld %ld",
                static_cast<double>(balance_tilt.load()),
                static_cast<double>(balance_rate.load()), left_drive,
                right_drive, static_cast<long>(left_count),
                static_cast<long>(right_count));
  }
}
#endif

#ifdef BALANCE_RECORD
#ifndef BALANCE_RECORD_SAMPLES
#define BALANCE_RECORD_SAMPLES 3000
#endif

#ifndef BALANCE_RECORD_REPEAT_MS
#define BALANCE_RECORD_REPEAT_MS 10000
#endif

#ifdef TEMPORE_HOST
#define BALANCE_NOINIT
#else
#define BALANCE_NOINIT __NOINIT_ATTR
#endif

// A sample, in the units of the comment above.
struct balance_sample {
  int16_t tilt, rate, speed, reference;
  int16_t drives[2];
  uint16_t counts[2];
};

// A recording: the check word, the sequence number, the identifier of the
// run, the number of samples taken, the counts of the first sample, and the
// samples.
struct balance_record {
  uint32_t check;
  uint32_t sequence;
  uint32_t run;
  uint32_t length;
  int32_t first_counts[2];
  balance_sample samples[BALANCE_RECORD_SAMPLES];
};

static balance_record balance_records[2] BALANCE_NOINIT;

static std::atomic<bool> balance_recording{false};

// The slot recorded into since start-up, whether its recording is complete,
// and whether each slot held a recording at start-up.
static int balance_slot = 0;
static std::atomic<bool> balance_complete{false};
static bool balance_kept[2] = {false, false};

// The check word of the build: the 32-bit FNV-1a hash of its time of
// compilation and of its parameters of the recording.
static uint32_t balance_check() {
  static const char build[] = __DATE__ " " __TIME__;
  uint32_t hash = 2166136261u;
  const auto mix = [&hash](uint32_t byte) {
    hash = (hash ^ byte) * 16777619u;
  };
  const uint32_t parameters[2] = {BALANCE_RECORD, BALANCE_RECORD_SAMPLES};
  for (const char *c = build; *c != 0; ++c) mix(static_cast<uint8_t>(*c));
  for (const uint32_t word : parameters)
    for (int shift = 0; shift < 32; shift += 8) mix((word >> shift) & 0xff);
  return hash;
}

// Whether the slot r holds a recording of this build.
static bool balance_valid(const balance_record &r) {
  return r.check == balance_check() && r.length > 0 &&
         r.length <= BALANCE_RECORD_SAMPLES;
}

// The value x scaled by scale, rounded and saturated to 16 bits.
static int16_t balance_fixed(float x, float scale) {
  const float y = roundf(x * scale);
  return y >= 32767.0f    ? 32767
         : y <= -32768.0f ? -32768
                          : static_cast<int16_t>(y);
}

// The identifier of a run.
static uint32_t balance_run_id() {
#ifdef TEMPORE_HOST
  return 0;
#else
  return esp_random();
#endif
}

// Takes the samples of the slot balance_slot from the first arming on.
static void balance_record_task(void *) {
  balance_record &r = balance_records[balance_slot];
  const TickType_t interval = pdMS_TO_TICKS(BALANCE_RECORD);
  TickType_t wake = xTaskGetTickCount();
  while (!balance_armed.load()) vTaskDelayUntil(&wake, interval);
  r.run = balance_run_id();
  for (uint32_t i = 0; i < BALANCE_RECORD_SAMPLES; ++i) {
    if (i > 0) vTaskDelayUntil(&wake, interval);
    int16_t drives[2];
    int32_t counts[2];
    bala2_last_drives(&drives[0], &drives[1]);
    bala2_last_counts(&counts[0], &counts[1]);
    if (i == 0) {
      r.first_counts[0] = counts[0];
      r.first_counts[1] = counts[1];
    }
    r.samples[i] = {balance_fixed(balance_tilt.load(), 100.0f),
                    balance_fixed(balance_rate.load(), 10.0f),
                    balance_fixed(balance_wheel_speed.load(), 1.0f),
                    balance_fixed(balance_reference.load(), 100.0f),
                    {drives[0], drives[1]},
                    {static_cast<uint16_t>(counts[0]),
                     static_cast<uint16_t>(counts[1])}};
    r.length = i + 1;
    if (i == 0) r.check = balance_check();
  }
  balance_complete.store(true);
  vTaskDelete(nullptr);
}

// Prints the recording r as CSV, kept if it is from before the last start-up.
static void balance_print(const balance_record &r, bool kept) {
  char line[128];
  snprintf(line, sizeof line,
           "# Recording %lu, run %08lx, %lu of %d samples every %d ms from "
           "the arming%s",
           static_cast<unsigned long>(r.sequence),
           static_cast<unsigned long>(r.run),
           static_cast<unsigned long>(r.length), BALANCE_RECORD_SAMPLES,
           BALANCE_RECORD, kept ? ", kept from before the last start-up" : "");
  Serial.println(line);
  Serial.println(
      "time_ms,tilt_deg,rate_deg_s,speed_counts_s,reference_deg,left_drive,"
      "right_drive,left_count,right_count");
  int32_t counts[2] = {r.first_counts[0], r.first_counts[1]};
  for (uint32_t i = 0; i < r.length; ++i) {
    const balance_sample &s = r.samples[i];
    if (i > 0)
      for (int k = 0; k < 2; ++k)
        counts[k] += static_cast<int16_t>(
            static_cast<uint16_t>(s.counts[k] - r.samples[i - 1].counts[k]));
    snprintf(line, sizeof line, "%lu,%.2f,%.1f,%d,%.2f,%d,%d,%ld,%ld",
             static_cast<unsigned long>(i) * BALANCE_RECORD, s.tilt / 100.0,
             s.rate / 10.0, s.speed, s.reference / 100.0, s.drives[0],
             s.drives[1], static_cast<long>(counts[0]),
             static_cast<long>(counts[1]));
    Serial.println(line);
  }
  snprintf(line, sizeof line, "# End of recording %lu",
           static_cast<unsigned long>(r.sequence));
  Serial.println(line);
}

// Prints the recordings that are kept or complete, in the order of their
// sequence numbers, every BALANCE_RECORD_REPEAT_MS milliseconds, and checks
// for them every second while there is none.
static void balance_print_task(void *) {
  for (;;) {
    const int first =
        balance_records[0].sequence <= balance_records[1].sequence ? 0 : 1;
    const int order[2] = {first, 1 - first};
    bool printed = false;
    for (const int k : order) {
      const bool current = k == balance_slot;
      if (current ? balance_complete.load() : balance_kept[k]) {
        balance_print(balance_records[k], !current);
        printed = true;
      }
    }
    vTaskDelay(pdMS_TO_TICKS(printed ? BALANCE_RECORD_REPEAT_MS : 1000));
  }
}

// Keeps the valid slots, chooses the slot of the recording of this start-up,
// an invalid one or else that of the older recording, and starts the tasks.
static void balance_record_start() {
  uint32_t last = 0;
  for (int k = 0; k < 2; ++k) {
    balance_kept[k] = balance_valid(balance_records[k]);
    if (balance_kept[k] && balance_records[k].sequence > last)
      last = balance_records[k].sequence;
  }
  balance_slot = !balance_kept[0]  ? 0
                 : !balance_kept[1] ? 1
                 : balance_records[0].sequence < balance_records[1].sequence
                     ? 0
                     : 1;
  balance_kept[balance_slot] = false;
  balance_record &r = balance_records[balance_slot];
  r.check = 0;
  r.length = 0;
  r.sequence = last + 1;
  xTaskCreatePinnedToCore(balance_record_task, "balance-record", 4096, nullptr,
                          1, nullptr, 0);
  xTaskCreatePinnedToCore(balance_print_task, "balance-print", 4096, nullptr, 0,
                          nullptr, 0);
}
#endif

tempore_result_Publish binding_Publish(tempore_argument_Publish a) {
#ifdef BALANCE_SLOW_FROM_MS
  if (tempore_clock_us() >= BALANCE_SLOW_FROM_MS * 1000LL)
    tempore_elapse_us(3000);
#endif
  balance_tilt.store(a.c0);
  balance_rate.store(a.c1);
  balance_wheel_speed.store(a.c2);
  balance_reference.store(a.c3);
#ifdef BALANCE_LOG
  if (!balance_logging.exchange(true))
    xTaskCreatePinnedToCore(balance_log, "balance-log", 4096, nullptr, 0,
                            nullptr, 0);
#endif
#ifdef BALANCE_RECORD
  if (!balance_recording.exchange(true)) balance_record_start();
#endif
  return {};
}

tempore_result_Setpoints binding_Setpoints(tempore_argument_Setpoints) {
  const bool armed = balance_armed.load();
  const bool expired =
      armed && tempore_clock_us() - balance_command_us.load() >
                   BALANCE_COMMAND_MS * 1000LL;
  if (expired && !balance_expired.exchange(true))
    tempore_log("Supervision: no command for %d ms; setpoints zero",
                BALANCE_COMMAND_MS);
  if (!expired) balance_expired.store(false);
  return {armed, balance_bias.load(), expired ? 0.0f : balance_speed.load(),
          expired ? 0.0f : balance_turn.load()};
}

tempore_result_Attitude binding_Attitude(tempore_argument_Attitude) {
  return {balance_tilt.load(), balance_rate.load()};
}

// The bias of a calibration: the float of its only constructor, the only
// member of the union arg of its structure, whose member name the compiler
// numbers.
static float balance_bias_of(const tempore_argument_Arm &calibration) {
  float bias;
  memcpy(&bias, &calibration.arg, sizeof bias);
  return bias;
}

tempore_result_Arm binding_Arm(tempore_argument_Arm calibration) {
  const float bias = balance_bias_of(calibration);
  balance_bias.store(bias);
  balance_command_us.store(tempore_clock_us());
  balance_armed.store(true);
  return {};
}

tempore_result_Disarm binding_Disarm(tempore_argument_Disarm) {
  balance_armed.store(false);
  return {};
}

#ifdef TEMPORE_PERFORMS_Report
// Report of ../bala2-remote/balance_remote.tpe: the status of the robot, its
// arming and the tilt last published, sent to the controller through the
// package bala2-remote.
tempore_result_Report binding_Report(tempore_argument_Report armed) {
  bala2_remote_send_status(armed, balance_tilt.load());
  return {};
}
#endif

tempore_result_Command binding_Command(tempore_argument_Command a) {
  balance_speed.store(a.c0);
  balance_turn.store(a.c1);
  balance_command_us.store(tempore_clock_us());
  return {};
}

void balance_safe_state() { balance_armed.store(false); }
