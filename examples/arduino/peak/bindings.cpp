// The bindings of the operations of peak.tpe: the tilt published by the step
// and read by the recorder, in an atomic variable; the record, a float kept
// under the key "peak" of the namespace "tempore-peak" of the non-volatile
// storage of the ESP32 through Preferences, or in a variable on the host,
// each write logged; and the safe state, which writes a line to the log.

#include <Arduino.h>

#include <atomic>

#include "tempore_bindings.h"

#ifndef TEMPORE_HOST
#include <Preferences.h>
#endif

static std::atomic<float> peak_tilt{0};

tempore_result_Publish binding_Publish(tempore_argument_Publish tilt) {
  peak_tilt.store(tilt);
  return {};
}

tempore_result_Latest binding_Latest(tempore_argument_Latest) {
  return peak_tilt.load();
}

#ifdef TEMPORE_HOST
static float peak_record = 0;
#else
// The namespace of the record, opened on first use.
static Preferences &peak_storage() {
  static Preferences storage;
  static bool opened = storage.begin("tempore-peak", false);
  (void)opened;
  return storage;
}
#endif

tempore_result_LoadPeak binding_LoadPeak(tempore_argument_LoadPeak) {
#ifdef TEMPORE_HOST
  return peak_record;
#else
  return peak_storage().getFloat("peak", 0);
#endif
}

tempore_result_StorePeak binding_StorePeak(tempore_argument_StorePeak peak) {
#ifdef TEMPORE_HOST
  peak_record = peak;
#else
  peak_storage().putFloat("peak", peak);
#endif
  tempore_log("Flash: record %.3f degrees", static_cast<double>(peak));
  return {};
}

void peak_safe_state() { tempore_log("Peak recorder stopped"); }
