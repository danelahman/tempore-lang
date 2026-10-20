// The package bala2-radio: the sending of the status of the robot, for the
// bindings of an application that reads the state of the robot itself.

#ifndef BALA2_RADIO_H
#define BALA2_RADIO_H

#include <stdint.h>

// Queues the status of the robot to the peer, as SendStatus does: the code
// of its phase, as remote_phase_code of bala2_radio_protocol.tpe gives it,
// and its tilt, in degrees.
void bala2_radio_send_status(uint32_t phase, float tilt);

#endif
