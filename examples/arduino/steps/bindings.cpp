// The bindings of the operations of steps.tpe: the steps counted, kept in a
// variable, each count and reset logged; the time since start-up; a button
// on the display, drawn with the lock of the display held; and the safe
// state, which writes a line to the log.
//
// Under the build flag STEPS_RECORD, a bound in seconds, the readings of the
// unit and the events of the counter are recorded in flash memory, for the
// targets arduino-steps-record, -capture and -erase
// (src/05-backends/arduino/README.md: Recording the step counter):
//
// - Each reading of ReadImu, passed to m5_imu_observe, is a record of 16
//   bytes: the time of millis(), the clock of ReadClock, in its low 28 bits
//   and the kind of the record in its high 4, and the acceleration in units
//   of 1/4096 g and the angular rate in units of 1/16 degree per second, each
//   saturated to 16 bits. The events are records of other kinds: a count of
//   n steps, a reset, the start of a calibration, drawn as the Calibrate
//   button active, which begins a new numbered recording, the end of a
//   calibration, the button drawn idle, and the records dropped.
// - The watch task adds the records to a ring of STEPS_RECORD_RING records
//   in RAM (1024 unless the build flag sets it), without waiting, and
//   notifies the writer, a task of core 0, which writes them in order to the
//   data partition "spiffs" after its header sector, each write within one
//   page of 256 bytes, once 16 records are pending or 250 ms after the last
//   write. A write follows the notification of a reading, so that the
//   programming of the flash memory, which stops both cores, falls between
//   two readings. A record that finds the ring full is dropped, and counted.
// - The times of the records wrap after 2^28 ms, about 74 hours of uptime.
// - The recordings persist across resets and losses of power. They end at
//   STEPS_RECORD seconds of recorded time, the sum of the times between
//   consecutive records of each recording, or when the partition is full;
//   later records are dropped, and the screen shows "FULL" instead of
//   "REC n", in red text of size 1 at the right end of the row 134.
// - A partition whose header is not that of the format is erased and
//   formatted at start-up, after which the device restarts: an erase stops
//   both cores for each sector, so that the readings stall meanwhile.
// - A task of core 0 reads commands from the serial port: "dump" prints the
//   recordings, and "erase" erases them and restarts the device. The dump
//   begins with the line "# Recordings", each recording with the line
//   "# Recording N" and ends with the line "# End of recording N, R rows",
//   and the dump ends with "# End of the recordings". The line of the
//   columns and each row begin with "@", so that a line of the log written
//   at the same time does not mix with them.
// - The reset reason of the start-up is logged, and given in the header of
//   its first recording.
//
// In the host simulation the partition is a buffer in memory, the commands
// are not read, and world.cpp prints the recordings at the end.

#include <Arduino.h>
#include <M5Unified.h>

#include "tempore_bindings.h"

#ifdef STEPS_RECORD
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

#include <atomic>

#ifndef TEMPORE_HOST
#include <esp_partition.h>
#include <esp_system.h>
#endif

static void steps_record_count(uint32_t added);
static void steps_record_reset();
static void steps_record_button(const char *label, bool active);
#endif

static uint32_t steps_counted = 0;

tempore_result_CountStep binding_CountStep(tempore_argument_CountStep added) {
  steps_counted += static_cast<uint32_t>(added);
  tempore_log("Steps: %u counted, %u in all", static_cast<unsigned>(added),
              static_cast<unsigned>(steps_counted));
#ifdef STEPS_RECORD
  steps_record_count(static_cast<uint32_t>(added));
#endif
  return {};
}

tempore_result_ResetSteps binding_ResetSteps(tempore_argument_ResetSteps) {
  steps_counted = 0;
  tempore_log("Steps: reset");
#ifdef STEPS_RECORD
  steps_record_reset();
#endif
  return {};
}

tempore_result_ReadClock binding_ReadClock(tempore_argument_ReadClock) {
  return millis();
}

