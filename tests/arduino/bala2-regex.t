The BALA2 application of examples/arduino/bala2-regex: the balancing robot
under the regular expressions of timed operations, with the declarations of
the packages m5-imu, m5-display and bala2-base under these grades and the
binding file and host model of examples/arduino/bala2: its runs by the
interpreter, its rejected variants, and its closed loop with the host model
of the robot.

  $ app=../../examples/arduino/bala2-regex
  $ tempore () { ../../tempore --grades regex-timed-interval-rational-symbolic "$@"; }
  $ packages () { tempore --package m5-imu --package m5-display --package bala2-base --board m5stack-gray "$@"; }

The interpreter, with the declarations of the packages under their
running-time bounds on the M5Stack Gray, the board of the manifest, as for
the rejected variants below, runs two control steps with the default
implementations of the operations:

  $ packages $app/balance_regex.tpe > runs
  $ awk '/^=== Run 2/ { exit } { print }' runs
  === Run 1 ===
  return (2.8812, 0., 0., 0., 0.)
  State: [
    [{0.6}, {0.6}],
    { resource_0 ↦
        ((0., 0., 1.), (0., 0., 0.))
        # [{ReadEncoders; Setpoints}, {ReadEncoders; Setpoints}]
    },
    [{0.5}, {0.5}],
    [{0.01}, {0.01}],
    [{0.01}, {0.01}],
    [{0.2}, {0.2}],
    [{0.6}, {0.6}],
    { resource_1 ↦
        ((0., 0., 1.), (0., 0., 0.))
        # [{ReadEncoders; Setpoints}, {ReadEncoders; Setpoints}]
    },
    [{0.5}, {0.5}],
    [{0.01}, {0.01}],
    [{0.01}, {0.01}],
    [{0.2}, {0.2}]
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

The rejected variants, each loaded after the application: a step that reads
the encoders before the unit, a stale reading of the unit, a reading used
after a command of the motors, a measurement of the bias without disarming,
arming with the boxed calibration, arming before the robot is held upright
and with an expired calibration, a drive iteration that may exceed the
200 ms of a command, a supervision that leaves the robot armed, and the
handlers whose case of ReadImu also commands the motors, waits in place of
the reading, and delays the reading:

  $ for v in unordered stale stopped armed unchecked hasty late redrawn undisarmed commanding waiting slow; do packages --typecheck-only $app/balance_regex.tpe bala2-regex/$v.tpe; echo "[$?]"; done
  File "bala2-regex/unordered.tpe", lines 5-17, characters 57-39:
  5 |     ((tilt, speed, integral, position, heading) : state) : state
                                                               ^^^^^^^
  Typing error: This function's body has grade `[{ReadEncoders; ReadImu; Setpoints; Publish; SetMotors}, {ReadEncoders; ReadImu; Setpoints; Publish; SetMotors}]`, which does not match its annotated grade `[{ReadImu; ReadEncoders; Setpoints; Publish; SetMotors}, {ReadImu; ReadEncoders; Setpoints; Publish; SetMotors}]`
    Note: the effect inequality `[{ReadEncoders; ReadImu; Setpoints; Publish; SetMotors}, {ReadEncoders; ReadImu; Setpoints; Publish; SetMotors}] <= [{ReadImu; ReadEncoders; Setpoints; Publish; SetMotors}, {ReadImu; ReadEncoders; Setpoints; Publish; SetMotors}]` does not hold
  [1]
  File "bala2-regex/stale.tpe", lines 14-22, characters 2-58:
  14 |   unbox fresh as imu in
         ^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `fresh` is unboxed with grade `[{ReadEncoders; 1.5; ReadEncoders; Setpoints}, {ReadEncoders; 1.5; ReadEncoders; Setpoints}]` accumulated since it was bound, which is not below its box grade `[{ReadEncoders; Setpoints}, {ReadEncoders; Setpoints}]`
    File "bala2-regex/stale.tpe", line 7, characters 43-48:
    7 |   box {ReadEncoders; Setpoints} reading as fresh in
                                                   ^^^^^
    `fresh` is bound here
    File "bala2-regex/stale.tpe", line 8, characters 22-45:
    8 |   let left1, right1 = perform ReadEncoders () in
                              ^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{ReadEncoders}, {ReadEncoders}]` accumulates here (operation `ReadEncoders`)
    File "bala2-regex/stale.tpe", line 9, characters 2-11:
    9 |   delay 1.5;
          ^^^^^^^^^
    grade `[{1.5}, {1.5}]` accumulates here (delay)
    File "bala2-regex/stale.tpe", line 10, characters 22-45:
    10 |   let left2, right2 = perform ReadEncoders () in
                               ^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{ReadEncoders}, {ReadEncoders}]` accumulates here (operation `ReadEncoders`)
    File "bala2-regex/stale.tpe", line 13, characters 34-54:
    13 |   let armed, bias, target, turn = perform Setpoints () in
                                           ^^^^^^^^^^^^^^^^^^^^
    grade `[{Setpoints}, {Setpoints}]` accumulates here (operation `Setpoints`)
    Note: the resource inequality `[{ReadEncoders; 1.5; ReadEncoders; Setpoints}, {ReadEncoders; 1.5; ReadEncoders; Setpoints}] <= [{ReadEncoders; Setpoints}, {ReadEncoders; Setpoints}]` does not hold
  [1]
  File "bala2-regex/stopped.tpe", lines 11-19, characters 2-39:
  11 |   unbox fresh as imu in
         ^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `fresh` is unboxed with grade `[{ReadEncoders; Setpoints; (SetMotors | 0)}, {ReadEncoders; Setpoints; (SetMotors | 0)}]` accumulated since it was bound, which is not below its box grade `[{ReadEncoders; Setpoints}, {ReadEncoders; Setpoints}]`
    File "bala2-regex/stopped.tpe", line 7, characters 43-48:
    7 |   box {ReadEncoders; Setpoints} reading as fresh in
                                                   ^^^^^
    `fresh` is bound here
    File "bala2-regex/stopped.tpe", line 8, characters 20-43:
    8 |   let left, right = perform ReadEncoders () in
                            ^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{ReadEncoders}, {ReadEncoders}]` accumulates here (operation `ReadEncoders`)
    File "bala2-regex/stopped.tpe", line 9, characters 34-54:
    9 |   let armed, bias, target, turn = perform Setpoints () in
                                          ^^^^^^^^^^^^^^^^^^^^
    grade `[{Setpoints}, {Setpoints}]` accumulates here (operation `Setpoints`)
    File "bala2-regex/stopped.tpe", line 10, characters 2-52:
    10 |   (if armed then () else perform SetMotors (0i, 0i));
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{SetMotors | 0}, {SetMotors | 0}]` accumulates here (this computation)
    Note: the resource inequality `[{ReadEncoders; Setpoints; (SetMotors | 0)}, {ReadEncoders; Setpoints; (SetMotors | 0)}] <= [{ReadEncoders; Setpoints}, {ReadEncoders; Setpoints}]` does not hold
  [1]
  File "bala2-regex/armed.tpe", lines 4-9, characters 26-13:
  4 | let measure_bias_armed () : float
                                ^^^^^^^
  Typing error: This function's body has grade `[{ClearDisplay; ShowText}, {ClearDisplay; ShowText; _*}]`, which does not match its annotated grade `[{Disarm; ClearDisplay; ShowText; (Attitude; 10)*}, {Disarm; ClearDisplay; ShowText; (Attitude; 10)*}]`
    Note: the effect inequality `[{ClearDisplay; ShowText}, {ClearDisplay; ShowText; _*}] <= [{Disarm; ClearDisplay; ShowText; (Attitude; 10)*}, {Disarm; ClearDisplay; ShowText; (Attitude; 10)*}]` does not hold
  [1]
  File "bala2-regex/unchecked.tpe", line 6, characters 14-19:
  6 |   perform Arm token;
                    ^^^^^
  Typing error: Operation `Arm` takes an argument of type `calibration` but is given `[_]calibration`
    File "../../examples/arduino/bala2-regex/balance_regex.tpe", line 98, characters 0-60:
    98 | operation Arm : calibration ~> unit # {Arm} within [0, 0.05]
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Arm` is declared here
    File "bala2-regex/unchecked.tpe", line 5, characters 14-26:
    5 |   let token = calibrate () in
                      ^^^^^^^^^^^^
    `[_]calibration` was inferred here
  [1]
  File "bala2-regex/hasty.tpe", lines 8-10, characters 2-18:
  8 |   unbox token as calibration in
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `token` is unboxed with grade `[{ShowText; 100}, {ShowText; 100}]` accumulated since it was bound, which is not below its box grade `[{ShowText; [1000, 600000)}, {ShowText; [1000, 600000)}]`
    File "bala2-regex/hasty.tpe", line 5, characters 6-11:
    5 |   let token = calibrate () in
              ^^^^^
    `token` is bound here
    File "bala2-regex/hasty.tpe", line 6, characters 2-33:
    6 |   perform ShowText "Hold upright";
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{ShowText}, {ShowText}]` accumulates here (operation `ShowText`)
    File "bala2-regex/hasty.tpe", line 7, characters 2-11:
    7 |   delay 100;
          ^^^^^^^^^
    grade `[{100}, {100}]` accumulates here (delay)
    File "bala2-regex/hasty.tpe", line 5, characters 14-23:
    5 |   let token = calibrate () in
                      ^^^^^^^^^
    the inequality goes through the type of `calibrate` here
    Note: the resource inequality `[{ShowText; 100}, {ShowText; 100}] <= [{ShowText; [1000, 600000)}, {ShowText; [1000, 600000)}]` does not hold
  [1]
  File "bala2-regex/late.tpe", lines 8-10, characters 2-18:
  8 |   unbox token as calibration in
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `token` is unboxed with grade `[{ShowText; 600000}, {ShowText; 600000}]` accumulated since it was bound, which is not below its box grade `[{ShowText; [1000, 600000)}, {ShowText; [1000, 600000)}]`
    File "bala2-regex/late.tpe", line 5, characters 6-11:
    5 |   let token = calibrate () in
              ^^^^^
    `token` is bound here
    File "bala2-regex/late.tpe", line 6, characters 2-33:
    6 |   perform ShowText "Hold upright";
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{ShowText}, {ShowText}]` accumulates here (operation `ShowText`)
    File "bala2-regex/late.tpe", line 7, characters 2-14:
    7 |   delay 600000;
          ^^^^^^^^^^^^
    grade `[{600000}, {600000}]` accumulates here (delay)
    File "bala2-regex/late.tpe", line 5, characters 14-23:
    5 |   let token = calibrate () in
                      ^^^^^^^^^
    the inequality goes through the type of `calibrate` here
    Note: the resource inequality `[{ShowText; 600000}, {ShowText; 600000}] <= [{ShowText; [1000, 600000)}, {ShowText; [1000, 600000)}]` does not hold
  [1]
  File "bala2-regex/redrawn.tpe", lines 18-19, characters 6-21:
  18 |       unbox expiry as _ in
             ^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `expiry` is unboxed with grade `[{Attitude; Command; ClearDisplay; ShowText; ShowNumber; 150}, {Attitude; Command; ClearDisplay; ShowText; ShowNumber; 150}]` accumulated since it was bound, which is not below its box grade `[{0}, {[0, 200)}]`
    File "bala2-regex/redrawn.tpe", line 16, characters 25-31:
    16 |       box [0, 200) () as expiry in
                                  ^^^^^^
    `expiry` is bound here
    File "bala2-regex/redrawn.tpe", line 17, characters 6-26:
    17 |       drive_step_redrawn m;
               ^^^^^^^^^^^^^^^^^^^^
    grade `[{Attitude; Command; ClearDisplay; ShowText; ShowNumber; 150}, {Attitude; Command; ClearDisplay; ShowText; ShowNumber; 150}]` accumulates here (this computation)
    Note: the resource inequality `[{Attitude; Command; ClearDisplay; ShowText; ShowNumber; 150}, {Attitude; Command; ClearDisplay; ShowText; ShowNumber; 150}] <= [{0}, {[0, 200)}]` does not hold
  [1]
  File "bala2-regex/undisarmed.tpe", line 7, characters 14-23:
  7 |   let token = calibrate () in
                    ^^^^^^^^^
  Typing error: The effect inequality `[{Disarm; ClearDisplay; ShowText; (Attitude; 10)*; ShowText; 1000; Arm; ShowText; (Attitude; Command; (ShowNumber | 0); 100)*}, {Disarm; ClearDisplay; ShowText; (Attitude; 10)*; ShowText; 1000; Arm; ShowText; (Attitude; Command; (ShowNumber | 0); 100)*}] <= [{Disarm; ClearDisplay; ShowText; (Attitude; 10)*; ShowText; 1000; Arm; ShowText; (Attitude; Command; (ShowNumber | 0); 100)*; Disarm}, {Disarm; ClearDisplay; ShowText; (Attitude; 10)*; ShowText; 1000; Arm; ShowText; (Attitude; Command; (ShowNumber | 0); 100)*; Disarm}]` does not hold
    File "../../examples/arduino/bala2-regex/balance_regex.tpe", lines 357-359, characters 0-51:
    357 | let calibrate () =
          ^^^^^^^^^^^^^^^^^^
    `calibrate` is defined here
    File "bala2-regex/undisarmed.tpe", lines 4-13, characters 28-18:
    4 | let supervise_undisarmed () : unit
                                    ^^^^^^
    the inequality goes through the annotation here
  [1]
  File "bala2-regex/commanding.tpe", line 10, characters 6-29:
  10 |       continue k with reading
             ^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with grade `[{ReadImu; SetMotors}, {ReadImu; SetMotors}]` accumulated since it was bound, which is not below its box grade `[{ReadImu}, {ReadImu}]`
    File "bala2-regex/commanding.tpe", line 7, characters 15-16:
    7 |   | ReadImu () k ->
                       ^
    `k` is bound here
    File "bala2-regex/commanding.tpe", line 8, characters 20-38:
    8 |       let reading = perform ReadImu () in
                            ^^^^^^^^^^^^^^^^^^
    grade `[{ReadImu}, {ReadImu}]` accumulates here (operation `ReadImu`)
    File "bala2-regex/commanding.tpe", line 9, characters 6-32:
    9 |       perform SetMotors (0i, 0i);
              ^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{SetMotors}, {SetMotors}]` accumulates here (operation `SetMotors`)
    Note: the resource inequality `[{ReadImu; SetMotors}, {ReadImu; SetMotors}] <= [{ReadImu}, {ReadImu}]` does not hold
  [1]
  File "bala2-regex/waiting.tpe", line 9, characters 6-56:
  9 |       continue k with ((0.0, 0.0, 1.0), (0.0, 0.0, 0.0))
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with grade `[{0.6}, {0.6}]` accumulated since it was bound, which is not below its box grade `[{ReadImu}, {ReadImu}]`
    File "bala2-regex/waiting.tpe", line 7, characters 15-16:
    7 |   | ReadImu () k ->
                       ^
    `k` is bound here
    File "bala2-regex/waiting.tpe", line 8, characters 6-15:
    8 |       delay 3/5;
              ^^^^^^^^^
    grade `[{0.6}, {0.6}]` accumulates here (delay)
    Note: the resource inequality `[{0.6}, {0.6}] <= [{ReadImu}, {ReadImu}]` does not hold
  [1]
  File "bala2-regex/slow.tpe", line 10, characters 6-29:
  10 |       continue k with reading
             ^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with grade `[{ReadImu; 2}, {ReadImu; 2}]` accumulated since it was bound, which is not below its box grade `[{ReadImu}, {ReadImu}]`
    File "bala2-regex/slow.tpe", line 7, characters 15-16:
    7 |   | ReadImu () k ->
                       ^
    `k` is bound here
    File "bala2-regex/slow.tpe", line 8, characters 20-38:
    8 |       let reading = perform ReadImu () in
                            ^^^^^^^^^^^^^^^^^^
    grade `[{ReadImu}, {ReadImu}]` accumulates here (operation `ReadImu`)
    File "bala2-regex/slow.tpe", line 9, characters 6-13:
    9 |       delay 2;
              ^^^^^^^
    grade `[{2}, {2}]` accumulates here (delay)
    Note: the resource inequality `[{ReadImu; 2}, {ReadImu; 2}] <= [{ReadImu}, {ReadImu}]` does not hold
  [1]

