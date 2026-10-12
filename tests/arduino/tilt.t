The tilt display of examples/arduino/tilt on the M5Stack CoreS3 Lite, with
the packages m5-imu and m5-display: its runs by the interpreter, its rejected
variants, and its host simulation over the default world, a harmonic
oscillation of the tilt from 0.1 rad with a period of 2 s.

  $ app=../../examples/arduino/tilt
  $ tempore () { ../../tempore --grades time-interval-rational "$@"; }
  $ packages () { tempore --package m5-imu --package m5-display "$@"; }

The interpreter, with the declarations of the packages, runs a step and an
iteration of the display with the default implementations of the
operations:

  $ packages $app/tilt.tpe
  === Run 1 ===
  return 0.
  State: [
    [0.5, 0.5],
    [0.5, 0.5],
    { resource_0 ↦ ((0., 0., 1.), (0., 0., 0.)) # [0, 5] },
    [0.01, 0.01]
  ]
  
  === Run 2 ===
  return ()
  State: [
    [31, 31],
    [1, 1],
    [0.01, 0.01],
    { resource_0 ↦ 0. # [0, 5] },
    [1, 1],
    [250, 250]
  ]
  

The rejected variants, each loaded after the application: a display of a
tilt read before the screen is cleared, and a step that shows the tilt
itself and may last its period:

  $ for v in stale shown; do packages --typecheck-only $app/tilt.tpe tilt/$v.tpe; echo "[$?]"; done
  File "tilt/stale.tpe", lines 8-10, characters 2-11:
  8 |   unbox fresh as shown in
        ^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `fresh` is unboxed with grade `[10.2, 80]` accumulated since it was bound, which is not below its box grade `[0, 5]`
    File "tilt/stale.tpe", line 5, characters 21-26:
    5 |   box [0, 5] tilt as fresh in
                             ^^^^^
    `fresh` is bound here
    File "tilt/stale.tpe", line 6, characters 2-25:
    6 |   perform ClearDisplay ();
          ^^^^^^^^^^^^^^^^^^^^^^^
    grade `[10, 60]` accumulates here (operation `ClearDisplay`)
    File "tilt/stale.tpe", line 7, characters 2-35:
    7 |   perform ShowText "Tilt (degrees)";
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[0.2, 20]` accumulates here (operation `ShowText`)
    Note: the resource inequality `[10.2, 80] <= [0, 5]` does not hold
  [1]
  File "tilt/shown.tpe", lines 3-9, characters 30-6:
  3 | let step_shown (tilt : float) : float # [0, 20) =
                                    ^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `[0.4, 20.8]`, which does not match its annotated grade `[0, 20)`
    Note: the effect inequality `[0.4, 20.8] <= [0, 20)` does not hold
  [1]

The project, for the board m5stack-cores3; its sources compile without
exceptions and run-time type information:

  $ tempore --emit-arduino tilt --device $app/tilt.device.json $app/tilt.tpe | grep -c Wrote
  26
  $ grep -A3 '^\[env' _arduino/projects/tilt/platformio.ini
  [env:m5stack-cores3]
  platform = espressif32
  board = m5stack-cores3
  framework = arduino
  $ cd _arduino/projects/tilt
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

One second of simulated time: the step every 20 ms and the display every
283 ms (the clearing 31 ms, two lines of 1 ms each and the wait of 250 ms),
which shows the tilt of the world filtered from the readings:

  $ tempore --emit-arduino tilt --device $app/tilt.device.json --host-simulate 1 $app/tilt.tpe | grep '\] Display\|simulation'
  [31.000 ms] Display cleared
  [32.000 ms] Display: Tilt (degrees)
  [33.000 ms] Display: 5.707
  [314.000 ms] Display cleared
  [315.000 ms] Display: Tilt (degrees)
  [316.000 ms] Display: 3.298
  [597.000 ms] Display cleared
  [598.000 ms] Display: Tilt (degrees)
  [599.000 ms] Display: -1.451
  [880.000 ms] Display cleared
  [881.000 ms] Display: Tilt (degrees)
  [882.000 ms] Display: -5.275
  [1000.000 ms] End of the simulation
  $ tempore --emit-arduino tilt --device $app/tilt.device.json --host-simulate 1 $app/tilt.tpe | grep -c 'Release step'
  50
