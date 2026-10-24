# Opentrons backend

The proof-of-concept Opentrons backend compiles a Tempore program to a
single-file Opentrons Python protocol for the Opentrons Flex, accepted by the
Opentrons App and by the simulator `opentrons_simulate`.

- Grades are erased.
- The program is executed by an abstract machine included in the file, so
  that handlers, continuations and recursion behave as in the small-step
  interpreter.
- The calls of the operations are monitored against their running-time
  bounds while the protocol runs.

## Protocols and binding files

A protocol consists of the `metadata` and `requirements` of the protocol,
the runtime, the binding file, the compiled program and the function `run`
that the robot and the simulator call. Run as a script,
`python3 _opentrons/protocols/protocol.py`, the file executes the program as
the interpreter does, without the binding file.

The binding file, in Python, defines

- `setup(protocol)`, which loads the labware, pipettes and modules and
  returns a context object;
- for an operation `Op`, a function `Op(ctx, arg)` that performs the
  operation on the context object and the argument and returns its result.

A binding function declares the nominal duration of its action by
`tempore_elapse(seconds)`.

The binding file must not define the names `metadata`, `requirements` and
`run`, names beginning with `tempore_` or `_tempore_`, nor the names of the
top-level definitions of the compiled program.

## From programs to protocols

- Values. Arguments and results are Python values: a `nat` is an `int`, an
  `int` a `tempore_Int`, a subclass of `int`, a `string` a `str`, a tuple a
  `tuple` and `()` the unit value.
- Operations. An operation call that no handler handles calls the binding
  function of the operation, or else its default implementation, run outside
  every handler.
- Delays. `delay q` calls `protocol.delay` for `q` units of duration.
- Boxes. `box` binds the value it boxes and `unbox` the value it unboxes;
  neither generates an action.
- Handlers. Handlers are deep, as in the interpreter. The abstract machine
  keeps an explicit stack of frames, so that the depth of the Python stack
  does not grow with the recursion of the program, and a continuation may be
  dropped or resumed more than once.

The protocol is refused when

- the binding file defines no `setup` or defines a reserved name, or
- the code of a `run` command may perform an operation that has neither a
  binding function nor a default implementation and that no handler in that
  code has a case for.

Such an operation that a handler does have a case for is a warning if it is
atomic, and is accepted silently if it is compound, since a compound
operation is implemented by handlers only.

## Monitors and the time unit

Each call of a binding function is monitored against the running-time
bounds of its operation: those it declares by `within`, or else the
interval of durations its grade determines, such as `[2, 4]` for `! [2, 4]`
under `time-interval`. An operation with neither is not monitored.

A call outside its bounds ends the protocol with an error, is reported by a
comment, or is not checked, according to the monitor policy `abort`, `warn`
or `off`. Each run command is announced by a comment, each monitored call is
commented as it completes, and the value of the run is commented at its end.

In simulation the clock is virtual: it advances only by the delays of the
program and by the durations that binding functions declare. On the robot it
is the monotonic clock of the host, on which `tempore_elapse` has no effect.
A unit of duration of the program is a second unless `--time-unit` sets it.

## The simulator

The simulator is `opentrons_simulate` of the `opentrons` Python package
(tested with version 10.0.0), which needs Python 3.10 or later.
`make opentrons-deps` installs it in the virtual environment `_opentrons`,
and `make clean-opentrons` removes it, with the protocols in
`_opentrons/protocols`. A simulator installed otherwise is named by
`--simulator` or found on the `PATH`. A protocol run as a script needs only
Python 3.10 or later.

## Command line

    ./tempore --grades <grades> \
      --emit-opentrons protocol.py \
      --bind bindings.py \
      file.tpe

writes the protocol to `_opentrons/protocols/protocol.py`, creating the
directory if needed, and prints the path written.

A file name without a directory names a file in `_opentrons/protocols` of
the current directory, which git does not track; a name with a directory,
such as `./protocol.py`, is used as given.

Without `--bind`, only the compiled program is written. The options below
require `--bind`:

