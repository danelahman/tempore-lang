The digital level of examples/arduino/level on the M5Stack CoreS3 Lite, with
the packages m5-imu, m5-display, m5-touch and m5-speaker, under the regular
expressions of timed operations: its runs by the interpreter, its rejected
variants, its project and its host simulation, over the surface and the taps
of its host model.

  $ app=../../examples/arduino/level
  $ . ../helpers.sh
  $ from_header $app/level.tpe

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
    [{0.2}, {0.2}],
    { resource_0 ↦
        NoReference
        # [{(ReadImu | ReadTouch)*}, {(ReadImu | ReadTouch)*}]
    },
    [{0.6}, {0.6}],
    { resource_1 ↦ (0., 0., 1.) # [{ReadTouch}, {ReadTouch}] },
    [{0.3}, {0.3}],
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
reconfiguration, and a step that draws a reading taken before a
reconfiguration:

  $ for v in unchecked reconfigured stale; do packages --typecheck-only $app/level.tpe level/$v.tpe; echo "[$?]"; done
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
  File "level/reconfigured.tpe", lines 14-16, characters 2-33:
  14 |   unbox kept as reference in
         ^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `kept` is unboxed with grade `[{ReadImu; ReadTouch; (0 | ConfigureImu)}, {ReadImu; ReadTouch; (0 | ConfigureImu)}]` accumulated since it was bound, which is not below its box grade `[{(ReadImu | ReadTouch)*}, {(ReadImu | ReadTouch)*}]`
    File "level/reconfigured.tpe", line 4, characters 44-48:
    4 |   box {(ReadImu | ReadTouch)*} reference as kept in
                                                    ^^^^
    `kept` is bound here
    File "level/reconfigured.tpe", line 5, characters 17-35:
    5 |   let accel, _ = perform ReadImu () in
                         ^^^^^^^^^^^^^^^^^^
    grade `[{ReadImu}, {ReadImu}]` accumulates here (operation `ReadImu`)
    File "level/reconfigured.tpe", line 6, characters 22-42:
    6 |   let touched, x, y = perform ReadTouch () in
                              ^^^^^^^^^^^^^^^^^^^^
    grade `[{ReadTouch}, {ReadTouch}]` accumulates here (operation `ReadTouch`)
    File "level/reconfigured.tpe", lines 8-12, characters 4-13:
    8 |     if touched && not touching && on_sensor x y then (
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{0 | ConfigureImu}, {0 | ConfigureImu}]` accumulates here (this computation)
    Note: the resource inequality `[{ReadImu; ReadTouch; (0 | ConfigureImu)}, {ReadImu; ReadTouch; (0 | ConfigureImu)}] <= [{(ReadImu | ReadTouch)*}, {(ReadImu | ReadTouch)*}]` does not hold
  [1]
  File "level/stale.tpe", lines 11-13, characters 4-41:
  11 |     unbox reading as accel in
           ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `reading` is unboxed with grade `[{ReadTouch; ConfigureImu; Beep}, {ReadTouch; ConfigureImu; Beep}]` accumulated since it was bound, which is not below its box grade `[{ReadTouch}, {ReadTouch}]`
    File "level/stale.tpe", line 5, characters 27-34:
    5 |   box {ReadTouch} accel as reading in
                                   ^^^^^^^
    `reading` is bound here
    File "level/stale.tpe", line 6, characters 22-42:
    6 |   let touched, x, y = perform ReadTouch () in
                              ^^^^^^^^^^^^^^^^^^^^
    grade `[{ReadTouch}, {ReadTouch}]` accumulates here (operation `ReadTouch`)
    File "level/stale.tpe", line 9, characters 4-29:
    9 |     perform ConfigureImu rate;
            ^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{ConfigureImu}, {ConfigureImu}]` accumulates here (operation `ConfigureImu`)
    File "level/stale.tpe", line 10, characters 4-26:
    10 |     perform Beep (600, 50);
             ^^^^^^^^^^^^^^^^^^^^^^
    grade `[{Beep}, {Beep}]` accumulates here (operation `Beep`)
    Note: the resource inequality `[{ReadTouch; ConfigureImu; Beep}, {ReadTouch; ConfigureImu; Beep}] <= [{ReadTouch}, {ReadTouch}]` does not hold
  [1]

The project, for the board m5stack-cores3, whose step the typechecker checks
against its period; its sources compile without exceptions and run-time type
information:

  $ tempore --emit-arduino level --device $app/level.device.json $app/level.tpe | grep -c Wrote
  35
  $ cd _arduino/projects/level
  $ c++ -std=c++17 -Wall -Wextra -Werror -fno-exceptions -fno-rtti -fsyntax-only -DTEMPORE_HOST -I host -I src src/*.cpp
  $ cd ../../..

Ten seconds of simulated time, the tones, the reconfiguration and the
changes of the bubble, of the verdict and of the state of the reference:
without a reference, held still after the tap on "Set reference" at 1 s and
taken at about 2.36 s, the verdict lost on the steeper surface from 3 to
4.5 s, invalidated by the tap on the sensor button at 5 s, which then shows the new rate, rejected by its check
during the shaking at about 7.36 s, and taken again at about 9.36 s:

  $ changes () {
  >   awk '{ l = $0; sub(/^[^]]*] /, "", l)
  >          k = $4 == "disc" ? "disc" : $3 " " $4 " " $5 " " $6
  >          if ($3 != "Display" || l != last[k]) print
  >          if ($3 == "Display") last[k] = l }' | sed 's/ *$//'
  > }
  $ tempore --emit-arduino level --device $app/level.device.json --host-simulate 10 $app/level.tpe |
  >   grep 'Display disc\|Display at (\(130, 123\|0, 152\|0, 174\|157, 200\))\|Speaker\|accelerometer\|simulation' | changes
  [49.263 ms] Display at (157, 200): Sensor 100->400Hz
  [52.223 ms] IMU: accelerometer at 100 Hz
  [53.516 ms] Display disc at (55, 82), radius 8: 0x808080
  [61.796 ms] Display at (130, 123):
  [65.876 ms] Display at (0, 152): No reference: place on the
  [69.956 ms] Display at (0, 174): surface, tap Set reference
  [1065.003 ms] Display at (0, 152): Hold still...
  [1068.563 ms] Display at (0, 174):
  [2353.968 ms] Speaker: 2000 Hz for 100 ms
  [2358.008 ms] Display at (0, 152): Reference valid for 0:30
  [2361.908 ms] Display at (0, 174): (checked at rest)
  [2553.218 ms] Display disc at (60, 90), radius 8: 0x00e000
  [2561.598 ms] Display at (130, 123): LEVEL
  [2565.638 ms] Display at (0, 152): Reference valid for 0:29
  [3053.218 ms] Display disc at (60, 66), radius 8: 0xffffff
  [3061.518 ms] Display at (130, 123):
  [3565.243 ms] Display at (0, 152): Reference valid for 0:28
  [4553.218 ms] Display disc at (60, 90), radius 8: 0x00e000
  [4561.598 ms] Display at (130, 123): LEVEL
  [4565.638 ms] Display at (0, 152): Reference valid for 0:27
  [5053.103 ms] IMU: accelerometer at 400 Hz
  [5053.153 ms] Speaker: 600 Hz for 50 ms
  [5056.300 ms] Display at (157, 200): Sensor 400->100Hz
  [5057.218 ms] Display disc at (55, 82), radius 8: 0x808080
  [5065.498 ms] Display at (130, 123):
  [5069.558 ms] Display at (0, 152): Reconfigured, now 400 Hz:
  [5073.618 ms] Display at (0, 174): old reference not trusted
  [6065.003 ms] Display at (0, 152): Hold still...
  [6068.563 ms] Display at (0, 174):
  [7353.968 ms] Speaker: 400 Hz for 400 ms
  [7357.908 ms] Display at (0, 152): Moved during check:
  [7361.828 ms] Display at (0, 174): reference rejected
  [8065.003 ms] Display at (0, 152): Hold still...
  [8068.563 ms] Display at (0, 174):
  [9353.968 ms] Speaker: 2000 Hz for 100 ms
  [9358.008 ms] Display at (0, 152): Reference valid for 0:30
  [9361.908 ms] Display at (0, 174): (checked at rest)
  [9553.218 ms] Display disc at (60, 90), radius 8: 0x00e000
  [9561.598 ms] Display at (130, 123): LEVEL
  [9565.638 ms] Display at (0, 152): Reference valid for 0:29
  [10000.000 ms] End of the simulation

A run of 40 seconds: the time left of the reference taken at about 9.36 s,
shown here every five seconds, and its expiry after 120 steps:

  $ tempore --emit-arduino level --device $app/level.device.json --host-simulate 40 $app/level.tpe |
  >   grep 'Display at (0, 1[57][24])\|simulation' | changes |
  >   grep -v '^\[[0-8][0-9]\{0,3\}\.\|valid for 0:[0-9][1-46-9]'
  [9358.008 ms] Display at (0, 152): Reference valid for 0:30
  [9361.908 ms] Display at (0, 174): (checked at rest)
  [13565.323 ms] Display at (0, 152): Reference valid for 0:25
  [18565.323 ms] Display at (0, 152): Reference valid for 0:20
  [23565.323 ms] Display at (0, 152): Reference valid for 0:15
  [28565.323 ms] Display at (0, 152): Reference valid for 0:10
  [33565.323 ms] Display at (0, 152): Reference valid for 0:05
  [38565.323 ms] Display at (0, 152): Reference valid for 0:00
  [39315.418 ms] Display at (0, 152): Reference expired:
  [39319.318 ms] Display at (0, 174): tap Set reference
  [40000.000 ms] End of the simulation
