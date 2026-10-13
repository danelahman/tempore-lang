The wheel check of examples/arduino/wheels on the M5Stack BALA2, under the
regular expressions of timed operations, with the declarations of the
packages m5-imu, m5-display and bala2-base under these grades: its runs by
the interpreter, its rejected variants, the check of a periodic task against
its period from the durations of a trace, and its host simulation on a
stand, with a stalled wheel.

  $ app=../../examples/arduino/wheels
  $ tempore () { ../../tempore --grades regex-timed-interval-rational-symbolic "$@"; }
  $ packages () { tempore --package m5-imu --package m5-display --package bala2-base --board m5stack-gray "$@"; }

The interpreter, with the declarations of the packages under their
running-time bounds on the M5Stack Gray, the board of the manifest, as for
the rejected variants below, runs a step and a measurement with the default
implementations of the operations:

  $ packages $app/wheels.tpe
  === Run 1 ===
  return 2.94
  State: [
    [{0.6}, {0.6}],
    [{0.01}, {0.01}]
  ]
  
  === Run 2 ===
  return (0., 0.)
  State: [
    [{0.35}, {0.35}],
    { resource_0 ↦
        0.1
        # [{SetMotors; [100, 101]; ReadEncoders}, {SetMotors; [100, 101]; ReadEncoders}]
    },
    [{0.2}, {0.2}],
    [{100}, {100}],
    [{0.5}, {0.5}],
    [{0.2}, {0.2}]
  ]
  

The rejected variants, each loaded after the application: a drive commanded
after the wait, and the drive shown on the display within the window:

  $ for v in unordered shown; do packages --typecheck-only $app/wheels.tpe wheels/$v.tpe; echo "[$?]"; done
  File "wheels/unordered.tpe", lines 9-11, characters 2-63:
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
  File "wheels/shown.tpe", lines 11-13, characters 2-63:
  11 |   unbox window as seconds in
         ^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `window` is unboxed with grade `[{SetMotors; ShowNumber; 100; ReadEncoders}, {SetMotors; ShowNumber; 100; ReadEncoders}]` accumulated since it was bound, which is not below its box grade `[{SetMotors; [100, 101]; ReadEncoders}, {SetMotors; [100, 101]; ReadEncoders}]`
    File "wheels/shown.tpe", line 6, characters 51-57:
    6 |   box {SetMotors; [100, 101]; ReadEncoders} 0.1 as window in
                                                           ^^^^^^
    `window` is bound here
    File "wheels/shown.tpe", line 7, characters 2-34:
    7 |   perform SetMotors (drive, drive);
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{SetMotors}, {SetMotors}]` accumulates here (operation `SetMotors`)
    File "wheels/shown.tpe", line 8, characters 2-26:
    8 |   perform ShowNumber shown;
          ^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{ShowNumber}, {ShowNumber}]` accumulates here (operation `ShowNumber`)
    File "wheels/shown.tpe", line 9, characters 2-11:
    9 |   delay 100;
          ^^^^^^^^^
    grade `[{100}, {100}]` accumulates here (delay)
    File "wheels/shown.tpe", line 10, characters 20-43:
    10 |   let left, right = perform ReadEncoders () in
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

A grade with a star bounds the durations below by its fastest trace, and not
above: its function is refused for a periodic task, and accepted for a
repeated free task iff that lower bound is positive:

  $ cat > star.tpe <<'EOF'
  > let poll () : unit # {ReadImu; (ReadImu; 10)*} =
  >   let _ = perform ReadImu () in
  >   ()
  > 
  > let idle () : unit # {(ReadImu; 10)*} = ()
  > EOF
  $ cat > star.device.json <<'EOF'
  > {
  >   "board": "m5stack-gray",
  >   "tasks": [ { "function": "poll", "kind": "periodic", "period": 10 } ],
  >   "packages": ["m5-imu"]
  > }
  > EOF
  $ tempore --emit-arduino star --device star.device.json star.tpe
  File "star.device.json", line 3, characters 27-33:
  3 |   "tasks": [ { "function": "poll", "kind": "periodic", "period": 10 } ],
                                 ^^^^^^
  Compilation error: The effect `[{ReadImu; (ReadImu; 10)*}, {ReadImu; (ReadImu; 10)*}]` of the function 'poll' of a periodic task is not below its period: its durations are not all below 10
  [1]
  $ sed -i.bak 's/"kind": "periodic", "period": 10/"kind": "free", "repeat": true/' star.device.json
  $ tempore --emit-arduino star --device star.device.json star.tpe | tail -1
  Wrote _arduino/projects/star/host/m5_imu_model.cpp
  $ sed -i.bak 's/"poll"/"idle"/' star.device.json
  $ tempore --emit-arduino idle --device star.device.json star.tpe
  File "star.device.json", line 3, characters 27-33:
  3 |   "tasks": [ { "function": "idle", "kind": "free", "repeat": true } ],
                                 ^^^^^^
  Compilation error: The effect `[{(ReadImu; 10)*}, {(ReadImu; 10)*}]` of the function 'idle' of a repeated free task does not bound its durations below by a positive time, so that the task may never yield
  [1]