// The colours of a button: the border, and the fill and the label of a
// button and of an active one; the radius of its corners, in pixels.
enum : uint32_t {
  steps_white = 0xffffff,
  steps_black = 0x000000,
  steps_dark_grey = 0x303030,
  steps_yellow = 0xffd000
};
static const int32_t steps_corner = 6;

tempore_result_ShowButton binding_ShowButton(tempore_argument_ShowButton a) {
  {
    const tempore_display_guard guard;
    const int32_t x = static_cast<int32_t>(a.c0),
                  y = static_cast<int32_t>(a.c1);
    const int32_t w = static_cast<int32_t>(a.c2),
                  h = static_cast<int32_t>(a.c3);
    const uint32_t fill = a.c4 ? steps_yellow : steps_dark_grey;
    const uint32_t label = a.c4 ? steps_black : steps_white;
    tempore_display_drawn(x, y, w, h);
    M5.Display.fillRoundRect(x, y, w, h, steps_corner, fill);
    M5.Display.drawRoundRect(x, y, w, h, steps_corner, steps_white);
    M5.Display.setTextSize(2);
    M5.Display.setTextColor(label, fill);
    M5.Display.setCursor(x + (w - M5.Display.textWidth(a.c5)) / 2,
                         y + (h - M5.Display.fontHeight()) / 2);
    M5.Display.print(a.c5);
    M5.Display.setTextColor(steps_white, steps_black);
  }
#ifdef STEPS_RECORD
  steps_record_button(a.c5, a.c4);
#endif
  return {};
}

void steps_safe_state() { tempore_log("Step counter stopped"); }

#ifdef STEPS_RECORD

#ifndef STEPS_RECORD_RING
#define STEPS_RECORD_RING 1024
#endif

// A record: the time in milliseconds in the low 28 bits of head and the kind
// in its high 4, and six values. An erased record, all bits set, ends the
// records.
struct steps_record {
  uint32_t head;
  int16_t value[6];
};
static_assert(sizeof(steps_record) == 16, "a record is 16 bytes");

// The kinds of the records. A recording starts with a record start, whose
// first two values hold its number and whose third the reset reason plus 1
// of the start-up that it is the first of, and else 0. A count holds the
// steps, and a record dropped the number of records dropped, each in its
// first two values.
enum : uint32_t {
  steps_reading = 0,
  steps_start = 1,
  steps_count = 2,
  steps_reset = 3,
  steps_calibrated = 4,
  steps_dropped = 5,
  steps_erased = 0xffffffffu
};

// The header of the partition, in its first sector: the magic word, the
// version of the format and the bytes of the records erased after it.
struct steps_header {
  uint32_t magic;
  uint32_t version;
  uint32_t capacity;
};
static const uint32_t steps_magic = 0x53544550u;  // "STEP"
static const uint32_t steps_version = 1;

// The size of a sector and of a page of the flash memory, in bytes.
static const uint32_t steps_sector = 4096;
static const uint32_t steps_page = 256;

// The capacity of the records: 2000 bytes, 125 records, per second of the
// bound, rounded up to whole sectors; the bound in milliseconds.
static const uint32_t steps_capacity =
    (static_cast<uint32_t>(STEPS_RECORD) * 2000u + steps_sector - 1) /
    steps_sector * steps_sector;
static const uint32_t steps_bound_ms =
    static_cast<uint32_t>(STEPS_RECORD) * 1000u;

// The ring of the records not yet written, written by the watch task and
// read by the writer; the records dropped while it was full.
static steps_record steps_ring[STEPS_RECORD_RING];
static std::atomic<uint32_t> steps_ring_head{0};
static std::atomic<uint32_t> steps_ring_tail{0};
static std::atomic<uint32_t> steps_ring_dropped{0};

// The writer, null until the first record, the reset reason of the
// start-up, and whether the first start of this start-up is still to be
// recorded.
static TaskHandle_t steps_writer = nullptr;
static int steps_reason = 0;
static bool steps_first_start = true;

