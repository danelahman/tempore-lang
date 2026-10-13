The peak tilt recorder of examples/arduino/peak on the M5Stack CoreS3 Lite,
under the operation counts, with the declarations of the packages m5-imu and
m5-display under these grades: its runs by the interpreter, its rejected
variants, its project, whose operations have no running-time bounds and
whose periodic task is not checked against its period by the typechecker,
and its host simulation.

  $ app=../../examples/arduino/peak
  $ tempore () { ../../tempore --grades counts-upper-bound "$@"; }
  $ packages () { tempore --package m5-imu --package m5-display --board m5stack-cores3 "$@"; }

The interpreter runs a step and an iteration of the recorder with the
default implementations of the operations:

  $ packages $app/peak.tpe
  === Run 1 ===
  return 2.7
  State: []
  
  === Run 2 ===
  return ()
  State: [
    { resource_0 ↦ 0. # ((StorePeak, 0), (_, ∞)) }
  ]
  

The rejected variants, each loaded after the application: a step that
writes the flash, and a recorder that compares a second tilt with a copy of
the record read before a write:

  $ for v in stored twice; do packages --typecheck-only $app/peak.tpe peak/$v.tpe; echo "[$?]"; done
  File "peak/stored.tpe", lines 3-8, characters 31-6:
  3 | let step_stored (tilt : float) : float # ((ReadImu, 1), (Publish, 1)) =
                                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `((Publish, 1), (ReadImu, 1), (StorePeak, 1))`, which does not match its annotated grade `((Publish, 1), (ReadImu, 1))`
    Note: the effect inequality `((Publish, 1), (ReadImu, 1), (StorePeak, 1)) <= ((Publish, 1), (ReadImu, 1))` does not hold
  [1]
  File "peak/twice.tpe", lines 11-12, characters 2-63:
  11 |   unbox copy as peak in
         ^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `copy` is unboxed with grade `((Latest, 2), (StorePeak, 1))` accumulated since it was bound, which is not below its box grade `((StorePeak, 0), (_, ∞))`
    File "peak/twice.tpe", line 5, characters 43-47:
    5 |   box ((StorePeak, 0), (_, ∞)) stored as copy in
                                                 ^^^^
    `copy` is bound here
    File "peak/twice.tpe", line 6, characters 14-43:
    6 |   let first = magnitude (perform Latest ()) in
                      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `(Latest, 1)` accumulates here (this computation)
    File "peak/twice.tpe", line 8, characters 2-63:
    8 |   (if first > peak +. 0.5 then perform StorePeak first else ());
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `(StorePeak, 1)` accumulates here (this computation)
    File "peak/twice.tpe", line 10, characters 15-44:
    10 |   let second = magnitude (perform Latest ()) in
                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `(Latest, 1)` accumulates here (this computation)
    Note: the resource inequality `((Latest, 2), (StorePeak, 1)) <= ((StorePeak, 0), (_, ∞))` does not hold
  [1]

The project, for the board m5stack-cores3: the calls of the eight operations
are monitored without running-time bounds, and the steps of the periodic
task against its period by the monitor only; its sources compile without
exceptions and run-time type information:

  $ tempore --emit-arduino peak --device $app/peak.device.json $app/peak.tpe | grep -c Wrote
  27
  $ grep -c 'tempore_operation_monitor .*, nullptr);' _arduino/projects/peak/src/tempore_operations.cpp
  9
  $ grep 'The periodic task\|tempore_monitor_period' _arduino/projects/peak/src/main.cpp
  // The periodic task step, of period 20000 us; its grades bound no durations, so its steps are checked against the period by the monitor only.
      tempore_monitor_period(&tempore_task0_monitor, start, tempore_clock_us());
  $ cd _arduino/projects/peak
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

Three seconds of simulated time: the recorder writes the flash once, when
the tilt first exceeds the record, and shows the record every second,
between the name of the example and the footer:

  $ tempore --emit-arduino peak --device $app/peak.device.json --host-simulate 3 $app/peak.tpe | grep '\] \(Display\|Flash\)\|simulation'
  [31.000 ms] Display cleared
  [34.920 ms] Display at (0, 0): Peak tilt recorder
  [35.920 ms] Display: Peak tilt
  [36.920 ms] Display: 0.000
  [39.680 ms] Display at (80, 230): Typechecked by Tempore (tempore-lang.ee)
  [1039.680 ms] Flash: record 5.639 degrees
  [1070.680 ms] Display cleared
  [1074.600 ms] Display at (0, 0): Peak tilt recorder
  [1075.600 ms] Display: Peak tilt
  [1076.600 ms] Display: 5.639
  [1079.360 ms] Display at (80, 230): Typechecked by Tempore (tempore-lang.ee)
  [2110.360 ms] Display cleared
  [2114.280 ms] Display at (0, 0): Peak tilt recorder
  [2115.280 ms] Display: Peak tilt
  [2116.280 ms] Display: 5.639
  [2119.040 ms] Display at (80, 230): Typechecked by Tempore (tempore-lang.ee)
  [3000.000 ms] End of the simulation
  $ tempore --emit-arduino peak --device $app/peak.device.json --host-simulate 3 $app/peak.tpe | grep -c 'Release step'
  150
