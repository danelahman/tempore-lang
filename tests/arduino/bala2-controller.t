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
  Typing error: This function's body has grade `{(ReadTouch; SendBeat; Receive; (DrawLevel | ShowColourTextAt)?; !10.5)*; ReadTouch?; (Beep; ReadImu; SendArm; !12

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

The host simulation for 9 s, the packets sent shown when they change. The
controller shows that the link, to the fixed peer of the host model under
its fixed key, is encrypted, and sends Beat; the robot, scripted ready for Arm, is shown as such in the
guidance line at (0, 54); held pitched forwards by 10 degrees, a tap on Arm at 1 s,
acknowledged by a tone of 1760 Hz, records that tilt as neutral and starts
the arming, Arm 80 times, for 1 s, and once more until the status of the
robot, scripted armed from 1.5 s at a tilt of 2.5 degrees, confirms. It then
drives, measured from the neutral tilt, and shows "Armed", the tilt of the
robot and a green bubble in the vial centred at (62, 122): zero at first,
the bubble centred, the guidance line cleared; from 2.2 s, pitched forwards by 30 degrees, 20 beyond
the neutral tilt, a speed of -240 counts per second, forwards for the robot,
the bubble 33 pixels up (14 for the dead zone and 15 / 25 of the remaining
32); from 3 s, flat and rolled to the right by 15 degrees, a speed of 80,
backwards, and a turn of -40, to the right, the bubble 20 pixels down and 27
right; from 3.5 s, zero, the bubble centred. From 3.8 s the robot sends
nothing for 400 ms: once its last status is older than 50 ms, the controller
sends Beat and shows "No link" and a grey bubble, and drives again when the
status returns, at a tilt of 1.5 degrees. While disarmed the bubble is
centred and dark grey. A tap on Disarm at 4.6 s, acknowledged by a tone of
880 Hz, sends Disarm 20 times, then Beat. The guidance line then follows
the status of the robot, scripted armed until 4.9 s, calibrating, held
unsteadily from 5.6 s, calibrating again from 6.3 s, ready for Arm from 7 s
and silent from 7.6 s, about 1 s after which it shows "Switch on the
robot". An iteration redraws at most one band:

  $ tempore --emit-arduino controller --device $app/controller.device.json --host-simulate 9 $app/controller.tpe > sim.log
  $ grep -v '^Wrote\|\] \(Release\|Start\|End \|Operation\|IMU\|I2C\|Delay\|ESP-NOW model\)' sim.log | awk '/ESP-NOW: sent/ { m = $0; sub(/^\[[^]]*\] /, "", m); if (m == last) next; last = m } { print }'
  [1.458 ms] Display at (254, 0): Battery 87%
  [100.000 ms] ESP-NOW: started on channel 1, address 24:0A:C4:00:00:01, peer 24:0A:C4:00:00:02, encrypted (CCMP)
  [131.000 ms] Display cleared
  [134.800 ms] Display at (0, 2): Robot remote
  [137.560 ms] Display at (80, 231): Typechecked by Tempore (tempore-lang.ee)
  [141.280 ms] Display at (0, 32): Disarmed
  [144.000 ms] Display at (130, 82): Robot tilt
  [147.340 ms] Display at (130, 113): 0.0
  [150.040 ms] Display at (130, 152): Encrypted
  [152.536 ms] Display fill at (0, 188), 156 by 40: 0x303030
  [153.752 ms] Display at (60, 200): Arm
  [156.248 ms] Display fill at (164, 188), 156 by 40: 0x303030
  [157.524 ms] Display at (206, 200): Disarm
  [157.924 ms] ESP-NOW: sent tag 4, 0.000, 0.000
  [158.782 ms] Display at (254, 0): Battery 87%
  [159.058 ms] Display disc at (62, 122), radius 9: 0x404040
  [172.638 ms] Display at (0, 55): Robot ready: tap Arm
  [1001.088 ms] Speaker: 1760 Hz for 60 ms
  [1001.791 ms] ESP-NOW: sent tag 1, 0.000, 0.000
  [2023.294 ms] ESP-NOW: sent tag 2, 0.000, 0.000
  [2026.954 ms] Display at (0, 32): Armed
  [2040.737 ms] Display at (0, 55): 
  [2052.617 ms] Display disc at (62, 122), radius 9: 0x00c000
  [2067.460 ms] Display at (130, 113): 2.5
  [2205.496 ms] ESP-NOW: sent tag 2, -240.000, 0.000
  [2217.376 ms] Display disc at (62, 89), radius 9: 0x00c000
  [3011.083 ms] ESP-NOW: sent tag 2, 80.000, -40.000
  [3022.963 ms] Display disc at (89, 142), radius 9: 0x00c000
  [3506.089 ms] ESP-NOW: sent tag 2, 0.000, 0.000
  [3506.466 ms] Display disc at (62, 122), radius 9: 0x00c000
  [3840.053 ms] ESP-NOW: sent tag 4, 0.000, 0.000
  [3843.753 ms] Display at (0, 32): No link
  [3867.136 ms] Display disc at (62, 122), radius 9: 0x808080
  [4212.226 ms] ESP-NOW: sent tag 2, 0.000, 0.000
  [4215.886 ms] Display at (0, 32): Armed
  [4227.766 ms] Display disc at (62, 122), radius 9: 0x00c000
  [4242.609 ms] Display at (130, 113): 1.5
  [4610.755 ms] Speaker: 880 Hz for 60 ms
  [4610.855 ms] ESP-NOW: sent tag 3, 0.000, 0.000
  [4866.475 ms] Display at (0, 32): Disarmed
  [4866.875 ms] ESP-NOW: sent tag 4, 0.000, 0.000
  [4867.252 ms] Display disc at (62, 122), radius 9: 0x404040
  [4880.652 ms] Display at (0, 55): Robot armed
  [4905.372 ms] Display at (0, 55): Hold the robot upright and still
  [5605.452 ms] Display at (0, 55): Hold still
  [6305.972 ms] Display at (0, 55): Hold the robot upright and still
  [7006.252 ms] Display at (0, 55): Robot ready: tap Arm
  [8611.212 ms] Display at (0, 55): Switch on the robot

The packets are sent at most 50 ms apart, here 10.9 to 16.6 ms, Arm 81
times and Disarm 20 times:

  $ awk '/ESP-NOW: sent/ { t = substr($1, 2) + 0; if (last) { d = t - last; if (!lo || d < lo) lo = d; if (d > hi) hi = d } last = t } END { printf "%.1f %.1f\n", lo, hi }' sim.log
  10.9 16.6
  $ grep -c 'sent tag 1' sim.log; grep -c 'sent tag 3' sim.log
  81
  20