// The state of the writer: whether the records are read and the device
// accepts commands; the bytes of the records written; whether the bound is
// reached; the number of the current recording; whether the marker is to be
// drawn again; whether an erase is requested, and whether the writer has
// stopped for it.
static std::atomic<bool> steps_ready{false};
static std::atomic<uint32_t> steps_written{0};
static std::atomic<bool> steps_full{false};
static std::atomic<uint32_t> steps_number{0};
static std::atomic<bool> steps_marker_dirty{true};
static std::atomic<bool> steps_erasing{false};
static std::atomic<bool> steps_paused{false};

// The capacity of the records of the partition, as formatted.
static uint32_t steps_formatted = 0;

// The storage: the data partition "spiffs" on the device, a buffer in memory
// on the host; offsets from the start of the partition.
#ifdef TEMPORE_HOST
static uint8_t steps_memory[steps_sector + steps_capacity];

static bool steps_storage_open() { return true; }

static void steps_storage_read(uint32_t offset, void *data, size_t size) {
  memcpy(data, steps_memory + offset, size);
}

static void steps_storage_write(uint32_t offset, const void *data,
                                size_t size) {
  memcpy(steps_memory + offset, data, size);
}

static void steps_storage_erase(uint32_t offset, size_t size) {
  memset(steps_memory + offset, 0xff, size);
}

static uint32_t steps_storage_size() { return sizeof steps_memory; }

static int steps_reset_reason() { return 0; }

static const char *steps_reason_name(int) { return "host"; }
#else
static const esp_partition_t *steps_partition = nullptr;

static bool steps_storage_open() {
  steps_partition = esp_partition_find_first(
      ESP_PARTITION_TYPE_DATA, ESP_PARTITION_SUBTYPE_DATA_SPIFFS, "spiffs");
  return steps_partition != nullptr;
}

static void steps_storage_read(uint32_t offset, void *data, size_t size) {
  esp_partition_read(steps_partition, offset, data, size);
}

static void steps_storage_write(uint32_t offset, const void *data,
                                size_t size) {
  esp_partition_write(steps_partition, offset, data, size);
}

static void steps_storage_erase(uint32_t offset, size_t size) {
  esp_partition_erase_range(steps_partition, offset, size);
}

static uint32_t steps_storage_size() { return steps_partition->size; }

static int steps_reset_reason() { return static_cast<int>(esp_reset_reason()); }

static const char *steps_reason_name(int reason) {
  switch (reason) {
    case ESP_RST_POWERON:
      return "power-on";
    case ESP_RST_EXT:
      return "external pin";
    case ESP_RST_SW:
      return "software";
    case ESP_RST_PANIC:
      return "panic";
    case ESP_RST_INT_WDT:
      return "interrupt watchdog";
    case ESP_RST_TASK_WDT:
      return "task watchdog";
    case ESP_RST_WDT:
      return "other watchdog";
    case ESP_RST_DEEPSLEEP:
      return "deep sleep";
    case ESP_RST_BROWNOUT:
      return "brownout";
    case ESP_RST_SDIO:
      return "SDIO";
    default:
      return "unknown";
  }
}
#endif

static void steps_writer_task(void *);

// The value x scaled by scale, rounded and saturated to 16 bits.
static int16_t steps_fixed(float x, float scale) {
  const float y = roundf(x * scale);
  return y >= 32767.0f    ? 32767
         : y <= -32768.0f ? -32768
                          : static_cast<int16_t>(y);
}

// The record of the kind at the current time, with the number n in its first
// two values and v in its third.
static steps_record steps_event(uint32_t kind, uint32_t n, int16_t v) {
  steps_record r;
  r.head = (kind << 28) | (static_cast<uint32_t>(millis()) & 0x0fffffffu);
  r.value[0] = static_cast<int16_t>(n & 0xffff);
  r.value[1] = static_cast<int16_t>(n >> 16);
  r.value[2] = v;
  r.value[3] = r.value[4] = r.value[5] = 0;
  return r;
}

// The number held in the first two values of a record.
static uint32_t steps_held(const steps_record &r) {
  return static_cast<uint16_t>(r.value[0]) |
         (static_cast<uint32_t>(static_cast<uint16_t>(r.value[1])) << 16);
}

