// The package bala2-base: the last values exchanged with the base of the
// M5Stack BALA2, for logging by the application outside its timed bindings.
// Each value is read atomically; the two values of a pair may come from
// consecutive transactions.

#ifndef BALA2_BASE_H
#define BALA2_BASE_H

#include <stdint.h>

// The drives of the motors last written to the base, by SetMotors or by a
// stop of the motors; zero before the first.
void bala2_last_drives(int16_t *left, int16_t *right);

// The counts of the encoders last read by ReadEncoders, as it returns them;
// zero before the first.
void bala2_last_counts(int32_t *left, int32_t *right);

#endif
