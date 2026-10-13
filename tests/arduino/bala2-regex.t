The BALA2 application of examples/arduino/bala2-regex: the balancing robot
under the regular expressions of timed operations, with the declarations of
the packages m5-imu, m5-display and bala2-base under these grades and the
binding file and host model of examples/arduino/bala2: its runs by the
interpreter, its rejected variants, and its closed loop with the host model
of the robot.

  $ app=../../examples/arduino/bala2-regex
  $ tempore () { ../../tempore --grades regex-timed-interval-rational-symbolic "$@"; }
  $ packages () { tempore --package m5-imu --package m5-display --package bala2-base "$@"; }

The interpreter, with the declarations of the packages, runs two control
steps with the default implementations of the operations:

  $ packages $app/balance_regex.tpe
  === Run 1 ===
  return (2.8812, 0., 0., 0.)
  State: [
    [{0.5}, {0.5}],
    { resource_0 ↦
        ((0., 0., 1.), (0., 0., 0.))
        # [{ReadEncoders; Setpoints}, {ReadEncoders; Setpoints}]
    },
    [{0.25}, {0.25}],
    [{0.01}, {0.01}],
    [{0.01}, {0.01}],
    [{0.2}, {0.2}],
    [{0.5}, {0.5}],
    { resource_1 ↦
        ((0., 0., 1.), (0., 0., 0.))
        # [{ReadEncoders; Setpoints}, {ReadEncoders; Setpoints}]
    },
    [{0.25}, {0.25}],
    [{0.01}, {0.01}],
    [{0.01}, {0.01}],
    [{0.2}, {0.2}]
  ]
  

