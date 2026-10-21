The sprint start system of examples/arduino/starter on the M5Stack CoreS3 Lite,
with the packages m5-imu, m5-display, m5-touch and m5-speaker, under the
rigid regular expressions of timed operations: its runs by the interpreter,
its rejected variants, its project and its host simulation, over the starts
and the taps of its host model.

  $ app=../../examples/arduino/starter
  $ . ../helpers.sh
  $ from_header $app/starter.tpe

The interpreter judges the athlete of lane 1 after the gun: not warned, on a
block at rest, a start without a push; warned once, on a block pushed at
once, a disqualification, the reaction time 0 under the default ReadClock:

  $ packages $app/starter.tpe | strip_state
  === Run 1 ===
  return ((0, 0, 0, 1, 0), (1, 0))
  
  === Run 2 ===
  return ((0, 1, 1, 0, 0), (1, 2))
  

The rejected variants, each loaded after the application: the screen
cleared between the gun and the reading of its time, GO shown between the
reading of the time of the gun and the polls, and the gun fired after sixty
polls of the hold:

  $ for v in cleared shown early; do packages --typecheck-only $app/starter.tpe starter/$v.tpe > $v.log 2>&1; echo "[$?]"; grep -o 'Typing error: Variable `[a-z]*` is unboxed' $v.log; done
  [1]
  Typing error: Variable `gun` is unboxed
  [1]
  Typing error: Variable `window` is unboxed
  [1]
  Typing error: Variable `set` is unboxed

The project, for the board m5stack-cores3; its sources, with the thunks of
the nested boxes compiled as closures, compile without exceptions and
run-time type information:

  $ tempore --emit-arduino starter --device $app/starter.device.json $app/starter.tpe | grep -c Wrote
  36
  $ cd _arduino/projects/starter
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

