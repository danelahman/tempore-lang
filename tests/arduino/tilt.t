The tilt display of examples/arduino/tilt on the M5Stack CoreS3 Lite, with
the packages m5-imu and m5-display: its runs by the interpreter, its rejected
variants, and its host simulation over the default world, a harmonic
oscillation of the tilt from 0.1 rad with a period of 2 s.

  $ app=../../examples/arduino/tilt
  $ tempore () { ../../tempore --grades time-interval-rational "$@"; }
  $ packages () { tempore --package m5-imu --package m5-display --board m5stack-cores3 "$@"; }

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
    { resource_0 ↦ ((0., 0., 1.), (0., 0., 0.)) # [0, 5] },
    [0.01, 0.01]
  ]
  
  === Run 2 ===
  return ()
  State: [
    [31, 31],
    [2, 2],
    [1, 1],
    [0.01, 0.01],
    { resource_0 ↦ 0. # [0, 5] },
    [1, 1],
    [2, 2],
    [250, 250]
  ]
  

The rejected variants, each loaded after the application: a display of a
tilt read before the screen is cleared, and a step that shows the tilt
itself and may last its period:

  $ for v in stale shown; do packages --typecheck-only $app/tilt.tpe tilt/$v.tpe; echo "[$?]"; done
  File "tilt/stale.tpe", lines 8-10, characters 2-11:
  8 |   unbox fresh as shown in
        ^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `fresh` is unboxed with grade `[31.05, 60.5]` accumulated since it was bound, which is not below its box grade `[0, 5]`
    File "tilt/stale.tpe", line 5, characters 21-26:
    5 |   box [0, 5] tilt as fresh in
                             ^^^^^
    `fresh` is bound here
    File "tilt/stale.tpe", line 6, characters 2-25:
    6 |   perform ClearDisplay ();
          ^^^^^^^^^^^^^^^^^^^^^^^
    grade `[31, 48]` accumulates here (operation `ClearDisplay`)
    File "tilt/stale.tpe", line 7, characters 2-35:
    7 |   perform ShowText "Tilt (degrees)";
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[0.05, 12.5]` accumulates here (operation `ShowText`)
    Note: the resource inequality `[31.05, 60.5] <= [0, 5]` does not hold
  [1]
  File "tilt/shown.tpe", lines 3-10, characters 30-6:
  3 | let step_shown (tilt : float) : float # [0, 20) =
                                    ^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `[31.25, 62]`, which does not match its annotated grade `[0, 20)`
    Note: the effect inequality `[31.25, 62] <= [0, 20)` does not hold
  [1]

The project, for the board m5stack-cores3; its sources compile without
exceptions and run-time type information:

  $ tempore --emit-arduino tilt --device $app/tilt.device.json $app/tilt.tpe | grep -c Wrote
  26
  $ grep -A3 '^\[env' _arduino/projects/tilt/platformio.ini
  [env:m5stack-cores3]
  platform = espressif32@7.1.3
  board = m5stack-cores3
  framework = arduino
  $ cd _arduino/projects/tilt
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

One second of simulated time: the step every 20 ms and the display every
287.56 ms (the clearing 31 ms, two lines of 1 ms each, the name of the
example and the footer, 2.28 ms each with the filling of their bands, and
the wait of 250 ms), which shows the tilt of the world filtered from the
readings:

  $ tempore --emit-arduino tilt --device $app/tilt.device.json --host-simulate 1 $app/tilt.tpe | grep '\] Display\|simulation'
  [31.000 ms] Display cleared
  [34.560 ms] Display at (0, 0): Tilt display
  [35.560 ms] Display: Tilt (degrees)
  [36.560 ms] Display: 5.706
  [38.424 ms] Display at (104, 230): Powered by Tempore (tempore-lang.ee)
  [319.424 ms] Display cleared
  [322.984 ms] Display at (0, 0): Tilt display
  [323.984 ms] Display: Tilt (degrees)
  [324.984 ms] Display: 2.997
  [326.848 ms] Display at (104, 230): Powered by Tempore (tempore-lang.ee)
  [607.848 ms] Display cleared
  [611.408 ms] Display at (0, 0): Tilt display
  [612.408 ms] Display: Tilt (degrees)
  [613.408 ms] Display: -1.797
  [615.272 ms] Display at (104, 230): Powered by Tempore (tempore-lang.ee)
  [896.272 ms] Display cleared
  [899.832 ms] Display at (0, 0): Tilt display
  [900.832 ms] Display: Tilt (degrees)
  [901.832 ms] Display: -5.394
  [903.696 ms] Display at (104, 230): Powered by Tempore (tempore-lang.ee)
  [1000.000 ms] End of the simulation
  $ tempore --emit-arduino tilt --device $app/tilt.device.json --host-simulate 1 $app/tilt.tpe | grep -c 'Release step'
  50
