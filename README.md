# <picture><source media="(prefers-color-scheme: dark)" srcset="web/logo/tempore-logo-dark.svg"><img src="web/logo/tempore-logo.svg" alt="" width="40" height="40" align="top"></picture> Tempore Language

Tempore (as in *in tempore*, Latin for "in good time") is a prototype
programming language that combines graded modal types with graded effects to
specify and statically verify temporal properties of resources that programs
manipulate, such as that a resource is used only *when* its type-based
specification deems it safe. These properties are checked automatically by
a typechecker based on Hindley–Milner style type and grade inference.

Tempore grew out of Temporal Millet, which was implemented in [Joosep
Tavits](https://github.com/joosepgit)'s Master's thesis at the University of
Tartu ([code](https://github.com/joosepgit/temporal-millet),
[thesis](https://thesis.cs.ut.ee/1c038012-af0d-444a-95dc-7ffc8b3a1f20)).

Most notably, Tempore adds to Temporal Millet the following:

1. temporal algebraic effects and effect handlers that are guaranteed to
   respect the temporal specifications of operations,
2. [general resource grades](#grading-monoids) in place of only
   natural-number-based time grades, which modelled only whole lower time bounds
   of programs,
3. a number of concrete examples of such grades (ranging from time to regexes to
   security levels to trough/peak usage of resources),
4. a cleaner and more systematic treatment of type inference,
5. [multiple backends](#backends): besides the interpreter, proof-of-concept
   compilers of programs to protocols for Opentrons liquid-handling robots and
   to C++ for Arduino and ESP32 boards, with run-time monitors of the running
   times of operations, and
6. various usability improvements in the web-based user interface.

Tempore (and Temporal Millet before it) is built on Matija Pretnar's [Millet
Language](https://github.com/matijapretnar/millet) and follows the ideas of
[Ahman](https://doi.org/10.1007/978-3-031-30829-1_1) and [Ahman and
Žajdela](https://msfp-workshop.github.io/msfp2024/submissions/ahman+%c5%beajdela.pdf).

## Installing and running
<!-- web-skip -->

### Building

Requires OCaml 5.5 or later. The rational time grades use zarith, which
additionally needs the GMP library (opam installs it through `conf-gmp`).

Install the OCaml dependencies with opam:

    make tempore-deps

The Opentrons simulator, used only to simulate the protocols of the
proof-of-concept [Opentrons](#opentrons) backend, is installed separately; it
needs Python 3.10 or later and the network:

    make opentrons-deps

Tempore is fully usable without it, only `--simulate` option would fail without.

PlatformIO Core, used only to build and upload the projects of the Arduino
backend, is likewise optional; it needs Python 3.10 or later and the network,
and is installed (version 6.2.0) in the virtual environment `_arduino/venv`,
with its platforms, toolchains and libraries in `_arduino/platformio`:

    make arduino-deps

Only the options `--build` and `--upload` need it; `make clean-arduino`
removes `_arduino`, together with the projects written to `_arduino/projects`.

Build the language:

    make

Run the test suite:

    make test

The tests of the Opentrons backend run the generated Python and need Python 3.10
or later; they are skipped when `python3` is absent or older.

Remove the build (the Opentrons simulator and the protocols in `_opentrons` are
kept):

    make clean

### Command line

    ./tempore file1.tpe file2.tpe ...

loads the listed `.tpe` files, typechecks them, runs every `run` command in
them, and prints each `run` result with the final resource state.

Command-line options:

- `--grades <grades>` selects the [grading monoid](#grading-monoids) (default
  `time-lower-bound`);
- `--typecheck-only` typechecks the files without running them;
- `--no-stdlib` skips importing the standard library;
- `--debug` also prints the inferred typing context, including the inferred type
  schemes;
- `--timeline` prints the [timeline](#interpreter) of each run after its result,
  as a table, long grades shortened; `--timeline-full` prints it with the
  grades in full; neither can be combined with `--emit-opentrons` or
  `--emit-arduino`;
- `--emit-opentrons <file.py>` typechecks the files and writes them, compiled to
  Python, to the given file, without running them; a file name without a
  directory names a file in `_opentrons/protocols`; with `--bind`, as an
  Opentrons protocol (see [Opentrons](#opentrons));
- `--emit-arduino <directory>` typechecks the files and writes them, compiled to
  C++, to the given directory, without running them; a name without a
  directory component names a directory in `_arduino/projects`; with
  `--host-runs`, also the `run` commands and a main program for the host that
  executes them; with `--device <manifest.json>`, a PlatformIO project of the
  device the manifest describes, monitored under `--monitor abort|warn|off`
  (default `abort`), which `--host-simulate <seconds>` builds and runs on the
  host for the given simulated time; the declarations of the peripheral
  packages the manifest lists (`i2c`, `m5-imu`, `m5-display`, `bala2-base`,
  under `time-interval-rational` in milliseconds) are loaded before the files;
  `--build` builds the project with PlatformIO (`pio run`), and `--upload`
  builds it and uploads it to the board (`pio run -t upload`), through the
  serial port of `--port <port>` if given, each passing the output of
  PlatformIO through and exiting with its exit code; `--profile` builds the
  project with the profile of its running times, and `--capture <seconds>`
  reads the serial port after the upload; `--pio <path>` names the
  executable, by default `pio` on the `PATH`, or else that of `_arduino/venv`
  in the directory of `tempore` or in the current directory, run with
  `PLATFORMIO_CORE_DIR` set to `_arduino/platformio` unless the environment
  sets it;
- `--package <name>`, repeatable, loads the declarations of a peripheral
  package of the Arduino backend before the files, so that a program run by
  the interpreter performs its operations by their default implementations;
  it cannot be combined with `--device`; with `--board <board>`, the
  operations take the running-time bounds of the packages on that board;
- `--help` lists the options and the available grading monoids.

The [`examples/`](examples/) directory holds example programs grouped according
to their topics.

### Web interface

Open `web/index.html` after building, or use
<https://tempore-lang.ee/>.

You can load an existing example or write your own program, choose which grading
monoid to use, typecheck the program, and step through its reductions while
watching resource usage.

The backend selector, first among the code options, chooses the backend,
Interpreter, Opentrons or Arduino (see [Backends](#backends)).
Selecting a backend loads its default example (the sensor reading for Interpreter,
the ELISA for Opentrons, the tilt display for Arduino), and the gallery lists the
examples of the backend selected. Under Opentrons, the robot, the time unit and
the monitor policy are chosen under the selector, and the mark in the top right
corner of the editor switches between the program and the Opentrons protocol:
the binding file and the protocol compiled from the program once it typechecks.
Under Arduino, the device manifest, the binding file and the monitor policy are
the inputs; the declarations of the peripheral packages the manifest lists are
loaded before the program, which is checked again when they change, and the
compiled code is the configuration, `main.cpp`, the program and the operation
wrappers of the PlatformIO project, one file after another.
These declarations are shown read-only above the program, folded under the
names of their packages; once the program is checked, a name it uses from them,
such as an operation or a function, shows its declaration and scheme as a
tooltip, and ⌘-click (Ctrl-click) or F12 on it unfolds the declarations at it.

The address of the page names the example, the grades and the backend selected,
in the query parameters `example`, the path of the example relative to
`examples` (as in `examples/index`), `grades`, a grading monoid, and `backend`,
a backend's key (`interpreter`, `opentrons` or `arduino`), e.g.,
<https://tempore-lang.ee/?example=arduino/bala2/balance.tpe>. Opening such a
link loads the example as the gallery does, with its own grades and backend
unless `grades` or `backend` overrides them; `backend` without `example` selects
the backend with its default example, unless the example last loaded is of that
backend. The address follows the selection, `grades` and `backend` given only
where they differ from the example's own, and the button beside the example
copies it to the clipboard. The edited text of a program is not part of the
address. Parameters of unknown or malformed values are ignored, with a notice;
the choices not given by the address are those the browser remembers.

A run shows its [timeline](#interpreter) above the reductions, folded under its
title under Interpreter and unfolded under Opentrons and Arduino; the events inside default
implementations are greyed; under Opentrons the title states the time unit,
`Timeline (one time unit = 1 min)`. Long grades are shortened; a shortened cell shows
its full text as a tooltip and, when clicked, in place.

## Temporal resources

A value of modal type `[rho]a` is an `a`-typed resource that may be used only
once/until the grade `rho` (see [Grading monoids](#grading-monoids) below) has
accumulated since the resource was created.

### Boxes and unboxing

`box rho e` creates a resource of type `[rho]a`, where `e` has to be well-typed
in the future in which the grade `rho` has hypothetically accumulated.

`unbox e` opens a resource `e : [rho]a` to be used, and is allowed only if the
grade accumulated since boxing is bounded by `rho` (i.e., below `rho` in the
grade order).

Under the `time-lower-bound` grade, where resources are graded by the least
amount of time that has to pass before resources can be used, the program

```
run
  box 5 (10, 10) as b in
  delay 4;
  unbox b as (l, r) in l + r
```

is rejected by the typechecker, since the four ticks accumulated are not a
sub-grade of the five required:

    Variable `b` is unboxed with grade `4` accumulated since it was bound,
    which is not below its box grade `5`
      Note: the resource inequality `4 >= 5` does not hold

See [`examples/basics/basic_unbox.tpe`](examples/basics/basic_unbox.tpe).

### Delays

`delay tau` advances the accumulated grade by `tau`. Each [grading
monoid](#grading-monoids) has its own notion of delays, and maps them to grades
by a monoid morphism, so `delay 0` has the unit grade and `delay tau; delay
tau'` the grade of `delay (tau + tau')`
([`delay.mli`](src/01-language/grades/delay.mli)).

`tau` is currently a non-negative integer or rational fraction, depending on the
grade. The grades whose names end in `-rational` or `-rational-symbolic`,
`security-levels` and `flow-levels` have the non-negative rationals as delays
and accept any, such as `delay 1/3` or `delay 0.25`; the other monoids count
whole time steps and accept only integers.
See [`examples/basics/delay.tpe`](examples/basics/delay.tpe).

## Grading monoids

Resources and the effects of computations are graded by an ordered monoid,
chosen at run time with the `--grades` option or the **Grades** selector in the
web interface, e.g.,

    ./tempore --grades time-interval examples/time/intervals.tpe

### Grade literals

All monoids share one literal syntax: integers (`3`), fractions (`3/2`, or
exact decimals such as `1.5`), tuples (`(3, High)`), intervals and brace
expressions (`{...}`).

An interval has the standard mathematical meaning: a bracket includes its finite
endpoint and a parenthesis excludes it, as in `[1, 4]`, `(1, 4)`, `[1, 4)`,
`(1/2, 4]`, `[1, ∞)`, `(1, ∞)`, `(-∞, 4]`, `(-∞, ∞)` (ASCII `inf` and `-inf`) or
`[{A}, {A; B}]`; an infinite endpoint is always open, so `[1, ∞]` is a syntax
error, and an empty interval, such as `(1, 1)`, `[1, 1)` or `[4, 1]`, is
rejected. Over whole time steps an open endpoint abbreviates a closed one:
`(1, 4)` is `[2, 3]` and `(1, ∞)` is `[2, ∞)`.

Each monoid accepts the literals it understands; any other literal is a syntax
error naming the monoids that accept it. The greatest grade is `⊤` (ASCII
`top`). Negative integers (`-1`) are accepted only by `resource-levels`. A
fraction equal to an integer, such as `4/2` or `2.0`, is that integer.

### Time

In this category, a grade bounds the number of time steps, or ticks, a
computation takes.

- `time-lower-bound`: `n` is at least `n` ticks; ordered by `>=`, so `0` is
  the top.

- `time-upper-bound`: `n` is at most `n` ticks, `∞` (ASCII `inf`) no bound;
  ordered by `<=`, so `0` is least and `∞` the top.

  For example, with `Read` taking at most two ticks,

  ```
  operation Read : unit ~> nat # 2

  let read_twice () : nat # 5 =
    let x = perform Read () in
    delay 1;
    let y = perform Read () in
    x + y
  ```

  is accepted, as two reads and a delay take at most `2 + 1 + 2` ticks, while if
  we had given the function the type annotation `nat # 4`, the definition would
  have been rejected with

      This function's body has grade `5`, which does not match its annotated
      grade `4`

- `time-interval`: `[n, m]` is between `n` and `m` ticks, and `[n, ∞)` at
  least `n` ticks; ordered by containment, with top `[0, ∞)`. An open endpoint
  abbreviates a closed one, `(n, m)` being `[n + 1, m - 1]`.

See
[`examples/time/upper_bounds.tpe`](examples/time/upper_bounds.tpe) and
[`examples/time/intervals.tpe`](examples/time/intervals.tpe).

The rational variants `time-lower-bound-rational`, `time-upper-bound-rational`
and `time-interval-rational` measure time by non-negative rationals.

The intervals of the grade `time-interval-rational` may be open or half-open:
`box (4, 6] v` may be unboxed strictly after four units and at most six. A sum
of intervals is open at an endpoint if either summand is, so `[1, 2) · [1, 1]`
is `[2, 3)`. A grade is printed as an integer, as a finite decimal if one exists
(`0.125`), and otherwise as a fraction (`1/3`).

For example, under `time-interval-rational`, with `Sense` taking between a
quarter and a half of a unit of time,

```
operation Sense : unit ~> nat # [1/4, 1/2]

let sample () : nat # (1, 2) =
  let x = perform Sense () in
  delay 1;
  x
```

is accepted, as its body takes between `1.25` and `1.5` units, while `delay 1.5`
in place of `delay 1` would be rejected, as the body may then take exactly two
units:

    This function's body has grade `[1.75, 2]`, which does not match its
    annotated grade `(1, 2)`

See
[`examples/time/intervals_rational.tpe`](examples/time/intervals_rational.tpe).

### Traces

In this category, a grade is a non-empty finite set of *traces*, the sequences
of operations and delays a computation may exhibit: `Read; 3; Send` performs
`Read`, waits three ticks, and performs `Send`. Adjacent delays are merged, so
`Read; 1; 2; Send` is the same trace as `Read; 3; Send`. Grades multiply by
concatenation and join by union. Operations declare no running-time bounds.

In `traces-upper-bound`, a grade is the set of traces a computation is
*allowed*, ordered by set inclusion; a delay pays for no operation, and `{Read}`
is not below `{3}`. The unit `{0}` is not least, and `⊤`, any trace, is the top.
Traces are compared by equality, so only upper bounds are provided. The rational
variant `traces-upper-bound-rational` has non-negative rational delays.

Literals are those of the trace grades of timed operations, below.

For example, under `traces-upper-bound`, a door that opens for three ticks for a
known badge and raises an alarm for an unknown one,

```
operation Unlock : unit ~> unit # {Unlock}
operation Lock : unit ~> unit # {Lock}
operation Alarm : unit ~> unit # {Alarm}

let enter (known : bool) : unit # {Unlock; 3; Lock | Alarm} =
  if known then (perform Unlock (); delay 3; perform Lock ())
  else perform Alarm ()
```

is accepted, the traces of the two branches being joined into the set of both,
while leaving out `perform Lock ()` would be rejected, with a note naming the
trace not permitted:

    Note: the grade `{Unlock; 3}` is below `{Alarm | Unlock; 3}` but not below
    `{Alarm | Unlock; 3; Lock}`

See [`examples/traces/upper_bounds.tpe`](examples/traces/upper_bounds.tpe).

### Traces of timed operations

The grades are finite sets of traces as above, and every atomic operation
declares running-time bounds `within [lo, hi]`, which the orders use to trade
time against operations.

Literals use `;` for sequence, `|` for union and parentheses: `{(Read | 2);
Send}` is `{Read; Send | 2; Send}`. An integer `n` abbreviates `{n}`.

The grading monoids are:

- `traces-timed-lower-bound`: the traces a computation must *cover*; an
  operation performed counts as `lo` ticks towards a demanded duration. `{0}` is
  the top.

- `traces-timed-upper-bound`: the traces a computation is *allowed*; a duration
  pays for operations at their `hi`. `{0}` is least and `⊤` the top.

  For example, with `Read` taking between one and three ticks,

  ```
  operation Read : unit ~> nat # {Read} within [1, 3]

  let read_then_wait () : nat # {5} =
    let x = perform Read () in
    delay 2;
    x
  ```

  is accepted, as five ticks allow for a `Read` at its longest and a delay of
  two, while `delay 3` in place of `delay 2` would be rejected with the
  following error message:

      This function's body has grade `{Read; 3}`, which does not match its
      annotated grade `{5}`

- `traces-timed-interval`: closed intervals `[{...}, {...}]` of a lower and an
  upper bound, the traces at or above the one and at or below the other,
  compared componentwise; `[{...}, ∞)` has no upper bound, `{...}` abbreviates
  `[{...}, {...}]`, `n` is `[{n}, {n}]`, `[n, m]` is `[{n}, {m}]`, and an open
  endpoint abbreviates a closed one, `(n, m)` being `[{n + 1}, {m - 1}]`. The
  top is `[{0}, ∞)`.

See
[`examples/traces_timed_ops/lower_bounds.tpe`](examples/traces_timed_ops/lower_bounds.tpe),
[`examples/traces_timed_ops/upper_bounds.tpe`](examples/traces_timed_ops/upper_bounds.tpe)
and
[`examples/traces_timed_ops/intervals.tpe`](examples/traces_timed_ops/intervals.tpe).

The rational variants `traces-timed-lower-bound-rational`,
`traces-timed-upper-bound-rational` and `traces-timed-interval-rational` have
the same orders, units and tops, with non-negative rational durations and
running-time bounds: `{Sample; 1/2; Send}` has a duration of half a unit between
the two operations, a fraction `q` abbreviates `{q}`, and an operation may
declare bounds such as `within [1/2, 3/2]`.

For example, under `traces-timed-interval-rational`, the program

```
operation Sample : unit ~> nat # {Sample} within [1/2, 3/2]
operation Send : nat ~> unit # {Send} within [1/4, 1]

let report () : unit # [1, 3] =
  let x = perform Sample () in
  delay 1/2;
  perform Send x
```

is accepted, as the body takes at least `1/2 + 1/2 + 1/4` and at most
`3/2 + 1/2 + 1` units, while `delay 1` in place of `delay 1/2` would be
rejected, as the body may then take `3.5` units:

    This function's body has grade `[{Sample; 1; Send}, {Sample; 1; Send}]`,
    which does not match its annotated grade `[{1}, {3}]`

An interval with an open numeric endpoint, such as `(1/2, 2]`, denotes
infinitely many traces and is rejected, because grades are non-empty finite sets
of traces. The regular expressions of `regex-timed-interval-rational-symbolic`
can be used to express such cases instead.

See
[`examples/traces_timed_ops/intervals_rational.tpe`](examples/traces_timed_ops/intervals_rational.tpe).

### Regular expressions

A grade is a non-empty regular language of traces. The order is inclusion, the
product is concatenation and the join is union; the unit is `{0}` and the top
`⊤` is the language of all traces. Operations declare no running-time bounds.
The implementation provides two variants, described below.

Under both variants:

- literals are regular expressions, by increasing precedence: union `r | s`,
  intersection `r & s`, concatenation `r; s`, complement `~r` and Kleene star
  `r*`;
- an operation name is a letter, and parentheses or braces group:
  `{Open; (Read | Write)*; Close}` is a file session and `{~{_*; Revoke; _*}}`
  the traces that never revoke;
- a grade is printed as it is written;
- when an ordering fails, a note names the shortest trace of the lesser grade
  not in the greater one:

```
Typing error: Variable `t` is unboxed with grade `{Auth | Fetch}` accumulated
  since it was bound, which is not below its box grade `{Auth; _*}`
  ...
  Note: the grade `{Fetch}` is below `{Auth | Fetch}` but not below `{Auth; _*}`
```

The two variants are:

- `regex-upper-bound-symbolic`: traces are words over the letter `tick` (one
  time step) and declared operation names. A grade is a symbolic regular
  expression over sets of letters, kept in normal form, with no automaton; an
  inclusion `ρ ≾ ρ′` holds if `ρ & ~ρ′` is empty, found by a depth-first search
  of its gap derivatives, each reading a run of ticks of any length and the
  operation after it in one step, by sets of delays and minterms. Literals:

  - an integer `n` denotes `n` ticks, an interval `[n, m]` any number of ticks
    from `n` to `m` and `[n, ∞)` at least `n`;
  - an open endpoint abbreviates a closed one: `(1, 4)` is `2 | 3`;
  - `_` is any single letter, including operations the grade does not name.

  For example, the file session

  ```
  operation Open : unit ~> unit # {Open}
  operation Read : unit ~> nat # {Read}
  operation Write : nat ~> unit # {Write}
  operation Close : unit ~> unit # {Close}

  let copy () : unit # {Open; (Read | Write)*; Close} =
    perform Open ();
    let x = perform Read () in
    perform Write x;
    perform Write x;
    perform Close ()
  ```

  is accepted, as `Open; Read; Write; Write; Close` is one of the traces the
  star permits, while leaving out `perform Close ()` would be rejected:

      This function's body has grade `{Open; Read; Write; Write}`, which does
      not match its annotated grade `{Open; (Read | Write)*; Close}`

  See [`examples/regular/upper_bounds.tpe`](examples/regular/upper_bounds.tpe).

- `regex-upper-bound-rational-symbolic`: traces are *timed words*, operations
  and non-negative rational delays, a delay being a single letter and adjacent
  delays added, so that `{1/2; 1/2}` is `{1}`; delays are compared as rationals,
  not rounded to whole ticks. A grade is a symbolic regular expression over
  sets of operations and sets of delays, kept in normal form, with no automaton;
  an inclusion `ρ ≾ ρ′` holds if `ρ & ~ρ′` is empty, found by a depth-first
  search of its gap derivatives, each reading a delay and the operation after
  it in one step, by sets of delays and minterms. Literals:

  - delays are written `3`, `1/2` or `1.5`, and a plain number `q` abbreviates
    `{q}`;
  - intervals of delays are written `[q, r]`, `(q, r)`, `[q, r)`, `(q, r]`,
    `[q, ∞)` and `(q, ∞)`: `{[0, 1/2)}` is the delays below `1/2` and `{(1, ∞)}`
    those above `1`;
  - a parenthesis followed by a delay and a comma opens an interval, and
    otherwise a group: `{(1 | 2); (1, 2)}` is a delay `1` or `2` followed by one
    strictly between `1` and `2`;
  - `_` is any single operation or any positive delay, and `⊤` is `{_*}`;
  - the complement is taken over all timed words: `{~1}` is every trace but a
    delay of exactly `1`, and `{_ & ~Read}` any single operation but `Read` or
    any positive delay;
  - a repetition of delays is their sums, the empty sum `0` included: `{(1/2)*}`
    is `0`, `1/2`, `1`, …, and `{[1, 2]*}` is `0` and every delay from `1`;
  - a grade is printed with adjacent delays added.

  For example, the program

  ```
  operation Sample : unit ~> nat # {Sample}
  operation Send : nat ~> unit # {Send}

  let report () : unit # {Sample; [0, 1/2); Send} =
    let x = perform Sample () in
    delay 1/4;
    delay 1/8;
    perform Send x
  ```

  is accepted, as the two delays add up to `3/8`, below `1/2`, while `delay 1/4`
  in place of `delay 1/8` would be rejected, as the delays then add up to
  exactly `1/2`:

      This function's body has grade `{Sample; 0.5; Send}`, which does not match
      its annotated grade `{Sample; [0, 0.5); Send}`

  See
  [`examples/regular/upper_bounds_rational.tpe`](examples/regular/upper_bounds_rational.tpe).

Further implementations of `regex-upper-bound-symbolic`, kept for benchmarking,
are accepted by `--grades` with one of these suffixes in place of `-symbolic`:

- `-letter-automata`: minimal automata over single letters; inclusion by a
  breadth-first search of the product with the complement;
- `-symbolic-by-letters`: symbolic expressions as under `-symbolic`; inclusion
  by derivatives by single letters;
- `-letter-derivatives`: expressions over single letters; inclusion by
  derivatives by single letters.

Likewise, `regex-upper-bound-rational-automata` and the timed
`-rational-automata` variants below implement the rational grades by minimal
deterministic symbolic automata over sets of operations and sets of delays;
inclusion by a breadth-first search of the product with the complement, or with
a reader of the closure.

They can be compared by running
`dune exec --profile release bench/regular/bench_regular.exe`; see
[`bench/regular/README.md`](bench/regular/README.md).

### Regular expressions of timed operations

In this category, a grade is a regular language of traces, written as under the
regular expressions above, and every atomic operation declares running-time
bounds `within [lo, hi]`. The orders are those of the traces of timed
operations: a grade stands for its *closure*, the traces that fit inside one of
its traces (upper bounds, an operation taking `hi`) or that cover one of them
(lower bounds, an operation taking `lo`).

- `regex-timed-upper-bound-symbolic`: the allowance order; `{0}` is least and
  `⊤` the top.
- `regex-timed-lower-bound-symbolic`: the coverage order; `{0}` is the top.
- `regex-timed-interval-symbolic`: closed intervals `[{...}, {...}]` of a lower
  and an upper bound, compared componentwise, with the forms and abbreviations
  of `traces-timed-interval`; the top is `[{0}, ∞)`.

Under these:

- delays are whole ticks, and grades are represented as under
  `regex-upper-bound-symbolic`;
- an ordering `ρ ≾ ρ′` holds if no trace of `ρ` lies outside the closure of
  `ρ′`, found as under the rational variants below: by a breadth-first search
  of the automaton of the gap derivatives of `ρ` together with a reader of the
  closure of `ρ′`;
- a failed ordering names a trace with the fewest operations, its delays at the
  extremes of their sets;
- the alphabet is the atomic operations declared anywhere in the program, so
  `_` is any tick or atomic operation, and a grade must denote at least one
  trace over it;
- with `Read` declared `within [1, 3]`, under `regex-timed-upper-bound-symbolic`
  `{Read}` is below `{3}`, as three ticks allow for `Read`, and `{Read | 3}`
  equals `{3}`.

For example, under `regex-timed-lower-bound-symbolic`, the program

```
operation Fetch : unit ~> nat # {Fetch} within [2, 3]
operation Send : nat ~> unit # {Send} within [1, 1]

let send_after_wait () : unit # {5; Send} =
  let x = perform Fetch () in
  delay 3;
  perform Send x
```

is accepted, as `Fetch`, taking at least two ticks, and the delay of three cover
the five ticks demanded before `Send`, while `delay 2` in place of `delay 3`
would be rejected:

    This function's body has grade `{Fetch; 2; Send}`, which does not match its
    annotated grade `{5; Send}`

An upper bound stands for the traces that fit inside its traces, so the
operations of its traces may be left out. With a leading `_*`, a bound allows
any trace first and permits, without demanding, the rest: with `Ethanol`
declared `within [1, 2]` and `ChangeTip` `within [1, 1]`, under
`regex-timed-interval-symbolic` a value boxed with
`{_*; Ethanol; _*; Ethanol; [2, 5]; ChangeTip}` may be unboxed after the calls
of `Ethanol`, `ChangeTip` and `Ethanol`, a `delay 6` and a call of `ChangeTip`,
whose gap of six ticks before `ChangeTip` exceeds `[2, 5]`. A maximum gap
between given operations is stated by a fixed pattern: with the box grade
`{Ethanol; ChangeTip; Ethanol; [2, 5]; ChangeTip}`, the same unboxing is
rejected, and accepted after `delay 3` in place of `delay 6`.

See
[`examples/regular_timed_ops/lower_bounds.tpe`](examples/regular_timed_ops/lower_bounds.tpe),
[`examples/regular_timed_ops/upper_bounds.tpe`](examples/regular_timed_ops/upper_bounds.tpe)
and
[`examples/regular_timed_ops/intervals.tpe`](examples/regular_timed_ops/intervals.tpe).

The rational variants `regex-timed-lower-bound-rational-symbolic`,
`regex-timed-upper-bound-rational-symbolic` and
`regex-timed-interval-rational-symbolic` have the same orders over the timed
words of `regex-upper-bound-rational-symbolic`.

Under these:

- literals are those of `regex-upper-bound-rational-symbolic`, and running-time
  bounds may be fractional, such as `within [1/2, 3/2]`;
- durations are compared as rationals, not rounded to whole ticks: with `A`
  declared `within [1, 1]`, under `regex-timed-upper-bound-rational-symbolic`
  the grade `{(0, 1); A; (0, 1)}` is below `{3}` but below no `{q}` with
  `q < 3`, since the durations of its traces come arbitrarily close to `3`
  without reaching it;
- grades are represented as under `regex-upper-bound-rational-symbolic`; the
  closures are not regular, so an ordering `ρ ≾ ρ′` is decided by a
  breadth-first search of the automaton of the gap derivatives of `ρ` together
  with a reader of the closure of `ρ′`, which keeps the longest (upper) or
  shortest (lower) durations of the traces read so far;
- a complement is taken over all timed words, and a grade still stands for its
  closure: `{~1}` equals `⊤` under the upper order, since it contains the
  delays longer than `1`, which allow for the delay `1` it excludes;
- a set of delays in the lesser grade counts by its supremum (upper) or infimum
  (lower), attained or not: `{[0, 1)}` is below `{1}` but not below `{1/2}`;
- the implied running-time bounds of a compound operation are the least and
  greatest durations of the traces of its grade: with `Sample` declared
  `within [1/2, 3/2]` and `Send` `within [1/4, 1]`, `{Sample; [0, 1/2); Send}`
  takes `[3/4, 3)`;
- under `regex-timed-interval-rational-symbolic` an open numeric endpoint of an
  interval is a set of durations: `(0.8, 3)` is `[{(0.8, ∞)}, {[0, 3)}]`.

For example, under `regex-timed-upper-bound-rational-symbolic`, the program

```
operation Sample : unit ~> nat # {Sample} within [1/2, 3/2]
operation Send : nat ~> unit # {Send} within [1/4, 1/2]

let report () : unit # {[0, 3)} =
  let x = perform Sample () in
  delay 1/4;
  perform Send x
```

is accepted, as the body takes at most `3/2 + 1/4 + 1/2` units, below `3`, while
`delay 1` in place of `delay 1/4` would be rejected, as the body may then take
exactly `3` units:

    This function's body has grade `{Sample; 1; Send}`, which does not match its
    annotated grade `{[0, 3)}`

See
[`examples/regular_timed_ops/upper_bounds_rational.tpe`](examples/regular_timed_ops/upper_bounds_rational.tpe)
and
[`examples/regular_timed_ops/intervals_rational.tpe`](examples/regular_timed_ops/intervals_rational.tpe).

### Security levels and products

In this category, we have the following grading monoids:

- `security-levels`: the levels are given by the simple security lattice
  `Low < High`; a computation's grade is the highest level it touches, and
  delays touch none. A box at `Low` is out of reach once an operation of grade
  `High` has run.

  For example, the program

  ```
  operation ReadPublic : unit ~> string # Low
  operation ReadSecret : unit ~> string # High
  operation Post : string * string ~> unit # Low

  let forward () =
    let c = box Low "public" in
    let msg = perform ReadPublic () in
    unbox c as ch in
    perform Post (ch, msg)
  ```

  is accepted, while `ReadSecret` in place of `ReadPublic` would be rejected, as
  the public channel is out of reach once a secret has been read:

      Variable `c` is unboxed with grade `High` accumulated since it was bound,
      which is not below its box grade `Low`

- `time-lower-bound-levels`: pairs `(n, l)`, at least `n` ticks and nothing
  above security level `l`; `(3, Low)` is an embargo with a taint check. This is
  a direct product of the time lower bounds and security levels grades.

- `time-upper-bound-levels`: pairs `(n, l)`, at most `n` ticks and nothing above
  security level `l`; `(5, Low)` is an expiring capability. This is a direct
  product of the time upper bounds and security levels grades.

  For example, where a token boxed at `(5, Low)` expires after
  five ticks or once something secret is touched, the program

  ```
  operation Query : string ~> string # (2, Low)
  operation ReadPayroll : unit ~> string # (1, High)

  let query_in_time () =
    let t = box (5, Low) "token" in
    delay 3;
    unbox t as tok in
    perform Query tok
  ```

  is accepted, while `perform ReadPayroll ()` in place of `delay 3`
  would be rejected:

      Variable `t` is unboxed with grade `(1, High)` accumulated since it was
      bound, which is not below its box grade `(5, Low)`

- `flow-levels`: tuples `(l, (S₁, l₁), …, (Sₖ, lₖ))`, nothing above `l` touched
  and each output `Sᵢ` written at most at the level `lᵢ` touched before it; `l`
  alone writes no output, and an entry `(_, l')` bounds every output not listed.
  An output is a capitalised name, and an operation writing it has a grade such
  as `(Low, (Board, Low))`; after one of grade `High`, it is written at `High`.
  This grading monoid is an example of the semidirect product construction (see
  [Semidirect products](#semidirect-products)).

  For example, where a secret may be read after a public announcement but
  not announced, the program

  ```
  operation ReadSecret : unit ~> string # High
  operation Publish : string ~> unit # (Low, (Board, Low))

  let announce () : unit # (High, (Board, Low)) =
    perform Publish "maintenance at noon";
    let _ = perform ReadSecret () in
    ()
  ```

  is accepted, while publishing after the read would be rejected, as `Board` is
  then written at `High`:

      This function's body has grade `(High, (Board, High))`, which does not
      match its annotated grade `(High, (Board, Low))`

The pairs of the products with the time grades are compared, multiplied and
joined componentwise.

See
[`examples/levels/security.tpe`](examples/levels/security.tpe),
[`examples/levels/time_lower.tpe`](examples/levels/time_lower.tpe),
[`examples/levels/time_upper.tpe`](examples/levels/time_upper.tpe)
and [`examples/levels/flow.tpe`](examples/levels/flow.tpe).

### Semidirect products

In this category, a grade is generally a pair `(m, n)` whose second component is
acted on by the first components of the grades before it:
`(m, n) · (m', n') = (m · m', n ⊔ m ▷ n')`, where `m ▷ n'` is a grade-specific
action of `m` on `n'`. The pairs are compared and joined componentwise. The
`flow-levels` monoid from above is an example, as are:

- `resource-levels`: triples `(t, [d1, d2], h)` bounding a resource held, such
  as open files, relative to its level at the start: the trough `t` is the
  lowest level, the range `[d1, d2]` the net change and the peak `h` the highest
  level, with `t <= d1 <= d2 <= h` and `t <= 0 <= h`. It is the semidirect
  product of the upper bounds of the net change and the peaks, paired with its
  mirror image of the lower bounds and the troughs.

  The monoid operation is
  `(t, [d1, d2], h) · (t', [d1', d2'], h') = (min(t, d1 + t'), [d1 + d1', d2 + d2'], max(h, d2 + h'))`,
  and `x <= y` holds iff `x` has a trough at least, a range within and a peak at
  most those of `y`. Delays have the unit grade `(0, 0)`; `(∞, ∞)` is the top.

  A grade is written `(d, h)` for an exact net change `d` or `([d1, d2], h)` for
  a range, both with the trough `min(0, d1)`, or `(t, d, h)` and `(t, [d1, d2],
  h)` with an explicit trough; troughs may be `⊤`, unbounded below, and peaks
  `∞`, and a range unbounded below or above is written `(-∞, d2]` or `[d1, ∞)`,
  and an open end abbreviates a closed one.

  Resources are named by entries such as `(R, d, h)` or `(R, t, d, h)`, e.g.
  `((Files, 0, 2), (Sockets, 0, 1))`, each bounded on its own; a resource not
  listed is bounded by `(0, 0)`, or by the entry `(_, d, h)`, and a plain `(d,
  h)` bounds every resource. Opening a file has grade `(Files, 1, 1)` and
  closing one `(Files, -1, 0)`; two copies in sequence, each holding two files,
  have grade `(Files, 0, 2)`, and closing a file before opening one has grade
  `(Files, -1, 0, 0)`.

  For example, the program

  ```
  operation Open : string ~> unit # (Files, 1, 1)
  operation Close : string ~> unit # (Files, -1, 0)

  let copy () : unit # (Files, 0, 2) =
    perform Open "a";
    perform Open "b";
    perform Close "b";
    perform Close "a"
  ```

  is accepted, as it holds at most two files and closes all it opens, while
  leaving out `perform Close "a"` would be rejected, as a file is then left
  open:

      This function's body has grade `(Files, 1, 2)`, which does not match its
      annotated grade `(Files, 0, 2)`

- `windowed-schedules`: tuples `(T, (A, E_A), …)` of the possible durations `T`
  and the times `E_A` at which each operation `A` happens, all sets of numbers
  of ticks from the start; `(T, E) · (T', E') = (T + T', E ∪ (T + E'))`, `+`
  adding elementwise, and the order is inclusion. `T` is written `n`, `[n, m]`,
  `[n, ∞)`, with open endpoints as for `time-interval`, or as a brace literal
  over ticks, `{0 | 10}`, and `T` alone performs no operation; `E_A` is a brace
  literal, `{(4 | 5); 10*}` being ticks 4 and 5 of every ten, and an entry
  `(_, E)` bounds every operation not listed. An operation `Send` taking a tick
  and happening at its start has grade `(1, (Send, {0}))`.

  For example, where `Send` takes a tick and must start at tick 4
  or 5, the program

  ```
  operation Send : unit ~> unit # (1, (Send, {0}))

  let send_in_window () : unit # ([5, 6], (Send, {4 | 5})) =
    delay 4;
    perform Send ()
  ```

  is accepted, while `delay 6` in place of `delay 4` would be rejected, as
  `Send` then happens at tick 6:

      This function's body has grade `(7, (Send, {6}))`, which does not match
      its annotated grade `([5, 6], (Send, {4 | 5}))`

- `mode-switch-costs`: max-plus matrices of the greatest costs of the traces
  between named modes, the completion under joins of a semidirect product of
  mode changes and costs.

  Entries `(From, To, n)` give the traces, e.g. `(Off, On, 2)` for switching a
  radio on; the product gives `(p, r)` the greatest cost of a trace from `p` to
  a mode `q` followed by one from `q` to `r`.

  The reserved mode `Stuck` is never left, and an operation gets stuck in it at
  cost 0 from the modes its grade does not start from, so `(On, On, 4)` is
  possible only with the radio on, and `(On, Stuck, 3)` permits getting stuck
  from `On` after cost 3. A change between two distinct modes other than `Stuck`
  costs at least 1.

  A plain `n` costs `n` and keeps any mode. Modes not named are written `_`:
  `(p, _, n)` from `p` to one, `(_, q, n)` from one to `q`, `(_, _, n)` keeping
  one, `(_, ≠, n)` from one to another and `(_, Stuck, n)` from one into
  `Stuck`; a branch between a transmission and an operation of cost 1 in every
  mode has grade `((On, On, 4), (_, _, 1), (_, Stuck, 0))`. Delays cost nothing;
  idle draw is charged by operations such as `Sleep : unit ~> unit # ((Off, Off,
  10), (On, On, 50))`.

  For example, where switching a radio on costs 2 and a transmission
  4, the program

  ```
  operation TurnOn : unit ~> unit # (Off, On, 2)
  operation Transmit : string ~> unit # (On, On, 4)

  let report () : unit # (Off, On, 6) =
    perform TurnOn ();
    perform Transmit "reading"
  ```

  is accepted, while a second transmission would be rejected, as it costs `10`,
  and so would a transmission before `TurnOn`, as the radio is then off:

      This function's body has grade `(Off, On, 10)`, which does not match its
      annotated grade `(Off, On, 6)`

An (external) operation whose grade no code inside Tempore can meet, such as
opening or closing a file under `resource-levels`, has no default
implementation, and a run stops at its first call.

See
[`examples/semidirect/resource_levels.tpe`](examples/semidirect/resource_levels.tpe),
[`examples/semidirect/windowed_schedules.tpe`](examples/semidirect/windowed_schedules.tpe)
and
[`examples/semidirect/mode_switch_costs.tpe`](examples/semidirect/mode_switch_costs.tpe).

### Operation counts

In `counts-upper-bound`, a grade has entries `(A, n)`, at most `n` calls of the
operation `A`, `n` possibly `∞`; sequencing adds the calls of each operation,
and delays count none. An operation not listed is bounded by `0`, or by the
entry `(_, n)`, and a plain `n` bounds every operation: `((Auth, 1), (Send, 3))`
allows one `Auth`, three `Send` and nothing else. An operation counts itself,
e.g. `operation Send : nat ~> unit # (Send, 1)`.

For example, the program

```
operation Auth : string ~> unit # (Auth, 1)
operation Send : string ~> unit # (Send, 1)

let notify () : unit # ((Auth, 1), (Send, 3)) =
  perform Auth "key";
  perform Send "a";
  perform Send "b"
```

is accepted, as it authenticates once and sends twice, while two further
sends would be rejected, as they make four:

    This function's body has grade `((Auth, 1), (Send, 4))`, which does not
    match its annotated grade `((Auth, 1), (Send, 3))`

See [`examples/counts/rate_limits.tpe`](examples/counts/rate_limits.tpe).

## Eternal types

A type is *eternal* if its values stay valid however much grade accumulates as a
result of computations. Base types, tuples, and algebraic types built from
eternal types are eternal; function, handler, and box types are not. A local
variable of a non-eternal type may be used only while the grade accumulated
since its binding is a sub-grade of the unit. Under `time-lower-bound` and
`traces-timed-lower-bound` this always holds; under the other monoids such a
variable must be used before any nontrivial delay or operation call.

### Schemes and qualifiers

When eternality depends on a type variable of a top-level definition, it
becomes a qualifier of the definition's scheme, checked at each use.

Under `time-upper-bound`, the program `let keep x = delay 1; x` gets the scheme

    ∀ α. Et(α) ⇒ α → α # 1

so `keep 5` is accepted by the typechecker and `keep (fun () -> ())` is
rejected.

See [`examples/basics/eternal_types.tpe`](examples/basics/eternal_types.tpe).

### Noneternal declarations

`noneternal type epoxy = Epoxy` makes `epoxy`, and every type containing it,
non-eternal. The keyword prefixes a whole `type ... and ...` group of
algebraic types.

## Algebraic effects and effect handlers

### Operations and their grades

```
operation Read : unit ~> string # 2
```

declares an operation whose call `perform Read ()` has grade `2`. Under the
trace and regular-expression monoids of timed operations, an *atomic* operation,
graded by its own name, also declares its running-time bounds (`within [n, m]`):

```
operation Tx : string ~> unit # {Tx} within [2, 3]
```

The bounds are durations, written as for `delay` (see [Delays](#delays)), with
`lo <= hi` and `hi` positive. Either end may be open, as in `within (lo, hi)`,
`within [lo, hi)` or `within (lo, hi]`, the interval being non-empty.

The rational monoids of timed operations accept fractional bounds such as
`within [1/2, 3/2)`; under the other monoids of timed operations, which count
whole time steps, `within [1/2, 1]` is a syntax error and an open end
abbreviates a closed one, `within (1, 4)` being `within [2, 3]`.

The rational trace monoids compare traces with exact durations and read the
value of each end. The rational regular-expression monoids read whether each end
is attained: with `A` declared `within [1, 2)`, `{A}` is below `{[0, 2)}` under
`regex-timed-upper-bound-rational-symbolic`, and a default implementation of `A`
takes less than `2`.

A *compound* operation names other operations in its grade, and its bounds are
computed from theirs: `Send : string ~> unit # {Tx | Tx; Tx}` gets `[2, 6]`.

### Handlers and continuations

```
handle e with
  handler
  | x -> return-case
  | Op p k -> operation-case
```

An operation case receives the argument `p` and the continuation `k`, resumed
with `continue k with v`. Unhandled operations are forwarded. The continuation
is a resource boxed with the operation's grade, resumed only once the case has
accumulated a sub-grade of that grade: under `time-lower-bound`,
`Get () k -> delay 71; continue k with 42` handles `Get # 71`. A case is
checked for every effect its continuation may have; a failure names the
instance:

    Note: the effect inequality `∀ε_Op. 0 >= 1 · ε_Op` does not hold: for
      `ε_Op = 0` it becomes `0 >= 1`

See [`examples/handlers/lower_bound.tpe`](examples/handlers/lower_bound.tpe),
[`examples/handlers/upper_bound.tpe`](examples/handlers/upper_bound.tpe)
and [`examples/handlers/3d_printing.tpe`](examples/handlers/3d_printing.tpe).

### Contexts of operation cases

An operation case is typed with the top grade `⊤` accumulated for the variables
bound outside it. Under `time-lower-bound` and `traces-timed-lower-bound` the
top is the unit, which restricts nothing. Under the other monoids an outer
variable of non-eternal type, including an outer continuation, cannot be used in
the case, and an outer box can be unboxed only if `⊤` is below its grade. This
is because operation cases need to be executable anywhere in the computation
tree when handling. The case's own `p` and `k`, and top-level definitions, are
unaffected. See [`examples/handlers/nested.tpe`](examples/handlers/nested.tpe)
and
[`examples/handlers/nested_reject.tpe`](examples/handlers/nested_reject.tpe).

### Default implementations

```
default Heat () = delay 1
```

gives `Heat` a default, run only when a call reaches the top level unhandled
in a `run` command below it, commands taking effect in the order of the file;
here it simulates the running time of `Heat` by a delay. Where operations
declare running-time bounds, only atomic operations have defaults, and a
default's grade must be a sub-grade of `{lo}` under lower bounds, `{hi}` under
upper bounds, and `[{lo}, {hi}]` under intervals; the running-time bounds its
grade implies must moreover lie within the declared ones, an open end excluded,
so that with `A` declared `within [1, 2)` the default `default A () = delay 2`
is rejected under every monoid of timed operations. Elsewhere a default's grade
must be a sub-grade of the operation's grade. See
[`examples/traces_timed_ops/3d_printing.tpe`](examples/traces_timed_ops/3d_printing.tpe).

## Recursion

`let rec f p₁ … pₙ = c` must be structurally recursive: for a fixed position
`d`, every call of `f` in `c` has a `d`-th argument that is a variable bound
by a constructor, `x :: xs` or `m + k` pattern in a match on `p_d` or on such
a variable. Like an operation case, `c` is typed with the top grade `⊤`
accumulated for the local variables bound outside it (see [Contexts of
operation cases](#contexts-of-operation-cases)); `f` itself may be called
anywhere in `c`, including after delays and in operation cases.

A recursive function has the unit effect unless it is annotated
`let rec f p₁ … pₙ : ty # ε = c`. Then
`f : A₁ → … → (Aₙ → ty # ε)`, the outer arrows having the unit effect, and `ε`
must bound the effect of `c` assuming every recursive call has effect `ε`.

Under `regex-upper-bound-symbolic`,
```
let rec read_all n : nat # {Read*} =
  match n with
  | 0 -> 0
  | m + 1 -> let x = perform Read () in let y = read_all m in x + y
```

is accepted.

Under `time-upper-bound`, a loop with `delay 1; wait m` in each round is bounded
by `⊤` but by no `n`, as `1 · n ≾ n` fails.

## Type inference

Types, grades and effects are inferred in the style of HM(X) (Odersky, Sulzmann
and Wehr, TAPOS 1999). Types are compared by subtyping: functions are
contravariant in the argument and covariant in the result and effect, and a box
`[rho]a` is contravariant in `rho`. Top-level `let` definitions are generalised
to qualified schemes,

    ∀ α ρ₀ ε₀. Q ∧ R ⇒ A

where `Q` constrains the type, resource (`ρ`) and effect (`ε`) variables, `R`
lists the conditions of operation cases that must hold for every effect of
their continuations, and `∣ε∣` is the resource grade accumulated while `ε`
runs. A condition is printed `∀ε_Op. …`, `ε_Op` being the effect of the
continuation of a case for `Op`, primed (`ε_Op′`) for another case for `Op`.
`--debug` prints the schemes. Under `time-upper-bound`, the standard library's
`compose f g x = f (g x)` has

    ∀ α β γ ε₀. (α → β # ε₀) → (γ → α) → (γ → β # ε₀)

where `g` takes no time, since the non-eternal `f` is used after it: the
qualifier `∣ε₁∣ ≾ 0` on the effect `ε₁` of `g` admits only the least value
`0`, which the scheme substitutes; an effect of the unit is not printed.

Under `time-lower-bound`, with `operation Op : unit ~> unit # 1`, the handler

    let via f = handler | x -> x | Op () k -> f (); continue k with ()

has

    ∀ α β ε₀ ε₁. ∣ε₀∣ ≾ 1 ∧ (∀ε_Op. ε_Op · ε₀ ≾ 1 · ε_Op) ⇒ (unit → α # ε₀) → (β # ε₁ ⇒ β)

where `R`, `∀ε_Op. ε_Op · ε₀ ≾ 1 · ε_Op`, states that for every effect `ε_Op`
of `k` the case, `f` followed by `k`, takes at least the time of `Op` followed
by `k`. A `run` must establish every such condition: one without unknowns that
the typechecker can neither derive nor refute rejects it, and one with
unknowns must hold together with `Q` at a closed instance of the unknowns.
Under the time grades, the security levels and their products, a condition in
the effect of a single continuation is always decided; under the trace grades
it may not be.

### Annotations

A function's computation type may be annotated, `let f () : nat # 3 = ...`; the
body's grade must be a sub-grade of the annotation. Types may contain variables
`'a`, and grades may be variables `'e` or `'r`: within a top-level definition,
the same name is the same unknown, inferred and generalised with it. A name also
written after `#` stands for the resource image `∣ε∣` of that effect in box
grades. `let pass (f : unit -> nat # 'e) : nat # 'e = f ()` has the grade of
`f`.

Type-constructor application binds tightest, then the box `[rho]`, then
products `a * b`, which are n-ary and non-associative, and last arrows
`a -> b # e`, which are right-associative: `[2]nat list * bool -> nat` takes
a pair of a `[2](nat list)` and a `bool`, and a box of a function is written
`[2](nat -> nat)`. An effect `# e` belongs to the innermost arrow, so
`nat -> nat -> nat # 1` is `nat -> (nat -> nat # 1)`, and an arrow without
one has the unit effect. Printed types use the same precedences and leave out
an effect of the unit; a result that is a function type is printed in
parentheses where either arrow shows its effect, `nat → (nat → nat # 1)`.

### Sub-effecting

A computation may be used where one of a super-grade is expected. Under
`time-upper-bound`,

```
let apply (f : unit -> nat # 2) = f ()
let slow () = delay 1; 3
let branch c = if c then delay 1 else delay 2
```

`apply slow` is accepted, `unit → nat # 1` being a subtype of
`unit → nat # 2`, and `branch` has the type `bool → unit # 2`. A box type is
contravariant in its grade: under `time-lower-bound`, a `[2]nat` is accepted
where a `[3]nat` is expected, but a `[4]nat` is not.

Limits:

- type-constructor arguments and handler inputs are compared by equality: a
  `(unit -> nat # 1) list` is not accepted where a `(unit -> nat # 2) list` is
  expected, although `[slow]` has the scheme
  `∀ ε₀. 1 ≾ ε₀ ⇒ (unit → nat # ε₀) list` and is accepted at both;
- local `let` definitions are not generalised;
- the continuation effect of an operation case is rigid (see
  [Handlers and continuations](#handlers-and-continuations));
- satisfiability of a qualifier is decided provisionally: a definition is
  rejected only when its qualifier is refuted, including through the factors
  of a product whose other factors are above the unit, because the unit is the
  least grade or the hypotheses of the qualifier entail it, and each use
  checks it; a `run` must have a closed instance of its whole qualifier
  `Q ∧ R` among finitely many grades per unknown.

## Backends

A program is executed by one of three backends.

### Interpreter

The interpreter evaluates the program by a small-step reduction relation and
tracks the resource state: both the boxed resources and the accumulated grade. A
`run` command prints its result with the final resource state. The web interface
can also step through the individual reductions and shows the resource usage.

Natural numbers are unbounded and floats are of double precision. Besides the
arithmetic operators, the standard library provides `float_of_nat`, the
nearest float, infinity beyond the range; `nat_of_float`, truncated toward
zero, 0 for a negative float and for NaN, and a run-time error for infinity,
as division by zero; `sqrt`, NaN for a negative float; `atan`; and
`atan2 (y, x)`, the angle of the point `(x, y)` from -π to π, with the
special cases of C.

Integers, of type `int`, are unbounded and written with the suffix `i`: `3i`,
`0x1fi`, and, as the negation of a literal, `-3i`; as in OCaml, `x -3i` is the
subtraction `x - 3i`. Their operators are `+!`, `-!`, `*!`, `/!` and `mod!`,
of the precedences of `+`, `-`, `*`, `/` and `mod`, and the negation `~-!`.
Division and `mod!` truncate toward zero, as in C, the remainder having the
sign of the dividend, and division or modulo by zero is a run-time error. The
conversions are `int_of_nat`; `nat_of_int`, 0 for a negative integer;
`float_of_int`, the nearest float; and `int_of_float`, truncated toward zero,
0 for NaN, and a run-time error for infinity. A match on integers needs a
case for every other integer, such as a wildcard.

The timeline of a run lists, in grades, what reaches its top level: the delays,
the calls of operations that no handler handles and that are performed by their
default implementations, and the resources boxed and unboxed, by the name of the
variable they are bound to. A delay or an operation has a grade: that of the
delay, or the declared grade of the operation. Boxing and unboxing add nothing
to the grade accumulated; a box row names the grade the resource is boxed at in
its event, `box reading with grade [5, 10)`. The events of a
default implementation, the operations it performs among them, are listed below
its operation, indented by `·`. Each row at the top level
starts at the grade accumulated before it, the product of the grades of the
rows at the top level above it. Operations handled by handlers, and their
continuations, are not listed; the steps of a handler's case are listed as they
happen. The timeline displays the run and checks nothing, the program having
been typechecked before it runs. The command-line option `--timeline` prints it
after each run, e.g.

    ./tempore --grades time-interval-rational --timeline examples/introduction/sensor_reading.tpe

prints

    Timeline
    Run  Start       Event                           Grade
    1    [0, 0]      delay                           [0.1, 0.1]
    1    [0.1, 0.1]  box reading with grade [5, 10)
    1    [0.1, 0.1]  Compute                         [6, 8]
    1                · delay                         [7, 7]
    1    [6.1, 8.1]  unbox reading
    1    [6.1, 8.1]  AngleOf                         (0, 1]
    1                · delay                         [0.5, 0.5]
    1    (6.1, 9.1]  SetAngle                        (1, 2)
    1                · delay                         [1.5, 1.5]
    Run 1 returned () at (7.1, 11.1).

Grades whose ends exceed 40 characters, such as the traces of the Opentrons
examples under `regex-timed-interval-symbolic`, are shortened for display at
the separators `; ` of their events, never inside an event: the grade
accumulated keeps its last events, `{…; 3; ChangeTip; Disengage; Elute}`, a box
grade its first, `{Ethanol; ChangeTip; Ethanol; 2; …}`. The grades themselves
are unchanged; `--timeline-full` prints them in full.

### Opentrons

The proof-of-concept Opentrons backend compiles the program to a single-file
Opentrons Python protocol, accepted by the Opentrons App and by
`opentrons_simulate`. Grades are erased, and the program is executed by an
abstract machine included in the file, so that handlers, continuations and
recursion behave as in the small-step interpreter. The robot is the Flex.

The program is paired with a binding file in Python. It defines `setup(protocol)`,
which loads the labware, pipettes, and modules, and returns a context object, and,
for an operation `Op`, a function `Op(ctx, arg)` that performs the operation and
returns its result. Arguments and results are Python values: a `nat` is an
`int`, an `int` a `tempore_Int`, a subclass of `int`, a `string` a `str`, a tuple a `tuple` and `()` the unit value. A binding
function declares the nominal duration of its action by
`tempore_elapse(seconds)`. An operation call that no handler handles calls the
binding function of the operation, or else its default implementation, and
`delay q` calls `protocol.delay` for `q` units of duration.

Each call of a binding function is monitored against the running-time bounds of
its operation: those it declares by `within`, or else the interval of durations
its grade determines, such as `[2, 4]` for `# [2, 4]` under `time-interval`. An
operation with neither is not monitored. A call outside its bounds ends the
protocol with an error, is reported by a comment, or is not checked, according
to the monitor policy `abort`, `warn` or `off`.

The protocol is refused when the binding file defines no `setup` or defines a
reserved name, or when the code of a `run` command may perform an operation that
has neither a binding function nor a default implementation and that no handler
in that code has a case for. Such an operation that a handler does have a case
for is a warning if it is atomic, and is accepted silently if it is compound,
since a compound operation is implemented by handlers only.

The directory [`examples/opentrons/`](examples/opentrons/) holds the following
examples, each with a binding file and a rejected variant:

- [`elisa.tpe`](examples/opentrons/elisa.tpe): an enzyme-linked immunosorbent
  assay under `time-interval`;
- [`washes.tpe`](examples/opentrons/washes.tpe): a bead clean-up with exactly
  two ethanol washes, under `regex-timed-interval-symbolic`;
- [`contamination.tpe`](examples/opentrons/contamination.tpe): a ddPCR plate
  set-up under `time-upper-bound-levels`;
- [`reagents.tpe`](examples/opentrons/reagents.tpe): a tagmentation with reagents
  boxed `[0, 30]`;
- [`staggered.tpe`](examples/opentrons/staggered.tpe): a fixation of columns at
  staggered times;
- [`beads.tpe`](examples/opentrons/beads.tpe): a bead clean-up with beads boxed
  `[3, ∞)` and `[2, 3]`;
- [`stopread.tpe`](examples/opentrons/stopread.tpe): a stop and read with plates
  boxed `[0, 30]`;
- [`cleanup.tpe`](examples/opentrons/cleanup.tpe): a bead clean-up whose compound
  operations are performed by a handler through the atomic operations.

#### Command line
<!-- web-skip -->

    ./tempore --grades <grades> \
      --emit-opentrons protocol.py \
      --bind bindings.py \
      file.tpe

writes the protocol to `_opentrons/protocols/protocol.py`, creating the
directory if needed, and prints the path written. A file name without a
directory names a file in `_opentrons/protocols` of the current directory, which
git does not track; a name with a directory, such as `./protocol.py`, is used as
given. Run as a script, `python3 _opentrons/protocols/protocol.py` executes the
program as the interpreter does, without the binding file. Without `--bind`,
only the compiled program is written. The options below require `--bind`:

- `--api-level <level>` sets the `apiLevel` (default 2.30);
- `--time-unit <unit>` sets the length of a unit of duration: `seconds` (the
  default), `minutes`, `hours` or a positive number of seconds;
- `--monitor abort|warn|off` sets the monitor policy (default `abort`);
- `--simulate` runs the protocol with the Opentrons simulator and exits with its
  exit code; `--simulator <path>` names the executable, by default
  `opentrons_simulate` on the `PATH`, or else that of the virtual environment
  `_opentrons` in the directory of `tempore` or in the current directory.

For example,

    ./tempore --grades time-interval \
      --emit-opentrons elisa.py \
      --bind examples/opentrons/elisa_bindings.py \
      --time-unit minutes \
      --simulate \
      examples/opentrons/elisa.tpe

writes the ELISA protocol to `_opentrons/protocols/elisa.py` and simulates it.

Each example `NAME` has the targets `make opentrons-NAME-emit`, which writes
its protocol to `_opentrons/protocols/NAME.py`, and `make
opentrons-NAME-simulate`, which also simulates it, installing the simulator by
`make opentrons-deps` first; `make opentrons-simulate-all` simulates every
example, and `make examples-help` lists the targets. `MONITOR=warn` sets the
monitor policy. The targets are defined by
[`examples/examples.mk`](examples/examples.mk) from a fragment
`examples/opentrons/NAME.mk` next to the example, which sets its grades and
its unit of duration:

    EXAMPLE_GRADES = time-interval
    EXAMPLE_TIME_UNIT = minutes

A new example `NAME.tpe`, with its binding file `NAME_bindings.py`, gets its
targets by such a fragment; `tests/make/examples.t` checks that every example
has one and that its target runs the command of its header.

Requirements:

- the simulator is `opentrons_simulate` of the `opentrons` Python package
  (tested with version 10.0.0), which needs Python 3.10 or later;
- `make opentrons-deps` installs it in the virtual environment `_opentrons` of
  the repository with the first of `python3.13`, `python3.12`, `python3.11`,
  `python3.10` and `python3` of version 3.10 or later, and fails if there is
  none; `make clean-opentrons` removes it,
  together with the protocols written to `_opentrons/protocols`;
- it can also be installed by hand, e.g.
  `python3 -m venv venv && venv/bin/pip install opentrons==10.0.0`, and then
  named by `--simulator` or placed on the `PATH`;
- the simulator writes its configuration to `~/.opentrons` unless the
  environment variable `OT_API_CONFIG_DIR` names another directory; for the
  simulator of `_opentrons`, `--simulate` sets it to `_opentrons/config` unless
  it is set;
- a compiled protocol run as a script,
  `python3 _opentrons/protocols/protocol.py`, needs Python 3.10 or later only,
  not the `opentrons` package;
- `scripts/opentrons-simulate.sh [VENV_DIR]` simulates every example with the
  virtual environment `VENV_DIR` (default `_opentrons`), which it creates and
  installs the package in if needed (the network is then needed), writing the
  protocols and logs to the environment's directory.

### Arduino

The proof-of-concept Arduino backend compiles a first-order fragment of
Tempore to allocation-free C++ and generates a PlatformIO project for an
Arduino or ESP32 board, with FreeRTOS tasks and run-time monitors. Grades are
erased; boxes and unboxing generate no code.

The fragment consists of top-level functions, fully applied, `let`, `match`
and `if`, natural numbers (32-bit, `+`, `*` and `nat_of_float` modulo 2^32),
integers (32-bit two's complement, the arithmetic, `int_of_nat` and
`int_of_float` modulo 2^32 into [-2^31, 2^31), so that `-2147483648i /! -1i`
is `-2147483648i`; a literal outside that range is refused), single-precision
floats, booleans, tuples, datatypes without type parameters
that are not recursive, `delay`, operation calls and self calls in tail
position, which become loops. Local functions, functions as values, partial
application, handlers, lists, strings other than constant arguments of
operations, and recursion other than self calls in tail position are refused,
each with a `Compilation error` at the construct.

Under a device manifest, the definitions checked and compiled are those
reached from the task functions and the `initial` functions of the manifest;
the other definitions of the program, such as handlers used only by `run`
commands of the interpreter, may lie outside the fragment. Without a manifest,
every top-level definition of the program is checked and compiled, with its
`run` commands under `--host-runs`.

An application is described in four layers.

- A **board profile** gives the PlatformIO board, libraries and build flags,
  the cores, the I2C buses and the capabilities of a board: `m5stack-gray`,
  `m5stack-fire`, `m5stack-core2`, `m5stack-cores3`, `esp32-devkit` and
  `esp32s3-devkit`.
- A **device manifest**, in JSON, names the board, the tasks, the time unit of
  the program (`ms` by default), the peripheral packages, the C++ binding file,
  the C++ function of the safe state, and the C++ models of devices and of the
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
  the state its `initial` function returns; a free task calls its function, of
  type `unit -> unit`, once, or, with `repeat`, each time it returns.
- A **peripheral package** declares operations, with their grades and default
  implementations, and implements them in C++; the operations return plain
  values, and the freshness of a reading is specified by the application,
  which boxes it. A package declares its operations once for each grade
  system it supports, in a file of its own, and may share types and
  functions across them. The packages below are declared under
  `time-interval-rational` and under the regular expressions of timed
  operations over rational delays (`regex-timed-*-rational-symbolic`), with
  their running-time bounds in milliseconds, and under `counts-upper-bound`,
  each call counting once:
  - `i2c`: `I2cWrite8`, `I2cWrite16`, `I2cWrite32`, `I2cRead8`, `I2cRead16`
    and `I2cRead32`, register transactions on the bus `Wire`;
  - `m5-imu`: `ReadImu`, the accelerometer and gyroscope of an M5Stack core,
    with the tilt filters `tilt_x` and `tilt_y`; a unit of the MPU6886 family
    is read in one transaction of 14 bytes and converted as by M5Unified,
    any other unit, such as the BMI270 of the CoreS3, by one
    `M5.Imu.update` followed by `M5.Imu.getImuData`, which converts the
    readings of that update without the further update of `M5.Imu.getAccel`
    and `M5.Imu.getGyro` when more than 256 µs have passed since the last
    one; its running-time bounds are given per board, `[0.55, 1.25]` ms on
    the Gray and `[0.2, 1.5]` ms on the CoreS3, and the declarations give
    the bounds that cover both; `ConfigureImu`, which sets the output data
    rate of the accelerometer without changing its range (the register
    ACC_CONF of the BMI270, the sample rate divider of the MPU6886), so that
    the conversion of M5Unified stays valid; and `CheckAtRest`, a check of
    plausibility, not a self-test: four readings started 6 ms apart, true if
    the unit is at rest;
  - `m5-display`: `ShowText`, `ShowNumber` and `ClearDisplay`, lines of text
    of size 2 written one below another, and `ShowTextAt` and
    `ShowNumberAt`, a text or a number written at a position in a size from
    1 to 4 over a band of the display filled first, so that it replaces the
    text of that band without a clearing; the next line follows below it;
    `ShowTimeAt`, a text followed by a duration as m:ss, and
    `ShowColourTextAt`, a text in a colour over a band of another;
    `DrawButton`, a button with a centred label; `DrawBar`, a horizontal bar
    filled to a length; and `DrawLevel`, a bubble level, a vial with a
    bubble at an offset from its centre, redrawn only when the bubble moves
    or changes colour; colours are of 24 bits, `0xRRGGBB`;
  - `m5-touch`: `Touched`, whether the screen is touched and where, read
    through `M5.Touch.update` under the I2C lock (the touch screens of the
    CoreS3 and the Core2, capability `touch`);
  - `m5-speaker`: `Beep`, which starts a tone of a frequency and a duration
    on the speaker and returns at once (capability `speaker`);
  - `bala2-base`: `SetMotors`, `ReadEncoders` and `ResetEncoders` of the base
    of the M5Stack BALA2, with a watchdog of the motor setpoints; the counts
    of the encoders increase in the direction in which a positive drive turns
    the wheel (the registers of the base count the other way, and the package
    negates them); its header `bala2_base.h` gives the application the drives
    last written and the counts last read, for logging outside the timed
    bindings.
- The **application** is the program with its binding file, which defines,
  for each further operation `Op`, the function
  `tempore_result_Op binding_Op(tempore_argument_Op)`, and the safe-state
  function.

The typechecker checks the function of each periodic task against its period:
the durations of its effect must lie below the period, as for
`step : float -> float # [0, 20)`, and under the regular expressions of
timed operations for `watch : float -> float # {ReadImu; Publish}`, whose
durations are those of the operations of its trace. Under grades that bound
no durations, such as the operation counts, the period is checked by the
monitor of the device only, and the operations have no running-time bounds.
Boxes specify how long a reading may be used and, under other grades, which
operations must or may not precede its use. Under the regular expressions of
timed operations, the examples write a grade as one expression, which is both
bounds: the operations it names are demanded, in its order, and the delays
between them are bounded below and above; another operation may come between
them only within a delay, at the upper bound of its running time. A box grade
without delays therefore excludes every operation it does not name, while a
box grade with a delay bounds the time but not the operations within it. These
guarantees are relative to
the declared bounds of the operations. The bounds of the packages and of the
examples are measured on the devices by their profile (`--profile` with
`--capture`, below): the lower bound is the least time measured, rounded
down, and the upper bound 1.5 times the greatest, rounded up. Each
declaration states its measurements, and how the bounds not measured
directly, such as those of the package `i2c`, are derived. The bounds of
`ConfigureImu`, `CheckAtRest`, `Touched` and `Beep` are measured on the
CoreS3 only. The least times of `ShowTextAt` and `ShowNumberAt` depend on
the text, so their lower bound stays that of `ShowText`. The bounds of `ShowTimeAt`, `ShowColourTextAt`, `DrawButton`,
`DrawBar` and `DrawLevel` are provisional, derived from those measurements,
and not yet measured.

The bounds a package declares hold on every board it supports. Where an
operation is measured to run within narrower bounds on a particular board,
the member `bounds` of the descriptor `package.json` gives them, by board and
operation, as closed intervals in the time unit of the declarations:

    "bounds": {
      "m5stack-gray": { "ReadImu": [0.55, 1.25] },
      "m5stack-cores3": { "ReadImu": [0.2, 1.5] }
    }

For the board of a manifest, these bounds replace those of the declarations
under every grade system that bounds durations: the interval grade of the
operation under `time-interval-rational`, and its `within` bounds under the
regular expressions of timed operations; under `counts-upper-bound` the
operations have no bounds to replace. The program is typed, and the monitors
of the device are generated, under the bounds of its board. An interpreter
run with `--package` takes those of the board named by `--board`, and else
those of the declarations; the web interface takes those of the board of its
manifest. Each board and operation of `bounds` must be a board profile and
an operation the package binds, and the default implementations take a time
within the bounds of every board. The examples name the board of their
manifest by `--board` in the run command of their header, and the figures in
their comments are those under its bounds. On the device,
each call of a binding function is monitored against these bounds and each step of a
periodic task against its period; a violation puts the device in its safe
state and stops the tasks, is logged, or is not checked, according to the
monitor policy `abort`, `warn` or `off`. On a board with a screen driven
through M5Unified the violation is also shown: under `abort` a red banner
across the middle of the screen, drawn once the safe state is entered, and
under `warn` a yellow line above the footer, with the number of the warnings
and the last of them, drawn every 500 ms by a task of the lowest priority.
Watchdogs, cut-offs and the safe state are mechanisms of the C++ packages and of the application, outside the
typing.

The project can be simulated on the host: the tasks run against host models
of the devices and of the physical world, in simulated time, and the log is
printed. The host model of the I2C bus charges a transaction with the
transfer of its bytes at the frequency of the bus and a time per address
phase measured on the M5Stack Gray, 110 microseconds unless the build flag
`TEMPORE_I2C_MODEL_PHASE_US` sets it.

The I2C buses of a board profile are started after M5Unified and then set to
their frequency, since M5Unified may already have started a bus that shares
their port at 100 kHz; the optional member `imu_frequency` of a profile sets
the frequency of the transactions with the inertial measurement unit
(`M5.Imu.setClock`, and the build flag `TEMPORE_IMU_FREQUENCY` of the package
`m5-imu`; 400 kHz by default).

Running times are measured on the device by its profile. With the build flag
`TEMPORE_PROFILE`, set by `--profile`, the monitors collect the number and
the least, mean and greatest running time of the calls of each operation and
of the steps of each periodic task, with the least and greatest interval
between the starts of consecutive steps and the overruns, since start-up; a
task of the lowest priority logs them as a table every 5 seconds
(`TEMPORE_PROFILE_INTERVAL_MS`). The statistics are updated after the clock
is read and the table is printed outside the timed calls, so that the
measurement does not lengthen what it measures. The trace of the build flag
`TEMPORE_TRACE` (for example in `PLATFORMIO_BUILD_FLAGS`), which logs each
event, lengthens the steps by the time of its serial output and is not
suited to measurement.

The directory [`examples/arduino/`](examples/arduino/) holds the following
examples, each with its manifest and binding file, grouped by board. The board
is that of the manifest, and its profile and serial port variable are named
below.

M5Stack Gray, the core of the M5Stack BALA2 self-balancing robot (profile
`m5stack-gray`, port variable `PORT_M5STACK_GRAY`):

- [`bala2/balance.tpe`](examples/arduino/bala2/balance.tpe): a 5 ms balancing
  step of the M5Stack BALA2 robot with its supervision and calibration, and
  the host model of a wheeled inverted pendulum; the build flag
  `BALANCE_LOG` (an interval in milliseconds, e.g.
  `PLATFORMIO_BUILD_FLAGS=-DBALANCE_LOG=20` with `--upload` and `--capture`)
  logs its tilt, gyroscope rate, drives and encoder counts from a task of
  the lowest priority, whose start, outside the bounds of `Publish`, the
  target `-log` reports under the monitor policy `warn`, and the build flag `BALANCE_RECORD` records them,
  with the speed and the reference tilt of the speed loop, for the first
  minute after the arming (see Recording a run, below); the
  constant `balance_point` sets the tilt at which the robot is upright;
- [`bala2-regex/balance_regex.tpe`](examples/arduino/bala2-regex/balance_regex.tpe):
  the same robot under the regular expressions of timed operations, sharing
  the binding file and host model of `bala2`: the step reads the unit, the
  encoders and the setpoints before it commands the motors, uses the reading
  of the unit only if no command of the motors and no delay came between,
  across any number of reads of the encoders and setpoints, and the
  supervision disarms, calibrates, arms at least a second after its prompt,
  drives and disarms, in this order; handlers, which the device does
  not use, simulate the robot and a fault of its gyroscope in the
  interpreter, each case of an operation performing that operation;
- [`wheels/wheels.tpe`](examples/arduino/wheels/wheels.tpe): a wheel check of
  the M5Stack BALA2 on a stand, under the regular expressions of timed
  operations: the counts of the encoders are divided by the length of the
  window only after a drive command, 100 to 101 ms and a reading of the
  encoders, in this order.

M5Stack CoreS3 and CoreS3 Lite (profile `m5stack-cores3`, port variable
`PORT_M5STACK_CORES3`):

- [`tilt/tilt.tpe`](examples/arduino/tilt/tilt.tpe): a tilt display on the
  M5Stack CoreS3 Lite, with a 20 ms filter step and a display task;
- [`peak/peak.tpe`](examples/arduino/peak/peak.tpe): a recorder of the peak
  tilt in the flash memory of the M5Stack CoreS3 Lite, under the operation
  counts: the step performs one reading and one publication and no write of
  the flash, and a copy of the record is used only while no write of the flash
  has followed it;
- [`level/level.tpe`](examples/arduino/level/level.tpe): a digital level on
  the M5Stack CoreS3 Lite, under the regular expressions of timed
  operations: a bubble vial, the pitch and the roll less the offsets of a
  reference, and the buttons "Set reference" and "Reconfigure sensor"; a
  reference is taken after the unit is held still for a second, and
  installed only after a check at rest, the reconfiguration of the unit by
  "Reconfigure sensor" invalidates it, and it is applied only to a reading that no reconfiguration or new
  reference precedes within its 250 ms step, and expires after 30 seconds;
- [`fall/fall.tpe`](examples/arduino/fall/fall.tpe): a fall detector on the
  M5Stack CoreS3 Lite, under the regular expressions of timed operations: a
  free fall of at least 100 ms followed within a second by an impact is a
  fall, after which a prompt, in orange, a tone and a countdown of 10
  seconds with a shrinking bar precede the alarm, in red, raised only 10 to
  30 seconds after the prompt unless a tap cancels, and stopped by a tap;
  while watching, in green, the screen shows the falls counted, the time
  since the last event and a bar of the acceleration.

The digital level is used as follows. Place it on the surface taken as the
reference and tap "Set reference"; it asks to hold still, and a second later
reads the unit and checks that it is at rest, with a high tone, or rejects
the reference as moved during the check, with a low tone. Placed on another
surface, it then shows the angles relative to the reference, the bubble
green and "LEVEL" within half a degree. The reference becomes invalid, and
must be set again, when it is rejected, when "Reconfigure sensor"
reconfigures the unit, which switches the output data rate of its
accelerometer between 100 and 400 Hz, shown at the top right, and when it
expires 30 seconds after it was set, its time left shown meanwhile. Without a valid reference the bubble is grey and the angles are
those of the unit.

The CoreS3 examples show their name at the top of the screen, in text of
size 2, and a footer at the bottom right, in text of size 1, by
`ShowTextAt`: the line "Typechecked by Tempore (tempore-lang.ee)" at the
column 320 − 6 · 40 = 80 of its 40 characters of 6 pixels; in `level` and
`fall` it is below a line of size 1 under the name that states the guarantee
of the example. They are drawn
after each clearing in `tilt`, `peak` and `fall`, outside their boxes, and
once by the initial function in `level`, which redraws its values by bands
and does not clear.

#### Command line
<!-- web-skip -->

    ./tempore --grades time-interval-rational \
      --emit-arduino balance \
      --device examples/arduino/bala2/balance.device.json \
      --host-simulate 8 \
      examples/arduino/bala2/balance.tpe

writes the PlatformIO project to `_arduino/projects/balance`, loading the
declarations of the packages of the manifest before the file, and simulates
it on the host for 8 seconds;

    ./tempore --grades time-interval-rational \
      --emit-arduino balance-profile \
      --device examples/arduino/bala2/balance.device.json \
      --monitor warn --profile --upload --port /dev/cu.usbserial-02012C91 \
      --capture 60 \
      examples/arduino/bala2/balance.tpe

builds the project with the profile, uploads it, and reads the serial port
for 60 seconds, printing the last profile at the end. A name without a directory component names a
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
- `--profile` builds the project with the profile (`-DTEMPORE_PROFILE` in
  `platformio.ini`), and under `--host-simulate` logs it in place of the
  trace, every 5 simulated seconds and at the end;
- `--capture <seconds>`, with `--upload` and `--port`, reads the serial port
  after the upload for the given time at the baud rate of the board, prints
  its lines and, with `--profile`, then the last complete profile; without
  `--upload`, it writes the project and reads the port of a board already
  programmed, without PlatformIO; the port
  is opened in raw mode with its modem control lines as opening it sets them,
  both asserted, which on the boards with an automatic reset circuit holds
  neither the reset nor the boot pin, and they are left so when it is closed;
- `--package <name>`, repeatable, loads the declarations of a package for the
  interpreter, which performs its operations by their default implementations;
  `--board <board>` gives them the running-time bounds of the packages on
  that board.

Each example `NAME` has the targets `make arduino-NAME-simulate` (the host
simulation), `arduino-NAME-build` (the PlatformIO build),
`arduino-NAME-upload` (the build and upload), `arduino-NAME-profile` (the
upload with `--profile`, then `--capture`), and, for `bala2` and
`bala2-regex`, `arduino-NAME-log` (the upload with `-DBALANCE_LOG`, then
`--capture`), `arduino-NAME-record` (the upload with `-DBALANCE_RECORD`,
then `--capture`) and `arduino-NAME-capture` (`--capture` without an upload,
saving the recordings); `make arduino-simulate-all` and `make arduino-build-all` run
the first two for every example, and `make examples-help` lists the targets
with the values of their variables. The targets that need PlatformIO install
it by `make arduino-deps` first. An upload goes to the serial port of the
board of the manifest, `PORT_M5STACK_GRAY` (by default
`/dev/cu.usbserial-02012C91`) or `PORT_M5STACK_CORES3` (by default
`/dev/cu.usbmodem101`), the ports of the boards of the development machine,
or else to `PORT` when it is set; the variables are set on the command line
or in the environment:

    make arduino-bala2-upload PORT=/dev/ttyUSB0
    make arduino-tilt-profile PORT_M5STACK_CORES3=/dev/ttyACM0 CAPTURE=60

`CAPTURE` is the time, in seconds, for which the port is read (default 30),
`SIMULATE` the simulated time of the host simulation (by default that of the
example), `MONITOR` the monitor policy (by default `abort`, and `warn` for
the targets that read the port), `BALANCE_LOG` the interval of the log in
milliseconds (default 20) and `BALANCE_RECORD` the interval of the samples of
a recording in milliseconds (default 20).

The targets are defined by [`examples/examples.mk`](examples/examples.mk)
from a fragment `example.mk` in the directory of the example, which holds one
manifest `PROGRAM.device.json` and its program `PROGRAM.tpe`. The fragment
sets the grades and the simulated time of the host simulation, in seconds,
and optionally the build flags of the targets `-log` and `-record` and the
awk program with which the target `-capture` extracts the recordings from
the serial output:

    EXAMPLE_GRADES = time-interval-rational
    EXAMPLE_SIMULATE = 8
    BALANCE_LOG ?= 20
    EXAMPLE_LOG_FLAGS = -DBALANCE_LOG=$(BALANCE_LOG)
    BALANCE_RECORD ?= 20
    EXAMPLE_RECORD_FLAGS = -DBALANCE_RECORD=$(BALANCE_RECORD)
    EXAMPLE_RECORD_FILTER = examples/arduino/bala2/recordings.awk

The board is that of the manifest, and its port the variable `PORT_BOARD`,
the name of the board in upper case with `-` replaced by `_`, such as
`PORT_ESP32_DEVKIT` for `esp32-devkit`; a board without a default port
needs `PORT` or that variable. A new example gets its targets by such a
fragment; `tests/make/examples.t` checks that every example has one, that
the targets its header names exist and run under the grades of its run
command, and that the targets `arduino-bala2-simulate` and
`arduino-bala2-profile` run the commands above.

Requirements:

- `make arduino-deps` installs PlatformIO Core 6.2.0 in the virtual environment
  `_arduino/venv`, with the first Python of version 3.10 or later; without
  `--pio`, `pio` on the `PATH` is used, or else that of `_arduino/venv`;
- PlatformIO keeps its platforms, toolchains and libraries in
  `PLATFORMIO_CORE_DIR`, set to `_arduino/platformio` for the `pio` of
  `_arduino/venv` unless the environment sets it; after building the examples,
  `_arduino` takes about 3 GB, and `make clean-arduino` removes it;
- the first build of a board downloads its platform and toolchain;
- uploading needs the USB-serial driver of the board: its port is listed by
  `ls /dev/cu.*` on macOS once the board is connected.

A board is added as a profile `boards/NAME.json` in
[`src/05-backends/arduino/`](src/05-backends/arduino/), a package as a
directory `libraries/NAME/` with a descriptor `package.json`, which maps each
grade system to a file of declarations and may give running-time bounds per
board, and the declarations, C++ sources and host models; both are embedded in the compiler
when it is built. An application is a `.tpe` file, a manifest and a binding
file, with host models for the simulation if needed.

#### Recording a run
<!-- web-skip -->

The BALA2 examples record a run without the USB cable under the build flag
`BALANCE_RECORD` of [`bala2/bindings.cpp`](examples/arduino/bala2/bindings.cpp),
the interval of the samples in milliseconds. From the first arming after
start-up, a task of core 0 takes 3000 samples (`BALANCE_RECORD_SAMPLES`), a
minute at 20 ms, of the tilt, the rate of the gyroscope, the filtered speed of
the wheels, the reference tilt of the speed loop, the drives of the motors and
the counts of the encoders; the control step only publishes the values. Once
complete, the recording is printed over the serial port as CSV every 10
seconds (`BALANCE_RECORD_REPEAT_MS`), between a line `# Recording N, run ID,
...` and a line `# End of recording N`, N its sequence number and ID a random
identifier drawn at the arming. The core keeps running on its battery when
the cable is removed, the USB-serial bridge of the M5Stack Gray being powered
by USB, so that the recording is read once the cable is connected again. The
recordings of the last two start-ups are kept in memory that is not
initialised at start-up: a recording survives a reset, such as one by the
serial port or a brownout, and is then printed with the recording of the new
start-up, but not a loss of power.

    make arduino-bala2-record

builds and uploads the project `_arduino/projects/balance-record` and reads
the port for `CAPTURE` seconds. The robot then calibrates, arms and records
on the cable; to record a run without it, remove the cable and reset the
core with its power button, which starts a new recording at the next arming.
After the run, with the core still on, connect the cable and run

    make arduino-bala2-capture CAPTURE=60

which reads the port for 60 seconds without an upload, writes its output to
`_arduino/recordings/bala2-TIME.log`, TIME the date and time, and the last
complete copy of each recording to `_arduino/recordings/bala2-TIME.csv`; a
copy takes about 11 seconds at 115200 baud. The targets
`arduino-bala2-regex-record` and `arduino-bala2-regex-capture` do the same for
`bala2-regex`. The script [`scripts/bala2-recording.py`](scripts/bala2-recording.py),
optional and of the Python standard library only,

    python3 -I scripts/bala2-recording.py _arduino/recordings/bala2-TIME.csv

summarises each recording: the tilt, the reference tilt, the speed, the travel
of the wheels, the time of a fall beyond the cutoff, the difference of the
counts of the wheels and its drift, the fraction of the time each wheel is at
rest, and the correlation of the speed with the reference tilt.

## Editor support
<!-- web-skip -->

`editors/vscode/` contains a minimal VS Code extension with syntax highlighting
for `.tpe` files. Package and install it with

    make vscode-extension

or by hand with

    cd editors/vscode
    npx --yes @vscode/vsce package
    code --install-extension vscode-tempore-*.vsix --force

then restart VS Code. Uninstall with

    code --uninstall-extension tempore.vscode-tempore

To work on the extension itself, open `editors/vscode` in VS Code and press F5
for an Extension Development Host with the extension loaded.

## License
<!-- web-skip -->

Tempore is released under the MIT license (see [`LICENSE`](LICENSE)).
It is derived from Matija Pretnar's
[Millet](https://github.com/matijapretnar/millet) and from Joosep Tavits's
[original Temporal Millet](https://github.com/joosepgit/temporal-millet), both
MIT licensed; their copyright notices are retained in `LICENSE`. The notices
for the third-party code bundled into or loaded by the web interface are
collected in [`THIRD-PARTY.md`](THIRD-PARTY.md).

## AI usage disclaimer
<!-- web-skip -->

Agentic AI tools (from Anthropic's Claude family) have been used to develop
parts of this prototype implementation.