The project, for the board m5stack-gray, with the running-time bounds of
the operations, which the monitors check; its sources compile without
exceptions and run-time type information:

  $ tempore --emit-arduino wheels --device $app/wheels.device.json $app/wheels.tpe | grep -c Wrote
  31
  $ grep -A3 '^\[env' _arduino/projects/wheels/platformio.ini
  [env:m5stack-gray]
  platform = espressif32@7.1.3
  board = m5stack-grey
  framework = arduino
  $ grep 'bounds = ' _arduino/projects/wheels/src/tempore_operations.cpp
  static const tempore_bounds tempore_op_ReadImu_bounds = {550, false, 1250, false, true};
  static const tempore_bounds tempore_op_ShowText_bounds = {50, false, 12500, false, true};
  static const tempore_bounds tempore_op_ShowNumber_bounds = {50, false, 12500, false, true};
  static const tempore_bounds tempore_op_ClearDisplay_bounds = {31000, false, 48000, false, true};
  static const tempore_bounds tempore_op_ShowTextAt_bounds = {50, false, 33000, false, true};
  static const tempore_bounds tempore_op_SetMotors_bounds = {200, false, 450, false, true};
  static const tempore_bounds tempore_op_ReadEncoders_bounds = {450, false, 1000, false, true};
  static const tempore_bounds tempore_op_ResetEncoders_bounds = {300, false, 600, false, true};
  static const tempore_bounds tempore_op_Publish_bounds = {0, false, 50, false, true};
  static const tempore_bounds tempore_op_Latest_bounds = {0, false, 50, false, true};
  $ cd _arduino/projects/wheels
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

Three seconds of simulated time: the check spins the wheels forwards and
backwards, each window from the drive command to the reading of the encoders
lasting about 100.47 ms, shows the forward speeds, 310 counts per second, and
repeats after two seconds; the step runs every 10 ms:

  $ tempore --emit-arduino wheels --device $app/wheels.device.json --host-simulate 3 $app/wheels.tpe | grep '\] \(Display\|Operation SetMotors\|Operation ReadEncoders\)\|simulation'
  [31.245 ms] Display cleared
  [35.025 ms] Display at (0, 0): Wheel check
  [37.785 ms] Display at (80, 230): Typechecked by Tempore (tempore-lang.ee)
  [38.365 ms] Operation SetMotors took 245 us
  [138.833 ms] Operation ReadEncoders took 468 us
  [139.078 ms] Operation SetMotors took 245 us
  [439.658 ms] Operation SetMotors took 245 us
  [540.126 ms] Operation ReadEncoders took 468 us
  [540.371 ms] Operation SetMotors took 245 us
  [541.371 ms] Display: Wheels turn
  [542.371 ms] Display: 310.000
  [543.371 ms] Display: 310.000
  [2574.371 ms] Display cleared
  [2578.151 ms] Display at (0, 0): Wheel check
  [2580.911 ms] Display at (80, 230): Typechecked by Tempore (tempore-lang.ee)
  [2581.491 ms] Operation SetMotors took 245 us
  [2681.959 ms] Operation ReadEncoders took 468 us
  [2682.204 ms] Operation SetMotors took 245 us
  [2982.784 ms] Operation SetMotors took 245 us
  [3000.000 ms] End of the simulation
  $ tempore --emit-arduino wheels --device $app/wheels.device.json --host-simulate 3 $app/wheels.tpe | grep -c 'Release watch'
  300

With the right wheel stalled, the check reports its fault:

  $ cd _arduino/projects/wheels
  $ c++ -std=c++17 -Wall -Wextra -Werror -ffp-contract=off -DTEMPORE_HOST -DTEMPORE_TRACE -DSTAND_STALLED_WHEEL -pthread -I host -I src src/*.cpp host/*.cpp -o simulation
  $ ./simulation 3000000 | grep '\] Display'
  [31.245 ms] Display cleared
  [35.025 ms] Display at (0, 0): Wheel check
  [37.785 ms] Display at (80, 230): Typechecked by Tempore (tempore-lang.ee)
  [541.371 ms] Display: Right wheel fault
  [542.371 ms] Display: 310.000
  [543.371 ms] Display: 0.000
  [2574.371 ms] Display cleared
  [2578.151 ms] Display at (0, 0): Wheel check
  [2580.911 ms] Display at (80, 230): Typechecked by Tempore (tempore-lang.ee)
