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
[thesis](https://thesis.cs.ut.ee/1c038012-af0d-444a-95dc-7ffc8b3a1f20)). Tempore
(currently) adds (i) temporal algebraic effects and effect handlers that are
guaranteed to respect the temporal specifications of operations, and (ii)
general resource grades (see more on this [below](#grading-monoids)) in place of
natural-number time grades, which modelled only whole lower time bounds of
programs.

Tempore (and Temporal Millet before it) is built on Matija Pretnar's
[Millet Language](https://github.com/matijapretnar/millet) and follows the
ideas of [Ahman](https://doi.org/10.1007/978-3-031-30829-1_1) and [Ahman and
Žajdela](https://msfp-workshop.github.io/msfp2024/submissions/ahman+%c5%beajdela.pdf).

## Installing and running
<!-- web-skip -->

### Building

Requires OCaml 5.5 or later. The rational time grades use zarith, which needs
the GMP library (opam installs it through `conf-gmp`). 

Install the dependencies and build:

    make deps
    make

`make test` runs the test suite; `make clean` removes the build.

### Command line

    ./tempore file1.tpe file2.tpe ...

loads the listed files, runs every `run` command in them, and prints each result
with the final resource state. Options:

- `--grades <grades>` selects the grading monoid (default `time-lower-bound`;
  see [Grading monoids](#grading-monoids));
- `--typecheck-only` typechecks the files without running;
- `--no-stdlib` skips importing the standard library;
- `--debug` also prints the inferred typing context, including the inferred type
  schemes;
- `--help` lists the options and the grading monoids.

### Web interface

Open `web/index.html` after building, or use
<https://danel.ahman.ee/tempore-lang/>. Load an example or type a program,
typecheck it, and step through its reductions while watching the resource state.

The **Grades** selector chooses the grading monoid; loading an example selects
its respective grading monoid automatically.

The [`examples/`](examples/) directory holds example programs by topic:
`basics/`, `handlers/`, `time/`, `traces/`, `regular/`, `regular_costs/`,
`levels/`, `semidirect/`, `counts/`, `3dprint/` (a 3D-printing case study),
`rollout/` (a staged software release) and `sessions/` (a mail-session case
study). All but the `basics/` examples are offered in the web interface.

## Temporal resources

A value of the modal type `[rho]a` is an `a`-typed resource that may be used
only once the grade `rho` (see [Grading monoids](#grading-monoids) below) has
accumulated since it was created.

### Boxes and unboxing

`box rho e` creates a resource of type `[rho]a`; `e` is typed in the future in
which `rho` has accumulated. 

`unbox e` opens a resource `e : [rho]a`, and is allowed only if the grade
accumulated since boxing is below `rho`. 

Under `time-lower-bound`,

```
run
  box 5 (10, 10) as b in
  delay 4;
  unbox b as (l, r) in l + r
```

is rejected, since four ticks is not a sub-grade of five:

    Variable `b` is unboxed with grade `4` accumulated since it was bound,
    which is not below its box grade `5`
      Note: the resource inequality `4 >= 5` does not hold

See [`examples/basics/basic_unbox.tpe`](examples/basics/basic_unbox.tpe).

### Delays

`delay tau` advances the accumulated grade by `tau`. Each [grading monoids](#grading-monoids) 
maps its monoid of delays to grades by a monoid morphism, so `delay 0` has the unit
grade and `delay tau; delay tau'` the grade of `delay (tau + tau')`
([`delay.mli`](src/01-language/grades/delay.mli)). 

`tau` is a non-negative integer or rational fraction. The rational time and
trace grades, `security-levels` and `flow-levels` have the non-negative
rationals as delays and accept any, such as `delay 1/3` or `delay 0.25`; the
other monoids count whole time steps and accept only integers. See
[`examples/basics/delay.tpe`](examples/basics/delay.tpe).

## Grading monoids

Resources and computations are graded by an ordered monoid, chosen at run time
with `--grades` or the **Grades** selector, e.g.

    ./tempore --grades time-interval examples/time/time_intervals.tpe

### Grade literals

All monoids share one literal syntax: integers (`3`), fractions (`3/2`, or
exact decimals such as `1.5`), tuples (`(3, High)`), intervals and brace
expressions (`{...}`). 

An interval has the standard mathematical meaning: a bracket includes its finite
endpoint and a parenthesis excludes it, as in `[1, 4]`, `(1, 4)`, `[1, 4)`,
`(1/2, 4]`, `[1, ∞)`, `(1, ∞)`, `(-∞, 4]`, `(-∞, ∞)` (ASCII `inf` and `-inf`) or
`[{A}, {A; B}]`; an infinite endpoint is always open, so `[1, ∞]` is a syntax
error, and an empty interval, such as `(1, 1)`, `[1, 1)` or `[4, 1]`, is
rejected. Over whole time steps an open endpoint abbreviates a closed one: `(1, 4)` 
is `[2, 3]` and `(1, ∞)` is `[2, ∞)`. 

Each monoid accepts the literals it understands; any other literal is a syntax
error naming the monoids that accept it. The greatest grade is `⊤` (ASCII
`top`). Negative integers (`-1`) are accepted only by `resource-levels`. A fraction
equal to an integer, such as `4/2` or `2.0`, is that integer.

### Time

A grade bounds the number of time steps, or ticks, a computation takes.

- `time-lower-bound`: `n` is at least `n` ticks; ordered by `>=`, so `0` is
  the top.
- `time-upper-bound`: `n` is at most `n` ticks, `∞` (ASCII `inf`) no bound;
  ordered by `<=`, so `0` is least and `∞` the top.
- `time-interval`: `[n, m]` is between `n` and `m` ticks, and `[n, ∞)` at
  least `n` ticks; ordered by containment, with top `[0, ∞)`. An open endpoint
  abbreviates a closed one, `(n, m)` being `[n + 1, m - 1]`.

Example: `box [2, 5] v` may be unboxed after two to five ticks. See
[`examples/time/time_upper.tpe`](examples/time/time_upper.tpe) and
[`examples/time/time_intervals.tpe`](examples/time/time_intervals.tpe).

The rational variants `time-lower-bound-rational`, `time-upper-bound-rational` and
`time-interval-rational` measure time exactly by non-negative rationals, with
the same orders, units and tops: `box [0.5, 4/3] v` may be unboxed after half a
unit and before four thirds, and three delays of `1/3` take exactly `1` unit. The
intervals of `time-interval-rational` may be open or half-open: `box (4, 6] v`
may be unboxed strictly after four units and at most six. A sum of intervals
is open at an endpoint if either summand is, so `[1, 2) · [1, 1]` is `[2, 3)`. A
grade is printed as an integer, as a finite decimal if one exists (`0.125`),
and otherwise as a fraction (`1/3`). See
[`examples/time/rational_time_intervals.tpe`](examples/time/rational_time_intervals.tpe).

### Traces

A grade is a non-empty finite set of *traces*, the sequences of operations and
delays a computation may exhibit: `Read; 3; Send` performs `Read`, waits three
ticks, and performs `Send`; adjacent delays are merged, so `Read; 1; 2; Send` is
the same trace as `Read; 3; Send`. Grades multiply by concatenation and join by
union. Operations declare no running-time bounds.

In `traces-upper-bound`, the traces a computation is *allowed*, ordered by set
inclusion; a delay pays for no operation, and `{Read}` is not below `{3}`. The
unit `{0}` is not least, and `⊤`, any trace, is the top. Traces are compared by
equality, so only upper bounds are provided. The rational variant
`traces-upper-bound-rational` has non-negative rational delays. 

Literals are those of the trace grades with costs, below. When an ordering
fails, a note names a trace of the lesser grade that the greater one does not
list. See
[`examples/traces/plain_traces_upper.tpe`](examples/traces/plain_traces_upper.tpe).

### Traces with costs

The grades are finite sets of traces as above, and every atomic operation
declares running-time bounds `within [lo, hi]`, which the orders use to trade
time against operations.

- `traces-cost-lower-bound`: the traces a computation must *cover*; an operation
  performed counts as `lo` ticks towards a demanded duration. `{0}` is the top.
- `traces-cost-upper-bound`: the traces a computation is *allowed*; a duration
  pays for operations at their `hi`. `{0}` is least and `⊤` the top.
- `traces-cost-interval`: closed intervals `[{...}, {...}]` of a lower and an
  upper bound, the traces at or above the one and at or below the other,
  compared componentwise; `[{...}, ∞)` has no upper bound, `{...}` abbreviates
  `[{...}, {...}]`, `n` is `[{n}, {n}]`, `[n, m]` is `[{n}, {m}]`, and an open
  endpoint abbreviates a closed one, `(n, m)` being `[{n + 1}, {m - 1}]`. The
  top is `[{0}, ∞)`.

Literals use `;` for sequence, `|` for union and parentheses: `{(Read | 2);
Send}` is `{Read; Send | 2; Send}`. An integer `n` abbreviates `{n}`. See
[`examples/traces/traces_lower.tpe`](examples/traces/traces_lower.tpe),
[`examples/traces/traces_upper.tpe`](examples/traces/traces_upper.tpe) and
[`examples/traces/traces_intervals.tpe`](examples/traces/traces_intervals.tpe).

The rational variants `traces-cost-lower-bound-rational`,
`traces-cost-upper-bound-rational` and `traces-cost-interval-rational` have the
same orders, units and tops, with non-negative rational durations and
running-time bounds: `{Sample; 1/2; Send}` has a duration of half a unit between
the two operations, a fraction `q` abbreviates `{q}`, and an operation may
declare bounds such as `within [1/2, 3/2]`. 

An interval with an open numeric endpoint, such as `(1/2, 2]`, denotes
infinitely many traces and is rejected; the regular expressions of
`regex-cost-interval-rational` can be used to express such cases. See
[`examples/traces/rational_traces_intervals.tpe`](examples/traces/rational_traces_intervals.tpe).

### Regular expressions

A grade is a non-empty regular language of traces, words over the letter `tick`
(one time step) and declared operation names. The order is inclusion,
the product concatenation and the join union; the unit is `{0}` and the top
`⊤` the language of all traces. Operations declare no running-time bounds.

- `regex-upper-bound-symbolic`: decided by symbolic derivatives (preferred);
- `regex-upper-bound`: decided by minimal automata.

Literals are regular expressions, by increasing precedence: union `r | s`,
intersection `r & s`, concatenation `r; s`, complement `~r` and Kleene star
`r*`. 

An operation name is a letter, an integer `n` denotes `n` ticks, an interval
`[n, m]` any number of ticks from `n` to `m` and `[n, ∞)` at least `n`, an open
endpoint abbreviating a closed one (`(1, 4)` is `2 | 3`), `_` is any single
letter, including operations the grade does not name, and parentheses or braces
group. For example, `{Open; (Read | Write)*; Close}` is a file session and
`{~{_*; Revoke; _*}}` the traces that never revoke. When an ordering fails, a
note names the shortest trace of the lesser grade not in the greater one:

```
Typing error: Variable `t` is unboxed with grade `{Auth | Fetch}` accumulated 
  since it was bound, which is not below its box grade `{Auth; _*}`
  ...
  Note: the grade `{Fetch}` is below `{Auth | Fetch}` but not below `{Auth; _*}`
```

See [`examples/regular/regular_traces.tpe`](examples/regular/regular_traces.tpe).

You can benchmark four implementations of regular expressions (ranging from DFAs
to symbolic automata and symbolic derivatives) with 
`dune exec --profile release bench/regular/bench_regular.exe`; see
[`bench/regular/README.md`](bench/regular/README.md) for more information.

The rational variant `regex-upper-bound-rational` reads traces as *timed words*:
operations and non-negative rational delays, adjacent delays added, so that
`{1/2; 1/2}` is `{1}`. A delay is a single letter, and the order is exact over
the rationals, independent of any time step. Besides operation names and delays
such as `3`, `1/2` or `1.5`, literals have intervals of delays `[q, r]`, `(q,
r)`, `[q, r)`, `(q, r]`, `[q, ∞)` and `(q, ∞)`: `{[0, 1/2)}` is the set of the
delays below `1/2` and `{(1, ∞)}` that of those above `1`. A parenthesis
followed by a delay and a comma opens an interval, and otherwise a group: `{(1 |
2); (1, 2)}` is a delay `1` or `2` followed by one strictly between `1` and `2`.
`_` is any single operation or any positive delay, and the complement is taken
over all timed words: `{~1}` permits every trace but a delay of exactly `1`, and
`{_ & ~Read}` any single operation but `Read` or any positive delay. A
repetition of delays is their sums, the empty sum `0` included: `{(1/2)*}` is
the sums of any number of halves, `0`, `1/2`, `1`, …, and `{[1, 2]*}` is the
delay `0` and every delay from `1`. A plain number `q` abbreviates `{q}`. The
unit is `{0}` and the top `⊤`, `{_*}`. A grade is printed as it is written, with
adjacent delays added. See
[`examples/regular/regular_rational.tpe`](examples/regular/regular_rational.tpe).

### Regular expressions with costs

A grade is a regular language of traces, as under `regex-upper-bound`, ordered
as the trace monoids with costs order finite sets of traces, at the running-time
bounds `within [lo, hi]` of the atomic operations. A grade stands for its
closure: the traces that fit inside one of its traces (upper) or cover one of
them (lower).

- `regex-cost-upper-bound`: allowance order at `hi`; `{0}` is least, `⊤` the top.
- `regex-cost-lower-bound`: coverage order at `lo`; `{0}` is the top.
- `regex-cost-interval`: closed intervals `[{...}, {...}]` of a lower and an
  upper bound, with the forms and abbreviations of `traces-cost-interval`; the
  top is `[{0}, ∞)`.

Each of the above is also available with the suffix `-symbolic`, in which 
ordering of regexes is decided using symbolic automata and symbolic derivatives.

The alphabet is the atomic operations declared anywhere in the program, so `_`
is any tick or atomic operation, and a grade must denote at least one trace
over it. With `Read` declared `within [1, 3]`, under `regex-cost-upper-bound`
`{Read}` is below `{3}` and `{Read | 3}` equals `{3}`. See
[`examples/regular_costs/regular_costs_lower.tpe`](examples/regular_costs/regular_costs_lower.tpe),
[`examples/regular_costs/regular_costs_upper.tpe`](examples/regular_costs/regular_costs_upper.tpe)
and
[`examples/regular_costs/regular_costs_intervals.tpe`](examples/regular_costs/regular_costs_intervals.tpe).

The rational variants `regex-cost-lower-bound-rational`,
`regex-cost-upper-bound-rational` and `regex-cost-interval-rational` order the
timed words of `regex-upper-bound-rational` in the same way, with its literals
and fractional running-time bounds such as `within [1/2, 3/2]`. The orders are
exact over the rationals: with operation `A` declared `within [1, 1]`, under
`regex-cost-upper-bound-rational` the traces `{(0, 1); A; (0, 1)}` are below
`{3}` but below no `{q}` with `q < 3`, as the sums of their durations come
arbitrarily close to `2`. 

A complement is taken over all timed words, and a grade still stands for its
closure: `{~1}` equals `⊤` under the upper order, as the longer durations it
permits cover the one it excludes. A comparison reads each set of durations of
the lesser grade through its supremum (upper) or infimum (lower), and a grade is
printed as it is written. 

The implied running-time bounds of a compound operation are the least and
greatest weights of the traces of its grade: `{Sample; [0, 1/2); Send}` gets
`(3/4, 3)` if `Sample` is declared `within [1/2, 3/2]` and `Send`
`within [1/4, 1]`. 

Under `regex-cost-interval-rational` an open numeric endpoint of an interval is
a set of durations: `(0.8, 3)` is `[{(0.8, ∞)}, {[0, 3)}]`. See
[`examples/regular_costs/regular_costs_rational.tpe`](examples/regular_costs/regular_costs_rational.tpe)
and
[`examples/regular_costs/regular_costs_intervals_rational.tpe`](examples/regular_costs/regular_costs_intervals_rational.tpe).

### Security levels and products

- `security-levels`: the levels `Low < High`; a computation's grade is the
  highest level it touches, and delays touch none. A box at `Low` is out of
  reach once an operation of grade `High` has run.
- `time-lower-bound-levels`: pairs `(n, l)`, at least `n` ticks and nothing
  above `l`; `(3, Low)` is an embargo with a taint check. This is a direct
  product of the time lower bounds and security levels grades.
- `time-upper-bound-levels`: pairs `(n, l)`, at most `n` ticks and nothing
  above `l`; `(5, Low)` is an expiring capability. This is a direct
  product of the time lower bounds and security levels grades.
- `flow-levels`: tuples `(l, (S₁, l₁), …, (Sₖ, lₖ))`, nothing above `l` touched
  and each output `Sᵢ` written at most at the level `lᵢ` touched before it; `l`
  alone writes no output, and an entry `(_, l')` bounds every output not listed.
  An output is a capitalised name, and an operation writing it has a grade such
  as `(Low, (Board, Low))`; after one of grade `High`, it is written at `High`.
  This grading monoid is an example of the semidirect product construction (see
  [Semidirect products](#semidirect-products)).

The pairs of the products with the time grades are compared, multiplied and
joined componentwise. See
[`examples/levels/security_levels.tpe`](examples/levels/security_levels.tpe),
[`examples/levels/time_lower_levels.tpe`](examples/levels/time_lower_levels.tpe),
[`examples/levels/time_upper_levels.tpe`](examples/levels/time_upper_levels.tpe)
and [`examples/levels/flow_levels.tpe`](examples/levels/flow_levels.tpe).

### Semidirect products

A grade is a pair `(m, n)` whose second component is acted on by the first
components of the grades before it: `(m, n) · (m', n') = (m · m', n ⊔ m ▷ n')`,
`m ▷ n'` being the action of `m` on `n'`. The pairs are compared and joined
componentwise. The `flow-levels` monoid from above is an example, as are:

- `resource-levels`: triples `(t, [d1, d2], h)` bounding a resource held, such as
  open files, relative to its level at the start: the trough `t` is the lowest
  level, the range `[d1, d2]` the net change and the peak `h` the highest
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

- `windowed-schedules`: tuples `(T, (A, E_A), …)` of the possible durations `T` and
  the times `E_A` at which each operation `A` happens, all sets of numbers of
  ticks from the start; `(T, E) · (T', E') = (T + T', E ∪ (T + E'))`, `+`
  adding elementwise, and the order is inclusion. `T` is written `n`, `[n, m]`,
  `[n, ∞)`, with open endpoints as for `time-interval`, or as a brace literal
  over ticks, `{0 | 10}`, and `T` alone
  performs no operation; `E_A` is a brace literal,
  `{(4 | 5); 10*}` being ticks 4 and 5 of every ten, and an entry `(_, E)`
  bounds every operation not listed. An operation `Send` taking a tick and
  happening at its start has grade `(1, (Send, {0}))`.

- `mode-switch-costs`: max-plus matrices of the greatest costs of the traces between
  named modes, the completion under joins of a semidirect product of mode
  changes and costs. 

  Entries `(From, To, n)` give the traces, e.g. `(Off, On, 2)` for switching a
  radio on; the product gives `(p, r)` the greatest cost of a trace from `p` to a
  mode `q` followed by one from `q` to `r`. 
  
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

An (external) operation whose grade no code inside Tempore can meet, such as
opening or closing a file under `resource-levels`, has no default implementation, and
a run stops at its first call. See
[`examples/semidirect/resource_levels.tpe`](examples/semidirect/resource_levels.tpe),
[`examples/semidirect/windowed_schedules.tpe`](examples/semidirect/windowed_schedules.tpe)
and [`examples/semidirect/mode_switch_costs.tpe`](examples/semidirect/mode_switch_costs.tpe).

### Operation counts

- `counts-upper-bound`: entries `(A, n)`, at most `n` calls of the operation
  `A`, `n` possibly `∞`; sequencing adds the calls of each operation, and
  delays count none. An operation not listed is bounded by `0`, or by the entry
  `(_, n)`, and a plain `n` bounds every operation: `((Auth, 1), (Send, 3))`
  allows one `Auth`, three `Send` and nothing else. An operation counts itself,
  e.g. `operation Send : nat ~> unit # (Send, 1)`. See
  [`examples/counts/rate_limits.tpe`](examples/counts/rate_limits.tpe).

## Eternal types

A type is *eternal* if its values stay valid however much grade accumulates.
Base types, and tuples and algebraic types built from eternal types, are
eternal; function, handler and box types are not. A local variable of a
non-eternal type may be used only while the grade accumulated since its binding
is a sub-grade of the unit. Under `time-lower-bound` and
`traces-cost-lower-bound` this always holds; under the other monoids such a
variable must be used before any nontrivial delay or operation call.

### Schemes and qualifiers

When eternality depends on a type variable of a top-level definition, it
becomes a qualifier of the definition's scheme, checked at each use. Under
`time-upper-bound`, `let keep x = delay 1; x` gets

    ∀ α. Et(α) ⇒ α → α # 1

so `keep 5` is accepted and `keep (fun () -> ())` rejected. See
[`examples/basics/eternal_types.tpe`](examples/basics/eternal_types.tpe).

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
trace and regular-expression monoids with costs, an *atomic* operation, graded
by its own name, also declares its running-time bounds (`within [n, m]`):

```
operation Tx : string ~> unit # {Tx} within [2, 3]
```

The bounds are durations, written as for `delay` (see [Delays](#delays)), with
`lo <= hi` and `hi` positive. Either end may be open, as in `within (lo, hi)`,
`within [lo, hi)` or `within (lo, hi]`, the interval being non-empty. 

The rational monoids with costs accept fractional bounds such as `within [1/2,
3/2)`; under the other monoids with costs, which count whole time steps, `within
[1/2, 1]` is a syntax error and an open end abbreviates a closed one, `within
(1, 4)` being `within [2, 3]`. 

The rational trace monoids compare traces with exact durations and read the
value of each end. The rational regular-expression monoids read whether each
end is attained: with `A` declared `within [1, 2)`, `{A}` is below `{[0, 2)}`
under `regex-cost-upper-bound-rational`, and a default implementation of `A`
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

    Note: the effect inequality `∀ε₀. 0 >= 1 · ε₀` does not hold: for
      `ε₀ = 0` it becomes `0 >= 1`

See [`examples/handlers/handlers_lower_bound.tpe`](examples/handlers/handlers_lower_bound.tpe),
[`examples/handlers/handlers_upper_bound.tpe`](examples/handlers/handlers_upper_bound.tpe)
and [`examples/3dprint/3dprint_handlers.tpe`](examples/3dprint/3dprint_handlers.tpe).

### Contexts of operation cases

An operation case is typed with the top grade `⊤` accumulated for the variables
bound outside it. Under `time-lower-bound` and `traces-cost-lower-bound` the top
is the unit, which restricts nothing. Under the other monoids an outer variable
of non-eternal type, including an outer continuation, cannot be used in the
case, and an outer box can be unboxed only if `⊤` is below its grade. This is
because operation cases need to be executable anywhere in the computation tree
when handling. The case's own `p` and `k`, and top-level definitions, are
unaffected. See
[`examples/handlers/handlers_nested.tpe`](examples/handlers/handlers_nested.tpe)
and
[`examples/handlers/handlers_nested_reject.tpe`](examples/handlers/handlers_nested_reject.tpe).

### Default implementations

```
default Heat () = delay 1
```

gives `Heat` a default, run only when a call reaches the top level unhandled;
here it simulates the running time of `Heat` by a delay. Where operations
declare running-time bounds, only atomic operations have defaults,
and a default's grade must be a sub-grade of `{lo}` under lower bounds, `{hi}`
under upper bounds, and `[{lo}, {hi}]` under intervals; the running-time bounds
its grade implies must moreover lie within the declared ones, an open end
excluded, so that with `A` declared `within [1, 2)` the default
`default A () = delay 2` is rejected under every monoid with costs. Elsewhere a default's
grade must be a sub-grade of the operation's grade.
See [`examples/3dprint/3dprint_traces.tpe`](examples/3dprint/3dprint_traces.tpe).

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
the same name is the same unknown, inferred and generalised with it. A name
also written after `#` stands for the resource image `∣ε∣` of that effect in box
grades. `let pass (f : unit -> nat # 'e) : nat # 'e = f ()` has the grade of `f`.

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
where a `[3]nat` is expected, a `[4]nat` is not.

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