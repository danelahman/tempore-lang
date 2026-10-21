The tilt display of examples/arduino/tilt on the M5Stack CoreS3 Lite, with
the packages m5-imu and m5-display: its runs by the interpreter, its rejected
variants, and its host simulation over the default world, a harmonic
oscillation of the tilt from 0.1 rad with a period of 2 s.

  $ app=../../examples/arduino/tilt
  $ . ../helpers.sh
  $ from_header $app/tilt.tpe

The interpreter, with the declarations of the packages under their
running-time bounds on the M5Stack CoreS3, the board of the manifest, as for
the rejected variants below, runs a step and an iteration of the display
with the default implementations of the operations:

  $ packages $app/tilt.tpe
  === Run 1 ===
  return 0.
  State: [
    [0.6, 0.6],
    [0.6, 0.6],
    [0.01, 0.01]
  ]
  
  === Run 2 ===
  return ()
  State: [
    [31, 31],
    [3, 3],
    [0.01, 0.01],
    { resource_0 ↦ 0. # [0, 20) },
    [1, 1],
    [1, 1],
    [3, 3],
    [250, 250]
  ]
  

The rejected variants, each loaded after the application: a display of a
tilt read before the screen is cleared, and a step that shows the tilt
itself and may last its period:

  $ for v in stale shown; do packages --typecheck-only $app/tilt.tpe tilt/$v.tpe; echo "[$?]"; done
  File "tilt/stale.tpe", lines 9-11, characters 2-11:
  9 |   unbox fresh as shown in
        ^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `fresh` is unboxed with grade `[31.1, 93.5]` accumulated since it was bound, which is not below its box grade `[0, 20)`
    File "tilt/stale.tpe", line 5, characters 22-27:
    5 |   box [0, 20) tilt as fresh in
                              ^^^^^
    `fresh` is bound here
    File "tilt/stale.tpe", line 6, characters 2-25:
    6 |   perform ClearDisplay ();
          ^^^^^^^^^^^^^^^^^^^^^^^
    grade `[31, 48]` accumulates here (operation `ClearDisplay`)
    File "tilt/stale.tpe", line 7, characters 2-46:
    7 |   perform ShowTextAt (0, 0, 2, "Tilt display");
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[0.05, 33]` accumulates here (operation `ShowTextAt`)
    File "tilt/stale.tpe", line 8, characters 2-35:
    8 |   perform ShowText "Tilt (degrees)";
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[0.05, 12.5]` accumulates here (operation `ShowText`)
    Note: the resource inequality `[31.1, 93.5] <= [0, 20)` does not hold
  [1]
  File "tilt/shown.tpe", lines 3-8, characters 30-6:
  3 | let step_shown (tilt : float) : float # [0, 20) =
                                    ^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `[31.25, 62]`, which does not match its annotated grade `[0, 20)`
    Note: the effect inequality `[31.25, 62] <= [0, 20)` does not hold
  [1]

The project, for the board m5stack-cores3; its sources compile without
exceptions and run-time type information:

  $ tempore --emit-arduino tilt --device $app/tilt.device.json $app/tilt.tpe | grep -c Wrote
  31
  $ grep -A3 '^\[env' _arduino/projects/tilt/platformio.ini
  [env:m5stack-cores3]
  platform = espressif32@7.1.3
  board = m5stack-cores3
  framework = arduino
  $ cd _arduino/projects/tilt
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

One second of simulated time: the step every 20 ms and the display every
289.56 ms (the clearing 31 ms, two lines of 1 ms each, the name of the
example, 3.8 ms, and the footer, 2.76 ms, with the filling of their bands,
and the wait of 250 ms), which shows the tilt of the world filtered from the
readings, and the battery indicator of the scaffold, drawn again in the top
right corner once the display has drawn over it:

  $ tempore --emit-arduino tilt --device $app/tilt.device.json --host-simulate 1 $app/tilt.tpe | grep '\] Display\|simulation'
  [31.000 ms] Display cleared
  [34.800 ms] Display at (0, 2): Tilt display
  [35.800 ms] Display: Tilt (degrees)
  [36.800 ms] Display: 5.706
  [38.768 ms] Display at (188, 231): Typechecked by Tempore
  [40.026 ms] Display at (254, 0): Battery 87%
  [320.000 ms] Display cleared
  [323.800 ms] Display at (0, 2): Tilt display
  [324.800 ms] Display: Tilt (degrees)
  [325.800 ms] Display: 2.997
  [327.768 ms] Display at (188, 231): Typechecked by Tempore
  [329.026 ms] Display at (254, 0): Battery 87%
  [609.000 ms] Display cleared
  [612.800 ms] Display at (0, 2): Tilt display
  [613.800 ms] Display: Tilt (degrees)
  [614.800 ms] Display: -1.797
  [616.768 ms] Display at (188, 231): Typechecked by Tempore
  [618.026 ms] Display at (254, 0): Battery 87%
  [898.000 ms] Display cleared
  [901.800 ms] Display at (0, 2): Tilt display
  [902.800 ms] Display: Tilt (degrees)
  [903.800 ms] Display: -5.394
  [905.768 ms] Display at (188, 231): Typechecked by Tempore
  [907.026 ms] Display at (254, 0): Battery 87%
  [1000.000 ms] End of the simulation
  $ tempore --emit-arduino tilt --device $app/tilt.device.json --host-simulate 1 $app/tilt.tpe | grep -c 'Release step'
  50

The events of the monitor on the screen, with the upper bound of ShowTextAt
lowered to 3 ms in the generated operations, which the name of the example,
drawn in 3.8 ms, exceeds. Under the policy abort the safe state is entered
and a red banner across the middle of the screen states the violation:

  $ tighten () { sed 's/bounds_ShowTextAt = {50, false, 33000,/bounds_ShowTextAt = {50, false, 3000,/' src/tempore_operations.cpp > bounds.cpp && mv bounds.cpp src/tempore_operations.cpp; }
  $ build () { c++ -std=c++17 -Wall -Wextra -Werror -ffp-contract=off -DTEMPORE_HOST -pthread -I host -I src src/*.cpp host/*.cpp -o simulation; }
  $ tempore --emit-arduino tilt_abort --device $app/tilt.device.json $app/tilt.tpe > /dev/null
  $ cd _arduino/projects/tilt_abort
  $ tighten && build && ./simulation 1000000 | grep -v '\] Operation'
  [31.000 ms] Display cleared
  [34.800 ms] Display at (0, 2): Tilt display
  [34.800 ms] Tilt display stopped
  [34.800 ms] Monitor: operation ShowTextAt took 3800 us, outside its running-time bounds [50, 3000] us
  [34.800 ms] Safe state entered
  [34.800 ms] Speaker: 1000 Hz then 500 Hz, 150 ms each
  [47.088 ms] Display fill at (0, 72), 320 by 96: 0xc00000
  [48.528 ms] Display at (28, 84): Stopped by the monitor
  [49.968 ms] Display at (28, 112): ShowTextAt took 3.8 ms
  [51.288 ms] Display at (64, 136): bounds 0.05-3 ms
  [1000.000 ms] End of the simulation
  $ cd ../../..

Under the policy warn a task of the lowest priority draws the number of the
warnings and the last of them in yellow above the footer every 500 ms:

  $ tempore --emit-arduino tilt_warn --monitor warn --device $app/tilt.device.json $app/tilt.tpe > /dev/null
  $ cd _arduino/projects/tilt_warn
  $ tighten && build && ./simulation 1600000 | grep 'Monitor\|(0, 218)'
  [34.800 ms] Monitor: operation ShowTextAt took 3800 us, outside its running-time bounds [50, 3000] us
  [323.800 ms] Monitor: operation ShowTextAt took 3800 us, outside its running-time bounds [50, 3000] us
  [503.140 ms] Display at (0, 218): Monitor: 2 warnings, last ShowTextAt 3.8 ms
  [612.800 ms] Monitor: operation ShowTextAt took 3800 us, outside its running-time bounds [50, 3000] us
  [901.800 ms] Monitor: operation ShowTextAt took 3800 us, outside its running-time bounds [50, 3000] us
  [1006.140 ms] Display at (0, 218): Monitor: 4 warnings, last ShowTextAt 3.8 ms
  [1190.800 ms] Monitor: operation ShowTextAt took 3800 us, outside its running-time bounds [50, 3000] us
  [1479.800 ms] Monitor: operation ShowTextAt took 3800 us, outside its running-time bounds [50, 3000] us
  [1509.140 ms] Display at (0, 218): Monitor: 6 warnings, last ShowTextAt 3.8 ms
  $ cd ../../..
