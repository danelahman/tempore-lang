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
4. a cleaner and more systematic treatment of type inference, and
5. various usability improvements in the web-based user interface.

Tempore (and Temporal Millet before it) is built on Matija Pretnar's [Millet
Language](https://github.com/matijapretnar/millet) and follows the ideas of
[Ahman](https://doi.org/10.1007/978-3-031-30829-1_1) and [Ahman and
Žajdela](https://msfp-workshop.github.io/msfp2024/submissions/ahman+%c5%beajdela.pdf).

## Installing and running
<!-- web-skip -->

### Building

Requires OCaml 5.5 or later. The rational time grades use zarith, which
additionally needs the GMP library (opam installs it through `conf-gmp`).

Install the dependencies:

    make deps

Build the language:

    make

Run the test suite:

    make test

Remove the build:

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
- `--help` lists the options and the available grading monoids.

The [`examples/`](examples/) directory holds example programs grouped according
to their topics.

### Web interface

Open `web/index.html` after building, or use
<https://danel.ahman.ee/tempore-lang/>.

You can load an existing example or write your own program, choose which grading
monoid to use, typecheck the program, and step through its reductions while
watching resource usage.

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
  not rounded to whole ticks. A grade is a minimal deterministic symbolic
  automaton over sets of operations and sets of delays; an inclusion `ρ ≾ ρ′`
  holds if the product of `ρ` with the complement of `ρ′` accepts nothing, found
  by a breadth-first search. Literals:

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
- grades are the automata of `regex-upper-bound-rational-symbolic`; the
  closures are not regular, so an ordering `ρ ≾ ρ′` is decided by a
  breadth-first search of the product of `ρ` with a reader of the closure of
  `ρ′`, which keeps the longest (upper) or shortest (lower) durations of the
  traces read so far;
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
and [`examples/3dprint/handlers.tpe`](examples/3dprint/handlers.tpe).

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

gives `Heat` a default, run only when a call reaches the top level unhandled;
here it simulates the running time of `Heat` by a delay. Where operations
declare running-time bounds, only atomic operations have defaults, and a
default's grade must be a sub-grade of `{lo}` under lower bounds, `{hi}` under
upper bounds, and `[{lo}, {hi}]` under intervals; the running-time bounds its
grade implies must moreover lie within the declared ones, an open end excluded,
so that with `A` declared `within [1, 2)` the default `default A () = delay 2`
is rejected under every monoid of timed operations. Elsewhere a default's grade
must be a sub-grade of the operation's grade. See
[`examples/3dprint/traces.tpe`](examples/3dprint/traces.tpe).

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