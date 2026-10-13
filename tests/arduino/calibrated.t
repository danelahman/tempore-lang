The calibrated tilt display of examples/arduino/calibrated on the M5Stack
CoreS3 Lite, with the packages m5-imu and m5-display: its runs by the
interpreter, its variants rejected by the typechecker and by the Arduino
backend, the handler of its step compiled to a direct call of its case, and its host simulation of the
unit at rest at a tilt of 0.1 rad, whose gyroscope reads a bias of 2
degrees per second.

  $ app=../../examples/arduino/calibrated
  $ tempore () { ../../tempore --grades time-interval-rational "$@"; }
  $ packages () { tempore --package m5-imu --package m5-display --board m5stack-cores3 "$@"; }
  $ strip_state () { awk '/^State:/ { skip = 1 } /^$/ { skip = 0 } !skip'; }

The interpreter runs a step from the initial state and an iteration of the
display with the default implementations of the operations:

  $ packages $app/calibrated.tpe | strip_state
  === Run 1 ===
  return (0., 0.)
  
  === Run 2 ===
  return ()
  

The variant rejected by the typechecker, loaded after the application: a
handler whose case of ReadImu averages two readings and exceeds the grade of
the operation:

  $ packages --typecheck-only $app/calibrated.tpe calibrated/smoothed.tpe
  File "calibrated/smoothed.tpe", lines 10-12, characters 6-60:
  10 |       continue k with
             ^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with grade `[0.4, 3]` accumulated since it was bound, which is not below its box grade `[0.2, 1.5]`
    File "calibrated/smoothed.tpe", line 6, characters 15-16:
    6 |   | ReadImu () k ->
                       ^
    `k` is bound here
    File "calibrated/smoothed.tpe", line 7, characters 45-63:
    7 |       let (ax1, ay1, az1), (gx1, gy1, gz1) = perform ReadImu () in
                                                     ^^^^^^^^^^^^^^^^^^
    grade `[0.2, 1.5]` accumulates here (operation `ReadImu`)
    File "calibrated/smoothed.tpe", line 8, characters 45-63:
    8 |       let (ax2, ay2, az2), (gx2, gy2, gz2) = perform ReadImu () in
                                                     ^^^^^^^^^^^^^^^^^^
    grade `[0.2, 1.5]` accumulates here (operation `ReadImu`)
    Note: the resource inequality `[0.4, 3] <= [0.2, 1.5]` does not hold
  [1]

A handler whose case computes after the resumption of its continuation,
accepted by the typechecker, is rejected by the Arduino backend when a task
of the manifest uses it, here through the step that replaces that of
calibrated.tpe:

  $ tempore --emit-arduino observed --device $app/calibrated.device.json $app/calibrated.tpe calibrated/observed.tpe
  File "calibrated/observed.tpe", line 9, characters 26-27:
  9 |       let s, _ = continue k with (accel, (gx -. bias, gy, gz)) in
                                ^
  Compilation error: The continuation `k` of the case of `ReadImu` is resumed outside tail position, so the handler cannot be compiled to direct calls
  [1]
  $ test -e _arduino/projects/observed || echo 'Nothing is written.'
  Nothing is written.

The project, for the board m5stack-cores3; its sources compile without
exceptions and run-time type information. The step calls the case of the
handler, a function of the bias, in place of the operation, and the case
calls the monitored operation:

  $ tempore --emit-arduino calibrated --device $app/calibrated.device.json $app/calibrated.tpe | grep -c Wrote
  28
  $ cd _arduino/projects/calibrated
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ sed -n '/^static .* calibrated_ReadImu.*{/,/^}/p' src/tempore_program.cpp
  static tempore_tuple3 calibrated_ReadImu_11(float bias_49, tempore_unit) {
    const tempore_tuple3 tempore_t0 = tempore_op_ReadImu(tempore_unit{});
    const tempore_tuple2 accel_50 = tempore_t0.c0;
    const float gx_51 = tempore_t0.c1.c0;
    const float gy_52 = tempore_t0.c1.c1;
    const float gz_53 = tempore_t0.c1.c2;
    const float b_54 = (gx_51 - bias_49);
    return tempore_tuple3{accel_50, tempore_tuple2{b_54, gy_52, gz_53}};
  }
  $ grep '= calibrated_ReadImu' src/tempore_program.cpp
    const tempore_tuple3 imu_47 = calibrated_ReadImu_11(tempore_c0_0, tempore_unit{});
  $ cd ../../..

Two seconds of simulated time: the initial function reads the unit 50
times, 2.603 ms apart, and the step every 20 ms from then on; the display
shows the tilt of the unit, 0.1 rad, about 5.73 degrees, the bias removed
from every reading, within 0.01 degrees, after showing the tilt published
before the first step:

  $ tempore --emit-arduino calibrated --device $app/calibrated.device.json --host-simulate 2 $app/calibrated.tpe > run.log
  $ grep -c 'Release step' run.log
  94
  $ grep '\] Display: [-0-9]' run.log | awk '
  >   NR == 1 { print "first:", $NF; next }
  >   { n++; if ($NF < 5.72 || $NF > 5.74) bad++ }
  >   END { print n, "later, of which", bad + 0, "outside 5.72 to 5.74" }'
  first: 0.000
  6 later, of which 0 outside 5.72 to 5.74
