# <picture><source media="(prefers-color-scheme: dark)" srcset="web/logo/tempore-logo-dark.svg"><img src="web/logo/tempore-logo.svg" alt="" width="40" height="40" align="top"></picture> Tempore Language

Tempore (as in *in tempore*, Latin for "in good time") is a prototype
programming language that combines graded modal types with graded effects to
specify and verify temporal properties of resources that programs manipulate, in
particular allowing one to statically verify that resources are used only when
their type-based specifications deem it safe to do so. These properties are
checked automatically by Hindley–Milner style type and grade inference.

Tempore grew out of Temporal Millet, which was implemented in [Joosep
Tavits](https://github.com/joosepgit)'s Master's thesis at the University of
Tartu ([code](https://github.com/joosepgit/temporal-millet),
[thesis](https://thesis.cs.ut.ee/1c038012-af0d-444a-95dc-7ffc8b3a1f20)). Tempore
(currently) adds (i) temporal algebraic effects and effect handlers that are
guaranteed to respect the temporal specifications of operations, and (ii)
general resource grades in place of natural-number time grades, which only
modelled left-sided time intervals expressing lower time bounds of programs.

Tempore (and Temporal Millet that preceded it) is built on Matija Pretnar's
[Millet Language](https://github.com/matijapretnar/millet) and follows the
ideas of [Ahman](https://doi.org/10.1007/978-3-031-30829-1_1) and [Ahman and
Žajdela](https://msfp-workshop.github.io/msfp2024/submissions/ahman+%c5%beajdela.pdf).

## Installing and running
<!-- web-skip -->

### Building

Tested to work with OCaml >= 5.0. Install the dependencies and build:

    opam install --deps-only --with-dev-setup .
    make

`make test` runs the test suite, and `make clean` removes the build.

### Command line

    ./tempore file1.tpe file2.tpe ...

loads all listed files and runs every `run` command, printing each run's
result and final resource state.

Options: `--grades <grades>` selects the grades (see below),
`--typecheck-only` typechecks the files without running them, `--no-stdlib`
skips the standard library, and `--debug` also prints the typing context.

### Web interface

At `web/index.html` after building, or online at
<https://danel.ahman.ee/tempore-lang/>. Load a built-in example or type a
program, check whether the example typechecks, and if it does, step through
its reductions one by one while watching the resource state evolve.

The [`examples/`](examples/) directory contains example programs, grouped into
subdirectories by topic: `basics/` (the core language), `handlers/` (effect
handlers), `time/` (time grades), `traces/` (timed traces), `regular/`
(regular traces), `regular_costs/` (regular traces with costs), `levels/`
(security levels) and `3dprint/` (a case study of 3D printing). The examples
outside `basics/` are also offered by the web interface's example selector, in
groups matching these subdirectories, with [`examples/index`](examples/index)
giving the selector's manifest. Each example starts with the command that runs
it on the CLI.

## Grading monoids

Resource usage is measured in a grading monoid (an ordered monoid with some
additional structure). The monoid is not part of a source file but chosen when
the program is run: with `--grades` on the command line, e.g.

    ./tempore --grades time-interval examples/time/time_intervals.tpe

or with the **Grades** selector in the web interface, which switches
its value automatically when a built-in example is loaded. The selector groups
the monoids under a descriptive title and a one-line description (its
tooltip), and shows below it the `--grades` command equivalent to the current
selection; the CLI's `--help` lists the same names and titles, grouped
likewise. The default grade monoid is `time-lower-bound`. Currently, seventeen
monoids are available to choose, listed below by CLI name and title, as in
[`gradeRegistry.ml`](src/01-language/grades/gradeRegistry.ml), with what each
bounds:

- **Time** — `time-lower-bound` (Lower bounds): at least *n* time steps, the
  unit `0` greatest; `time-upper-bound` (Upper bounds): at most *n* time
  steps, the unit `0` least; `time-interval` (Intervals): between *n* and *m*
  time steps, ordered by containment.
- **Timed traces** — `traces-lower-bound` (Lower bounds): timed traces in the
  coverage order, operations costing their lower runtime bounds;
  `traces-upper-bound` (Upper bounds): timed traces in the allowance order,
  operations costing their upper runtime bounds; `traces-interval`
  (Intervals): a lower and an upper timed-trace bound, compared
  componentwise.
- **Regular traces** — `traces-regex` (Regular languages) and
  `traces-regex-symbolic` (Regular languages, symbolic derivatives): the same
  grade, regular languages of runs over delays and operations, decided
  respectively by automata and by symbolic derivatives.
- **Regular traces with costs** — `traces-regex-lower`, `traces-regex-upper`
  and `traces-regex-interval` (Lower bounds, Upper bounds, Intervals),
  each also offered with a `-symbolic` suffix: regular languages of runs
  costed by the runtime bounds of the operations they name, in the coverage
  order, the allowance order, or both, decided by automata or, with the
  suffix, by symbolic derivatives.
- **Security levels** — `security-levels` (Levels): the two-point security
  lattice `Low < High`; `time-lower-bound-levels` (Embargoes): a time lower
  bound paired with a level; `time-upper-bound-levels` (Expiring
  capabilities): a time upper bound paired with a level.

### Grade literals

All monoids share one syntax of grade literals, and each reads the literals it
understands; a literal the chosen monoid does not understand is a syntax error,
which names the monoids that do. Grades are written as integers such as `3`,
pairs such as `(1, 4)`, or brace expressions such as `{...}`, depending on the
monoid, detailed below. The greatest grade of every monoid is written
`⊤` (ASCII `top`).

### Time

Three monoids grade resources and computations by time, written as integer
literals such as `3` or pairs such as `(1, 4)`:

- **`time-lower-bound`** — non-negative integers, a lower bound on the time a
  computation takes. `rho` is a sub-grade of `rho'` when `rho >= rho'`; zero is
  the *top* of the order.
- **`time-upper-bound`** — non-negative integers, an upper bound on the time a
  computation takes. `rho` is a sub-grade of `rho'` when `rho <= rho'`; zero is
  the *minimum* of the order and `∞` (ASCII `inf`), imposing no bound, its top.
- **`time-interval`** — pairs `(n, m)` with `n <= m`, a lower and an upper
  bound at once. `(n, m)` is a sub-grade of `(k, l)` when `n >= k` and
  `l >= m` (interval containment); `(n, ∞)` (ASCII `(n, inf)`) imposes no
  upper bound. `(0, 0)` is neither the top nor the minimum, and the top is
  `(0, ∞)`. See
  [`examples/time/time_intervals.tpe`](examples/time/time_intervals.tpe).

All three variants of time bounds are inclusive on the values they carry, e.g.,
while intervals are written as `(n,m)`, they should be read as `[n,m]`.

### Timed traces

Three monoids grade resources and computations by the *timed traces* they may
exhibit. A timed trace is one run of a computation, an alternation of operation
events and positive delays: `Read; 3; Send` performs `Read`, waits three ticks,
and performs `Send`. A grade built from traces is a non-empty finite set of
runs, the alternatives a computation may exhibit, `{Read; 3; Send | Send;
Send}`; grades multiply by the (non-commutative) language product. An integer
`n` abbreviates `{n}`, so the zero grade is `{0}`. The orders trade time against
operations through the runtime bounds `within (lo, hi)` every atomic operation
(one whose trace is its own name) declares under these monoids (see below).

- **`traces-lower-bound`** — the runs a computation must *cover*. `rho`
  is a sub-grade of `rho'` when every run of `rho` covers some run of `rho'`:
  each operation performed banks its `lo` towards the delays `rho'` demands,
  but waiting never counts as performing a demanded operation. `{0}` is the
  top of the order. See
  [`examples/traces/traces_lower.tpe`](examples/traces/traces_lower.tpe).
- **`traces-upper-bound`** — the runs a computation is *allowed*. `rho`
  is a sub-grade of `rho'` when every run of `rho` fits inside some run of
  `rho'`: a delay in `rho'` pays for operations of `rho` at their `hi`, but
  waiting never counts as performing an operation the bound asks for. `{0}` is
  the minimum of the order; its top is a separate point `⊤`, permitting any
  run. See
  [`examples/traces/traces_upper.tpe`](examples/traces/traces_upper.tpe).
- **`traces-interval`** — pairs `({...}, {...})` of a lower bound
  (coverage order, reading `lo`) and an upper bound (allowance order, reading
  `hi`), compared componentwise. `{...}` abbreviates the pair of a set with
  itself, `n` abbreviates `({n}, {n})`, and `(n, m)` abbreviates
  `({n}, {m})`; either component may be `⊤`, the top of its order.
  `({0}, {0})` is neither the top nor the minimum, and the top is `({0}, ⊤)`.
  See [`examples/traces/traces_intervals.tpe`](examples/traces/traces_intervals.tpe).

The sets of traces are written in a brace literal `{...}`, which is a regular
expression over operation names and delays: `r; s` concatenates, `r | s` is a
union, and parentheses group, so that `{(Read | 2); Send}` is `{Read; Send | 2;
Send}`. The other forms of regular expressions below, repetition `r*`,
intersection `r & s`, complement `~r` and the wildcard `_`, denote infinite or
cofinite sets of runs, which these three monoids reject with a syntax error at
the literal naming the monoid.

### Regular traces

Two monoids grade resources and computations by *regular languages* of runs;
they are one grade, implemented in two ways:

- **`traces-regex-symbolic`** and **`traces-regex`** — a run is read as a word
  whose letters are operations and ticks: an operation `Read` is the letter
  `Read`, and a delay of `n` ticks is `n` copies of the letter `tick`. A grade
  is a non-empty regular language, the runs a computation may exhibit, or after
  which a resource may be used. `rho` is a sub-grade of `rho'` when every word
  of `rho` is in `rho'` (inclusion); grades multiply by concatenation and join
  by union; the unit is `{0}`, the language of the empty word, and the top `⊤`
  is the language of all words. The top is not absorbing: `{3}` multiplied by
  `⊤` is `{3; _*}`, the runs that begin with three ticks, not `⊤`. The order
  does not trade time against operations, so no operation declares runtime
  bounds. See
  [`examples/regular/regular_traces.tpe`](examples/regular/regular_traces.tpe),
  which runs with `traces-regex-symbolic`, the implementation to prefer.

#### Alphabet and literals

Their brace literals are the full regular expressions, by increasing precedence:
union `r | s`, intersection `r & s`, concatenation `r; s`, complement `~r` and
repetition `r*`; an operation name is that letter, an integer `n` is `n` ticks
(`0` the empty word), `_` is any single letter, and parentheses or braces
group. So `{Open; (Read | Write)*; Close}` is a file session, `{_*; Auth; _*}`
the runs that authenticate at some point, and `{~{_*; Revoke; _*}}` those that
never revoke. The operators need no spaces around them inside braces, as in
`{Read*|~Send}`; as in OCaml, a `*)` inside a comment closes it, so a
commented-out `{~(_*; Revoke; _*)}` is better written with braces. A plain
integer `n` abbreviates `{n}`, and a literal denoting the empty language, such
as `{Read & Send}`, is a syntax error, since grades are non-empty.

The letters of a grade are `tick`, the operations it names, and one catch-all
letter standing for every other operation; `_` and `~` range over these
letters, so `{_ & ~Read}` is any single tick or operation other than `Read`.
When two grades are combined or compared, both are read over the operations
either names, the catch-all letter of each standing also for the operations
only the other names: `{Send}` is a sub-grade of `{_ & ~Read}`.

#### Two implementations: automata and symbolic derivatives

`traces-regex-symbolic` keeps grades as regular expressions in a normal form:
unions and intersections are sets of operands, with the unit and zero laws,
`~~r` is `r`, and letter sets are merged, as in `{_ & ~Read | Read}`, which is
`{_}`. Inclusion and equality are decided by *symbolic derivatives*, in the
style of RE# (Varatalu, Veanes and Ernits, POPL 2025): `rho <= rho'` holds when
no derivative of `rho & ~rho'`, taken by the classes of letters the expression
tells apart, contains the empty word, and equality is a bisimulation of the
derivatives of both grades. No automaton is built, so products and joins cost
nothing and only the derivatives a decision needs are computed.
`traces-regex` keeps each grade as its minimal deterministic automaton over the
letters it names, so that equal grades are equal automata, and builds the
automata of products, joins and complements by the product and subset
constructions.

`dune exec --profile release bench/regular/bench_regular.exe` benchmarks the two
implementations on the example, the tests and grade operations at scale, with
the results in [`bench/regular/README.md`](bench/regular/README.md).

#### Printing and counterexamples

A grade is printed as one of three regular expressions determined by its
language: the one read off its minimal automaton by state elimination and
simplified by laws of Kleene algebra, the complement of the one for its
complement, and the reversal of the one for its reversal. The one printed is
the least costly, the cost counting the states of the automata and the sizes of
the expressions built along the way, provided that the cost does not exceed the
size of the grade's normal form (under `traces-regex`, the normal form of the
expression the grade was built from): each construction stops as soon as it
does, and if none fits, the normal form itself is printed. Two grades denoting
the same language thus print alike unless one of them is printed as its normal
form, and so do the two implementations unless `traces-regex-symbolic`, which
explores the derivatives of the normal form rather than an automaton at hand,
prints its normal form. For example, `{~(_*; Revoke; _*)}` prints as `{(_ &
~Revoke)*}`, `{_*; Auth; _*}` as `{~(_ & ~Auth)*}`, `{Open; Read*; Close |
Open; Write*; Close}` as `{Open; {Read* | Write*}; Close}` and `{~(A*; (_ &
~A))*}` as `{_*; A}`, but `{3 | 2*}` and `{_*; A; _; _; _}`, whose minimal
automata have more states than their normal forms have symbols, as written; a
group ending with `*` is printed in braces, so that it can be quoted in a
comment. When an ordering of grades fails, a note names a shortest run of the
lesser grade that the greater one does not contain, unless that run is the
lesser grade itself:

```
Typing error: Variable `t` is unboxed with grade `{Auth | Fetch}` accumulated since it was bound, which is not below its box grade `{Auth; _*}`
  ...
  Note: the resource inequality `{Auth | Fetch} <= {Auth; _*}` does not hold
  Note: the grade `{Fetch}` is below `{Auth | Fetch}` but not below `{Auth; _*}`
```

### Regular traces with costs

Three monoids read the regular languages of runs the way the timed-trace
monoids read finite sets of runs, trading time against operations at the
runtime bounds `within (lo, hi)` that every atomic operation declares under
them; like the regular trace grade, each is implemented in two ways, over the
implementation of `traces-regex` and, under the same name followed by
`-symbolic`, over that of `traces-regex-symbolic`:

- **`traces-regex-upper`** — the runs a computation is *allowed*, as under
  `traces-upper-bound`. `rho` is a sub-grade of `rho'` when every run of `rho`
  fits inside some run of `rho'`: the ticks of `rho'` pay for the operations
  of `rho` at their `hi`, an operation `rho'` names may instead be matched by
  the same operation of `rho`, and a match resets the budget, so that ticks
  before it pay for nothing after it and conversely. `{0}` is the minimum of
  the order and `⊤` its top.
- **`traces-regex-lower`** — the runs a computation must *cover*, as under
  `traces-lower-bound`. `rho` is a sub-grade of `rho'` when every run of `rho`
  covers some run of `rho'`: the ticks and operations of `rho` bank towards the
  ticks `rho'` demands, operations at their `lo`, and an operation `rho'`
  demands is covered only by that operation. `{0}` is the top of the order.
- **`traces-regex-interval`** — pairs `({...}, {...})` of a lower bound (the
  order of `traces-regex-lower`, reading `lo`) and an upper bound (the order of
  `traces-regex-upper`, reading `hi`), compared componentwise, with the
  abbreviations of `traces-interval`: `{...}` is the pair of a language with
  itself, `n` is `({n}, {n})` and `(n, m)` is `({n}, {m})`. The top is
  `({0}, ⊤)`.

Their literals, products, joins and printing are those of `traces-regex` and
`traces-regex-symbolic`. The alphabet is *closed*: the letters of a comparison
are `tick` and the operations the whole program declares with runtime bounds,
its atomic operations, each at its own runtime bounds, and the catch-all letter
of a grade stands for each of them it does not name. All the sources of a
program, the standard library included, are read before any is typechecked,
and the operations they declare are collected from their `operation`
declarations, their names and runtime bounds only, so that a grade means the
same wherever it is written, before or after the declarations; an operation is
still performed only after its declaration. So `_` is any single tick or
atomic operation of the program, and under `traces-regex-upper` `{_}` is a
sub-grade of `{n}` exactly when `n` is at least the greatest `hi` declared
(and at least 1). A compound operation is no letter: performing it exhibits the
runs of its grade. Every operation a grade names must be declared, as for the
timed-trace monoids.

A run that performs the catch-all letter where every operation of the program
is named is no run at all, and a grade must denote at least one run: a grade
written in a program that declares only `Fetch`, such as `{_ & ~1 & ~Fetch}`,
is rejected at its literal, wherever it is written,

```
Typing error: The grade `{_ & ~(1 | Fetch)}` permits no run of the declared operations
```

and accepted once the program declares another atomic operation anywhere.
Each component of an interval grade must denote a run. This keeps `{0}` the
minimum of `traces-regex-upper`.

A grade stands for its *closure*: under `traces-regex-upper`, the runs that fit
inside one of its runs, and under `traces-regex-lower`, the runs that cover one
of them. `rho` is a sub-grade of `rho'` when every run of `rho` is in the
closure of `rho'`, which is decided by exploring the product of an automaton of
`rho` with an automaton of that closure, whose states are sets of states of an
automaton of `rho'`, both built only as far as the search needs them. Over
`traces-regex`, both are the minimal automata of the grades. Over
`traces-regex-symbolic`, the states of the automaton of `rho` are its
derivatives, and so are those of the automaton of `rho'` under the lower order,
whose closure has a derivative of its own: the derivative of the closure of a
set of expressions by a letter is the closure of their derivatives by the
letter and by the ticks it banks; the closure under the upper order needs all
the states of `rho'` at once, and is built over the automaton of the
derivatives of `rho'`, explored in full. The closure automaton can be
exponentially larger than `rho'`, as for the scattered-subword closures that
are a special case of it. When an ordering fails, a note names a shortest run
of the lesser grade outside the closure of the greater one.

Grades equal as closures are equal, which is coarser than equality of
languages, so several laws hold only up to this equality. With `Read` declared
`within (1, 3)`: under `traces-regex-upper`, `{Read}` is a sub-grade of `{3}`
but not conversely, and `{Read | 3}` equals `{3}`; `⊤` is absorbing, `{3}`
multiplied by `⊤` being `⊤`, unlike under `traces-regex`; and the closure of a
product may be larger than the product of the closures, `{Read}` being a
sub-grade of `{2}` multiplied by `{2}` but not of `{2}`. An operation cannot
be excluded while unbounded time is allowed: `{(_ & ~Read)*}` equals `⊤`,
since its ticks pay for `Read`. Under `traces-regex-lower`, `{Read | 1}` equals
`{1}`, and `⊤` equals the unit `{0}`, which every run covers. See
[`examples/regular_costs/regular_costs_lower.tpe`](examples/regular_costs/regular_costs_lower.tpe),
[`examples/regular_costs/regular_costs_upper.tpe`](examples/regular_costs/regular_costs_upper.tpe)
and
[`examples/regular_costs/regular_costs_intervals.tpe`](examples/regular_costs/regular_costs_intervals.tpe),
which run with `traces-regex-lower-symbolic`, `traces-regex-upper-symbolic`
and `traces-regex-interval-symbolic` respectively, the default implementations,
consistent with `traces-regex-symbolic`.

`dune exec --profile release bench/regular/bench_regular.exe` also benchmarks
the two implementations of these monoids, on their examples, their tests and
grade operations at scale, with the results in
[`bench/regular/README.md`](bench/regular/README.md).

### Security levels and products

One monoid grades resources and computations by *security levels*, and two
more pair it with time:

- **`security-levels`** — the two levels `Low` and `High`, with `Low` below
  `High`. The grade of a computation is the highest level it touches: both the
  product and the join of two levels are the higher of them, `Low` is the unit
  and the minimum, and `High` the top. Delays touch no level, so `delay n` has
  the grade `Low`. A resource boxed at a level may be unboxed only while the
  level has not risen above it since boxing: a value boxed at `Low` is out of
  reach once an operation of grade `High` has run. See
  [`examples/levels/security_levels.tpe`](examples/levels/security_levels.tpe).
- **`time-lower-bound-levels`** — pairs `(n, l)` of a `time-lower-bound`
  grade and a level: at least `n` ticks, touching nothing above `l`. A box at
  `(3, Low)` is an embargo with a taint check, claimable after at least three
  ticks and only while nothing `High` has run. See
  [`examples/levels/time_lower_levels.tpe`](examples/levels/time_lower_levels.tpe).
- **`time-upper-bound-levels`** — pairs `(n, l)` of a `time-upper-bound`
  grade and a level: at most `n` ticks, touching nothing above `l`. A box at
  `(5, Low)` is an expiring capability, usable within five ticks and only while
  nothing `High` has run; `(∞, Low)` never expires. See
  [`examples/levels/time_upper_levels.tpe`](examples/levels/time_upper_levels.tpe).

The last two are instances of a general *product* of two monoids: pairs of
grades, multiplied, joined and compared componentwise, with the pair of the
units as the unit and the pair of the tops, written `⊤`, as the top; a delay of
`n` ticks is graded in both components at once. The unit is the minimum, and
the product commutative, when they are so in both components.

## Temporal resources

A value of the modal type `[rho]a` is an `a`-typed resource that may be used
only once the grade `rho` has been accumulated since it was created: an amount
of time, a sequence of operations, or whatever the chosen monoid measures.

### Boxes and unboxing

- `box rho e` creates a resource of type `[rho]a`. The expression `e` is typed
  in the hypothetical future in which the accumulated grade has grown by `rho`.
- `unbox e` opens a resource `e : [rho]a`, yielding an `a`. It is allowed only
  if the grade accumulated since `e` was boxed is a sub-grade of `rho`: at
  least `rho` ticks under the lower-bound monoids, at most `rho` under the
  upper-bound ones, a run that covers or fits inside `rho` under the trace
  monoids, a run in the language `rho` under the regular trace monoids, and a level no higher than `rho` under `security-levels`; the
  products check both components.

### Delays

`delay tau` advances the accumulated grade by `tau`. Operation calls (below)
advance it by the grade of the operation. See
[`examples/basics/delay.tpe`](examples/basics/delay.tpe).

The computation type of a function can be stated explicitly, either on its body,
`let f () : mounted # rho = ...`, or on the function as a whole, `let f : unit
-> mounted # rho = fun () -> ...`. The annotation is a sub-effecting coercion,
analogously to handlers' operation case: the grade the body accumulates must be
a sub-grade of the one stated in the type annotation.

## Eternal types

A type is *eternal* if its values stay valid however much grade accumulates
after they are bound. Eternal are the base types (integers, strings, booleans,
floats, unit), tuples of eternal types, and algebraic types all of whose
constructor arguments are eternal. Function types, handler types, and box types
`[rho]a` are never eternal. A type variable is eternal exactly when it is
instantiated with an eternal type, so a parameterised type is eternal depending
on how its parameters are used: `'a list` is eternal when `'a` is, while a
phantom parameter, as in `type 'a tag = Tag`, imposes nothing.

Referencing a local variable `x : a` generates the constraint "`a` is eternal,
or the grade accumulated since `x` was bound is a sub-grade of zero". Under
`time-lower-bound` and `traces-lower-bound` zero is the top of the order,
so the constraint always holds and any local variable may be used at any later
point. Under the other monoids a local variable of a non-eternal type must be
used before any `delay` or operation call has happened since it was bound.

### Schemes and qualifiers

When the constraint depends on a type variable of a top-level definition, it
is not decided at the definition but becomes a qualifier of its generalised
type, checked at every use. For example, under `time-upper-bound`,

```
let keep x = delay 1; x
let after g x = g (); x
```

respectively get the qualified schemes

    ∀ α. Et(α) ⇒ α → α # 1
    ∀ α β ε₀. Et(β) ∨ ∣ε₀∣ ≾ 0 ⇒ (unit → α # ε₀) → β → β # ε₀ # 0

shown by `--debug`, where `Et(β)` requires `β` to be eternal and `∣ε₀∣` is the
resource grade that accumulates while `g` runs. So `keep 5` is accepted and
`keep (fun () -> ())` is rejected:

    `unit → unit` is not eternal, but `keep` needs the type of `x` to be
    eternal
      Note: the resource inequality `1 <= 0` does not hold

while `after (fun () -> delay 2) 5` is accepted because `5` is eternal, and
`after (fun () -> ()) (fun () -> ())` because `g` takes no time. A variable
captured in an operation case is constrained in the same way, the top grade
having accumulated for it (see [Contexts of operation
cases](#contexts-of-operation-cases)). See
[`examples/basics/eternal_types.tpe`](examples/basics/eternal_types.tpe) and the end of
[`examples/3dprint/3dprint_traces.tpe`](examples/3dprint/3dprint_traces.tpe).

### Noneternal declarations

A type definition can be declared non-eternal regardless of its structure:

```
noneternal type epoxy = Epoxy
```

This makes `epoxy`, and every type containing it, non-eternal. The keyword
prefixes a whole `type ... and ...` group. It is allowed on algebraic types
only, since type aliases are unfolded before eternality is checked.

## Algebraic effects and effect handlers

### Operations and their grades

Operations are declared at the top of a source file:

```
operation OperationName : input-type ~> result-type # grade
```

The grade records the resource usage of one call.

Under the timed-trace monoids an *atomic* operation, one graded by the singleton
trace set containing just itself, must also state its runtime bounds,

```
operation OperationName : input-type ~> result-type # grade within (lo, hi)
```

the least and greatest number of ticks a call may take (`within n` is short for
`within (n, n)`). The bounds are the cost model of the trace orders:
`traces-lower-bound` reads `lo`, `traces-upper-bound` reads `hi`,
and `traces-interval` reads both.

A *compound* operation names other, already declared operations in its grade,
and its bounds are computed from theirs: `lo` is the duration of the fastest run
of its grade with every event at its lower bound, `hi` that of the slowest run
with every event at its upper bound. So given `Tx : string ~> unit # {Tx} within
(2, 3)`, the operation `Send : string ~> unit # {Tx | Tx; Tx}` gets the bounds
`(2, 6)`; declaring bounds on it is rejected, as is naming itself, since `Send #
{Send | Send; Send}` would make its bounds depend on themselves. Retries are
expressed through a smaller operation instead. Under the time monoids no bounds
are declared, since the grade already is the bound, nor under the regular trace
monoids, whose order does not read them.

An operation is called with

```
perform OperationName argument
```

which returns a `result-type` value and advances the accumulated grade by the
operation's grade.

### Handlers and continuations

Operation calls are given meaning by handlers:

```
let h =
  handler
  | x -> return-case
  | OperationName p k -> operation-case
  | ...
```

The return case runs when the handled program returns a value `x`. An operation
case runs when the handled program calls the operation; `p` is the
argument/parameter and `k` the continuation, resumed with `continue k with
result`. Operations without a case are forwarded to the enclosing handler.

An operation case need not have exactly the grade of the operation: it
suffices that its grade is a sub-grade of the operation's grade composed with
that of the continuation. The continuation `k` is a resource of the
operation's grade, so resuming it unboxes it, which is allowed only once the
case has accumulated a sub-grade of that grade. So
`PrintModel : model ~> print # {Heat; Extrude; Cool}` may be handled by
performing `Heat`, `Extrude` and `Cool` in that order and continuing, while
another order is rejected:

    Variable `k` is unboxed with grade `{Cool; Extrude; Heat}` accumulated
    since it was bound, which is not below its box grade
    `{Heat; Extrude; Cool}`
      Note: the resource inequality
        `{Cool; Extrude; Heat} <= {Heat; Extrude; Cool}` does not hold

Under the time monoids the same rule lets a case delay longer than the
operation's grade under `time-lower-bound`, and shorter under
`time-upper-bound`.

The effect of the continuation `k` is not known when the handler is
typechecked, so an operation case must be well-typed for *every* effect `eps`
of `k`: `k` has the type `[rho](b → c # eps)` for the operation's grade `rho`,
and the case must have a sub-grade of `rho · eps`. The typechecker makes `eps`
a rigid effect variable: it is never given a value, and it may not occur in the
type of a top-level definition, so it can be neither fixed by the case nor
instantiated at a use site. An inequality mentioning `eps` must hold for every
value of it. A case that does not resume, `Op p k -> 5`, has grade `0`, a
sub-grade of `1 · eps` for every `eps` under an upper bound, where zero is the
minimum, but for no `eps` under a lower bound, where the messages state the
quantification and the failing instance:

    For every grade `ε₀` the continuation `k` may have, the case for `Op` must
    have a grade matching `1 · ε₀`, but its grade `0` does not
      Note: the effect inequality `∀ε₀. 0 >= 1 · ε₀` does not hold: for
        `ε₀ = 0` it becomes `0 >= 1`

Resuming twice under `Op # 1` fails under an upper bound: the second
resumption unboxes `k` after the first has run for `eps`, and `∣eps∣ <= 1`
fails for `eps = ∞`:

    Variable `k` is unboxed with grade `∣ε₀∣` accumulated since it was bound,
    which is not below its box grade `1`
      Note: the resource inequality `∀ε₀. ∣ε₀∣ <= 1` does not hold: for
        `ε₀ = ∞` it becomes `∞ <= 1`

Under a lower bound it is accepted once the case has waited for the
operation's grade, `Op p k -> delay 1; let a = continue k with () in continue
k with ()`, as the grade accumulated before the second resumption only grows.

### Contexts of operation cases

An operation case runs with a grade the handler does not fix: the call may come
at any point of the handled computation, and the case must be well-typed for
every grade its continuation may have. So a case is typed in its context
*locked* at the top grade `⊤`: to the variables bound outside the case, the
top grade has accumulated when the case runs. By the usual rules, such a
variable may then be used in the case only if its type is eternal or `⊤` is
below the unit, and an outer box may be unboxed in the case only if `⊤` is
below its grade.

Under `time-lower-bound` and `traces-lower-bound` the top is the unit, so the
lock restricts nothing: a case may use a function, a non-eternal value or an
outer continuation bound outside it, and unbox any outer box. Under the other
monoids a variable of non-eternal type bound outside the case is rejected
there, whatever the grades are; under `time-upper-bound`:

    Variable `f` has type `unit → int`, which is not eternal, so it cannot be
    used in the case for `Op`: the case runs with a grade the handler does not
    fix
      Note: the resource inequality `∞ <= 0` does not hold

and an outer box of grade `3` cannot be unboxed in a case:

    Variable `b` is unboxed with grade `∞` accumulated since it was bound, which
    is not below its box grade `3`
      Note: the resource inequality `∞ <= 3` does not hold

The case's own `p` and `k`, and everything bound inside it, are unaffected:
they obey the usual rules from the start of the case. When the type is a type
variable the obligation becomes a qualifier of the definition's scheme, as
above, so under `time-upper-bound`
`let h x = handler | y -> y | Op p k -> let r = continue k with () in x` gets
a scheme qualified by `Et(α)` for the type `α` of `x`, usable at `int` and not
at `unit → unit`.

A continuation is a box, so under the monoids whose top is not the unit an
inner case cannot resume an outer handler's continuation: in nested handlers
each case resumes its own continuation, and the outer one is resumed after the
inner `handle` returns.

Top-level definitions are exempt: they are closed, time-invariant values, so
they stay in scope inside a case whatever their type.

See [`tests/op_case_context.tpe`](tests/op_case_context.tpe) and the
`tests/op_case_context_*.tpe` files, and
[`examples/handlers/handlers_lower_bound.tpe`](examples/handlers/handlers_lower_bound.tpe),
[`examples/handlers/handlers_upper_bound.tpe`](examples/handlers/handlers_upper_bound.tpe),
[`examples/handlers/handlers_nested.tpe`](examples/handlers/handlers_nested.tpe),
[`examples/handlers/handlers_nested_reject.tpe`](examples/handlers/handlers_nested_reject.tpe)
and [`examples/3dprint/3dprint_handlers.tpe`](examples/3dprint/3dprint_handlers.tpe).

### Default implementations

An operation may be given one default implementation, after its declaration:

```
default OperationName p = t
```

The default runs only when a call reaches the top level unhandled, that is,
after every enclosing handler has forwarded it; a handled call never uses it,
and a call without a default stops the run. The body `t` runs in place of the
call and its result goes to the continuation.

A default is checked against the operation's runtime bounds rather than its
grade: the body must have a sub-grade of `{lo}` under
`traces-lower-bound`, of `{hi}` under `traces-upper-bound`, and of
`({lo}, {hi})` under `traces-interval`. Under the time monoids it is
checked against the operation's grade, and so it is under the regular trace
monoids, whose operations declare no runtime bounds; there an atomic operation such as
`Read # {Read}` thus admits no default, and is only realised by performing it. The grade itself cannot be required,
since realising `{Heat}` would mean performing `Heat` again. So

```
operation Heat : unit ~> unit # ({Heat}, {Heat}) within (1, 2)
default Heat () = delay 1
```

is accepted under `traces-interval` because `({1}, {1}) <= ({1}, {2})`,
while `delay 6` is rejected:

    The default implementation of `Heat` has grade `({6},{6})`, which does not
    match the declared grade `({1},{2})` of `Heat`
      Note: the effect inequality `({6},{6}) <= ({1},{2})` does not hold

Under the trace monoids only *atomic* operations, graded by the single run of
themselves such as `Heat # {Heat}`, may have defaults; a compound operation
such as `PrintModel # {Heat; Extrude; Cool}` is meant to be handled in terms
of the operations it names. A default may itself perform operations, which are
handled or defaulted in turn; a default that performs its own operation
typechecks but never terminates.

## Type inference

Types and grades are inferred in the style of HM(X), Hindley–Milner inference
over a constraint domain: a program generates constraints, which are then
solved and simplified.

### Subtyping

Types are compared by subtyping rather than by equality. A function type is
contravariant in its argument and covariant in its result and effect, and a
box type `[rho]a` is contravariant in its grade: a box claimable with `rho`
accumulated may be used where one claimable with a sub-grade of `rho`
accumulated is expected. Subtyping preserves the shape of types, and the
arguments of type constructors such as `list` are compared for equality.

### Resource and effect grades

Box types and the grades accumulated in a context are *resource* grades;
computations and operation signatures carry *effect* grades. The two sorts
are related by a grade system, which maps an effect grade to the resource
grade that accumulates while it runs. At present each grading monoid
provides both sorts, related by the identity.

### Constraints

Besides subtyping, a program asks for orderings between grades, for types
to be eternal, and, for a variable used with some grade `rho` accumulated
since its binding, that its type is eternal or `rho` is below the unit. The
effect of the continuation of a handler's operation case is unknown to the
case, so the case is checked for every such effect.

### Schemes

Only top-level `let` definitions are generalised; a local `let` has a
monomorphic type. The scheme of a top-level definition is qualified,
`∀ α ρ₀ ε₀. Q ∧ R ⇒ A`: `Q` are the constraints left on its unknowns and `R`
conditions of operation cases that must hold for every effect of their
continuations. Every use of the definition instantiates the scheme and
checks its qualifier. Schemes are simplified before they are reported:
redundant constraints are dropped, and an unknown the type does not need is
replaced by its bound. For example, under `time-upper-bound` the standard
library's `compose f g x = f (g x)` has the scheme

    ∀ α β γ ε₀ ε₁. ∣ε₁∣ ≾ 0 ⇒ (α → β # ε₀) → (γ → α # ε₁) → γ → β # ε₁ · ε₀ # 0 # 0

where `ε₁ · ε₀` is `g`'s effect followed by `f`'s, and `∣ε₁∣ ≾ 0` asks `g`
to take no time, as the non-eternal `f` is used after it has run.

### Satisfiability

Whether the qualifier of a definition can be met is decided provisionally:
a closed instance of it is searched for, and the definition is rejected
only when the search refutes the qualifier. When the search neither finds
nor refutes an instance, the definition is accepted, and its uses report
any failure of the qualifier instantiated there.

## Sub-effecting and its limits

Grades are compared by the sub-grade order wherever a value or a computation
meets what is expected of it, following the subtyping of types: a computation
may be used where one of a super-grade is expected, and an annotation on a
function or its body is an upper bound, the grade the body accumulates having
to be a sub-grade of the annotated one. So under `time-upper-bound`

```
let apply (f : unit -> int # 2) = f ()
let slow () = delay 1; 3
let branch c = if c then delay 1 else delay 2
```

`apply slow` is accepted, `unit → int # 1` being a subtype of
`unit → int # 2`, and `branch` gets the type `bool → unit # 2`, both branches
having a sub-grade of `2`. A box type is contravariant in its grade: under
`time-lower-bound` a `[2]int` is accepted where a `[3]int` is expected, since
a resource that may be claimed after two ticks may also be claimed after three,
while a `[4]int` is not.

The limits are these:

- the arguments of a type constructor such as `list`, and the input of a
  handler type, are compared for equality, grades included: a
  `(unit -> int # 1) list` is not accepted where a `(unit -> int # 2) list` is
  expected, although a list built from `slow` gets the scheme
  `∀ ε₀. 1 ≾ ε₀ ⇒ (unit → int # ε₀) list` and is accepted at both;
- a local `let` is not generalised, so a locally defined function is used at
  one type throughout its scope;
- the effect of a handler clause's continuation is rigid, so the clause is
  checked for every effect its continuation may have (see
  [Algebraic effects and effect handlers](#algebraic-effects-and-effect-handlers));
- whether the qualifier of a top-level definition can be met is decided
  provisionally (see [Type inference](#type-inference)).

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