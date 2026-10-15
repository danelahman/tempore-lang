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
of the serial port and the capabilities of a board (`imu`, `display`,
`touch`, `speaker`, `battery`, ...). The profiles are `m5stack-gray`,
`m5stack-fire`, `m5stack-core2`, `m5stack-cores3`, `esp32-devkit` and
`esp32s3-devkit`.

The I2C buses of a profile are started after M5Unified and then set to their
frequency, since M5Unified may already have started a bus that shares their
port at 100 kHz.

On a board with M5Unified and the capability `display`, the brightness of
the display is set once at start-up, after the initialisation of M5Unified
and of the packages and before the tasks of the manifest are created, to the
build flag `TEMPORE_DISPLAY_BRIGHTNESS`, a percentage from 0 to 100 of the
greatest brightness, and to 24 % without it, below the default of M5Unified,
50 %. On the CoreS3 the percentage sets the voltage of the backlight in nine
steps, from 2.5 V for 1 to 11 % to 3.3 V for 100 %, 0 switching it off;
24 % gives 2.6 V. The host simulation ignores it.

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
the state its `initial` function returns, and after a missed release, as
after an overrun, a period after the end of the late step; a free task calls its function, of
type `unit -> unit`, once, or, with `repeat`, each time it returns, after a
wait of one tick, so that the idle task of its core runs also when the
function waits only actively, as for a delay below a millisecond.

With `"battery": true`, on a board with the capabilities `display` and
`battery` (the M5Stack cores), the scaffold draws the charge of the battery,
`Battery 87%`, followed by `+` while it charges, in grey in the top right
corner of the screen, outside the program. A task of priority 1 reads the
gauge every 5 seconds under the I2C lock, and redraws the text when it
changes or when a drawing of `m5-display` covers the corner. The examples on
the CoreS3 enable it.

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
`event-separation`, with running-time bounds in milliseconds, and under
`counts-upper-bound`, each call counting once.

### The packages

- `i2c`: `I2cWrite8`, `I2cWrite16`, `I2cWrite32`, `I2cRead8`, `I2cRead16` and
  `I2cRead32`, register transactions on the bus `Wire`.
- `m5-imu`:
  - `ReadImu`, the accelerometer and gyroscope of an M5Stack core, with the
    tilt filters `tilt_x` and `tilt_y`. A unit of the MPU6886 family is read
    in one transaction of 14 bytes and converted as by M5Unified. Any other
    unit, such as the BMI270 of the CoreS3, is read by one `M5.Imu.update`
    followed by `M5.Imu.getImuData`, which converts the readings of that
    update without the further update of `M5.Imu.getAccel` and
    `M5.Imu.getGyro` when more than 256 µs have passed since the last one.
  - `ConfigureImu` sets the output data rate of the accelerometer without
    changing its range (the register ACC_CONF of the BMI270, the sample rate
    divider of the MPU6886), so that the conversion of M5Unified stays valid.
  - `CheckAtRest` is a check of plausibility, not a self-test: four readings
    started 6 ms apart, true if the unit is at rest.
  - Each reading of `ReadImu` is passed to `m5_imu_observe(accel, gyro)`,
    defined weakly to do nothing, which an application may define to record
    the readings.
- `m5-display`, with colours of 24 bits, `0xRRGGBB`:
  - `ShowText`, `ShowNumber` and `ClearDisplay`, lines of text of size 2
    written one below another;
  - `ShowTextAt` and `ShowNumberAt`, a text or a number written at a position
    in a size from 1 to 4 over a band of the display filled first, so that it
    replaces the text of that band without a clearing, the next line
    following below it; the text is centred vertically in the band, with a
    left margin of 3 times the size in pixels on a band not black;
  - `ShowTimeAt`, a text followed by a duration as m:ss;
  - `ShowColourTextAt`, a text in a colour over a band of another;
  - `ShowColourNumberAt`, a number in a colour over a band of another;
  - `DrawButton`, a button with a centred label;
  - `DrawBar`, a horizontal bar filled to a length;
  - `DrawLevel`, a bubble level, a vial with a bubble at an offset from its
    centre, redrawn only when the bubble moves or changes colour.
