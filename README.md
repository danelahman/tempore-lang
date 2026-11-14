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

1. temporally graded algebraic effects and effect handlers that are guaranteed
   to respect the temporal specifications of operation signatures,
2. [general effect and resource grades](#grade-algebras) in place of only
   natural-number-based time grades, which modelled only whole lower time bounds
   of programs and resources,
3. sub-typing and -effecting,
4. a number of concrete examples of such grades (e.g., ranging from time
   intervals to regular expressions based grades to grade lattices to watermark
   grades of resource usage to combinations of grades),
5. a cleaner and more systematic treatment of type inference with qualified
   principal types schemes,
6. [multiple backends](#backends): besides the small-step interpreter,
   proof-of-concept compilers of programs to C++ for Arduino and ESP32 boards,
   and to Python for protocols for Opentrons liquid-handling robots, with
   run-time monitors of the running times of operations, and
7. various usability improvements in the web-based user interface.

Tempore (and Temporal Millet before it) is built on Matija Pretnar's [Millet
Language](https://github.com/matijapretnar/millet) and follows the ideas of
[Ahman](https://doi.org/10.1007/978-3-031-30829-1_1) and [Ahman and
Žajdela](https://msfp-workshop.github.io/msfp2024/submissions/ahman+%c5%beajdela.pdf).

## Installing and running
<!-- web-skip -->

### Building

Requires OCaml 5.5 or later.

#### General OCaml dependencies

Install the OCaml dependencies with opam:

    make tempore-deps

#### Arduino backend dependencies

PlatformIO Core, used only to build and upload the projects of the Arduino
backend, is optional. It needs Python 3.10 or later, and is installed in the
virtual environment `_arduino/venv`, with its platforms, toolchains and
libraries in `_arduino/platformio`:

    make arduino-deps

Only the options `--build` and `--upload` need it. The first build for a board
downloads its platform and toolchain, and an upload needs the USB-serial driver
of the board, whose port `pio device list` then lists. `make clean-arduino`
removes `_arduino`, together with the projects written to `_arduino/projects`.

#### Opentrons backend dependencies

The Opentrons simulator, used only to simulate the protocols of the
proof-of-concept [Opentrons](#opentrons) backend, is installed separately. It
needs Python 3.10 or later:

    make opentrons-deps

Only the option `--simulate` needs it.

#### Building Tempore

Build the language:

    make

Run the test suite, which takes about a minute:

    make test

The tests of the Opentrons backend run the generated Python and need Python 3.10
or later. They are skipped when `python3` is absent or older.

Remove the build (the Opentrons simulator and the protocols in `_opentrons` are
kept):

    make clean

#### Docker container

[`.devcontainer/`](.devcontainer/) holds a development Docker container with all
the dependencies installed. It can be used in VS Code with the Dev Containers
extension.

### Running Tempore from the command line

    ./tempore file1.tpe file2.tpe ...

loads the listed `.tpe` files, typechecks them, runs every `run` command in
them, and prints each `run` result with its final resource state.

Exit codes:
- 0 for success.
- 1 for a rejected program or another error (such as an unknown grade algebra).
- 2 for malformed options or an exhausted stack.
- 3 for when the program is accepted but a run fails.

A run fails at an operation call without a handler or a default implementation,
or at a run-time error such as a division by zero.

Command-line options:

- `--grades <grades>` selects the [effect and resource grade algebra](#grade-algebras) 
  (default `time-lower-bound`).
- `--resource-grades <grades>` selects a [resource grade algebra](#grade-algebras) 
  other than that of `--grades`, but only if the grade
  algebras form a [supported grade system](#grade-systems).
- `--typecheck-only` typechecks the files without running them.
- `--no-stdlib` skips importing the standard library.
- `--debug` also prints the inferred type schemes of the top-level definitions
  of the standard library and of the `.tpe` files passed on the command line.
- `--timeline` prints the [timeline](#interpreter) of each run after its result,
  as a table, with long grades shortened. 
- `--timeline-full` prints the timeline with the grades in full.
- `--emit-opentrons <file.py>` typechecks the files, compiles them to Python, 
  and writes them to `file.py`, without running them. A file name without a
  directory names a file in `_opentrons/protocols`.
- `--emit-arduino <directory>` typechecks the files, compiles them to C++, and
  writes them to `directory`, without running them. A name without a directory
  component names a directory in `_arduino/projects`. See Arduiono backend's
  [README](src/05-backends/arduino/README.md#command-line) for further options.
- `--package <name>`, repeatable, loads the declarations of a peripheral
  package of the Arduino backend before the files, so that a program run by
  the interpreter performs its operations by their default implementations.
- `--help` lists the options and the available grade algebras.

The [`examples/`](examples/) directory holds example programs grouped by topic
and backend, each opening with the command that runs it on the command line.

A reading order, one example per concept:

1. [`introduction/sensor_reading.tpe`](examples/introduction/sensor_reading.tpe):
   temporal resources, time grades, operations and handlers
2. [`introduction/stale_calibration.tpe`](examples/introduction/stale_calibration.tpe):
   temporal resources grades as regular languages of traces
3. [`basics/eternal_types.tpe`](examples/basics/eternal_types.tpe): which
   values survive non-trivial time passages and effects
4. [`handlers/lower_bound.tpe`](examples/handlers/lower_bound.tpe) and
   [`handlers/upper_bound.tpe`](examples/handlers/upper_bound.tpe): the
   handler's operation case's continuation as a boxed resource
5. [`banked_traces/3d_printing.tpe`](examples/banked_traces/3d_printing.tpe):
   traces of operations with running times
6. [`regular_trace_languages/upper_bounds.tpe`](examples/regular_trace_languages/upper_bounds.tpe) and
   [`banked_regex/intervals_rational.tpe`](examples/banked_regex/intervals_rational.tpe):
   protocols and windows as regular expressions
7. [`timed_regex/upper_bounds_rational.tpe`](examples/timed_regex/upper_bounds_rational.tpe):
   operations demanded in order
8. [`lattice/time_upper.tpe`](examples/lattice/time_upper.tpe): a product
   of time with a grade lattice
9. [`grade_systems/session_key.tpe`](examples/grade_systems/session_key.tpe):
   effects and resources graded by different grade algebras

The remaining files under `examples/` vary them over further grade algebras and
are linked from the [grade algebra reference](#grade-algebra-reference).

### Running Tempore from the web interface

Open `web/index.html` after building, or use
<https://tempore-lang.ee/>.

The page has an editor for the program, a gallery of examples, and selectors
for the backend and the grades.

A program is loaded from the gallery or written in the editor, typechecked, and
run using the interpreter step by step, with its resource usage shown.

#### Grade selection

Two selectors choose the grades the program is typechecked under:

- The grade algebra selector chooses the grade algebra of the effects (see
  [Grade algebras](#grade-algebras)).
- The resource grade algebra selector, under it, chooses the grade system (see
  [Grade systems](#grade-systems)). "Same as effects" is the identity system.
  The other choices are the resource grade algebras that a supported grade
  system pairs with the selected effect grade algebra.

The resource grade algebra selector is disabled when no grade system pairs the
selected effect grade algebra with another one. When the effect grade algebra
changes to one that the selected resource grade algebra is not paired with, the
selector returns to "Same as effects".

Loading an existing example selects the grades of both selectors accordingly.

#### Backend selection

The backend selector chooses between the interpreter, Arduino and Opentrons
(see [Backends](#backends)).

Choosing a backend loads its default example and makes the gallery list the
examples of that backend.

The icon in the top right corner of the editor switches between the program and
the compiled code, and any other required inputs of the compiled code.

#### URL parameters

The query parameters of the web interface's URL name and determine what the page shows:

| Parameter   | Meaning                                                                      |
| ----------- | ---------------------------------------------------------------------------- |
| `example`   | the example, by its path relative to `examples`                              |
| `grades`    | the grade algebra                                                            |
| `resources` | the resource grade algebra, the grade algebra itself for the identity system |
| `backend`   | the backend: `interpreter`, `arduino` or `opentrons`                         |
| `line`      | a line of the example to highlight, from 1                                   |

An example is
<https://tempore-lang.ee/?example=arduino/bala2/balance.tpe&line=42>.

With `example`, the parameters `grades`, `resources`, and `backend` are needed
only where they differ from those of the example.

## Temporal resources

A value of modal type `[rho]a` is an `a`-typed resource that may be used only
once/until the [grade](#grade-algebras) `rho` has accumulated since the resource
was created or brought into scope.

### Boxes and unboxing

`box rho e` creates a resource of type `[rho]a`, where `e` has to be well-typed
in the future in which the grade `rho` has hypothetically accumulated.

`unbox e` opens a resource `e : [rho]a` for use, and is allowed only if the
grade accumulated since boxing is bounded by `rho` (i.e., below `rho` in the
[grade order](#grade-algebras)).

Under the `time-lower-bound` grades, where resources are graded by the least
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

`delay tau` advances the accumulated grade by a (time) duration`tau`. Each
[grade algebra](#grade-algebras) has its own notion of delay durations, and maps
them to grades by a monoid morphism, so `delay 0` has the unit grade and `delay
tau; delay tau'` has the grade of `delay (tau + tau')`
([`delay.mli`](src/01-language/grades/delay.mli)).

`tau` is a non-negative integer or, under a grade algebra supporting rational
delays, a non-negative rational number, such as `delay 1/3` or `delay 0.25`.

## Grade algebras

Resources and the effects of computations are graded by a grade algebra, a
preordered monoid with a greatest element `⊤` and binary joins
([`grade.mli`](src/01-language/grades/grade.mli)). Sequencing multiplies grades
in the monoid, a branching joins the grades of its branches, and the order
compares an accumulated grade with a box grade or a grade annotation.

The grade algebra is chosen at run time with the `--grades` option or the
**Grade algebra** selector in the web interface, e.g.,

    ./tempore --grades time-interval examples/time/intervals.tpe

`./tempore --help` lists the available grade algebras by family. 

Grade algebras also optionally declare properties that the solver can use to
decide more grade orderings, such as that the unit is the least element, the
multiplication is commutative, or that a grade has a closure, i.e., the least
grade that covers doing it once or any greater number of times in a row.

The [grade algebra reference](#grade-algebra-reference) near the end of this
README describes each grade family, its literals, and its examples.

### Grade families and names

The grade families include bounds on time, sets and regular languages of traces
of operations and delays, grade lattices, and counts of calls. A name states the
family and, where the family has several variants, the variant:

- `-lower-bound`, `-upper-bound` and `-interval`: what a computation must at
  least take or perform, what it may at most, or both, as an interval;
- `-rational`: delays and running times are non-negative rationals rather than
  whole time steps;
- `-symbolic`: the representation by symbolic regular expressions.

For example, `banked-traces-upper-bound-rational` is the upper bounds version of
the trace grades with banked delays over rational number `delay`s, and
`time-upper-bound-lattice` the product of the time upper bounds grades with a
grade lattice.

Under some grade algebras the orders read running-time bounds that atomic
operations declare (see [Operations and their
grades](#operations-and-their-grades)).

### Grade literals

All grade algebras share one literal syntax: integers (`3`), fractions (`3/2`,
or exact decimals such as `1.5`), tuples (`(3, High)`), intervals and brace
expressions (`{...}`).

An interval has the standard mathematical meaning: a bracket includes its finite
endpoint and a parenthesis excludes it, as in `[1, 4]`, `(1, 4)`, `[1, 4)`,
`(1/2, 4]`, `[1, ∞)`, `(1, ∞)`, `(-∞, 4]`, `(-∞, ∞)` (ASCII `inf` and `-inf`) or
`[{A}, {A; B}]`.

- An infinite endpoint is always open, so `[1, ∞]` is a syntax error.
- An empty interval, such as `(1, 1)`, `[1, 1)` or `[4, 1]`, is rejected.
- Over whole time steps an open endpoint abbreviates a closed one: `(1, 4)` is
  `[2, 3]` and `(1, ∞)` is `[2, ∞)`.

Each grade algebra accepts the literals it understands. Any other literal is a
syntax error naming the grade algebras that accept it. The greatest grade is
`⊤` (ASCII `top`).

### Grade systems

A grade system grades effects by one grade algebra and resources by another,
with a morphism `∣_∣` from the former to the latter: it is monotone and
preserves the unit, products, the top, joins and delays. A continuation is
behind a lock of the resource grade `∣ε∣` of the effects `ε` before it, and an
`unbox` compares the accumulated resource grade with the resource's box grade.
Under `--grades` alone, one grade algebra grades both, `∣ε∣` being `ε`.

`--grades` names the effect grade algebra and `--resource-grades` the resource
grade algebra:

    ./tempore --grades time-interval --resource-grades time-lower-bound \
      examples/grade_systems/proofing.tpe

The literals of boxes `box ρ e` and of box types `[ρ]a` are read by the
resource grade algebra, and those of effects `! ε`, operation signatures
included, by the effect grade algebra. A pair without a system is refused.

`./tempore --help` lists the supported pairs under `--resource-grades`, and
[Supported grade systems](#supported-grade-systems) lists them with their
morphisms. See the examples
[`approvals.tpe`](examples/grade_systems/approvals.tpe),
[`latte.tpe`](examples/grade_systems/latte.tpe),
[`proofing.tpe`](examples/grade_systems/proofing.tpe),
[`seats.tpe`](examples/grade_systems/seats.tpe),
[`session_key.tpe`](examples/grade_systems/session_key.tpe) and
[`token.tpe`](examples/grade_systems/token.tpe) in
[`examples/grade_systems/`](examples/grade_systems/).

## Eternal types

A type is *eternal* if its values stay valid however much grade accumulates as a
result of computations. Base types, tuples, and algebraic types built from
eternal types are eternal; function, handler, and box types are not.

A local variable of a non-eternal type may be used only while the grade
accumulated since its binding is a sub-grade of the unit grade. Where the unit
is the top grade, as under the lower bounds on time, this always holds, and
there nothing ever expires once available for use. Under other grade algebras
such a variable must be used before any non-trivial delay or operation call.

### Type schemes and qualifiers

When eternality depends on a type variable of a top-level definition, it becomes
a qualifier of the definition's type scheme, checked at each use.

Under `time-upper-bound`, the program `let keep x = delay 1; x` gets the type
scheme

    ∀ α. Et(α) ⇒ α → α ! 1

so `keep 5` is accepted by the typechecker and `keep (fun () -> ())` is
rejected.

See [`examples/basics/eternal_types.tpe`](examples/basics/eternal_types.tpe).

### Non-eternal declarations

Types can also be explicitly declared to be non-eternal.

For example, `noneternal type epoxy = Epoxy` makes `epoxy`, and every type
containing it, non-eternal.

## Algebraic effects and effect handlers

### Operations and their grades

```
operation Read : unit ~> string ! 2
```

declares an operation whose call `perform Read ()` has grade `2`. 

Under the grade algebras whose orders read running-time bounds, an *atomic*
operation, graded by its own name, also declares its running-time bounds
(`within [n, m]`):

```
operation Tx : string ~> unit ! {Tx} within [2, 3]
```

The bounds are durations, written as for `delay` (see [Delays](#delays)), with
`lo <= hi` and `hi` positive. Either end may be open, as in `within (lo, hi)`,
`within [lo, hi)` or `within (lo, hi]`, the interval being non-empty. The
running time is positive: `lo` is above 0, or open at 0, as in
`within (0, 1]`. Over whole time steps an open end abbreviates a closed one,
`within (1, 4)` being `within [2, 3]`.

A *compound* operation names other operations in its grade, and its bounds are
computed from theirs: `Send : string ~> unit ! {Tx | Tx; Tx}` gets `[2, 6]`.

### Handlers and continuations

```
handle e with
  handler
  | x -> return-case
  | Op p k -> operation-case
```

The return case comes first and may be omitted, in which case it is `x -> x`.

An operation case receives the argument `p` and the continuation `k`, resumed
with `continue k with v`. Unhandled operations are forwarded. The continuation
is a resource boxed with the operation's grade, resumed only once the operation
case has accumulated a sub-grade of that grade: under `time-lower-bound`, `Get
() k -> delay 71; continue k with 42` handles `Get ! 71`. A case is checked for
every effect its continuation may have; a failure names the instance:

    Note: the effect inequality `∀ε_Op. 0 >= 1 · ε_Op` does not hold: for
      `ε_Op = 0` it becomes `0 >= 1`

See [`examples/handlers/lower_bound.tpe`](examples/handlers/lower_bound.tpe),
[`examples/handlers/upper_bound.tpe`](examples/handlers/upper_bound.tpe)
and [`examples/handlers/3d_printing.tpe`](examples/handlers/3d_printing.tpe);
a condition on a variable of the definition becomes a hypothesis of its
scheme ([Qualified type schemes](#qualified-type-schemes),
[`examples/handlers/qualified.tpe`](examples/handlers/qualified.tpe)).

### Contexts of operation cases

An operation case is typed with the top grade `⊤` accumulated for the variables
bound outside it, because operation cases need to be executable anywhere in
the computation tree when handling.

- Where the top is the unit, as under the lower bounds on time, this restricts
  nothing.
- Under the other grade algebras an outer variable of non-eternal type,
  including an outer continuation, cannot be used in the operation case, and an
  outer box can be unboxed only if `⊤` is below its grade.
- The operation case's own `p` and `k`, and top-level definitions, are
  unaffected, as they are bound after `⊤` in the case's context.

See [`examples/handlers/nested.tpe`](examples/handlers/nested.tpe)
and
[`examples/handlers/nested_reject.tpe`](examples/handlers/nested_reject.tpe).

### Default implementations

```
default Heat () = delay 1
```

gives the operation `Heat` a default, run only when a call of it reaches the top
level unhandled in a `run` command, e.g., here it simulates the running time of
`Heat` by a delay.

Where operations declare running-time bounds:

- only atomic operations (see above) can have defaults;
- a default's grade must be a sub-grade of `{lo}` under lower bounds, `{hi}`
  under upper bounds, and `[{lo}, {hi}]` under intervals;
- the running-time bounds its grade implies must moreover lie within the
  declared ones, as far as the grade algebra checks them (see [Timed regex
  grades](#timed-regex-grades)).

Elsewhere, a default's grade must be a sub-grade of the operation's grade.

## Recursion

`let rec f p₁ … pₙ = c` must be structurally recursive to ensure termination.

Like an effect handler's operation case, `c` is typed with the top grade `⊤`
accumulated for the local variables bound outside it (see [Contexts of
operation cases](#contexts-of-operation-cases)); `f` itself may be called
anywhere in `c`, including after delays and in operation cases.

A recursive function has the unit effect unless it is annotated as
`let rec f p₁ … pₙ : ty ! ε = c`. Then
`f : A₁ → … → (Aₙ → ty ! ε)`, the outer arrows having the unit effect, and `ε`
must bound the effect of `c` assuming every recursive call has effect `ε`.

Under `regular-trace-languages-symbolic`,
```
let rec read_all n : nat ! {Read*} =
  match n with
  | 0 -> 0
  | m + 1 -> let x = perform Read () in let y = read_all m in x + y
```

is accepted.

Under `time-upper-bound`, a loop with `delay 1; wait m` in each round is bounded
by `⊤` but by no `n`.

## Type inference

Types, grades and effects are inferred in Hindley--Milner style with constraints
and qualified principal type schemes. 

Types are compared by subtyping: functions are contravariant in the argument and
covariant in the result and effect, and a box `[rho]a` is contravariant in
`rho`.

### Qualified type schemes

Top-level `let` definitions are generalised to qualified type schemes,

    ∀ α ρ₀ ε₀. Q ∧ R ⇒ A

where

- `Q` constrains the type, resource (`ρ`) and effect (`ε`) variables;
- `R` lists the conditions of operation cases that must hold for every effect
  of their continuations;
- `∣ε∣` is the resource grade accumulated while `ε` runs.

A condition is printed `∀ε_Op. …`, `ε_Op` being the effect of the continuation
of a case for `Op`, primed (`ε_Op′`) for another case for `Op`. 

`--debug` prints the inferred type schemes of top-level definitions.

Under `time-upper-bound`, the standard library's `compose f g x = f (g x)` has
type scheme

    ∀ α β γ ε₀. (α → β ! ε₀) → (γ → α) → (γ → β ! ε₀)

where `g` takes no time, since the non-eternal `f` is used after it: the
qualifier `∣ε₁∣ ≾ 0` on the effect `ε₁` of `g` admits only the least value `0`,
which the solver decides and the  type scheme substitutes. An effect of the unit
is not printed on a function arrow, but is printed on both sides of a handler
type `A ! ε ⇛ B ! ε′`.

Under `time-lower-bound`, with `operation Op : unit ~> unit ! 1`, the top-level
effect handler

    let via f = handler 
      | x -> x 
      | Op () k -> f (); continue k with ()

has type scheme

    ∀ α β ε₀ ε₁. ∣ε₀∣ ≾ 1 ∧ (∀ε_Op. ε_Op · ε₀ ≾ 1 · ε_Op) ⇒ (unit → α ! ε₀) → (β ! ε₁ ⇛ β ! 0)

where `R`, `∀ε_Op. ε_Op · ε₀ ≾ 1 · ε_Op`, states that for every effect `ε_Op` of
`k` the operation case (calling `f` followed by `k`) takes at least the time of
`Op` followed by `k`. See
[`examples/handlers/qualified.tpe`](examples/handlers/qualified.tpe), where such
a type scheme is met at one use and refuted at another.

For a `run` to typecheck, it must establish every such qualified condition: one
without unknowns that the typechecker can neither derive nor refute rejects it,
and one with unknowns must hold together with `Q` at a closed instance of them.

### Type and grade annotations

A function's computation type may be annotated, `let f () : nat ! 3 = ...`; the
body's grade must be a sub-grade of the annotation. Types may contain variables
`'a`, and grades may be variables `'e` or `'r`: within a top-level definition,
the same name is the same unknown, inferred and generalised with it. A name also
written after `!` stands for the resource image `∣ε∣` of that effect in box
grades. `let pass (f : unit -> nat ! 'e) : nat ! 'e = f ()` has the grade of
`f`.

Type-constructor application binds tightest, then the box `[rho]`, then
products `a * b`, which are n-ary and non-associative, and last arrows
`a -> b ! e`, which are right-associative: `[2]nat list * bool -> nat` takes
a pair of a `[2](nat list)` and a `bool`, and a box of a function is written
`[2](nat -> nat)`.

An effect `! e` belongs to the innermost arrow, so `nat -> nat -> nat ! 1` is
`nat -> (nat -> nat ! 1)`, and an arrow without one has the unit effect.

Printed types use the same precedences and leave out an effect of the unit; a
result that is a function type is printed in parentheses where either arrow
shows its effect, `nat → (nat → nat ! 1)`.

### Sub-effecting

A computation may be used where one of a super-grade is expected. Under
`time-upper-bound`,

```
let apply (f : unit -> nat ! 2) = f ()
let slow () = delay 1; 3
let branch c = if c then delay 1 else delay 2
```

`apply slow` is accepted, `unit → nat ! 1` being a subtype of
`unit → nat ! 2`, and `branch` has the type `bool → unit ! 2`. 

A box type is contravariant in its grade: under `time-lower-bound`, a `[2]nat`
is accepted where a `[3]nat` is expected, but a `[4]nat` is not. 

A handler type `A ! ε ⇛ B ! ε′` is contravariant in its input `A ! ε` and
covariant in its output `B ! ε′`.

Limits:

- type-constructor arguments are compared by equality: a
  `(unit -> nat ! 1) list` is not accepted where a `(unit -> nat ! 2) list` is
  expected;
- local `let` definitions are not generalised;
- the continuation effect of an operation case is rigid (see
  [Handlers and continuations](#handlers-and-continuations));
- satisfiability of a qualifier is decided provisionally: a definition is
  rejected only when its qualifier is refuted, and each use checks it; a `run`
  must have a closed instance of its whole qualifier `Q ∧ R` among finitely many
  grades per unknown.

## Backends

A program is executed by one of three backends.

### Interpreter

The interpreter evaluates the program by a small-step reduction relation and
tracks the resource state: both the boxed resources and the accumulated grade. A
`run` command prints its result with the final resource state. The web interface
can also step through the individual reductions and shows the resource usage.

#### Natural numbers and floats

Natural numbers are unbounded and floats are of double precision. Besides the
arithmetic operators, the standard library provides

- `float_of_nat`, the nearest float, infinity beyond the range;
- `nat_of_float`, truncated toward zero, 0 for a negative float and for NaN,
  and a run-time error for infinity, as division by zero;
- `sqrt`, NaN for a negative float;
- `atan`;
- `atan2 (y, x)`, the angle of the point `(x, y)` from -π to π, with the
  special cases of C.

#### Integers

Integers, of type `int`, are unbounded and written with the suffix `i`: `3i`,
`0x1fi`, and, as the negation of a literal, `-3i`. 

- Their operators are `+!`, `-!`, `*!`, `/!` and `mod!`, of the precedences
  of `+`, `-`, `*`, `/` and `mod`, and the negation `~-!`.
- Division and `mod!` truncate toward zero, as in C, the remainder having the
  sign of the dividend, and division or modulo by zero is a run-time error.
- The conversions are `int_of_nat`; `nat_of_int`, 0 for a negative integer;
  `float_of_int`, the nearest float; and `int_of_float`, truncated toward
  zero, 0 for NaN, and a run-time error for infinity.
- A match on integers needs a case for every other integer, such as a
  wildcard.

As in OCaml, `x -3i` is read as a subtraction, not as `x` applied to `-3i`, and
the subtraction of integers is written `x -! 3i`.

#### Timelines

The timeline of a run lists, in grades, what reaches its top level: the delays,
the calls of operations that no handler handles and that are performed by their
default implementations, and the resources boxed and unboxed, by the name of the
variable they are bound to.

- A delay, an operation or a box has a grade: that of the delay, the declared
  grade of the operation, or the grade the resource is boxed at.
- Boxing and unboxing add nothing to the grade accumulated.
- The events of a default implementation, the operations it performs among
  them, are listed below its operation, indented by `·`.
- Each row at the top level starts at the grade accumulated before it, the
  product of the grades of the rows at the top level above it.
- Operations handled by handlers, and their continuations, are not listed;
  the steps of a handler's case are listed as they happen.

The timeline displays the interpreter's run that checks nothing additional, the
program having been successfully typechecked before it runs. The command-line
option `--timeline` prints the timelines after each run, e.g.

    ./tempore --grades time-interval-rational --timeline examples/introduction/sensor_reading.tpe

prints

    Timeline
    Run  Start       Event          Grade
    1    [0, 0]      delay          [0.1, 0.1]
    1    [0.1, 0.1]  box reading    [5, 10)
    1    [0.1, 0.1]  Compute        [6, 8]
    1                · delay        [7, 7]
    1    [6.1, 8.1]  unbox reading
    1    [6.1, 8.1]  AngleOf        (0, 1]
    1                · delay        [0.5, 0.5]
    1    (6.1, 9.1]  SetAngle       (1, 2)
    1                · delay        [1.5, 1.5]
    Run 1 returned () at (7.1, 11.1).

Long grades are shortened for display between their events, the grade
accumulated to its last events and a box grade to its first;
`--timeline-full` prints them in full.

### Arduino

The proof-of-concept Arduino backend compiles a fragment of Tempore to
allocation-free C++ and generates a PlatformIO project for an Arduino or ESP32
board, with FreeRTOS tasks. A device manifest names the board, the periodic and
free tasks and the peripheral packages, which declare operations with
running-time bounds measured on the boards or from specifications. The program
is typed against those bounds and the periods of its tasks, and run-time
monitors on the device check them. The details and the examples, in
[`examples/arduino/`](examples/arduino/), are in
[`src/05-backends/arduino/README.md`](src/05-backends/arduino/README.md).

#### Quick start
<!-- web-skip -->

    make arduino-deps
    make examples-help
    make arduino-tilt-simulate
    make arduino-tilt-upload

install PlatformIO, list the targets of the examples, simulate the tilt
display on the host, and build and upload it. 

Each example `NAME` has the targets `arduino-NAME-simulate` and
`arduino-NAME-upload`; an upload goes to the port `PORT` when it is set, else to
that of the board of the manifest, such as `PORT_M5STACK_CORES3`, and else to
the port of the connected board, if found by its USB identifiers.

### Opentrons

The proof-of-concept Opentrons backend compiles the program to a single-file
Opentrons Python protocol for the Opentrons Flex, accepted by the Opentrons
App and by the simulator `opentrons_simulate`. A binding file in Python loads
the labware, pipettes and modules and implements the operations. The program
is executed by an abstract machine included in the file, and run-time
monitors check the running-time bounds of the operations. The details and the
examples, in [`examples/opentrons/`](examples/opentrons/), are in
[`src/05-backends/opentrons/README.md`](src/05-backends/opentrons/README.md).

#### Quick start
<!-- web-skip -->

    make opentrons-deps
    make examples-help
    make opentrons-elisa-simulate

install the Opentrons simulator, list the targets of the examples, and write
the ELISA protocol to `_opentrons/protocols/elisa.py` and simulate it. 

Each example `NAME` has the targets `opentrons-NAME-emit` and
`opentrons-NAME-simulate`; `MONITOR=warn` sets the monitor policy.

## Grade algebra reference

The grade families below follow the groups of `./tempore --help`. Each entry
gives the name of a grade algebra and its meaning. 

The interfaces in [`src/01-language/grades/`](src/01-language/grades/) document
the orders, literals and decision procedures in full, and the examples linked
show each family at work.

### Time

A grade bounds the number of time steps, or ticks, a computation takes.

- `time-lower-bound`: at least `n` ticks, also written `[n, ∞)`; ordered by
  `>=`, so the unit `0` is the top.
- `time-upper-bound`: at most `n` ticks, also written `[0, n]`, `∞` being no
  bound; ordered by `<=`, so the unit `0` is least.
- `time-interval`: `[n, m]`, between `n` and `m` ticks, and `[n, ∞)`, at least
  `n`; ordered by containment, with top `[0, ∞)`.

The `-rational` variants measure time by non-negative rationals, and an end
may be open: `(q, ∞)` is more than `q` units, `[0, q)` less than `q`, and
`(4, 6]` more than four units and at most six. A sum of intervals is open at
an endpoint if either summand is, so `[1, 2) · [1, 1]` is `[2, 3)`.

Examples: [`time/upper_bounds.tpe`](examples/time/upper_bounds.tpe),
[`time/intervals.tpe`](examples/time/intervals.tpe),
[`time/open_lower_bounds.tpe`](examples/time/open_lower_bounds.tpe) and
[`time/intervals_rational.tpe`](examples/time/intervals_rational.tpe).

### Finite run sets

A grade is a non-empty finite set of *traces*, the sequences of operations and
delays a computation may exhibit: `Read; 3; Send` performs `Read`, waits three
ticks, and performs `Send`. Adjacent delays are merged. Grades multiply by
concatenation and join by union. Operations declare no running-time bounds.

- `finite-run-sets` and `finite-run-sets-rational`: the set of traces a
  computation is *allowed*, ordered by inclusion, with whole or rational
  delays. The unit `{skip}` is the empty trace, and `⊤`, any trace, is the
  top.

Literals are those of the trace grades with banked delays, such as
`{Unlock; 3; Lock | Alarm}`. The closure of a grade other than `{skip}` is `⊤`.

Examples:
[`finite_run_sets/upper_bounds.tpe`](examples/finite_run_sets/upper_bounds.tpe)
and
[`finite_run_sets/upper_bounds_rational.tpe`](examples/finite_run_sets/upper_bounds_rational.tpe).

### Trace grades with banked delays

The grades are finite sets of traces, and every atomic operation declares
running-time bounds `within [lo, hi]`, which the orders use to trade time
against operations in the traces.

- `banked-traces-lower-bound`: the traces a computation must *cover*, an
  operation performed counting as `lo` ticks towards a demanded duration;
  `{skip}` is the top.
- `banked-traces-upper-bound`: the traces a computation is *allowed*, a
  duration paying for operations at their `hi`; `{skip}` is least and `⊤` the
  top.
- `banked-traces-interval`: intervals `[{...}, {...}]` of a lower and an upper
  bound, compared componentwise; `[{...}, ∞)` has no upper bound and `{...}`
  abbreviates `[{...}, {...}]`.

The `-rational` variants have rational durations and running-time bounds, such
as `{Sample; 1/2; Send}` and `within [1/2, 3/2]`.

Literals use `;` for sequence, `|` for union and parentheses: `{(Read | 2);
Send}` is `{Read; Send | 2; Send}`. A number `n` abbreviates `{n}`. An
interval grade is rejected unless some run meets both ends at the running times
of the operations. 

Under `banked-traces-interval-rational` an interval with an open endpoint, such
as `(1/2, 2]`, denotes infinitely many traces and is thus rejected.

Examples:
[`banked_traces/lower_bounds.tpe`](examples/banked_traces/lower_bounds.tpe),
[`banked_traces/upper_bounds.tpe`](examples/banked_traces/upper_bounds.tpe),
[`banked_traces/intervals.tpe`](examples/banked_traces/intervals.tpe) and
[`banked_traces/intervals_rational.tpe`](examples/banked_traces/intervals_rational.tpe).

### Regular trace languages

A grade is a non-empty regular language of traces, ordered by inclusion, with
concatenation as the product and union as the join. The unit is `{skip}` and
the top `⊤` is the language of all traces. Operations declare no running-time
bounds. The closure of a grade `L` is `L; L*`.

- `regular-trace-languages-symbolic`: traces over the letter `tick`, one time
  step, and the declared operations. An integer `n` denotes `n` ticks, and an
  interval `[n, m]` or `[n, ∞)` a range of them.
- `regular-trace-languages-rational-symbolic`: *timed words* of operations and
  non-negative rational delays, adjacent delays added, so that `{1/2; 1/2}` is
  `{1}`. Intervals of delays, such as `{[0, 1/2)}` or `{(1, ∞)}`, may be open.
  A repetition of delays is their sums: `{(1/2)*}` is `0`, `1/2`, `1`, ….

Literals are regular expressions, by increasing precedence union `r | s`,
intersection `r & s`, concatenation `r; s`, complement `~r`, Kleene star `r*`
and bounded repetition `r^n`. An operation name is a letter, `skip` the empty
trace, `_` any single letter, and parentheses or braces group: `{Open; (Read |
Write)*; Close}` is a file session and `{~{_*; Revoke; _*}}` the traces that
never revoke. When an ordering fails, a note names a trace of the lesser grade
not in the greater one.

Examples:
[`regular_trace_languages/upper_bounds.tpe`](examples/regular_trace_languages/upper_bounds.tpe)
and
[`regular_trace_languages/upper_bounds_rational.tpe`](examples/regular_trace_languages/upper_bounds_rational.tpe).

#### Bounded repetition

A repetition with a count is written `r^n`, `r^[m, n]` or `r^[m, ∞)` (ASCII
`inf`), and an open endpoint abbreviates the closed one next to it. 

`r^[m, n]` denotes the concatenations of `k` words of `r` for `k` from `m` to
`n`, so `r^0` is `skip` and `r^[0, ∞)` is `r*`. A repetition and its unrolling
are the same grade. The grades over regular expressions read it, and those over
finite sets of traces read finite counts only.

A grade the typechecker computes is printed with every run of two or more equal
adjacent factors as one repetition, e.g., three calls of `Ping` print as
`{Ping^3}`. For instance, the sprint start system example in
([`examples/arduino/starter/starter.tpe`](examples/arduino/starter/starter.tpe))
annotates its 200 polls as `{(skip | idle 2.5; ReadImu; ReadClock)^200}`.

#### Implementations for benchmarking
<!-- web-skip -->

Further implementations of the regular grades, kept for benchmarking, are
accepted by `--grades` with the suffixes `-letter-automata`,
`-symbolic-by-letters` and `-letter-derivatives` in place of `-symbolic`, and
`-rational-automata` in place of `-rational-symbolic`. 

They are compared by `dune exec --profile release
bench/regular/bench_regular.exe`; see
[`bench/regular/README.md`](bench/regular/README.md). 

The typechecking times of the example and test programs are in
[`bench/typecheck/README.md`](bench/typecheck/README.md).

### Regex grades with banked delays

A grade is a regular language of traces, written as for the regular trace
languages, and every atomic operation declares running-time bounds
`within [lo, hi]`. The orders are those of the trace grades with banked
delays: a grade stands for its *closure*, the traces that fit inside one of
its traces (upper bounds, an operation taking `hi`) or that cover one of them
(lower bounds, an operation taking `lo`).

- `banked-regex-upper-bound-symbolic`: the allowance order; `{skip}` is least
  and `⊤` the top.
- `banked-regex-lower-bound-symbolic`: the coverage order; `{skip}` is the top,
  and so is every grade containing the empty trace.
- `banked-regex-interval-symbolic`: intervals `[{...}, {...}]` of a lower and
  an upper bound, compared componentwise.

The `-rational-symbolic` variants range over the timed words of
`regular-trace-languages-rational-symbolic`, with fractional running-time
bounds. A set of delays in the lesser grade counts by its supremum (upper) or
infimum (lower), so `{[0, 1)}` is below `{1}` but not below `{1/2}`. Under
the interval variant an open numeric endpoint is a set of durations: `(0.8, 3)`
is `[{(0.8, ∞)}, {[0, 3)}]`.

The alphabet is the atomic operations declared anywhere in the program, over
which `_` ranges besides the delays. Since an upper bound stands for the traces
that fit inside its traces, the operations of its traces may be left out.

Examples:
[`banked_regex/lower_bounds.tpe`](examples/banked_regex/lower_bounds.tpe),
[`banked_regex/upper_bounds.tpe`](examples/banked_regex/upper_bounds.tpe),
[`banked_regex/intervals.tpe`](examples/banked_regex/intervals.tpe),
[`banked_regex/upper_bounds_rational.tpe`](examples/banked_regex/upper_bounds_rational.tpe)
and
[`banked_regex/intervals_rational.tpe`](examples/banked_regex/intervals_rational.tpe).

### Timed regex grades

`timed-regex-lower-bound`, `timed-regex-upper-bound` and
`timed-regex-interval`, and their `-rational` variants, are regular
expressions over operations, *time spans* and *idle waits*, ordered so that
every operation of a bound is demanded, matched in order by the program's
trace. Atomic operations declare running-time bounds.

The letters are:

- an operation `A`, or a set of operations, such as `(A | B)`, `_`, `~Read`
  or `_ & ~Read`: exactly one operation of the set;
- a *time span*, a duration in which operations may happen as long as they
  fit: `d`, `[a, b]`, `(a, b)`, `≤d`, `<d`, `≥d` or `>d` (ASCII `<=` and
  `>=`), `≥0` being any duration and the top;
- an *idle wait*, a time span that admits no operations, such as `idle 10`,
  `idle [2, 3]` or `idle ≤5`;
- a time span `I & S` restricted to a set of operations `S`, such as
  `≥0 & ~Read`;
- `skip`, the empty trace.

Expressions use `;`, `|`, `*`, `^n`, `^[m, n]` and `r?`, which is `r | skip`.
An upper bound reads a letter by its upper end and a lower bound by its lower
end, and under the interval grades a literal `{e}` is the pair of its two
readings. The grade of `delay d` is the idle wait `idle d`. The unit is
`{skip}` and the top `{≥0}`.

As an upper bound, an operation letter demands the program's operation at its
place, the program's other operations fit in time spans at their `hi`, and an
idle wait admits waits only. As a lower bound, a time span `≥d` demands at
least `d` units, covered by waits and by operations at their `lo`, and there
are no implicit time spans around the letters. The implied running time of a
default implementation is checked only at the end that a one-sided grade
bounds.

For example, `{(idle [9.5, 10.5]; ReadImu)*}` permits readings and waits only,
whereas `{([9.5, 10.5]; ReadImu)*}` admits a short operation beside each wait,
and `{≥0 & ~ConfigureImu}` keeps a reading from a reconfiguration.

Examples:
[`timed_regex/upper_bounds_rational.tpe`](examples/timed_regex/upper_bounds_rational.tpe),
[`timed_regex/intervals_rational.tpe`](examples/timed_regex/intervals_rational.tpe),
[`tests/idle_waits_rational_reject.tpe`](tests/idle_waits_rational_reject.tpe),
[`tests/idle_waits_lower_reject.tpe`](tests/idle_waits_lower_reject.tpe), and
the Opentrons examples
[`opentrons/washes.tpe`](examples/opentrons/washes.tpe) and
[`opentrons/purification.tpe`](examples/opentrons/purification.tpe). The
Arduino packages declare their operations under these grades too.

### Finite timed regex grades

`timed-regex-finite-lower-bound`, `timed-regex-finite-upper-bound`,
`timed-regex-finite-interval` and their `-rational` variants are the timed
regex grades on finite sets of traces: their literals have operations, sets of
operations, time spans and idle waits, with `;`, `|` and bounded repetition,
and no star. See
[`tests/timed_regex_finite_upper_reject.tpe`](tests/timed_regex_finite_upper_reject.tpe)
and [`tests/idle_waits_finite_reject.tpe`](tests/idle_waits_finite_reject.tpe).

### Grade lattices

The grades are, or include, the elements of a finite grade lattice, the
simple security lattice `Low < High` unless the program declares its own.

- `lattice`: an element of the grade lattice; a computation's grade is the
  join of the elements it touches, and delays touch none.
- `time-lower-bound-lattice`: pairs `(n, l)`, at least `n` ticks and nothing
  above `l` touched, as in `(3, Low)`.
- `time-upper-bound-lattice`: pairs `(n, l)`, at most `n` ticks and nothing
  above `l` touched, as in `(5, Low)`.
- `time-interval-lattice`: pairs `(i, l)` of a rational time interval and an
  element, as in `((0, 0.1], Low)`.

The pairs are compared, multiplied and joined componentwise.

Examples: [`lattice/security.tpe`](examples/lattice/security.tpe),
[`lattice/time_lower.tpe`](examples/lattice/time_lower.tpe),
[`lattice/time_upper.tpe`](examples/lattice/time_upper.tpe) and
[`lattice/staged_release.tpe`](examples/lattice/staged_release.tpe).

#### Declaring the grade lattice

A program may declare its own finite grade lattice in place of `Low < High`,
which the grade algebras built on a grade lattice then use. 

The user-defined grade lattice declaration opens a file, after its header
comment:

```
grade lattice Quiet < Noisy

grade lattice Public < Team < Confidential,
              Public < Partner < Confidential
```

Each chain `L1 < L2 < ...` gives edges, and the order is their reflexive and
transitive closure. The elements must form a lattice: no element repeated in a
chain, no cycle, a least element, and a least upper bound for every two
elements. The files of one run share one declaration, which a file may repeat. A
differing one is an error, as is a declaration under a grade algebra not built
on a grade lattice. Elsewhere, `grade` and `lattice` remain ordinary names.

See [`lattice/quiet_noisy.tpe`](examples/lattice/quiet_noisy.tpe) and
[`lattice/quiet_noisy_intervals.tpe`](examples/lattice/quiet_noisy_intervals.tpe).

### Time with an energy budget

- `time-upper-bound-energy`: pairs `(t, e)`, at most `t` ticks and at most `e`
  units of energy drawn; sequencing adds both, and the order and the join are
  componentwise. Each component is written as a `time-upper-bound` grade. A
  delay `d` is `(d, 0)`, as waiting draws no energy.

See [`energy/energy_budget.tpe`](examples/energy/energy_budget.tpe).

### Semidirect products

A semidirect product grade is, in general, a pair `(m, n)` whose second
component is acted on by the first components of the grades before it: 
`(m, n) · (m', n') = (m · m', n ⊔ m ▷ n')`, where `m ▷ n'` is an action of 
`m` on `n'` that each grade algebra defines. 

Tempore includes the following examples of semidirect products: 

- `flow-sensitive-levels`: tuples `(l, (S₁, l₁), …, (Sₖ, lₖ))` over the grade
  lattice, only elements at most `l` touched and each output `Sᵢ` written at
  most at the element `lᵢ` touched before it. An operation writing an output
  has a grade such as `(Low, (Board, Low))`, and after one of grade `High` the
  output is written at `High`.
- `watermarks`: triples `(t, [d1, d2], h)` bounding a resource held, such as
  open files, relative to its level at the start: the trough `t`, the range
  `[d1, d2]` of the net change, and the peak `h`. A grade is written `(d, h)`
  or `([d1, d2], h)`, with the trough `min(0, d1)`, or with an explicit trough.
  Resources are named by entries, as in `((Files, 0, 2), (Sockets, 0, 1))`,
  and opening a file has grade `(Files, 1, 1)`.
- `call-time-sets`: tuples `(T, (A, E_A), …)` of the possible durations `T` of
  the program and the times `E_A` at which each operation `A` can happen in the
  computation, all sets of ticks from the start, ordered by inclusion. `T` is a
  number, an interval or a brace literal over ticks, and `E_A` a brace literal:
  `{(4 | 5); 10*}` is ticks 4 and 5 of every ten.

In the tuples an entry `(_, …)` bounds every output, resource or operation not
listed.

Examples:
[`lattice/flow_sensitive_levels.tpe`](examples/lattice/flow_sensitive_levels.tpe),
[`watermarks/watermarks.tpe`](examples/watermarks/watermarks.tpe),
[`watermarks/savepoints.tpe`](examples/watermarks/savepoints.tpe) and
[`semidirect/call_time_sets.tpe`](examples/semidirect/call_time_sets.tpe).

### Mode grades

A grade describes devices that are always in one of several modes, such as a
radio that is on or off, and whose operations may change the mode.

- `mode-switch-costs`: max-plus matrices of the greatest costs of the traces
  between named modes, written by entries `(From, To, n)`, as in
  `(Off, On, 2)`. The reserved mode `Stuck` is never left, an operation gets
  stuck at cost 0 from the modes its grade does not start from, and a change
  between two distinct modes other than `Stuck` costs at least 1. Modes not
  named are written `_`, as in `((On, On, 4), (_, _, 1), (_, Stuck, 0))`.
- `mode-times`: the same matrices as above with the time spent in each mode 
  and the total time, each bounded by an interval, as in
  `(Cold, Cold, (Out, [0, 10]))`. An operation names itself, as in
  `({Take}, Cold, Out)`, declares its running time `within [lo, hi]`, spends
  it in the mode it starts from, and changes the mode at its end.

A delay keeps the mode. It costs nothing under `mode-switch-costs`, and under
`mode-times` its time is spent in the mode. Examples:
[`modes/mode_switch_costs.tpe`](examples/modes/mode_switch_costs.tpe) and
[`opentrons/enzyme.tpe`](examples/opentrons/enzyme.tpe).

### Counts

A grade has entries `(A, n)` for the calls of the operation `A`, sequencing
adds the calls of each operation, and delays count none. An operation counts
itself, as in `operation Send : nat ~> unit ! (Send, 1)`, and the entry
`(_, n)` covers the operations not listed.

- `at-most-counts`: at most `n` calls, `n` possibly `∞`; an operation not
  listed is bounded by `0`, and `((Auth, 1), (Send, 3))` allows one `Auth`,
  three `Send` and nothing else.
- `at-least-counts`: at least `n` calls, also written `[n, ∞)`; a branch
  guarantees the lesser count of its arms, and the unit `0` is the top. A
  counted operation has no default implementation, which would have to
  perform the operation itself.
- `at-least-counts-with-top`: the at-least counts with a greatest grade `⊤`
  above the unit, which absorbs products and joins.

Examples:
[`at_most_counts/rate_limits.tpe`](examples/at_most_counts/rate_limits.tpe)
and [`at_least_counts/rinses.tpe`](examples/at_least_counts/rinses.tpe).

### Inter-arrival grades

- `inter-arrival`: how often each operation recurs, by the time between the
  starts of consecutive calls, at most and at least, as for heartbeats,
  sampling rates, and rate limits. Delays are rational, and an operation `X`
  has grade `{X}`, occurs at its start, and takes a time within its `within`
  bounds.

For each operation, a grade bounds by intervals the lead time before its first
call, the gaps between consecutive calls, the tail after its last call, and
optionally the number of calls, together with the total duration:

- `(X, [s, t])`: gaps in `[s, t]`, and no duration without `X` longer than `t`
  at the start or the end; `(Beep, [2, ∞))` is a rate limit;
- `(X, lead, gaps, tail)`: the lead time, the gaps and the tail each bounded
  on its own;
- `(n, X, gaps)`, `(n, X, lead, tail)` and `(n, X, lead, gaps, tail)`: the
  same with a count `n` or `[n, m]`;
- a tuple of such entries and at most one interval, the total duration, as in
  `((Read, [0, 20]), (Draw, [0, 50]), [0, 100])`, the operations not listed
  being unconstrained;
- a brace literal `{Beat; Work | Beat}` of operations and delays, a number or
  an interval is a computation, without occurrences besides those it names.

A grade whose entries admit no common total duration is rejected. Examples:
[`opentrons/binding.tpe`](examples/opentrons/binding.tpe) and
[`arduino/steps/steps.tpe`](examples/arduino/steps/steps.tpe).

### Supported grade systems

Each item names the effect grade algebra, the resource grade algebra and the
morphism `∣ε∣`.

- `time-interval` to `time-lower-bound`: the lower end, `∣[d, a]∣ = [d, ∞)`.
- `time-interval` to `time-upper-bound`: the upper end, `∣[d, a]∣ = [0, a]`.
- `timed-regex-interval` and `timed-regex-finite-interval` to `time-interval`:
  the least interval containing the durations of the runs of `ε`.
- `timed-regex-lower-bound` and `timed-regex-finite-lower-bound` to
  `time-lower-bound`: the infimum of the durations of the runs of `ε`.
- `timed-regex-upper-bound` and `timed-regex-finite-upper-bound` to
  `time-upper-bound`: the supremum of the durations of the runs of `ε`.
- `banked-traces-lower-bound` to `time-lower-bound`: the least duration of a
  trace of `ε`, at the lower running times.
- `banked-traces-upper-bound` to `time-upper-bound`: the greatest duration of
  a trace of `ε`, at the upper running times.
- `banked-traces-interval` to `time-interval`: both of the above, of the two
  ends.
- `finite-run-sets` to `at-most-counts`: the greatest number of calls of each
  operation in a run of `ε`.
- `finite-run-sets` to `at-least-counts-with-top`: the least number of calls
  of each operation in a run of `ε`, the top mapped to the top.
- `banked-traces-lower-bound` to `at-least-counts`: the least number of calls
  of each operation in a trace of `ε`.
- `time-lower-bound-lattice` to `time-lower-bound` and to `lattice`: the
  projections, `∣(n, ℓ)∣ = n` and `∣(n, ℓ)∣ = ℓ`, over the grade lattice the
  program declares.

Each system to a time resource grade algebra, except the projections, also
exists over rational delays, both names ending in `-rational`. 

An end keeps its openness, and in the timed regex and banked trace grades an
operation takes its running time.

## Editor support
<!-- web-skip -->

`editors/vscode/` contains a minimal VS Code extension with syntax highlighting
for `.tpe` files. 

Package and install it with

    make vscode-extension

or by hand with

    cd editors/vscode
    npx --yes @vscode/vsce package
    code --install-extension vscode-tempore-*.vsix --force

then restart VS Code. 

Uninstall with

    code --uninstall-extension tempore.vscode-tempore

To work on the extension itself, open `editors/vscode` in VS Code and press F5
for an Extension Development Host with the extension loaded.

## Repository layout
<!-- web-skip -->

The sources in `src/` are numbered by the stages of the pipeline, 
as in [Millet](https://github.com/matijapretnar/millet):

- `00-utils`: locations, diagnostics, errors, symbols and printing.
- `01-language`: the abstract syntax and the grade algebras.
- `02-parser`: the lexer and the grammar.
- `03-desugarer`: the desugaring of parsed programs and the resolution of
  names.
- `04-typechecker`: the type and grade inference and the explanation of
  diagnostics.
- `05-backends`: the interpreter, the Arduino and Opentrons backends, and the
  run timelines.
- `06-loader`: the loading of programs through the stages above, with the
  standard library `stdlib.tpe`.
- `07-user-interface`: the command line interface (`cli/`) and the web
  interface (`web/`).

`tests/` holds the cram tests of the command line and the unit tests: the
programs and expected outputs of the language at its top level, and one
directory per component (`grades/`, `inference/`, `references/`, `headers/`
for the headers of the examples, `arduino/`, `opentrons/`, `make/`, and
`web/` for the web interface), with the shared helpers in `support/` and the
probes for optional tools in `probes/`.

`examples/` holds the example programs, grouped by topic and backend, with the
index the web interface reads and the make targets of the backend examples.

`web/` holds the page of the web interface and its assets, into which the build
promotes `web.bc.js`. `bench/` holds the benchmarks, `editors/` the VS Code
extension, and `scripts/` the auxiliary scripts.

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
