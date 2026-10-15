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

The second: the wait for the second tap on Reset reads only the touch
screen, so that the unit is not read while the prompt is shown:

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

46 seconds of simulated time over the motions of the host model, by the
last motion begun: the calibration at rest and the beep; shaking, a bump,
the device picked up and put down, bouncing on the spot and a walk of ten
steps; a tap on Calibrate, a single tap on Reset, a tap outside the
buttons, a double tap on Reset, a walk of six steps and a tap on Calibrate.
The states, the counts, the prompt, the buttons, drawn active or idle, and
the tones, in order: shaking is too fast, the bump a single rise, putting
the device down and bouncing have no sway, and the walk is counted once
four of its steps are confirmed; each tap on Calibrate calibrates again,
the button active meanwhile, and beeps once; the single tap on Reset
clears the prompt, the tap outside the buttons does nothing, and the double
tap on Reset resets the count:

  $ tempore --emit-arduino steps --device $app/steps.device.json --host-simulate 46 $app/steps.tpe > run.log
  $ awk '/Display at \(0, (30|168)\)|Steps:|Speaker|fill at \((0|164), 188\)/ { t = substr($1, 2) / 1000; w = t < 3 ? "rest" : t < 7 ? "shaking" : t < 9 ? "bump" : t < 12 ? "picked up" : t < 15 ? "put down" : t < 21 ? "bouncing" : t < 28 ? "walk" : t < 31 ? "calibrate" : t < 34 ? "single reset" : t < 36 ? "outside" : t < 39 ? "double reset" : t < 44 ? "walk" : "calibrate"; sub(/^\[[0-9.]* ms\] (Display at \(0, 30\): )?/, ""); sub(/^Display at \(0, 168\): ?/, "prompt: "); sub(/^Display fill at \(0, 188\), 156 by 40:/, "Calibrate:"); sub(/^Display fill at \(164, 188\), 156 by 40:/, "Reset:"); sub(/0xffd000/, "active"); sub(/0x303030/, "idle"); print w ": " $0 }' run.log | sed 's/ *$//'
  rest: Hold still
  rest: prompt: Calibrating: not counting
  rest: Calibrate: active
  rest: Still
  rest: Calibrate: idle
  rest: Reset: idle
  rest: Speaker: 2000 Hz for 150 ms
  shaking: Checking rhythm
  shaking: Ignored: too fast
  shaking: Still
  bump: Checking rhythm
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
  calibrate: Hold still
  calibrate: prompt: Calibrating: not counting
  calibrate: Calibrate: active
  calibrate: Still
  calibrate: Calibrate: idle
  calibrate: Reset: idle
  calibrate: Speaker: 2000 Hz for 150 ms
  single reset: prompt: Tap Reset again to reset
  single reset: Reset: active
  single reset: prompt:
  single reset: Reset: idle
  double reset: prompt: Tap Reset again to reset
  double reset: Reset: active
  double reset: Steps: reset
  double reset: prompt:
  double reset: Reset: idle
  walk: Checking rhythm
  walk: Steps: 4 counted, 4 in all
  walk: Walking
  walk: Steps: 1 counted, 5 in all
  walk: Steps: 1 counted, 6 in all
  walk: Still
  calibrate: Hold still
  calibrate: prompt: Calibrating: not counting
  calibrate: Calibrate: active
  calibrate: Still
  calibrate: Calibrate: idle
  calibrate: Reset: idle
  calibrate: Speaker: 2000 Hz for 150 ms

The steps redrawn after the first tap on Calibrate, kept; and the steps and
the distance, in metres, shown at the end, kept by the second:

  $ grep "Display at (120, 52)" run.log | awk '{ t = substr($1, 2) / 1000 } t > 28 && t < 29' | sed "s/^\[[0-9.]* ms\] //"
  Display at (120, 52): 10
  $ grep "Display at (120, 52)" run.log | tail -1 | sed "s/^\[[0-9.]* ms\] //"
  Display at (120, 52): 6
  $ grep "Display at (200, 112)" run.log | tail -1 | sed "s/^\[[0-9.]* ms\] //"
  Display at (200, 112): 4

While counting, from each beep to the next calibration, the readings are
about 12 ms apart; the longest time between the ends of two readings, in
whole milliseconds, is well within the bound of 50 ms:

  $ awk '/Speaker/ { s = 1; p = 0 } /Hold still/ { s = 0 } s && /Operation ReadImu took/ { t = substr($1, 2) + 0; if (p && t - p > m) m = t - p; p = t } END { printf "%.0f ms\n", m }' run.log
  15 ms
