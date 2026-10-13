The fall detector of examples/arduino/fall on the M5Stack CoreS3 Lite, with
the packages m5-imu, m5-display, m5-touch and m5-speaker, under the regular
expressions of timed operations: its run by the interpreter, its rejected
variants, its project and its host simulation, over the falls and the taps
of its host model.

  $ app=../../examples/arduino/fall
  $ tempore () { ../../tempore --grades regex-timed-interval-rational-symbolic "$@"; }
  $ packages () {
  >   tempore --package m5-imu --package m5-display --package m5-touch \
  >     --package m5-speaker --board m5stack-cores3 "$@"
  > }

The interpreter runs a suspected fall with the default implementations of
the operations, which read a unit at rest:

  $ packages $app/fall.tpe
  === Run 1 ===
  return 0
  State: [
    { resource_0 ↦ 0.1 # [{100}, ∞) },
    [{10}, {10}],
    [{0.6}, {0.6}],
    [{10}, {10}],
    [{0.6}, {0.6}],
    [{10}, {10}],
    [{0.6}, {0.6}],
    [{10}, {10}],
    [{0.6}, {0.6}],
    [{10}, {10}],
    [{0.6}, {0.6}],
    [{10}, {10}],
    [{0.6}, {0.6}],
    [{10}, {10}],
    [{0.6}, {0.6}],
    [{10}, {10}],
    [{0.6}, {0.6}],
    [{10}, {10}],
    [{0.6}, {0.6}],
    [{10}, {10}],
    [{0.6}, {0.6}]
  ]
  

The rejected variants, each loaded after the application: a free fall
confirmed within 100 ms, an impact searched for beyond a second, and an
alarm raised five seconds after the tone, without the prompt, and from a
stale event:

  $ for v in brief late early silent stale; do packages --typecheck-only $app/fall.tpe fall/$v.tpe; echo "[$?]"; done
  File "fall/brief.tpe", line 6, characters 18-49:
  6 |   if falling then (unbox onset as least in least) else first
                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `onset` is unboxed with grade `[{10; ReadImu; 10; ReadImu; 10; ReadImu; 10; ReadImu; 10; ReadImu}, {10; ReadImu; 10; ReadImu; 10; ReadImu; 10; ReadImu; 10; ReadImu}]` accumulated since it was bound, which is not below its box grade `[{100}, ∞)`
    File "fall/brief.tpe", line 4, characters 26-31:
    4 |   box [100, ∞) first as onset in
                                ^^^^^
    `onset` is bound here
    File "fall/brief.tpe", line 5, characters 16-48:
    5 |   let falling = low (low (low (low (low true)))) in
                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{10; ReadImu; 10; ReadImu; 10; ReadImu; 10; ReadImu; 10; ReadImu}, {10; ReadImu; 10; ReadImu; 10; ReadImu; 10; ReadImu; 10; ReadImu}]` accumulates here (this computation)
    Note: the resource inequality `[{10; ReadImu; 10; ReadImu; 10; ReadImu; 10; ReadImu; 10; ReadImu}, {10; ReadImu; 10; ReadImu; 10; ReadImu; 10; ReadImu; 10; ReadImu}] <= [{100}, ∞)` does not hold
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
  File "fall/early.tpe", lines 9-10, characters 2-12:
  9 |   unbox event as fall in
        ^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `event` is unboxed with grade `[{ShowColourTextAt; ShowColourTextAt; Beep; 5000}, {ShowColourTextAt; ShowColourTextAt; Beep; 5000}]` accumulated since it was bound, which is not below its box grade `[{ShowColourTextAt; ShowColourTextAt; Beep; [10000, 30000]}, {ShowColourTextAt; ShowColourTextAt; Beep; [10000, 30000]}]`
    File "fall/early.tpe", line 4, characters 73-78:
    4 |   box {ShowColourTextAt; ShowColourTextAt; Beep; [10000, 30000]} fall as event in
                                                                                 ^^^^^
    `event` is bound here
    File "fall/early.tpe", line 5, characters 2-67:
    5 |   perform ShowColourTextAt (0, 44, 3, black, orange, "Are you OK?");
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{ShowColourTextAt}, {ShowColourTextAt}]` accumulates here (operation `ShowColourTextAt`)
    File "fall/early.tpe", line 6, characters 2-69:
    6 |   perform ShowColourTextAt (0, 76, 2, black, orange, "Tap to cancel");
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{ShowColourTextAt}, {ShowColourTextAt}]` accumulates here (operation `ShowColourTextAt`)
    File "fall/early.tpe", line 7, characters 2-26:
    7 |   perform Beep (1000, 300);
          ^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{Beep}, {Beep}]` accumulates here (operation `Beep`)
    File "fall/early.tpe", line 8, characters 2-12:
    8 |   delay 5000;
          ^^^^^^^^^^
    grade `[{5000}, {5000}]` accumulates here (delay)
    Note: the resource inequality `[{ShowColourTextAt; ShowColourTextAt; Beep; 5000}, {ShowColourTextAt; ShowColourTextAt; Beep; 5000}] <= [{ShowColourTextAt; ShowColourTextAt; Beep; [10000, 30000]}, {ShowColourTextAt; ShowColourTextAt; Beep; [10000, 30000]}]` does not hold
  [1]
  File "fall/silent.tpe", lines 6-7, characters 2-12:
  6 |   unbox event as fall in
        ^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `event` is unboxed with grade `[{10000}, {10000}]` accumulated since it was bound, which is not below its box grade `[{ShowColourTextAt; ShowColourTextAt; Beep; [10000, 30000]}, {ShowColourTextAt; ShowColourTextAt; Beep; [10000, 30000]}]`
    File "fall/silent.tpe", line 4, characters 73-78:
    4 |   box {ShowColourTextAt; ShowColourTextAt; Beep; [10000, 30000]} fall as event in
                                                                                 ^^^^^
    `event` is bound here
    File "fall/silent.tpe", line 5, characters 2-13:
    5 |   delay 10000;
          ^^^^^^^^^^^
    grade `[{10000}, {10000}]` accumulates here (delay)
    Note: the resource inequality `[{10000}, {10000}] <= [{ShowColourTextAt; ShowColourTextAt; Beep; [10000, 30000]}, {ShowColourTextAt; ShowColourTextAt; Beep; [10000, 30000]}]` does not hold
  [1]
  File "fall/stale.tpe", line 10, characters 32-67:
  10 |   if tapped then cancel () else (unbox event as fall in raise fall)
                                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `event` is unboxed with grade `[{ShowColourTextAt; ShowColourTextAt; Beep; [1000, 1030]; 29000}, {ShowColourTextAt; ShowColourTextAt; Beep; [1000, 1030]; 29000}]` accumulated since it was bound, which is not below its box grade `[{ShowColourTextAt; ShowColourTextAt; Beep; [10000, 30000]}, {ShowColourTextAt; ShowColourTextAt; Beep; [10000, 30000]}]`
    File "fall/stale.tpe", line 4, characters 73-78:
    4 |   box {ShowColourTextAt; ShowColourTextAt; Beep; [10000, 30000]} fall as event in
                                                                                 ^^^^^
    `event` is bound here
    File "fall/stale.tpe", line 5, characters 2-67:
    5 |   perform ShowColourTextAt (0, 44, 3, black, orange, "Are you OK?");
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{ShowColourTextAt}, {ShowColourTextAt}]` accumulates here (operation `ShowColourTextAt`)
    File "fall/stale.tpe", line 6, characters 2-69:
    6 |   perform ShowColourTextAt (0, 76, 2, black, orange, "Tap to cancel");
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{ShowColourTextAt}, {ShowColourTextAt}]` accumulates here (operation `ShowColourTextAt`)
    File "fall/stale.tpe", line 7, characters 2-26:
    7 |   perform Beep (1000, 300);
          ^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{Beep}, {Beep}]` accumulates here (operation `Beep`)
    File "fall/stale.tpe", line 8, characters 15-26:
    8 |   let tapped = polls false in
                       ^^^^^^^^^^^
    grade `[{[1000, 1030]}, {[1000, 1030]}]` accumulates here (this computation)
    File "fall/stale.tpe", line 9, characters 2-13:
    9 |   delay 29000;
          ^^^^^^^^^^^
    grade `[{29000}, {29000}]` accumulates here (delay)
    Note: the resource inequality `[{ShowColourTextAt; ShowColourTextAt; Beep; [1000, 1030]; 29000}, {ShowColourTextAt; ShowColourTextAt; Beep; [1000, 1030]; 29000}] <= [{ShowColourTextAt; ShowColourTextAt; Beep; [10000, 30000]}, {ShowColourTextAt; ShowColourTextAt; Beep; [10000, 30000]}]` does not hold
  [1]

The project, for the board m5stack-cores3; its sources compile without
exceptions and run-time type information:

  $ tempore --emit-arduino fall --device $app/fall.device.json $app/fall.tpe | grep -c Wrote
  32
  $ cd _arduino/projects/fall
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

35 seconds of simulated time: the first fall, at 2 s, is detected after its
impact at 2.3 s, counted down in orange, and alarmed in red at about 12.5 s,
the alarm flashing and sounding every second until the tap at 16 s stops it;
the second, at 25 s, is cancelled by the tap at 28 s. The screen of the
watch, in green, shows the falls counted:

  $ tempore --emit-arduino fall --device $app/fall.device.json --host-simulate 35 $app/fall.tpe > run.log
  $ grep 'Display at (0, \(44\|76\|100\))\|Display at (160\|Display fill at (0, 44)\|simulation' run.log | sed 's/ *$//'
  [44.680 ms] Display fill at (0, 44), 320 by 30: 0x00c000
  [45.840 ms] Display at (0, 44): Watching
  [49.580 ms] Display at (0, 76): for falls
  [53.240 ms] Display at (0, 100): Falls
  [55.540 ms] Display at (160, 100): 0
  [2353.773 ms] Display fill at (0, 44), 320 by 30: 0xff8000
  [2354.993 ms] Display at (0, 44): Are you OK?
  [2358.813 ms] Display at (0, 76): Tap to cancel
  [2365.023 ms] Display at (0, 100): 10
  [3379.211 ms] Display at (0, 100): 9
  [4393.398 ms] Display at (0, 100): 8
  [5407.585 ms] Display at (0, 100): 7
  [6421.772 ms] Display at (0, 100): 6
  [7435.959 ms] Display at (0, 100): 5
  [8450.147 ms] Display at (0, 100): 4
  [9464.334 ms] Display at (0, 100): 3
  [10478.521 ms] Display at (0, 100): 2
  [11492.708 ms] Display at (0, 100): 1
  [12545.435 ms] Display fill at (0, 44), 320 by 30: 0xe00000
  [12546.535 ms] Display at (0, 44): ALARM
  [12550.315 ms] Display at (0, 76): Tap to stop
  [12554.075 ms] Display at (0, 100): Impact (g)
  [12556.415 ms] Display at (160, 100): 3.5
  [13570.145 ms] Display fill at (0, 44), 320 by 30: 0xffffff
  [13571.245 ms] Display at (0, 44): ALARM
  [14584.975 ms] Display fill at (0, 44), 320 by 30: 0xe00000
  [14586.075 ms] Display at (0, 44): ALARM
  [15599.805 ms] Display fill at (0, 44), 320 by 30: 0xffffff
  [15600.905 ms] Display at (0, 44): ALARM
  [16614.685 ms] Display fill at (0, 44), 320 by 30: 0x00c000
  [16615.945 ms] Display at (0, 44): Alarm stopped
  [16619.505 ms] Display at (0, 76):
  [18664.185 ms] Display fill at (0, 44), 320 by 30: 0x00c000
  [18665.345 ms] Display at (0, 44): Watching
  [18669.085 ms] Display at (0, 76): for falls
  [18672.745 ms] Display at (0, 100): Falls
  [18675.045 ms] Display at (160, 100): 1
  [25346.134 ms] Display fill at (0, 44), 320 by 30: 0xff8000
  [25347.354 ms] Display at (0, 44): Are you OK?
  [25351.174 ms] Display at (0, 76): Tap to cancel
  [25357.384 ms] Display at (0, 100): 10
  [26371.572 ms] Display at (0, 100): 9
  [27385.759 ms] Display at (0, 100): 8
  [28397.696 ms] Display fill at (0, 44), 320 by 30: 0x00c000
  [28398.876 ms] Display at (0, 44): Cancelled
  [28402.716 ms] Display at (0, 76): Glad you're OK
  [30447.396 ms] Display fill at (0, 44), 320 by 30: 0x00c000
  [30448.556 ms] Display at (0, 44): Watching
  [30452.296 ms] Display at (0, 76): for falls
  [30455.956 ms] Display at (0, 100): Falls
  [30458.256 ms] Display at (160, 100): 2
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
  [59.520 ms] Display at (0, 146): Since last event 0:00
  [1136.990 ms] Display at (0, 146): Since last event 0:01
  [18679.025 ms] Display at (0, 146): Since last event 0:00
  $ grep -c 'Display fill at (0, 172)' run.log
  132
