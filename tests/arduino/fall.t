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
    { resource_0 ↦ 0.1 # [{100}, {(![9.5, 10.5]; ReadImu)*}] },
    [{!10}, {!10}],
    [{!0.6}, {!0.6}],
    [{!10}, {!10}],
    [{!0.6}, {!0.6}],
    [{!10}, {!10}],
    [{!0.6}, {!0.6}],
    [{!10}, {!10}],
    [{!0.6}, {!0.6}],
    [{!10}, {!10}],
    [{!0.6}, {!0.6}],
    [{!10}, {!10}],
    [{!0.6}, {!0.6}],
    [{!10}, {!10}],
    [{!0.6}, {!0.6}],
    [{!10}, {!10}],
    [{!0.6}, {!0.6}],
    [{!10}, {!10}],
    [{!0.6}, {!0.6}],
    [{!10}, {!10}],
    [{!0.6}, {!0.6}]
  ]
  

The rejected variants, each loaded after the application: an alarm raised
without the prompt, the unit reconfigured before the confirmation of a free
fall, and an alarm sounding on the even seconds only:

  $ for v in silent rated even; do packages --typecheck-only $app/fall.tpe fall/$v.tpe; echo "[$?]"; done
  File "fall/silent.tpe", lines 6-7, characters 2-16:
  6 |   unbox event as detected in
        ^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `event` is unboxed with grade `[{!20000}, {!20000}]` accumulated since it was bound, which is not below its box grade `[{ShowColourTextAt; ShowColourTextAt; Beep; [10000, 30000]}, {ShowColourTextAt; ShowColourTextAt; Beep; [10000, 30000]}]`
    File "fall/silent.tpe", line 4, characters 73-78:
    4 |   box {ShowColourTextAt; ShowColourTextAt; Beep; [10000, 30000]} fall as event in
                                                                                 ^^^^^
    `event` is bound here
    File "fall/silent.tpe", line 5, characters 2-13:
    5 |   delay 20000;
          ^^^^^^^^^^^
    grade `[{!20000}, {!20000}]` accumulates here (delay)
    Note: the resource inequality `[{!20000}, {!20000}] <= [{ShowColourTextAt; ShowColourTextAt; Beep; [10000, 30000]}, {ShowColourTextAt; ShowColourTextAt; Beep; [10000, 30000]}]` does not hold
  [1]
  File "fall/rated.tpe", line 7, characters 18-49:
  7 |   if falling then (unbox onset as least in least) else first
                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `onset` is unboxed with grade `[{ConfigureImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu}, {ConfigureImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu}]` accumulated since it was bound, which is not below its box grade `[{100}, {(![9.5, 10.5]; ReadImu)*}]`
    File "fall/rated.tpe", line 4, characters 51-56:
    4 |   box [{100}, {(![9.5, 10.5]; ReadImu)*}] first as onset in
                                                           ^^^^^
    `onset` is bound here
    File "fall/rated.tpe", line 5, characters 2-26:
    5 |   perform ConfigureImu 400;
          ^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{ConfigureImu}, {ConfigureImu}]` accumulates here (operation `ConfigureImu`)
    File "fall/rated.tpe", line 6, characters 16-26:
    6 |   let falling = confirm () in
                        ^^^^^^^^^^
    grade `[{!10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu}, {!10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu}]` accumulates here (this computation)
    Note: the resource inequality `[{ConfigureImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu}, {ConfigureImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu}] <= [{100}, {(![9.5, 10.5]; ReadImu)*}]` does not hold
  [1]
  File "fall/even.tpe", lines 3-21, characters 45-35:
  3 | let rec alarm_even (n : nat) (seconds : nat) : unit
                                                   ^^^^^^
  Typing error: This function's body has grade `[{[1000, 1030]; (ShowColourTextAt; ShowTimeAt; (0 | Beep); ([1000, 1030]; ShowColourTextAt; ShowTimeAt; Beep)*; (0 | [1000, 1030]; Beep; ShowColourTextAt; ShowColourTextAt; 2000) | Beep; ShowColourTextAt^2; !2000) | 0}, {[1000, 1030]; (ShowColourTextAt; ShowTimeAt; (0 | Beep); ([1000, 1030]; ShowColourTextAt; ShowTimeAt; Beep)*; (0 | [1000, 1030]; Beep; ShowColourTextAt; ShowColourTextAt; 2000) | Beep; ShowColourTextAt^2; !2000) | 0}]`, which does not match its annotated grade `[{([1000, 1030]; ShowColourTextAt; ShowTimeAt; Beep)*; (0 | [1000, 1030]; Beep; ShowColourTextAt; ShowColourTextAt; 2000)}, {([1000, 1030]; ShowColourTextAt; ShowTimeAt; Beep)*; (0 | [1000, 1030]; Beep; ShowColourTextAt; ShowColourTextAt; 2000)}]`
    Note: the effect inequality `[{[1000, 1030]; (ShowColourTextAt; ShowTimeAt; (0 | Beep); ([1000, 1030]; ShowColourTextAt; ShowTimeAt; Beep)*; (0 | [1000, 1030]; Beep; ShowColourTextAt; ShowColourTextAt; 2000) | Beep; ShowColourTextAt^2; !2000) | 0}, {[1000, 1030]; (ShowColourTextAt; ShowTimeAt; (0 | Beep); ([1000, 1030]; ShowColourTextAt; ShowTimeAt; Beep)*; (0 | [1000, 1030]; Beep; ShowColourTextAt; ShowColourTextAt; 2000) | Beep; ShowColourTextAt^2; !2000) | 0}] <= [{([1000, 1030]; ShowColourTextAt; ShowTimeAt; Beep)*; (0 | [1000, 1030]; Beep; ShowColourTextAt; ShowColourTextAt; 2000)}, {([1000, 1030]; ShowColourTextAt; ShowTimeAt; Beep)*; (0 | [1000, 1030]; Beep; ShowColourTextAt; ShowColourTextAt; 2000)}]` does not hold
    Note: the grade `[{[1000, 1030]; (ShowColourTextAt; ShowTimeAt; (0 | Beep); ([1000, 1030]; ShowColourTextAt; ShowTimeAt; Beep)*; (0 | [1000, 1030]; Beep; ShowColourTextAt; ShowColourTextAt; 2000) | Beep; ShowColourTextAt^2; !2000) | 0}, {1030; ShowColourTextAt; ShowTimeAt}]` is below `[{[1000, 1030]; (ShowColourTextAt; ShowTimeAt; (0 | Beep); ([1000, 1030]; ShowColourTextAt; ShowTimeAt; Beep)*; (0 | [1000, 1030]; Beep; ShowColourTextAt; ShowColourTextAt; 2000) | Beep; ShowColourTextAt^2; !2000) | 0}, {[1000, 1030]; (ShowColourTextAt; ShowTimeAt; (0 | Beep); ([1000, 1030]; ShowColourTextAt; ShowTimeAt; Beep)*; (0 | [1000, 1030]; Beep; ShowColourTextAt; ShowColourTextAt; 2000) | Beep; ShowColourTextAt^2; !2000) | 0}]` but not below `[{([1000, 1030]; ShowColourTextAt; ShowTimeAt; Beep)*; (0 | [1000, 1030]; Beep; ShowColourTextAt; ShowColourTextAt; 2000)}, {([1000, 1030]; ShowColourTextAt; ShowTimeAt; Beep)*; (0 | [1000, 1030]; Beep; ShowColourTextAt; ShowColourTextAt; 2000)}]`
  [1]

The project, for the board m5stack-cores3; its sources compile without
exceptions and run-time type information:

  $ tempore --emit-arduino fall --device $app/fall.device.json $app/fall.tpe | grep -c Wrote
  35
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
  [44.680 ms] Display fill at (0, 44), 320 by 30: 0x00c000
  [45.840 ms] Display at (9, 47): Watching
  [49.580 ms] Display at (6, 78): for falls
  [53.240 ms] Display at (0, 102): Falls
  [55.540 ms] Display at (160, 102): 0
  [2354.428 ms] Display fill at (0, 44), 320 by 30: 0xff8000
  [2355.648 ms] Display at (9, 47): Are you OK?
  [2359.468 ms] Display at (6, 78): Tap to cancel
  [2366.886 ms] Display at (0, 104): 10
  [3381.074 ms] Display at (0, 104): 9
  [4395.261 ms] Display at (0, 104): 8
  [5409.448 ms] Display at (0, 104): 7
  [6423.635 ms] Display at (0, 104): 6
  [7437.822 ms] Display at (0, 104): 5
  [8452.010 ms] Display at (0, 104): 4
  [9466.197 ms] Display at (0, 104): 3
  [10480.384 ms] Display at (0, 104): 2
  [11494.571 ms] Display at (0, 104): 1
  [12547.298 ms] Display fill at (0, 44), 320 by 30: 0xe00000
  [12548.398 ms] Display at (9, 47): ALARM
  [12552.178 ms] Display at (6, 78): Tap to stop
  [12555.938 ms] Display at (0, 102): Impact (g)
  [12558.278 ms] Display at (160, 102): 3.5
  [12564.458 ms] Display at (160, 124): 0.05
  [13578.188 ms] Display fill at (0, 44), 320 by 30: 0xffffff
  [13579.288 ms] Display at (9, 47): ALARM
  [14593.018 ms] Display fill at (0, 44), 320 by 30: 0xe00000
  [14594.118 ms] Display at (9, 47): ALARM
  [15607.848 ms] Display fill at (0, 44), 320 by 30: 0xffffff
  [15608.948 ms] Display at (9, 47): ALARM
  [16622.728 ms] Display fill at (0, 44), 320 by 30: 0x00c000
  [16623.988 ms] Display at (9, 47): Alarm stopped
  [16627.548 ms] Display at (6, 78):
  [18672.228 ms] Display fill at (0, 44), 320 by 30: 0x00c000
  [18673.388 ms] Display at (9, 47): Watching
  [18677.128 ms] Display at (6, 78): for falls
  [18680.788 ms] Display at (0, 102): Falls
  [18683.088 ms] Display at (160, 102): 1
  [25354.832 ms] Display fill at (0, 44), 320 by 30: 0xff8000
  [25356.052 ms] Display at (9, 47): Are you OK?
  [25359.872 ms] Display at (6, 78): Tap to cancel
  [25367.290 ms] Display at (0, 104): 10
  [26381.478 ms] Display at (0, 104): 9
  [27395.665 ms] Display at (0, 104): 8
  [28407.602 ms] Display fill at (0, 44), 320 by 30: 0x00c000
  [28408.782 ms] Display at (9, 47): Cancelled
  [28412.622 ms] Display at (6, 78): Glad you're OK
  [30457.302 ms] Display fill at (0, 44), 320 by 30: 0x00c000
  [30458.462 ms] Display at (9, 47): Watching
  [30462.202 ms] Display at (6, 78): for falls
  [30465.862 ms] Display at (0, 102): Falls
  [30468.162 ms] Display at (160, 102): 2
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
  [59.520 ms] Display at (0, 148): Since last event 0:00
  [1137.645 ms] Display at (0, 148): Since last event 0:01
  [18687.068 ms] Display at (0, 148): Since last event 0:00
  $ grep -c 'Display fill at (0, 1\(72\|80\))' run.log
  132

The scaffold draws the battery indicator in the top right corner after each
drawing over it; the first time after the screen of the watch:

  $ grep -m 1 'Battery' run.log
  [63.498 ms] Display at (254, 0): Battery 87%
