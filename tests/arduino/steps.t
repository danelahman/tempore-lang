The step counter of examples/arduino/steps on the M5Stack CoreS3 Lite, with
the packages m5-imu, m5-display, m5-touch and m5-speaker, under the event
separation: its run by the interpreter, its rejected variants, its project
and its host simulation over the motions of its host model.

  $ app=../../examples/arduino/steps
  $ . ../helpers.sh
  $ from_header $app/steps.tpe

The interpreter replays a walk of 2.5 steps a second through the handler
'walk' from the time 1 s: the run is confirmed at its fourth step, when four
steps are counted, and the next step is counted 400 ms later; two counts of
five steps, the last at 2875 ms, the least time between them 400 ms:

  $ packages $app/steps.tpe | strip_state
  === Run 1 ===
  return (2, 5, 2875, 400)
  

The first rejected variant, loaded after the application: a count not
followed by the cooldown, so that two counts may be 10.05 ms apart:

  $ packages --typecheck-only $app/steps.tpe steps/eager.tpe > eager.log 2>&1; echo "[$?]"
  [1]
  $ grep -o 'Typing error: This function.s body has grade\|CountStep: active ([^;]*' eager.log
  Typing error: This function's body has grade
  CountStep: active ([10.4, ∞), [10.05, ∞), [0, ∞))

The second: the wait for the second tap reads only the touch screen, so that
the unit is not read while the prompt is shown:

  $ packages --typecheck-only $app/steps.tpe steps/touch_only.tpe > touch_only.log 2>&1; echo "[$?]"
  [1]
  $ grep -o 'Typing error: Variable .tap. is unboxed\|its box grade `[^`]*`\|grade `((0, CountStep, \[0, ∞)), (ReadTouch[^`]*` accumulates' touch_only.log
  Typing error: Variable `tap` is unboxed
  its box grade `((ReadImu, [0, 50]), (ReadTouch, [300, ∞), [0, ∞), [0, ∞)))`
  grade `((0, CountStep, [0, ∞)), (ReadTouch, [0, 0], [0, 50], [0, 50]))` accumulates

The third: the calibration reads the unit 50 times without the delays, so
that the readings may return the same sample:

  $ packages --typecheck-only $app/steps.tpe steps/tight.tpe > tight.log 2>&1; echo "[$?]"
  [1]
  $ grep -o 'Typing error: Variable .samples. is unboxed\|its box grade `[^`]*`' tight.log
  Typing error: Variable `samples` is unboxed
  its box grade `(50, ReadImu, [0, 50], [10, 45], [0, 50])`

The project, for the board m5stack-cores3; its sources compile without
exceptions and run-time type information:

  $ tempore --emit-arduino steps --device $app/steps.device.json $app/steps.tpe | grep -c Wrote
  35
  $ cd _arduino/projects/steps
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

43 seconds of simulated time over the motions of the host model, by the
last motion begun: the calibration at rest and the beep; shaking, a bump,
the device picked up and put down, bouncing on the spot and a walk of ten
steps; a single tap, a finger held on the screen, a double tap, and a walk
of six steps. The states, the counts, the prompt and the tones, in order:
shaking is too fast, the bump no rise, picking the device up a single rise,
putting it down and bouncing have no sway, and the walk is counted once four
of its steps are confirmed; the single tap and the held finger clear the prompt, and the
double tap resets the count:

  $ tempore --emit-arduino steps --device $app/steps.device.json --host-simulate 43 $app/steps.tpe > run.log
  $ awk '/Display at \(0, (44|116)\)|Steps:|Speaker/ { t = substr($1, 2) / 1000; w = t < 3 ? "rest" : t < 7 ? "shaking" : t < 9 ? "bump" : t < 12 ? "picked up" : t < 15 ? "put down" : t < 21 ? "bouncing" : t < 28 ? "walk" : t < 31 ? "single tap" : t < 35 ? "held finger" : t < 38 ? "double tap" : "walk"; sub(/^\[[0-9.]* ms\] (Display at \(0, 44\): )?/, ""); sub(/^Display at \(0, 116\): ?/, "prompt: "); print w ": " $0 }' run.log | sed 's/ *$//'
  rest: Hold still
  rest: Still
  rest: Speaker: 2000 Hz for 150 ms
  shaking: Checking rhythm
  shaking: Ignored: too fast
  shaking: Still
  picked up: Checking rhythm
  picked up: Still
  put down: Ignored: no sway
  put down: Still
  bouncing: Ignored: no sway
  bouncing: Still
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
  single tap: prompt: Tap again to reset
  single tap: prompt:
  held finger: prompt: Tap again to reset
  held finger: prompt:
  double tap: prompt: Tap again to reset
  double tap: Steps: reset
  double tap: prompt:
  walk: Checking rhythm
  walk: Steps: 4 counted, 4 in all
  walk: Walking
  walk: Steps: 1 counted, 5 in all
  walk: Steps: 1 counted, 6 in all
  walk: Still

The steps and the distance, in metres, shown at the end:

  $ grep "Display at (120, 72)" run.log | tail -1 | sed "s/^\[[0-9.]* ms\] //"
  Display at (120, 72): 6
  $ grep "Display at (200, 162)" run.log | tail -1 | sed "s/^\[[0-9.]* ms\] //"
  Display at (200, 162): 4

After the beep, the readings are about 12 ms apart; the longest time between
the ends of two readings, in whole milliseconds, is well within the bound of
50 ms:

  $ awk '/Speaker/ { s = 1 } s && /Operation ReadImu took/ { t = substr($1, 2) + 0; if (p && t - p > m) m = t - p; p = t } END { printf "%.0f ms\n", m }' run.log
  15 ms