// Creates the writer at the first record, with the reset reason of the
// start-up logged.
static void steps_begin() {
  if (steps_writer != nullptr) return;
  steps_reason = steps_reset_reason();
  tempore_log("Recorder: start-up after the reset reason %s (%d)",
              steps_reason_name(steps_reason), steps_reason);
  xTaskCreatePinnedToCore(steps_writer_task, "steps-writer", 6144, nullptr, 2,
                          &steps_writer, 0);
}

// Adds a record to the ring, or counts it as dropped, and notifies the
// writer.
static void steps_push(const steps_record &r) {
  steps_begin();
  const uint32_t head = steps_ring_head.load(std::memory_order_relaxed);
  if (head - steps_ring_tail.load(std::memory_order_acquire) >=
      STEPS_RECORD_RING) {
    steps_ring_dropped.fetch_add(1);
  } else {
    steps_ring[head % STEPS_RECORD_RING] = r;
    steps_ring_head.store(head + 1, std::memory_order_release);
  }
  xTaskNotifyGive(steps_writer);
}

void m5_imu_observe(const float *accel, const float *gyro) {
  if (steps_writer == nullptr) return;
  steps_record r;
  r.head = static_cast<uint32_t>(millis()) & 0x0fffffffu;
  for (int k = 0; k < 3; ++k) {
    r.value[k] = steps_fixed(accel[k], 4096.0f);
    r.value[3 + k] = steps_fixed(gyro[k], 16.0f);
  }
  steps_push(r);
}

static void steps_record_count(uint32_t added) {
  steps_push(steps_event(steps_count, added, 0));
}

static void steps_record_reset() { steps_push(steps_event(steps_reset, 0, 0)); }

// The Calibrate button drawn active starts a recording, the first of a
// start-up with its reset reason, and drawn idle ends the calibration; each
// drawing of a button draws the marker again.
static void steps_record_button(const char *label, bool active) {
  if (strcmp(label, "Calibrate") == 0) {
    steps_begin();
    const int16_t reason =
        steps_first_start ? static_cast<int16_t>(steps_reason + 1) : 0;
    if (active) steps_first_start = false;
    steps_push(steps_event(active ? steps_start : steps_calibrated, 0,
                           active ? reason : 0));
  }
  steps_marker_dirty.store(true);
  if (steps_writer != nullptr) xTaskNotifyGive(steps_writer);
}

// The tally of the records read in order: the number of the last recording,
// whether one is open, the time of the last record and the recorded time.
struct steps_tally {
  uint32_t number = 0;
  bool open = false;
  uint32_t last_ms = 0;
  uint32_t recorded_ms = 0;
};

static void steps_account(steps_tally &t, const steps_record &r) {
  const uint32_t time = r.head & 0x0fffffffu;
  if (r.head >> 28 == steps_start) {
    t.number = steps_held(r);
    t.open = true;
  } else if (t.open && time >= t.last_ms) {
    t.recorded_ms += time - t.last_ms;
  }
  t.last_ms = time;
}

// The recorded time of the records written, in milliseconds.
static std::atomic<uint32_t> steps_recorded_ms{0};

// The capacity of the records of this build within the partition.
static uint32_t steps_build_capacity() {
  const uint32_t room =
      (steps_storage_size() - steps_sector) / steps_sector * steps_sector;
  return steps_capacity < room ? steps_capacity : room;
}

