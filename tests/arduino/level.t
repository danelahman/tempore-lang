The spirit level of examples/arduino/level on the M5Stack CoreS3 Lite, with
the packages m5-imu, m5-display, m5-touch and m5-speaker, under the regular
expressions of timed operations: its runs by the interpreter, its rejected
variants, its project and its host simulation, over the surface and the taps
of its host model.

  $ app=../../examples/arduino/level
  $ tempore () { ../../tempore --grades regex-timed-interval-rational-symbolic "$@"; }
  $ packages () {
  >   tempore --package m5-imu --package m5-display --package m5-touch \
  >     --package m5-speaker --board m5stack-cores3 "$@"
  > }

The interpreter runs a step from the initial state and a calibration with
the default implementations of the operations:

  $ packages $app/level.tpe
  === Run 1 ===
  return (Uncalibrated, 0, 100, false)
  State: [
    [{31}, {31}],
    [{2}, {2}],
    [{2}, {2}],
    [{2}, {2}],
    [{2}, {2}],
    [{2}, {2}],
    [{0.2}, {0.2}],
    { resource_0 ↦ Uncalibrated # [{Touched; ReadImu}, {Touched; ReadImu}] },
    [{0.3}, {0.3}],
    [{0.6}, {0.6}],
    { resource_1 ↦ (0., 0., 1.) # [{0}, {5}] },
    [{2}, {2}],
    [{2}, {2}],
    [{2}, {2}],
    [{2}, {2}],
    [{2}, {2}]
  ]
  
  === Run 2 ===
  return (Offsets (0., -0.))
  State: [
    [{0.6}, {0.6}],
    [{10}, {10}],
    [{0.6}, {0.6}],
    [{10}, {10}],
    [{0.6}, {0.6}],
    [{10}, {10}],
    [{0.6}, {0.6}],
    { resource_0 ↦
        Offsets (0., -0.)
        # [{SelfTestImu; Beep}, {SelfTestImu; Beep}]
    },
    [{17}, {17}],
    [{0.05}, {0.05}]
  ]
  

The rejected variants, each loaded after the application: a calibration
without a self-test, a step that applies the calibration after a
reconfiguration, a step that applies a calibration to a reading taken
before it, and a step that draws before it reads the unit:

  $ for v in untested reconfigured stale drawn_first; do packages --typecheck-only $app/level.tpe level/$v.tpe; echo "[$?]"; done
  File "level/untested.tpe", lines 7-8, characters 2-8:
  7 |   unbox untested as tested in
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `untested` is unboxed with grade `[{Beep}, {Beep}]` accumulated since it was bound, which is not below its box grade `[{SelfTestImu; Beep}, {SelfTestImu; Beep}]`
    File "level/untested.tpe", line 5, characters 46-54:
    5 |   box {SelfTestImu; Beep} (Offsets (x, y)) as untested in
                                                      ^^^^^^^^
    `untested` is bound here
    File "level/untested.tpe", line 6, characters 2-26:
    6 |   perform Beep (2000, 100);
          ^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{Beep}, {Beep}]` accumulates here (operation `Beep`)
    Note: the resource inequality `[{Beep}, {Beep}] <= [{SelfTestImu; Beep}, {SelfTestImu; Beep}]` does not hold
  [1]
  File "level/reconfigured.tpe", lines 11-13, characters 2-39:
  11 |   unbox kept as calibration in
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `kept` is unboxed with grade `[{Touched; (0 | ConfigureImu; Beep); ReadImu}, {Touched; (0 | ConfigureImu; Beep); ReadImu}]` accumulated since it was bound, which is not below its box grade `[{Touched; ReadImu}, {Touched; ReadImu}]`
    File "level/reconfigured.tpe", line 4, characters 40-44:
    4 |   box {Touched; ReadImu} calibration as kept in
                                                ^^^^
    `kept` is bound here
    File "level/reconfigured.tpe", line 5, characters 22-40:
    5 |   let touched, x, y = perform Touched () in
                              ^^^^^^^^^^^^^^^^^^
    grade `[{Touched}, {Touched}]` accumulates here (operation `Touched`)
    File "level/reconfigured.tpe", lines 6-9, characters 2-11:
    6 |   (if touched && corner x y then (
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{0 | ConfigureImu; Beep}, {0 | ConfigureImu; Beep}]` accumulates here (this computation)
    File "level/reconfigured.tpe", line 10, characters 17-35:
    10 |   let accel, _ = perform ReadImu () in
                          ^^^^^^^^^^^^^^^^^^
    grade `[{ReadImu}, {ReadImu}]` accumulates here (operation `ReadImu`)
    Note: the resource inequality `[{Touched; (0 | ConfigureImu; Beep); ReadImu}, {Touched; (0 | ConfigureImu; Beep); ReadImu}] <= [{Touched; ReadImu}, {Touched; ReadImu}]` does not hold
  [1]
  File "level/stale.tpe", lines 8-10, characters 2-33:
  8 |   unbox reading as accel in
        ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `reading` is unboxed with grade `[{0 | ReadImu; 10; ReadImu; 10; ReadImu; 10; ReadImu; SelfTestImu; Beep}, {0 | ReadImu; 10; ReadImu; 10; ReadImu; 10; ReadImu; SelfTestImu; Beep}]` accumulated since it was bound, which is not below its box grade `[{0}, {5}]`
    File "level/stale.tpe", line 6, characters 22-29:
    6 |   box [0, 5] accel as reading in
                              ^^^^^^^
    `reading` is bound here
    File "level/stale.tpe", line 7, characters 20-65:
    7 |   let calibration = if touched then calibrate () else calibration in
                            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{0 | ReadImu; 10; ReadImu; 10; ReadImu; 10; ReadImu; SelfTestImu; Beep}, {0 | ReadImu; 10; ReadImu; 10; ReadImu; 10; ReadImu; SelfTestImu; Beep}]` accumulates here (this computation)
    Note: the resource inequality `[{0 | ReadImu; 10; ReadImu; 10; ReadImu; 10; ReadImu; SelfTestImu; Beep}, {0 | ReadImu; 10; ReadImu; 10; ReadImu; 10; ReadImu; SelfTestImu; Beep}] <= [{0}, {5}]` does not hold
  [1]
  File "level/drawn_first.tpe", lines 3-9, characters 66-39:
  3 | let step_drawn_first ((calibration, age, rate, touching) : state) : state
                                                                        ^^^^^^^
  Typing error: This function's body has grade `[{Touched; ShowNumberAt; ShowNumberAt; ShowTextAt; ShowTextAt; ShowNumberAt; ReadImu}, {Touched; ShowNumberAt; ShowNumberAt; ShowTextAt; ShowTextAt; ShowNumberAt; ReadImu}]`, which does not match its annotated grade `[{Touched; ReadImu; ShowNumberAt; ShowNumberAt; ShowTextAt; ShowTextAt; ShowNumberAt}, {Touched; ReadImu; ShowNumberAt; ShowNumberAt; ShowTextAt; ShowTextAt; ShowNumberAt}]`
    Note: the effect inequality `[{Touched; ShowNumberAt; ShowNumberAt; ShowTextAt; ShowTextAt; ShowNumberAt; ReadImu}, {Touched; ShowNumberAt; ShowNumberAt; ShowTextAt; ShowTextAt; ShowNumberAt; ReadImu}] <= [{Touched; ReadImu; ShowNumberAt; ShowNumberAt; ShowTextAt; ShowTextAt; ShowNumberAt}, {Touched; ReadImu; ShowNumberAt; ShowNumberAt; ShowTextAt; ShowTextAt; ShowNumberAt}]` does not hold
  [1]

The project, for the board m5stack-cores3, whose step the typechecker checks
against its period; its sources compile without exceptions and run-time type
information:

  $ tempore --emit-arduino level --device $app/level.device.json $app/level.tpe | grep -c Wrote
  31
  $ cd _arduino/projects/level
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

Nine seconds of simulated time, the tones, the reconfigurations and the
changes of the verdict and of the state of the calibration: uncalibrated, calibrated by the tap at 1 s, the verdict
lost on the steeper surface from 3 to 4.5 s, invalidated by the
reconfiguration at 5 s, and calibrated again at 6.5 s:

  $ changes () {
  >   awk '{ l = $0; sub(/^[^]]*] /, "", l)
  >          if ($3 != "Display" || l != last[$6]) print
  >          if ($3 == "Display") last[$6] = l }' | sed 's/ *$//'
  > }
  $ tempore --emit-arduino level --device $app/level.device.json --host-simulate 9 $app/level.tpe |
  >   grep 'Display at (0, 1[16]0)\|Speaker\|accelerometer\|simulation' | changes
  [49.000 ms] IMU: accelerometer at 100 Hz
  [62.583 ms] Display at (0, 110):
  [66.143 ms] Display at (0, 160): Tap to calibrate
  [1099.174 ms] Speaker: 2000 Hz for 100 ms
  [1112.457 ms] Display at (0, 110): LEVEL
  [1116.017 ms] Display at (0, 160): Calibrated
  [3062.583 ms] Display at (0, 110):
  [4562.583 ms] Display at (0, 110): LEVEL
  [5049.500 ms] IMU: accelerometer at 400 Hz
  [5049.550 ms] Speaker: 600 Hz for 50 ms
  [5062.833 ms] Display at (0, 110):
  [5066.393 ms] Display at (0, 160): Recalibrate (tap)
  [6599.174 ms] Speaker: 2000 Hz for 100 ms
  [6612.457 ms] Display at (0, 110): LEVEL
  [6616.017 ms] Display at (0, 160): Calibrated
  [9000.000 ms] End of the simulation

A run of 10 minutes after a calibration: the calibration expires after 2400
steps, and the screen asks for a new one:

  $ tempore --emit-arduino level --device $app/level.device.json --host-simulate 610 $app/level.tpe |
  >   grep 'Display at (0, 160)\|simulation' | changes
  [66.143 ms] Display at (0, 160): Tap to calibrate
  [1116.017 ms] Display at (0, 160): Calibrated
  [5066.393 ms] Display at (0, 160): Recalibrate (tap)
  [6616.017 ms] Display at (0, 160): Calibrated
  [606566.143 ms] Display at (0, 160): Recalibrate (tap)
  [610000.000 ms] End of the simulation
