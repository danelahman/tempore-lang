The BALA2 application of examples/arduino/bala2-remote: the balancing robot
driven by a controller over ESP-NOW, with the packages esp-now and
bala2-remote and the binding file and host model of examples/arduino/bala2:
its typing, its rejected variants, and its host simulation with a scripted
controller.

  $ app=../../examples/arduino/bala2-remote
  $ . ../helpers.sh
  $ from_header $app/balance_remote.tpe
  $ packages --typecheck-only $app/balance_remote.tpe

The rejected variants, each loaded after the application: arming as soon as
the controller sends Arm, before the robot is held upright, and an iteration
of the drive that redraws the screen between receiving a message and
applying it:

  $ for v in hasty redrawn; do packages --typecheck-only $app/balance_remote.tpe bala2-remote/$v.tpe > out 2>&1; echo "[$?]"; grep 'error\|Note' out; done
  [1]
  Typing error: Variable `token` is unboxed with grade `[0.05, ∞)` accumulated since it was bound, which is not below its box grade `[1000, ∞)`
    Note: the resource inequality `[0.05, ∞) <= [1000, ∞)` does not hold
  [1]
  Typing error: Variable `fresh` is unboxed with grade `[31.2, 159.5]` accumulated since it was bound, which is not below its box grade `[0, 150)`
    Note: the resource inequality `[31.2, 159.5] <= [0, 150)` does not hold

The PlatformIO project for the M5Stack Gray, its C++ sources checked without
exceptions and run-time type information:

  $ tempore --emit-arduino balance_remote --device $app/balance_remote.device.json $app/balance_remote.tpe > /dev/null
  $ cd _arduino/projects/balance_remote
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

The host simulation for 8 s. The controller sends Beat until 1.5 s, Arm,
Drive (100, 0) from 1.6 s, Disarm at 3 s, Beat, Arm again at 4.4 s,
Drive (-100, 0) from 4.5 s, and nothing from 5 s. The robot is armed once
it is held upright and Arm comes, disarmed at the Disarm, armed again after
a second held upright, and shows "Link lost" and beeps about 2 s after the
last message, staying armed. After the Disarm the robot falls, and the step
no longer drives the motors beyond the cutoff. The tilts of the plant,
whose digits depend on the C library, are not shown:

  $ tempore --emit-arduino balance_remote --device $app/balance_remote.device.json --host-simulate 8 $app/balance_remote.tpe | grep -v '^Wrote\|\] \(Release\|Start\|End step\|Operation\|IMU\|I2C\|Delay\|ESP-NOW model\)\|Plant: \(tilt\|largest\)'
  [31.245 ms] Display cleared
  [35.045 ms] Display at (0, 2): Remote robot
  [37.805 ms] Display at (80, 231): Typechecked by Tempore (tempore-lang.ee)
  [38.805 ms] Display: Calibrating
  [100.245 ms] ESP-NOW: started on channel 1, address 24:0A:C4:00:00:01, peer FF:FF:FF:FF:FF:FF
  [542.605 ms] Display at (0, 102): Hold upright
  [1546.465 ms] Display at (0, 102): Waiting for Arm
  [1550.125 ms] Display at (0, 102): Armed
  [3028.845 ms] Display at (0, 102): Disarmed
  [3032.645 ms] Display at (0, 102): Hold upright
  [4036.505 ms] Display at (0, 102): Waiting for Arm
  [4415.165 ms] Display at (0, 102): Armed
  [7031.405 ms] Display at (0, 102): Link lost
  [7031.455 ms] Speaker: 880 Hz for 200 ms
  [8000.000 ms] End of the simulation
  [8000.000 ms] Plant: released at 1547.0 ms
