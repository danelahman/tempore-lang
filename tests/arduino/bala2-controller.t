The controller of examples/arduino/bala2-controller: the M5Stack CoreS3 that
drives the BALA2 of examples/arduino/bala2-remote by its tilt over ESP-NOW,
under the rigid regular expressions of timed operations, with the packages m5-imu, m5-display, m5-touch, m5-speaker, esp-now and bala2-remote:
its typing, its rejected variants, and its host simulation.

  $ app=../../examples/arduino/bala2-controller
  $ . ../helpers.sh
  $ from_header $app/controller.tpe
  $ packages --typecheck-only $app/controller.tpe

The rejected variants, each loaded after the application: an armed
iteration that redraws the bubble after the readings and then drives on
the reading of the unit, which may then be older than 2 ms; two sessions
that keep the neutral tilt recorded before the first, used after a Disarm;
a session that redraws the screen after the handshake and then drives on
its confirmation, which may then be older than 200 ms; and a session that
sends Arm once, against the protocol of its grade:

  $ for v in redrawn kept stale once; do packages --typecheck-only $app/controller.tpe bala2-controller/$v.tpe > out 2>&1; echo "[$?]"; grep 'error' out | cut -c 1-160; done
  [1]
  Typing error: Variable `latest_reading` is unboxed with grade `{ReadTouch; DrawLevel}` accumulated since it was bound, which is not below its box grade `{[0, 2]
  [1]
  Typing error: Variable `zero` is unboxed with grade `{(SendArm; !12.5)^80; SendArm; !12.5; Receive; (SendArm; !12.5; Receive)*; (ReadImu; ReadTouch; (SendBeat |
  [1]
  Typing error: Variable `latest` is unboxed with grade `{ClearDisplay; ShowTextAt^4; DrawButton^2}` accumulated since it was bound, which is not below its box gr
  [1]
  Typing error: This function's body has grade `{(ReadTouch; SendBeat; DrawLevel?; !10.5)*; ReadTouch?; (Beep; ReadImu; SendArm; !12.5; SendArm; !12.5; Receive; (

The PlatformIO project for the M5Stack CoreS3, its C++ sources checked
without exceptions and run-time type information:

  $ tempore --emit-arduino controller --device $app/controller.device.json $app/controller.tpe > /dev/null
  $ cd _arduino/projects/controller
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp

Paired with the robot by the build flags ESP_NOW_PEER and ESP_NOW_KEY, here
a fake key, the link is encrypted, which the controller shows right of the
vial:

  $ c++ -std=c++17 -Wall -Wextra -Werror -ffp-contract=off -DTEMPORE_HOST -DESP_NOW_PEER=0x24,0x0a,0xc4,0x00,0x00,0x07 -DESP_NOW_KEY=000102030405060708090a0b0c0d0e0f -pthread -I host -I src src/*.cpp host/*.cpp -o simulation
  $ ./simulation 200000 | grep 'ESP-NOW: started\|(130, 152)'
  [100.000 ms] ESP-NOW: started on channel 1, address 24:0A:C4:00:00:01, peer 24:0A:C4:00:00:07, encrypted (CCMP)
  [150.040 ms] Display at (130, 152): Encrypted
  $ cd ../../..

The host simulation for 6 s, the packets sent shown when they change. The
controller shows that the link, to the broadcast address, is not encrypted,
and sends Beat; held pitched forwards by 10 degrees, a tap on Arm at 1 s,
acknowledged by a tone of 1760 Hz, records that tilt as neutral and starts
the arming, Arm 80 times, for 1 s, and once more until the status of the
robot, scripted armed from 1.5 s at a tilt of 2.5 degrees, confirms. It then
drives, measured from the neutral tilt, and shows "Armed", the tilt of the
robot and a green bubble in the vial centred at (62, 122): zero at first,
the bubble centred; from 2.2 s, pitched forwards by 30 degrees, 20 beyond
the neutral tilt, a speed of -240 counts per second, forwards for the robot,
the bubble 33 pixels up (14 for the dead zone and 15 / 25 of the remaining
32); from 3 s, flat and rolled to the right by 15 degrees, a speed of 80,
backwards, and a turn of 40, to the right, the bubble 20 pixels down and 27
right; from 3.5 s, zero, the bubble centred. From 3.8 s the robot sends
nothing for 400 ms: once its last status is older than 50 ms, the controller
sends Beat and shows "No link" and a grey bubble, and drives again when the
status returns, at a tilt of 1.5 degrees. While disarmed the bubble is
centred and dark grey. A tap on Disarm at 4.6 s, acknowledged by a tone of
880 Hz, sends Disarm 20 times, then Beat. An iteration redraws at most one
band:

  $ tempore --emit-arduino controller --device $app/controller.device.json --host-simulate 6 $app/controller.tpe > sim.log
  $ grep -v '^Wrote\|\] \(Release\|Start\|End \|Operation\|IMU\|I2C\|Delay\|ESP-NOW model\)' sim.log | awk '/ESP-NOW: sent/ { m = $0; sub(/^\[[^]]*\] /, "", m); if (m == last) next; last = m } { print }'
  [1.458 ms] Display at (254, 0): Battery 87%
  [100.000 ms] ESP-NOW: started on channel 1, address 24:0A:C4:00:00:01, peer FF:FF:FF:FF:FF:FF, not encrypted
  [131.000 ms] Display cleared
  [134.800 ms] Display at (0, 2): Robot remote
  [137.560 ms] Display at (80, 231): Typechecked by Tempore (tempore-lang.ee)
  [141.280 ms] Display at (0, 32): Disarmed
  [144.000 ms] Display at (130, 82): Robot tilt
  [147.340 ms] Display at (130, 113): 0.0
  [150.120 ms] Display at (130, 152): Not encrypted
  [152.616 ms] Display fill at (0, 188), 156 by 40: 0x303030
  [153.832 ms] Display at (60, 200): Arm
  [156.328 ms] Display fill at (164, 188), 156 by 40: 0x303030
  [157.604 ms] Display at (206, 200): Disarm
  [158.004 ms] ESP-NOW: sent tag 4, 0.000, 0.000
  [158.862 ms] Display at (254, 0): Battery 87%
  [159.138 ms] Display disc at (62, 122), radius 9: 0x404040
  [1009.288 ms] Speaker: 1760 Hz for 60 ms
  [1009.991 ms] ESP-NOW: sent tag 1, 0.000, 0.000
  [2031.494 ms] ESP-NOW: sent tag 2, 0.000, 0.000
  [2035.154 ms] Display at (0, 32): Armed
  [2047.034 ms] Display disc at (62, 122), radius 9: 0x00c000
  [2061.877 ms] Display at (130, 113): 2.5
  [2211.416 ms] ESP-NOW: sent tag 2, -240.000, 0.000
  [2211.793 ms] Display disc at (62, 89), radius 9: 0x00c000
  [3005.500 ms] ESP-NOW: sent tag 2, 80.000, 40.000
  [3017.380 ms] Display disc at (89, 142), radius 9: 0x00c000
  [3500.506 ms] ESP-NOW: sent tag 2, 0.000, 0.000
  [3500.883 ms] Display disc at (62, 122), radius 9: 0x00c000
  [3834.470 ms] ESP-NOW: sent tag 4, 0.000, 0.000
  [3838.170 ms] Display at (0, 32): No link
  [3861.553 ms] Display disc at (62, 122), radius 9: 0x808080
  [4206.643 ms] ESP-NOW: sent tag 2, 0.000, 0.000
  [4210.303 ms] Display at (0, 32): Armed
  [4222.183 ms] Display disc at (62, 122), radius 9: 0x00c000
  [4237.026 ms] Display at (130, 113): 1.5
  [4605.072 ms] Speaker: 880 Hz for 60 ms
  [4605.172 ms] ESP-NOW: sent tag 3, 0.000, 0.000
  [4860.792 ms] Display at (0, 32): Disarmed
  [4861.192 ms] ESP-NOW: sent tag 4, 0.000, 0.000
  [4861.569 ms] Display disc at (62, 122), radius 9: 0x404040

The packets are sent at most 50 ms apart, here 10.9 to 16.6 ms, Arm 81
times and Disarm 20 times:

  $ awk '/ESP-NOW: sent/ { t = substr($1, 2) + 0; if (last) { d = t - last; if (!lo || d < lo) lo = d; if (d > hi) hi = d } last = t } END { printf "%.1f %.1f\n", lo, hi }' sim.log
  10.9 16.6
  $ grep -c 'sent tag 1' sim.log; grep -c 'sent tag 3' sim.log
  81
  20
