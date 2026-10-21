The BALA2 application of examples/arduino/bala2-radio-robot: the balancing robot
driven by a controller over ESP-NOW, under the rigid regular expressions of
timed operations, with the packages esp-now and bala2-radio and the binding
file and host model of examples/arduino/bala2:
its typing, its rejected variants, and its host simulation with a scripted
controller.

  $ app=../../examples/arduino/bala2-radio-robot
  $ . ../helpers.sh
  $ from_header $app/robot.tpe
  $ packages --typecheck-only $app/robot.tpe

The rejected variants, each loaded after the application: a session that
reads the tilt before the wait for Start and starts the balancing on it,
outside the start window; a session that moves with zero setpoints before
the start, within the box of the calibration; an iteration that polls again
before it applies the message received first, no longer the latest; a
session that opens the start window right after the hold and starts the
balancing after the wait for Start; and a measurement that checks the robot
at rest before it stops the balancing and samples the readings after the
StopBalancing:

  $ for v in stale_tilt stopped polled early unsettled; do packages --typecheck-only $app/robot.tpe bala2-radio-robot/$v.tpe > out 2>&1; echo "[$?]"; grep 'error' out; done
  [1]
  Typing error: Variable `starting` is unboxed with the unit grade `{0}` accumulated since it was bound, which is not below its box grade `{LatestTilt; ([0, 1) & ~(Move | ReceiveMessage))}`
  [1]
  Typing error: Variable `calibrated` is unboxed with grade `{ReportStatus; ShowTextAt; !500; ReportStatus; !500; ShowTextAt; Beep; (ReceiveMessage; ReportStatus; !400)^[1, 500]; Move}` accumulated since it was bound, which is not below its box grade `{[1000, 600000] & ~Move}`
  [1]
  Typing error: Variable `latest` is unboxed with grade `{ReceiveMessage; StopBalancing?}` accumulated since it was bound, which is not below its box grade `{[0, 150) & ~ReceiveMessage}`
  [1]
  Typing error: Variable `starting` is unboxed with grade `{(ReceiveMessage; ReportStatus; !400)^[1, 500]}` accumulated since it was bound, which is not below its box grade `{LatestTilt; ([0, 1) & ~(Move | ReceiveMessage))}`
  [1]
  Typing error: Variable `checked` is unboxed with grade `{StopBalancing; (Reading; !10)*}` accumulated since it was bound, which is not below its box grade `{(Reading; !10)*}`

The PlatformIO project for the M5Stack Gray with its radio running (profile
m5stack-gray-radio), its C++ sources checked without exceptions and run-time
type information:

  $ tempore --emit-arduino robot --device $app/robot.device.json $app/robot.tpe > /dev/null
  $ cd _arduino/projects/robot
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

Under the bounds of m5stack-gray-radio the step takes up to 4.6 ms, so that
its period of 5 ms is the least whole number of milliseconds, and 4 ms is
rejected:

  $ sed -e 's/"period": 5,/"period": 4,/' -e "s|\"\.\./bala2/|\"$app/../bala2/|g" -e "s|\"controller\.cpp\"|\"$app/controller.cpp\"|" $app/robot.device.json > period.device.json
  $ tempore --emit-arduino balance_period --device period.device.json $app/robot.tpe 2>&1 | grep error
  Compilation error: The effect `{ReadImu; ReadEncoders; Setpoints; Publish; SetMotors}` of the function `step` of a periodic task is not below its period: its durations are not all below 4

