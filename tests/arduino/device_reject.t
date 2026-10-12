Device manifests that are malformed or do not fit the program are rejected
with a compilation error at the place of the manifest, and nothing is written.

  $ reject () { ../../tempore --grades time-interval-rational --emit-arduino rejected --device "$1" "${2:-toy/toy.tpe}"; echo "exit $?"; test ! -e _arduino/projects/rejected; }
  $ task () {
  >   printf '{ "board": "esp32-devkit",\n  "tasks": [ %s ],\n  "bindings": "toy/toy_bindings.cpp" }\n' "$1" > m.json
  > }

Malformed JSON:

  $ printf '{ "board": "esp32-devkit", }\n' > m.json
  $ reject m.json
  File "m.json", line 1, characters 27-28:
  1 | { "board": "esp32-devkit", }
                                 ^
  Syntax error: Expected the name of a member
  exit 1

An unknown member, a member of the wrong kind, a missing member and no task:

  $ printf '{ "board": "esp32-devkit", "task": [] }\n' > m.json
  $ reject m.json
  File "m.json", line 1, characters 27-33:
  1 | { "board": "esp32-devkit", "task": [] }
                                 ^^^^^^
  Compilation error: Unknown member 'task' of the manifest; accepted: board, time_unit, tasks, packages, bindings, safe_state
  exit 1
  $ printf '{ "board": 32, "tasks": [ { "function": "blinker", "kind": "free" } ] }\n' > m.json
  $ reject m.json
  File "m.json", line 1, characters 11-13:
  1 | { "board": 32, "tasks": [ { "function": "blinker", "kind": "free" } ] }
                 ^^
  Compilation error: The member 'board' of the manifest is a number, not a string
  exit 1
  $ printf '{ "tasks": [ { "function": "blinker", "kind": "free" } ] }\n' > m.json
  $ reject m.json
  File "m.json", line 1, characters 0-58:
  1 | { "tasks": [ { "function": "blinker", "kind": "free" } ] }
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Compilation error: The member 'board' of the manifest is missing
  exit 1
  $ printf '{ "board": "esp32-devkit", "tasks": [] }\n' > m.json
  $ reject m.json
  File "m.json", line 1, characters 36-38:
  1 | { "board": "esp32-devkit", "tasks": [] }
                                          ^^
  Compilation error: The manifest declares no task
  exit 1

An unknown board, package and time unit:

  $ sed 's/esp32-devkit/esp8266/; s/toy_bindings/toy\/toy_bindings/' toy/toy.device.json > m.json
  $ reject m.json
  File "m.json", line 2, characters 11-20:
  2 |   "board": "esp8266",
                 ^^^^^^^^^
  Compilation error: Unknown board 'esp8266'; accepted: esp32-devkit, esp32s3-devkit, m5stack-core2, m5stack-cores3, m5stack-fire, m5stack-gray
  exit 1
  $ sed 's/"time_unit": "ms",/"time_unit": "ms", "packages": ["m5-imu"],/' toy/toy.device.json | sed 's/toy_bindings/toy\/toy_bindings/' > m.json
  $ reject m.json
  File "m.json", line 3, characters 34-42:
  3 |   "time_unit": "ms", "packages": ["m5-imu"],
                                        ^^^^^^^^
  Compilation error: Unknown package 'm5-imu'; no peripheral packages are available
  exit 1
  $ sed 's/"time_unit": "ms"/"time_unit": "min"/' toy/toy.device.json > m.json
  $ reject m.json
  File "m.json", line 3, characters 15-20:
  3 |   "time_unit": "min",
                     ^^^^^
  Compilation error: The time unit must be ms, us, s or a positive number of microseconds
  exit 1

