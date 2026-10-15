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
  [46.038 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [47.138 ms] Display at (9, 43): READY
  [49.698 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [50.878 ms] Display at (6, 72): Tap Start
  [92.910 ms] Display at (48, 200): Start
  [96.662 ms] Display at (212, 200): Reset
  [1006.202 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [1007.462 ms] Display at (9, 43): ON YOUR MARKS
  [1010.022 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [1011.302 ms] Display at (6, 72): Settle for 1 s
  [1015.114 ms] Display at (30, 200): Stand up
  [1018.766 ms] Display at (242, 200):
  [2246.786 ms] Display fill at (0, 40), 320 by 30: 0xffd000
  [2247.846 ms] Display at (9, 43): SET
  [2250.406 ms] Display fill at (0, 70), 320 by 20: 0xffd000
  [2251.606 ms] Display at (6, 72): Hold still
  [2251.656 ms] Speaker: 1500 Hz for 80 ms
  [4006.364 ms] Speaker: 2500 Hz for 300 ms
  [4171.560 ms] Display fill at (0, 40), 320 by 30: 0x00c000
  [4172.780 ms] Display at (9, 43): LEGAL START
  [4175.340 ms] Display fill at (0, 70), 320 by 20: 0x00c000
  [4176.560 ms] Display at (6, 72): Reaction, s
  [4177.840 ms] Display fill at (160, 70), 160 by 20: 0x00c000
  [4178.940 ms] Display at (166, 72): 0.161
  [4221.052 ms] Display at (48, 200): Start
  [4224.804 ms] Display at (212, 200): Reset
  [8051.744 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [8053.004 ms] Display at (9, 43): ON YOUR MARKS
  [8055.564 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [8056.844 ms] Display at (6, 72): Settle for 1 s
  [8060.656 ms] Display at (30, 200): Stand up
  [8064.308 ms] Display at (242, 200):
  [9292.328 ms] Display fill at (0, 40), 320 by 30: 0xffd000
  [9293.388 ms] Display at (9, 43): SET
  [9295.948 ms] Display fill at (0, 70), 320 by 20: 0xffd000
  [9297.148 ms] Display at (6, 72): Hold still
  [9297.198 ms] Speaker: 1500 Hz for 80 ms
  [10929.488 ms] Speaker: 2500 Hz for 300 ms
  [10991.598 ms] Speaker: 800 Hz for 80 ms
  [11101.648 ms] Speaker: 800 Hz for 80 ms
  [11105.488 ms] Display fill at (0, 40), 320 by 30: 0xe00000
  [11106.708 ms] Display at (9, 43): FALSE START
  [11109.268 ms] Display fill at (0, 70), 320 by 20: 0xe00000
  [11110.668 ms] Display at (6, 72): Warning: under 0.1 s
  [11152.780 ms] Display at (48, 200): Start
  [11156.532 ms] Display at (212, 200): Reset
  [15033.772 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [15035.032 ms] Display at (9, 43): ON YOUR MARKS
  [15037.592 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [15038.872 ms] Display at (6, 72): Settle for 1 s
  [15042.684 ms] Display at (30, 200): Stand up
  [15046.336 ms] Display at (242, 200):
  [16274.356 ms] Display fill at (0, 40), 320 by 30: 0xffd000
  [16275.416 ms] Display at (9, 43): SET
  [16277.976 ms] Display fill at (0, 70), 320 by 20: 0xffd000
  [16279.176 ms] Display at (6, 72): Hold still
  [16279.226 ms] Speaker: 1500 Hz for 80 ms
  [17095.396 ms] Speaker: 800 Hz for 80 ms
  [17205.446 ms] Speaker: 800 Hz for 80 ms
  [17209.286 ms] Display fill at (0, 40), 320 by 30: 0xe00000
  [17210.526 ms] Display at (9, 43): DISQUALIFIED
  [17213.086 ms] Display fill at (0, 70), 320 by 20: 0xe00000
  [17214.326 ms] Display at (6, 72): Moved in Set
  [17256.438 ms] Display at (48, 200): Start
  [17260.190 ms] Display at (212, 200): Reset
  [22042.830 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [22044.090 ms] Display at (9, 43): ON YOUR MARKS
  [22046.650 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [22047.930 ms] Display at (6, 72): Settle for 1 s
  [22051.742 ms] Display at (30, 200): Stand up
  [22055.394 ms] Display at (242, 200):
  [23283.414 ms] Display fill at (0, 40), 320 by 30: 0xffd000
  [23284.474 ms] Display at (9, 43): SET
  [23287.034 ms] Display fill at (0, 70), 320 by 20: 0xffd000
  [23288.234 ms] Display at (6, 72): Hold still
  [23288.284 ms] Speaker: 1500 Hz for 80 ms
  [24940.977 ms] Speaker: 2500 Hz for 300 ms
  [25255.117 ms] Display fill at (0, 40), 320 by 30: 0xff8000
  [25256.277 ms] Display at (9, 43): NO START
  [25258.837 ms] Display fill at (0, 70), 320 by 20: 0xff8000
  [25260.077 ms] Display at (6, 72): No push seen
  [25302.189 ms] Display at (48, 200): Start
  [25305.941 ms] Display at (212, 200): Reset
  [29032.281 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [29033.541 ms] Display at (9, 43): ON YOUR MARKS
  [29036.101 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [29037.381 ms] Display at (6, 72): Settle for 1 s
  [29041.193 ms] Display at (30, 200): Stand up
  [29044.845 ms] Display at (242, 200):
  [30272.865 ms] Display fill at (0, 40), 320 by 30: 0xffd000
  [30273.925 ms] Display at (9, 43): SET
  [30276.485 ms] Display fill at (0, 70), 320 by 20: 0xffd000
  [30277.685 ms] Display at (6, 72): Hold still
  [30277.735 ms] Speaker: 1500 Hz for 80 ms
  [31301.725 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [31302.885 ms] Display at (9, 43): STAND UP
  [31305.445 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [31306.745 ms] Display at (6, 72): Start abandoned
  [31348.857 ms] Display at (48, 200): Start
  [31352.609 ms] Display at (212, 200): Reset
  [36030.859 ms] Speaker: 3000 Hz for 50 ms
  [36034.699 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [36035.799 ms] Display at (9, 43): READY
  [36038.359 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [36039.619 ms] Display at (6, 72): Tally cleared
  [36081.651 ms] Display at (48, 200): Start
  [36085.403 ms] Display at (212, 200): Reset
  [43030.943 ms] Display fill at (0, 40), 320 by 30: 0xffffff
  [43032.203 ms] Display at (9, 43): ON YOUR MARKS
  [43034.763 ms] Display fill at (0, 70), 320 by 20: 0xffffff
  [43036.043 ms] Display at (6, 72): Settle for 1 s
  [43039.855 ms] Display at (30, 200): Stand up
  [43043.507 ms] Display at (242, 200):
  [44271.527 ms] Display fill at (0, 40), 320 by 30: 0xff8000
  [44272.707 ms] Display at (9, 43): NOT STILL
  [44275.267 ms] Display fill at (0, 70), 320 by 20: 0xff8000
  [44276.667 ms] Display at (6, 72): Settle and tap Start
  [44318.699 ms] Display at (48, 200): Start
  [44322.451 ms] Display at (212, 200): Reset
  [50000.000 ms] End of the simulation

The gun is fired 1500 to 3000 ms after the Set command, at times drawn from
the clock, and the tally after the starts, before the Reset, reads one legal
start, one warning, one disqualification and one start without a push, each
row written from left to right, each label before its value:

  $ grep 'Speaker: \(1500\|2500\)' run.log | awk '{ t = substr($1, 2) + 0; if ($4 == "1500") set = t; else print int(t - set), (t - set >= 1500 && t - set <= 3000) }'
  1754 1
  1632 1
  1652 1
  $ grep 'Display at ([0-9]*, \(102\|124\|146\|168\))' run.log | sed -n '71,84p'
  [31310.405 ms] Display at (0, 102): Legal
  [31313.217 ms] Display at (96, 102): 1
  [31315.657 ms] Display at (160, 102): Warnings
  [31316.997 ms] Display at (280, 102): 1
  [31320.597 ms] Display at (0, 124): DQ
  [31323.409 ms] Display at (96, 124): 1
  [31325.869 ms] Display at (160, 124): No starts
  [31327.209 ms] Display at (280, 124): 1
  [31330.909 ms] Display at (0, 146): Best, s
  [31333.801 ms] Display at (96, 146): 0.161
  [31337.441 ms] Display at (0, 168): Lane
  [31340.541 ms] Display at (60, 168): 1
  [31343.573 ms] Display at (96, 168): False starts
  [31345.105 ms] Display at (256, 168): 2
