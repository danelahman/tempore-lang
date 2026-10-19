// The package bala2-remote: one operation for sending each message, over the
// packets of the package esp-now. The tags are those of remote_encode in
// bala2_remote_protocol.tpe: Arm 1, Drive 2, Disarm 3 and Beat 4, the floats
// unused by a message 0; the status of the robot is tag 5, with the code of
// its phase and the tilt.

#include "bala2_remote.h"
#include "esp_now_link.h"
#include "tempore_bindings.h"

namespace {

enum : uint32_t { arm = 1, drive = 2, disarm = 3, beat = 4, status = 5 };

}  // namespace

#ifdef TEMPORE_PERFORMS_SendArm
tempore_result_SendArm binding_SendArm(tempore_argument_SendArm) {
  esp_now_link_send(arm, 0.0f, 0.0f);
  return {};
}
#endif

#ifdef TEMPORE_PERFORMS_SendDrive
tempore_result_SendDrive binding_SendDrive(tempore_argument_SendDrive a) {
  esp_now_link_send(drive, a.c0, a.c1);
  return {};
}
#endif

#ifdef TEMPORE_PERFORMS_SendDisarm
tempore_result_SendDisarm binding_SendDisarm(tempore_argument_SendDisarm) {
  esp_now_link_send(disarm, 0.0f, 0.0f);
  return {};
}
#endif

#ifdef TEMPORE_PERFORMS_SendBeat
tempore_result_SendBeat binding_SendBeat(tempore_argument_SendBeat) {
  esp_now_link_send(beat, 0.0f, 0.0f);
  return {};
}
#endif

void bala2_remote_send_status(uint32_t phase, float tilt) {
  esp_now_link_send(status, static_cast<float>(phase), tilt);
}

#ifdef TEMPORE_PERFORMS_SendStatus
tempore_result_SendStatus binding_SendStatus(tempore_argument_SendStatus a) {
  bala2_remote_send_status(a.c0, a.c1);
  return {};
}
#endif
