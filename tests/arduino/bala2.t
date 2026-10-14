The BALA2 application of examples/arduino/bala2: the balancing robot with the
packages m5-imu, m5-display and bala2-base, its rejected variants, and its
closed loop with the host model of the robot.

  $ app=../../examples/arduino/bala2
  $ . ../helpers.sh
  $ from_header $app/balance.tpe

The interpreter, with the declarations of the packages under their
running-time bounds on the M5Stack Gray, the board of the manifest, as for
the rejected variants below, runs two control steps with the default
implementations of the operations:

  $ packages $app/balance.tpe
  === Run 1 ===
  return (2.8812, 0., 0., 0., 0.)
  State: [
    [0.6, 0.6],
    { resource_0 ↦ ((0., 0., 1.), (0., 0., 0.)) # [0, 2] },
    [0.5, 0.5],
    [0.01, 0.01],
    [0.01, 0.01],
    [0.2, 0.2],
    [0.6, 0.6],
    { resource_1 ↦ ((0., 0., 1.), (0., 0., 0.)) # [0, 2] },
    [0.5, 0.5],
    [0.01, 0.01],
    [0.01, 0.01],
    [0.2, 0.2]
  ]
  

The rejected variants, each loaded after the application: a stale reading of
the unit, arming before the robot is held upright, and a supervisory
iteration that may exceed the 200 ms of a command:

  $ for v in stale hasty redrawn; do packages --typecheck-only $app/balance.tpe bala2/$v.tpe; echo "[$?]"; done
  File "bala2/stale.tpe", lines 14-21, characters 2-58:
  14 |   unbox fresh as imu in
         ^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `fresh` is unboxed with grade `[2.4, 3.55]` accumulated since it was bound, which is not below its box grade `[0, 2]`
    File "bala2/stale.tpe", line 7, characters 24-29:
    7 |   box [0, 2] reading as fresh in
                                ^^^^^
    `fresh` is bound here
    File "bala2/stale.tpe", line 8, characters 22-45:
    8 |   let left1, right1 = perform ReadEncoders () in
                              ^^^^^^^^^^^^^^^^^^^^^^^
    grade `[0.45, 1]` accumulates here (operation `ReadEncoders`)
    File "bala2/stale.tpe", line 9, characters 2-11:
    9 |   delay 1.5;
          ^^^^^^^^^
    grade `[1.5, 1.5]` accumulates here (delay)
    File "bala2/stale.tpe", line 10, characters 22-45:
    10 |   let left2, right2 = perform ReadEncoders () in
                               ^^^^^^^^^^^^^^^^^^^^^^^
    grade `[0.45, 1]` accumulates here (operation `ReadEncoders`)
    File "bala2/stale.tpe", line 13, characters 34-54:
    13 |   let armed, bias, target, turn = perform Setpoints () in
                                           ^^^^^^^^^^^^^^^^^^^^
    grade `[0, 0.05]` accumulates here (operation `Setpoints`)
    Note: the resource inequality `[2.4, 3.55] <= [0, 2]` does not hold
  [1]
  File "bala2/hasty.tpe", lines 8-10, characters 2-18:
  8 |   unbox token as calibration in
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `token` is unboxed with grade `[100.05, 112.5]` accumulated since it was bound, which is not below its box grade `[1000, ∞)`
    File "bala2/hasty.tpe", line 5, characters 6-11:
    5 |   let token = calibrate () in
              ^^^^^
    `token` is bound here
    File "bala2/hasty.tpe", line 6, characters 2-33:
    6 |   perform ShowText "Hold upright";
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[0.05, 12.5]` accumulates here (operation `ShowText`)
    File "bala2/hasty.tpe", line 7, characters 2-11:
    7 |   delay 100;
          ^^^^^^^^^
    grade `[100, 100]` accumulates here (delay)
    File "bala2/hasty.tpe", line 5, characters 14-23:
    5 |   let token = calibrate () in
                      ^^^^^^^^^
    the inequality goes through the type of `calibrate` here
    Note: the resource inequality `[100.05, 112.5] <= [1000, ∞)` does not hold
  [1]
  File "bala2/redrawn.tpe", lines 4-10, characters 33-11:
  4 | let drive_step_redrawn (n : nat) : unit # [0, 200) =
                                       ^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `[181.1, 223.1]`, which does not match its annotated grade `[0, 200)`
    Note: the effect inequality `[181.1, 223.1] <= [0, 200)` does not hold
  [1]

The PlatformIO project for the M5Stack Gray, its C++ sources checked without
exceptions and run-time type information, and its host build:

  $ tempore --emit-arduino balance --device $app/balance.device.json $app/balance.tpe | grep -c Wrote
  33
  $ cd _arduino/projects/balance
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ build () { c++ -std=c++17 -Wall -Wextra -Werror -ffp-contract=off -DTEMPORE_HOST -DTEMPORE_TRACE "$@" -pthread -I host -I src src/*.cpp host/*.cpp -o simulation; }
  $ events () { ./simulation "$1" | grep -v '\] \(Release\|Start\|End step\|Operation\|IMU\|I2C\|Delay\)'; }
  $ cd ../../..

The closed loop for 8 s from a tilt of 0.1 rad, the robot held until its
motors are first driven: the supervision calibrates the gyroscope, arms the
robot after a second and shows the tilt every second; the tilt stays below
2.5 degrees from one second after the release. The digits of the simulated
tilt depend on the rounding of the single-precision functions of the C
library, so that the filter balanced checks the tilts, the position of the
wheels and the largest drive against bounds, and prints the other events as
they are:

  $ balanced () {
  >   awk '
  >     function within(x, b) { return (x < 0 ? -x : x) < b }
  >     function check(ok, text) { print (ok ? text : $0) }
  >     / Display: -?[0-9]+\.[0-9]+$/ {
  >       check(within($NF, 2.5), $1 " " $2 " Display: a tilt below 2.5 degrees"); next
  >     }
  >     / Plant: tilt / {
  >       check(within($5, 2.5) && within($9, 0.2),
  >         $1 " " $2 " Plant: tilt below 2.5 degrees, wheels within 0.2 m"); next
  >     }
  >     / Plant: largest tilt / {
  >       check(within($(NF - 1), 2.5),
  >         $1 " " $2 " Plant: largest tilt from 1 s after the release below 2.5 degrees"); next
  >     }
  >     / Plant: largest drive / {
  >       d = $6; sub(/,$/, "", d)
  >       check(within(d, 0.4), $1 " " $2 " Plant: largest drive below 0.4, " $7 " " $8 " " $9 " " $10); next
  >     }
  >     { print }'
  > }

  $ tempore --emit-arduino balance --device $app/balance.device.json --host-simulate 8 $app/balance.tpe | grep -v '^Wrote\|\] \(Release\|Start\|End step\|Operation\|IMU\|I2C\|Delay\)' | balanced
  [31.245 ms] Display cleared
  [35.105 ms] Display at (0, 0): Balancing robot
  [37.865 ms] Display at (80, 230): Typechecked by Tempore (tempore-lang.ee)
  [38.865 ms] Display: Calibrating
  [539.865 ms] Display: Hold upright
  [1540.865 ms] Display: Armed
  [2441.865 ms] Display: a tilt below 2.5 degrees
  [3442.865 ms] Display: a tilt below 2.5 degrees
  [4443.865 ms] Display: a tilt below 2.5 degrees
  [5444.865 ms] Display: a tilt below 2.5 degrees
  [6445.865 ms] Display: a tilt below 2.5 degrees
  [7446.865 ms] Display: a tilt below 2.5 degrees
  [8000.000 ms] End of the simulation
  [8000.000 ms] Plant: released at 1542.0 ms
  [8000.000 ms] Plant: tilt below 2.5 degrees, wheels within 0.2 m
  [8000.000 ms] Plant: largest tilt from 1 s after the release below 2.5 degrees
  [8000.000 ms] Plant: largest drive below 0.4, last at 8000.0 ms

From a tilt of 1.3 rad (74.5 degrees), beyond the cutoff of 70 degrees, the
step never drives the motors, and the robot falls when released at 2 s:

  $ cd _arduino/projects/balance
  $ build -DPLANT_TILT=1.3 && events 8000000
  [31.245 ms] Display cleared
  [35.105 ms] Display at (0, 0): Balancing robot
  [37.865 ms] Display at (80, 230): Typechecked by Tempore (tempore-lang.ee)
  [38.865 ms] Display: Calibrating
  [539.865 ms] Display: Hold upright
  [1540.865 ms] Display: Armed
  [2441.865 ms] Display: 80.124
  [3442.865 ms] Display: 80.212
  [4443.865 ms] Display: 80.214
  [5444.865 ms] Display: 80.214
  [6445.865 ms] Display: 80.214
  [7446.865 ms] Display: 80.214
  [8000.000 ms] End of the simulation
  [8000.000 ms] Plant: released at 2000.0 ms
  [8000.000 ms] Plant: tilt 80.21 degrees, wheels at -0.495 m
  [8000.000 ms] Plant: largest tilt from 1 s after the release 80.21 degrees
  [8000.000 ms] Plant: the motors were never driven

A binding made slow from 4 s on, Publish taking 3 ms beyond its bound of
0.05 ms: its monitor enters the safe state, which stops the motors, and then
draws a red banner across the middle of the screen that states the violation;
the robot falls:

  $ build -DBALANCE_SLOW_FROM_MS=4000 && events 8000000
  [31.245 ms] Display cleared
  [35.105 ms] Display at (0, 0): Balancing robot
  [37.865 ms] Display at (80, 230): Typechecked by Tempore (tempore-lang.ee)
  [38.865 ms] Display: Calibrating
  [539.865 ms] Display: Hold upright
  [1540.865 ms] Display: Armed
  [2441.865 ms] Display: -0.044
  [3442.865 ms] Display: 0.084
  [4005.316 ms] Monitor: operation Publish took 3000 us, outside its running-time bounds [0, 50] us
  [4005.316 ms] Safe state entered
  [4017.604 ms] Display fill at (0, 72), 320 by 96: 0xc00000
  [4019.044 ms] Display at (28, 84): Stopped by the monitor
  [4020.384 ms] Display at (58, 112): Publish took 3 ms
  [4021.704 ms] Display at (64, 136): bounds 0-0.05 ms
  [4021.704 ms] Task step stopped
  [4042.000 ms] Task supervise stopped
  [8000.000 ms] End of the simulation
  [8000.000 ms] Plant: released at 1542.0 ms
  [8000.000 ms] Plant: tilt 80.21 degrees, wheels at -0.214 m
  [8000.000 ms] Plant: largest tilt from 1 s after the release 80.21 degrees
  [8000.000 ms] Plant: largest drive 0.316, last at 4005.0 ms

Under the policy warn the monitor logs each violation, and a task of the
lowest priority draws the number of the warnings and the last of them in
yellow above the footer every 500 ms:

  $ cd ../../..
  $ tempore --emit-arduino balance_warn --monitor warn --device $app/balance.device.json $app/balance.tpe > /dev/null
  $ cd _arduino/projects/balance_warn
  $ build -DBALANCE_SLOW_FROM_MS=4000 && ./simulation 6000000 > warn.log
  $ grep -c 'Monitor: operation Publish' warn.log
  399
  $ grep '(0, 218)' warn.log
  [4503.060 ms] Display at (0, 218): Monitor: 99 warnings, last Publish 3 ms
  [5006.080 ms] Display at (0, 218): Monitor: 200 warnings, last Publish 3 ms
  [5509.080 ms] Display at (0, 218): Monitor: 301 warnings, last Publish 3 ms
  $ cd ../balance

With the build flag BALANCE_LOG, here 500 ms, a task started by the first
publication logs the published attitude, the drives last written and the
counts last read, and the arming:

  $ build -DBALANCE_LOG=500 && ./simulation 3000000 | grep '\] \(Armed\|Tilt\)'
  [502.000 ms] Tilt 5.73 deg, rate 0.0 deg/s, drives 0 0, counts 0 0
  [1002.000 ms] Tilt 5.73 deg, rate 0.0 deg/s, drives 0 0, counts 0 0
  [1502.000 ms] Tilt 5.73 deg, rate 0.0 deg/s, drives 0 0, counts 0 0
  [2002.000 ms] Armed, gyroscope bias 0.000 deg/s
  [2002.000 ms] Tilt 0.02 deg, rate -1.7 deg/s, drives 71 181, counts 14 14
  [2502.000 ms] Tilt -0.07 deg, rate 3.3 deg/s, drives -78 -188, counts 12 12

With the build flag BALANCE_RECORD, here 100 ms, and 20 samples, two tasks
started by the first publication record the run from the arming for 2 s and
print the recording, once complete, every 10 s; the filter recordings.awk of
the target -capture extracts it. The recording has its header, the line of
its columns and 20 rows of 9 fields, one every 100 ms; the tilt stays below 5
degrees, the reference tilt within its limit of 20 degrees, and the counts of
the wheels within 500:

  $ build -DBALANCE_RECORD=100 -DBALANCE_RECORD_SAMPLES=20 && ./simulation 15000000 > record.log
  $ grep -c '^# Recording' record.log
  2
  $ awk -f ../../../$app/recordings.awk record.log > record.csv
  $ head -n 2 record.csv
  # Recording 1, run 00000000, 20 of 20 samples every 100 ms from the arming
  time_ms,tilt_deg,rate_deg_s,speed_counts_s,reference_deg,left_drive,right_drive,left_count,right_count
  $ tail -n 1 record.csv
  # End of recording 1
  $ awk -F, '
  >   function within(x, b) { return (x < 0 ? -x : x) < b }
  >   NR > 2 && !/^#/ {
  >     n++
  >     if (NF != 9 || $1 != 100 * (n - 1)) print "row " n ": " $0
  >     if (!within($2, 5) || !within($5, 20.01) || !within($8, 500) || !within($9, 500)) print "row " n ": " $0
  >   }
  >   END { print n " rows" }' record.csv
  20 rows

The filter recordings.awk on a serial output read from the device by the
target -capture, shortened: the bytes read as the port opens, the end of a
copy of recording 1 without its header, a complete copy, and a copy cut
short. Under the locale C, which the target sets, the filter extracts the
complete copy, of 3000 rows, and reports the copy cut short:

  $ capture=../../../bala2/capture.log
  $ extract () { LC_ALL=C awk -f ../../../$app/recordings.awk "$@"; }
  $ extract $capture > capture.csv
  Skipped an incomplete copy of recording 1: no end line
  $ head -n 1 capture.csv; tail -n 2 capture.csv; grep -c '^[0-9]' capture.csv
  # Recording 1, run 505e56f7, 3000 of 3000 samples every 20 ms from the arming
  59980,-1.72,-103.9,118,-2.26,-100,-100,696,-731
  # End of recording 1
  3000

With a carriage return at the end of each line and other bytes before each
header, the filter extracts the same copy; without a row of the complete
copy, it extracts none:

  $ LC_ALL=C awk '{ printf "%s%s\r\n", (/^# Recording/ ? "\001>" : ""), $0 }' $capture | extract 2> /dev/null | cmp - capture.csv
  $ LC_ALL=C awk '!/^30000,/' $capture | extract
  Skipped an incomplete copy of recording 1: 2999 of 3000 rows
  Skipped an incomplete copy of recording 1: no end line

The closed loop over 120 s from the arming, recorded every 100 ms and built
without the trace, checked by the filter settled: given the balance tilt B
and bounds T, R and S, it prints a row of the recording whose tilt is beyond
the cutoff or, from 20 s on, whose tilt is not within T degrees of B, whose
reference tilt is not within R degrees of B, or whose wheels are not within
1000 counts of their start; then the number of rows, and whether from 20 s
on the wheels stay within a span of S counts, and the span of the last 50 s
exceeds that of the 50 s before by less than 10 counts, so that an
oscillation does not grow:

  $ quiet () { c++ -std=c++17 -Wall -Wextra -Werror -ffp-contract=off -DTEMPORE_HOST -DBALANCE_RECORD=100 -DBALANCE_RECORD_SAMPLES=1200 "$@" -pthread -I host -I src src/*.cpp host/*.cpp -o simulation; }
  $ settled () {
  >   awk -F, -v b="$1" -v t="$2" -v r="$3" -v s="$4" '
  >     function within(x, d) { return (x < 0 ? -x : x) < d }
  >     function span(k) { return high[k] - low[k] }
  >     NR > 2 && !/^#/ {
  >       n++
  >       w = ($8 + $9) / 2
  >       if (!within($2, 70)) print "row " n ", beyond the cutoff: " $0
  >       if ($1 < 20000) next
  >       if (!within($2 - b, t) || !within($5 - b, r) || !within(w, 1000))
  >         print "row " n ": " $0
  >       for (k = 0; k < 3; k++) {
  >         if (k == 1 && $1 >= 70000 || k == 2 && $1 < 70000) continue
  >         if (!(k in low) || w < low[k]) low[k] = w
  >         if (!(k in high) || w > high[k]) high[k] = w
  >       }
  >     }
  >     END {
  >       print n " rows; the wheels from 20 s on " (span(0) < s ? "within" : "beyond") " a span of " s " counts, " \
  >         (span(2) < span(1) + 10 ? "not growing" : "growing from " span(1) " to " span(2) " counts")
  >     }' "$5"
  > }
  $ long () { ./simulation 124000000 | awk -f ../../../$app/recordings.awk > "$1"; }

The filter heading, given a bound D, prints whether the difference of the
counts of the left and the right wheel, the heading of the robot, stays
within D counts throughout a recording:

  $ heading () {
  >   awk -F, -v d="$1" '
  >     function within(x, b) { return (x < 0 ? -x : x) < b }
  >     NR > 2 && !/^#/ && !within($8 - $9, d) { n++ }
  >     END { print "the difference of the counts " (n ? "beyond " d " counts in " n " rows" : "within " d " counts") }' "$2"
  > }

On the model, whose dead bands of the motors, 70 and 180, the step
compensates, the robot settles within half a degree and keeps its heading:

  $ quiet && long model.csv
  $ settled 0 0.5 1 20 model.csv
  1200 rows; the wheels from 20 s on within a span of 20 counts, not growing
  $ heading 10 model.csv
  the difference of the counts within 10 counts

Without the dead bands of the motors, which the step then overcompensates,
the robot settles within half a degree:

  $ quiet -DPLANT_DEAD_BAND=0 -DPLANT_RIGHT_DEAD_BAND=0 && long ideal.csv
  $ settled 0 0.5 1 20 ideal.csv
  1200 rows; the wheels from 20 s on within a span of 20 counts, not growing
  $ heading 10 ideal.csv
  the difference of the counts within 10 counts

The centre of mass of the model 0.035 rad (2 degrees) forwards of the axis of
the body, and backwards, under the build flag PLANT_OFFSET of plant.cpp: the
robot balances about a tilt of -2 and 2 degrees, the integral of the speed
loop taking up the offset, with the wheels about 500 counts from their start:

  $ quiet -DPLANT_OFFSET=0.035 && long forwards.csv
  $ settled -2 0.5 1 20 forwards.csv
  1200 rows; the wheels from 20 s on within a span of 20 counts, not growing
  $ heading 10 forwards.csv
  the difference of the counts within 10 counts
  $ quiet -DPLANT_OFFSET=-0.035 && long backwards.csv
  $ settled 2 0.5 1 20 backwards.csv
  1200 rows; the wheels from 20 s on within a span of 20 counts, not growing
  $ heading 10 backwards.csv
  the difference of the counts within 10 counts

With a dead band of the right motor of 240, 60 beyond the compensation of the
step, the robot keeps a limit cycle of about 2.5 degrees, 3.5 degrees of the
reference tilt and 590 counts of the wheels, in which the right wheel lags
the left; the heading loop keeps the difference of the counts within about
20 counts, which reaches about 240 counts without it:

  $ quiet -DPLANT_RIGHT_DEAD_BAND=240 && long weak.csv
  $ settled 0 3 5 700 weak.csv
  1200 rows; the wheels from 20 s on within a span of 700 counts, not growing
  $ heading 40 weak.csv
  the difference of the counts within 40 counts

So also with a right motor of 0.8 times the strength of the left, under the
build flag PLANT_RIGHT_STRENGTH of plant.cpp: the limit cycle is of about 2
degrees, 3 degrees of the reference tilt and 440 counts of the wheels, and
the difference of the counts, which reaches about 190 counts without the
heading loop, stays within about 20 counts:

  $ quiet -DPLANT_RIGHT_STRENGTH=0.8 && long strength.csv
  $ settled 0 3 5 600 strength.csv
  1200 rows; the wheels from 20 s on within a span of 600 counts, not growing
  $ heading 40 strength.csv
  the difference of the counts within 40 counts

The profile of the closed loop over 6 s, built with TEMPORE_PROFILE in place
of TEMPORE_TRACE, at the end of the simulation: each call takes the nominal
time of its binding or device model, and the steps keep their period of 5 ms
from the second on, the first starting late in its tick after the initial
function:

  $ c++ -std=c++17 -Wall -Wextra -Werror -ffp-contract=off -DTEMPORE_HOST -DTEMPORE_PROFILE -pthread -I host -I src src/*.cpp host/*.cpp -o simulation
  $ ./simulation 6000000 | sed -n '/End of the simulation/,$p' | grep -v Plant
  [6000.000 ms] End of the simulation
  [6000.000 ms] Profile since start-up, times in microseconds
    operation        calls       min       mean       max
    ReadImu           1201       603      603.0       603
    ShowText             3      1000     1000.0      1000
    ShowNumber           4      1000     1000.0      1000
    ClearDisplay         1     31000    31000.0     31000
    ShowTextAt           2      2760     3310.0      3860
    SetMotors         1200       245      245.0       245
    ReadEncoders      1200       468      468.0       468
    ResetEncoders        1       335      335.0       335
    Publish           1200         0        0.0         0
    Setpoints         1200         0        0.0         0
    Attitude            95         0        0.0         0
    Arm                  1         0        0.0         0
    Disarm               1         0        0.0         0
    Command             45         0        0.0         0
    task             steps       min       mean       max    period  min interval  max interval  overruns
    step              1200      1316     1316.0      1316      5000          4817          5000         0
  [6000.000 ms] End of the profile