// Draws the marker at the right end of the row 134 in red text of size 1:
// "ERASING", "REC" before the records are read, "FULL", or "REC n".
static void steps_draw_marker() {
  char text[16];
  const uint32_t n = steps_number.load();
  if (steps_erasing.load())
    snprintf(text, sizeof text, "ERASING");
  else if (steps_full.load())
    snprintf(text, sizeof text, "FULL");
  else if (!steps_ready.load() || n == 0)
    snprintf(text, sizeof text, "REC");
  else
    snprintf(text, sizeof text, "REC %lu", static_cast<unsigned long>(n));
  const tempore_display_guard guard;
  if (tempore_halted()) return;
  const int32_t x = M5.Display.getCursorX(), y = M5.Display.getCursorY();
  const float size = M5.Display.getTextSizeX();
  M5.Display.setTextSize(1);
  const int32_t right = M5.Display.width(), width = 42;
  M5.Display.fillRect(right - width, 134, width, 8, steps_black);
  M5.Display.setTextColor(0xff4040, steps_black);
  M5.Display.setCursor(right - M5.Display.textWidth(text), 134);
  M5.Display.print(text);
  M5.Display.setTextColor(steps_white, steps_black);
  M5.Display.setTextSize(size);
  M5.Display.setCursor(x, y);
}

// Erases the header sector and the first erase bytes of the records, sector
// by sector, each erase followed by a yield, and writes the header of the
// capacity.
static void steps_format(uint32_t erase, uint32_t capacity) {
  for (uint32_t offset = 0; offset < steps_sector + erase;
       offset += steps_sector) {
    steps_storage_erase(offset, steps_sector);
    vTaskDelay(1);
  }
  const steps_header header = {steps_magic, steps_version, capacity};
  steps_storage_write(0, &header, sizeof header);
}

// Writes a line of the dump and a newline in one write; false if the port is
// not connected.
static bool steps_line(const char *format, ...)
    __attribute__((format(printf, 1, 2)));

static bool steps_line(const char *format, ...) {
  char line[112];
  va_list arguments;
  va_start(arguments, format);
  int n = vsnprintf(line, sizeof line - 1, format, arguments);
  va_end(arguments);
  if (n < 0) return false;
  if (n > static_cast<int>(sizeof line) - 2) n = sizeof line - 2;
  line[n] = '\n';
  line[n + 1] = '\0';
#ifdef TEMPORE_HOST
  Serial.print(line);
  return true;
#else
  if (!Serial) return false;
  Serial.write(reinterpret_cast<const uint8_t *>(line), n + 1);
  return true;
#endif
}

// The line of the record r of the recording open, its time t and kind kind.
static bool steps_row(const steps_record &r, unsigned long t, uint32_t kind) {
  switch (kind) {
    case steps_reading:
      return steps_line("@%lu,%.5f,%.5f,%.5f,%.4f,%.4f,%.4f,", t,
                        r.value[0] / 4096.0, r.value[1] / 4096.0,
                        r.value[2] / 4096.0, r.value[3] / 16.0,
                        r.value[4] / 16.0, r.value[5] / 16.0);
    case steps_count:
      return steps_line("@%lu,,,,,,,count %lu", t,
                        static_cast<unsigned long>(steps_held(r)));
    case steps_dropped:
      return steps_line("@%lu,,,,,,,dropped %lu", t,
                        static_cast<unsigned long>(steps_held(r)));
    case steps_reset:
      return steps_line("@%lu,,,,,,,reset", t);
    case steps_calibrated:
      return steps_line("@%lu,,,,,,,calibration end", t);
    default:
      return steps_line("@%lu,,,,,,,unknown", t);
  }
}

