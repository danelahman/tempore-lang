The controller of examples/arduino/bala2-controller: the M5Stack CoreS3 that
drives the BALA2 of examples/arduino/bala2-remote by its tilt over ESP-NOW,
under the rigid regular expressions of timed operations, with the packages m5-imu, m5-display, m5-touch, esp-now and bala2-remote:
its typing, its rejected variants, and its host simulation.

  $ app=../../examples/arduino/bala2-controller
  $ . ../helpers.sh
  $ from_header $app/controller.tpe
  $ packages --typecheck-only $app/controller.tpe

The rejected variants, each loaded after the application: a session that
sends Arm once, against the protocol of its grade; two sessions that keep
the neutral tilt recorded before the first, used after a Disarm; and a
session that redraws the screen after the handshake and then drives on its
confirmation, which may then be older than 200 ms:

  $ for v in once kept stale; do packages --typecheck-only $app/controller.tpe bala2-controller/$v.tpe > out 2>&1; echo "[$?]"; grep 'error' out | cut -c 1-160; done
  [1]
  Typing error: This function's body has grade `[{(ReadTouch; SendBeat; !10.5)*; (ReadTouch | 0); (0 | ReadImu; SendArm; !12.5; SendArm; !12.5; Receive; (SendArm;
  [1]
  Typing error: Variable `zero` is unboxed with grade `[{(SendArm; !12.5)^80; SendArm; !12.5; Receive; (SendArm; !12.5; Receive)*; (ReadImu; ReadTouch; (SendDrive
  [1]
  Typing error: Variable `fresh` is unboxed with grade `[{ClearDisplay; ShowTextAt^4; DrawButton^2}, {ClearDisplay; ShowTextAt^4; DrawButton^2}]` accumulated sinc

The PlatformIO project for the M5Stack CoreS3, its C++ sources checked
without exceptions and run-time type information:

  $ tempore --emit-arduino controller --device $app/controller.device.json $app/controller.tpe > /dev/null
  $ cd _arduino/projects/controller
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

The host simulation for 6 s, the packets sent shown when they change. The
controller sends Beat; held pitched forwards by 10 degrees, a tap on Arm
at 1 s records that tilt as neutral and starts the arming, Arm 80 times,
for 1 s, and once more until the status of the robot, scripted armed from
1.5 s at a tilt of 2.5 degrees, confirms. It then drives, measured from the
neutral tilt, and shows "Armed" and the tilt of the robot: zero at first;
from 2.2 s, pitched forwards by 30 degrees, a speed of 240 counts per
second; from 3 s, flat and rolled by 15 degrees, -80 and a turn of 40; from
3.5 s, zero. From 3.8 s the robot sends nothing for 400 ms: once its last
status is older than 50 ms, the controller sends Beat and shows "No link",
and drives again when the status returns, at a tilt of 1.5 degrees. A tap
on Disarm at 4.6 s sends Disarm 20 times, then Beat. An iteration redraws
at most one band:

  $ tempore --emit-arduino controller --device $app/controller.device.json --host-simulate 6 $app/controller.tpe > sim.log
  $ grep -v '^Wrote\|\] \(Release\|Start\|End \|Operation\|IMU\|I2C\|Delay\|ESP-NOW model\)' sim.log | awk '/ESP-NOW: sent/ { m = $0; sub(/^\[[^]]*\] /, "", m); if (m == last) next; last = m } { print }'
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
  [157.480 ms] Display at (0, 172): Robot
  [160.140 ms] Display at (120, 172): 0.0
  [162.636 ms] Display fill at (0, 188), 156 by 40: 0x303030
  [163.852 ms] Display at (60, 200): Arm
  [166.348 ms] Display fill at (164, 188), 156 by 40: 0x303030
  [167.624 ms] Display at (206, 200): Disarm
  [168.024 ms] ESP-NOW: sent tag 4, 0.000, 0.000
  [168.882 ms] Display at (254, 0): Battery 87%
  [1007.927 ms] ESP-NOW: sent tag 1, 0.000, 0.000
  [2029.430 ms] ESP-NOW: sent tag 2, 0.000, 0.000
  [2033.090 ms] Display at (0, 62): Armed
  [2070.259 ms] Display at (120, 172): 2.5
  [2208.295 ms] ESP-NOW: sent tag 2, 240.000, 0.000
  [2222.458 ms] Display at (120, 102): 240
  [3004.662 ms] ESP-NOW: sent tag 2, -80.000, 40.000
  [3018.825 ms] Display at (120, 102): -80
  [3032.968 ms] Display at (120, 142): 40
  [3504.591 ms] ESP-NOW: sent tag 2, 0.000, 0.000
  [3507.211 ms] Display at (120, 102): 0
  [3521.334 ms] Display at (120, 142): 0
  [3843.418 ms] ESP-NOW: sent tag 4, 0.000, 0.000
  [3847.118 ms] Display at (0, 62): No link
  [4203.711 ms] ESP-NOW: sent tag 2, 0.000, 0.000
  [4207.371 ms] Display at (0, 62): Armed
  [4221.534 ms] Display at (120, 172): 1.5
  [4601.133 ms] ESP-NOW: sent tag 3, 0.000, 0.000
  [4856.753 ms] Display at (0, 62): Disarmed
  [4857.153 ms] ESP-NOW: sent tag 4, 0.000, 0.000

The packets are sent at most 50 ms apart, here 10.9 to 16.6 ms, Arm 81
times and Disarm 20 times:

  $ awk '/ESP-NOW: sent/ { t = substr($1, 2) + 0; if (last) { d = t - last; if (!lo || d < lo) lo = d; if (d > hi) hi = d } last = t } END { printf "%.1f %.1f\n", lo, hi }' sim.log
  10.9 16.6
  $ grep -c 'sent tag 1' sim.log; grep -c 'sent tag 3' sim.log
  81
  20