The rejected variants, each loaded after the application: a step that reads
the encoders before the unit, a stale reading of the unit, a reading used
after a command of the motors, a measurement of the bias without disarming,
arming with the boxed calibration, arming before the robot is held upright
and with an expired calibration, a drive iteration that may exceed the
200 ms of a command, and a supervision that leaves the robot armed:

  $ for v in unordered stale stopped armed unchecked hasty late redrawn undisarmed; do packages --typecheck-only $app/balance_regex.tpe bala2-regex/$v.tpe; echo "[$?]"; done
  File "bala2-regex/unordered.tpe", lines 4-15, characters 63-75:
  4 | let step_unordered ((tilt, speed, integral, position) : state) : state
                                                                     ^^^^^^^
  Typing error: This function's body has grade `[{ReadEncoders; ReadImu; Setpoints; Publish; SetMotors}, {ReadEncoders; ReadImu; Setpoints; Publish; SetMotors}]`, which does not match its annotated grade `[{ReadImu; ReadEncoders; Setpoints; Publish; SetMotors}, {ReadImu; ReadEncoders; Setpoints; Publish; SetMotors}]`
    Note: the effect inequality `[{ReadEncoders; ReadImu; Setpoints; Publish; SetMotors}, {ReadEncoders; ReadImu; Setpoints; Publish; SetMotors}] <= [{ReadImu; ReadEncoders; Setpoints; Publish; SetMotors}, {ReadImu; ReadEncoders; Setpoints; Publish; SetMotors}]` does not hold
  [1]
  File "bala2-regex/stale.tpe", lines 13-21, characters 2-49:
  13 |   unbox fresh as imu in
         ^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `fresh` is unboxed with grade `[{ReadEncoders; 1.5; ReadEncoders; Setpoints}, {ReadEncoders; 1.5; ReadEncoders; Setpoints}]` accumulated since it was bound, which is not below its box grade `[{ReadEncoders; Setpoints}, {ReadEncoders; Setpoints}]`
    File "bala2-regex/stale.tpe", line 6, characters 43-48:
    6 |   box {ReadEncoders; Setpoints} reading as fresh in
                                                   ^^^^^
    `fresh` is bound here
    File "bala2-regex/stale.tpe", line 7, characters 22-45:
    7 |   let left1, right1 = perform ReadEncoders () in
                              ^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{ReadEncoders}, {ReadEncoders}]` accumulates here (operation `ReadEncoders`)
    File "bala2-regex/stale.tpe", line 8, characters 2-11:
    8 |   delay 1.5;
          ^^^^^^^^^
    grade `[{1.5}, {1.5}]` accumulates here (delay)
    File "bala2-regex/stale.tpe", line 9, characters 22-45:
    9 |   let left2, right2 = perform ReadEncoders () in
                              ^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{ReadEncoders}, {ReadEncoders}]` accumulates here (operation `ReadEncoders`)
    File "bala2-regex/stale.tpe", line 12, characters 34-54:
    12 |   let armed, bias, target, turn = perform Setpoints () in
                                           ^^^^^^^^^^^^^^^^^^^^
    grade `[{Setpoints}, {Setpoints}]` accumulates here (operation `Setpoints`)
    Note: the resource inequality `[{ReadEncoders; 1.5; ReadEncoders; Setpoints}, {ReadEncoders; 1.5; ReadEncoders; Setpoints}] <= [{ReadEncoders; Setpoints}, {ReadEncoders; Setpoints}]` does not hold
  [1]
  File "bala2-regex/stopped.tpe", lines 10-17, characters 2-75:
  10 |   unbox fresh as imu in
         ^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `fresh` is unboxed with grade `[{ReadEncoders; Setpoints; (SetMotors | 0)}, {ReadEncoders; Setpoints; (SetMotors | 0)}]` accumulated since it was bound, which is not below its box grade `[{ReadEncoders; Setpoints}, {ReadEncoders; Setpoints}]`
    File "bala2-regex/stopped.tpe", line 6, characters 43-48:
    6 |   box {ReadEncoders; Setpoints} reading as fresh in
                                                   ^^^^^
    `fresh` is bound here
    File "bala2-regex/stopped.tpe", line 7, characters 20-43:
    7 |   let left, right = perform ReadEncoders () in
                            ^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{ReadEncoders}, {ReadEncoders}]` accumulates here (operation `ReadEncoders`)
    File "bala2-regex/stopped.tpe", line 8, characters 34-54:
    8 |   let armed, bias, target, turn = perform Setpoints () in
                                          ^^^^^^^^^^^^^^^^^^^^
    grade `[{Setpoints}, {Setpoints}]` accumulates here (operation `Setpoints`)
    File "bala2-regex/stopped.tpe", line 9, characters 2-52:
    9 |   (if armed then () else perform SetMotors (0i, 0i));
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
    File "../../examples/arduino/bala2-regex/balance_regex.tpe", line 82, characters 0-60:
    82 | operation Arm : calibration ~> unit # {Arm} within [0, 0.05]
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
  Typing error: Variable `expiry` is unboxed with grade `[{Attitude; Command; ClearDisplay; ShowText; ShowNumber; 100}, {Attitude; Command; ClearDisplay; ShowText; ShowNumber; 100}]` accumulated since it was bound, which is not below its box grade `[{0}, {[0, 200)}]`
    File "bala2-regex/redrawn.tpe", line 16, characters 25-31:
    16 |       box [0, 200) () as expiry in
                                  ^^^^^^
    `expiry` is bound here
    File "bala2-regex/redrawn.tpe", line 17, characters 6-26:
    17 |       drive_step_redrawn m;
               ^^^^^^^^^^^^^^^^^^^^
    grade `[{Attitude; Command; ClearDisplay; ShowText; ShowNumber; 100}, {Attitude; Command; ClearDisplay; ShowText; ShowNumber; 100}]` accumulates here (this computation)
    Note: the resource inequality `[{Attitude; Command; ClearDisplay; ShowText; ShowNumber; 100}, {Attitude; Command; ClearDisplay; ShowText; ShowNumber; 100}] <= [{0}, {[0, 200)}]` does not hold
  [1]
  File "bala2-regex/undisarmed.tpe", line 7, characters 14-23:
  7 |   let token = calibrate () in
                    ^^^^^^^^^
  Typing error: The effect inequality `[{Disarm; ClearDisplay; ShowText; (Attitude; 10)*; ShowText; 1000; Arm; ShowText; (Attitude; Command; (ShowNumber | 0); 100)*}, {Disarm; ClearDisplay; ShowText; (Attitude; 10)*; ShowText; 1000; Arm; ShowText; (Attitude; Command; (ShowNumber | 0); 100)*}] <= [{Disarm; ClearDisplay; ShowText; (Attitude; 10)*; ShowText; 1000; Arm; ShowText; (Attitude; Command; (ShowNumber | 0); 100)*; Disarm}, {Disarm; ClearDisplay; ShowText; (Attitude; 10)*; ShowText; 1000; Arm; ShowText; (Attitude; Command; (ShowNumber | 0); 100)*; Disarm}]` does not hold
    File "../../examples/arduino/bala2-regex/balance_regex.tpe", lines 310-312, characters 0-51:
    310 | let calibrate () =
          ^^^^^^^^^^^^^^^^^^
    `calibrate` is defined here
    File "bala2-regex/undisarmed.tpe", lines 4-13, characters 28-18:
    4 | let supervise_undisarmed () : unit
                                    ^^^^^^
    the inequality goes through the annotation here
  [1]

The PlatformIO project for the M5Stack Gray, its C++ sources checked without
exceptions and run-time type information:

  $ tempore --emit-arduino balance_regex --device $app/balance_regex.device.json $app/balance_regex.tpe | grep -c Wrote
  29
  $ cd _arduino/projects/balance_regex
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

The closed loop for 8 s from a tilt of 0.1 rad, the robot held until its
motors are first driven, as for examples/arduino/bala2: the supervision
calibrates the gyroscope, arms the robot after a second and shows the tilt
every second; the tilt stays below a degree from one second after the
release:

  $ tempore --emit-arduino balance_regex --device $app/balance_regex.device.json --host-simulate 8 $app/balance_regex.tpe | grep -v '^Wrote\|\] \(Release\|Start\|End step\|Operation\|IMU\|I2C\|Delay\)'
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
