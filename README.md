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

Tested to work with OCaml >= 5.0. Install the dependencies and build:

    opam install --deps-only --with-dev-setup .
    make

`make test` runs the test suite, and `make clean` removes the build.

There are two ways to run programs:

- **Web interface**, at `web/index.html` after building, or online at
  <https://danel.ahman.ee/tempore-lang/>. Load a built-in example or type a
  program, check whether the example typechecks, and if it does, step through
  its reductions one by one while watching the resource state evolve.

- **Command line**:

      ./tempore file1.tpe file2.tpe ...

  loads all listed files and runs every `run` command, printing each run's
  result and final resource state.

  Options: `--grades <grades>` selects the grades (see below),
  `--typecheck-only` typechecks the files without running them, `--no-stdlib`
  skips the standard library, and `--debug` also prints the typing context.

The [`examples/`](examples/) directory contains the programs available in the
web interface; each also starts with listing the command that runs it in CLI.

## Grading monoids

Resource usage is measured in a grading monoid (an ordered monoid with some
additional structure). The monoid is not part of a source file but chosen when
the program is run: with `--grades` on the command line, e.g.

    ./tempore --grades time-interval examples/time_intervals.tpe

or with the **Grades** selector in the web interface, which switches
its value automatically when a built-in example is loaded. The default grade
monoid is `time-lower-bound`. Currently, nine monoids are available to choose.

All monoids share one syntax of grade literals, and each reads the literals it
understands; a literal the chosen monoid does not understand is a syntax error,
which names the monoids that do. The greatest grade of every monoid is written
`⊤` (ASCII `top`).

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
  [`examples/time_intervals.tpe`](examples/time_intervals.tpe).

All three variants of time bounds are inclusive on the values they carry, e.g.,
while intervals are written as `(n,m)`, they should be read as `[n,m]`.

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
  [`examples/traces_lower.tpe`](examples/traces_lower.tpe).
- **`traces-upper-bound`** — the runs a computation is *allowed*. `rho`
  is a sub-grade of `rho'` when every run of `rho` fits inside some run of
  `rho'`: a delay in `rho'` pays for operations of `rho` at their `hi`, but
  waiting never counts as performing an operation the bound asks for. `{0}` is
  the minimum of the order; its top is a separate point `⊤`, permitting any
  run. See
  [`examples/traces_upper.tpe`](examples/traces_upper.tpe).
- **`traces-interval`** — pairs `({...}, {...})` of a lower bound
  (coverage order, reading `lo`) and an upper bound (allowance order, reading
  `hi`), compared componentwise. `{...}` abbreviates the pair of a set with
  itself, `n` abbreviates `({n}, {n})`, and `(n, m)` abbreviates
  `({n}, {m})`; either component may be `⊤`, the top of its order.
  `({0}, {0})` is neither the top nor the minimum, and the top is `({0}, ⊤)`.
  See [`examples/traces_intervals.tpe`](examples/traces_intervals.tpe).

The sets of traces are written in a brace literal `{...}`, which is a regular
expression over operation names and delays: `r; s` concatenates, `r | s` is a
union, and parentheses group, so that `{(Read | 2); Send}` is `{Read; Send | 2;
Send}`. Repetition `r*`, intersection `r & s`, complement `~r` and the wildcard
`_`, standing for any single operation, are also part of the syntax, but no
monoid accepts them yet.

One monoid grades resources and computations by *security levels*, and two
more pair it with time:

- **`security-levels`** — the two levels `Low` and `High`, with `Low` below
  `High`. The grade of a computation is the highest level it touches: both the
  product and the join of two levels are the higher of them, `Low` is the unit
  and the minimum, and `High` the top. Delays touch no level, so `delay n` has
  the grade `Low`. A resource boxed at a level may be unboxed only while the
  level has not risen above it since boxing: a value boxed at `Low` is out of
  reach once an operation of grade `High` has run. See
  [`examples/security_levels.tpe`](examples/security_levels.tpe).
