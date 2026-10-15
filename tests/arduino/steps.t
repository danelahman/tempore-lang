The step counter of examples/arduino/steps on the M5Stack CoreS3 Lite, with
the packages m5-imu, m5-display and m5-speaker, under the event separation:
its run by the interpreter, its rejected variants, its project and its host
simulation over the motions of its host model.

  $ app=../../examples/arduino/steps
  $ . ../helpers.sh
  $ from_header $app/steps.tpe

The interpreter runs three rounds of two readings with the default
implementations of the operations, which read a unit at rest; the first
reading of each round is boxed until the second:

  $ packages $app/steps.tpe
  === Run 1 ===
  return ()
  State: [
    0.6,
    { resource_0 ↦ (1., 1., 1.) # (1, ReadImu, [10, 45], [0, 1.5]) },
    1,
    10,
    0.6,
    0.01,
    1,
    10,
    0.6,
    { resource_1 ↦ (1., 1., 1.) # (1, ReadImu, [10, 45], [0, 1.5]) },
    1,
    10,
    0.6,
    0.01,
    1,
    10,
    0.6,
    { resource_2 ↦ (1., 1., 1.) # (1, ReadImu, [10, 45], [0, 1.5]) },
    1,
    10,
    0.6,
    0.01,
    1,
    10
  ]
  

The first rejected variant, loaded after the application: a count not
followed by the cooldown, so that two counts may be 10.1 ms apart:

  $ packages --typecheck-only $app/steps.tpe steps/eager.tpe > eager.log 2>&1; echo "[$?]"
  [1]
  $ grep -o 'Typing error: This function.s body has grade\|CountStep: active ([^;]*' eager.log
  Typing error: This function's body has grade
  CountStep: active ([10.4, ∞), [10.1, ∞), [0, ∞))

The second: the screen redrawn in full at a count, which leaves up to 455.9
ms between two readings:

  $ packages --typecheck-only $app/steps.tpe steps/redrawn.tpe > redrawn.log 2>&1; echo "[$?]"
  [1]
  $ grep -o 'Typing error: This function.s body has grade\|ReadImu: active ([^;]*' redrawn.log
  Typing error: This function's body has grade
  ReadImu: active ([2, ∞), [0, 0], [0, 455.9], [0, 50])

The third: the second reading follows the first at once, and may return the
same sample:

  $ packages --typecheck-only $app/steps.tpe steps/at_once.tpe; echo "[$?]"
  File "steps/at_once.tpe", lines 9-19, characters 2-66:
  9 |   unbox boxed as first in
        ^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `boxed` is unboxed with grade `{ReadImu}` accumulated since it was bound, which is not below its box grade `(1, ReadImu, [10, 45], [0, 1.5])`
    File "steps/at_once.tpe", line 7, characters 48-53:
    7 |   box (1, ReadImu, [10, 45], [0, 1.5]) first as boxed in
                                                        ^^^^^
    `boxed` is bound here
    File "steps/at_once.tpe", line 8, characters 10-17:
    8 |   let x = load () in
                  ^^^^^^^
    grade `{ReadImu}` accumulates here (this computation)
    Note: the resource inequality `{ReadImu} <= (1, ReadImu, [10, 45], [0, 1.5])` does not hold
  [1]

The project, for the board m5stack-cores3; its sources compile without
exceptions and run-time type information:

  $ tempore --emit-arduino steps --device $app/steps.device.json $app/steps.tpe | grep -c Wrote
  33
  $ cd _arduino/projects/steps
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

22 seconds of simulated time over the motions of the host model: shaking
from 1 s to 3 s, a bump at 5.5 s, the device picked up at 8 s and put down
at 11 s, and a walk of ten steps from 14 s to 19 s. The states shown and
the counts, in order, by the last motion begun: the shaking is too fast,
the bump and each motion of the device a single rise, and the walk is
counted once four of its steps are confirmed, ten steps in all:

  $ tempore --emit-arduino steps --device $app/steps.device.json --host-simulate 22 $app/steps.tpe > run.log
  $ awk '/Display at \(0, 44\)|Steps:/ { t = substr($1, 2) / 1000; w = t < 1 ? "rest" : t < 5.5 ? "shaking" : t < 8 ? "bump" : t < 11 ? "picked up" : t < 14 ? "put down" : "walk"; sub(/^\[[0-9.]* ms\] (Display at \(0, 44\): )?/, ""); print w ": " $0 }' run.log
  rest: Still
  shaking: Checking rhythm
  shaking: Ignored: too fast
  shaking: Still
  bump: Checking rhythm
  bump: Still
  picked up: Checking rhythm
  picked up: Still
  put down: Checking rhythm
  put down: Still
  walk: Checking rhythm
  walk: Steps: 4 counted, 4 in all
  walk: Walking
  walk: Steps: 1 counted, 5 in all
  walk: Steps: 1 counted, 6 in all
  walk: Steps: 1 counted, 7 in all
  walk: Steps: 1 counted, 8 in all
  walk: Steps: 1 counted, 9 in all
  walk: Steps: 1 counted, 10 in all
  walk: Still

The steps and the distance, in metres, shown at the end:

  $ grep "Display at (120, 72)" run.log | tail -1 | sed "s/^\[[0-9.]* ms\] //"
  Display at (120, 72): 10
  $ grep "Display at (200, 150)" run.log | tail -1 | sed "s/^\[[0-9.]* ms\] //"
  Display at (200, 150): 7

The readings are about 12 ms apart; the longest time between the ends of two
readings, in whole milliseconds, is well within the bound of 50 ms:

  $ awk '/Operation ReadImu took/ { t = substr($1, 2) + 0; if (p && t - p > m) m = t - p; p = t } END { printf "%.0f ms\n", m }' run.log
  15 ms
