The sprint starter of examples/arduino/starter on the M5Stack CoreS3 Lite,
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
cleared between the gun and the reading of its time, the athlete judged
after fifty further polls, Set commanded at once after On your marks, the
gun fired after sixty polls of the hold, and the unit reconfigured on a tap
on Reset:

  $ for v in cleared late at_once early; do packages --typecheck-only $app/starter.tpe starter/$v.tpe > $v.log 2>&1; echo "[$?]"; grep -o 'Typing error: Variable `[a-z]*` is unboxed' $v.log; done
  [1]
  Typing error: Variable `gun` is unboxed
  [1]
  Typing error: Variable `gun` is unboxed
  [1]
  Typing error: Variable `mark` is unboxed
  [1]
  Typing error: Variable `set` is unboxed
  $ packages --typecheck-only $app/starter.tpe starter/reconfigured.tpe 2>&1 | grep -o "Typing error: This function's body has grade"
  Typing error: This function's body has grade

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
  [45.998 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [47.098 ms] Display at (9, 43): READY
  [49.658 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [50.838 ms] Display at (6, 72): Tap Start
  [92.870 ms] Display at (48, 200): Start
  [96.622 ms] Display at (212, 200): Reset
  [1006.162 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [1007.422 ms] Display at (9, 43): ON YOUR MARKS
  [1009.982 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [1011.262 ms] Display at (6, 72): Settle for 1 s
  [1015.074 ms] Display at (30, 200): Stand up
  [1018.726 ms] Display at (242, 200):
  [2246.746 ms] Display fill at (0, 40), 320 by 30: 0xffd000
  [2247.806 ms] Display at (9, 43): SET
  [2250.366 ms] Display fill at (0, 70), 320 by 20: 0xffd000
  [2251.566 ms] Display at (6, 72): Hold still
  [2251.616 ms] Speaker: 1500 Hz for 80 ms
  [4230.757 ms] Speaker: 2500 Hz for 300 ms
  [4395.953 ms] Display fill at (0, 40), 320 by 30: 0x00c000
  [4397.173 ms] Display at (9, 43): LEGAL START
  [4399.733 ms] Display fill at (0, 70), 320 by 20: 0x00c000
  [4400.953 ms] Display at (6, 72): Reaction, s
  [4402.233 ms] Display fill at (160, 70), 160 by 20: 0x00c000
  [4403.333 ms] Display at (166, 72): 0.161
  [4445.445 ms] Display at (48, 200): Start
  [4449.197 ms] Display at (212, 200): Reset
  [8024.637 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [8025.897 ms] Display at (9, 43): ON YOUR MARKS
  [8028.457 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [8029.737 ms] Display at (6, 72): Settle for 1 s
  [8033.549 ms] Display at (30, 200): Stand up
  [8037.201 ms] Display at (242, 200):
  [9265.221 ms] Display fill at (0, 40), 320 by 30: 0xffd000
  [9266.281 ms] Display at (9, 43): SET
  [9268.841 ms] Display fill at (0, 70), 320 by 20: 0xffd000
  [9270.041 ms] Display at (6, 72): Hold still
  [9270.091 ms] Speaker: 1500 Hz for 80 ms
  [11412.456 ms] Speaker: 2500 Hz for 300 ms
  [11474.566 ms] Speaker: 800 Hz for 80 ms
  [11584.616 ms] Speaker: 800 Hz for 80 ms
  [11588.456 ms] Display fill at (0, 40), 320 by 30: 0xe00000
  [11589.676 ms] Display at (9, 43): FALSE START
  [11592.236 ms] Display fill at (0, 70), 320 by 20: 0xe00000
  [11593.636 ms] Display at (6, 72): Warning: under 0.1 s
  [11635.748 ms] Display at (48, 200): Start
  [11639.500 ms] Display at (212, 200): Reset
  [15013.740 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [15015.000 ms] Display at (9, 43): ON YOUR MARKS
  [15017.560 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [15018.840 ms] Display at (6, 72): Settle for 1 s
  [15022.652 ms] Display at (30, 200): Stand up
  [15026.304 ms] Display at (242, 200):
  [16254.324 ms] Display fill at (0, 40), 320 by 30: 0xffd000
  [16255.384 ms] Display at (9, 43): SET
  [16257.944 ms] Display fill at (0, 70), 320 by 20: 0xffd000
  [16259.144 ms] Display at (6, 72): Hold still
  [16259.194 ms] Speaker: 1500 Hz for 80 ms
  [17075.364 ms] Speaker: 800 Hz for 80 ms
  [17185.414 ms] Speaker: 800 Hz for 80 ms
  [17189.254 ms] Display fill at (0, 40), 320 by 30: 0xe00000
  [17190.494 ms] Display at (9, 43): DISQUALIFIED
  [17193.054 ms] Display fill at (0, 70), 320 by 20: 0xe00000
  [17194.294 ms] Display at (6, 72): Moved in Set
  [17236.406 ms] Display at (48, 200): Start
  [17240.158 ms] Display at (212, 200): Reset
  [22022.798 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [22024.058 ms] Display at (9, 43): ON YOUR MARKS
  [22026.618 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [22027.898 ms] Display at (6, 72): Settle for 1 s
  [22031.710 ms] Display at (30, 200): Stand up
  [22035.362 ms] Display at (242, 200):
  [23263.382 ms] Display fill at (0, 40), 320 by 30: 0xffd000
  [23264.442 ms] Display at (9, 43): SET
  [23267.002 ms] Display fill at (0, 70), 320 by 20: 0xffd000
  [23268.202 ms] Display at (6, 72): Hold still
  [23268.252 ms] Speaker: 1500 Hz for 80 ms
  [25145.378 ms] Speaker: 2500 Hz for 300 ms
  [25769.818 ms] Display fill at (0, 40), 320 by 30: 0xff8000
  [25770.978 ms] Display at (9, 43): NO START
  [25773.538 ms] Display fill at (0, 70), 320 by 20: 0xff8000
  [25774.898 ms] Display at (6, 72): No push within 1 s
  [25817.010 ms] Display at (48, 200): Start
  [25820.762 ms] Display at (212, 200): Reset
  [29044.102 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [29045.362 ms] Display at (9, 43): ON YOUR MARKS
  [29047.922 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [29049.202 ms] Display at (6, 72): Settle for 1 s
  [29053.014 ms] Display at (30, 200): Stand up
  [29056.666 ms] Display at (242, 200):
  [30284.686 ms] Display fill at (0, 40), 320 by 30: 0xffd000
  [30285.746 ms] Display at (9, 43): SET
  [30288.306 ms] Display fill at (0, 70), 320 by 20: 0xffd000
  [30289.506 ms] Display at (6, 72): Hold still
  [30289.556 ms] Speaker: 1500 Hz for 80 ms
  [31313.546 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [31314.706 ms] Display at (9, 43): STAND UP
  [31317.266 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [31318.566 ms] Display at (6, 72): Start abandoned
  [31360.678 ms] Display at (48, 200): Start
  [31364.430 ms] Display at (212, 200): Reset
  [36042.680 ms] Speaker: 3000 Hz for 50 ms
  [36046.520 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [36047.620 ms] Display at (9, 43): READY
  [36050.180 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [36051.440 ms] Display at (6, 72): Tally cleared
  [36093.472 ms] Display at (48, 200): Start
  [36097.224 ms] Display at (212, 200): Reset
  [43042.764 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [43044.024 ms] Display at (9, 43): ON YOUR MARKS
  [43046.584 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [43047.864 ms] Display at (6, 72): Settle for 1 s
  [43051.676 ms] Display at (30, 200): Stand up
  [43055.328 ms] Display at (242, 200):
  [44283.348 ms] Display fill at (0, 40), 320 by 30: 0xff8000
  [44284.528 ms] Display at (9, 43): NOT STILL
  [44287.088 ms] Display fill at (0, 70), 320 by 20: 0xff8000
  [44288.488 ms] Display at (6, 72): Settle and tap Start
  [44330.520 ms] Display at (48, 200): Start
  [44334.272 ms] Display at (212, 200): Reset
  [50000.000 ms] End of the simulation

The gun is fired 1500 to 3000 ms after the Set command, at times drawn from
the clock, and the tally after the starts, before the Reset, reads one legal
start, one warning, one disqualification and one start without a push, each
row written from left to right, each label before its value:

  $ grep 'Speaker: \(1500\|2500\)' run.log | awk '{ t = substr($1, 2) + 0; if ($4 == "1500") set = t; else print int(t - set), (t - set >= 1500 && t - set <= 3000) }'
  1979 1
  2142 1
  1877 1
  $ grep 'Display at ([0-9]*, \(102\|124\|146\|168\))' run.log | sed -n '71,84p'
  [31322.226 ms] Display at (0, 102): Legal
  [31325.038 ms] Display at (96, 102): 1
  [31327.478 ms] Display at (160, 102): Warnings
  [31328.818 ms] Display at (280, 102): 1
  [31332.418 ms] Display at (0, 124): DQ
  [31335.230 ms] Display at (96, 124): 1
  [31337.690 ms] Display at (160, 124): No starts
  [31339.030 ms] Display at (280, 124): 1
  [31342.730 ms] Display at (0, 146): Best, s
  [31345.622 ms] Display at (96, 146): 0.161
  [31349.262 ms] Display at (0, 168): Lane
  [31352.362 ms] Display at (60, 168): 1
  [31355.394 ms] Display at (96, 168): False starts
  [31356.926 ms] Display at (256, 168): 2