50 seconds of simulated time, a tap every 7 s from 1 s: a legal start, the
push 160 ms after the gun; a false start, the push 60 ms after it, a
warning; a movement in Set, the second false start, a disqualification; a
start without a push; a start abandoned by Stand up a second after Set; a
tap on Reset, which clears the tally; and a block not still at the marks.
The Set tone is of 1500 Hz, the gun of 2500 Hz, the recall two tones of
800 Hz and the tone of Reset of 3000 Hz. Each state fills both bands of the
panel, from the rows 40 and 70, in one colour, the reaction time included;
the Reset button is drawn without a label during a start:

  $ tempore --emit-arduino starter --device $app/starter.device.json --host-simulate 50 $app/starter.tpe > run.log
  $ grep 'Display at (\(9, 43\|6, 72\|166, 72\|[0-9]*, 200\))\|Display fill at (\(0, 40\|0, 70\|160, 70\))\|Speaker\|simulation' run.log | sed 's/ *$//'
  [45.306 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [46.406 ms] Display at (9, 43): READY
  [48.966 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [50.146 ms] Display at (6, 72): Tap Start
  [92.178 ms] Display at (48, 200): Start
  [95.930 ms] Display at (212, 200): Reset
  [1005.470 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [1006.730 ms] Display at (9, 43): ON YOUR MARKS
  [1009.290 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [1010.570 ms] Display at (6, 72): Settle for 1 s
  [1014.382 ms] Display at (30, 200): Stand up
  [1018.034 ms] Display at (242, 200):
  [2246.054 ms] Display fill at (0, 40), 320 by 30: 0xffd000
  [2247.114 ms] Display at (9, 43): SET
  [2249.674 ms] Display fill at (0, 70), 320 by 20: 0xffd000
  [2250.874 ms] Display at (6, 72): Hold still
  [2251.024 ms] Speaker: 1500 Hz for 80 ms
  [4638.325 ms] Speaker: 2500 Hz for 300 ms
  [4803.521 ms] Display fill at (0, 40), 320 by 30: 0x00c000
  [4804.741 ms] Display at (9, 43): LEGAL START
  [4807.301 ms] Display fill at (0, 70), 320 by 20: 0x00c000
  [4808.521 ms] Display at (6, 72): Reaction, s
  [4809.801 ms] Display fill at (160, 70), 160 by 20: 0x00c000
  [4810.901 ms] Display at (166, 72): 0.161
  [4853.013 ms] Display at (48, 200): Start
  [4856.765 ms] Display at (212, 200): Reset
  [8029.805 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [8031.065 ms] Display at (9, 43): ON YOUR MARKS
  [8033.625 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [8034.905 ms] Display at (6, 72): Settle for 1 s
  [8038.717 ms] Display at (30, 200): Stand up
  [8042.369 ms] Display at (242, 200):
  [9270.389 ms] Display fill at (0, 40), 320 by 30: 0xffd000
  [9271.449 ms] Display at (9, 43): SET
  [9274.009 ms] Display fill at (0, 70), 320 by 20: 0xffd000
  [9275.209 ms] Display at (6, 72): Hold still
  [9275.359 ms] Speaker: 1500 Hz for 80 ms
  [11723.869 ms] Speaker: 2500 Hz for 300 ms
  [11786.079 ms] Speaker: 800 Hz for 80 ms
  [11896.229 ms] Speaker: 800 Hz for 80 ms
  [11900.069 ms] Display fill at (0, 40), 320 by 30: 0xe00000
  [11901.289 ms] Display at (9, 43): FALSE START
  [11903.849 ms] Display fill at (0, 70), 320 by 20: 0xe00000
  [11905.249 ms] Display at (6, 72): Warning: under 0.1 s
  [11947.361 ms] Display at (48, 200): Start
  [11951.113 ms] Display at (212, 200): Reset
  [15023.553 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [15024.813 ms] Display at (9, 43): ON YOUR MARKS
  [15027.373 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [15028.653 ms] Display at (6, 72): Settle for 1 s
  [15032.465 ms] Display at (30, 200): Stand up
  [15036.117 ms] Display at (242, 200):
  [16264.137 ms] Display fill at (0, 40), 320 by 30: 0xffd000
  [16265.197 ms] Display at (9, 43): SET
  [16267.757 ms] Display fill at (0, 70), 320 by 20: 0xffd000
  [16268.957 ms] Display at (6, 72): Hold still
  [16269.107 ms] Speaker: 1500 Hz for 80 ms
  [17085.377 ms] Speaker: 800 Hz for 80 ms
  [17195.527 ms] Speaker: 800 Hz for 80 ms
  [17199.367 ms] Display fill at (0, 40), 320 by 30: 0xe00000
  [17200.607 ms] Display at (9, 43): DISQUALIFIED
  [17203.167 ms] Display fill at (0, 70), 320 by 20: 0xe00000
  [17204.407 ms] Display at (6, 72): Moved in Set
  [17246.519 ms] Display at (48, 200): Start
  [17250.271 ms] Display at (212, 200): Reset
  [22032.911 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [22034.171 ms] Display at (9, 43): ON YOUR MARKS
  [22036.731 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [22038.011 ms] Display at (6, 72): Settle for 1 s
  [22041.823 ms] Display at (30, 200): Stand up
  [22045.475 ms] Display at (242, 200):
  [23273.495 ms] Display fill at (0, 40), 320 by 30: 0xffd000
  [23274.555 ms] Display at (9, 43): SET
  [23277.115 ms] Display fill at (0, 70), 320 by 20: 0xffd000
  [23278.315 ms] Display at (6, 72): Hold still
  [23278.465 ms] Speaker: 1500 Hz for 80 ms
  [25420.930 ms] Speaker: 2500 Hz for 300 ms
  [26045.370 ms] Display fill at (0, 40), 320 by 30: 0xff8000
  [26046.530 ms] Display at (9, 43): NO START
  [26049.090 ms] Display fill at (0, 70), 320 by 20: 0xff8000
  [26050.330 ms] Display at (6, 72): No push seen
  [26092.442 ms] Display at (48, 200): Start
  [26096.194 ms] Display at (212, 200): Reset
  [29017.734 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [29018.994 ms] Display at (9, 43): ON YOUR MARKS
  [29021.554 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [29022.834 ms] Display at (6, 72): Settle for 1 s
  [29026.646 ms] Display at (30, 200): Stand up
  [29030.298 ms] Display at (242, 200):
  [30258.318 ms] Display fill at (0, 40), 320 by 30: 0xffd000
  [30259.378 ms] Display at (9, 43): SET
  [30261.938 ms] Display fill at (0, 70), 320 by 20: 0xffd000
  [30263.138 ms] Display at (6, 72): Hold still
  [30263.288 ms] Speaker: 1500 Hz for 80 ms
  [31287.278 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [31288.438 ms] Display at (9, 43): STAND UP
  [31290.998 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [31292.298 ms] Display at (6, 72): Start abandoned
  [31334.410 ms] Display at (48, 200): Start
  [31338.162 ms] Display at (212, 200): Reset
  [36016.512 ms] Speaker: 3000 Hz for 50 ms
  [36020.352 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [36021.452 ms] Display at (9, 43): READY
  [36024.012 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [36025.272 ms] Display at (6, 72): Tally cleared
  [36067.304 ms] Display at (48, 200): Start
  [36071.056 ms] Display at (212, 200): Reset
  [43016.596 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [43017.856 ms] Display at (9, 43): ON YOUR MARKS
  [43020.416 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [43021.696 ms] Display at (6, 72): Settle for 1 s
  [43025.508 ms] Display at (30, 200): Stand up
  [43029.160 ms] Display at (242, 200):
  [44257.180 ms] Display fill at (0, 40), 320 by 30: 0xff8000
  [44258.360 ms] Display at (9, 43): NOT STILL
  [44260.920 ms] Display fill at (0, 70), 320 by 20: 0xff8000
  [44262.320 ms] Display at (6, 72): Settle and tap Start
  [44304.352 ms] Display at (48, 200): Start
  [44308.104 ms] Display at (212, 200): Reset
  [50000.000 ms] End of the simulation

The gun is fired 1500 to 3000 ms after the Set command, at times drawn from
the clock, and the tally after the starts, before the Reset, reads one legal
start, one warning, one disqualification and one start without a push, each
row written from left to right, each label before its value:

  $ grep 'Speaker: \(1500\|2500\)' run.log | awk '{ t = substr($1, 2) + 0; if ($4 == "1500") set = t; else print int(t - set), (t - set >= 1500 && t - set <= 3000) }'
  2387 1
  2448 1
  2142 1
  $ grep 'Display at ([0-9]*, \(102\|124\|146\|168\))' run.log | sed -n '71,84p'
  [31295.958 ms] Display at (0, 102): Legal
  [31298.770 ms] Display at (96, 102): 1
  [31301.210 ms] Display at (160, 102): Warnings
  [31302.550 ms] Display at (280, 102): 1
  [31306.150 ms] Display at (0, 124): DQ
  [31308.962 ms] Display at (96, 124): 1
  [31311.422 ms] Display at (160, 124): No starts
  [31312.762 ms] Display at (280, 124): 1
  [31316.462 ms] Display at (0, 146): Best, s
  [31319.354 ms] Display at (96, 146): 0.161
  [31322.994 ms] Display at (0, 168): Lane
  [31326.094 ms] Display at (60, 168): 1
  [31329.126 ms] Display at (96, 168): False starts
  [31330.658 ms] Display at (256, 168): 2