The host simulation for 12 s. The controller sends Beat until 1.5 s, Start
for 1 s, Drive (100, 0) from 2.5 s, Stop at 3.5 s, Beat, Start again for
1 s from 6.2 s, Drive (-100, 0) from 7.2 s, nothing from 7.6 s, and Beat
again from 10 s. The robot starts the link before its first step and its
first report, is calibrated at rest, held upright, beeps at 2 kHz when it
waits for Start, is started once a poll finds Start, and stopped at the
Stop; it then falls, so that the at-rest check
fails and it shows "Hold still", until the user stands it up at 3.8 s and
holds it still; it is calibrated anew, beeps, is started again and balances;
it shows "Link lost" and beeps at 880 Hz about 2 s after the last message,
still balancing, and "Balancing" again when messages return. Its status, sent at
each check at rest, at each failed check, twice in the hold, at each poll
and at each iteration of the drive, is shown when its phase changes: 2
calibrating, 3 calibrating after a failed check, 0 ready for Start, 1
balancing. The gyroscope of the plant reads a constant bias of 25 degrees per
second about its y axis, which the check at rest, judging the variation of
the readings, admits. The tilts of the plant, whose digits depend on the C
library, are not shown:

  $ tempore --emit-arduino robot --device $app/robot.device.json --host-simulate 12 $app/robot.tpe | grep -v '^Wrote\|\] \(Release\|Start\|End step\|Operation\|IMU\|I2C\|Delay\|ESP-NOW model\)\|Plant: \(tilt\|largest\)' | awk '/ESP-NOW: sent tag 5,/ { a = $7; sub(/,$/, "", a); if (a == last) next; last = a; print $1, $2, "ESP-NOW: status, phase " a; next } { print }'
  [31.245 ms] Display cleared
  [35.045 ms] Display at (0, 2): Remote robot
  [37.013 ms] Display at (188, 231): Typechecked by Tempore
  [88.245 ms] ESP-NOW: started on channel 1, address 24:0A:C4:00:00:01, peer 24:0A:C4:00:00:02, encrypted (CCMP)
  [100.793 ms] Display at (0, 102): Calibrating
  [100.893 ms] ESP-NOW: status, phase 2.000
  [623.396 ms] Display at (0, 102): Hold upright
  [1627.396 ms] Display at (0, 102): Waiting for Start
  [1627.546 ms] Speaker: 2000 Hz for 80 ms
  [1627.646 ms] ESP-NOW: status, phase 0.000
  [2031.386 ms] Display at (0, 102): Balancing
  [2031.486 ms] ESP-NOW: status, phase 1.000
  [3534.386 ms] Display at (0, 102): Stopped
  [3538.166 ms] Display at (0, 102): Calibrating
  [3538.266 ms] ESP-NOW: status, phase 2.000
  [4056.969 ms] ESP-NOW: status, phase 3.000
  [4060.729 ms] Display at (0, 102): Hold still
  [4564.509 ms] Display at (0, 102): Calibrating
  [5083.312 ms] ESP-NOW: status, phase 2.000
  [5087.112 ms] Display at (0, 102): Hold upright
  [6091.112 ms] Display at (0, 102): Waiting for Start
  [6091.262 ms] Speaker: 2000 Hz for 80 ms
  [6091.362 ms] ESP-NOW: status, phase 0.000
  [6895.202 ms] Display at (0, 102): Balancing
  [6895.302 ms] ESP-NOW: status, phase 1.000
  [9658.342 ms] Display at (0, 102): Link lost
  [9658.492 ms] Speaker: 880 Hz for 200 ms
  [10015.032 ms] Display at (0, 102): Balancing
  [12000.000 ms] End of the simulation
  [12000.000 ms] Plant: released at 6895.0 ms

Held askew at 0.5 rad (28.6 degrees) from the start, the robot is
calibrated, since it is held still, but not started at the Start of 1.5 s: the
published tilt lies beyond the 10 degrees of upright_limit, and the session
shows "Not upright" and calibrates anew; the body, released at 2 s, falls
during that calibration, which therefore shows "Hold still"; the motors are
not driven:

  $ cd _arduino/projects/robot
  $ c++ -std=c++17 -ffp-contract=off -DTEMPORE_HOST -DTEMPORE_TRACE -DPLANT_TILT=0.5 -pthread -I host -I src src/*.cpp host/*.cpp -o askew
  $ ./askew 3000000 | grep 'Display at (0, 102)\|motors were never'
  [100.793 ms] Display at (0, 102): Calibrating
  [623.396 ms] Display at (0, 102): Hold upright
  [1627.396 ms] Display at (0, 102): Waiting for Start
  [2031.426 ms] Display at (0, 102): Not upright
  [2035.206 ms] Display at (0, 102): Calibrating
  [2557.769 ms] Display at (0, 102): Hold still
  [3000.000 ms] Plant: the motors were never driven

Held and turned steadily by 0.1 rad/s (5.7 degrees per second), the robot
is never calibrated: the rate is constant, so that the spread of the rates
and CheckAtRest admit it, but the direction of gravity turns by more than
the 2 degrees of rest_cosine over the samples:

  $ c++ -std=c++17 -ffp-contract=off -DTEMPORE_HOST -DTEMPORE_TRACE -DPLANT_HELD_RATE=0.1 -pthread -I host -I src src/*.cpp host/*.cpp -o turned
  $ ./turned 1900000 | grep 'Display at (0, 102)\|motors were never'
  [100.793 ms] Display at (0, 102): Calibrating
  [623.356 ms] Display at (0, 102): Hold still
  [1127.136 ms] Display at (0, 102): Calibrating
  [1649.779 ms] Display at (0, 102): Hold still
  [1900.000 ms] Plant: the motors were never driven
  $ cd ../../..

