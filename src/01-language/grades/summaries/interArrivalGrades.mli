(** The inter-arrival grade, ["inter-arrival"]: how often each operation recurs,
    bounding the time between the occurrences of an operation, at most and at
    least. It generalises the minimum inter-arrival times of sporadic tasks
    (Mok, PhD thesis, MIT, 1983) and the minimum and maximum event distances of
    event models (Henia et al., IEE Proc. Comput. Digit. Tech. 152, 2005).

    {2 Summaries}

    An operation occurs at its start, and takes a time within its running-time
    bounds [within [lo, hi]]; delays are non-negative rationals. For a name [X],
    a computation has one of two summaries:
    - [Silent d]: it performs no [X] and takes the time [d], [0] occurrences;
    - [Active (k, a, G, b)]: it performs [k ≥ 1] [X]s, takes the time [a] before
      the first, the times [G] between the starts of consecutive [X]s, none with
      one [X], and the time [b] from the start of the last [X] to its end.

    Sequencing is the longest-gap monoid with the counts added:
    [Silent d · Silent d'] is [Silent (d + d')],
    [Silent d · Active (k, a, G, b)] is [Active (k, d + a, G, b)],
    [Active (k, a, G, b) · Silent d] is [Active (k, a, G, b + d)], and
    [Active (k, a, G, b) · Active (k', a', G', b')] is
    [Active (k + k', a, G ∪ G' ∪ {b + a'}, b')], the tail of the first part and
    the lead time of the second forming a gap.

    A grade over-approximates a set of computations by, for each name, an
    interval of their silent durations or none, and intervals containing their
    counts, natural numbers of at least [1], their lead times, their gaps (or
    none, with one occurrence) and their tails, or none; and by an interval of
    their total durations. Products and joins are taken case by case with the
    Minkowski sums and the hulls of intervals, of durations and of counts; the
    sums distribute over the hulls, so that the product is associative and
    distributes over the join. The order is inclusion, component by component
    and name by name. The unit is silent for every name, of duration [0] and
    count [0]; it is not least, and the product does not commute. The top bounds
    nothing.

    An interval {!DurationIntervals.t} has a finite lower end and possibly an
    infinite upper one, each finite end closed or open.

    {2 Representation}

    The product does not receive the running-time bounds of the operations, so a
    grade is a term of {!SummaryTerms}: occurrences, delays, specifications,
    products, joins and closures, evaluated to its summary under the
    running-time bounds by the order, the equality, [duration_bounds],
    [inhabited] and [counterexample]. A name a term does not mention is silent
    in it, for its whole duration; a name a specification does not mention is
    unconstrained.

    {2 Closure}

    The closure {!Grade.S.plus} of a grade, the least grade above it closed
    under the product, is taken name by name, with the closure of the total
    durations. The closure [i⁺] of an interval [i] has the lower end of [i], and
    the upper end of [i] if [i] is [[0, 0]] and [∞] otherwise. For an entry with
    silent durations [S] (or none), let [Z] be [[0, 0]] if there are none and
    the hull of [[0, 0]] and [S⁺] otherwise, the durations of any number of
    silent parts. The closure of the entry has the silent durations [S⁺] (or
    none), and the closure of its active case [(K, A, G, B)] (or none) is
    [(\[k, ∞), Z + A, G ∪ (B + Z + A), B + Z)], where [k] is the least count of
    [K] and [∪] is the hull, [G] being empty where there are no gaps: any number
    of active parts, the silent parts between and around them added to the lead
    time and the tail, and the tail, a silent part and the lead time of the next
    active part forming a gap.

    The closure preserves the invariants of the summaries: an entry with some
    case, counts of at least [1], and gaps absent exactly where the count is
    [1]. A term containing a fixed summary that violates the first two, which
    the literals do not produce, has no closure ([None]). The closure of a term
    without occurrences is the fixed closure of its summary, that of a delay [i]
    the delay [i⁺]; the closure of any other term is a closure term, evaluated
    to the closure of its summary under the running times.

    {2 Literals}

    - [{X}] is the occurrence of the operation [X], the grade it declares, e.g.
      [operation Beat : unit ~> unit ! {Beat} within [0.1, 0.5]]; a brace
      literal is a sequence [;] and a union [|] of operation names, delays,
      intervals of delays and [skip], the computation without occurrences of
      duration [0], e.g. [{Beat; 2 | Beat; [1, 3]}] or [{Beat | skip}].
    - A number [q] or an interval, e.g. [[1, 2]], [(1/2, 3\]] or the open pair
      [(1, 4)], is a computation without occurrences taking a time in it.
    - [(X, [s, t])] is a specification: consecutive [X]s at least [s] and at
      most [t] apart, and no duration without [X] longer than [t] at the start
      or the end: lead time, tail and silent duration in [[0, t]]. E.g.
      [(Beep, \[2, ∞))] is a rate limit, two [Beep]s at least [2] apart.
    - [(X, lead, gaps, tail)] bounds the three components of the active
      computations, the lead time, the gaps and the tail, by the intervals
      [lead], [gaps] and [tail], and the silent durations by the intersection of
      [lead] and [tail].
    - These two forms state no count: any number of [X]s, spaced as stated. With
      a count [n] first, a natural number or an interval [[n, m]] or [\[n, ∞)]
      of them, [(n, X, ...)] bounds the number of [X]s by [n] as well, its
      silent computations being those of count [0]: [(n, X, gaps)] is the short
      form, [(n, X, lead, tail)] leaves the gaps unconstrained and
      [(n, X, lead, gaps, tail)] is the full form. E.g.
      [(1, Read, [10, 45], [0, 1.5])] is exactly one [Read], started [10] to
      [45] after the start, the end at most [1.5] after it; [(0, Send, \[0, ∞))]
      performs no [Send]. A pair [(n, X)] is rejected, as is an entry of count
      [0] whose lead time and tail do not meet, which admits no computation.
    - A tuple of entries of these forms, each name listed once, and at most one
      interval, the total duration, e.g.
      [((Read, [0, 20]), (Draw, 5), [0, 100])]; the names not listed are
      unconstrained, and an entry [(_, ...)] is rejected. The components of an
      entry are intervals, or numbers for single points.
    - [⊤] (ASCII [top]) is the greatest grade.

    The repetitions, intersections, complements and the catch-all letter of the
    brace literals are rejected.

    {2 Loop invariants}

    The specification [(X, [s, t])] is not closed under sequencing: two
    durations of [t] without [X] may meet, at the end of one part and the start
    of the next. The invariant of a loop whose body starts with [X] and takes at
    most [t] is the full form [(X, [0, 0], [0, t], [0, t])]: no time before the
    first [X], gaps and tail at most [t]; it is closed under sequencing. A rate
    limit [(X, \[s, ∞))] is not closed under sequencing, as the tail of one part
    and the lead time of the next may form a gap shorter than [s]; it is the
    invariant of a loop each of whose rounds that performs [X] takes at least
    [s] from the start of its last [X] to its end.

    Counts add under sequencing, so that an invariant states none, or [\[0, ∞)];
    a count suits a bounded duration, such as the time from a box to its
    unboxing: [(1, X, lead, tail)] is exactly one [X] between them.

    The grade ["at-most-counts"] bounds the numbers of calls from above alone,
    without their times; this one bounds the counts of the occurrences together
    with the times before, between and after them.

    {2 Printing}

    A term built from literals is printed as one: a sequence or a union of
    occurrences and delays as a brace literal, a delay as a number or an
    interval, and a specification as a tuple of entries, in the short form where
    it is one. A product with a specification is printed with [·] and a join
    with [⊔]. The closure of a term [c] is printed as [{r^\[1, ∞)}] where [c] is
    printed as the brace literal [{r}], and as [(c)^\[1, ∞)] otherwise; these
    forms do not read back. A summary that is no specification, such as a
    counterexample, is printed as
    [⟨X: silent S, active (L, G, T); _: ...; total D⟩], an entry by name and one
    for the names not listed, [_], an absent case being omitted, no gaps written
    [∅] and the total omitted where it is [\[0, ∞)]; the count [K] of an active
    case is written first, [active (K, L, G, T)], where it is neither [\[1, ∞)]
    nor [1], which [∅] shows. These forms do not read back. An entry is printed
    in the first of the forms above that denotes it, those without a count
    first, so that an entry without a count prints without one.

    {2 Running times, durations and inhabitation}

    [needs_op_bounds] holds: an atomic operation declares its running-time
    bounds, its grade being its occurrence [{X}]. [duration_bounds] is the
    interval of the total durations, [\[0, ∞)] where a specification bounds
    none, and [of_bounds b] the delay of a duration in [b].

    All entries describe one run and share its total duration. For a name [X] of
    running times [within [lo, hi]], the total durations its entry admits are
    the set [D_X] of the silent durations and of the sums
    [a + g₁ + ... + g_{k-1} + b] of a lead time [a], gaps [gᵢ] and a tail [b] in
    their intervals and a count [k] in its interval, each gap and the tail at
    least [lo]: an occurrence ends before the next one starts and before the
    end. [D_X] is a {!DelaySet}, exact for unbounded counts. [vacuous] gives a
    reason where the total durations of the grade and the sets [D_X] of the
    names listed, and that of the names not listed at any running time, have no
    common element: one of them alone, two of them, or all.

    The check is exact on the shared total duration and on the running time of
    each name, and over-approximates the interleaving of the names: the
    occurrences of different names, sequential and of positive running times,
    are not placed on one timeline, so that e.g.
    [((1, X, [0, 0], [1, 1]), (1, Y, [0, 0], [1, 1]))], which starts both [X]
    and [Y] at [0], is accepted. Deciding the interleaving exactly is a problem
    of sequencing with release times and deadlines, NP-hard in general (M. R.
    Garey and D. S. Johnson, "Computers and Intractability", 1979, problem SS1).

    {2 Counterexamples and witnesses}

    A failure of the order is witnessed by the summary of the lesser grade with,
    at the first failing name having both cases, the failing case alone, and
    otherwise by that summary itself. The witnesses of a condition are its
    constants and their pairwise products ({!Grade.sampled}), and are partial.
*)

module Summary : sig
  type count = { least : int; most : int option }
  (** An interval [[least, most]] of natural numbers, [most] being [None] where
      it is unbounded. *)

  type active = {
    count : count;
    lead : DurationIntervals.t;
    gaps : DurationIntervals.t option;
    tail : DurationIntervals.t;
  }
  (** The active computations of a name: an interval of their numbers of
      occurrences, at least [1], and intervals of the lead times, of the gaps,
      [None] exactly where the count is [1], and of the tails. *)

  type entry = { silent : DurationIntervals.t option; active : active option }
  (** The summary of a name: the silent durations and the active computations,
      either absent. *)

  type t = {
    entries : entry GradeConstructions.Indexed.t;
        (** The summary of each name. *)
    total : DurationIntervals.t;  (** The total durations. *)
  }
  (** The summaries of the computations of a grade. *)

  include SummaryTerms.SUMMARY with type t := t and type op = unit
end

module Terms : module type of SummaryTerms.Make (Summary)
(** The terms over the summaries. *)

include Grade.S with type t = Terms.t and type Delay.t = Delay.Rational.t
