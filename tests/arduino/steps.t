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
  CountStep: active ((10.4, ∞), (10.05, ∞), [0, ∞))

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
  36
  $ cd _arduino/projects/steps
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

46 seconds of simulated time over the motions of the host model, by the
last motion begun: the calibration at rest and the beep; shaking, a bump,
the device picked up and put down, bouncing on the spot and a walk of ten
steps; a tap on Calibrate, a single tap on Reset, a tap outside the
buttons, a double tap on Reset, a walk of six steps and a tap on Calibrate.
The states, the counts, the prompt, the buttons, drawn active or idle, and
the tones, in order: shaking, the bump, putting the device down and
bouncing are motions along a line, and picking it up has no rise; the walk
is counted once four of its steps are confirmed; each tap on Calibrate
calibrates again, the button active meanwhile, and beeps once; the single
tap on Reset clears the prompt, the tap outside the buttons does nothing,
and the double tap on Reset resets the count with a short tone:

  $ tempore --emit-arduino steps --device $app/steps.device.json --host-simulate 46 $app/steps.tpe > run.log
  $ awk '/Display at \((0, 32|[06], 170)\)|Steps:|Speaker|fill at \((0|164), 188\)/ { t = substr($1, 2) / 1000; w = t < 3 ? "rest" : t < 7 ? "shaking" : t < 9 ? "bump" : t < 12 ? "picked up" : t < 15 ? "put down" : t < 21 ? "bouncing" : t < 28 ? "walk" : t < 31 ? "calibrate" : t < 34 ? "single reset" : t < 36 ? "outside" : t < 39 ? "double reset" : t < 44 ? "walk" : "calibrate"; sub(/^\[[0-9.]* ms\] (Display at \(0, 32\): )?/, ""); sub(/^Display at \([06], 170\): ?/, "prompt: "); sub(/^Display fill at \(0, 188\), 156 by 40:/, "Calibrate:"); sub(/^Display fill at \(164, 188\), 156 by 40:/, "Reset:"); sub(/0xffd000/, "active"); sub(/0x303030/, "idle"); print w ": " $0 }' run.log | sed 's/ *$//'
  rest: Hold still
  rest: prompt: Calibrating: not counting
  rest: Calibrate: active
  rest: Still
  rest: Calibrate: idle
  rest: Reset: idle
  rest: Speaker: 2000 Hz for 150 ms
  shaking: Ignored: along a line
  shaking: Still
  bump: Ignored: along a line
  bump: Still
  put down: Ignored: along a line
  put down: Still
  bouncing: Ignored: along a line
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
  double reset: Speaker: 3000 Hz for 50 ms
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

  $ grep "Display at (120, 56)" run.log | awk '{ t = substr($1, 2) / 1000 } t > 28 && t < 29' | sed "s/^\[[0-9.]* ms\] //"
  Display at (120, 56): 10
  $ grep "Display at (120, 56)" run.log | tail -1 | sed "s/^\[[0-9.]* ms\] //"
  Display at (120, 56): 6
  $ grep "Display at (200, 114)" run.log | tail -1 | sed "s/^\[[0-9.]* ms\] //"
  Display at (200, 114): 4

While counting, from each beep to the next calibration, the readings are
about 12 ms apart; the longest time between the ends of two readings, in
whole milliseconds, is well within the bound of 50 ms:

  $ awk '/Speaker/ { s = 1; p = 0 } /Hold still/ { s = 0 } s && /Operation ReadImu took/ { t = substr($1, 2) + 0; if (p && t - p > m) m = t - p; p = t } END { printf "%.0f ms\n", m }' run.log
  15 ms

Under the build flag STEPS_RECORD, here 600 s, bindings.cpp records the
readings and the events in a partition, in memory on the host, one
recording per calibration, and world.cpp prints them at the end. The
partition is formatted at the first record; the marker shows the number of
the recording; the events are those of the run above. Each line of the
dump ends with a checksum, removed in dump.log:

  $ cd _arduino/projects/steps
  $ build () { c++ -std=c++17 -Wall -Wextra -Werror -ffp-contract=off -DTEMPORE_HOST "$@" -pthread -I host -I src src/*.cpp host/*.cpp -o simulation; }
  $ build -DSTEPS_RECORD=600 && ./simulation 46000000 > record.log
  $ grep '^[@#]' record.log | grep -cv '\*[0-9A-F]\{4\}$'
  0
  [1]
  $ sed 's/\*[0-9A-F]\{4\}$//' record.log > dump.log
  $ grep -e '^# ' -e 'Recorder' dump.log | sed 's/^\[[0-9.]* ms\] //'
  Recorder: start-up after the reset reason host (0)
  Recorder: formatting the partition
  Recorder: 0 recordings, 0 records, 0 ms recorded
  # Recordings: 3936 records, the last recording 3, 45.9 of 600 s recorded
  # Recording 1, the first after the start-up by the reset reason host (0)
  # End of recording 1, 2399 rows
  # Recording 2
  # End of recording 2, 1370 rows
  # Recording 3
  # End of recording 3, 167 rows
  # End of the recordings
  $ grep 'Display at (290, 134)' dump.log | sed 's/^\[[0-9.]* ms\] //' | uniq
  Display at (290, 134): REC 1
  Display at (290, 134): REC 2
  Display at (290, 134): REC 3
  $ grep '^@[0-9]' dump.log | grep -v ',$' | sed 's/^@[0-9]*,,,,,,,//' | uniq -c | sed 's/^ *//'
  1 calibration start
  1 calibration end
  1 count 4
  6 count 1
  1 calibration start
  1 calibration end
  1 reset
  1 count 4
  2 count 1
  1 calibration start
  1 calibration end

The readings of the recordings have the 8 fields of the columns, and are at
most 23 ms apart but from the end of each calibration to the beep:

  $ grep '^@[0-9]' dump.log | awk -F, 'NF != 8 { print "row: " $0 } /calibration end/ { p = 0 } $2 != "" { t = substr($1, 2) + 0; if (p && t - p > m) m = t - p; p = t } END { print m " ms" }'
  23 ms

With a bound of 10 s, the recording stops at the bound, and the marker
shows FULL:

  $ build -DSTEPS_RECORD=10 && ./simulation 20000000 > full.log
  $ grep -e '^# Recordings' -e 'full' -e 'FULL' full.log | sed -e 's/^\[[0-9.]* ms\] //' -e 's/\*[0-9A-F]\{4\}$//'
  Recorder: full, 9998 ms recorded
  Display at (296, 134): FULL
  # Recordings: 857 records, the last recording 1, 10.0 of 10 s recorded, full
  $ cd ../../..

The five recordings of steps/recordings, made on the CoreS3 Lite (their
README.md), replayed by the host simulation through STEPS_REPLAY: the
steps counted in each. Lying still, moving the device up and down in the
hand and handling it count none; walking with it in the hand counts 29 of
about 32 steps, and walking with it in a pocket 53, of about 49 clear
steps and up to 10 unclear ones at the standstill, where the count depends
on the times at which the recording is read:

  $ cd _arduino/projects/steps
  $ build
  $ for i in 1 2 3 4 5; do
  >   STEPS_REPLAY=../../../steps/recordings/steps-$i.csv ./simulation 47000000 > replay-$i.log
  >   echo "recording $i: $(grep -o 'Steps: [0-9]* counted' replay-$i.log | awk '{ s += $2 } END { print s + 0 }') steps"
  > done
  recording 1: 0 steps
  recording 2: 29 steps
  recording 3: 0 steps
  recording 4: 53 steps
  recording 5: 0 steps
  $ cd ../../..
