The controller of examples/arduino/bala2-controller: the M5Stack CoreS3 that
drives the BALA2 of examples/arduino/bala2-remote by its tilt over ESP-NOW,
under the rigid regular expressions of timed operations, with the packages m5-imu, m5-display, m5-touch, esp-now and bala2-remote:
its typing, its rejected variants, and its host simulation.

  $ app=../../examples/arduino/bala2-controller
  $ . ../helpers.sh
  $ from_header $app/controller.tpe
  $ packages --typecheck-only $app/controller.tpe

The rejected variants, each loaded after the application: a session that
sends Arm once, against the protocol of its grade; a drive that reads the
unit again after the touch screen and averages the pitches, so that the
first reading is no longer the latest; and a drive that redraws the Disarm
button between the touch screen and the command, which may then be sent
more than 2 ms after the reading:

  $ for v in once averaged redrawn; do packages --typecheck-only $app/controller.tpe bala2-controller/$v.tpe > out 2>&1; echo "[$?]"; grep 'error' out | cut -c 1-160; done
  [1]
  Typing error: This function's body has grade `[{(ReadTouch; SendBeat; !10.5)*; (ReadTouch | 0); (0 | SendArm; !12.5; ShowTextAt; (ReadImu; ReadTouch; SendDrive;
  [1]
  Typing error: Variable `latest` is unboxed with grade `[{ReadTouch; ReadImu}, {ReadTouch; ReadImu}]` accumulated since it was bound, which is not below its box 
  [1]
  Typing error: Variable `recent` is unboxed with grade `[{ReadTouch; DrawButton}, {ReadTouch; DrawButton}]` accumulated since it was bound, which is not below it

The PlatformIO project for the M5Stack CoreS3, its C++ sources checked
without exceptions and run-time type information:

  $ tempore --emit-arduino controller --device $app/controller.device.json $app/controller.tpe > /dev/null
  $ cd _arduino/projects/controller
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

The host simulation for 4 s, the packets sent shown when they change. The
controller sends Beat; a tap on Arm at 1 s starts the arming, Arm 20 times,
then Drive: from 1.5 s, pitched forwards by 20 degrees, a speed of
(20 - 5) * 16 = 240 counts per second; from 2.5 s, pitched backwards by 10
degrees and rolled by 15 degrees, -80 and a turn of (15 - 5) * 4 = 40; from
3 s, flat, zero. A tap on Disarm at 3.5 s sends Disarm 20 times, then Beat.
An iteration redraws at most one band:

  $ tempore --emit-arduino controller --device $app/controller.device.json --host-simulate 4 $app/controller.tpe > sim.log
  $ grep -v '^Wrote\|\] \(Release\|Start\|End \|Operation\|IMU\|I2C\|Delay\)' sim.log | awk '/ESP-NOW: sent/ { m = $0; sub(/^\[[^]]*\] /, "", m); if (m == last) next; last = m } { print }'
  [1.458 ms] Display at (254, 0): Battery 87%
  [100.000 ms] ESP-NOW: started on channel 1, address 24:0A:C4:00:00:01, peer FF:FF:FF:FF:FF:FF
  [131.000 ms] Display cleared
  [134.800 ms] Display at (0, 2): Robot remote
  [137.560 ms] Display at (80, 231): Typechecked by Tempore (tempore-lang.ee)
  [141.280 ms] Display at (0, 62): Disarmed
  [144.940 ms] Display at (0, 102): Speed
  [147.560 ms] Display at (120, 102): 0
  [151.200 ms] Display at (0, 142): Turn
  [153.820 ms] Display at (120, 142): 0
  [156.316 ms] Display fill at (0, 188), 156 by 40: 0x303030
  [157.532 ms] Display at (60, 200): Arm
  [160.028 ms] Display fill at (164, 188), 156 by 40: 0x303030
  [161.304 ms] Display at (206, 200): Disarm
  [161.704 ms] ESP-NOW: sent tag 4, 0.000, 0.000
  [162.562 ms] Display at (254, 0): Battery 87%
  [1001.004 ms] ESP-NOW: sent tag 1, 0.000, 0.000
  [1256.564 ms] Display at (0, 62): Armed
  [1257.567 ms] ESP-NOW: sent tag 2, 0.000, 0.000
  [1510.633 ms] ESP-NOW: sent tag 2, 240.000, 0.000
  [1513.293 ms] Display at (120, 102): 240
  [2502.551 ms] ESP-NOW: sent tag 2, -80.000, 40.000
  [2505.211 ms] Display at (120, 102): -80
  [2519.354 ms] Display at (120, 142): 40
  [3002.480 ms] ESP-NOW: sent tag 2, 0.000, 0.000
  [3005.100 ms] Display at (120, 142): 0
  [3019.223 ms] Display at (120, 102): 0
  [3502.349 ms] ESP-NOW: sent tag 3, 0.000, 0.000
  [3757.969 ms] Display at (0, 62): Disarmed
  [3758.369 ms] ESP-NOW: sent tag 4, 0.000, 0.000

The packets are sent at most 50 ms apart, here 10.9 to 17.2 ms, and Arm
and Disarm 20 times each:

  $ awk '/ESP-NOW: sent/ { t = substr($1, 2) + 0; if (last) { d = t - last; if (!lo || d < lo) lo = d; if (d > hi) hi = d } last = t } END { printf "%.1f %.1f\n", lo, hi }' sim.log
  10.9 17.2
  $ grep -c 'sent tag 1' sim.log; grep -c 'sent tag 3' sim.log
  20
  20
