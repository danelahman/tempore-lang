The sprint starter of examples/arduino/starter on the M5Stack CoreS3 Lite,
with the packages m5-imu, m5-display, m5-touch and m5-speaker, under the
regular expressions of timed operations: its runs by the interpreter, its
rejected variants, its project and its host simulation, over the starts and
the taps of its host model.

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
after fifty further polls, Set commanded at once after On your marks, and
the gun fired after sixty polls of the hold:

  $ for v in cleared late at_once early; do packages --typecheck-only $app/starter.tpe starter/$v.tpe > $v.log 2>&1; echo "[$?]"; grep -o 'Typing error: Variable `[a-z]*` is unboxed' $v.log; done
  [1]
  Typing error: Variable `armed` is unboxed
  [1]
  Typing error: Variable `gun` is unboxed
  [1]
  Typing error: Variable `mark` is unboxed
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
800 Hz and the tone of Reset of 3000 Hz:

  $ tempore --emit-arduino starter --device $app/starter.device.json --host-simulate 50 $app/starter.tpe > run.log
  $ grep 'Display at (0, \(44\|76\))\|Display at (160, 76)\|Speaker\|simulation' run.log | sed 's/ *$//'
  [77.134 ms] Display at (0, 44): READY
  [80.874 ms] Display at (0, 76): Tap Start
  [1011.254 ms] Display at (0, 44): ON YOUR MARKS
  [1014.814 ms] Display at (0, 76):
  [2247.706 ms] Display at (0, 44): SET
  [2247.756 ms] Speaker: 1500 Hz for 80 ms
  [4553.345 ms] Speaker: 2500 Hz for 300 ms
  [4719.761 ms] Display at (0, 44): LEGAL START
  [4723.541 ms] Display at (0, 76): Reaction, s
  [4725.921 ms] Display at (160, 76): 0.161
  [8020.401 ms] Display at (0, 44): ON YOUR MARKS
  [8023.961 ms] Display at (0, 76):
  [9256.853 ms] Display at (0, 44): SET
  [9256.903 ms] Speaker: 1500 Hz for 80 ms
  [11827.731 ms] Speaker: 2500 Hz for 300 ms
  [11889.841 ms] Speaker: 800 Hz for 80 ms
  [11999.891 ms] Speaker: 800 Hz for 80 ms
  [12004.951 ms] Display at (0, 44): FALSE START
  [12008.911 ms] Display at (0, 76): Warning: under 0.1 s
  [15051.891 ms] Display at (0, 44): ON YOUR MARKS
  [15055.451 ms] Display at (0, 76):
  [16288.343 ms] Display at (0, 44): SET
  [16288.393 ms] Speaker: 1500 Hz for 80 ms
  [17104.563 ms] Speaker: 800 Hz for 80 ms
  [17214.613 ms] Speaker: 800 Hz for 80 ms
  [17219.693 ms] Display at (0, 44): DISQUALIFIED
  [17223.493 ms] Display at (0, 76): Moved in Set
  [22026.973 ms] Display at (0, 44): ON YOUR MARKS
  [22030.533 ms] Display at (0, 76):
  [23263.425 ms] Display at (0, 44): SET
  [23263.475 ms] Speaker: 1500 Hz for 80 ms
  [25487.452 ms] Speaker: 2500 Hz for 300 ms
  [26113.052 ms] Display at (0, 44): NO START
  [26116.972 ms] Display at (0, 76): No push within 1 s
  [29009.052 ms] Display at (0, 44): ON YOUR MARKS
  [29012.612 ms] Display at (0, 76):
  [30245.504 ms] Display at (0, 44): SET
  [30245.554 ms] Speaker: 1500 Hz for 80 ms
  [31270.704 ms] Display at (0, 44): STAND UP
  [31274.564 ms] Display at (0, 76): Start abandoned
  [36022.694 ms] Speaker: 3000 Hz for 50 ms
  [36027.634 ms] Display at (0, 44): READY
  [36031.454 ms] Display at (0, 76): Tally cleared
  [43048.134 ms] Display at (0, 44): ON YOUR MARKS
  [43051.694 ms] Display at (0, 76):
  [44284.706 ms] Display at (0, 44): NOT STILL
  [44288.666 ms] Display at (0, 76): Settle and tap Start
  [50000.000 ms] End of the simulation

The gun is fired 1500 to 3000 ms after the Set command, at times drawn from
the clock, and the tally after the starts, before the Reset, reads one legal
start, one warning, one disqualification and one start without a push:

  $ grep 'Speaker: \(1500\|2500\)' run.log | awk '{ t = substr($1, 2) + 0; if ($4 == "1500") set = t; else print int(t - set), (t - set >= 1500 && t - set <= 3000) }'
  2305 1
  2570 1
  2223 1
  $ grep 'Display at (\(96\|280\), \(106\|128\))' run.log | sed -n '21,24p'
  [31277.376 ms] Display at (96, 106): 1
  [31278.716 ms] Display at (280, 106): 1
  [31281.528 ms] Display at (96, 128): 1
  [31282.868 ms] Display at (280, 128): 1
