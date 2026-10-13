The BALA2 application of examples/arduino/bala2: the balancing robot with the
packages m5-imu, m5-display and bala2-base, its rejected variants, and its
closed loop with the host model of the robot.

  $ app=../../examples/arduino/bala2
  $ tempore () { ../../tempore --grades time-interval-rational "$@"; }
  $ packages () { tempore --package m5-imu --package m5-display --package bala2-base --board m5stack-gray "$@"; }

The interpreter, with the declarations of the packages under their
running-time bounds on the M5Stack Gray, the board of the manifest, as for
the rejected variants below, runs two control steps with the default
implementations of the operations:

  $ packages $app/balance.tpe
  === Run 1 ===
  return (2.8812, 0., 0., 0.)
  State: [
    [0.6, 0.6],
    { resource_0 ↦ ((0., 0., 1.), (0., 0., 0.)) # [0, 2] },
    [0.5, 0.5],
    [0.01, 0.01],
    [0.01, 0.01],
    [0.2, 0.2],
    [0.6, 0.6],
    { resource_1 ↦ ((0., 0., 1.), (0., 0., 0.)) # [0, 2] },
    [0.5, 0.5],
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
  Typing error: Variable `fresh` is unboxed with grade `[2.4, 3.55]` accumulated since it was bound, which is not below its box grade `[0, 2]`
    File "bala2/stale.tpe", line 6, characters 24-29:
    6 |   box [0, 2] reading as fresh in
                                ^^^^^
    `fresh` is bound here
    File "bala2/stale.tpe", line 7, characters 22-45:
    7 |   let left1, right1 = perform ReadEncoders () in
                              ^^^^^^^^^^^^^^^^^^^^^^^
    grade `[0.45, 1]` accumulates here (operation `ReadEncoders`)
    File "bala2/stale.tpe", line 8, characters 2-11:
    8 |   delay 1.5;
          ^^^^^^^^^
    grade `[1.5, 1.5]` accumulates here (delay)
    File "bala2/stale.tpe", line 9, characters 22-45:
    9 |   let left2, right2 = perform ReadEncoders () in
                              ^^^^^^^^^^^^^^^^^^^^^^^
    grade `[0.45, 1]` accumulates here (operation `ReadEncoders`)
    File "bala2/stale.tpe", line 12, characters 34-54:
    12 |   let armed, bias, target, turn = perform Setpoints () in
                                           ^^^^^^^^^^^^^^^^^^^^
    grade `[0, 0.05]` accumulates here (operation `Setpoints`)
    Note: the resource inequality `[2.4, 3.55] <= [0, 2]` does not hold
  [1]
  File "bala2/period.tpe", lines 4-15, characters 59-35:
  4 | let step_shown ((tilt, speed, integral, position) : state) : state # [0, 5) =
                                                                 ^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `[0.85, 14.2]`, which does not match its annotated grade `[0, 5)`
    Note: the effect inequality `[0.85, 14.2] <= [0, 5)` does not hold
  [1]
  File "bala2/unchecked.tpe", line 6, characters 14-19:
  6 |   perform Arm token;
                    ^^^^^
  Typing error: Operation `Arm` takes an argument of type `calibration` but is given `[_]calibration`
    File "../../examples/arduino/bala2/balance.tpe", line 94, characters 0-47:
    94 | operation Arm : calibration ~> unit # [0, 0.05]
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
  Typing error: Variable `token` is unboxed with grade `[600000.1, 600012.5]` accumulated since it was bound, which is not below its box grade `[0, 600000)`
    File "bala2/late.tpe", line 5, characters 6-11:
    5 |   let token = calibrate () in
              ^^^^^
    `token` is bound here
    File "bala2/late.tpe", line 6, characters 2-33:
    6 |   perform ShowText "Hold upright";
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[0.1, 12.5]` accumulates here (operation `ShowText`)
    File "bala2/late.tpe", line 7, characters 2-14:
    7 |   delay 600000;
          ^^^^^^^^^^^^
    grade `[600000, 600000]` accumulates here (delay)
    File "bala2/late.tpe", line 5, characters 14-23:
    5 |   let token = calibrate () in
                      ^^^^^^^^^
    the inequality goes through the type of `calibrate` here
    Note: the resource inequality `[600000.1, 600012.5] <= [0, 600000)` does not hold
  [1]
  File "bala2/redrawn.tpe", lines 4-10, characters 33-11:
  4 | let drive_step_redrawn (n : nat) : unit # [0, 200) =
                                       ^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `[181.2, 223.1]`, which does not match its annotated grade `[0, 200)`
    Note: the effect inequality `[181.2, 223.1] <= [0, 200)` does not hold
  [1]

The PlatformIO project for the M5Stack Gray, its C++ sources checked without
exceptions and run-time type information, and its host build:

  $ tempore --emit-arduino balance --device $app/balance.device.json $app/balance.tpe | grep -c Wrote
  30
  $ cd _arduino/projects/balance
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ build () { c++ -std=c++17 -Wall -Wextra -Werror -ffp-contract=off -DTEMPORE_HOST -DTEMPORE_TRACE "$@" -pthread -I host -I src src/*.cpp host/*.cpp -o simulation; }
  $ events () { ./simulation "$1" | grep -v '\] \(Release\|Start\|End step\|Operation\|IMU\|I2C\|Delay\)'; }
  $ cd ../../..

The closed loop for 8 s from a tilt of 0.1 rad, the robot held until its
motors are first driven: the supervision calibrates the gyroscope, arms the
robot after a second and shows the tilt every second; the tilt stays below
half a degree from one second after the release. The digits of the simulated
tilt depend on the rounding of the single-precision functions of the C
library, so that the filter balanced checks the tilts, the position of the
wheels and the largest drive against bounds, and prints the other events as
they are:

  $ balanced () {
  >   awk '
  >     function within(x, b) { return (x < 0 ? -x : x) < b }
  >     function check(ok, text) { print (ok ? text : $0) }
  >     / Display: -?[0-9]+\.[0-9]+$/ {
  >       check(within($NF, 0.5), $1 " " $2 " Display: a tilt below 0.5 degrees"); next
  >     }
  >     / Plant: tilt / {
  >       check(within($5, 0.2) && within($9, 0.01),
  >         $1 " " $2 " Plant: tilt below 0.2 degrees, wheels within 0.01 m"); next
  >     }
  >     / Plant: largest tilt / {
  >       check(within($(NF - 1), 0.5),
  >         $1 " " $2 " Plant: largest tilt from 1 s after the release below 0.5 degrees"); next
  >     }
  >     / Plant: largest drive / {
  >       d = $6; sub(/,$/, "", d)
  >       check(within(d, 0.2), $1 " " $2 " Plant: largest drive below 0.2, " $7 " " $8 " " $9 " " $10); next
  >     }
  >     { print }'
  > }

  $ tempore --emit-arduino balance --device $app/balance.device.json --host-simulate 8 $app/balance.tpe | grep -v '^Wrote\|\] \(Release\|Start\|End step\|Operation\|IMU\|I2C\|Delay\)' | balanced
  [31.245 ms] Display cleared
  [32.245 ms] Display: Calibrating
  [533.245 ms] Display: Hold upright
  [1534.245 ms] Display: Armed
  [2435.245 ms] Display: a tilt below 0.5 degrees
  [3436.245 ms] Display: a tilt below 0.5 degrees
  [4437.245 ms] Display: a tilt below 0.5 degrees
  [5438.245 ms] Display: a tilt below 0.5 degrees
  [6439.245 ms] Display: a tilt below 0.5 degrees
  [7440.245 ms] Display: a tilt below 0.5 degrees
  [8000.000 ms] End of the simulation
  [8000.000 ms] Plant: released at 1537.0 ms
  [8000.000 ms] Plant: tilt below 0.2 degrees, wheels within 0.01 m
  [8000.000 ms] Plant: largest tilt from 1 s after the release below 0.5 degrees
  [8000.000 ms] Plant: largest drive below 0.2, last at 8000.0 ms

From a tilt of 1.3 rad (74.5 degrees), beyond the cutoff of 70 degrees, the
step never drives the motors, and the robot falls when released at 2 s:

  $ cd _arduino/projects/balance
  $ build -DPLANT_TILT=1.3 && events 8000000
  [31.245 ms] Display cleared
  [32.245 ms] Display: Calibrating
  [533.245 ms] Display: Hold upright
  [1534.245 ms] Display: Armed
  [2435.245 ms] Display: 80.326
  [3436.245 ms] Display: 80.216
  [4437.245 ms] Display: 80.214
  [5438.245 ms] Display: 80.214
  [6439.245 ms] Display: 80.214
  [7440.245 ms] Display: 80.214
  [8000.000 ms] End of the simulation
  [8000.000 ms] Plant: released at 2000.0 ms
  [8000.000 ms] Plant: tilt 80.21 degrees, wheels at -0.247 m
  [8000.000 ms] Plant: largest tilt from 1 s after the release 80.21 degrees
  [8000.000 ms] Plant: the motors were never driven

A binding made slow from 4 s on, Publish taking 3 ms beyond its bound of
0.05 ms: its monitor enters the safe state, which stops the motors, and the
robot falls:

  $ build -DBALANCE_SLOW_FROM_MS=4000 && events 8000000
  [31.245 ms] Display cleared
  [32.245 ms] Display: Calibrating
  [533.245 ms] Display: Hold upright
  [1534.245 ms] Display: Armed
  [2435.245 ms] Display: -0.046
  [3436.245 ms] Display: -0.059
  [4005.071 ms] Monitor: operation Publish took 3000 us, outside its running-time bounds [0, 50] us
  [4005.071 ms] Safe state
  [4005.316 ms] Task step stopped
  [4036.000 ms] Task supervise stopped
  [8000.000 ms] End of the simulation
  [8000.000 ms] Plant: released at 1537.0 ms
  [8000.000 ms] Plant: tilt 80.21 degrees, wheels at -0.043 m
  [8000.000 ms] Plant: largest tilt from 1 s after the release 80.21 degrees
  [8000.000 ms] Plant: largest drive 0.140, last at 4005.0 ms

With the build flag BALANCE_LOG, here 500 ms, a task started by the first
publication logs the published attitude, the drives last written and the
counts last read, and the arming:

  $ build -DBALANCE_LOG=500 && ./simulation 3000000 | grep '\] \(Armed\|Tilt\)'
  [502.000 ms] Tilt 5.73 deg, rate 0.0 deg/s, drives 0 0, counts 0 0
  [1002.000 ms] Tilt 5.73 deg, rate 0.0 deg/s, drives 0 0, counts 0 0
  [1502.000 ms] Tilt 5.73 deg, rate 0.0 deg/s, drives 0 0, counts 0 0
  [2002.000 ms] Armed, gyroscope bias 0.000 deg/s
  [2002.000 ms] Tilt -0.01 deg, rate 1.9 deg/s, drives 15 15, counts 31 31
  [2502.000 ms] Tilt -0.06 deg, rate -2.5 deg/s, drives 18 18, counts 57 57

The profile of the closed loop over 6 s, built with TEMPORE_PROFILE in place
of TEMPORE_TRACE, at the end of the simulation: each call takes the nominal
time of its binding or device model, and the steps keep their period of 5 ms
from the second on, the first starting late in its tick after the initial
function:

  $ c++ -std=c++17 -Wall -Wextra -Werror -ffp-contract=off -DTEMPORE_HOST -DTEMPORE_PROFILE -pthread -I host -I src src/*.cpp host/*.cpp -o simulation
  $ ./simulation 6000000 | sed -n '/End of the simulation/,$p' | grep -v Plant
  [6000.000 ms] End of the simulation
  [6000.000 ms] Profile since start-up, times in microseconds
    operation        calls       min       mean       max
    ReadImu           1201       603      603.0       603
    ShowText             3      1000     1000.0      1000
    ShowNumber           4      1000     1000.0      1000
    ClearDisplay         1     31000    31000.0     31000
    SetMotors         1200       245      245.0       245
    ReadEncoders      1200       468      468.0       468
    ResetEncoders        1       335      335.0       335
    Publish           1200         0        0.0         0
    Setpoints         1200         0        0.0         0
    Attitude            95         0        0.0         0
    Arm                  1         0        0.0         0
    Disarm               1         0        0.0         0
    Command             45         0        0.0         0
    task             steps       min       mean       max    period  min interval  max interval  overruns
    step              1200      1316     1316.0      1316      5000          4817          5000         0
  [6000.000 ms] End of the profile
