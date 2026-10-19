// The signal of the halt on the speaker of a board driven through M5Unified:
// a falling pair of tones, the second queued after the first on one channel
// of the speaker, which the task of the speaker of M5Unified plays; the task
// is not halted with the tasks of the application. The speaker is started at
// start-up, under the lock of the I2C buses, since starting it enables the
// amplifier of some boards over the internal bus, so that the signal uses no
// bus. The host simulation logs the tones instead.

#include <M5Unified.h>

#include "tempore_scaffold.h"

#ifndef TEMPORE_HALT_TONE_HIGH_HZ
#define TEMPORE_HALT_TONE_HIGH_HZ 1000
#endif

#ifndef TEMPORE_HALT_TONE_LOW_HZ
#define TEMPORE_HALT_TONE_LOW_HZ 500
#endif

#ifndef TEMPORE_HALT_TONE_MS
#define TEMPORE_HALT_TONE_MS 150
#endif

namespace {

void tones() {
#ifdef TEMPORE_HOST
  tempore_log("Speaker: %u Hz then %u Hz, %u ms each",
              static_cast<unsigned>(TEMPORE_HALT_TONE_HIGH_HZ),
              static_cast<unsigned>(TEMPORE_HALT_TONE_LOW_HZ),
              static_cast<unsigned>(TEMPORE_HALT_TONE_MS));
#else
  // The lowest channel, which a tone on a channel chosen by M5Unified takes
  // last.
  const int channel = 0;
  M5.Speaker.tone(TEMPORE_HALT_TONE_HIGH_HZ, TEMPORE_HALT_TONE_MS, channel,
                  true);
  M5.Speaker.tone(TEMPORE_HALT_TONE_LOW_HZ, TEMPORE_HALT_TONE_MS, channel,
                  false);
#endif
}

}  // namespace

void tempore_halt_tones_begin() {
  {
    const tempore_i2c_guard guard;
    M5.Speaker.begin();
  }
  tempore_halt_signal_begin(tones);
}
