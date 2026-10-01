(** The regular trace grades of timed operations over rational delays: the timed
    regular languages of {!RegularTraceGradeRational}, ordered as the trace
    grades of {!TimedTraceGrades} order finite sets of traces, trading time
    against operations at their declared running-time bounds, which may be
    fractional.

    {2 Orders}

    A trace is a timed word ({!DelayAutomaton}): operations and non-negative
    rational delays, adjacent delays added. The orders on single traces are
    allowance and coverage, as characterised in {!DelayTimedClosure}. A grade is
    ordered below another through the closure of the greater one:
    - upper bounds, ["regex-timed-upper-bound-rational-symbolic"]: [ρ ≾ ρ'] iff
      every trace of [ρ] is permitted by some trace of [ρ'], i.e. [ρ ⊆ ↓ρ'],
      operations counting at their upper running-time bound [hi];
    - lower bounds, ["regex-timed-lower-bound-rational-symbolic"]: [ρ ≾ ρ'] iff
      every trace of [ρ] covers some trace of [ρ'], i.e. [ρ ⊆ ↑ρ'], operations
      counting at their lower running-time bound [lo];
    - intervals, ["regex-timed-interval-rational-symbolic"]: closed intervals of
      a lower and an upper bound, compared componentwise.

    Both are preorders, [equal] being mutual [≾]: if [Read] declares
    [within [1/2, 3/2]], then [{Read} ≾ {3/2}] but not conversely under the
    upper order, and [{Read | 1/2} ≡ {1/2}] under the lower order. Products and
    joins are those of languages, monotone in the orders. The orders are exact
    over the rationals: if [A] takes [1] under the upper order,
    [{(0, 1); A; (0, 1)}] is below [{3}] and below no [{q}] with [q < 3], its
    delays coming arbitrarily close to [1]. A running time is the extremal value
    of an end of the running-time bounds, attained iff the end is closed, and a
    trace is permitted, or covers, iff it does at every duration of its
    operations: if [A] declares [within \[1, 2)], then [{A} ≾ {\[0, 2)}] under
    the upper order, which fails for [within [1, 2]]. The closures are not timed
    regular languages, and a grade is printed as it was written, not as its
    closure.

    {2 Closed world}

    As for {!RegularTimedTraceGrades}: the operations of a comparison are those
    the whole program declares with running-time bounds and the names the grades
    compared mention; the catch-all [_] stands for each declared operation a
    grade does not name, and for every positive delay. A grade must denote at
    least one trace over them ({!Grade.S.inhabited}). The unit [{0}] is least
    under the upper order.

    {2 Grades}

    The literals, the unit [{0}], the product, the join, [of_delay] and the
    printing are those of {!RegularTraceGradeRational}: timed regular
    expressions with rational delays, the intervals of delays such as [\[0, q)]
    and [(q, ∞)], [_], intersection and complement over all timed words, a
    number [q] abbreviating [{q}] and [⊤] the language of all traces, which is
    the unit [{0}] under the lower order. The upper order has [⊤] as its top and
    its unit least; the lower order has the unit as its top. The running-time
    bounds implied by a grade are the infimum of the weights of its lower-bound
    traces, at [lo], and the supremum of those of its upper-bound traces, at
    [hi], each attained or not, [None] if the latter is unbounded; an
    operation's time shadow [of_bounds (lo, hi)] is [{lo}], or [{(lo, ∞)}] if
    [lo] is open, under the lower order, and [{hi}], or [{\[0, hi)}] if [hi] is
    open, under the upper. A counterexample to [ρ ≾ ρ'] is the grade of a trace
    of [ρ] outside the closure of [ρ'] with the fewest operations, each delay
    close to the extremal delay of its set, in which a name stands for itself.
    The witnesses of a closed condition are its constants and their pairwise
    products ({!Grade.sampled}), which are not complete.

    {2 Decisions}

    The operations of a comparison are the names the grades mention and, of the
    declared operations the grades do not name, the least of each running time,
    which stands for the others of its running time: no grade tells them apart.
    [ρ ≾ ρ'] is decided by {!DelayTimedClosure.allowance} under the upper order
    and {!DelayTimedClosure.coverage} under the lower order, on the automata of
    the grades; there is nothing to decide if the grades are the same language
    or [ρ'] is the top. A grade is the top if its representation is that of the
    top and otherwise iff the order decides [⊤ ≾ ρ]. *)

(** Lower bounds, in the coverage order at [lo]. *)
module Lower :
  Grade.S
    with type t = RegularTraceGradeRational.t
     and type Delay.t = Delay.Rational.t

(** Upper bounds, in the allowance order at [hi]. *)
module Upper :
  Grade.S
    with type t = RegularTraceGradeRational.t
     and type Delay.t = Delay.Rational.t

(** Closed intervals of a lower and an upper bound, compared componentwise,
    written [[{...}, {...}]], and [\[{...}, ∞)] with the upper bound [⊤]; a
    brace literal [{...}] abbreviates the interval of a language with itself, a
    number [q] the interval [[{q}, {q}]] and [[q, r]] the interval [[{q}, {r}]].
    An open numeric endpoint is a set of delays: [(q, r)], also written as a
    pair, is [\[{(q, ∞)}, {[0, r)}]], and so on for the half-open intervals. *)
module Interval :
  Grade.S
    with type t = RegularTraceGradeRational.t * RegularTraceGradeRational.t
     and type Delay.t = Delay.Rational.t
