The BALA2 application of examples/arduino/bala2-regex: the balancing robot under
the timed regex grades, with the declarations of the packages m5-imu, m5-display
and bala2-base under these grades and the binding file and host model of
examples/arduino/bala2: its runs by the interpreter, its rejected variants, and
its closed loop with the host model of the robot.

  $ app=../../examples/arduino/bala2-regex
  $ . ../helpers.sh
  $ from_header $app/balance_regex.tpe

The interpreter, with the declarations of the packages under their
running-time bounds on the M5Stack Gray, the board of the manifest, as for
the rejected variants below, runs two control steps with the default
implementations of the operations:

  $ packages $app/balance_regex.tpe > runs
  $ awk '/^=== Run 2/ { exit } { print }' runs
  === Run 1 ===
  return (2.8812, 0., 0., 0., 0.)
  State: [
    {idle 0.6},
    { resource_0 ↦ ((0., 0., 1.), (0., 0., 0.)) ! {(ReadEncoders | Setpoints)*}
    },
    {idle 0.5},
    {idle 0.01},
    {idle 0.01},
    {idle 0.2},
    {idle 0.6},
    { resource_1 ↦ ((0., 0., 1.), (0., 0., 0.)) ! {(ReadEncoders | Setpoints)*}
    },
    {idle 0.5},
    {idle 0.01},
    {idle 0.01},
    {idle 0.2}
  ]
  

and, with the handlers of the file, 20 steps of the closed loop with the
simulated robot from a tilt of 3 degrees, and 10 steps of the robot held
upright with the gyroscope stuck, from the eighth of which on the step stops
the motors:

  $ grep -A 2 '^=== Run 2' runs | sed 's/ *$//'; grep -A 1 '^=== Run 3' runs
  === Run 2 ===
  return ((0.0274756773391, -3.32667600333, 0.14970042015, 0., 0.),
          0.301752548292)
  === Run 3 ===
  return ((89.6343246251, 0., 0., 0., 0.), 0.)

The rejected variants, each loaded after the application: a reading of the
unit used after a command of the motors, a measurement of the bias without
stopping the balancing, and a measurement of the bias that shows the rates left between
its readings:

  $ for v in stopped balancing shown; do packages --typecheck-only $app/balance_regex.tpe bala2-regex/$v.tpe; echo "[$?]"; done
  File "bala2-regex/stopped.tpe", lines 10-18, characters 2-39:
  10 |   unbox fresh as imu in
         ^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `fresh` is unboxed with grade `{ReadEncoders; Setpoints; SetMotors?}` accumulated since it was bound, which is not below its box grade `{(ReadEncoders | Setpoints)*}`
    File "bala2-regex/stopped.tpe", line 6, characters 6-11:
    6 |   let fresh = fresh_imu () in
              ^^^^^
    `fresh` is bound here
    File "bala2-regex/stopped.tpe", line 7, characters 20-43:
    7 |   let left, right = perform ReadEncoders () in
                            ^^^^^^^^^^^^^^^^^^^^^^^
    grade `{ReadEncoders}` accumulates here (operation `ReadEncoders`)
    File "bala2-regex/stopped.tpe", line 8, characters 38-58:
    8 |   let balancing, bias, target, turn = perform Setpoints () in
                                              ^^^^^^^^^^^^^^^^^^^^
    grade `{Setpoints}` accumulates here (operation `Setpoints`)
    File "bala2-regex/stopped.tpe", line 9, characters 2-56:
    9 |   (if balancing then () else perform SetMotors (0i, 0i));
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{SetMotors?}` accumulates here (this computation)
    File "bala2-regex/stopped.tpe", line 6, characters 14-23:
    6 |   let fresh = fresh_imu () in
                      ^^^^^^^^^
    the inequality goes through the type of `fresh_imu` here
    Note: the resource inequality `{ReadEncoders; Setpoints; SetMotors?} <= {(ReadEncoders | Setpoints)*}` does not hold
    Note: the grade `[{ReadEncoders; Setpoints; SetMotors}, {ReadEncoders; Setpoints; SetMotors?}]` is below `{ReadEncoders; Setpoints; SetMotors?}` but not below `{(ReadEncoders | Setpoints)*}`
  [1]
  File "bala2-regex/balancing.tpe", lines 4-12, characters 30-13:
  4 | let measure_bias_balancing () : float
                                    ^^^^^^^
  Typing error: This function's body has grade `{ClearDisplay; ShowTextAt^2; ShowText; (LatestTilt; 10)*}`, which does not match its annotated grade `{StopBalancing; ClearDisplay; ShowTextAt^2; ShowText; (LatestTilt; 10)*}`
    Note: the effect inequality `{ClearDisplay; ShowTextAt^2; ShowText; (LatestTilt; 10)*} <= {StopBalancing; ClearDisplay; ShowTextAt^2; ShowText; (LatestTilt; 10)*}` does not hold
    Note: the grade `[{ClearDisplay; ShowTextAt^2; ShowText}, {ClearDisplay; ShowTextAt^2; ShowText; (LatestTilt; ≤10)*}]` is below `{ClearDisplay; ShowTextAt^2; ShowText; (LatestTilt; 10)*}` but not below `{StopBalancing; ClearDisplay; ShowTextAt^2; ShowText; (LatestTilt; 10)*}`
  [1]
  File "bala2-regex/shown.tpe", lines 4-11, characters 47-36:
  4 | let rec rate_sum_shown (n : nat) (sum : float) : float ! {(LatestTilt; 10)*} =
                                                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{(LatestTilt; ShowNumber; idle 10; (LatestTilt; 10)*)?}`, which does not match its annotated grade `{(LatestTilt; 10)*}`
    Note: the effect inequality `{(LatestTilt; ShowNumber; idle 10; (LatestTilt; 10)*)?} <= {(LatestTilt; 10)*}` does not hold
    Note: the grade `[{(LatestTilt; ShowNumber; idle ≥10; (LatestTilt; ≥10)*)?}, {LatestTilt; ShowNumber; idle ≤10}]` is below `{(LatestTilt; ShowNumber; idle 10; (LatestTilt; 10)*)?}` but not below `{(LatestTilt; 10)*}`
  [1]

