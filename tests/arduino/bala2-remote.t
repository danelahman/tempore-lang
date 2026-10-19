The BALA2 application of examples/arduino/bala2-remote: the balancing robot
driven by a controller over ESP-NOW, under the rigid regular expressions of
timed operations, with the packages esp-now and bala2-remote and the binding
file and host model of examples/arduino/bala2:
its typing, its rejected variants, and its host simulation with a scripted
controller.

  $ app=../../examples/arduino/bala2-remote
  $ . ../helpers.sh
  $ from_header $app/balance_remote.tpe
  $ packages --typecheck-only $app/balance_remote.tpe

The rejected variants, each loaded after the application: a session that
reads the tilt before the wait for Arm and arms the robot on it, outside
the arming window; a session that commands zero setpoints before the
arming, within the box of the calibration; an iteration that polls again
before it applies the message received first, no longer the latest; a
session that opens the arming window right after the hold and arms the
robot after the wait for Arm; and a measurement that checks the robot at
rest before it disarms it and samples the readings after the Disarm:

  $ for v in stale_tilt stopped polled early unsettled; do packages --typecheck-only $app/balance_remote.tpe bala2-remote/$v.tpe > out 2>&1; echo "[$?]"; grep 'error' out; done
  [1]
  Typing error: Variable `arming` is unboxed with the unit grade `{0}` accumulated since it was bound, which is not below its box grade `{Attitude; ([0, 1) & ~(Command | Receive))}`
  [1]
  Typing error: Variable `calibrated` is unboxed with grade `{ShowTextAt; !1000; (Receive; Report; !400)^[1, 500]; Command}` accumulated since it was bound, which is not below its box grade `{[1000, 600000] & ~Command}`
  [1]
  Typing error: Variable `latest` is unboxed with grade `{Receive; Disarm?}` accumulated since it was bound, which is not below its box grade `{[0, 150) & ~Receive}`
  [1]
  Typing error: Variable `arming` is unboxed with grade `{(Receive; Report; !400)^[1, 500]}` accumulated since it was bound, which is not below its box grade `{Attitude; ([0, 1) & ~(Command | Receive))}`
  [1]
  Typing error: Variable `checked` is unboxed with grade `{Disarm; (Reading; !10)*}` accumulated since it was bound, which is not below its box grade `{(Reading; !10)*}`

The PlatformIO project for the M5Stack Gray with its radio running (profile
m5stack-gray-radio), its C++ sources checked without exceptions and run-time
type information:

  $ tempore --emit-arduino balance_remote --device $app/balance_remote.device.json $app/balance_remote.tpe > /dev/null
  $ cd _arduino/projects/balance_remote
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

Under the bounds of m5stack-gray-radio the step takes up to 7.2 ms, so that
the period of 5 ms of the BALA2 without the radio is rejected:

  $ sed -e 's/"period": 8,/"period": 5,/' -e "s|\"\.\./bala2/|\"$app/../bala2/|g" -e "s|\"controller\.cpp\"|\"$app/controller.cpp\"|" $app/balance_remote.device.json > period.device.json
  $ tempore --emit-arduino balance_period --device period.device.json $app/balance_remote.tpe 2>&1 | grep error
  Compilation error: The effect `{ReadImu; ReadEncoders; Setpoints; Publish; SetMotors}` of the function `step` of a periodic task is not below its period: its durations are not all below 5