Tasks: an unknown kind, a periodic task without a period, a period that is not
a whole number of milliseconds, a free task with a period, a core beyond those
of the board and a priority out of range:

  $ task '{ "function": "step", "kind": "sporadic" }'
  $ reject m.json
  File "m.json", line 2, characters 43-53:
  2 |   "tasks": [ { "function": "step", "kind": "sporadic" } ],
                                                 ^^^^^^^^^^
  Compilation error: Unknown kind of task 'sporadic'; accepted: periodic, free
  exit 1
  $ task '{ "function": "step", "kind": "periodic", "initial": "start" }'
  $ reject m.json
  File "m.json", line 2, characters 13-75:
  2 |   "tasks": [ { "function": "step", "kind": "periodic", "initial": "start" } ],
                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Compilation error: A periodic task needs the member 'period'
  exit 1
  $ task '{ "function": "step", "kind": "periodic", "period": 2.5, "initial": "start" }'
  $ reject m.json
  File "m.json", line 2, characters 65-68:
  2 |   "tasks": [ { "function": "step", "kind": "periodic", "period": 2.5, "initial": "start" } ],
                                                                       ^^^
  Compilation error: The period of a periodic task must be a positive whole number of milliseconds, the tick of FreeRTOS, but it is 2500 microseconds
  exit 1
  $ task '{ "function": "blinker", "kind": "free", "period": 10 }'
  $ reject m.json
  File "m.json", line 2, characters 64-66:
  2 |   "tasks": [ { "function": "blinker", "kind": "free", "period": 10 } ],
                                                                      ^^
  Compilation error: A free task has no period
  exit 1
  $ task '{ "function": "blinker", "kind": "free", "core": 2 }'
  $ reject m.json
  File "m.json", line 2, characters 62-63:
  2 |   "tasks": [ { "function": "blinker", "kind": "free", "core": 2 } ],
                                                                    ^
  Compilation error: The core of a task must be below 2, the number of cores of the board esp32-devkit
  exit 1
  $ task '{ "function": "blinker", "kind": "free", "priority": 25 }'
  $ reject m.json
  File "m.json", line 2, characters 66-68:
  2 |   "tasks": [ { "function": "blinker", "kind": "free", "priority": 25 } ],
                                                                        ^^
  Compilation error: The priority of task 1 must be from 1 to 24
  exit 1

Task functions: an unknown function, functions of the wrong types, and a
periodic task whose state needs an initial function:

  $ task '{ "function": "stepp", "kind": "periodic", "period": 10 }'
  $ reject m.json
  File "m.json", line 2, characters 27-34:
  2 |   "tasks": [ { "function": "stepp", "kind": "periodic", "period": 10 } ],
                                 ^^^^^^^
  Compilation error: Unknown function 'stepp'; the top-level functions of the program are: start, step, blink, blinker
  exit 1
  $ task '{ "function": "step", "kind": "free" }'
  $ reject m.json
  File "m.json", line 2, characters 27-33:
  2 |   "tasks": [ { "function": "step", "kind": "free" } ],
                                 ^^^^^^
  Compilation error: The function 'step' of a free task must have the type unit -> unit, but it has the type nat -> nat
  exit 1
  $ task '{ "function": "start", "kind": "periodic", "period": 10 }'
  $ reject m.json
  File "m.json", line 2, characters 27-34:
  2 |   "tasks": [ { "function": "start", "kind": "periodic", "period": 10 } ],
                                 ^^^^^^^
  Compilation error: The function 'start' of a periodic task must have the type s -> s for a type s without type variables, but it has the type unit -> nat
  exit 1
  $ task '{ "function": "step", "kind": "periodic", "period": 10, "initial": "blinker" }'
  $ reject m.json
  File "m.json", line 2, characters 80-89:
  2 |   "tasks": [ { "function": "step", "kind": "periodic", "period": 10, "initial": "blinker" } ],
                                                                                      ^^^^^^^^^
  Compilation error: The function 'blinker' of the initial state of a periodic task must have the type unit -> nat, but it has the type unit -> unit
  exit 1
  $ task '{ "function": "step", "kind": "periodic", "period": 10 }'
  $ reject m.json
  File "m.json", line 2, characters 27-33:
  2 |   "tasks": [ { "function": "step", "kind": "periodic", "period": 10 } ],
                                 ^^^^^^
  Compilation error: The periodic task of the function 'step' has the state type nat, so it needs the member 'initial'
  exit 1
  $ task '{ "function": "add", "kind": "periodic", "period": 10 }'
  $ reject m.json toy/tasks.tpe
  File "m.json", line 2, characters 27-32:
  2 |   "tasks": [ { "function": "add", "kind": "periodic", "period": 10 } ],
                                 ^^^^^
  Compilation error: The function 'add' of a periodic task must have the type s -> s for a type s without type variables, but it has the type nat -> nat -> nat
  exit 1
  $ task '{ "function": "swap", "kind": "periodic", "period": 10, "initial": "zero" }'
  $ reject m.json toy/tasks.tpe
  File "m.json", line 2, characters 27-33:
  2 |   "tasks": [ { "function": "swap", "kind": "periodic", "period": 10, "initial": "zero" } ],
                                 ^^^^^^
  Compilation error: The function 'swap' of a periodic task must have the type s -> s for a type s without type variables, but it has the type ('a * 'b) -> ('b * 'a)
  exit 1

