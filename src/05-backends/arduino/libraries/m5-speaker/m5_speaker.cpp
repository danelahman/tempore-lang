// The package m5-speaker: tones on the speaker of an M5Stack core, through
// M5Unified. The speaker is started at initialisation, under the I2C lock,
// since starting it enables the amplifier of the CoreS3 over the internal
// bus; a tone is then queued to the task of the speaker of M5Unified, which
// plays it, and the call returns at once.

#include <M5Unified.h>

#include "tempore_bindings.h"

void m5_speaker_init() {
  const tempore_i2c_guard guard;
  M5.Speaker.begin();
}

#ifdef TEMPORE_PERFORMS_Beep
tempore_result_Beep binding_Beep(tempore_argument_Beep tone) {
  M5.Speaker.tone(static_cast<float>(tone.c0), tone.c1);
  return {};
}
#endif