- `m5-touch`: `ReadTouch`, whether the screen is touched and where, read
  through `M5.Touch.update` under the I2C lock (the touch screens of the
  CoreS3 and the Core2, capability `touch`).
- `m5-speaker`: `Beep`, which starts a tone of a frequency and a duration on
  the speaker and returns at once (capability `speaker`). Each tone is passed
  to `m5_speaker_observe(frequency, duration)`, defined weakly to do nothing,
  as `m5_imu_observe` is, on the device and in the host simulation.
- `bala2-base`: `SetMotors`, `ReadEncoders` and `ResetEncoders` of the base of
  the M5Stack BALA2, with a watchdog of the motor setpoints. The counts of the
  encoders increase in the direction in which a positive drive turns the
  wheel (the registers of the base count the other way, and the package
  negates them). Its header `bala2_base.h` gives the application the drives
  last written and the counts last read, for logging outside the timed
  bindings.

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
regular expressions of timed operations and `event-separation`.

- The program is typed, and the monitors are generated, under the bounds of
  its board.
- An interpreter run with `--package` takes those of the board named by
  `--board`, and else those of the declarations; the web interface takes
  those of the board of its manifest.
- Each board and operation of `bounds` must be a board profile and an
  operation the package binds.
- The default implementations take a time within the bounds of every board.
- The examples name the board of their manifest by `--board` in the run
  command of their header, and the figures in their comments are those under
  its bounds.

### How the bounds are measured

