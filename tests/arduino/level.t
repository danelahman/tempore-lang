The digital level of examples/arduino/level on the M5Stack CoreS3 Lite, with
the packages m5-imu, m5-display, m5-touch and m5-speaker, under the rigid
regular expressions of timed operations: its runs by the interpreter, its
rejected variants, its project and its host simulation, over the surface and
the taps of its host model.

  $ app=../../examples/arduino/level
  $ . ../helpers.sh
  $ from_header $app/level.tpe

The interpreter runs a step from the initial state and the taking of a
reference with the default implementations of the operations:

  $ packages $app/level.tpe
  === Run 1 ===
  return (NoReference, 0, 100, false)
  State: [
    [{!31}, {!31}],
    [{!3}, {!3}],
    [{!3}, {!3}],
    [{!3}, {!3}],
    [{!3}, {!3}],
    [{!3}, {!3}],
    [{!3}, {!3}],
    [{!3}, {!3}],
    [{!0.2}, {!0.2}],
    { resource_0 ↦
        NoReference
        # [{(ReadImu | ReadTouch)*; (ConfigureImu; CheckAtRest | 0)}, {(ReadImu | ReadTouch)*; (ConfigureImu; CheckAtRest | 0)}]
    },
    [{!0.6}, {!0.6}],
    { resource_1 ↦ (0., 0., 1.) # [{ReadTouch}, {ReadTouch}] },
    [{!0.3}, {!0.3}],
    [{!1}, {!1}],
    [{!3}, {!3}],
    [{!3}, {!3}],
    [{!3}, {!3}],
    [{!3}, {!3}],
    [{!3}, {!3}]
  ]
  
  === Run 2 ===
  return (Offsets (0., -0.))
  State: [
    [{!0.6}, {!0.6}],
    [{!10}, {!10}],
    [{!0.6}, {!0.6}],
    [{!10}, {!10}],
    [{!0.6}, {!0.6}],
    [{!10}, {!10}],
    [{!0.6}, {!0.6}],
    { resource_0 ↦
        Offsets (0., -0.)
        # [{CheckAtRest; Beep}, {CheckAtRest; Beep}]
    },
    [{!18}, {!18}],
    [{!0.05}, {!0.05}]
  ]
  

The rejected variants, each loaded after the application: a reference
without a check at rest, a step that applies the reference after a
reconfiguration without a check at rest, and a step that draws a reading taken before a
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
  File "level/reconfigured.tpe", lines 15-17, characters 2-33:
  15 |   unbox kept as reference in
         ^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `kept` is unboxed with grade `[{ReadImu; ReadTouch; (0 | ConfigureImu)}, {ReadImu; ReadTouch; (0 | ConfigureImu)}]` accumulated since it was bound, which is not below its box grade `[{(ReadImu | ReadTouch)*; (ConfigureImu; CheckAtRest | 0)}, {(ReadImu | ReadTouch)*; (ConfigureImu; CheckAtRest | 0)}]`
    File "level/reconfigured.tpe", line 5, characters 7-11:
    5 |     as kept in
               ^^^^
    `kept` is bound here
    File "level/reconfigured.tpe", line 6, characters 17-35:
    6 |   let accel, _ = perform ReadImu () in
                         ^^^^^^^^^^^^^^^^^^
    grade `[{ReadImu}, {ReadImu}]` accumulates here (operation `ReadImu`)
    File "level/reconfigured.tpe", line 7, characters 22-42:
    7 |   let touched, x, y = perform ReadTouch () in
                              ^^^^^^^^^^^^^^^^^^^^
    grade `[{ReadTouch}, {ReadTouch}]` accumulates here (operation `ReadTouch`)
    File "level/reconfigured.tpe", lines 9-13, characters 4-13:
    9 |     if touched && not touching && on_sensor x y then (
            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `[{0 | ConfigureImu}, {0 | ConfigureImu}]` accumulates here (this computation)
    Note: the resource inequality `[{ReadImu; ReadTouch; (0 | ConfigureImu)}, {ReadImu; ReadTouch; (0 | ConfigureImu)}] <= [{(ReadImu | ReadTouch)*; (ConfigureImu; CheckAtRest | 0)}, {(ReadImu | ReadTouch)*; (ConfigureImu; CheckAtRest | 0)}]` does not hold
    Note: the grade `[{ReadImu; ReadTouch; (0 | ConfigureImu)}, {ReadImu; ReadTouch; ConfigureImu}]` is below `[{ReadImu; ReadTouch; (0 | ConfigureImu)}, {ReadImu; ReadTouch; (0 | ConfigureImu)}]` but not below `[{(ReadImu | ReadTouch)*; (ConfigureImu; CheckAtRest | 0)}, {(ReadImu | ReadTouch)*; (ConfigureImu; CheckAtRest | 0)}]`
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
4.5 s, kept by the tap on the sensor button at 5 s, the unit at rest,
invalidated by the tap at 5.5 s, the unit shaken, the button showing the
new rate after each, rejected by its check during the shaking at about
7.36 s, and taken again at about 9.36 s:

  $ changes () {
  >   awk '{ l = $0; sub(/^[^]]*] /, "", l)
  >          k = $4 == "disc" ? "disc" : $3 " " $4 " " $5 " " $6
  >          if ($3 != "Display" || l != last[k]) print
  >          if ($3 == "Display") last[k] = l }' | sed 's/ *$//'
  > }
  $ tempore --emit-arduino level --device $app/level.device.json --host-simulate 10 $app/level.tpe |
  >   grep 'Display disc\|Display at (\(130, 123\|0, 152\|0, 174\|157, 200\))\|Speaker\|accelerometer\|simulation' | changes
  [49.003 ms] Display at (157, 200): Sensor 100->400Hz
  [51.963 ms] IMU: accelerometer at 100 Hz
  [53.256 ms] Display disc at (55, 82), radius 8: 0x808080
  [61.536 ms] Display at (130, 123):
  [65.616 ms] Display at (0, 152): No reference: place on the
  [69.696 ms] Display at (0, 174): surface, tap Set reference
  [1064.003 ms] Display at (0, 152): Hold still...
  [1067.563 ms] Display at (0, 174):
  [2352.968 ms] Speaker: 2000 Hz for 100 ms
  [2357.008 ms] Display at (0, 152): Reference valid for 0:30
  [2360.908 ms] Display at (0, 174): (checked at rest)
  [2552.218 ms] Display disc at (60, 90), radius 8: 0x00e000
  [2560.598 ms] Display at (130, 123): LEVEL
  [2564.638 ms] Display at (0, 152): Reference valid for 0:29
  [3052.218 ms] Display disc at (60, 66), radius 8: 0xffffff
  [3060.518 ms] Display at (130, 123):
  [3564.243 ms] Display at (0, 152): Reference valid for 0:28
  [4552.218 ms] Display disc at (60, 90), radius 8: 0x00e000
  [4560.598 ms] Display at (130, 123): LEVEL
  [4564.638 ms] Display at (0, 152): Reference valid for 0:27
  [5052.103 ms] IMU: accelerometer at 400 Hz
  [5070.756 ms] Speaker: 600 Hz for 50 ms
  [5073.903 ms] Display at (157, 200): Sensor 400->100Hz
  [5086.946 ms] Display at (0, 152): Reconfigured, now 400 Hz:
  [5090.966 ms] Display at (0, 174): reference kept, at rest
  [5314.323 ms] Display at (0, 152): Reference valid for 0:27
  [5318.223 ms] Display at (0, 174): (checked at rest)
  [5552.103 ms] IMU: accelerometer at 100 Hz
  [5570.756 ms] Speaker: 600 Hz for 50 ms
  [5573.903 ms] Display at (157, 200): Sensor 100->400Hz
  [5574.821 ms] Display disc at (55, 82), radius 8: 0x808080
  [5583.101 ms] Display at (130, 123):
  [5587.161 ms] Display at (0, 152): Reconfigured, now 100 Hz:
  [5591.221 ms] Display at (0, 174): old reference not trusted
  [6064.003 ms] Display at (0, 152): Hold still...
  [6067.563 ms] Display at (0, 174):
  [7352.968 ms] Speaker: 400 Hz for 400 ms
  [7356.908 ms] Display at (0, 152): Moved during check:
  [7360.828 ms] Display at (0, 174): reference rejected
  [8064.003 ms] Display at (0, 152): Hold still...
  [8067.563 ms] Display at (0, 174):
  [9352.968 ms] Speaker: 2000 Hz for 100 ms
  [9357.008 ms] Display at (0, 152): Reference valid for 0:30
  [9360.908 ms] Display at (0, 174): (checked at rest)
  [9552.218 ms] Display disc at (60, 90), radius 8: 0x00e000
  [9560.598 ms] Display at (130, 123): LEVEL
  [9564.638 ms] Display at (0, 152): Reference valid for 0:29
  [10000.000 ms] End of the simulation

A run of 40 seconds: the time left of the reference taken at about 9.36 s,
shown here every five seconds, and its expiry after 120 steps:

  $ tempore --emit-arduino level --device $app/level.device.json --host-simulate 40 $app/level.tpe |
  >   grep 'Display at (0, 1[57][24])\|simulation' | changes |
  >   grep -v '^\[[0-8][0-9]\{0,3\}\.\|valid for 0:[0-9][1-46-9]'
  [9357.008 ms] Display at (0, 152): Reference valid for 0:30
  [9360.908 ms] Display at (0, 174): (checked at rest)
  [13564.323 ms] Display at (0, 152): Reference valid for 0:25
  [18564.323 ms] Display at (0, 152): Reference valid for 0:20
  [23564.323 ms] Display at (0, 152): Reference valid for 0:15
  [28564.323 ms] Display at (0, 152): Reference valid for 0:10
  [33564.323 ms] Display at (0, 152): Reference valid for 0:05
  [38564.323 ms] Display at (0, 152): Reference valid for 0:00
  [39314.418 ms] Display at (0, 152): Reference expired:
  [39318.318 ms] Display at (0, 174): tap Set reference
  [40000.000 ms] End of the simulation
