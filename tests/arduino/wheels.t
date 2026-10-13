The wheel check of examples/arduino/wheels on the M5Stack BALA2, under the
regular expressions of timed operations, with the declarations of the
packages m5-imu, m5-display and bala2-base under these grades: its runs by
the interpreter, its rejected variants, the check of a periodic task against
its period from the durations of a trace, and its host simulation on a
stand, with a stalled wheel.

  $ app=../../examples/arduino/wheels
  $ tempore () { ../../tempore --grades regex-timed-interval-rational-symbolic "$@"; }
  $ packages () { tempore --package m5-imu --package m5-display --package bala2-base "$@"; }

The interpreter runs a step and a measurement with the default
implementations of the operations:

  $ packages $app/wheels.tpe
  === Run 1 ===
  return 2.94
  State: [
    [{0.5}, {0.5}],
    [{0.01}, {0.01}]
  ]
  
  === Run 2 ===
  return (0., 0.)
  State: [
    [{0.2}, {0.2}],
    { resource_0 ↦
        0.1
        # [{SetMotors; [100, 101]; ReadEncoders}, {SetMotors; [100, 101]; ReadEncoders}]
    },
    [{0.2}, {0.2}],
    [{100}, {100}],
    [{0.25}, {0.25}],
    [{0.2}, {0.2}]
  ]
  

