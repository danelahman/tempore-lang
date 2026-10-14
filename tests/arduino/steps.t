The step counter of examples/arduino/steps on the M5Stack CoreS3 Lite, with
the packages m5-imu and m5-display, under the event separation: its run by
the interpreter, its rejected variants, its project and its host simulation
over the walk of its host model.

  $ app=../../examples/arduino/steps
  $ . ../helpers.sh
  $ from_header $app/steps.tpe

The interpreter runs three rounds of two readings with the default
implementations of the operations, which read a unit at rest; each reading
is followed by the bar of the acceleration and the delay, and the first of
each round is boxed until the second:

  $ packages $app/steps.tpe
  === Run 1 ===
  return ()
  State: [
    0.6,
    { resource_0 ↦ 1. # (ReadImu, [10, 45], [0, 0], [0, 1.5]) },
    1,
    10,
    0.6,
    1,
    10,
    0.6,
    { resource_1 ↦ 1. # (ReadImu, [10, 45], [0, 0], [0, 1.5]) },
    1,
    10,
    0.6,
    1,
    10,
    0.6,
    { resource_2 ↦ 1. # (ReadImu, [10, 45], [0, 0], [0, 1.5]) },
    1,
    10,
    0.6,
    1,
    10
  ]
  

The rejected variant, loaded after the application: the screen redrawn in
full whenever a step is counted, which leaves up to 257.5 ms between two
readings:

  $ packages --typecheck-only $app/steps.tpe steps/redrawn.tpe; echo "[$?]"
  File "steps/redrawn.tpe", lines 4-19, characters 4-74:
  4 |     : unit # (ReadImu, [0, 0], [0, 50], [0, 50]) =
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `0 ⊔ {ReadImu; DrawBar; 10; ReadImu; (DrawBar | ClearDisplay; ShowTextAt; ShowTextAt; ShowTextAt; ShowNumberAt; ShowTextAt; ShowTextAt); 10} · (ReadImu, [0, 0], [0, 50], [0, 50])`, which does not match its annotated grade `(ReadImu, [0, 0], [0, 50], [0, 50])`
    Note: the effect inequality `0 ⊔ {ReadImu; DrawBar; 10; ReadImu; (DrawBar | ClearDisplay; ShowTextAt; ShowTextAt; ShowTextAt; ShowNumberAt; ShowTextAt; ShowTextAt); 10} · (ReadImu, [0, 0], [0, 50], [0, 50]) <= (ReadImu, [0, 0], [0, 50], [0, 50])` does not hold
    Note: the grade `⟨ClearDisplay: silent [0, ∞), active ([10.4, ∞), [0, ∞), [0, ∞)); DrawBar: silent [0, 0], active ([0.2, 1.5], [0, ∞), [0, ∞)); ReadImu: active ([0, 0], [0, 257.5], [0, 257.5]); _: silent [0, ∞), active ([20.4, ∞), [0, ∞), [0, ∞))⟩` is below `0 ⊔ {ReadImu; DrawBar; 10; ReadImu; (DrawBar | ClearDisplay; ShowTextAt; ShowTextAt; ShowTextAt; ShowNumberAt; ShowTextAt; ShowTextAt); 10} · (ReadImu, [0, 0], [0, 50], [0, 50])` but not below `(ReadImu, [0, 0], [0, 50], [0, 50])`
  [1]

The second rejected variant: the second reading follows the first at once,
and may return the same sample:

  $ packages --typecheck-only $app/steps.tpe steps/at_once.tpe; echo "[$?]"
  File "steps/at_once.tpe", lines 11-17, characters 6-74:
  11 |       unbox first as a in
             ^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `first` is unboxed with grade `{ReadImu}` accumulated since it was bound, which is not below its box grade `(ReadImu, [10, 45], [0, 0], [0, 1.5])`
    File "steps/at_once.tpe", line 9, characters 53-58:
    9 |       box (ReadImu, [10, 45], [0, 0], [0, 1.5]) a as first in
                                                             ^^^^^
    `first` is bound here
    File "steps/at_once.tpe", line 10, characters 14-21:
    10 |       let b = load () in
                       ^^^^^^^
    grade `{ReadImu}` accumulates here (this computation)
    Note: the resource inequality `{ReadImu} <= (ReadImu, [10, 45], [0, 0], [0, 1.5])` does not hold
  [1]

The project, for the board m5stack-cores3; its sources compile without
exceptions and run-time type information:

  $ tempore --emit-arduino steps --device $app/steps.device.json $app/steps.tpe | grep -c Wrote
  31
  $ cd _arduino/projects/steps
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

8 seconds of simulated time: the screen, and the ten steps of the walk from
1 s to 6 s, each counted at the second reading of its rise above 1.2 g:

  $ tempore --emit-arduino steps --device $app/steps.device.json --host-simulate 8 $app/steps.tpe > run.log
  $ grep 'Display at (\(0\|120\), \(0\|24\|60\))\|simulation' run.log
  [35.000 ms] Display at (0, 0): Step counter
  [38.060 ms] Display at (0, 24): Accelerometer read at least every 50 ms
  [41.720 ms] Display at (0, 60): Steps
  [45.940 ms] Display at (120, 60): 0
  [1309.323 ms] Display at (120, 60): 1
  [1817.499 ms] Display at (120, 60): 2
  [2325.679 ms] Display at (120, 60): 3
  [2833.856 ms] Display at (120, 60): 4
  [3316.731 ms] Display at (120, 60): 5
  [3824.917 ms] Display at (120, 60): 6
  [4333.098 ms] Display at (120, 60): 7
  [4815.976 ms] Display at (120, 60): 8
  [5324.160 ms] Display at (120, 60): 9
  [5832.363 ms] Display at (120, 60): 10
  [8000.000 ms] End of the simulation

The readings are about 13 ms apart while the bar is redrawn; the longest
time between the ends of two readings, in whole milliseconds, is well
within the bound of 50 ms:

  $ awk '/Operation ReadImu took/ { t = substr($1, 2) + 0; if (p && t - p > m) m = t - p; p = t } END { printf "%.0f ms\n", m }' run.log
  15 ms
