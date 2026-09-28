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

Tested with OCaml >= 5.0. Install the dependencies and build:

    opam install --deps-only --with-dev-setup .
    make

`make test` runs the test suite; `make clean` removes the build.

### Command line

    ./tempore file1.tpe file2.tpe ...

loads the listed files, runs every `run` command, and prints each result with
the final resource state. Options:

- `--grades <grades>` selects the grading monoid (default `time-lower-bound`;
  see [Grading monoids](#grading-monoids));
- `--typecheck-only` typechecks without running;
- `--no-stdlib` skips the standard library;
- `--debug` also prints the typing context, including the inferred schemes;
- `--help` lists the options and the grading monoids.

### Web interface

Open `web/index.html` after building, or use
<https://danel.ahman.ee/tempore-lang/>. Load an example or type a program,
typecheck it, and step through its reductions while watching the resource
state. The **Grades** selector chooses the grading monoid; loading an example
selects its monoid.

The [`examples/`](examples/) directory holds example programs by topic:
`basics/`, `handlers/`, `time/`, `traces/`, `regular/`, `regular_costs/`,
`levels/`, `semidirect/`, `counts/`, `3dprint/` (a 3D-printing case study)
and `rollout/` (a staged software rollout). All but `basics/` are offered in the web interface
([`examples/index`](examples/index)).

## Grading monoids

Resources and computations are graded by an ordered monoid, chosen at run time
with `--grades` or the **Grades** selector, e.g.

    ./tempore --grades time-interval examples/time/time_intervals.tpe

`rho <= rho'` is the sub-grade order. The monoids are listed in
[`gradeRegistry.ml`](src/01-language/grades/gradeRegistry.ml); their
implementation is documented in the modules under
[`src/01-language/grades/`](src/01-language/grades/).

### Grade literals

All monoids share one literal syntax: integers (`3`), pairs (`(1, 4)`) and
brace expressions (`{...}`). Each monoid accepts the literals it understands;
any other literal is a syntax error naming the monoids that accept it. The
greatest grade is `⊤` (ASCII `top`). Integers may be negative (`-1`); only
`peak-usage` accepts negative ones.

### Time

A grade bounds the number of time steps a computation takes. Bounds are
inclusive.

- `time-lower-bound`: `n` is at least `n` steps; ordered by `>=`, so `0` is
  the top.
- `time-upper-bound`: `n` is at most `n` steps, `∞` (ASCII `inf`) no bound;
  ordered by `<=`, so `0` is least and `∞` the top.
- `time-interval`: `(n, m)` is between `n` and `m` steps; ordered by
  containment, with top `(0, ∞)`.

Example: `box (2, 5) x` may be unboxed after two to five steps. See
[`examples/time/time_upper.tpe`](examples/time/time_upper.tpe) and
[`examples/time/time_intervals.tpe`](examples/time/time_intervals.tpe).

### Timed traces

A grade is a non-empty finite set of *timed traces*, the runs a computation may
exhibit. A run alternates operations and delays: `Read; 3; Send` performs
`Read`, waits three steps, and performs `Send`. Grades multiply by
concatenation. Every atomic operation declares runtime bounds
`within (lo, hi)`, at which the orders trade time against operations.

- `traces-lower-bound`: the runs a computation must *cover*; an operation
  performed counts as `lo` steps towards a demanded delay. `{0}` is the top.
- `traces-upper-bound`: the runs a computation is *allowed*; a delay pays for
  operations at their `hi`. `{0}` is least and `⊤` the top.
- `traces-interval`: pairs `({...}, {...})` of a lower and an upper bound,
  compared componentwise; `{...}` abbreviates `({...}, {...})`, `n` is
  `({n}, {n})` and `(n, m)` is `({n}, {m})`.

Literals use `;` for sequence, `|` for union and parentheses: `{(Read | 2);
Send}` is `{Read; Send | 2; Send}`. An integer `n` abbreviates `{n}`. See
[`examples/traces/traces_lower.tpe`](examples/traces/traces_lower.tpe),
[`examples/traces/traces_upper.tpe`](examples/traces/traces_upper.tpe) and
[`examples/traces/traces_intervals.tpe`](examples/traces/traces_intervals.tpe).

### Regular traces

A grade is a non-empty regular language of runs, read as words over the
letter `tick` (one time step) and operation names. The order is inclusion,
the product concatenation and the join union; the unit is `{0}` and the top
`⊤` the language of all runs. Operations declare no runtime bounds.

- `traces-regex-symbolic`: decided by symbolic derivatives (preferred);
- `traces-regex`: decided by minimal automata.

Literals are regular expressions, by increasing precedence: union `r | s`,
intersection `r & s`, concatenation `r; s`, complement `~r` and repetition
`r*`. An operation name is that letter, an integer `n` is `n` ticks, `_` is
any single letter (including one catch-all letter for the operations the
grade does not name), and parentheses or braces group. For example,
`{Open; (Read | Write)*; Close}` is a file session and `{~{_*; Revoke; _*}}`
the runs that never revoke. When an ordering fails, a note names a shortest
run of the lesser grade not in the greater one:

```
Typing error: Variable `t` is unboxed with grade `{Auth | Fetch}` accumulated since it was bound, which is not below its box grade `{Auth; _*}`
  ...
  Note: the grade `{Fetch}` is below `{Auth | Fetch}` but not below `{Auth; _*}`
```

See [`examples/regular/regular_traces.tpe`](examples/regular/regular_traces.tpe).
`dune exec --profile release bench/regular/bench_regular.exe` benchmarks the
two implementations, together with two intermediate ones that separate the
effects of their design choices; see
[`bench/regular/README.md`](bench/regular/README.md).

### Regular traces with costs

A grade is a regular language of runs, as under `traces-regex`, ordered as the
timed-trace monoids order finite sets of runs, at the runtime bounds
`within (lo, hi)` of the atomic operations. A grade stands for its closure:
the runs that fit inside one of its runs (upper) or cover one of them (lower).

- `traces-regex-upper`: allowance order at `hi`; `{0}` is least, `⊤` the top.
- `traces-regex-lower`: coverage order at `lo`; `{0}` is the top.
- `traces-regex-interval`: pairs of a lower and an upper bound, with the
  abbreviations of `traces-interval`; the top is `({0}, ⊤)`.

Each is also available with the suffix `-symbolic`, over
`traces-regex-symbolic`. Literals are those of `traces-regex`. The alphabet is
the atomic operations of the whole program, declared anywhere in it, so `_`
is any tick or atomic operation. A grade must denote at least one run of these
operations. With `Read` declared `within (1, 3)`, under `traces-regex-upper`
`{Read}` is a sub-grade of `{3}`, and `{Read | 3}` equals `{3}`. See
[`examples/regular_costs/regular_costs_lower.tpe`](examples/regular_costs/regular_costs_lower.tpe),
[`examples/regular_costs/regular_costs_upper.tpe`](examples/regular_costs/regular_costs_upper.tpe)
and
[`examples/regular_costs/regular_costs_intervals.tpe`](examples/regular_costs/regular_costs_intervals.tpe).

### Security levels and products

- `security-levels`: the levels `Low < High`; a computation's grade is the
  highest level it touches, and delays touch none. A box at `Low` is out of
  reach once an operation of grade `High` has run.
- `time-lower-bound-levels`: pairs `(n, l)`, at least `n` steps and nothing
  above `l`; `(3, Low)` is an embargo with a taint check.
- `time-upper-bound-levels`: pairs `(n, l)`, at most `n` steps and nothing
  above `l`; `(5, Low)` is an expiring capability.
- `flow-levels`: tuples `(l, (S₁, l₁), …, (Sₖ, lₖ))`, nothing above `l`
  touched and each output `Sᵢ` written at most at the level `lᵢ` touched
  before it; `l` alone writes no output, and an entry `(_, l')` bounds every
  output not listed. An output is a capitalised name, and
  an operation writing it has a grade such as `(Low, (Board, Low))`; after one
  of grade `High`, it is written at `High`. A semidirect product (see
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
componentwise.

- `peak-usage`: pairs `(d, h)` of the net change `d` and the peak `h` of a
  resource held, such as open files, with `h >= 0` and `h >= d`;
  `(d, h) · (d', h') = (d + d', max(h, d + h'))`. Delays change nothing, so
  the unit `(0, 0)` is their grade; `(∞, ∞)` is the top. Resources are named
  by entries `(R, d, h)`, e.g. `((Files, 0, 2), (Sockets, 0, 1))`, each bounded
  on its own; a resource not listed is bounded by `(0, 0)`, or by the entry
  `(_, d, h)`, and a plain `(d, h)` bounds every resource. An operation opening
  a file has grade `(Files, 1, 1)`, and one closing it `(Files, -1, 0)`; two
  copies in sequence, each holding two files, have grade `(Files, 0, 2)`.
- `time-windows`: tuples `(T, (A, E_A), …)` of the possible durations `T` and
  the times `E_A` at which each operation `A` happens, all sets of numbers of
  ticks from the start; `(T, E) · (T', E') = (T + T', E ∪ (T + E'))`, `+`
  adding elementwise, and the order is inclusion. `T` is written `n`, `(n, m)`
  (from `n` to `m`, `m` possibly `∞`) or as a brace literal over ticks,
  `{0 | 10}`, and `T` alone performs no operation; `E_A` is a brace literal,
  `{(4 | 5); 10*}` being ticks 4 and 5 of every ten, and an entry `(_, E)`
  bounds every operation not listed. An operation `Send` taking a tick and
  happening at its start has grade `(1, (Send, {0}))`.
- `mode-costs`: max-plus matrices of the greatest costs of the runs between
  named modes, the completion under joins of a semidirect product of mode
  changes and costs. Entries `(From, To, n)` give the runs, e.g.
  `(Off, On, 2)` for switching a radio on; the product gives `(p, r)` the
  greatest cost of a run from `p` to a mode `q` followed by one from `q` to
  `r`. An operation has no run from the modes its grade does not name, so
  `(On, On, 4)` is possible only with the radio on, and a plain `n` costs `n`
  and keeps any mode. Delays cost nothing; an idle draw is charged by
  operations such as `Sleep : unit ~> unit # ((Off, Off, 10), (On, On, 50))`.

An operation whose grade no code meets, such as closing a file under
`peak-usage`, has no default implementation, and a run stops at its first
call. See
[`examples/semidirect/peak_usage.tpe`](examples/semidirect/peak_usage.tpe),
[`examples/semidirect/time_windows.tpe`](examples/semidirect/time_windows.tpe)
and [`examples/semidirect/mode_costs.tpe`](examples/semidirect/mode_costs.tpe).

### Operation counts

- `counts-upper-bound`: entries `(A, n)`, at most `n` calls of the operation
  `A`, `n` possibly `∞`; sequencing adds the calls of each operation, and
  delays count none. An operation not listed is bounded by `0`, or by the entry
  `(_, n)`, and a plain `n` bounds every operation: `((Auth, 1), (Send, 3))`
  allows one `Auth`, three `Send` and nothing else. An operation counts itself,
  e.g. `operation Send : int ~> unit # (Send, 1)`. See
  [`examples/counts/rate_limits.tpe`](examples/counts/rate_limits.tpe).

## Temporal resources

A value of the modal type `[rho]a` is an `a`-typed resource that may be used
only once the grade `rho` has accumulated since it was created.

### Boxes and unboxing

`box rho e` creates a resource of type `[rho]a`; `e` is typed in the future in
which `rho` has accumulated. `unbox e` opens a resource `e : [rho]a`, and is
allowed only if the grade accumulated since boxing is a sub-grade of `rho`.
Under `time-lower-bound`,

```
run
  box 5 (10, 10) as b in
  delay 4;
  unbox b as (l, r) in l + r
```

is rejected, since four steps is not a sub-grade of five:

    Variable `b` is unboxed with grade `4` accumulated since it was bound,
    which is not below its box grade `5`
      Note: the resource inequality `4 >= 5` does not hold

See [`examples/basics/basic_unbox.tpe`](examples/basics/basic_unbox.tpe).

### Delays

`delay tau` advances the accumulated grade by `tau`; an operation call advances
it by the operation's grade. A function's computation type may be annotated,
`let f () : int # 3 = ...`; the body's grade must be a sub-grade of the
annotation. See [`examples/basics/delay.tpe`](examples/basics/delay.tpe).

## Eternal types

A type is *eternal* if its values stay valid however much grade accumulates.
Base types, and tuples and algebraic types built from eternal types, are
eternal; function, handler and box types are not. A local variable of a
non-eternal type may be used only while the grade accumulated since its binding
is a sub-grade of the unit. Under `time-lower-bound` and `traces-lower-bound`
this always holds; under the other monoids such a variable must be used before
any delay or operation call.

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
timed-trace and cost-model monoids, an *atomic* operation, graded by its own
name, also declares its runtime bounds (`within n` abbreviates
`within (n, n)`):

```
operation Tx : string ~> unit # {Tx} within (2, 3)
```

A *compound* operation names other operations in its grade, and its bounds are
computed from theirs: `Send : string ~> unit # {Tx | Tx; Tx}` gets `(2, 6)`.

### Handlers and continuations

```
handle e with
  handler
  | x -> return-case
  | Op p k -> operation-case
```

An operation case receives the argument `p` and the continuation `k`, resumed
with `continue k with v`. Unhandled operations are forwarded. The continuation
is a resource of the operation's grade: resuming it is allowed only once the
case has accumulated a sub-grade of that grade. So under `time-lower-bound`,
`Get () k -> delay 71; continue k with 42` handles `Get # 71`. A case is
checked for every effect its continuation may have; a failure names the
instance:

    Note: the effect inequality `∀ε₀. 0 >= 1 · ε₀` does not hold: for
      `ε₀ = 0` it becomes `0 >= 1`

See [`examples/handlers/handlers_lower_bound.tpe`](examples/handlers/handlers_lower_bound.tpe),
[`examples/handlers/handlers_upper_bound.tpe`](examples/handlers/handlers_upper_bound.tpe)
and [`examples/3dprint/3dprint_handlers.tpe`](examples/3dprint/3dprint_handlers.tpe).

### Contexts of operation cases

An operation case is typed with the top grade `⊤` accumulated for the
variables bound outside it. Under `time-lower-bound` and `traces-lower-bound`
the top is the unit, which restricts nothing. Under the other monoids an outer
variable of non-eternal type, including an outer continuation, cannot be used
in the case, and an outer box can be unboxed only if `⊤` is below its grade. The
case's own `p` and `k`, and top-level definitions, are unaffected. See
[`examples/handlers/handlers_nested.tpe`](examples/handlers/handlers_nested.tpe)
and
[`examples/handlers/handlers_nested_reject.tpe`](examples/handlers/handlers_nested_reject.tpe).

### Default implementations

```
default Heat () = delay 1
```

gives `Heat` a default, run only when a call reaches the top level unhandled.
Where operations declare runtime bounds, only atomic operations have defaults,
and a default's grade must be a sub-grade of `{lo}` under lower bounds, `{hi}`
under upper bounds, and `({lo}, {hi})` under intervals. Elsewhere it must be a
sub-grade of the operation's grade.
See [`examples/3dprint/3dprint_traces.tpe`](examples/3dprint/3dprint_traces.tpe).

## Type inference

Types, grades and effects are inferred in the style of HM(X) (Odersky,
Sulzmann and Wehr, TAPOS 1999). Types are
compared by subtyping: functions are contravariant in the argument and
covariant in the result and effect, and a box `[rho]a` is contravariant in
`rho`. Top-level `let` definitions are generalised to qualified schemes,

    ∀ α ρ₀ ε₀. Q ∧ R ⇒ A

where `Q` constrains the type, resource (`ρ`) and effect (`ε`) variables, `R`
lists the conditions of operation cases that must hold for every effect of
their continuations (printed as `∀ε. …`), and `∣ε∣` is the resource grade
accumulated while `ε` runs. `--debug` prints the
schemes. Under `time-upper-bound`, the standard library's
`compose f g x = f (g x)` has

    ∀ α β γ ε₀. (α → β # ε₀) → (γ → α # 0) → γ → β # ε₀ # 0 # 0

where `g` takes no time, since the non-eternal `f` is used after it: the
qualifier `∣ε₁∣ ≾ 0` on the effect `ε₁` of `g` leaves `ε₁` no value but the
least, `0`, which the scheme puts in its place. A qualifier is checked at
every use of the definition.

Under `time-lower-bound`, with `operation Op : unit ~> unit # 1`, the handler

    let via f = handler | x -> x | Op () k -> f (); continue k with ()

has

    ∀ α β ε₀ ε₁. ∣ε₀∣ ≾ 1 ∧ (∀ε₂ (Op). ε₂ · ε₀ ≾ 1 · ε₂) ⇒ (unit → α # ε₀) → β # ε₁ ⇒ β # 0 # 0

where `R`, `∀ε₂ (Op). ε₂ · ε₀ ≾ 1 · ε₂`, is the condition of the case for `Op`
that must hold for every effect `ε₂` of `k`: the case, `f` followed by `k`,
takes at least the time of `Op` followed by `k`. A `run` must establish every such condition: one that the
typechecker can neither derive nor refute rejects it. Under the time grades,
the security levels and their products, a condition in the effect of a single
continuation is always decided; under the trace grades it may not be.

### Sub-effecting

A computation may be used where one of a super-grade is expected, and an
annotation is an upper bound. Under `time-upper-bound`,

```
let apply (f : unit -> int # 2) = f ()
let slow () = delay 1; 3
let branch c = if c then delay 1 else delay 2
```

`apply slow` is accepted, `unit → int # 1` being a subtype of
`unit → int # 2`, and `branch` has the type `bool → unit # 2`. A box type is
contravariant in its grade: under `time-lower-bound`, a `[2]int` is accepted
where a `[3]int` is expected, a `[4]int` is not.

Limits:

- type-constructor arguments and handler inputs are compared by equality: a
  `(unit -> int # 1) list` is not accepted where a `(unit -> int # 2) list` is
  expected, although `[slow]` has the scheme
  `∀ ε₀. 1 ≾ ε₀ ⇒ (unit → int # ε₀) list` and is accepted at both;
- local `let` definitions are not generalised;
- the continuation effect of an operation case is rigid (see
  [Handlers and continuations](#handlers-and-continuations));
- satisfiability of a qualifier is decided provisionally: a definition is
  rejected only when its qualifier is refuted, and each use checks it; a `run`
  must establish its conditions `R`.

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