The rejected variants, each loaded after the application: a drive commanded
after the wait, and the drive shown on the display within the window:

  $ for v in unordered shown; do packages --typecheck-only $app/wheels.tpe wheels/$v.tpe; echo "[$?]"; done
  File "wheels/unordered.tpe", lines 9-11, characters 2-37:
  9 |   unbox window as seconds in
        ^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `window` is unboxed with grade `[{100; SetMotors; ReadEncoders}, {100; SetMotors; ReadEncoders}]` accumulated since it was bound, which is not below its box grade `[{SetMotors; [100, 101]; ReadEncoders}, {SetMotors; [100, 101]; ReadEncoders}]`
    File "wheels/unordered.tpe", line 5, characters 51-57:
    5 |   box {SetMotors; [100, 101]; ReadEncoders} 0.1 as window in
                                                           ^^^^^^
    `window` is bound here
    File "wheels/unordered.tpe", line 6, characters 2-11:
    6 |   delay 100;
          ^^^^^^^^^
    grade `[{100}, {100}]` accumulates here (delay)
    File "wheels/unordered.tpe", line 7, characters 2-34:
    7 |   perform SetMotors (drive, drive);
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{SetMotors}, {SetMotors}]` accumulates here (operation `SetMotors`)
    File "wheels/unordered.tpe", line 8, characters 20-43:
    8 |   let left, right = perform ReadEncoders () in
                            ^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{ReadEncoders}, {ReadEncoders}]` accumulates here (operation `ReadEncoders`)
    Note: the resource inequality `[{100; SetMotors; ReadEncoders}, {100; SetMotors; ReadEncoders}] <= [{SetMotors; [100, 101]; ReadEncoders}, {SetMotors; [100, 101]; ReadEncoders}]` does not hold
  [1]
  File "wheels/shown.tpe", lines 10-12, characters 2-37:
  10 |   unbox window as seconds in
         ^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `window` is unboxed with grade `[{SetMotors; ShowNumber; 100; ReadEncoders}, {SetMotors; ShowNumber; 100; ReadEncoders}]` accumulated since it was bound, which is not below its box grade `[{SetMotors; [100, 101]; ReadEncoders}, {SetMotors; [100, 101]; ReadEncoders}]`
    File "wheels/shown.tpe", line 5, characters 51-57:
    5 |   box {SetMotors; [100, 101]; ReadEncoders} 0.1 as window in
                                                           ^^^^^^
    `window` is bound here
    File "wheels/shown.tpe", line 6, characters 2-34:
    6 |   perform SetMotors (drive, drive);
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{SetMotors}, {SetMotors}]` accumulates here (operation `SetMotors`)
    File "wheels/shown.tpe", line 7, characters 2-26:
    7 |   perform ShowNumber drive;
          ^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{ShowNumber}, {ShowNumber}]` accumulates here (operation `ShowNumber`)
    File "wheels/shown.tpe", line 8, characters 2-11:
    8 |   delay 100;
          ^^^^^^^^^
    grade `[{100}, {100}]` accumulates here (delay)
    File "wheels/shown.tpe", line 9, characters 20-43:
    9 |   let left, right = perform ReadEncoders () in
                            ^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{ReadEncoders}, {ReadEncoders}]` accumulates here (operation `ReadEncoders`)
    Note: the resource inequality `[{SetMotors; ShowNumber; 100; ReadEncoders}, {SetMotors; ShowNumber; 100; ReadEncoders}] <= [{SetMotors; [100, 101]; ReadEncoders}, {SetMotors; [100, 101]; ReadEncoders}]` does not hold
  [1]

A periodic task whose trace takes 10.2 to 10.8 ms is refused for a period of
10 ms:

  $ cat > slow.tpe <<'EOF'
  > let slow (tilt : float) : float # {ReadImu; 10} =
  >   let _ = perform ReadImu () in
  >   delay 10;
  >   tilt
  > EOF
  $ cat > slow.device.json <<'EOF'
  > {
  >   "board": "m5stack-gray",
  >   "tasks": [ { "function": "slow", "kind": "periodic", "period": 10 } ],
  >   "packages": ["m5-imu"]
  > }
  > EOF
  $ tempore --emit-arduino slow --device slow.device.json slow.tpe
  File "slow.device.json", line 3, characters 27-33:
  3 |   "tasks": [ { "function": "slow", "kind": "periodic", "period": 10 } ],
                                 ^^^^^^
  Compilation error: The effect `[{ReadImu; 10}, {ReadImu; 10}]` of the function 'slow' of a periodic task is not below its period: its durations are not all below 10
  [1]

The project, for the board m5stack-gray, with the running-time bounds of
the operations, which the monitors check; its sources compile without
exceptions and run-time type information:

  $ tempore --emit-arduino wheels --device $app/wheels.device.json $app/wheels.tpe | grep -c Wrote
  29
  $ grep -A3 '^\[env' _arduino/projects/wheels/platformio.ini
  [env:m5stack-gray]
  platform = espressif32
  board = m5stack-grey
  framework = arduino
  $ grep 'bounds = ' _arduino/projects/wheels/src/tempore_operations.cpp
  static const tempore_bounds tempore_op_ReadImu_bounds = {200, false, 800, false, true};
  static const tempore_bounds tempore_op_ShowText_bounds = {200, false, 20000, false, true};
  static const tempore_bounds tempore_op_ShowNumber_bounds = {200, false, 20000, false, true};
  static const tempore_bounds tempore_op_ClearDisplay_bounds = {10000, false, 60000, false, true};
  static const tempore_bounds tempore_op_SetMotors_bounds = {50, false, 500, false, true};
  static const tempore_bounds tempore_op_ReadEncoders_bounds = {100, false, 600, false, true};
  static const tempore_bounds tempore_op_ResetEncoders_bounds = {50, false, 500, false, true};
  static const tempore_bounds tempore_op_Publish_bounds = {0, false, 50, false, true};
  static const tempore_bounds tempore_op_Latest_bounds = {0, false, 50, false, true};
  $ cd _arduino/projects/wheels
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

Three seconds of simulated time: the check spins the wheels forwards and
backwards, each window from the drive command to the reading of the encoders
lasting about 100.25 ms, shows the forward speeds, 310 counts per second, and
repeats after two seconds; the step runs every 10 ms:

  $ tempore --emit-arduino wheels --device $app/wheels.device.json --host-simulate 3 $app/wheels.tpe | grep '\] \(Display\|Operation SetMotors\|Operation ReadEncoders\)\|simulation'
  [31.135 ms] Display cleared
  [31.495 ms] Operation SetMotors took 135 us
  [131.743 ms] Operation ReadEncoders took 248 us
  [131.878 ms] Operation SetMotors took 135 us
  [432.238 ms] Operation SetMotors took 135 us
  [532.486 ms] Operation ReadEncoders took 248 us
  [532.621 ms] Operation SetMotors took 135 us
  [533.621 ms] Display: Wheels turn
  [534.621 ms] Display: 310.000
  [535.621 ms] Display: 310.000
  [2566.621 ms] Display cleared
  [2566.981 ms] Operation SetMotors took 135 us
  [2667.229 ms] Operation ReadEncoders took 248 us
  [2667.364 ms] Operation SetMotors took 135 us
  [2967.724 ms] Operation SetMotors took 135 us
  [3000.000 ms] End of the simulation
  $ tempore --emit-arduino wheels --device $app/wheels.device.json --host-simulate 3 $app/wheels.tpe | grep -c 'Release watch'
  300

With the right wheel stalled, the check reports its fault:

  $ cd _arduino/projects/wheels
  $ c++ -std=c++17 -Wall -Wextra -Werror -DTEMPORE_HOST -DTEMPORE_TRACE -DSTAND_STALLED_WHEEL -pthread -I host -I src src/*.cpp host/*.cpp -o simulation
  $ ./simulation 3000000 | grep '\] Display'
  [31.135 ms] Display cleared
  [533.621 ms] Display: Right wheel fault
  [534.621 ms] Display: 310.000
  [535.621 ms] Display: 0.000
  [2566.621 ms] Display cleared
