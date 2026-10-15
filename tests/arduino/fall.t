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
  

The rejected variants, each loaded after the application: a free fall
confirmed within 100 ms, an impact searched for beyond a second, an alarm
raised without the prompt, the unit reconfigured before the confirmation of
a free fall, and an alarm sounding on the even seconds only:

  $ for v in brief late silent rated even; do packages --typecheck-only $app/fall.tpe fall/$v.tpe; echo "[$?]"; done
  File "fall/brief.tpe", line 6, characters 18-49:
  6 |   if falling then (unbox onset as least in least) else first
                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `onset` is unboxed with grade `[{!10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu}, {!10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu}]` accumulated since it was bound, which is not below its box grade `[{100}, {(![9.5, 10.5]; ReadImu)*}]`
    File "fall/brief.tpe", line 4, characters 51-56:
    4 |   box [{100}, {(![9.5, 10.5]; ReadImu)*}] first as onset in
                                                           ^^^^^
    `onset` is bound here
    File "fall/brief.tpe", line 5, characters 16-48:
    5 |   let falling = low (low (low (low (low true)))) in
                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{!10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu}, {!10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu}]` accumulates here (this computation)
    Note: the resource inequality `[{!10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu}, {!10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu; !10; ReadImu}] <= [{100}, {(![9.5, 10.5]; ReadImu)*}]` does not hold
  [1]
  File "fall/late.tpe", line 6, characters 24-69:
  6 |   if peak > impact then (unbox window as least in Fall (least, peak))
                              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `window` is unboxed with grade `[{[0, 920]; [0, 115]; [0, 115]}, {[0, 920]; [0, 115]; [0, 115]}]` accumulated since it was bound, which is not below its box grade `[{0}, {1000}]`
    File "fall/late.tpe", line 4, characters 25-31:
    4 |   box [0, 1000] least as window in
                                 ^^^^^^
    `window` is bound here
    File "fall/late.tpe", line 5, characters 13-42:
    5 |   let peak = strikes (strikes (search ())) in
                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{[0, 920]; [0, 115]; [0, 115]}, {[0, 920]; [0, 115]; [0, 115]}]` accumulates here (this computation)
    Note: the resource inequality `[{[0, 920]; [0, 115]; [0, 115]}, {[0, 920]; [0, 115]; [0, 115]}] <= [{0}, {1000}]` does not hold
  [1]
  File "fall/silent.tpe", lines 6-7, characters 2-12:
  6 |   unbox event as fall in
        ^^^^^^^^^^^^^^^^^^^^^^
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
  Typing error: This function's body has grade `[{[1000, 1030]; (ShowColourTextAt; ShowTimeAt; (0 | Beep); ([1000, 1030]; ShowColourTextAt; ShowTimeAt; Beep)*; (0 | [1000, 1030]; Beep; ShowColourTextAt; ShowColourTextAt; 2000) | Beep; ShowColourTextAt; ShowColourTextAt; !2000) | 0}, {[1000, 1030]; (ShowColourTextAt; ShowTimeAt; (0 | Beep); ([1000, 1030]; ShowColourTextAt; ShowTimeAt; Beep)*; (0 | [1000, 1030]; Beep; ShowColourTextAt; ShowColourTextAt; 2000) | Beep; ShowColourTextAt; ShowColourTextAt; !2000) | 0}]`, which does not match its annotated grade `[{([1000, 1030]; ShowColourTextAt; ShowTimeAt; Beep)*; (0 | [1000, 1030]; Beep; ShowColourTextAt; ShowColourTextAt; 2000)}, {([1000, 1030]; ShowColourTextAt; ShowTimeAt; Beep)*; (0 | [1000, 1030]; Beep; ShowColourTextAt; ShowColourTextAt; 2000)}]`
    Note: the effect inequality `[{[1000, 1030]; (ShowColourTextAt; ShowTimeAt; (0 | Beep); ([1000, 1030]; ShowColourTextAt; ShowTimeAt; Beep)*; (0 | [1000, 1030]; Beep; ShowColourTextAt; ShowColourTextAt; 2000) | Beep; ShowColourTextAt; ShowColourTextAt; !2000) | 0}, {[1000, 1030]; (ShowColourTextAt; ShowTimeAt; (0 | Beep); ([1000, 1030]; ShowColourTextAt; ShowTimeAt; Beep)*; (0 | [1000, 1030]; Beep; ShowColourTextAt; ShowColourTextAt; 2000) | Beep; ShowColourTextAt; ShowColourTextAt; !2000) | 0}] <= [{([1000, 1030]; ShowColourTextAt; ShowTimeAt; Beep)*; (0 | [1000, 1030]; Beep; ShowColourTextAt; ShowColourTextAt; 2000)}, {([1000, 1030]; ShowColourTextAt; ShowTimeAt; Beep)*; (0 | [1000, 1030]; Beep; ShowColourTextAt; ShowColourTextAt; 2000)}]` does not hold
    Note: the grade `[{[1000, 1030]; (ShowColourTextAt; ShowTimeAt; (0 | Beep); ([1000, 1030]; ShowColourTextAt; ShowTimeAt; Beep)*; (0 | [1000, 1030]; Beep; ShowColourTextAt; ShowColourTextAt; 2000) | Beep; ShowColourTextAt; ShowColourTextAt; !2000) | 0}, {1030; ShowColourTextAt; ShowTimeAt}]` is below `[{[1000, 1030]; (ShowColourTextAt; ShowTimeAt; (0 | Beep); ([1000, 1030]; ShowColourTextAt; ShowTimeAt; Beep)*; (0 | [1000, 1030]; Beep; ShowColourTextAt; ShowColourTextAt; 2000) | Beep; ShowColourTextAt; ShowColourTextAt; !2000) | 0}, {[1000, 1030]; (ShowColourTextAt; ShowTimeAt; (0 | Beep); ([1000, 1030]; ShowColourTextAt; ShowTimeAt; Beep)*; (0 | [1000, 1030]; Beep; ShowColourTextAt; ShowColourTextAt; 2000) | Beep; ShowColourTextAt; ShowColourTextAt; !2000) | 0}]` but not below `[{([1000, 1030]; ShowColourTextAt; ShowTimeAt; Beep)*; (0 | [1000, 1030]; Beep; ShowColourTextAt; ShowColourTextAt; 2000)}, {([1000, 1030]; ShowColourTextAt; ShowTimeAt; Beep)*; (0 | [1000, 1030]; Beep; ShowColourTextAt; ShowColourTextAt; 2000)}]`
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
  [13572.008 ms] Display fill at (0, 44), 320 by 30: 0xffffff
  [13573.108 ms] Display at (9, 47): ALARM
  [14586.838 ms] Display fill at (0, 44), 320 by 30: 0xe00000
  [14587.938 ms] Display at (9, 47): ALARM
  [15601.668 ms] Display fill at (0, 44), 320 by 30: 0xffffff
  [15602.768 ms] Display at (9, 47): ALARM
  [16616.548 ms] Display fill at (0, 44), 320 by 30: 0x00c000
  [16617.808 ms] Display at (9, 47): Alarm stopped
  [16621.368 ms] Display at (6, 78):
  [18666.048 ms] Display fill at (0, 44), 320 by 30: 0x00c000
  [18667.208 ms] Display at (9, 47): Watching
  [18670.948 ms] Display at (6, 78): for falls
  [18674.608 ms] Display at (0, 102): Falls
  [18676.908 ms] Display at (160, 102): 1
  [25348.652 ms] Display fill at (0, 44), 320 by 30: 0xff8000
  [25349.872 ms] Display at (9, 47): Are you OK?
  [25353.692 ms] Display at (6, 78): Tap to cancel
  [25361.110 ms] Display at (0, 104): 10
  [26375.298 ms] Display at (0, 104): 9
  [27389.485 ms] Display at (0, 104): 8
  [28401.422 ms] Display fill at (0, 44), 320 by 30: 0x00c000
  [28402.602 ms] Display at (9, 47): Cancelled
  [28406.442 ms] Display at (6, 78): Glad you're OK
  [30451.122 ms] Display fill at (0, 44), 320 by 30: 0x00c000
  [30452.282 ms] Display at (9, 47): Watching
  [30456.022 ms] Display at (6, 78): for falls
  [30459.682 ms] Display at (0, 102): Falls
  [30461.982 ms] Display at (160, 102): 2
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
  [18680.888 ms] Display at (0, 148): Since last event 0:00
  $ grep -c 'Display fill at (0, 1\(72\|80\))' run.log
  132

The scaffold draws the battery indicator in the top right corner after each
drawing over it; the first time after the screen of the watch:

  $ grep -m 1 'Battery' run.log
  [63.498 ms] Display at (254, 0): Battery 87%