- `--api-level <level>` sets the `apiLevel` (default 2.30);
- `--time-unit <unit>` sets the length of a unit of duration: `seconds` (the
  default), `minutes`, `hours` or a positive number of seconds;
- `--monitor abort|warn|off` sets the monitor policy (default `abort`);
- `--simulate` runs the protocol with the simulator and exits with its exit
  code; `--simulator <path>` names the executable, by default
  `opentrons_simulate` on the `PATH`, or else that of the virtual
  environment `_opentrons` in the directory of `tempore` or in the current
  directory.

For example,

    ./tempore --grades time-interval \
      --emit-opentrons elisa.py \
      --bind examples/opentrons/elisa_bindings.py \
      --time-unit minutes \
      --simulate \
      examples/opentrons/elisa.tpe

writes the ELISA protocol to `_opentrons/protocols/elisa.py` and simulates
it.

### Make targets

Each example `NAME` has the targets

- `make opentrons-NAME-emit`, which writes its protocol to
  `_opentrons/protocols/NAME.py`;
- `make opentrons-NAME-simulate`, which also simulates it, installing the
  simulator by `make opentrons-deps` first.

Further targets and variables:

- `make opentrons-simulate-all` simulates every example;
- `make examples-help` lists the targets;
- `MONITOR=warn` sets the monitor policy.

### Fragments
<!-- web-skip -->

The targets are defined by
[`examples/examples.mk`](../../../examples/examples.mk) from a fragment
`examples/opentrons/NAME.mk` next to the example, which sets its grades and
its unit of duration:

    EXAMPLE_GRADES = time-interval
    EXAMPLE_TIME_UNIT = minutes

## Examples

The directory [`examples/opentrons/`](../../../examples/opentrons/) holds the
following examples, each with a binding file `NAME_bindings.py`, a fragment
`NAME.mk` and a rejected variant `NAME_reject.tpe`. The unit of duration of
each is a minute.

- [`elisa.tpe`](../../../examples/opentrons/elisa.tpe): an enzyme-linked
  immunosorbent assay under `time-interval`. The typechecker proves, under
  the declared running times of the operations:
  - the diluted detection antibody is added within 20 minutes of its
    dilution;
  - the plate is washed only after at least 60 minutes with the antibody;
  - the development is stopped 15 to 20 minutes after the substrate is
    added.
- [`washes.tpe`](../../../examples/opentrons/washes.tpe): a bead clean-up
  with two or more ethanol washes, under
  `regex-timed-rigid-interval-rational-symbolic`, each wash followed by a
  fresh tip and nothing else, with a strict binding, a strict air-dry and no
  removal of liquid off the magnet. The typechecker proves, under the
  declared running times of the operations:
  - the plate goes onto the magnet 5 to 10 minutes after the beads are mixed
    in, with only waiting in between;
  - the elution buffer is added only after at least two washes, each but the
    last followed by a fresh tip and nothing else;
  - the last wash is followed by an air-dry of 2 to 3 minutes, waiting only,
    and a fresh tip;
  - no supernatant is removed, no wash made and no eluate transferred while
    the plate is off the magnet;
  - the eluates are transferred after 2 to 5 minutes of settling, waiting
    only.
- [`contamination.tpe`](../../../examples/opentrons/contamination.tpe): a
  ddPCR plate set-up under `time-upper-bound-levels`, whose master mix is
  boxed `(30, High)` and unboxed for each dispensing. The typechecker
  proves, under the declared running times of the operations:
  - a tip is used only while it has touched nothing contaminated since it
    was put on, so that a tip that touched the test article is not used
    again;
  - the master mix is dispensed, each time, within 30 minutes of its
    preparation.
- [`reagents.tpe`](../../../examples/opentrons/reagents.tpe): a tagmentation
  with reagents boxed `[0, 30]`, under `time-interval`. The typechecker
  proves, under the declared running times of the operations:
  - each thawed reagent is dispensed within 30 minutes of its thawing;
  - a reagent taken from its window is dispensed before any further step.