The host simulation for 12 s. The controller sends Beat until 1.5 s, Arm
for 1 s, Drive (100, 0) from 2.5 s, Disarm at 3.5 s, Beat, Arm again for
1 s from 6.2 s, Drive (-100, 0) from 7.2 s, nothing from 7.6 s, and Beat
again from 10 s. The robot is armed once it is calibrated at rest, held
upright and a poll finds Arm, and disarmed at the Disarm; it then falls, so
that the at-rest check fails and it shows "Hold still", until the user
stands it up at 3.8 s and holds it still; it is calibrated anew, armed
again and balances; it shows "Link lost" and beeps about 2 s after the last
message, staying armed, and "Armed" again when messages return. Its status,
sent at each poll and each iteration of the drive, is shown when its arming
changes. The gyroscope of the plant reads a constant bias of 25 degrees per
second about its y axis, which the check at rest, judging the variation of
the readings, admits. The tilts of the plant, whose digits depend on the C
library, are not shown:

  $ tempore --emit-arduino balance_remote --device $app/balance_remote.device.json --host-simulate 12 $app/balance_remote.tpe | grep -v '^Wrote\|\] \(Release\|Start\|End step\|Operation\|IMU\|I2C\|Delay\|ESP-NOW model\)\|Plant: \(tilt\|largest\)' | awk '/ESP-NOW: sent tag 5,/ { a = $7; sub(/,$/, "", a); if (a == last) next; last = a; print $1, $2, "ESP-NOW: status, armed " a; next } { print }'
  [31.245 ms] Display cleared
  [35.045 ms] Display at (0, 2): Remote robot
  [37.805 ms] Display at (80, 231): Typechecked by Tempore (tempore-lang.ee)
  [41.585 ms] Display at (0, 102): Calibrating
  [100.245 ms] ESP-NOW: started on channel 1, address 24:0A:C4:00:00:01, peer FF:FF:FF:FF:FF:FF, not encrypted
  [563.988 ms] Display at (0, 102): Hold upright
  [1567.848 ms] Display at (0, 102): Waiting for Arm
  [1567.948 ms] ESP-NOW: status, armed 0.000
  [1971.608 ms] Display at (0, 102): Armed
  [1971.708 ms] ESP-NOW: status, armed 1.000
  [3525.028 ms] Display at (0, 102): Disarmed
  [3528.808 ms] Display at (0, 102): Calibrating
  [4051.171 ms] Display at (0, 102): Hold still
  [4554.951 ms] Display at (0, 102): Calibrating
  [5077.354 ms] Display at (0, 102): Hold upright
  [6081.214 ms] Display at (0, 102): Waiting for Arm
  [6081.314 ms] ESP-NOW: status, armed 0.000
  [6885.074 ms] Display at (0, 102): Armed
  [6885.174 ms] ESP-NOW: status, armed 1.000
  [9648.214 ms] Display at (0, 102): Link lost
  [9648.264 ms] Speaker: 880 Hz for 200 ms
  [10017.324 ms] Display at (0, 102): Armed
  [12000.000 ms] End of the simulation
  [12000.000 ms] Plant: released at 6886.0 ms

Held askew at 0.5 rad (28.6 degrees) from the start, the robot is
calibrated, since it is held still, but not armed at the Arm of 1.5 s: the
published tilt lies beyond the 10 degrees of upright_limit, and the session
shows "Not upright" and calibrates anew; the body, released at 2 s, falls
during that calibration, which therefore shows "Hold still"; the motors are
not driven:

  $ cd _arduino/projects/balance_remote
  $ c++ -std=c++17 -ffp-contract=off -DTEMPORE_HOST -DTEMPORE_TRACE -DPLANT_TILT=0.5 -pthread -I host -I src src/*.cpp host/*.cpp -o askew
  $ ./askew 3000000 | grep 'Display at (0, 102)\|motors were never'
  [41.585 ms] Display at (0, 102): Calibrating
  [563.988 ms] Display at (0, 102): Hold upright
  [1567.848 ms] Display at (0, 102): Waiting for Arm
  [1971.728 ms] Display at (0, 102): Not upright
  [1975.508 ms] Display at (0, 102): Calibrating
  [2497.871 ms] Display at (0, 102): Hold still
  [3000.000 ms] Plant: the motors were never driven

Held and turned steadily by 0.1 rad/s (5.7 degrees per second), the robot
is never calibrated: the rate is constant, so that the spread of the rates
and CheckAtRest admit it, but the direction of gravity turns by more than
the 2 degrees of rest_cosine over the samples:

  $ c++ -std=c++17 -ffp-contract=off -DTEMPORE_HOST -DTEMPORE_TRACE -DPLANT_HELD_RATE=0.1 -pthread -I host -I src src/*.cpp host/*.cpp -o turned
  $ ./turned 1900000 | grep 'Display at (0, 102)\|motors were never'
  [41.585 ms] Display at (0, 102): Calibrating
  [563.948 ms] Display at (0, 102): Hold still
  [1067.728 ms] Display at (0, 102): Calibrating
  [1590.679 ms] Display at (0, 102): Hold still
  [1900.000 ms] Plant: the motors were never driven
  $ cd ../../..

