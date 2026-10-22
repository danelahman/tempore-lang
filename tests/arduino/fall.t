The fall detector of examples/arduino/fall on the M5Stack CoreS3 Lite, with
the packages m5-imu, m5-display, m5-touch and m5-speaker, under the rigid
regular expressions of timed operations: its run by the interpreter, its
rejected variants, its project and its host simulation, over the falls and
the taps of its host model.

  $ app=../../examples/arduino/fall
  $ . ../helpers.sh
  $ from_header $app/fall.tpe

The interpreter runs a suspected fall with the default implementations of
the operations, which read a unit at rest:

  $ packages $app/fall.tpe
  === Run 1 ===
  return 0
  State: [
    { resource_0 ↦ 0.1 ! [{≥100}, {(idle ≤10.5; ReadImu)^10}] },
    {idle 10},
    {idle 0.6},
    {idle 10},
    {idle 0.6},
    {idle 10},
    {idle 0.6},
    {idle 10},
    {idle 0.6},
    {idle 10},
    {idle 0.6},
    {idle 10},
    {idle 0.6},
    {idle 10},
    {idle 0.6},
    {idle 10},
    {idle 0.6},
    {idle 10},
    {idle 0.6},
    {idle 10},
    {idle 0.6}
  ]
  

The rejected variants, each loaded after the application: an alarm raised
without the prompt, the unit reconfigured before the confirmation of a free
fall, and an alarm sounding on the even seconds only:

  $ for v in silent rated even; do packages --typecheck-only $app/fall.tpe fall/$v.tpe; echo "[$?]"; done
  File "fall/silent.tpe", lines 6-7, characters 2-16:
  6 |   unbox event as detected in
        ^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `event` is unboxed with grade `{idle 20000}` accumulated since it was bound, which is not below its box grade `{ShowColourTextAt^2; Beep; [10000, 30000]}`
    File "fall/silent.tpe", line 4, characters 73-78:
    4 |   box {ShowColourTextAt; ShowColourTextAt; Beep; [10000, 30000]} fall as event in
                                                                                 ^^^^^
    `event` is bound here
    File "fall/silent.tpe", line 5, characters 2-13:
    5 |   delay 20000;
          ^^^^^^^^^^^
    grade `{idle 20000}` accumulates here (delay)
    Note: the resource inequality `{idle 20000} <= {ShowColourTextAt^2; Beep; [10000, 30000]}` does not hold
  [1]
  File "fall/rated.tpe", line 7, characters 18-49:
  7 |   if falling then (unbox onset as least in least) else first
                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `onset` is unboxed with grade `{ConfigureImu; (idle 10; ReadImu)^10}` accumulated since it was bound, which is not below its box grade `[{≥100}, {(idle ≤10.5; ReadImu)^10}]`
    File "fall/rated.tpe", line 4, characters 57-62:
    4 |   box [{100}, {(idle [9.5, 10.5]; ReadImu)^10}] first as onset in
                                                                 ^^^^^
    `onset` is bound here
    File "fall/rated.tpe", line 5, characters 2-26:
    5 |   perform ConfigureImu 400;
          ^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{ConfigureImu}` accumulates here (operation `ConfigureImu`)
    File "fall/rated.tpe", line 6, characters 16-26:
    6 |   let falling = confirm () in
                        ^^^^^^^^^^
    grade `{(idle 10; ReadImu)^10}` accumulates here (this computation)
    Note: the resource inequality `{ConfigureImu; (idle 10; ReadImu)^10} <= [{≥100}, {(idle ≤10.5; ReadImu)^10}]` does not hold
  [1]
  File "fall/even.tpe", lines 3-21, characters 45-35:
  3 | let rec alarm_even (n : nat) (seconds : nat) : unit
                                                   ^^^^^^
  Typing error: This function's body has grade `{((ReadTouch; idle 50)^20; (Beep; ShowColourTextAt^2; idle 2000 | ShowColourTextAt; ShowTimeAt; Beep?; ((ReadTouch; idle 50)^20; ShowColourTextAt; ShowTimeAt; Beep)*; ((ReadTouch; idle 50)^20; Beep; ShowColourTextAt^2; idle 2000)?))?}`, which does not match its annotated grade `{((ReadTouch; idle 50)^20; ShowColourTextAt; ShowTimeAt; Beep)*; ((ReadTouch; idle 50)^20; Beep; ShowColourTextAt^2; idle 2000)?}`
    Note: the effect inequality `{((ReadTouch; idle 50)^20; (Beep; ShowColourTextAt^2; idle 2000 | ShowColourTextAt; ShowTimeAt; Beep?; ((ReadTouch; idle 50)^20; ShowColourTextAt; ShowTimeAt; Beep)*; ((ReadTouch; idle 50)^20; Beep; ShowColourTextAt^2; idle 2000)?))?} <= {((ReadTouch; idle 50)^20; ShowColourTextAt; ShowTimeAt; Beep)*; ((ReadTouch; idle 50)^20; Beep; ShowColourTextAt^2; idle 2000)?}` does not hold
    Note: the grade `[{ReadTouch; idle ≥50; ReadTouch; idle ≥50; ReadTouch; idle ≥50; ReadTouch; idle ≥50; ReadTouch; idle ≥50; ReadTouch; idle ≥50; ReadTouch; idle ≥50; ReadTouch; idle ≥50; ReadTouch; idle ≥50; ReadTouch; idle ≥50; ReadTouch; idle ≥50; ReadTouch; idle ≥50; ReadTouch; idle ≥50; ReadTouch; idle ≥50; ReadTouch; idle ≥50; ReadTouch; idle ≥50; ReadTouch; idle ≥50; ReadTouch; idle ≥50; ReadTouch; idle ≥50; ReadTouch; idle ≥50; ShowColourTextAt; ShowTimeAt}, {((ReadTouch; idle ≤50)^20; (Beep; ShowColourTextAt^2; idle ≤2000 | ShowColourTextAt; ShowTimeAt; Beep?; ((ReadTouch; idle ≤50)^20; ShowColourTextAt; ShowTimeAt; Beep)*; ((ReadTouch; idle ≤50)^20; Beep; ShowColourTextAt^2; idle ≤2000)?))?}]` is below `{((ReadTouch; idle 50)^20; (Beep; ShowColourTextAt^2; idle 2000 | ShowColourTextAt; ShowTimeAt; Beep?; ((ReadTouch; idle 50)^20; ShowColourTextAt; ShowTimeAt; Beep)*; ((ReadTouch; idle 50)^20; Beep; ShowColourTextAt^2; idle 2000)?))?}` but not below `{((ReadTouch; idle 50)^20; ShowColourTextAt; ShowTimeAt; Beep)*; ((ReadTouch; idle 50)^20; Beep; ShowColourTextAt^2; idle 2000)?}`
  [1]

The project, for the board m5stack-cores3; its sources compile without
exceptions and run-time type information:

  $ tempore --emit-arduino fall --device $app/fall.device.json $app/fall.tpe | grep -c Wrote
  36
  $ cd _arduino/projects/fall
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

35 seconds of simulated time: the first fall, at 2 s, is detected after its
impact at 2.3 s, counted down in orange, and alarmed in red at about 12.5 s,
the alarm flashing and sounding every second until the tap at 16 s stops it;
the second, at 25 s, is cancelled by the tap at 28 s. The screen of the
watch, in green, shows the falls counted:

  $ tempore --emit-arduino fall --device $app/fall.device.json --host-simulate 35 $app/fall.tpe > run.log
  $ grep 'Display at (\(9, 47\|6, 78\|0, 10[24]\))\|Display at (160\|Display fill at (0, 44)\|simulation' run.log | sed 's/ *$//'
  [43.888 ms] Display fill at (0, 44), 320 by 30: 0x00c000
  [45.048 ms] Display at (9, 47): Watching
  [48.788 ms] Display at (6, 78): for falls
  [52.448 ms] Display at (0, 102): Falls
  [54.748 ms] Display at (160, 102): 0
  [2352.844 ms] Display fill at (0, 44), 320 by 30: 0xff8000
  [2354.064 ms] Display at (9, 47): Are you OK?
  [2357.884 ms] Display at (6, 78): Tap to cancel
  [2365.302 ms] Display at (0, 104): 10
  [3379.490 ms] Display at (0, 104): 9
  [4393.677 ms] Display at (0, 104): 8
  [5407.864 ms] Display at (0, 104): 7
  [6422.051 ms] Display at (0, 104): 6
  [7436.238 ms] Display at (0, 104): 5
  [8450.426 ms] Display at (0, 104): 4
  [9464.613 ms] Display at (0, 104): 3
  [10478.800 ms] Display at (0, 104): 2
  [11492.987 ms] Display at (0, 104): 1
  [12544.922 ms] Display fill at (0, 44), 320 by 30: 0xe00000
  [12546.022 ms] Display at (9, 47): ALARM
  [12549.802 ms] Display at (6, 78): Tap to stop
  [12553.562 ms] Display at (0, 102): Impact (g)
  [12555.902 ms] Display at (160, 102): 3.5
  [12562.082 ms] Display at (160, 124): 0.05
  [13575.912 ms] Display fill at (0, 44), 320 by 30: 0xffffff
  [13577.012 ms] Display at (9, 47): ALARM
  [14590.842 ms] Display fill at (0, 44), 320 by 30: 0xe00000
  [14591.942 ms] Display at (9, 47): ALARM
  [15605.772 ms] Display fill at (0, 44), 320 by 30: 0xffffff
  [15606.872 ms] Display at (9, 47): ALARM
  [16620.852 ms] Display fill at (0, 44), 320 by 30: 0x00c000
  [16622.112 ms] Display at (9, 47): Alarm stopped
  [16625.672 ms] Display at (6, 78):
  [18669.560 ms] Display fill at (0, 44), 320 by 30: 0x00c000
  [18670.720 ms] Display at (9, 47): Watching
  [18674.460 ms] Display at (6, 78): for falls
  [18678.120 ms] Display at (0, 102): Falls
  [18680.420 ms] Display at (160, 102): 1
  [25351.372 ms] Display fill at (0, 44), 320 by 30: 0xff8000
  [25352.592 ms] Display at (9, 47): Are you OK?
  [25356.412 ms] Display at (6, 78): Tap to cancel
  [25363.830 ms] Display at (0, 104): 10
  [26378.018 ms] Display at (0, 104): 9
  [27392.205 ms] Display at (0, 104): 8
  [28404.242 ms] Display fill at (0, 44), 320 by 30: 0x00c000
  [28405.422 ms] Display at (9, 47): Cancelled
  [28409.262 ms] Display at (6, 78): Glad you're OK
  [30453.150 ms] Display fill at (0, 44), 320 by 30: 0x00c000
  [30454.310 ms] Display at (9, 47): Watching
  [30458.050 ms] Display at (6, 78): for falls
  [30461.710 ms] Display at (0, 102): Falls
  [30464.010 ms] Display at (160, 102): 2
  [35000.000 ms] End of the simulation
The alarm sounds four tones, and a tone of 1500 Hz acknowledges each of the
two taps; the time since the last event is redrawn every hundred readings,
and the bar of the acceleration every ten readings, and of the countdown
every second:

  $ grep -c 'Speaker: 2000 Hz' run.log
  4
  $ grep -c 'Speaker: 1500 Hz' run.log
  2
  $ grep 'Since last event' run.log | sed -n '1,3p'
  [58.728 ms] Display at (0, 148): Since last event 0:00
  [1136.853 ms] Display at (0, 148): Since last event 0:01
  [18684.400 ms] Display at (0, 148): Since last event 0:00
  $ grep -c 'Display fill at (0, 1\(72\|80\))' run.log
  132

The scaffold draws the battery indicator in the top right corner after each
drawing over it; the first time after the screen of the watch:

  $ grep -m 1 'Battery' run.log
  [62.706 ms] Display at (254, 0): Battery 87%