The effect of the function of a periodic task must be below its period: the
inferred effect [12, 12] of slow is not below 10, nor is the effect [0, ∞) of
blinker, whose state is the unit; slow fits a period of 13.

  $ task '{ "function": "slow", "kind": "periodic", "period": 10, "initial": "zero" }'
  $ reject m.json toy/tasks.tpe
  File "m.json", line 2, characters 27-33:
  2 |   "tasks": [ { "function": "slow", "kind": "periodic", "period": 10, "initial": "zero" } ],
                                 ^^^^^^
  Compilation error: The effect `[12, 12]` of the function 'slow' of a periodic task is not below its period: its durations are not all below 10
  exit 1
  $ task '{ "function": "blinker", "kind": "periodic", "period": 10 }'
  $ reject m.json
  File "m.json", line 2, characters 27-36:
  2 |   "tasks": [ { "function": "blinker", "kind": "periodic", "period": 10 } ],
                                 ^^^^^^^^^
  Compilation error: The effect `[0, ∞)` of the function 'blinker' of a periodic task is not below its period: its durations are not all below 10
  exit 1
  $ task '{ "function": "slow", "kind": "periodic", "period": 13, "initial": "zero" }'
  $ sed -i.bak 's/toy_bindings/overrun_bindings/' m.json
  $ ../../tempore --grades time-interval-rational --emit-arduino accepted --device m.json toy/tasks.tpe | tail -1
  Wrote _arduino/projects/accepted/src/overrun_bindings.cpp

Under grades that do not bound durations, no effect is below a period:

  $ printf 'let tick (n : nat) = n + 1\nlet zero () = 0\n' > levels.tpe
  $ printf '{ "board": "esp32-devkit", "tasks": [ { "function": "tick", "kind": "periodic", "period": 10, "initial": "zero" } ] }\n' > m.json
  $ ../../tempore --grades security-levels --emit-arduino rejected --device m.json levels.tpe
  File "m.json", line 1, characters 52-58:
  1 | { "board": "esp32-devkit", "tasks": [ { "function": "tick", "kind": "periodic", "period": 10, "initial": "zero" } ] }
                                                          ^^^^^^
  Compilation error: The effect `Low` of the function 'tick' of a periodic task does not bound its durations, so it is not below the period 10
  [1]

Bindings: the operations performed need a binding file that mentions their
binding functions, and the safe-state hook must be mentioned too:

  $ printf '{ "board": "esp32-devkit", "tasks": [ { "function": "blinker", "kind": "free" } ] }\n' > m.json
  $ reject m.json
  File "m.json", line 1, characters 0-83:
  1 | { "board": "esp32-devkit", "tasks": [ { "function": "blinker", "kind": "free" } ] }
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Compilation error: The function binding_Show of the operation Show needs a binding file, the member 'bindings' of the manifest
  exit 1
  $ printf 'tempore_unit binding_Show(uint32_t) { return {}; }\n' > partial.cpp
  $ printf '{ "board": "esp32-devkit", "tasks": [ { "function": "blinker", "kind": "free" } ], "bindings": "partial.cpp" }\n' > m.json
  $ reject m.json
  File "m.json", line 1, characters 95-108:
  1 | { "board": "esp32-devkit", "tasks": [ { "function": "blinker", "kind": "free" } ], "bindings": "partial.cpp" }
                                                                                                     ^^^^^^^^^^^^^
  Compilation error: The binding file partial.cpp does not define the function binding_Blink of the operation Blink
  exit 1
  $ printf '{ "board": "esp32-devkit", "tasks": [ { "function": "blinker", "kind": "free" } ], "bindings": "toy/toy_bindings.cpp", "safe_state": "motors_off" }\n' > m.json
  $ reject m.json
  File "m.json", line 1, characters 95-117:
  1 | { "board": "esp32-devkit", "tasks": [ { "function": "blinker", "kind": "free" } ], "bindings": "toy/toy_bindings.cpp", "safe_state": "motors_off" }
                                                                                                     ^^^^^^^^^^^^^^^^^^^^^^
  Compilation error: The binding file toy_bindings.cpp does not define the function motors_off of the safe state
  exit 1
  $ printf '{ "board": "esp32-devkit", "tasks": [ { "function": "blinker", "kind": "free" } ], "bindings": "toy/missing.cpp" }\n' > m.json
  $ reject m.json
  Error: ./toy/missing.cpp: No such file or directory
  exit 1

Options:

  $ ../../tempore --device m.json toy/toy.tpe
  ../../tempore: option '--device' requires '--emit-arduino'.
  [2]
  $ ../../tempore --emit-arduino x --device m.json --host-runs toy/toy.tpe
  ../../tempore: option '--host-runs' cannot be used with '--device'.
  [2]
  $ ../../tempore --emit-arduino x --host-simulate 1 toy/toy.tpe
  ../../tempore: option '--host-simulate' requires '--device'.
  [2]
  $ ../../tempore --emit-arduino x --monitor warn toy/toy.tpe
  ../../tempore: option '--monitor' requires '--bind' or '--device'.
  [2]
  $ ../../tempore --emit-arduino x --device m.json --host-simulate 0 toy/toy.tpe 2>&1 | head -1
  ../../tempore: option '--host-simulate': '0' is not a positive number of seconds of at most 10^6.
