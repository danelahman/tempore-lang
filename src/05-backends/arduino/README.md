# Arduino backend

The proof-of-concept Arduino backend compiles a fragment of
Tempore to allocation-free C++ and generates a PlatformIO project for an
Arduino or ESP32 board, with FreeRTOS tasks and run-time monitors.

- Grades are erased; boxes and unboxing generate no code.
- The program is typed against the running-time bounds of its operations on
  its board.
- The monitors of the device check those bounds and the periods of the tasks
  while it runs.

An application is described in four parts: a board profile, a device
manifest, peripheral packages, and the program with its binding file.

## Board profiles

A profile [`boards/NAME.json`](boards/) gives the PlatformIO platform, board,
libraries and build flags, the number of cores, the I2C buses, the baud rate
of the serial port, the USB identifiers of its serial interface (`usb`, by
which the make targets find its port, [Ports](#ports)) and the capabilities
of a board (`imu`, `display`, `touch`, `speaker`, `battery`, ...). The
boards supported are those of the profiles in that directory.

A profile with the suffix `-radio`, such as `m5stack-gray-radio`, is a board
with its Wi-Fi radio running, as for `esp-now`: the same hardware and project
as the board without the suffix, under its own name for the bounds of the
packages measured with the radio ([Bounds per board](#bounds-per-board)),
which assume the radio on core 0 and the tasks of the manifest on core 1.

On a board with the capability `display`, the build flag
`TEMPORE_DISPLAY_BRIGHTNESS` sets the brightness of the display at start-up,
a percentage from 0 to 100 (default 24).

The optional member `imu_frequency` sets the frequency of the
transactions with the inertial measurement unit (`M5.Imu.setClock`, and the
build flag `TEMPORE_IMU_FREQUENCY` of the package `m5-imu`; 400 kHz by
default).

## Device manifests

A device manifest, in JSON, names the board, the tasks, the time unit of the
program (`ms` by default), the peripheral packages, the C++ binding file, the
C++ function of the safe state, and the C++ models of devices and of the
physical world used only by the host simulation:

    {
      "board": "m5stack-cores3",
      "tasks": [
        { "function": "step", "kind": "periodic", "period": 20,
          "initial": "start", "priority": 2 },
        { "function": "show", "kind": "free", "repeat": true,
          "priority": 1, "core": 0 }
      ],
      "packages": ["m5-imu", "m5-display"],
      "bindings": "bindings.cpp",
      "safe_state": "tilt_safe_state"
    }

A periodic task calls its function, of type `s -> s`, once per period, from
the state its `initial` function returns. A free task calls its function, of
type `unit -> unit`, once, or, with `repeat`, each time it returns.

With `"battery": true`, on a board with the capabilities `display` and
`battery`, the charge of the battery is shown in the top right corner of the
screen, outside the program.

## Peripheral packages

A package, a directory [`libraries/NAME/`](libraries/) with a descriptor
`package.json`, declares operations, with their grades and default
implementations, and implements them in C++, with host models for the
simulation. The operations return plain values; the freshness of a reading
is specified by the application, which boxes it.

### Declarations and definitions

The descriptor maps each grade system the package supports to a file of
declarations, and may name a file of definitions, types and functions shared
by all of them, such as the tilt filters of `m5-imu`. Every package is
declared under `time-interval-rational`, under the regular expressions of
timed operations over rational delays (`regex-timed-*-rational-symbolic`),
their rigid variants (`regex-timed-rigid-*-rational-symbolic`) and
`operation-spacing`, with running-time bounds in milliseconds, and under
`counts-upper-bound`, each call counting once.

### The packages

- `i2c`: `I2cWrite8`, `I2cWrite16`, `I2cWrite32`, `I2cRead8`, `I2cRead16` and
  `I2cRead32`, register transactions on the bus `Wire`.
- `m5-imu`:
  - `ReadImu`, the accelerometer and gyroscope of an M5Stack core, with the
    tilt filters `tilt_x` and `tilt_y`;
  - `ConfigureImu`, the output data rate of the accelerometer, its range
    unchanged;
  - `CheckAtRest`, a check of plausibility, not a self-test: whether the unit
    is at rest, judged by the variation of four readings, so that a constant
    bias of the gyroscope passes; the spread of the angular rate about each
    axis is to lie below the build flag `TEMPORE_IMU_REST_SPREAD`, in degrees
    per second (default 5);
  - under the rigid grades of timed operations, `read_imu_boxed`, one reading
    in one box, `latest_imu`, of grade `{≤2 & ~ReadImu}`, usable within 2 ms
    and before the next `ReadImu`;
  - `m5_imu_observe(accel, gyro)`, defined weakly to do nothing, receives
    each reading, for an application to record it.
- `m5-display`, with colours of 24 bits, `0xRRGGBB`:
  - `ShowText`, `ShowNumber` and `ClearDisplay`, lines of text of size 2
    written one below another;
  - `ShowTextAt` and `ShowNumberAt`, a text or a number at a position in a
    size from 1 to 4, over a band of the display filled first, so that it
    replaces the text of that band without a clearing;
  - `ShowTimeAt`, a text followed by a duration as m:ss;
  - `ShowColourTextAt` and `ShowColourNumberAt`, a text or a number in a
    colour over a band of another;
  - `DrawButton`, a button with a centred label;
  - `DrawBar`, a horizontal bar filled to a length;
  - `DrawLevel`, a bubble level, a vial with a bubble at an offset from its
    centre.
- `m5-touch`: `ReadTouch`, whether the screen is touched and where
  (capability `touch`).
- `m5-speaker`: `Beep`, which starts a tone of a frequency and a duration and
  returns at once (capability `speaker`); `m5_speaker_observe(frequency,
  duration)`, defined weakly to do nothing, receives each tone.
- `bala2-base`: `SetMotors`, `ReadEncoders` and `ResetEncoders` of the base of
  the M5Stack BALA2, with a watchdog of the motor setpoints; the counts of the
  encoders increase in the direction in which a positive drive turns the
  wheel.
- `esp-now`: encrypted packets of a tag and two floats between two ESP32
  boards over ESP-NOW:
  - a device build requires the peer, the build flag `ESP_NOW_PEER`, six
    bytes separated by commas, and the key, the build flag `ESP_NOW_KEY`,
    32 hexadecimal digits; a missing or malformed peer or key, and the
    broadcast address, which ESP-NOW does not encrypt, are compilation
    errors;
  - `LinkStart` starts the radio and ESP-NOW on a channel, on core 0, and
    returns whether the link is encrypted, true for every link;
  - `Send` queues a packet and returns without waiting;
  - `ReceiveMessage` returns, without waiting, the latest packet from the peer if it
    arrived at most a given number of milliseconds ago.
- `bala2-radio`: the messages of the remote control of the BALA2, shared by
  the robot and the controller, over `esp-now`, listed before it, declared
  under `time-interval-rational` and the regular expressions of timed
  operations with intervals or upper bounds:
  - the type `message`, `Start`, `Drive (speed, turn)`, `Stop` or `Beat`;
  - `SendStart`, `SendDrive`, `SendStop` and `SendBeat`, one operation per
    message, so that grades tell the messages apart;
  - `remote_receive`, the latest message received at most 50 ms ago, or
    `Nothing`, boxed with `[0, 150)`, so that a move is applied at most
    200 ms after it was sent, and under the rigid grades with
    `{<150 & ~ReceiveMessage}`, its setpoints of the non-eternal type `setpoints`;
  - `SendStatus` and `remote_status`, the status of the robot, its phase and
    tilt, the latest received at most 50 ms ago, boxed with `[0, 200)`, and
    under the rigid grades with `{<200 & ~ReceiveMessage}`.

### Bounds per board

The bounds a package declares hold on every board it supports. Where an
operation is measured to run within narrower bounds on a particular board,
the member `bounds` of the descriptor gives them, by board and operation, as
closed intervals in the time unit of the declarations:

    "bounds": {
      "m5stack-gray": { "ReadImu": [0.55, 1.25] },
      "m5stack-cores3": { "ReadImu": [0.2, 1.5] }
    }

For the board of a manifest, these bounds replace those of the declarations
under every grade system that bounds durations: the interval grade of the
operation under `time-interval-rational`, and its `within` bounds under the
regular expressions of timed operations and `operation-spacing`.

- The program is typed, and the monitors are generated, under the bounds of
  its board.
- An interpreter run with `--package` takes those of the board named by
  `--board`, and else those of the declarations; the web interface takes
  those of the board of its manifest.
- Each board and operation of `bounds` must be a board profile and an
  operation the package binds.
- A lower bound 0 is open at 0 where the declaration is, as under the
  regular expressions of timed operations, whose operations take positive
  time.
- The default implementations take a time within the bounds of every board.
- The examples name the board of their manifest by `--board` in the run
  command of their header, and the figures in their comments are those under
  its bounds.

### How the bounds are measured

The bounds of the packages and of the examples are measured on the devices
by their profile ([Measuring running times](#measuring-running-times)): the
lower bound is the least time measured, rounded down, and the upper bound 1.5
times the greatest, rounded up. On a profile with the radio, the bounds are
measured with the radio running and are never narrower than those of the
board without it, which an operation not measured with the radio keeps.
Bounds not yet measured are provisional; each declaration states its
measurements and how the bounds not measured directly, such as those of
`i2c`, are derived.

## The program

The program is a `.tpe` file with a binding file, which defines, for each
operation `Op` not bound by a package, the function
`tempore_result_Op binding_Op(tempore_argument_Op)`, and the safe-state
function. A name `Op` other than of ASCII letters and digits with single
underscores between them is spelt there as a C++ identifier followed by `_`,
its bytes in hexadecimal and `_`, so that distinct names stay distinct: the
binding function of `Show'` is `binding_Show_p_53686f7727_`.

Under a device manifest, the definitions checked and compiled are those
reached from the task functions and the `initial` functions of the manifest;
the other definitions, such as handlers used only by `run` commands of the
interpreter, may lie outside the fragment. Without a manifest, every
top-level definition is checked, and the `run` commands are compiled under
`--host-runs`.

The entry points are the task functions and the `initial` functions, or,
without a manifest, the functions that the `run` commands call outside every
handler, or every top-level function if there is no `run` command. Only the
code reached from them is compiled, so that a function used only under a
handler has no instance outside it, and the operations the program declares
are those it performs outside every handler.

### The fragment

The fragment consists of

- top-level functions, fully applied;
- `let`, `match` and `if`;
- natural numbers (32-bit, `+`, `*` and `nat_of_float` modulo 2^32);
- integers (32-bit two's complement, the arithmetic, `int_of_nat` and
  `int_of_float` modulo 2^32; a literal outside [-2^31, 2^31) is refused);
- single-precision floats, booleans and tuples;
- datatypes without type parameters that are not recursive;
- `delay` and operation calls;
- self calls in tail position, which become loops;
- anonymous functions `fun p -> c` as values, also in boxes, tuples and the
  state of a periodic task, compiled by defunctionalisation (Reynolds,
  "Definitional interpreters for higher-order programming languages", 1972);
- tail-resumptive handlers.

The following are refused, each with a `Compilation error` at the
construct: local recursive functions, top-level functions and handlers as
values, partial application, datatypes whose constructors take functions, a
closure whose environment contains a closure of its own type, handlers that
are not tail-resumptive, lists, strings other than constant arguments of
operations, and recursion other than self calls in tail position, also
inside a closure.

### Tail-resumptive handlers

A handler is compiled if it is

- known at its `handle`: a top-level handler, possibly of first-order
  parameters such as `offset d`, or a handler written at the `handle` or
  bound by `let`, whose free variables become its parameters; and
- tail-resumptive: the continuation `k` of each operation case occurs only in
  resumptions `continue k with v` in tail position of every branch of the
  case, through `let`, `match`, `delay`, `box`, `unbox` and operation calls,
  and in neither the bound computations nor `v`.

Such handlers are the runners of Ahman and Bauer (ESOP 2020) without state:

    let offset (d : nat) =
      handler
      | x -> x
      | Read () k ->
          let v = perform Read () in
          continue k with v + d

A case that resumes its continuation twice or not at all, computes after the
resumption, or passes the continuation on is refused at the occurrence of
the continuation, or at the end of the branch that does not resume it; the
return case is not constrained.

Under a manifest, a handler written in a top-level definition of the
program's sources that the tasks do not reach is not refused when it is not
tail-resumptive. It is reported by a `Warning` at the same place, and the
project is written, since the interpreter can still run the handler (as the
handler `simulated_robot` of the BALA2 example with regexes). The handlers
of the standard library, of the packages and of `run` commands are not
checked.

The handlers are compiled by specialisation, with no indirect calls and no
allocation. As in the interpreter, they are deep: an operation calls the case
of the innermost handler of the operation, or its binding if no handler
handles it. An operation handled by a case is not a call of its binding and
is not monitored ([Monitors](#monitors)); see the examples
[`calibrated`](../../../examples/arduino/calibrated/calibrated.tpe) and
[`steps`](../../../examples/arduino/steps/steps.tpe).

#### Compilation of handlers
<!-- web-skip -->

The specialisation is as follows:

- each operation case becomes a C++ function of the parameters of the
  handler and the argument of the operation that returns the value of the
  resumption;
- the return case becomes a function applied to the result of the handled
  computation;
- each function, also of a closure, is compiled once for each instance of
  its type and each context of the handlers its operations reach, with the
  parameters of those handlers as further parameters; the operations of a
  closure thus go to the handlers around its application, as in the
  interpreter.

A case runs outside its handler: its own operations go to the handlers
outside it.

An operation that no code performs outside all handlers needs no binding.
See [`tests/arduino/handlers.tpe`](../../../tests/arduino/handlers.tpe).

### Typing of the tasks

The function of each periodic task is checked against its period: the
durations of its effect must lie below the period, as for
`step : float -> float ! [0, 20)`, and under the regular expressions of timed
operations for `watch : float -> float ! {ReadImu; Publish}`, whose durations
are those of the operations of its trace. Under grades that bound no
durations, such as the operation counts, the period is checked by the
monitor only, and the operations have no running-time bounds.

Boxes specify how long a reading may be used and, under other grades, which
operations must or may not precede its use. The examples under the regular
expressions of timed operations use their rigid variants
([Rigid regular expressions of timed operations](../../../README.md#rigid-regular-expressions-of-timed-operations)),
whose grades demand the operations they name, in their order.

## Monitors

### Guarantees of the typing

The typing is static and relative to the declared grades of the operations:
the effect grade of each computation is checked against the annotations of
the functions and the periods of the tasks, and each boxed value is unboxed
only within its box grade
([Temporal resources](../../../README.md#temporal-resources)). These
guarantees hold of the device provided each operation behaves as its
declared grade states.

### What the monitors check

The grades and the boxes are erased in the compiled code and cost nothing at
run time. The monitors are what remains of the grades, and check, where it
concerns time, the proviso that each operation behaves as its declared grade
states:

- the running time of each call of a binding function against the bounds of
  its operation on the board;
- the duration of each step of a periodic task against its period.

A run either satisfies the assumptions of the typing, or the monitors report
it.

The order and the number of the operations need no monitor, since the
compiled code performs exactly the operations the typed program performs.
An operation handled by a compiled case of a handler is not monitored: its
case is typed against the grade of the operation, and its own operations
are monitored.

### Monitor policy

A violation puts the device in its safe state and stops the tasks, is
logged, or is not checked, according to the monitor policy `abort` (the
default), `warn` or `off`.

On a board with a screen driven through M5Unified the violation is also
shown on the screen. Under `abort` the safe state is entered before the
violation is logged. On entering the safe state, by a violation or a
run-time error, a board with a speaker sounds a falling pair of tones, 1000
and 500 Hz, once, and the reason is logged again every 5 s while the device
is halted, so that a serial monitor connected later shows it. The log is written to the serial port from a buffer by a
task of its own, so that a timed call or step does not wait for the port; a
line logged while the buffer is full is dropped, and the lines dropped are
counted in the log.

Watchdogs, cut-offs and the safe state are mechanisms of the C++ packages and
of the application, outside the typing.

## Command line

    ./tempore --grades time-interval-rational \
      --emit-arduino balance \
      --device examples/arduino/bala2/balance.device.json \
      --host-simulate 8 \
      examples/arduino/bala2/balance.tpe

writes the PlatformIO project to `_arduino/projects/balance`, loading the
declarations of the packages of the manifest before the file, and simulates
it on the host for 8 seconds. A name without a directory component names a
directory in `_arduino/projects`. The options are:

- `--emit-arduino <directory>` writes the compiled program, and with
  `--device <manifest.json>` the project of the manifest;
- `--host-runs`, without `--device`, also compiles the `run` commands and a
  main program for the host that executes them;
- `--monitor abort|warn|off` sets the monitor policy (default `abort`);
- `--host-simulate <seconds>` builds the project on the host with `c++` and
  runs it for the given simulated time;
- `--build` builds the project with PlatformIO (`pio run`); `--upload` builds
  it and uploads it to the board (`pio run -t upload`), through the serial
  port `--port <port>` if given; each passes the output of PlatformIO through
  and exits with its exit code;
- `--pio <path>` names the PlatformIO executable, by default `pio` on the
  `PATH`, or else that of `_arduino/venv` in the directory of `tempore` or in
  the current directory, run with `PLATFORMIO_CORE_DIR` set to
  `_arduino/platformio` unless the environment sets it;
- `--profile` builds the project with the profile;
- `--capture <seconds>` reads the serial port (below);
- `--package <name>`, repeatable, loads the declarations of a package for the
  interpreter, which performs its operations by their default
  implementations; `--board <board>` gives them the running-time bounds of
  the packages on that board.

### Make targets

Each example `NAME` has the targets

- `make arduino-NAME-simulate`, the host simulation;
- `make arduino-NAME-build`, the PlatformIO build;
- `make arduino-NAME-upload`, the build and upload;
- `make arduino-NAME-profile`, the upload with `--profile`, then `--capture`;

and `bala2` and `bala2-regex` also

- `make arduino-NAME-log`, the upload with `-DBALANCE_LOG`, then `--capture`;
- `make arduino-NAME-record`, the upload with `-DBALANCE_RECORD`, then
  `--capture`;
- `make arduino-NAME-capture`, `--capture` without an upload, saving the
  recordings;

and `steps` the targets `-record`, `-capture` and `-erase` of
[Recording the step counter](#recording-the-step-counter).

`make arduino-simulate-all` and `make arduino-build-all` run the first two for
every example, and `make examples-help` lists the targets by board with the
values of their variables; `make arduino-diagnostics-help` lists likewise the
diagnostic targets, `-profile`, `-log`, `-record`, `-capture` and `-erase`. The targets that need PlatformIO install it by
`make arduino-deps` first. The variables, set on the command line or in the
environment, are

- `CAPTURE`, the time in seconds for which the port is read (default 30);
- `SIMULATE`, the simulated time of the host simulation (by default that of
  the example);
- `MONITOR`, the monitor policy (by default `abort`, and `warn` for the
  targets that read the port);
- `BRIGHTNESS`, when set, the brightness of the display, a percentage from 0
  to 100 (default 24), passed as `-DTEMPORE_DISPLAY_BRIGHTNESS` to every target that
  builds;
- `BALANCE_LOG` and `BALANCE_RECORD`, the intervals in milliseconds of the log
  and of the samples of a recording (default 20);
- `STEPS_RECORD`, the bound of the recordings of `steps`, in seconds
  (default 600);
- `PORT` and `PORT_BOARD`, the serial port (below).

### Ports

A target that opens the serial port of the board of the manifest (`-upload`,
`-profile`, `-log`, `-record`, `-capture`, `-erase`) uses `PORT` when it is
set, else the variable `PORT_BOARD`, the name of the board in upper case
with `-` replaced by `_`, when it is set, and else finds the port when it
runs. `PORT_M5STACK_GRAY_RADIO` defaults to `PORT_M5STACK_GRAY` and
`PORT_M5STACK_CORES3_RADIO` to `PORT_M5STACK_CORES3`.

The port is found by [`scripts/port.sh`](../../../scripts/port.sh) among
the serial ports listed by `pio device list --serial --json-output`, by the
USB identifiers `VID:PID` of the member `usb` of the board profile. The port
found is reported, as `M5Stack CoreS3 on /dev/cu.usbmodem1101`.
No matching port, several matching ports, as for two boards of the same
kind, and a profile without `usb`, such as `esp32-devkit`, are errors that
ask for `PORT` or `PORT_BOARD`:

    make arduino-bala2-upload PORT=/dev/ttyUSB0
    make arduino-tilt-profile PORT_M5STACK_CORES3=/dev/ttyACM0 CAPTURE=60

`make examples-help` shows each port variable, or the identifiers by which
the port is found; neither the help nor a dry run `make -n` lists the
ports.

### Fragments
<!-- web-skip -->

The targets are defined by
[`examples/examples.mk`](../../../examples/examples.mk) from a fragment
`example.mk` in the directory of the example, which holds one manifest
`PROGRAM.device.json` and its program `PROGRAM.tpe`.

The fragment sets the grades and the simulated time of the host simulation,
in seconds, and optionally the build flags of the targets `-log` and
`-record` and the awk program with which the target `-capture` extracts the
recordings from the serial output:

    EXAMPLE_GRADES = time-interval-rational
    EXAMPLE_SIMULATE = 8
    BALANCE_LOG ?= 20
    EXAMPLE_LOG_FLAGS = -DBALANCE_LOG=$(BALANCE_LOG)
    BALANCE_RECORD ?= 20
    EXAMPLE_RECORD_FLAGS = -DBALANCE_RECORD=$(BALANCE_RECORD)
    EXAMPLE_RECORD_FILTER = examples/arduino/bala2/recordings.awk

`EXAMPLE_BUILD_FLAGS` gives the build flags of every device build of the
example, as `-DTEMPORE_IMU_REST_SPREAD=25` for `bala2-radio-robot`. `EXAMPLE_LINK` and `EXAMPLE_LINK_ROLE` name the encrypted ESP-NOW
link of its device builds and the role of its board in it, as
`bala2-radio-robot` and `bala2-radio-controller` do
([Pairing the robot and the controller](#pairing-the-robot-and-the-controller)).

Instead of the awk program, `EXAMPLE_RECORD_TOOL` names a Python script by
which the targets `-capture` and `-erase` read and erase the recordings kept
on the device, as for `steps`.

[`tests/make/examples.t`](../../../tests/make/examples.t) checks that every
example has a fragment, that the targets its header names exist and run
under the grades of its run command, and that the targets
`arduino-bala2-simulate` and `arduino-bala2-profile` run the commands of
this file.

### Requirements
<!-- web-skip -->

PlatformIO Core, installed by `make arduino-deps`, and the other requirements
are listed under [Building](../../../README.md#building) in the main README.

## Measuring running times

With the build flag `TEMPORE_PROFILE`, set by `--profile`, the monitors
collect, since start-up,

- the number and the least, mean and greatest running time of the calls of
  each operation and of the steps of each periodic task;
- the least and greatest interval between the starts of consecutive steps;
- the overruns.

A task of the lowest priority logs them as a table every 5 seconds
(`TEMPORE_PROFILE_INTERVAL_MS`); under `--host-simulate` the table is logged
in place of the trace, every 5 simulated seconds and at the end.

The measurement does not lengthen what it measures. The trace of the build flag `TEMPORE_TRACE` (for example in
`PLATFORMIO_BUILD_FLAGS`), which logs each event, lengthens the steps by the
time of its serial output and is not suited to measurement.

    ./tempore --grades time-interval-rational \
      --emit-arduino balance-profile \
      --device examples/arduino/bala2/balance.device.json \
      --monitor warn --profile --upload --port /dev/cu.usbserial-02012C91 \
      --capture 60 \
      examples/arduino/bala2/balance.tpe

builds the project with the profile, uploads it, and reads the serial port
for 60 seconds, printing the last profile at the end.

### Reading the serial port

`--capture <seconds>`, with `--upload` and `--port`, reads the serial port
after the upload for the given time at the baud rate of the board, prints its
lines and, with `--profile`, then the last complete profile. Without
`--upload`, it writes the project and reads the port of a board already
programmed, without PlatformIO.

## Recording a run

The BALA2 examples record a run without the USB cable under the build flag
`BALANCE_RECORD` of
[`bala2/bindings.cpp`](../../../examples/arduino/bala2/bindings.cpp), the
interval of the samples in milliseconds. From the first start of the
balancing after start-up, the recording holds the tilt, the rate of the gyroscope, the speed
of the wheels, the reference tilt of the speed loop, the drives of the motors
and the counts of the encoders. Once complete, it is printed over the serial
port as CSV, repeatedly. It survives a reset, but not a loss of power.

### Recording and reading a run

    make arduino-bala2-record

builds and uploads the project `_arduino/projects/balance-record` and reads
the port for `CAPTURE` seconds. The robot then calibrates, starts balancing
and records
on the cable. To record a run without it, remove the cable and reset the
core with its power button, which starts a new recording at the next start;
the core keeps running on its battery.

After the run, with the core still on, connect the cable and run

    make arduino-bala2-capture CAPTURE=60

which reads the port for 60 seconds without an upload, and writes

- its output to `_arduino/recordings/bala2-TIME.log`, TIME the date and time;
- the last complete copy of each recording to
  `_arduino/recordings/bala2-TIME.csv`.

The targets `arduino-bala2-regex-record` and `arduino-bala2-regex-capture`
do the same for `bala2-regex`.

### Summarising a recording

The script
[`scripts/bala2-recording.py`](../../../scripts/bala2-recording.py), optional
and of the Python standard library only,

    python3 -I scripts/bala2-recording.py _arduino/recordings/bala2-TIME.csv

summarises each recording: the tilt, the reference tilt, the speed, the travel
of the wheels, the time of a fall beyond the cutoff, the difference of the
counts of the wheels and its drift, the fraction of the time each wheel is at
rest, and the correlation of the speed with the reference tilt.

## Recording the step counter

Under the build flag `STEPS_RECORD`, a bound in seconds,
[`steps/bindings.cpp`](../../../examples/arduino/steps/bindings.cpp) records
every reading of the unit, its time and its raw acceleration and angular
rate, and the events of the counter in the flash memory of the CoreS3, so
that the recordings persist across resets and losses of power; the program
and its grades are unchanged. Each calibration, at start-up and at each tap
on Calibrate, begins a new numbered recording; the screen shows "REC n", and
"FULL" once the recordings hold `STEPS_RECORD` seconds. The first start-up
of a record build formats the flash partition and restarts.

The procedure, with the cable connected:

    make arduino-steps-record
    make arduino-steps-erase       # erases the recordings on the device

Then, on the battery and without the cable: tap Calibrate, hold the device
still until the beep, walk for 20 seconds; tap Calibrate again, move the
device up and down for 20 seconds; and so on, one motion per recording.
Connect the cable and run

    make arduino-steps-capture

which reads the recordings from the device through
[`scripts/steps-recording.py`](../../../scripts/steps-recording.py) and
writes them to `_arduino/recordings/steps-TIME-N.csv`, N the number of the
recording, with the columns `t_ms`, `ax`, `ay`, `az` (g), `gx`, `gy`, `gz`
(degrees per second) and `event` (a count of steps, a reset, the start and
the end of a calibration), and the lines read to
`_arduino/recordings/steps-TIME.log`. `make arduino-steps-erase` erases the
recordings and restarts the device. With `STEPS_REPLAY=FILE`, the host
simulation of `steps` reads the accelerometer readings of a recording.

## Host simulation

Under `--host-simulate` the tasks run against host models of the devices and
of the physical world, in simulated time, and the log is printed. The exit
code is 3 if the tasks have halted, by a monitor or a run-time error, and 0
otherwise; without `--device`, a run-time error of the `run` commands ends
the program with exit code 3.

## Examples

The directory [`examples/arduino/`](../../../examples/arduino/) holds the
following examples, each with its manifest, binding file and fragment,
grouped by the board of their manifest. The header of each example describes
it and names its make targets.

### M5Stack Gray

The core of the M5Stack BALA2 self-balancing robot (profile `m5stack-gray`,
port variable `PORT_M5STACK_GRAY`; for `bala2-radio-robot`, which runs the radio,
profile `m5stack-gray-radio`, port variable `PORT_M5STACK_GRAY_RADIO`).

- [`bala2`](../../../examples/arduino/bala2/balance.tpe): a 5 ms balancing
  step of the robot with its supervision and calibration; the constant
  `balance_point` sets the tilt at which the robot is upright, and the build
  flags `BALANCE_LOG` and `BALANCE_RECORD` log and record a run
  ([Recording a run](#recording-a-run)). The typechecker proves, under the
  declared running times of the operations:
  - the control step finishes within its 5 ms period;
  - the motors are driven from a reading of the unit at most 2 ms old;
  - the balancing is started only with a calibration at least 1 s old;
  - the supervision renews its move within 200 ms, before it expires.
- [`bala2-regex`](../../../examples/arduino/bala2-regex/balance_regex.tpe):
  the same robot under the regular expressions of timed operations, which
  fix the order of the operations of its step and its supervision. The
  typechecker proves, under the declared running times of the operations:
  - the control step reads the unit, the encoders and the setpoints,
    publishes and drives the motors, each once and in this order, within
    its 5 ms period;
  - the motors are driven from a reading of the unit after which only the
    encoders and the setpoints are read;
  - the calibration stops the balancing before it reads the rates, each within
    10 ms of the last, with nothing in between;
  - the balancing is started at least 1 s after the message that asks for
    the robot to be held upright;
  - each move is sent again within 200 ms;
  - the supervision calibrates, starts, drives and stops, in this order.
- [`bala2-radio-robot`](../../../examples/arduino/bala2-radio-robot/robot.tpe):
  the robot of `bala2-regex` driven by the controller `bala2-radio-controller` over
  an encrypted ESP-NOW link, under the rigid regular expressions of timed
  operations; the grade of a session is its protocol, StartBalancing, moves
  and StopBalancing, in this order. The typechecker proves, under the declared running
  times of the operations:
  - the control step finishes within its 5 ms period;
  - each message received is acted on within 150 ms, before the next
    reception;
  - the balancing starts only with a calibration at least 1 s and at most
    10 minutes old, with no move since it was taken;
  - the tilt that decides the start is read less than 1 ms before it, with
    no reception or move in between;
  - the at-rest verdict of a calibration is used only after its samples,
    with no other operation in between;
  - each session is StartBalancing, then moves, then StopBalancing, in this
    order.
- [`wheels`](../../../examples/arduino/wheels/wheels.tpe): a wheel check of
  the robot on a stand, its speeds and spin-up times measured over windows of
  fixed traces. The typechecker proves, under the declared running times of
  the operations:
  - the step reads the unit and then publishes the tilt, within its 10 ms
    period;
  - a speed is computed only from counts read 100 to 101 ms after the drive
    command, with nothing in between;
  - a spin-up profile is computed only from readings each 19 to 21 ms after
    the last, following one drive command and nothing else.

### M5Stack CoreS3 and CoreS3 Lite

Profile `m5stack-cores3`, port variable `PORT_M5STACK_CORES3`; for
`bala2-radio-controller`, which runs the radio, profile `m5stack-cores3-radio`,
port variable `PORT_M5STACK_CORES3_RADIO`.

- [`tilt`](../../../examples/arduino/tilt/tilt.tpe): a tilt display, with a
  20 ms filter step and a display task. The typechecker proves, under the
  declared running times of the operations:
  - the step finishes within its 20 ms period;
  - the tilt shown was read less than 20 ms earlier.
- [`calibrated`](../../../examples/arduino/calibrated/calibrated.tpe): the
  tilt display with a gyroscope bias removed from every reading by a
  tail-resumptive handler, compiled to a direct call. The typechecker
  proves, under the declared running times of the operations:
  - the corrected reading takes no longer than a reading of the unit, so
    that every bound holds with the correction;
  - the step finishes within its 20 ms period;
  - the tilt shown was read less than 20 ms earlier.
- [`peak`](../../../examples/arduino/peak/peak.tpe): a recorder of the peak
  tilt in the flash memory, under the operation counts. The typechecker
  proves:
  - the step reads the unit once, publishes once and never writes the flash
    memory;
  - each iteration of the recorder writes the flash memory at most once;
  - a record read from the flash memory is shown only if no write came after
    its reading.
- [`level`](../../../examples/arduino/level/level.tpe): a digital level,
  under the regular expressions of timed operations, whose reference is
  applied only to readings that no reconfiguration of the unit precedes
  unchecked; its header describes its use. The typechecker proves, under the
  declared running times of the operations:
  - the step finishes within its 250 ms period;
  - a new reference is installed only after a check at rest, with no other
    operation in between;
  - a reference is applied only after readings of the unit and the touch
    screen, and after a reconfiguration of the unit only once a check finds
    it at rest;
  - the reading drawn is followed only by the reading of the touch screen;
    after a reconfiguration a new reading is drawn.
- [`fall`](../../../examples/arduino/fall/fall.tpe): a fall detector, a free
  fall and an impact within a second, with an alarm raised 10 to 30 seconds
  after a prompt that a tap cancels. The typechecker proves, under the
  declared running times of the operations:
  - a free fall is confirmed only by ten further readings, each 9.5 to
    10.5 ms after the last with nothing in between, and at least 100 ms
    after the first low reading;
  - a fall is reported only for an impact found within 1 s of the free fall;
  - the alarm is raised only after the prompt, its second line and a tone,
    and 10 to 30 s after them;
  - the raised alarm shows and sounds after every twenty polls of the screen
    50 ms apart, until a tap stops it.
- [`steps`](../../../examples/arduino/steps/steps.tpe): a step counter, under
  `operation-spacing`, which reads the unit at least every 50 ms and proves the
  counts at least 250 ms apart; under `-DSTEPS_RECORD` it records its
  readings ([Recording the step counter](#recording-the-step-counter)). The
  typechecker proves, under the declared running times of the operations:
  - while counting, the unit is read at least every 50 ms, also while the
    prompt of a reset is shown;
  - counts of steps start at least 250 ms apart, also across calibrations;
  - a calibration averages exactly 50 readings, 10 to 45 ms apart;
  - the counting starts at most 0.2 ms after the start of the beep that
    follows the drawing of the screen;
  - after a tap on a button, the touch screen is not read for 300 ms, so
    that a bounce is not taken for a second tap;
  - the beep that confirms a reset comes at once after the reset of the
    count, before any redraw of the screen.
- [`starter`](../../../examples/arduino/starter/starter.tpe): a sprint start
  system and false-start judge, the gun 1.5 to 3 s after Set and the start
  judged within a second of it. The typechecker proves, under the declared
  running times of the operations:
  - Set is commanded at least 1 s after On your marks;
  - the gun fires 1.5 to 3 s after Set;
  - the time of the gun is read at once after it, and the athlete is judged
    within 1 s of the gun;
  - the reaction time is measured only from polls in which each reading of
    the block is timed at once, with no pause above 2.5 ms;
  - a start with its outcome and the tally begins with On your marks and
    takes at most 6 s.
- [`bala2-radio-controller`](../../../examples/arduino/bala2-radio-controller/controller.tpe):
  the controller of [`bala2-radio-robot`](#m5stack-gray), driving the robot by the
  tilt of the device and starting and stopping it by touch, under the rigid
  regular expressions of timed operations. The typechecker proves, under the
  declared running times of the operations:
  - every message to the robot follows the previous one within 50 ms, in
    every phase;
  - it drives only on a robot status received within the last 200 ms, from
    a tilt read within the last 2 ms;
  - the neutral tilt of a session is used only within that session, before
    its Stop;
  - each session is Beat, then Start 80 times and until the robot confirms,
    then Drive or Beat, then Stop 20 times.

#### Pairing the robot and the controller

The robot and the controller share the encrypted link `bala2-radio`. Each
pair of boards has a link file in `~/.config/tempore/links`, outside the
repository, of mode 600 in a directory of mode 700: `bala2-radio` for the
default pair, `bala2-radio-PAIR` for the pair `PAIR`. It holds the key and
the address of the board of each role:

    key=0123456789abcdef0123456789abcdef
    robot=XX:XX:XX:XX:XX:XX
    controller=YY:YY:YY:YY:YY:YY

Every target of the two examples that builds for the device runs
`scripts/link.sh` first, which passes the address of the other board and
the key of the pair as `ESP_NOW_PEER` and `ESP_NOW_KEY`, without showing
the key:

- an upload, profile, log or record target reads the address of the
  board on its port, finds the link file that records it, and records a
  new board; a build without an upload reads no port and takes the default
  pair, or `PAIR`;
- an absent key is generated, 16 random bytes;
- without the address of the other board the build stops, and names the
  board to connect and the target to run first.

One pair needs no setting. The first pairing, one board at a time:

1. connect the robot and run `make arduino-bala2-radio-robot-upload`: it
   records the address of the robot and the key, and stops;
2. connect the controller and run `make arduino-bala2-radio-controller-upload`:
   it records its address and uploads;
3. connect the robot again and run `make arduino-bala2-radio-robot-upload`.

With several pairs, each known board finds its pair by its address. A new
board joins the default pair while that has no board of its role;
otherwise the build stops, naming the board recorded, until it is run with
one of

- `PAIR=<name>`, of letters, digits, `-` and `_`, which starts or joins
  the pair of that name: the three uploads of the first pairing, each with
  `PAIR=2`, pair a second robot and controller, with a key of their own;
- `REPLACE=1`, which replaces the board of its role in the default pair;
  an upload to the other board then gives it the new address.

A board of a named pair is replaced by an upload with its `PAIR`, without
`REPLACE=1`. A board recorded in several link files, or as the board of
the other role, stops the build.

A board recorded in another pair is not moved to the pair of `PAIR` or
`REMOTE_LINK_FILE`: the build stops, naming both link files, unless it is
run with `MOVE=1`, which records the board in the link file chosen and
removes it from the other. `PAIR`, `REPLACE`, `MOVE` and `REMOTE_LINK_FILE`
set in the environment rather than on the make command line are reported
by every build of the link. Other choices:

- `REMOTE_LINK_DIR` sets the directory of the link files, and
  `REMOTE_LINK_FILE` one link file for every board, without the search by
  address;
- `REMOTE_PEER`, an address `XX:XX:XX:XX:XX:XX`, and `REMOTE_KEY`, 32
  hexadecimal digits, override the address of the other board and the key;
- on another computer, copy the link files, which keep the pairings.

The build reports the link file and the reason for it, and what it
records, never the key; a malformed link file or override stops it. With
one board of each kind connected at a time, the ports are found by their
USB identifiers ([Ports](#ports)).

#### Using the remote-controlled robot

1. Switch on the controller, at any time; it shows "Encrypted" and, while
   no status arrives, "Switch robot on".
2. Switch on the robot and hold it upright and still. It calibrates,
   "Hold upright" on the controller ("Hold still" while it moves), and
   sounds one tone when it is ready.
3. With "Now tap Start" shown, tap Start, within about 200 s of the
   tone; a high tone acknowledges the tap. The robot starts only upright,
   within 10 degrees of its balance point, and then balances.
4. Tilt the controller from the tilt at the tap: forwards drives the robot
   forwards, to the right turns it to the right; the bubble moves in the
   direction of the tilt.
5. Tap Stop; a low tone acknowledges the tap, the robot stops its
   motors, and it calibrates again for the next session.

When the wait for Start ends without one, the robot calibrates again. When
no message arrives for about 2 s, as when the controller is switched off,
the robot sounds one tone and keeps balancing in place, with zero
setpoints, until a message arrives.

A violated running-time bound halts the robot with its lights on and a
falling pair of tones, and its reset button restarts it. A robot that falls with its lights off has a
battery too weak for the motors, charged through the USB-C port of the Gray.

## Adding a board, a package or an example
<!-- web-skip -->

- A board is a profile `boards/NAME.json`.
- A package is a directory `libraries/NAME/` with a descriptor
  `package.json`, which maps each grade system to a file of declarations and
  may name a file of definitions, give running-time bounds per board and
  name, by `packages`, the packages whose operations it performs, which a
  program lists before it, and the declarations, C++ sources and host
  models.
- An example is a directory under `examples/arduino/` with a program
  `PROGRAM.tpe`, its manifest `PROGRAM.device.json`, a binding file, host
  models for the simulation if needed, and a fragment `example.mk`
  ([Fragments](#fragments)). Its header names its make targets.

Boards and packages are embedded in the compiler when it is built.
