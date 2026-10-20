// The package bala2-radio: one operation for sending each message, over the
// packets of the package esp-now. The tags are those of remote_encode in
// bala2_radio_protocol.tpe: Start 1, Drive 2, Stop 3 and Beat 4, the floats
// unused by a message 0; the status of the robot is tag 5, with the code of
// its phase and the tilt.

#include "bala2_radio.h"
#include "esp_now_link.h"
#include "tempore_bindings.h"

namespace {

enum : uint32_t { start = 1, drive = 2, stop = 3, beat = 4, status = 5 };

}  // namespace

#ifdef TEMPORE_PERFORMS_SendStart
tempore_result_SendStart binding_SendStart(tempore_argument_SendStart) {
  esp_now_link_send(start, 0.0f, 0.0f);
  return {};
}
#endif

#ifdef TEMPORE_PERFORMS_SendDrive
tempore_result_SendDrive binding_SendDrive(tempore_argument_SendDrive a) {
  esp_now_link_send(drive, a.c0, a.c1);
  return {};
}
#endif

#ifdef TEMPORE_PERFORMS_SendStop
tempore_result_SendStop binding_SendStop(tempore_argument_SendStop) {
  esp_now_link_send(stop, 0.0f, 0.0f);
  return {};
}
#endif

#ifdef TEMPORE_PERFORMS_SendBeat
tempore_result_SendBeat binding_SendBeat(tempore_argument_SendBeat) {
  esp_now_link_send(beat, 0.0f, 0.0f);
  return {};
}
#endif

void bala2_radio_send_status(uint32_t phase, float tilt) {
  esp_now_link_send(status, static_cast<float>(phase), tilt);
}

#ifdef TEMPORE_PERFORMS_SendStatus
tempore_result_SendStatus binding_SendStatus(tempore_argument_SendStatus a) {
  bala2_radio_send_status(a.c0, a.c1);
  return {};
}
#endif
