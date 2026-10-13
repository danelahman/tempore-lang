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
  Typing error: Variable `event` is unboxed with grade `[{ShowTextAt; ShowTextAt; Beep; 5000}, {ShowTextAt; ShowTextAt; Beep; 5000}]` accumulated since it was bound, which is not below its box grade `[{ShowTextAt; ShowTextAt; Beep; [10000, 30000]}, {ShowTextAt; ShowTextAt; Beep; [10000, 30000]}]`
    File "fall/early.tpe", line 4, characters 61-66:
    4 |   box {ShowTextAt; ShowTextAt; Beep; [10000, 30000]} fall as event in
                                                                     ^^^^^
    `event` is bound here
    File "fall/early.tpe", line 5, characters 2-48:
    5 |   perform ShowTextAt (0, 60, 3, "Fall detected");
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{ShowTextAt}, {ShowTextAt}]` accumulates here (operation `ShowTextAt`)
    File "fall/early.tpe", line 6, characters 2-45:
    6 |   perform ShowTextAt (0, 100, 3, "Tap if OK");
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{ShowTextAt}, {ShowTextAt}]` accumulates here (operation `ShowTextAt`)
    File "fall/early.tpe", line 7, characters 2-26:
    7 |   perform Beep (1000, 300);
          ^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{Beep}, {Beep}]` accumulates here (operation `Beep`)
    File "fall/early.tpe", line 8, characters 2-12:
    8 |   delay 5000;
          ^^^^^^^^^^
    grade `[{5000}, {5000}]` accumulates here (delay)
    Note: the resource inequality `[{ShowTextAt; ShowTextAt; Beep; 5000}, {ShowTextAt; ShowTextAt; Beep; 5000}] <= [{ShowTextAt; ShowTextAt; Beep; [10000, 30000]}, {ShowTextAt; ShowTextAt; Beep; [10000, 30000]}]` does not hold
  [1]
  File "fall/silent.tpe", lines 6-7, characters 2-12:
  6 |   unbox event as fall in
        ^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `event` is unboxed with grade `[{10000}, {10000}]` accumulated since it was bound, which is not below its box grade `[{ShowTextAt; ShowTextAt; Beep; [10000, 30000]}, {ShowTextAt; ShowTextAt; Beep; [10000, 30000]}]`
    File "fall/silent.tpe", line 4, characters 61-66:
    4 |   box {ShowTextAt; ShowTextAt; Beep; [10000, 30000]} fall as event in
                                                                     ^^^^^
    `event` is bound here
    File "fall/silent.tpe", line 5, characters 2-13:
    5 |   delay 10000;
          ^^^^^^^^^^^
    grade `[{10000}, {10000}]` accumulates here (delay)
    Note: the resource inequality `[{10000}, {10000}] <= [{ShowTextAt; ShowTextAt; Beep; [10000, 30000]}, {ShowTextAt; ShowTextAt; Beep; [10000, 30000]}]` does not hold
  [1]
  File "fall/stale.tpe", line 10, characters 32-67:
  10 |   if tapped then cancel () else (unbox event as fall in raise fall)
                                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `event` is unboxed with grade `[{ShowTextAt; ShowTextAt; Beep; [1000, 1030]; 29000}, {ShowTextAt; ShowTextAt; Beep; [1000, 1030]; 29000}]` accumulated since it was bound, which is not below its box grade `[{ShowTextAt; ShowTextAt; Beep; [10000, 30000]}, {ShowTextAt; ShowTextAt; Beep; [10000, 30000]}]`
    File "fall/stale.tpe", line 4, characters 61-66:
    4 |   box {ShowTextAt; ShowTextAt; Beep; [10000, 30000]} fall as event in
                                                                     ^^^^^
    `event` is bound here
    File "fall/stale.tpe", line 5, characters 2-48:
    5 |   perform ShowTextAt (0, 60, 3, "Fall detected");
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{ShowTextAt}, {ShowTextAt}]` accumulates here (operation `ShowTextAt`)
    File "fall/stale.tpe", line 6, characters 2-45:
    6 |   perform ShowTextAt (0, 100, 3, "Tap if OK");
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{ShowTextAt}, {ShowTextAt}]` accumulates here (operation `ShowTextAt`)
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
    Note: the resource inequality `[{ShowTextAt; ShowTextAt; Beep; [1000, 1030]; 29000}, {ShowTextAt; ShowTextAt; Beep; [1000, 1030]; 29000}] <= [{ShowTextAt; ShowTextAt; Beep; [10000, 30000]}, {ShowTextAt; ShowTextAt; Beep; [10000, 30000]}]` does not hold
  [1]

The project, for the board m5stack-cores3; its sources compile without
exceptions and run-time type information:

  $ tempore --emit-arduino fall --device $app/fall.device.json $app/fall.tpe | grep -c Wrote
  31
  $ cd _arduino/projects/fall
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

35 seconds of simulated time: the first fall, at 2 s, is detected after its
impact at 2.3 s, counted down, and alarmed at about 12.4 s, the alarm
sounding every second until the tap at 16 s acknowledges it; the second, at
25 s, is cancelled by the tap at 28 s. The screen shows the falls counted:

  $ tempore --emit-arduino fall --device $app/fall.device.json --host-simulate 35 $app/fall.tpe > run.log
  $ grep 'Display at (0, [0-9]*0)\|Display at (130\|simulation' run.log | grep -v 'Display at (0, 0)\|(0, 230)\|(0, 190)' | sed 's/ *$//'
  [38.120 ms] Display at (0, 60): Monitoring
  [44.200 ms] Display at (130, 190): 0
  [2310.362 ms] Display at (0, 60): Fall detected
  [2315.202 ms] Display at (0, 100): Tap if OK
  [2321.372 ms] Display at (0, 140): 10
  [3333.492 ms] Display at (0, 140): 9
  [4345.612 ms] Display at (0, 140): 8
  [5357.732 ms] Display at (0, 140): 7
  [6369.852 ms] Display at (0, 140): 6
  [7381.972 ms] Display at (0, 140): 5
  [8394.092 ms] Display at (0, 140): 4
  [9406.212 ms] Display at (0, 140): 3
  [10418.332 ms] Display at (0, 140): 2
  [11430.452 ms] Display at (0, 140): 1
  [12442.572 ms] Display at (0, 60): ALARM
  [12447.412 ms] Display at (0, 100): 3.5
  [12453.532 ms] Display at (0, 140):
  [16482.572 ms] Display at (0, 60): Alarm
  [16487.412 ms] Display at (0, 100): acknowledged
  [18525.532 ms] Display at (0, 60): Monitoring
  [18531.612 ms] Display at (130, 190): 1
  [25314.652 ms] Display at (0, 60): Fall detected
  [25319.492 ms] Display at (0, 100): Tap if OK
  [25325.662 ms] Display at (0, 140): 10
  [26337.782 ms] Display at (0, 140): 9
  [27349.902 ms] Display at (0, 140): 8
  [28362.022 ms] Display at (0, 140):
  [28366.862 ms] Display at (0, 100): Cancelled
  [30404.982 ms] Display at (0, 60): Monitoring
  [30411.062 ms] Display at (130, 190): 2
  [35000.000 ms] End of the simulation
  $ grep -c 'Speaker: 2000 Hz' run.log
  4
