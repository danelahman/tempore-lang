// The package bala2-remote: the sending of the status of the robot, for the
// bindings of an application that reads the state of the robot itself.

#ifndef BALA2_REMOTE_H
#define BALA2_REMOTE_H

// Queues the status of the robot to the peer, as SendStatus does: whether
// it is armed and its tilt, in degrees.
void bala2_remote_send_status(bool armed, float tilt);

#endif
