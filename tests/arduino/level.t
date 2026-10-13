The digital level of examples/arduino/level on the M5Stack CoreS3 Lite, with
the packages m5-imu, m5-display, m5-touch and m5-speaker, under the regular
expressions of timed operations: its runs by the interpreter, its rejected
variants, its project and its host simulation, over the surface and the taps
of its host model.

  $ app=../../examples/arduino/level
  $ tempore () { ../../tempore --grades regex-timed-interval-rational-symbolic "$@"; }
  $ packages () {
  >   tempore --package m5-imu --package m5-display --package m5-touch \
  >     --package m5-speaker --board m5stack-cores3 "$@"
  > }

The interpreter runs a step from the initial state and the taking of a
reference with the default implementations of the operations:

  $ packages $app/level.tpe
  === Run 1 ===
  return (NoReference, 0, 100, false)
  State: [
    [{31}, {31}],
    [{3}, {3}],
    [{3}, {3}],
    [{3}, {3}],
    [{3}, {3}],
    [{3}, {3}],
    [{3}, {3}],
    [{3}, {3}],
    [{3}, {3}],
    [{0.2}, {0.2}],
    { resource_0 ↦ NoReference # [{Touched; ReadImu}, {Touched; ReadImu}] },
    [{0.3}, {0.3}],
    [{0.6}, {0.6}],
    { resource_1 ↦ (0., 0., 1.) # [{0}, {0}] },
    [{1}, {1}],
    [{3}, {3}],
    [{3}, {3}],
    [{3}, {3}],
    [{3}, {3}],
    [{3}, {3}]
  ]
  
  === Run 2 ===
  return (Offsets (0., -0.))
  State: [
    [{0.6}, {0.6}],
    [{10}, {10}],
    [{0.6}, {0.6}],
    [{10}, {10}],
    [{0.6}, {0.6}],
    [{10}, {10}],
    [{0.6}, {0.6}],
    { resource_0 ↦
        Offsets (0., -0.)
        # [{CheckAtRest; Beep}, {CheckAtRest; Beep}]
    },
    [{18}, {18}],
    [{0.05}, {0.05}]
  ]
  

The rejected variants, each loaded after the application: a reference
without a check at rest, a step that applies the reference after a
reconfiguration, a step that applies a reference to a reading taken before
it, and a step that draws before it reads the unit:

  $ for v in unchecked reconfigured stale drawn_first; do packages --typecheck-only $app/level.tpe level/$v.tpe; echo "[$?]"; done
  File "level/unchecked.tpe", lines 7-8, characters 2-9:
  7 |   unbox unchecked as checked in
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `unchecked` is unboxed with grade `[{Beep}, {Beep}]` accumulated since it was bound, which is not below its box grade `[{CheckAtRest; Beep}, {CheckAtRest; Beep}]`
    File "level/unchecked.tpe", line 5, characters 46-55:
    5 |   box {CheckAtRest; Beep} (Offsets (x, y)) as unchecked in
                                                      ^^^^^^^^^
    `unchecked` is bound here
    File "level/unchecked.tpe", line 6, characters 2-26:
    6 |   perform Beep (2000, 100);
          ^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{Beep}, {Beep}]` accumulates here (operation `Beep`)
    Note: the resource inequality `[{Beep}, {Beep}] <= [{CheckAtRest; Beep}, {CheckAtRest; Beep}]` does not hold
  [1]
  File "level/reconfigured.tpe", lines 11-13, characters 2-37:
  11 |   unbox kept as reference in
         ^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `kept` is unboxed with grade `[{Touched; (0 | ConfigureImu; Beep); ReadImu}, {Touched; (0 | ConfigureImu; Beep); ReadImu}]` accumulated since it was bound, which is not below its box grade `[{Touched; ReadImu}, {Touched; ReadImu}]`
    File "level/reconfigured.tpe", line 4, characters 38-42:
    4 |   box {Touched; ReadImu} reference as kept in
                                              ^^^^
    `kept` is bound here
    File "level/reconfigured.tpe", line 5, characters 22-40:
    5 |   let touched, x, y = perform Touched () in
                              ^^^^^^^^^^^^^^^^^^
    grade `[{Touched}, {Touched}]` accumulates here (operation `Touched`)
    File "level/reconfigured.tpe", lines 6-9, characters 2-11:
    6 |   (if touched && on_sensor x y then (
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{0 | ConfigureImu; Beep}, {0 | ConfigureImu; Beep}]` accumulates here (this computation)
    File "level/reconfigured.tpe", line 10, characters 17-35:
    10 |   let accel, _ = perform ReadImu () in
                          ^^^^^^^^^^^^^^^^^^
    grade `[{ReadImu}, {ReadImu}]` accumulates here (operation `ReadImu`)
    Note: the resource inequality `[{Touched; (0 | ConfigureImu; Beep); ReadImu}, {Touched; (0 | ConfigureImu; Beep); ReadImu}] <= [{Touched; ReadImu}, {Touched; ReadImu}]` does not hold
  [1]
  File "level/stale.tpe", lines 8-10, characters 2-31:
  8 |   unbox reading as accel in
        ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `reading` is unboxed with grade `[{0 | ReadImu; 10; ReadImu; 10; ReadImu; 10; ReadImu; CheckAtRest; Beep}, {0 | ReadImu; 10; ReadImu; 10; ReadImu; 10; ReadImu; CheckAtRest; Beep}]` accumulated since it was bound, which is not below its box grade `[{0}, {0}]`
    File "level/stale.tpe", line 6, characters 17-24:
    6 |   box 0 accel as reading in
                         ^^^^^^^
    `reading` is bound here
    File "level/stale.tpe", line 7, characters 18-56:
    7 |   let reference = if touched then take () else reference in
                          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{0 | ReadImu; 10; ReadImu; 10; ReadImu; 10; ReadImu; CheckAtRest; Beep}, {0 | ReadImu; 10; ReadImu; 10; ReadImu; 10; ReadImu; CheckAtRest; Beep}]` accumulates here (this computation)
    Note: the resource inequality `[{0 | ReadImu; 10; ReadImu; 10; ReadImu; 10; ReadImu; CheckAtRest; Beep}, {0 | ReadImu; 10; ReadImu; 10; ReadImu; 10; ReadImu; CheckAtRest; Beep}] <= [{0}, {0}]` does not hold
  [1]
  File "level/drawn_first.tpe", lines 3-9, characters 64-37:
  3 | let step_drawn_first ((reference, age, rate, touching) : state) : state
                                                                      ^^^^^^^
  Typing error: This function's body has grade `[{Touched; DrawLevel; ShowNumberAt; ShowNumberAt; ShowTextAt; (ShowTextAt | ShowTimeAt); ShowTextAt; ReadImu}, {Touched; DrawLevel; ShowNumberAt; ShowNumberAt; ShowTextAt; (ShowTextAt | ShowTimeAt); ShowTextAt; ReadImu}]`, which does not match its annotated grade `[{Touched; ReadImu; DrawLevel; ShowNumberAt; ShowNumberAt; ShowTextAt; (ShowTextAt | ShowTimeAt); ShowTextAt}, {Touched; ReadImu; DrawLevel; ShowNumberAt; ShowNumberAt; ShowTextAt; (ShowTextAt | ShowTimeAt); ShowTextAt}]`
    Note: the effect inequality `[{Touched; DrawLevel; ShowNumberAt; ShowNumberAt; ShowTextAt; (ShowTextAt | ShowTimeAt); ShowTextAt; ReadImu}, {Touched; DrawLevel; ShowNumberAt; ShowNumberAt; ShowTextAt; (ShowTextAt | ShowTimeAt); ShowTextAt; ReadImu}] <= [{Touched; ReadImu; DrawLevel; ShowNumberAt; ShowNumberAt; ShowTextAt; (ShowTextAt | ShowTimeAt); ShowTextAt}, {Touched; ReadImu; DrawLevel; ShowNumberAt; ShowNumberAt; ShowTextAt; (ShowTextAt | ShowTimeAt); ShowTextAt}]` does not hold
    Note: the grade `[{Touched; DrawLevel; ShowNumberAt; ShowNumberAt; ShowTextAt; ShowTextAt; ShowTextAt; ReadImu}, {Touched; DrawLevel; ShowNumberAt; ShowNumberAt; ShowTextAt; (ShowTextAt | ShowTimeAt); ShowTextAt; ReadImu}]` is below `[{Touched; DrawLevel; ShowNumberAt; ShowNumberAt; ShowTextAt; (ShowTextAt | ShowTimeAt); ShowTextAt; ReadImu}, {Touched; DrawLevel; ShowNumberAt; ShowNumberAt; ShowTextAt; (ShowTextAt | ShowTimeAt); ShowTextAt; ReadImu}]` but not below `[{Touched; ReadImu; DrawLevel; ShowNumberAt; ShowNumberAt; ShowTextAt; (ShowTextAt | ShowTimeAt); ShowTextAt}, {Touched; ReadImu; DrawLevel; ShowNumberAt; ShowNumberAt; ShowTextAt; (ShowTextAt | ShowTimeAt); ShowTextAt}]`
  [1]

The project, for the board m5stack-cores3, whose step the typechecker checks
against its period; its sources compile without exceptions and run-time type
information:

  $ tempore --emit-arduino level --device $app/level.device.json $app/level.tpe | grep -c Wrote
  31
  $ cd _arduino/projects/level
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

Ten seconds of simulated time, the tones, the reconfiguration and the
changes of the bubble, of the verdict and of the state of the reference:
without a reference, held still after the tap on "Set reference" at 1 s and
taken at about 2.36 s, the verdict lost on the steeper surface from 3 to
4.5 s, invalidated by the tap on "Reconfigure sensor" at 5 s, rejected by its check
during the shaking at about 7.36 s, and taken again at about 9.36 s:

  $ changes () {
  >   awk '{ l = $0; sub(/^[^]]*] /, "", l)
  >          k = $4 == "disc" ? "disc" : $3 " " $4 " " $5 " " $6
  >          if ($3 != "Display" || l != last[k]) print
  >          if ($3 == "Display") last[k] = l }' | sed 's/ *$//'
  > }
  $ tempore --emit-arduino level --device $app/level.device.json --host-simulate 10 $app/level.tpe |
  >   grep 'Display disc\|Display at (\(130, 120\|0, 150\|0, 172\|206, 6\))\|Speaker\|accelerometer\|simulation' | changes
  [45.176 ms] Display at (206, 6): Sensor rate: 100 Hz
  [54.848 ms] IMU: accelerometer at 100 Hz
  [55.986 ms] Display disc at (55, 82), radius 8: 0x808080
  [64.266 ms] Display at (130, 120):
  [68.346 ms] Display at (0, 150): No reference: place on the
  [72.426 ms] Display at (0, 172): surface, tap Set reference
  [1067.003 ms] Display at (0, 150): Hold still...
  [1070.563 ms] Display at (0, 172):
  [2355.365 ms] Speaker: 2000 Hz for 100 ms
  [2359.405 ms] Display at (0, 150): Reference valid for 0:30
  [2363.305 ms] Display at (0, 172): (checked at rest)
  [2555.218 ms] Display disc at (60, 90), radius 8: 0x00e000
  [2563.598 ms] Display at (130, 120): LEVEL
  [2567.638 ms] Display at (0, 150): Reference valid for 0:29
  [3055.218 ms] Display disc at (60, 66), radius 8: 0xffffff
  [3063.498 ms] Display at (130, 120):
  [3567.223 ms] Display at (0, 150): Reference valid for 0:28
  [4555.218 ms] Display disc at (60, 90), radius 8: 0x00e000
  [4563.598 ms] Display at (130, 120): LEVEL
  [4567.638 ms] Display at (0, 150): Reference valid for 0:27
  [5054.500 ms] IMU: accelerometer at 400 Hz
  [5054.550 ms] Speaker: 600 Hz for 50 ms
  [5056.386 ms] Display at (206, 6): Sensor rate: 400 Hz
  [5057.304 ms] Display disc at (55, 82), radius 8: 0x808080
  [5065.584 ms] Display at (130, 120):
  [5069.644 ms] Display at (0, 150): Reconfigured, now 400 Hz:
  [5073.704 ms] Display at (0, 172): old reference not trusted
  [6067.003 ms] Display at (0, 150): Hold still...
  [6070.563 ms] Display at (0, 172):
  [7355.365 ms] Speaker: 400 Hz for 400 ms
  [7359.305 ms] Display at (0, 150): Moved during check:
  [7363.225 ms] Display at (0, 172): reference rejected
  [8067.003 ms] Display at (0, 150): Hold still...
  [8070.563 ms] Display at (0, 172):
  [9355.365 ms] Speaker: 2000 Hz for 100 ms
  [9359.405 ms] Display at (0, 150): Reference valid for 0:30
  [9363.305 ms] Display at (0, 172): (checked at rest)
  [9555.218 ms] Display disc at (60, 90), radius 8: 0x00e000
  [9563.598 ms] Display at (130, 120): LEVEL
  [9567.638 ms] Display at (0, 150): Reference valid for 0:29
  [10000.000 ms] End of the simulation

A run of 40 seconds: the time left of the reference taken at about 9.36 s,
shown here every five seconds, and its expiry after 120 steps:

  $ tempore --emit-arduino level --device $app/level.device.json --host-simulate 40 $app/level.tpe |
  >   grep 'Display at (0, 1[57][02])\|simulation' | changes |
  >   grep -v '^\[[0-8][0-9]\{0,3\}\.\|valid for 0:[0-9][1-46-9]'
  [9359.405 ms] Display at (0, 150): Reference valid for 0:30
  [9363.305 ms] Display at (0, 172): (checked at rest)
  [13567.323 ms] Display at (0, 150): Reference valid for 0:25
  [18567.323 ms] Display at (0, 150): Reference valid for 0:20
  [23567.323 ms] Display at (0, 150): Reference valid for 0:15
  [28567.323 ms] Display at (0, 150): Reference valid for 0:10
  [33567.323 ms] Display at (0, 150): Reference valid for 0:05
  [38567.323 ms] Display at (0, 150): Reference valid for 0:00
  [39317.418 ms] Display at (0, 150): Reference expired:
  [39321.318 ms] Display at (0, 172): tap Set reference
  [40000.000 ms] End of the simulation
