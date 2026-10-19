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
  35
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
  [46.098 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [47.198 ms] Display at (9, 43): READY
  [49.758 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [50.938 ms] Display at (6, 72): Tap Start
  [92.970 ms] Display at (48, 200): Start
  [96.722 ms] Display at (212, 200): Reset
  [1006.262 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [1007.522 ms] Display at (9, 43): ON YOUR MARKS
  [1010.082 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [1011.362 ms] Display at (6, 72): Settle for 1 s
  [1015.174 ms] Display at (30, 200): Stand up
  [1018.826 ms] Display at (242, 200):
  [2246.846 ms] Display fill at (0, 40), 320 by 30: 0xffd000
  [2247.906 ms] Display at (9, 43): SET
  [2250.466 ms] Display fill at (0, 70), 320 by 20: 0xffd000
  [2251.666 ms] Display at (6, 72): Hold still
  [2251.816 ms] Speaker: 1500 Hz for 80 ms
  [4149.445 ms] Speaker: 2500 Hz for 300 ms
  [4314.641 ms] Display fill at (0, 40), 320 by 30: 0x00c000
  [4315.861 ms] Display at (9, 43): LEGAL START
  [4318.421 ms] Display fill at (0, 70), 320 by 20: 0x00c000
  [4319.641 ms] Display at (6, 72): Reaction, s
  [4320.921 ms] Display fill at (160, 70), 160 by 20: 0x00c000
  [4322.021 ms] Display at (166, 72): 0.161
  [4364.133 ms] Display at (48, 200): Start
  [4367.885 ms] Display at (212, 200): Reset
  [8043.925 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [8045.185 ms] Display at (9, 43): ON YOUR MARKS
  [8047.745 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [8049.025 ms] Display at (6, 72): Settle for 1 s
  [8052.837 ms] Display at (30, 200): Stand up
  [8056.489 ms] Display at (242, 200):
  [9284.509 ms] Display fill at (0, 40), 320 by 30: 0xffd000
  [9285.569 ms] Display at (9, 43): SET
  [9288.129 ms] Display fill at (0, 70), 320 by 20: 0xffd000
  [9289.329 ms] Display at (6, 72): Hold still
  [9289.479 ms] Speaker: 1500 Hz for 80 ms
  [11595.168 ms] Speaker: 2500 Hz for 300 ms
  [11657.378 ms] Speaker: 800 Hz for 80 ms
  [11767.528 ms] Speaker: 800 Hz for 80 ms
  [11771.368 ms] Display fill at (0, 40), 320 by 30: 0xe00000
  [11772.588 ms] Display at (9, 43): FALSE START
  [11775.148 ms] Display fill at (0, 70), 320 by 20: 0xe00000
  [11776.548 ms] Display at (6, 72): Warning: under 0.1 s
  [11818.660 ms] Display at (48, 200): Start
  [11822.412 ms] Display at (212, 200): Reset
  [15045.752 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [15047.012 ms] Display at (9, 43): ON YOUR MARKS
  [15049.572 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [15050.852 ms] Display at (6, 72): Settle for 1 s
  [15054.664 ms] Display at (30, 200): Stand up
  [15058.316 ms] Display at (242, 200):
  [16286.336 ms] Display fill at (0, 40), 320 by 30: 0xffd000
  [16287.396 ms] Display at (9, 43): SET
  [16289.956 ms] Display fill at (0, 70), 320 by 20: 0xffd000
  [16291.156 ms] Display at (6, 72): Hold still
  [16291.306 ms] Speaker: 1500 Hz for 80 ms
  [17107.576 ms] Speaker: 800 Hz for 80 ms
  [17217.726 ms] Speaker: 800 Hz for 80 ms
  [17221.566 ms] Display fill at (0, 40), 320 by 30: 0xe00000
  [17222.806 ms] Display at (9, 43): DISQUALIFIED
  [17225.366 ms] Display fill at (0, 70), 320 by 20: 0xe00000
  [17226.606 ms] Display at (6, 72): Moved in Set
  [17268.718 ms] Display at (48, 200): Start
  [17272.470 ms] Display at (212, 200): Reset
  [22004.810 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [22006.070 ms] Display at (9, 43): ON YOUR MARKS
  [22008.630 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [22009.910 ms] Display at (6, 72): Settle for 1 s
  [22013.722 ms] Display at (30, 200): Stand up
  [22017.374 ms] Display at (242, 200):
  [23245.394 ms] Display fill at (0, 40), 320 by 30: 0xffd000
  [23246.454 ms] Display at (9, 43): SET
  [23249.014 ms] Display fill at (0, 70), 320 by 20: 0xffd000
  [23250.214 ms] Display at (6, 72): Hold still
  [23250.364 ms] Speaker: 1500 Hz for 80 ms
  [25392.829 ms] Speaker: 2500 Hz for 300 ms
  [26017.269 ms] Display fill at (0, 40), 320 by 30: 0xff8000
  [26018.429 ms] Display at (9, 43): NO START
  [26020.989 ms] Display fill at (0, 70), 320 by 20: 0xff8000
  [26022.229 ms] Display at (6, 72): No push seen
  [26064.341 ms] Display at (48, 200): Start
  [26068.093 ms] Display at (212, 200): Reset
  [29039.933 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [29041.193 ms] Display at (9, 43): ON YOUR MARKS
  [29043.753 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [29045.033 ms] Display at (6, 72): Settle for 1 s
  [29048.845 ms] Display at (30, 200): Stand up
  [29052.497 ms] Display at (242, 200):
  [30280.517 ms] Display fill at (0, 40), 320 by 30: 0xffd000
  [30281.577 ms] Display at (9, 43): SET
  [30284.137 ms] Display fill at (0, 70), 320 by 20: 0xffd000
  [30285.337 ms] Display at (6, 72): Hold still
  [30285.487 ms] Speaker: 1500 Hz for 80 ms
  [31309.477 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [31310.637 ms] Display at (9, 43): STAND UP
  [31313.197 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [31314.497 ms] Display at (6, 72): Start abandoned
  [31356.609 ms] Display at (48, 200): Start
  [31360.361 ms] Display at (212, 200): Reset
  [36038.711 ms] Speaker: 3000 Hz for 50 ms
  [36042.551 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [36043.651 ms] Display at (9, 43): READY
  [36046.211 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [36047.471 ms] Display at (6, 72): Tally cleared
  [36089.503 ms] Display at (48, 200): Start
  [36093.255 ms] Display at (212, 200): Reset
  [43038.795 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [43040.055 ms] Display at (9, 43): ON YOUR MARKS
  [43042.615 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [43043.895 ms] Display at (6, 72): Settle for 1 s
  [43047.707 ms] Display at (30, 200): Stand up
  [43051.359 ms] Display at (242, 200):
  [44279.379 ms] Display fill at (0, 40), 320 by 30: 0xff8000
  [44280.559 ms] Display at (9, 43): NOT STILL
  [44283.119 ms] Display fill at (0, 70), 320 by 20: 0xff8000
  [44284.519 ms] Display at (6, 72): Settle and tap Start
  [44326.551 ms] Display at (48, 200): Start
  [44330.303 ms] Display at (212, 200): Reset
  [50000.000 ms] End of the simulation

The gun is fired 1500 to 3000 ms after the Set command, at times drawn from
the clock, and the tally after the starts, before the Reset, reads one legal
start, one warning, one disqualification and one start without a push, each
row written from left to right, each label before its value:

  $ grep 'Speaker: \(1500\|2500\)' run.log | awk '{ t = substr($1, 2) + 0; if ($4 == "1500") set = t; else print int(t - set), (t - set >= 1500 && t - set <= 3000) }'
  1897 1
  2305 1
  2142 1
  $ grep 'Display at ([0-9]*, \(102\|124\|146\|168\))' run.log | sed -n '71,84p'
  [31318.157 ms] Display at (0, 102): Legal
  [31320.969 ms] Display at (96, 102): 1
  [31323.409 ms] Display at (160, 102): Warnings
  [31324.749 ms] Display at (280, 102): 1
  [31328.349 ms] Display at (0, 124): DQ
  [31331.161 ms] Display at (96, 124): 1
  [31333.621 ms] Display at (160, 124): No starts
  [31334.961 ms] Display at (280, 124): 1
  [31338.661 ms] Display at (0, 146): Best, s
  [31341.553 ms] Display at (96, 146): 0.161
  [31345.193 ms] Display at (0, 168): Lane
  [31348.293 ms] Display at (60, 168): 1
  [31351.325 ms] Display at (96, 168): False starts
  [31352.857 ms] Display at (256, 168): 2
