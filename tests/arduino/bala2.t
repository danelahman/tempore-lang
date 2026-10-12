The BALA2 application of examples/arduino/bala2: the balancing robot with the
packages m5-imu, m5-display and bala2-base, its rejected variants, and its
closed loop with the host model of the robot.

  $ app=../../examples/arduino/bala2
  $ tempore () { ../../tempore --grades time-interval-rational "$@"; }
  $ packages () { tempore --package m5-imu --package m5-display --package bala2-base "$@"; }

The interpreter, with the declarations of the packages, runs two control
steps with the default implementations of the operations:

  $ packages $app/balance.tpe
  === Run 1 ===
  return (2.8812, 0., 0., 0.)
  State: [
    [0.5, 0.5],
    { resource_0 ↦ ((0., 0., 1.), (0., 0., 0.)) # [0, 2] },
    [0.25, 0.25],
    [0.01, 0.01],
    [0.01, 0.01],
    [0.2, 0.2],
    [0.5, 0.5],
    { resource_1 ↦ ((0., 0., 1.), (0., 0., 0.)) # [0, 2] },
    [0.25, 0.25],
    [0.01, 0.01],
    [0.01, 0.01],
    [0.2, 0.2]
  ]
  

The rejected variants, each loaded after the application: a stale reading of
the unit, a step longer than its period, arming with the boxed calibration
and with an expired one, and a supervisory iteration that may exceed the
200 ms of a command:

  $ for v in stale period unchecked late redrawn; do packages --typecheck-only $app/balance.tpe bala2/$v.tpe; echo "[$?]"; done
  File "bala2/stale.tpe", lines 13-20, characters 2-49:
  13 |   unbox fresh as imu in
         ^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `fresh` is unboxed with grade `[1.7, 2.75]` accumulated since it was bound, which is not below its box grade `[0, 2]`
    File "bala2/stale.tpe", line 6, characters 24-29:
    6 |   box [0, 2] reading as fresh in
                                ^^^^^
    `fresh` is bound here
    File "bala2/stale.tpe", line 7, characters 22-45:
    7 |   let left1, right1 = perform ReadEncoders () in
                              ^^^^^^^^^^^^^^^^^^^^^^^
    grade `[0.1, 0.6]` accumulates here (operation `ReadEncoders`)
    File "bala2/stale.tpe", line 8, characters 2-11:
    8 |   delay 1.5;
          ^^^^^^^^^
    grade `[1.5, 1.5]` accumulates here (delay)
    File "bala2/stale.tpe", line 9, characters 22-45:
    9 |   let left2, right2 = perform ReadEncoders () in
                              ^^^^^^^^^^^^^^^^^^^^^^^
    grade `[0.1, 0.6]` accumulates here (operation `ReadEncoders`)
    File "bala2/stale.tpe", line 12, characters 34-54:
    12 |   let armed, bias, target, turn = perform Setpoints () in
                                           ^^^^^^^^^^^^^^^^^^^^
    grade `[0, 0.05]` accumulates here (operation `Setpoints`)
    Note: the resource inequality `[1.7, 2.75] <= [0, 2]` does not hold
  [1]
  File "bala2/period.tpe", lines 4-15, characters 59-35:
  4 | let step_shown ((tilt, speed, integral, position) : state) : state # [0, 5) =
                                                                 ^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `[0.45, 21.3]`, which does not match its annotated grade `[0, 5)`
    Note: the effect inequality `[0.45, 21.3] <= [0, 5)` does not hold
  [1]
  File "bala2/unchecked.tpe", line 6, characters 14-19:
  6 |   perform Arm token;
                    ^^^^^
  Typing error: Operation `Arm` takes an argument of type `calibration` but is given `[_]calibration`
    File "../../examples/arduino/bala2/balance.tpe", line 60, characters 0-47:
    60 | operation Arm : calibration ~> unit # [0, 0.05]
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Arm` is declared here
    File "bala2/unchecked.tpe", line 5, characters 14-26:
    5 |   let token = calibrate () in
                      ^^^^^^^^^^^^
    `[_]calibration` was inferred here
  [1]
  File "bala2/late.tpe", lines 8-10, characters 2-18:
  8 |   unbox token as calibration in
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `token` is unboxed with grade `[600000.2, 600020]` accumulated since it was bound, which is not below its box grade `[0, 600000)`
    File "bala2/late.tpe", line 5, characters 6-11:
    5 |   let token = calibrate () in
              ^^^^^
    `token` is bound here
    File "bala2/late.tpe", line 6, characters 2-33:
    6 |   perform ShowText "Hold upright";
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[0.2, 20]` accumulates here (operation `ShowText`)
    File "bala2/late.tpe", line 7, characters 2-14:
    7 |   delay 600000;
          ^^^^^^^^^^^^
    grade `[600000, 600000]` accumulates here (delay)
    File "bala2/late.tpe", line 5, characters 14-23:
    5 |   let token = calibrate () in
                      ^^^^^^^^^
    the inequality goes through the type of `calibrate` here
    Note: the resource inequality `[600000.2, 600020] <= [0, 600000)` does not hold
  [1]
  File "bala2/redrawn.tpe", lines 4-10, characters 33-11:
  4 | let drive_step_redrawn (n : nat) : unit # [0, 200) =
                                       ^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `[110.4, 200.1]`, which does not match its annotated grade `[0, 200)`
    Note: the effect inequality `[110.4, 200.1] <= [0, 200)` does not hold
  [1]

The PlatformIO project for the M5Stack Gray, its C++ sources checked without
exceptions and run-time type information, and its host build:

  $ tempore --emit-arduino balance --device $app/balance.device.json $app/balance.tpe | grep -c Wrote
  29
  $ cd _arduino/projects/balance
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ build () { c++ -std=c++17 -Wall -Wextra -Werror -DTEMPORE_HOST -DTEMPORE_TRACE "$@" -pthread -I host -I src src/*.cpp host/*.cpp -o simulation; }
  $ events () { ./simulation "$1" | grep -v '\] \(Release\|Start\|End step\|Operation\|IMU\|I2C\|Delay\)'; }
  $ cd ../../..

The closed loop for 8 s from a tilt of 0.1 rad, the robot held until its
motors are first driven: the supervision calibrates the gyroscope, arms the
robot after a second and shows the tilt every second; the tilt stays below
a degree from one second after the release:

  $ tempore --emit-arduino balance --device $app/balance.device.json --host-simulate 8 $app/balance.tpe | grep -v '^Wrote\|\] \(Release\|Start\|End step\|Operation\|IMU\|I2C\|Delay\)'
  [31.135 ms] Display cleared
  [32.135 ms] Display: Calibrating
  [533.135 ms] Display: Hold upright
  [1533.135 ms] Armed, gyroscope bias 0.000 deg/s
  [1534.135 ms] Display: Armed
  [2435.135 ms] Display: -0.002
  [3436.135 ms] Display: -0.035
  [4437.135 ms] Display: 0.130
  [5438.135 ms] Display: 0.023
  [6439.135 ms] Display: 0.000
  [7440.135 ms] Display: -0.020
  [8000.000 ms] End of the simulation
  [8000.000 ms] Plant: released at 1535.6 ms
  [8000.000 ms] Plant: tilt 0.01 degrees, wheels at 0.005 m
  [8000.000 ms] Plant: largest tilt from 1 s after the release 0.29 degrees
  [8000.000 ms] Plant: largest drive 0.280, last at 7995.6 ms

From a tilt of 1.3 rad (74.5 degrees), beyond the cutoff of 70 degrees, the
step never drives the motors, and the robot falls when released at 2 s:

  $ cd _arduino/projects/balance
  $ build -DPLANT_TILT=1.3 && events 8000000
  [31.135 ms] Display cleared
  [32.135 ms] Display: Calibrating
  [533.135 ms] Display: Hold upright
  [1533.135 ms] Armed, gyroscope bias 0.000 deg/s
  [1534.135 ms] Display: Armed
  [2435.135 ms] Display: 80.244
  [3436.135 ms] Display: 80.215
  [4437.135 ms] Display: 80.214
  [5438.135 ms] Display: 80.214
  [6439.135 ms] Display: 80.214
  [7440.135 ms] Display: 80.214
  [8000.000 ms] End of the simulation
  [8000.000 ms] Plant: released at 2000.0 ms
  [8000.000 ms] Plant: tilt 80.21 degrees, wheels at -0.247 m
  [8000.000 ms] Plant: largest tilt from 1 s after the release 80.21 degrees
  [8000.000 ms] Plant: the motors were never driven

A binding made slow from 4 s on, Publish taking 3 ms beyond its bound of
0.05 ms: its monitor enters the safe state, which stops the motors, and the
robot falls:

  $ build -DBALANCE_SLOW_FROM_MS=4000 && events 8000000
  [31.135 ms] Display cleared
  [32.135 ms] Display: Calibrating
  [533.135 ms] Display: Hold upright
  [1533.135 ms] Armed, gyroscope bias 0.000 deg/s
  [1534.135 ms] Display: Armed
  [2435.135 ms] Display: -0.002
  [3436.135 ms] Display: -0.035
  [4003.631 ms] Monitor: operation Publish took 3000 us, outside its running-time bounds [0, 50] us
  [4003.631 ms] Safe state
  [4003.766 ms] Task step stopped
  [4036.000 ms] Task supervise stopped
  [8000.000 ms] End of the simulation
  [8000.000 ms] Plant: released at 1535.6 ms
  [8000.000 ms] Plant: tilt -80.21 degrees, wheels at 0.097 m
  [8000.000 ms] Plant: largest tilt from 1 s after the release 80.21 degrees
  [8000.000 ms] Plant: largest drive 0.280, last at 3995.6 ms