// Prints the records written so far, recording by recording; stops if the
// port is not connected.
static void steps_dump() {
  const uint32_t end = steps_written.load();
  if (!steps_line("# Recordings: %lu records, %.1f of %u s recorded%s",
                  static_cast<unsigned long>(end / sizeof(steps_record)),
                  steps_recorded_ms.load() / 1000.0,
                  static_cast<unsigned>(STEPS_RECORD),
                  steps_full.load() ? ", full" : ""))
    return;
  steps_record block[64];
  unsigned long number = 0, rows = 0;
  bool open = false;
  for (uint32_t offset = 0; offset < end; offset += sizeof block) {
    const uint32_t size =
        end - offset < sizeof block ? end - offset : sizeof block;
    steps_storage_read(steps_sector + offset, block, size);
    for (uint32_t i = 0; i < size / sizeof(steps_record); ++i) {
      const steps_record &r = block[i];
      const unsigned long t = r.head & 0x0fffffffu;
      const uint32_t kind = r.head >> 28;
      if (kind == steps_start) {
        if (open &&
            !steps_line("# End of recording %lu, %lu rows", number, rows))
          return;
        number = steps_held(r);
        rows = 0;
        open = true;
        const int reason = r.value[2] - 1;
        const bool ok =
            (r.value[2] > 0
                 ? steps_line("# Recording %lu, the first after the start-up "
                              "by the reset reason %s (%d)",
                              number, steps_reason_name(reason), reason)
                 : steps_line("# Recording %lu", number)) &&
            steps_line("@t_ms,ax,ay,az,gx,gy,gz,event") &&
            steps_line("@%lu,,,,,,,calibration start", t);
        if (!ok) return;
      } else if (!open) {
        continue;
      } else if (!steps_row(r, t, kind)) {
        return;
      }
      ++rows;
    }
  }
  if (open && !steps_line("# End of recording %lu, %lu rows", number, rows))
    return;
  steps_line("# End of the recordings");
}

#ifndef TEMPORE_HOST
// Erases the recordings, once the writer has stopped, and restarts.
static void steps_erase() {
  steps_erasing.store(true);
  steps_marker_dirty.store(true);
  for (int i = 0; i < 200 && !steps_paused.load(); ++i) {
    xTaskNotifyGive(steps_writer);
    vTaskDelay(pdMS_TO_TICKS(10));
  }
  steps_line("# Erasing the recordings");
  tempore_log("Recorder: erasing the recordings");
  const uint32_t capacity = steps_build_capacity();
  const uint32_t used = (steps_written.load() + steps_sector - 1) /
                        steps_sector * steps_sector;
  steps_format(capacity > steps_formatted ? capacity : used, capacity);
  steps_line("# Recordings erased; restarting");
  delay(200);
  esp_restart();
}

// Reads the commands "dump" and "erase", each a line, from the serial port;
// the input that arrives during a dump is discarded.
static void steps_console_task(void *) {
  char line[16];
  size_t n = 0;
  for (;;) {
    vTaskDelay(pdMS_TO_TICKS(20));
    while (Serial.available() > 0) {
      const int c = Serial.read();
      if (c == '\n' || c == '\r') {
        line[n] = '\0';
        n = 0;
        if (strcmp(line, "dump") == 0) {
          steps_dump();
          while (Serial.available() > 0) Serial.read();
        } else if (strcmp(line, "erase") == 0) {
          steps_erase();
        }
      } else if (n < sizeof line - 1) {
        line[n++] = static_cast<char>(c);
      }
    }
  }
}
#endif

// Reads the records written, up to the first erased record, into the tally;
// their bytes.
static uint32_t steps_scan(steps_tally &tally) {
  steps_record block[64];
  uint32_t written = 0;
  while (written < steps_formatted) {
    steps_storage_read(steps_sector + written, block, sizeof block);
    for (const steps_record &r : block) {
      if (r.head == steps_erased || written >= steps_formatted) return written;
      steps_account(tally, r);
      written += sizeof r;
    }
    if (written % steps_sector == 0) vTaskDelay(1);
  }
  return written;
}

