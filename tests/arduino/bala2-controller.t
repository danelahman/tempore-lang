The controller of examples/arduino/bala2-controller: the M5Stack CoreS3 that
drives the BALA2 of examples/arduino/bala2-remote by its tilt over ESP-NOW,
with the packages m5-imu, m5-display, m5-touch, esp-now and bala2-remote:
its typing, its rejected variants, and its host simulation.

  $ app=../../examples/arduino/bala2-controller
  $ . ../helpers.sh
  $ from_header $app/controller.tpe
  $ packages --typecheck-only $app/controller.tpe

The rejected variants, each loaded after the application: an iteration that
redraws both the speed and the turn, and one that waits 40 ms; each may
exceed the 50 ms within which the robot expects a message:

  $ for v in both slow; do packages --typecheck-only $app/controller.tpe bala2-controller/$v.tpe > out 2>&1; echo "[$?]"; grep 'error\|Note' out; done
  [1]
  Typing error: This function's body has grade `[10.8, 80.45]`, which does not match its annotated grade `[0, 50)`
    Note: the effect inequality `[10.8, 80.45] <= [0, 50)` does not hold
  [1]
  Typing error: This function's body has grade `[40.2, 76.95]`, which does not match its annotated grade `[0, 50)`
    Note: the effect inequality `[40.2, 76.95] <= [0, 50)` does not hold

The PlatformIO project for the M5Stack CoreS3, its C++ sources checked
without exceptions and run-time type information:

  $ tempore --emit-arduino controller --device $app/controller.device.json $app/controller.tpe > /dev/null
  $ cd _arduino/projects/controller
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

The host simulation for 4 s, the packets sent shown when they change. The
controller sends Beat; a tap on Arm at 1 s sends Arm for the 100 ms of the
tap and 20 further iterations, then Drive: from 1.5 s, pitched forwards by
20 degrees, a speed of (20 - 5) * 16 = 240 counts per second; from 2.5 s,
pitched backwards by 10 degrees and rolled by 15 degrees, -80 and a turn of
(15 - 5) * 4 = 40; from 3 s, flat, zero. A tap on Disarm at 3.5 s sends
Disarm likewise, then Beat. An iteration redraws at most one band:

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
  [162.307 ms] ESP-NOW: sent tag 4, 0.000, 0.000
  [162.562 ms] Display at (254, 0): Battery 87%
  [1002.026 ms] ESP-NOW: sent tag 1, 0.000, 0.000
  [1005.686 ms] Display at (0, 62): Armed
  [1339.273 ms] ESP-NOW: sent tag 2, 0.000, 0.000
  [1500.315 ms] ESP-NOW: sent tag 2, 240.000, 0.000
  [1514.478 ms] Display at (120, 102): 240
  [2503.736 ms] ESP-NOW: sent tag 2, -80.000, 40.000
  [2506.396 ms] Display at (120, 102): -80
  [2520.539 ms] Display at (120, 142): 40
  [3003.665 ms] ESP-NOW: sent tag 2, 0.000, 0.000
  [3006.285 ms] Display at (120, 142): 0
  [3020.408 ms] Display at (120, 102): 0
  [3503.534 ms] ESP-NOW: sent tag 3, 0.000, 0.000
  [3507.254 ms] Display at (0, 62): Disarmed
  [3840.841 ms] ESP-NOW: sent tag 4, 0.000, 0.000

The packets are sent at most 50 ms apart, here 11.5 to 15.2 ms:

  $ awk '/ESP-NOW: sent/ { t = substr($1, 2) + 0; if (last) { d = t - last; if (!lo || d < lo) lo = d; if (d > hi) hi = d } last = t } END { printf "%.1f %.1f\n", lo, hi }' sim.log
  11.5 15.2