The PlatformIO project for the M5Stack Gray, its C++ sources checked without
exceptions and run-time type information:

  $ tempore --emit-arduino balance_regex --device $app/balance_regex.device.json $app/balance_regex.tpe | grep -c Wrote
  File "../../examples/arduino/bala2-regex/balance_regex.tpe", line 362, characters 26-27:
  362 |       let s, _ = continue k with () in
                                  ^
  Warning: The handler `simulated_robot` is not tail-resumptive: the continuation `k` of its case of `SetMotors` is resumed outside tail position; it is not compiled for the device, and the interpreter can run it
  34
  $ cd _arduino/projects/balance_regex
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

The closed loop for 8 s from a tilt of 0.1 rad, the robot held until its
motors are first driven, as for examples/arduino/bala2: the supervision
calibrates the gyroscope, starts the balancing after a second and shows the tilt
every second; the tilt stays below 2.5 degrees from one second after the
release. The digits of the simulated tilt depend on the rounding of the
single-precision functions of the C library, so that the filter balanced
checks the tilts, the position of the wheels and the largest drive against
bounds, and prints the other events as they are:

  $ balanced () {
  >   awk '
  >     function within(x, b) { return (x < 0 ? -x : x) < b }
  >     function check(ok, text) { print (ok ? text : $0) }
  >     / Display: -?[0-9]+\.[0-9]+$/ {
  >       check(within($NF, 2.5), $1 " " $2 " Display: a tilt below 2.5 degrees"); next
  >     }
  >     / Plant: tilt / {
  >       check(within($5, 2.5) && within($9, 0.2),
  >         $1 " " $2 " Plant: tilt below 2.5 degrees, wheels within 0.2 m"); next
  >     }
  >     / Plant: largest tilt / {
  >       check(within($(NF - 1), 2.5),
  >         $1 " " $2 " Plant: largest tilt from 1 s after the release below 2.5 degrees"); next
  >     }
  >     / Plant: largest drive / {
  >       d = $6; sub(/,$/, "", d)
  >       check(within(d, 0.4), $1 " " $2 " Plant: largest drive below 0.4, " $7 " " $8 " " $9 " " $10); next
  >     }
  >     { print }'
  > }

  $ tempore --emit-arduino balance_regex --device $app/balance_regex.device.json --host-simulate 8 $app/balance_regex.tpe | grep -v '^Wrote\|\] \(Release\|Start\|End step\|Operation\|IMU\|I2C\|Delay\)' | balanced
  File "../../examples/arduino/bala2-regex/balance_regex.tpe", line 362, characters 26-27:
  362 |       let s, _ = continue k with () in
                                  ^
  Warning: The handler `simulated_robot` is not tail-resumptive: the continuation `k` of its case of `SetMotors` is resumed outside tail position; it is not compiled for the device, and the interpreter can run it
  [31.245 ms] Display cleared
  [35.365 ms] Display at (0, 2): Balancing robot with regexes
  [37.333 ms] Display at (188, 231): Typechecked by Tempore
  [38.333 ms] Display: Calibrating
  [539.333 ms] Display: Hold upright
  [1540.333 ms] Display: Balancing
  [2441.333 ms] Display: a tilt below 2.5 degrees
  [3442.333 ms] Display: a tilt below 2.5 degrees
  [4443.333 ms] Display: a tilt below 2.5 degrees
  [5444.333 ms] Display: a tilt below 2.5 degrees
  [6445.333 ms] Display: a tilt below 2.5 degrees
  [7446.333 ms] Display: a tilt below 2.5 degrees
  [8000.000 ms] End of the simulation
  [8000.000 ms] Plant: released at 1542.0 ms
  [8000.000 ms] Plant: tilt below 2.5 degrees, wheels within 0.2 m
  [8000.000 ms] Plant: largest tilt from 1 s after the release below 2.5 degrees
  [8000.000 ms] Plant: largest drive below 0.4, last at 8000.0 ms