- [`staggered.tpe`](../../../examples/opentrons/staggered.tpe): a fixation
  of columns at staggered times, under `time-interval`. The typechecker
  proves, under the declared running times of the operations:
  - each column, of any number, is rinsed 12 to 20 minutes after its
    fixative is added.
- [`beads.tpe`](../../../examples/opentrons/beads.tpe): a bead clean-up with
  beads boxed `[3, ∞)` and `[2, 3]`, under `time-interval`. The typechecker
  proves, under the declared running times of the operations:
  - the supernatant is removed, and the eluate transferred, only after the
    beads have been on the magnet at least 3 minutes;
  - the elution buffer is added 2 to 3 minutes after the last ethanol wash.
- [`binding.tpe`](../../../examples/opentrons/binding.tpe): a bead binding
  whose beads are mixed every 2 to 5 minutes, under `operation-spacing`. The
  typechecker proves, under the declared running times of the operations:
  - the beads are first mixed 1 to 2 minutes after the binding starts;
  - consecutive mixes start 2 to 5 minutes apart;
  - the binding ends at most 5 minutes after the start of the last mix.
- [`enzyme.tpe`](../../../examples/opentrons/enzyme.tpe): a reaction set-up
  whose enzyme mix is at most 30 minutes out of the cold block in total,
  under `mode-times`. The typechecker proves, under the declared running
  times of the operations:
  - each round returns the enzyme mix to the cold block at most 7 minutes
    after taking it out;
  - over the set-up the enzyme mix is out of the cold block at most
    30 minutes in total, and is back on it at the end;
  - a plate of reactions is loaded, filled and unloaded only while the
    enzyme mix is out, the block being free.
- [`stopread.tpe`](../../../examples/opentrons/stopread.tpe): a stop and
  read with plates boxed `[0, 30]`, under `time-interval`. The typechecker
  proves, under the declared running times of the operations:
  - each plate is read within 30 minutes of its stop;
  - the simulated reader keeps within the running times of Stop and Read,
    so that the bound holds under it.
- [`cleanup.tpe`](../../../examples/opentrons/cleanup.tpe): a bead clean-up
  whose compound operations are performed by a handler through the atomic
  operations, under `regex-timed-rigid-interval-rational-symbolic`. The
  typechecker proves, under the declared running times of the operations:
  - each compound step performs the atomic operations its declaration names,
    in order and within its delays;
  - the supernatant is removed only after the beads have settled on the
    magnet for 3 to 5 minutes;
  - the elution buffer is added only after exactly two ethanol washes and an
    air-dry of 2 to 3 minutes.
- [`purification.tpe`](../../../examples/opentrons/purification.tpe): a
  bead purification under `regex-timed-rigid-interval-rational-symbolic`
  whose steps each take the beads in a box and return them in the box of the
  next step, exactly two washes accepted, and whose eluates are boxed in two
  successive stages, all within a box of the time at room temperature. The
  typechecker proves, under the declared running times of the operations:
  - the beads bind for 5 to 10 minutes before the plate goes on the magnet,
    and settle for 3 to 5 minutes before the supernatant is removed;
  - there are exactly two ethanol washes, the ethanol of each standing 0.5
    to 1.5 minutes, waiting only;
  - the beads air-dry for 3 to 5 minutes before the plate is moved off the
    magnet for the elution buffer;
  - the eluates are taken after 2 to 5 minutes in the buffer and 2 to 5
    minutes of settling on the magnet;
  - the eluates reach the cold block at most 40 minutes after the beads are
    added, with no other step before the transfer, and take the master mix
    2 to 5 minutes later.

## Adding an example
<!-- web-skip -->

An example is a program `examples/opentrons/NAME.tpe` with its binding file
`NAME_bindings.py` and a fragment `NAME.mk`, which gives it its targets. Its
header gives the command that simulates it; `tests/make/examples.t` checks
that every example has a fragment and that its target `-simulate` runs that
command.
