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
  [2251.716 ms] Speaker: 1500 Hz for 80 ms
  [4190.051 ms] Speaker: 2500 Hz for 300 ms
  [4355.247 ms] Display fill at (0, 40), 320 by 30: 0x00c000
  [4356.467 ms] Display at (9, 43): LEGAL START
  [4359.027 ms] Display fill at (0, 70), 320 by 20: 0x00c000
  [4360.247 ms] Display at (6, 72): Reaction, s
  [4361.527 ms] Display fill at (160, 70), 160 by 20: 0x00c000
  [4362.627 ms] Display at (166, 72): 0.161
  [4404.739 ms] Display at (48, 200): Start
  [4408.491 ms] Display at (212, 200): Reset
  [8034.231 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [8035.491 ms] Display at (9, 43): ON YOUR MARKS
  [8038.051 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [8039.331 ms] Display at (6, 72): Settle for 1 s
  [8043.143 ms] Display at (30, 200): Stand up
  [8046.795 ms] Display at (242, 200):
  [9274.815 ms] Display fill at (0, 40), 320 by 30: 0xffd000
  [9275.875 ms] Display at (9, 43): SET
  [9278.435 ms] Display fill at (0, 70), 320 by 20: 0xffd000
  [9279.635 ms] Display at (6, 72): Hold still
  [9279.685 ms] Speaker: 1500 Hz for 80 ms
  [11544.468 ms] Speaker: 2500 Hz for 300 ms
  [11606.578 ms] Speaker: 800 Hz for 80 ms
  [11716.628 ms] Speaker: 800 Hz for 80 ms
  [11720.468 ms] Display fill at (0, 40), 320 by 30: 0xe00000
  [11721.688 ms] Display at (9, 43): FALSE START
  [11724.248 ms] Display fill at (0, 70), 320 by 20: 0xe00000
  [11725.648 ms] Display at (6, 72): Warning: under 0.1 s
  [11767.760 ms] Display at (48, 200): Start
  [11771.512 ms] Display at (212, 200): Reset
  [15045.152 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [15046.412 ms] Display at (9, 43): ON YOUR MARKS
  [15048.972 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [15050.252 ms] Display at (6, 72): Settle for 1 s
  [15054.064 ms] Display at (30, 200): Stand up
  [15057.716 ms] Display at (242, 200):
  [16285.736 ms] Display fill at (0, 40), 320 by 30: 0xffd000
  [16286.796 ms] Display at (9, 43): SET
  [16289.356 ms] Display fill at (0, 70), 320 by 20: 0xffd000
  [16290.556 ms] Display at (6, 72): Hold still
  [16290.606 ms] Speaker: 1500 Hz for 80 ms
  [17106.776 ms] Speaker: 800 Hz for 80 ms
  [17216.826 ms] Speaker: 800 Hz for 80 ms
  [17220.666 ms] Display fill at (0, 40), 320 by 30: 0xe00000
  [17221.906 ms] Display at (9, 43): DISQUALIFIED
  [17224.466 ms] Display fill at (0, 70), 320 by 20: 0xe00000
  [17225.706 ms] Display at (6, 72): Moved in Set
  [17267.818 ms] Display at (48, 200): Start
  [17271.570 ms] Display at (212, 200): Reset
  [22054.210 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [22055.470 ms] Display at (9, 43): ON YOUR MARKS
  [22058.030 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [22059.310 ms] Display at (6, 72): Settle for 1 s
  [22063.122 ms] Display at (30, 200): Stand up
  [22066.774 ms] Display at (242, 200):
  [23294.794 ms] Display fill at (0, 40), 320 by 30: 0xffd000
  [23295.854 ms] Display at (9, 43): SET
  [23298.414 ms] Display fill at (0, 70), 320 by 20: 0xffd000
  [23299.614 ms] Display at (6, 72): Hold still
  [23299.664 ms] Speaker: 1500 Hz for 80 ms
  [25095.178 ms] Speaker: 2500 Hz for 300 ms
  [25719.618 ms] Display fill at (0, 40), 320 by 30: 0xff8000
  [25720.778 ms] Display at (9, 43): NO START
  [25723.338 ms] Display fill at (0, 70), 320 by 20: 0xff8000
  [25724.578 ms] Display at (6, 72): No push seen
  [25766.690 ms] Display at (48, 200): Start
  [25770.442 ms] Display at (212, 200): Reset
  [29044.082 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [29045.342 ms] Display at (9, 43): ON YOUR MARKS
  [29047.902 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [29049.182 ms] Display at (6, 72): Settle for 1 s
  [29052.994 ms] Display at (30, 200): Stand up
  [29056.646 ms] Display at (242, 200):
  [30284.666 ms] Display fill at (0, 40), 320 by 30: 0xffd000
  [30285.726 ms] Display at (9, 43): SET
  [30288.286 ms] Display fill at (0, 70), 320 by 20: 0xffd000
  [30289.486 ms] Display at (6, 72): Hold still
  [30289.536 ms] Speaker: 1500 Hz for 80 ms
  [31313.526 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [31314.686 ms] Display at (9, 43): STAND UP
  [31317.246 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [31318.546 ms] Display at (6, 72): Start abandoned
  [31360.658 ms] Display at (48, 200): Start
  [31364.410 ms] Display at (212, 200): Reset
  [36042.660 ms] Speaker: 3000 Hz for 50 ms
  [36046.500 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [36047.600 ms] Display at (9, 43): READY
  [36050.160 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [36051.420 ms] Display at (6, 72): Tally cleared
  [36093.452 ms] Display at (48, 200): Start
  [36097.204 ms] Display at (212, 200): Reset
  [43042.744 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [43044.004 ms] Display at (9, 43): ON YOUR MARKS
  [43046.564 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [43047.844 ms] Display at (6, 72): Settle for 1 s
  [43051.656 ms] Display at (30, 200): Stand up
  [43055.308 ms] Display at (242, 200):
  [44283.328 ms] Display fill at (0, 40), 320 by 30: 0xff8000
  [44284.508 ms] Display at (9, 43): NOT STILL
  [44287.068 ms] Display fill at (0, 70), 320 by 20: 0xff8000
  [44288.468 ms] Display at (6, 72): Settle and tap Start
  [44330.500 ms] Display at (48, 200): Start
  [44334.252 ms] Display at (212, 200): Reset
  [50000.000 ms] End of the simulation

The gun is fired 1500 to 3000 ms after the Set command, at times drawn from
the clock, and the tally after the starts, before the Reset, reads one legal
start, one warning, one disqualification and one start without a push, each
row written from left to right, each label before its value:

  $ grep 'Speaker: \(1500\|2500\)' run.log | awk '{ t = substr($1, 2) + 0; if ($4 == "1500") set = t; else print int(t - set), (t - set >= 1500 && t - set <= 3000) }'
  1938 1
  2264 1
  1795 1
  $ grep 'Display at ([0-9]*, \(102\|124\|146\|168\))' run.log | sed -n '71,84p'
  [31322.206 ms] Display at (0, 102): Legal
  [31325.018 ms] Display at (96, 102): 1
  [31327.458 ms] Display at (160, 102): Warnings
  [31328.798 ms] Display at (280, 102): 1
  [31332.398 ms] Display at (0, 124): DQ
  [31335.210 ms] Display at (96, 124): 1
  [31337.670 ms] Display at (160, 124): No starts
  [31339.010 ms] Display at (280, 124): 1
  [31342.710 ms] Display at (0, 146): Best, s
  [31345.602 ms] Display at (96, 146): 0.161
  [31349.242 ms] Display at (0, 168): Lane
  [31352.342 ms] Display at (60, 168): 1
  [31355.374 ms] Display at (96, 168): False starts
  [31356.906 ms] Display at (256, 168): 2