// The writer: checks the header, formatting the partition if it is not that
// of the format, reads the records written, and then writes the records of
// the ring, each write within a page, and draws the marker.
static void steps_writer_task(void *) {
  if (!steps_storage_open()) {
    tempore_log("Recorder: no data partition \"spiffs\"");
    vTaskDelete(nullptr);
    return;
  }
  const uint32_t capacity = steps_build_capacity();
  steps_header header;
  steps_storage_read(0, &header, sizeof header);
  if (header.magic != steps_magic || header.version != steps_version ||
      header.capacity > steps_storage_size() - steps_sector) {
    tempore_log("Recorder: formatting the partition");
    steps_erasing.store(true);
    steps_draw_marker();
    steps_format(capacity, capacity);
    header.capacity = capacity;
    steps_erasing.store(false);
#ifndef TEMPORE_HOST
    tempore_log("Recorder: partition formatted; restarting");
    vTaskDelay(pdMS_TO_TICKS(200));
    esp_restart();
#endif
  }
  steps_formatted = header.capacity < capacity ? header.capacity : capacity;
  steps_tally tally;
  uint32_t written = steps_scan(tally);
  steps_written.store(written);
  steps_recorded_ms.store(tally.recorded_ms);
  steps_full.store(tally.recorded_ms >= steps_bound_ms ||
                   written + sizeof(steps_record) > steps_formatted);
  tempore_log("Recorder: %lu recordings, %lu records, %lu ms recorded%s",
              static_cast<unsigned long>(tally.number),
              static_cast<unsigned long>(written / sizeof(steps_record)),
              static_cast<unsigned long>(tally.recorded_ms),
              steps_full.load() ? ", full" : "");
  tally.open = false;
  steps_ready.store(true);
  steps_marker_dirty.store(true);
#ifndef TEMPORE_HOST
  xTaskCreatePinnedToCore(steps_console_task, "steps-console", 6144, nullptr,
                          1, nullptr, 0);
#endif
  const uint32_t per_page = steps_page / sizeof(steps_record);
  TickType_t last_write = xTaskGetTickCount();
  for (;;) {
    ulTaskNotifyTake(pdTRUE, pdMS_TO_TICKS(100));
    if (steps_erasing.load()) {
      steps_paused.store(true);
      if (steps_marker_dirty.exchange(false)) steps_draw_marker();
      continue;
    }
    if (steps_marker_dirty.exchange(false)) steps_draw_marker();
    const uint32_t tail = steps_ring_tail.load(std::memory_order_relaxed);
    const uint32_t pending =
        steps_ring_head.load(std::memory_order_acquire) - tail;
    const bool dropped = steps_ring_dropped.load() > 0;
    if (pending == 0 && !dropped) continue;
    if (pending < per_page && !dropped &&
        xTaskGetTickCount() - last_write < pdMS_TO_TICKS(250))
      continue;
    // The records up to the end of the page, the count of the records
    // dropped first.
    steps_record page[steps_page / sizeof(steps_record)];
    const uint32_t room = (steps_page - written % steps_page) /
                          sizeof(steps_record);
    uint32_t n = 0, taken = 0;
    const bool full = steps_full.load();
    if (dropped) {
      const steps_record r =
          steps_event(steps_dropped, steps_ring_dropped.exchange(0), 0);
      if (!full && tally.open) {
        steps_account(tally, r);
        page[n++] = r;
      }
    }
    for (; taken < pending && n < room; ++taken) {
      steps_record r = steps_ring[(tail + taken) % STEPS_RECORD_RING];
      if (steps_full.load()) continue;
      if (r.head >> 28 == steps_start) {
        r.value[0] = static_cast<int16_t>((tally.number + 1) & 0xffff);
        r.value[1] = static_cast<int16_t>((tally.number + 1) >> 16);
      } else if (!tally.open) {
        continue;
      }
      steps_tally next = tally;
      steps_account(next, r);
      if (next.recorded_ms >= steps_bound_ms ||
          written + (n + 1) * sizeof(steps_record) > steps_formatted) {
        steps_full.store(true);
        steps_marker_dirty.store(true);
        tempore_log("Recorder: full, %lu ms recorded",
                    static_cast<unsigned long>(tally.recorded_ms));
        continue;
      }
      tally = next;
      page[n++] = r;
    }
    steps_ring_tail.store(tail + taken, std::memory_order_release);
    if (n > 0) {
      steps_storage_write(steps_sector + written, page,
                          n * sizeof(steps_record));
      written += n * sizeof(steps_record);
      steps_written.store(written);
      steps_recorded_ms.store(tally.recorded_ms);
    }
    last_write = xTaskGetTickCount();
    if (tally.number != steps_number.load()) {
      steps_number.store(tally.number);
      steps_draw_marker();
    }
  }
}

#ifdef TEMPORE_HOST
void steps_record_print() { steps_dump(); }
#endif

#endif