The bounds of the packages and of the examples are measured on the devices
by their profile ([Measuring running times](#measuring-running-times)): the
lower bound is the least time measured, rounded down, and the upper bound 1.5
times the greatest, rounded up. Each declaration states its measurements and
how the bounds not measured directly, such as those of `i2c`, are derived.

- The bounds of `ConfigureImu`, `CheckAtRest`, `ReadTouch` and `Beep` are
  measured on the CoreS3 only.
- The least times of `ShowTextAt` and `ShowNumberAt` depend on the text, so
  their lower bound is that of `ShowText`.
- The bounds of `ShowTimeAt`, `ShowColourTextAt`, `ShowColourNumberAt`,
  `DrawButton`, `DrawBar` and `DrawLevel` are provisional, derived from those
  measurements; `ShowColourNumberAt` has the bounds of `ShowNumberAt`.

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
top-level definition is checked and compiled, with its `run` commands under
`--host-runs`.

### The fragment

The fragment consists of

- top-level functions, fully applied;
- `let`, `match` and `if`;
- natural numbers (32-bit, `+`, `*` and `nat_of_float` modulo 2^32);
- integers (32-bit two's complement, the arithmetic, `int_of_nat` and
  `int_of_float` modulo 2^32 into [-2^31, 2^31), so that
  `-2147483648i /! -1i` is `-2147483648i`; a literal outside that range is
  refused);
- single-precision floats, booleans and tuples;
- datatypes without type parameters that are not recursive;
- `delay` and operation calls;
- self calls in tail position, which become loops;
- anonymous functions `fun p -> c` as values, also in boxes, tuples and the
  state of a periodic task, compiled by defunctionalisation (Reynolds,
  "Definitional interpreters for higher-order programming languages", 1972):
  a closure is a struct with a tag, which names its function among those of
  its type, and the values of its free variables, and an application calls
  the function of the tag;
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

#### Compilation of handlers

The handlers are compiled by specialisation, with no indirect calls and no
allocation:

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

As in the interpreter, the handlers are deep and a case runs outside its
handler. An operation performed inside a `handle`, also in the functions it
calls, calls the case of the innermost handler of the operation, whose own
operations go to the handlers outside it, or the binding of the operation if
no handler handles it.

An operation handled by a case is not a call of its binding and is not
monitored ([Monitors](#monitors)); an operation that no code performs
outside all handlers needs no binding. See
[`tests/arduino/handlers.tpe`](../../../tests/arduino/handlers.tpe) and the
examples [`calibrated`](../../../examples/arduino/calibrated/calibrated.tpe)
and [`steps`](../../../examples/arduino/steps/steps.tpe).

### Typing of the tasks

The function of each periodic task is checked against its period: the
durations of its effect must lie below the period, as for
`step : float -> float # [0, 20)`, and under the regular expressions of timed
operations for `watch : float -> float # {ReadImu; Publish}`, whose durations
are those of the operations of its trace. Under grades that bound no
durations, such as the operation counts, the period is checked by the
monitor only, and the operations have no running-time bounds.

Boxes specify how long a reading may be used and, under other grades, which
operations must or may not precede its use.

The examples under the regular expressions of timed operations use their
rigid variants and write a grade as one expression, which is both bounds:

- the operations it names are demanded, in its order;
- the delays between them are bounded below and above;
- another operation may come between them only within a delay, at the upper
  bound of its running time, and not within a strict delay `!d`;
- a Kleene star of rounds permits these rounds only.

A box grade without delays therefore excludes every operation it does not
name, while a box grade with a delay bounds the time, and the operations
within it only by their running times. These guarantees are relative to the
declared bounds of the operations.

## Monitors

### Guarantees of the typing

The typing is static and relative to the declared grades of the operations.
The effect grade of each computation, accumulated from the grades of its
operations and delays, is checked against the annotations of the functions
and the periods of the tasks.

Each boxed value, of a type `[ρ]A`, is unboxed only after a computation
whose grade since the boxing lies below `ρ`:

- under the time grades, within its window of time;
- under the regular expressions, only after the operations they admit, in
  the order they admit;
- under the operation counts, after at most the operations they count.

These guarantees hold of the device provided each operation behaves as its
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
shown:

- under `abort`, a red banner across the middle of the screen, drawn once
  the safe state is entered;
- under `warn`, a yellow line above the footer, with the number of the
  warnings and the last of them, drawn every 500 ms by a task of the lowest
  priority.

Under `abort` the safe state is entered before the violation is logged. The
log is written to the serial port by a task of priority 1 from a buffer of 32
lines (`TEMPORE_LOG_LINES`), so that a timed call or step does not wait for
the port, whose transmit buffer is 1024 bytes (`TEMPORE_SERIAL_TX_BUFFER`). A
line logged while the buffer is full is dropped, and the number of the lines
dropped is logged.

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
- `--build` builds the project with PlatformIO; `--upload` builds it and
  uploads it to the board, through the serial port `--port <port>` if given;
  `--pio <path>` names the PlatformIO executable;
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

An upload goes to the serial port `PORT` when it is set, and else to that of
the board of the manifest, the variable `PORT_BOARD`, the name of the board
in upper case with `-` replaced by `_`.

`PORT_M5STACK_GRAY` defaults to `/dev/cu.usbserial-02012C91` and
`PORT_M5STACK_CORES3` to `/dev/cu.usbmodem101`, the ports of the boards of
the development machine. A board without a default port, such as
`esp32-devkit`, needs `PORT` or `PORT_ESP32_DEVKIT`:

    make arduino-bala2-upload PORT=/dev/ttyUSB0
    make arduino-tilt-profile PORT_M5STACK_CORES3=/dev/ttyACM0 CAPTURE=60

### Fragments

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

Instead of the awk program, `EXAMPLE_RECORD_TOOL` names a Python script by
which the targets `-capture` and `-erase` read and erase the recordings kept
on the device, as for `steps`.

[`tests/make/examples.t`](../../../tests/make/examples.t) checks that every
example has a fragment, that the targets its header names exist and run
under the grades of its run command, and that the targets
`arduino-bala2-simulate` and `arduino-bala2-profile` run the commands of
this file.

### Requirements

- `make arduino-deps` installs PlatformIO Core 6.2.0 in the virtual
  environment `_arduino/venv`, with the first Python of version 3.10 or
  later; without `--pio`, `pio` on the `PATH` is used, or else that of
  `_arduino/venv`;
- PlatformIO keeps its platforms, toolchains and libraries in
  `PLATFORMIO_CORE_DIR`, set to `_arduino/platformio` for the `pio` of
  `_arduino/venv` unless the environment sets it; after building the
  examples, `_arduino` takes about 3 GB, and `make clean-arduino` removes it;
- the first build of a board downloads its platform and toolchain;
- uploading needs the USB-serial driver of the board: its port is listed by
  `ls /dev/cu.*` on macOS once the board is connected.

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

The statistics are updated after the clock is read and the table is printed
outside the timed calls, so that the measurement does not lengthen what it
measures. The trace of the build flag `TEMPORE_TRACE` (for example in
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

The port is opened in raw mode with its modem
control lines as opening it sets them, both asserted, which on the boards
with an automatic reset circuit holds neither the reset nor the boot pin, and
they are left so when it is closed.

## Recording a run

The BALA2 examples record a run without the USB cable under the build flag
`BALANCE_RECORD` of
[`bala2/bindings.cpp`](../../../examples/arduino/bala2/bindings.cpp), the
interval of the samples in milliseconds.

### The recording

From the first arming after start-up, a task of core 0 takes 3000 samples
(`BALANCE_RECORD_SAMPLES`), a minute at 20 ms, of the tilt, the rate of the
gyroscope, the filtered speed of the wheels, the reference tilt of the speed
loop, the drives of the motors and the counts of the encoders; the control
step only publishes the values.

Once complete, the recording is printed over the serial port as CSV every 10
seconds (`BALANCE_RECORD_REPEAT_MS`), between a line
`# Recording N, run ID, ...` and a line `# End of recording N`, N its
sequence number and ID a random identifier drawn at the arming.

The core keeps running on its battery when the cable is removed, the
USB-serial bridge of the M5Stack Gray being powered by USB, so that the
recording is read once the cable is connected again.

The recordings of the last two start-ups are kept in memory that is not
initialised at start-up: a recording survives a reset, such as one by the
serial port or a brownout, and is then printed with the recording of the new
start-up, but not a loss of power.

### Recording and reading a run

    make arduino-bala2-record

builds and uploads the project `_arduino/projects/balance-record` and reads
the port for `CAPTURE` seconds. The robot then calibrates, arms and records
on the cable. To record a run without it, remove the cable and reset the
core with its power button, which starts a new recording at the next arming.

After the run, with the core still on, connect the cable and run

    make arduino-bala2-capture CAPTURE=60

which reads the port for 60 seconds without an upload, and writes

- its output to `_arduino/recordings/bala2-TIME.log`, TIME the date and time;
- the last complete copy of each recording to
  `_arduino/recordings/bala2-TIME.csv`; a copy takes about 11 seconds at
  115200 baud.

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
that the recordings persist across resets and losses of power. The readings
reach it through `m5_imu_observe`, a function of the package `m5-imu` that
an application may define; the program and its grades are unchanged.

- Each calibration, at start-up and at each tap on Calibrate, begins a new
  numbered recording; the screen shows "REC n" in red at the right end of
  the row 134, and "FULL" once the recordings hold `STEPS_RECORD` seconds,
  after which nothing more is recorded.
- A record takes 16 bytes, about 1.6 KB a second; the records are buffered
  in RAM and written to the data partition `spiffs` a page at a time, after
  a reading, so that the programming of the flash memory, which stops both
  cores for under a millisecond a page, falls between the readings.
- The first start-up of a record build formats the partition, which stalls
  the readings for about 15 seconds, and restarts. Each start-up logs its
  reset reason.

The procedure, with the cable connected:

    make arduino-steps-record
    make arduino-steps-erase       # clears the earlier recordings

Then, on the battery and without the cable: tap Calibrate, hold the device
still until the beep, walk for 20 seconds; tap Calibrate again, move the
device up and down for 20 seconds; and so on, one motion per recording.
Connect the cable and run

    make arduino-steps-capture

which asks the device for its recordings through
[`scripts/steps-recording.py`](../../../scripts/steps-recording.py) and
writes them to `_arduino/recordings/steps-TIME-N.csv`, N the number of the
recording, with the columns `t_ms`, `ax`, `ay`, `az` (g), `gx`, `gy`, `gz`
(degrees per second) and `event` (a count of steps, a reset, the start and
the end of a calibration), and the lines read to
`_arduino/recordings/steps-TIME.log`. The device answers a command line,
sent again until the first line of the answer arrives, so that a reset by
the opening of the port does not matter. Each line of the dump carries a
CRC-16 and is written once the transmit buffer of the port has room for
it; a recording that arrives damaged or incomplete is requested again by
its number. `make arduino-steps-erase` erases the recordings and restarts
the device. With `STEPS_REPLAY=FILE`, the host simulation of `steps` reads
the accelerometer readings of a recording.

## Host simulation

Under `--host-simulate` the tasks run against host models of the devices and
of the physical world, in simulated time, and the log is printed. The host
model of the I2C bus charges a transaction with the transfer of its bytes at
the frequency of the bus and a time per address phase measured on the
M5Stack Gray, 110 µs unless the build flag `TEMPORE_I2C_MODEL_PHASE_US` sets
it.

## Examples

The directory [`examples/arduino/`](../../../examples/arduino/) holds the
following examples, each with its manifest, binding file and fragment,
grouped by the board of their manifest.

### M5Stack Gray

The core of the M5Stack BALA2 self-balancing robot (profile `m5stack-gray`,
port variable `PORT_M5STACK_GRAY`).

- [`bala2`](../../../examples/arduino/bala2/balance.tpe): a 5 ms balancing
  step of the robot with its supervision and calibration, and the host model
  of a wheeled inverted pendulum.
  - The constant `balance_point` sets the tilt at which the robot is upright.
  - The build flag `BALANCE_LOG` logs the tilt, the gyroscope rate, the
    drives and the encoder counts from a task of the lowest priority, whose
    start, outside the bounds of `Publish`, the target `-log` reports under
    the monitor policy `warn`.
  - The build flag `BALANCE_RECORD` records them, with the speed and the
    reference tilt of the speed loop ([Recording a run](#recording-a-run)).
- [`bala2-regex`](../../../examples/arduino/bala2-regex/balance_regex.tpe):
  the same robot under the regular expressions of timed operations, sharing
  the binding file and host model of `bala2`.
  - The step reads the unit, the encoders and the setpoints before it
    commands the motors, and uses the reading of the unit only if no command
    of the motors and no delay came between, across any number of reads of
    the encoders and setpoints.
  - The bias is measured from readings of the attitude at most 10 ms apart,
    with no other operation between.
  - The supervision disarms, calibrates, arms at least a second after its
    prompt, drives and disarms, in this order.
  - Handlers, which the device does not use, simulate the robot and a fault
    of its gyroscope in the interpreter, each case of an operation performing
    that operation.
- [`wheels`](../../../examples/arduino/wheels/wheels.tpe): a wheel check of
  the robot on a stand, under the regular expressions of timed operations.
  - The counts of the encoders are divided by the length of the window only
    after a drive command, 100 to 101 ms and a reading of the encoders, in
    this order.
  - A spin-up profile samples the encoders after the drive command, each
    sample after a wait of 19 to 21 ms with no other operation, and shows
    the time of each wheel to reach 90 % of its final speed.

### M5Stack CoreS3 and CoreS3 Lite

Profile `m5stack-cores3`, port variable `PORT_M5STACK_CORES3`.

- [`tilt`](../../../examples/arduino/tilt/tilt.tpe): a tilt display, with a
  20 ms filter step and a display task.
- [`calibrated`](../../../examples/arduino/calibrated/calibrated.tpe): the
  tilt display with a gyroscope bias measured at start-up and removed from
  every reading by a tail-resumptive handler around the step, whose case of
  `ReadImu` is checked against the grade of the operation and compiled to a
  direct call; its host model holds the unit at rest with a biased
  gyroscope.
- [`peak`](../../../examples/arduino/peak/peak.tpe): a recorder of the peak
  tilt in the flash memory, under the operation counts: the step performs one
  reading and one publication and no write of the flash, and a copy of the
  record is used only while no write of the flash has followed it.
- [`level`](../../../examples/arduino/level/level.tpe): a digital level,
  under the regular expressions of timed operations: a bubble vial, the pitch
  and the roll less the offsets of a reference, the button "Set reference"
  and the sensor button, labelled with the current and the next rate.
  - A reference is taken after the unit is held still for a second and
    installed only after a check at rest.
  - The reconfiguration of the unit keeps it only after a new check at
    rest, with no operation between.
  - It is applied only to a reading that no reconfiguration or new reference
    precedes within its 250 ms step, and expires after 30 seconds.
- [`fall`](../../../examples/arduino/fall/fall.tpe): a fall detector, under
  the regular expressions of timed operations.
  - A free fall of at least 100 ms followed within a second by an impact is
    a fall; it is confirmed from readings alone, each after a wait of 9.5
    to 10.5 ms.
  - After a fall, a prompt, in orange, a tone and a countdown of 10 seconds
    with a shrinking bar precede the alarm, in red, raised only 10 to 30
    seconds after the prompt unless a tap cancels, sounding a tone every
    second until a tap stops it.
  - While watching, in green, the screen shows the falls counted, the time
    since the last event and a bar of the acceleration.
- [`steps`](../../../examples/arduino/steps/steps.tpe): a step counter,
  under `event-separation`: one loop reads the unit at least every 50 ms
  and the touch screen while it redraws the screen, one band per round: the
  state, the steps, the prompt of a reset, the Reset button, the cadence,
  the distance at a stride of 0.7 m, and a bar of the smoothed magnitude of
  the acceleration with its thresholds. Two buttons of 156 by 40 pixels, "Calibrate" and
  "Reset", fill the band above the footer; a touch counts for a button when
  it begins inside it, and elsewhere does nothing.
  - At start-up and at each tap on Calibrate, with "Hold still" shown, the
    Calibrate button active and no step counted, 50 readings 10 to 45 ms
    apart give the gain and the direction of gravity. The number of samples
    is boxed with exactly these readings, and the calibration then with the
    beep that starts the counting; each box is returned by the function
    that binds it. A tail-resumptive handler, applied for each session of
    counting, applies the gain to every reading. The steps are kept from
    one session to the next, and the loop of the sessions proves the counts
    250 ms apart across the calibrations.
  - The step signal is the magnitude of the acceleration, smoothed by two
    exponential moving averages, less its slow mean, so that no orientation
    is assumed. A step is a rise of the signal through a hysteresis of
    0.35 times its root mean square, at least 0.03 g, decided at the second
    reading of a round, boxed 10 to 45 ms after the first, a new sample of
    the unit at 100 Hz, its time read by the operation `ReadClock` within
    0.1 ms of the decision.
  - A rise in a motion along a line, the effective dimension of the recent
    covariance of the acceleration below 1.4, is no step and ends the run,
    so that moving the device up and down, bouncing or shaking it counts
    none.
  - A rise within 0.25 s of the last is ignored, a gap above 1.5 s ends the
    run, and a gap outside 0.5 to 1.5 times the last restarts it; steps
    count after a run of four, then added at once. The host model plays
    these motions and walks, and replays recordings.
  - Each count goes through the operation `CountStep` of the example and is
    followed by a cooldown of twelve rounds, so that the typechecker proves
    the counts at least 250 ms apart.
  - A tap on Reset shows "Tap Reset again to reset", with the button
    active; a second tap on Reset within 2 s, at least 300 ms after the
    first, resets the count through `ResetSteps`, and a tap on Calibrate
    clears the prompt. The button of the first tap is boxed over the
    recursive wait, which reads the unit at least every 50 ms; the steps
    found meanwhile are passed to `CountStep` with the next count. The
    confirming tap beeps, the counter boxed with the beep before any band
    of the screen is redrawn.
  - The operation `ShowButton` of the example draws a button, idle or
    active.
  - The handler `walk`, not compiled, replays a walk in the interpreter.
  - Under `-DSTEPS_RECORD` the readings and the events are recorded in flash
    memory ([Recording the step counter](#recording-the-step-counter)).
- [`starter`](../../../examples/arduino/starter/starter.tpe): a sprint
  starter and false-start judge, under the regular expressions of timed
  operations.
  - The protocol of a start is three boxes nested in each other, each holding
    a closure that creates the next: Set at least a second after On your
    marks, the gun 1.5 to 3 s after Set, and the athlete judged within half
    a second of the gun.
  - The gun follows the Set command after a hold of 80 polls and as many
    further polls as the clock gives, 1576 to 2919 ms; the time of the gun is
    read at once, with no operation between.
  - A box over the reaction window admits the reaction time only after
    nothing but polls, each reading stamped at once and taken at most 2.5 ms
    after the last stamp, so that a push is seen within about 4 ms; no push
    in 100 polls, 270 to 405 ms, is a start without a push.
  - The session consists of rounds of a poll of the touch screen followed by
    a start, a reset or a wait of 50 ms.
  - A reaction under 100 ms or a movement in Set is a false start: a warning
    for the first, a disqualification for the second. "Stand up" abandons a
    start before the gun, and "Reset" clears the tally.
  - The host model observes the tones of the Set command and of the gun
    through `m5_speaker_observe` and scripts the pushes after them.

#### Using the digital level

1. Place it on the surface taken as the reference and tap "Set reference".
   It asks to hold still, and a second later reads the unit and checks that
   it is at rest, with a high tone, or rejects the reference as moved during
   the check, with a low tone.
2. Placed on another surface, it then shows the angles relative to the
   reference, the bubble green and "LEVEL" within half a degree.

The reference becomes invalid, and must be set again,

- when it is rejected;
- when the sensor button reconfigures the unit, which switches the output
  data rate of its accelerometer between 100 and 400 Hz, the current and the
  next rate shown on the button (`Sensor 100->400Hz`);
- when it expires 30 seconds after it was set, its time left shown
  meanwhile.

Without a valid reference the bubble is grey and the angles are those of the
unit.

#### Name and footer

The CoreS3 examples show their name at the top of the screen, in text of
size 2, and a footer at the bottom right, in text of size 1, by
`ShowTextAt`: the line "Typechecked by Tempore (tempore-lang.ee)" at the
column 320 − 6 · 40 = 80 of its 40 characters of 6 pixels. In `level`,
`fall` and `steps` the footer is below a line of size 1 under the name that
states the guarantee of the example.

The name and the footer are drawn after each clearing in `tilt`, `peak`,
`fall` and `steps`, outside their boxes, and once by the initial function in
`level`, which redraws its values by bands and does not clear.

## Adding a board, a package or an example

- A board is a profile `boards/NAME.json`.
- A package is a directory `libraries/NAME/` with a descriptor
  `package.json`, which maps each grade system to a file of declarations and
  may name a file of definitions and give running-time bounds per board, and
  the declarations, C++ sources and host models.
- An example is a directory under `examples/arduino/` with a program
  `PROGRAM.tpe`, its manifest `PROGRAM.device.json`, a binding file, host
  models for the simulation if needed, and a fragment `example.mk`
  ([Fragments](#fragments)). Its header names its make targets.

Boards and packages are embedded in the compiler when it is built.