The PlatformIO project for the M5Stack Gray, its C++ sources checked without
exceptions and run-time type information:

  $ tempore --emit-arduino balance_regex --device $app/balance_regex.device.json $app/balance_regex.tpe | grep -c Wrote
  30
  $ cd _arduino/projects/balance_regex
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

The closed loop for 8 s from a tilt of 0.1 rad, the robot held until its
motors are first driven, as for examples/arduino/bala2: the supervision
calibrates the gyroscope, arms the robot after a second and shows the tilt
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
  [31.245 ms] Display cleared
  [32.245 ms] Display: Calibrating
  [533.245 ms] Display: Hold upright
  [1534.245 ms] Display: Armed
  [2435.245 ms] Display: a tilt below 2.5 degrees
  [3436.245 ms] Display: a tilt below 2.5 degrees
  [4437.245 ms] Display: a tilt below 2.5 degrees
  [5438.245 ms] Display: a tilt below 2.5 degrees
  [6439.245 ms] Display: a tilt below 2.5 degrees
  [7440.245 ms] Display: a tilt below 2.5 degrees
  [8000.000 ms] End of the simulation
  [8000.000 ms] Plant: released at 1537.0 ms
  [8000.000 ms] Plant: tilt below 2.5 degrees, wheels within 0.2 m
  [8000.000 ms] Plant: largest tilt from 1 s after the release below 2.5 degrees
  [8000.000 ms] Plant: largest drive below 0.4, last at 8000.0 ms
