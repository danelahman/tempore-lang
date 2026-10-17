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
commands zero setpoints before it waits for Arm, a motion after the
calibration; a session that waits for Arm without a bound, so that the
calibration may be older than 10 minutes; and an iteration that polls again
before it applies the message received first, no longer the latest:

  $ for v in commanding waited polled; do packages --typecheck-only $app/balance_remote.tpe bala2-remote/$v.tpe > out 2>&1; echo "[$?]"; grep 'error' out; done
  [1]
  Typing error: Variable `still` is unboxed with grade `[{ShowTextAt; !1000; Command; (Receive; Report; !400)^[1, 500]}, {ShowTextAt; !1000; Command; (Receive; Report; !400)^[1, 500]}]` accumulated since it was bound, which is not below its box grade `[{(!_ & ~Command)*}, {(!_ & ~Command)*}]`
  [1]
  Typing error: Variable `aged` is unboxed with grade `[{ShowTextAt; !1000; (Receive; Report; !400)*; (Receive | 0)}, {ShowTextAt; !1000; (Receive; Report; !400)*; (Receive | 0)}]` accumulated since it was bound, which is not below its box grade `[{[1000, ∞)}, {[0, 600000]}]`
  [1]
  Typing error: Variable `latest` is unboxed with grade `[{Receive; (0 | Disarm)}, {Receive; (0 | Disarm)}]` accumulated since it was bound, which is not below its box grade `[{(!_ & ~Receive)*}, {(!_ & ~Receive)*}]`

The PlatformIO project for the M5Stack Gray, its C++ sources checked without
exceptions and run-time type information:

  $ tempore --emit-arduino balance_remote --device $app/balance_remote.device.json $app/balance_remote.tpe > /dev/null
  $ cd _arduino/projects/balance_remote
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

The host simulation for 10 s. The controller sends Beat until 1.5 s, Arm
for 1 s, Drive (100, 0) from 2.5 s, Disarm at 3.5 s, Beat, Arm again for
1 s from 5 s, Drive (-100, 0) from 6 s, nothing from 6.3 s, and Beat again
from 8.8 s. The robot is armed once it is calibrated, held upright and a
poll finds Arm, disarmed at the Disarm, calibrated anew and armed again; it
shows "Link lost" and beeps about 2 s after the last message, staying
armed, and "Armed" again when messages return. Its status, sent at each
poll and each iteration of the drive, is shown when its arming changes.
After the Disarm the robot falls, and the step no longer drives the motors
beyond the cutoff. The tilts of the plant, whose digits depend on the C
library, are not shown:

  $ tempore --emit-arduino balance_remote --device $app/balance_remote.device.json --host-simulate 10 $app/balance_remote.tpe | grep -v '^Wrote\|\] \(Release\|Start\|End step\|Operation\|IMU\|I2C\|Delay\|ESP-NOW model\)\|Plant: \(tilt\|largest\)' | awk '/ESP-NOW: sent tag 5,/ { a = $7; sub(/,$/, "", a); if (a == last) next; last = a; print $1, $2, "ESP-NOW: status, armed " a; next } { print }'
  [31.245 ms] Display cleared
  [35.045 ms] Display at (0, 2): Remote robot
  [37.805 ms] Display at (80, 231): Typechecked by Tempore (tempore-lang.ee)
  [41.585 ms] Display at (0, 102): Calibrating
  [100.245 ms] ESP-NOW: started on channel 1, address 24:0A:C4:00:00:01, peer FF:FF:FF:FF:FF:FF
  [545.385 ms] Display at (0, 102): Hold upright
  [1549.245 ms] Display at (0, 102): Waiting for Arm
  [1549.345 ms] ESP-NOW: status, armed 0.000
  [1953.005 ms] Display at (0, 102): Armed
  [1953.105 ms] ESP-NOW: status, armed 1.000
  [3519.025 ms] Display at (0, 102): Disarmed
  [3522.805 ms] Display at (0, 102): Calibrating
  [4026.605 ms] Display at (0, 102): Hold upright
  [5030.465 ms] Display at (0, 102): Waiting for Arm
  [5030.565 ms] ESP-NOW: status, armed 0.000
  [5434.225 ms] Display at (0, 102): Armed
  [5434.325 ms] ESP-NOW: status, armed 1.000
  [8348.565 ms] Display at (0, 102): Link lost
  [8348.615 ms] Speaker: 880 Hz for 200 ms
  [8805.875 ms] Display at (0, 102): Armed
  [10000.000 ms] End of the simulation
  [10000.000 ms] Plant: released at 1952.0 ms