- **`time-lower-bound-levels`** — pairs `(n, l)` of a `time-lower-bound`
  grade and a level: at least `n` ticks, touching nothing above `l`. A box at
  `(3, Low)` is an embargo with a taint check, claimable after at least three
  ticks and only while nothing `High` has run. See
  [`examples/time_lower_levels.tpe`](examples/time_lower_levels.tpe).
- **`time-upper-bound-levels`** — pairs `(n, l)` of a `time-upper-bound`
  grade and a level: at most `n` ticks, touching nothing above `l`. A box at
  `(5, Low)` is an expiring capability, usable within five ticks and only while
  nothing `High` has run; `(∞, Low)` never expires. See
  [`examples/time_upper_levels.tpe`](examples/time_upper_levels.tpe).

The last two are instances of a general *product* of two monoids: pairs of
grades, multiplied, joined and compared componentwise, with the pair of the
units as the unit and the pair of the tops, written `⊤`, as the top; a delay of
`n` ticks is graded in both components at once. The unit is the minimum, and
the product commutative, when they are so in both components.

## Temporal resources

A value of the modal type `[rho]a` is an `a`-typed resource that may be used
only once the grade `rho` has been accumulated since it was created: an amount
of time, a sequence of operations, or whatever the chosen monoid measures.

- `box rho e` creates a resource of type `[rho]a`. The expression `e` is typed
  in the hypothetical future in which the accumulated grade has grown by `rho`.
- `unbox e` opens a resource `e : [rho]a`, yielding an `a`. It is allowed only
  if the grade accumulated since `e` was boxed is a sub-grade of `rho`: at
  least `rho` ticks under the lower-bound monoids, at most `rho` under the
  upper-bound ones, a run that covers or fits inside `rho` under the trace
  monoids, and a level no higher than `rho` under `security-levels`; the
  products check both components.
- `delay tau` advances the accumulated grade by `tau`. Operation calls (below)
  advance it by the grade of the operation.

See [`examples/delay.tpe`](examples/delay.tpe).

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
resource grade that elapses while `g` runs. So `keep 5` is accepted and
`keep (fun () -> ())` is rejected:

    `unit → unit` is not eternal, but `keep` needs the type of `x` to be
    eternal
      Note: the resource inequality `1 <= 0` does not hold

while `after (fun () -> delay 2) 5` is accepted because `5` is eternal, and
`after (fun () -> ()) (fun () -> ())` because `g` takes no time. A variable
captured in an operation case is constrained in the same way, the top grade
having elapsed for it (see [Contexts of operation
cases](#contexts-of-operation-cases)). See
[`examples/eternal_types.tpe`](examples/eternal_types.tpe) and the end of
[`examples/3dprint_traces.tpe`](examples/3dprint_traces.tpe).

A type definition can be declared non-eternal regardless of its structure:

```
noneternal type epoxy = Epoxy
```

This makes `epoxy`, and every type containing it, non-eternal. The keyword
prefixes a whole `type ... and ...` group. It is allowed on algebraic types
only, since type aliases are unfolded before eternality is checked.

## Algebraic effects and effect handlers

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
are declared, since the grade already is the bound.

An operation is called with

```
perform OperationName argument
```

which returns a `result-type` value and advances the accumulated grade by the
operation's grade.

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
case has accumulated a sub-grade of that grade. So `PrintModel : model ~> print
# {Heat; Extrude; Cool}` may be handled by performing `Heat`, `Extrude` and
`Cool` in that order and continuing, while another order is rejected:

    Variable `k` is unboxed after grade `{Cool; Extrude; Heat}` has elapsed,
    which does not match its box grade `{Heat; Extrude; Cool}`
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

    Variable `k` is unboxed after grade `∣ε₀∣` has elapsed, which does not
    match its box grade `1`
      Note: the resource inequality `∀ε₀. ∣ε₀∣ <= 1` does not hold: for
        `ε₀ = ∞` it becomes `∞ <= 1`

Under a lower bound it is accepted once the case has waited for the
operation's grade, `Op p k -> delay 1; let a = continue k with () in continue
k with ()`, as the grade elapsed before the second resumption only grows.

### Contexts of operation cases

An operation case runs at a time the handler does not fix: the call may come
at any point of the handled computation, and the case must be well-typed for
every grade its continuation may have. So a case is typed in its context
*locked* at the top grade `⊤`: to the variables bound outside the case, the
top grade has elapsed by the time the case runs. By the usual rules, such a
variable may then be used in the case only if its type is eternal or `⊤` is
below the unit, and an outer box may be unboxed in the case only if `⊤` is
below its grade.

Under `time-lower-bound` and `traces-lower-bound` the top is the unit, so the
lock restricts nothing: a case may use a function, a non-eternal value or an
outer continuation bound outside it, and unbox any outer box. Under the other
monoids a variable of non-eternal type bound outside the case is rejected
there, whatever the grades are; under `time-upper-bound`:

    Variable `f` has type `unit → int`, which is not eternal, so it cannot be
    used in the case for `Op`: the case runs at a time the handler does not fix
      Note: the resource inequality `∞ <= 0` does not hold

and an outer box of grade `3` cannot be unboxed in a case:

    Variable `b` is unboxed after grade `∞` has elapsed, which does not match
    its box grade `3`
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
[`examples/handlers_lower_bound.tpe`](examples/handlers_lower_bound.tpe),
[`examples/handlers_upper_bound.tpe`](examples/handlers_upper_bound.tpe),
[`examples/handlers_nested.tpe`](examples/handlers_nested.tpe),
[`examples/handlers_nested_reject.tpe`](examples/handlers_nested_reject.tpe)
and [`examples/3dprint_handlers.tpe`](examples/3dprint_handlers.tpe).

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
checked against the operation's grade. The grade itself cannot be required,
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

- **Subtyping.** Types are compared by subtyping rather than by equality. A
  function type is contravariant in its argument and covariant in its result
  and effect, and a box type `[rho]a` is contravariant in its grade: a box
  claimable after `rho` may be used where one claimable after a sub-grade of
  `rho` is expected. Subtyping preserves the shape of types, and the arguments
  of type constructors such as `list` are compared for equality.
- **Resource and effect grades.** Box types and the grades elapsed in a
  context are *resource* grades; computations and operation signatures carry
  *effect* grades. The two sorts are related by a grade system, which maps an
  effect grade to the resource grade that elapses while it runs. At present
  each grading monoid provides both sorts, related by the identity.
- **Constraints.** Besides subtyping, a program asks for orderings between
  grades, for types to be eternal, and, for a variable used after some grade
  `rho` has elapsed, that its type is eternal or `rho` is below the unit. The
  effect of the continuation of a handler's operation case is unknown to the
  case, so the case is checked for every such effect.
- **Schemes.** Only top-level `let` definitions are generalised; a local
  `let` has a monomorphic type. The scheme of a top-level definition is
  qualified, `∀ α ρ₀ ε₀. Q ∧ R ⇒ A`: `Q` are the constraints left on its
  unknowns and `R` conditions of operation cases that must hold for every
  effect of their continuations. Every use of the definition instantiates the
  scheme and checks its qualifier. Schemes are simplified before they are
  reported: redundant constraints are dropped, and an unknown the type does not
  need is replaced by its bound. For example, under `time-upper-bound` the
  standard library's `compose f g x = f (g x)` has the scheme

      ∀ α β γ ε₀ ε₁. ∣ε₁∣ ≾ 0 ⇒ (α → β # ε₀) → (γ → α # ε₁) → γ → β # ε₁ · ε₀ # 0 # 0

  where `ε₁ · ε₀` is `g`'s effect followed by `f`'s, and `∣ε₁∣ ≾ 0` asks `g`
  to take no time, as the non-eternal `f` is used after it has run.
- **Satisfiability.** Whether the qualifier of a definition can be met is
  decided provisionally: a closed instance of it is searched for, and the
  definition is rejected only when the search refutes the qualifier. When the
  search neither finds nor refutes an instance, the definition is accepted, and
  its uses report any failure of the qualifier instantiated there.

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

Agentic AI tools (from the Claude family) have been used to develop parts of
this prototype implementation.