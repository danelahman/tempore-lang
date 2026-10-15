(** The event-separation grade, ["event-separation"]: how often each operation
    recurs, bounding the time between the occurrences of an operation, at most
    and at least, as the minimum and maximum distance functions of event streams
    (K. Richter, "Compositional Scheduling Analysis Using Standard Event
    Models", PhD thesis, TU Braunschweig, 2005) and the bounded recurrence of
    real-time specification patterns (S. Konrad and B. H. C. Cheng, "Real-time
    specification patterns", ICSE 2005) do.

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
    the lead of the second forming a gap.

    A grade over-approximates a set of computations by, for each name, an
    interval of their silent durations or none, and intervals containing their
    counts, natural numbers of at least [1], their leads, their gaps (or none,
    with one occurrence) and their tails, or none; and by an interval of their
    total durations. Products and joins are taken case by case with the
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
    products and joins, evaluated to its summary under the running-time bounds
    by the order, the equality, [duration_bounds], [inhabited] and
    [counterexample]. A name a term does not mention is silent in it, for its
    whole duration; a name a specification does not mention is unconstrained.

    {2 Literals}

    - [{X}] is the occurrence of the operation [X], the grade it declares, e.g.
      [operation Beat : unit ~> unit # {Beat} within [0.1, 0.5]]; a brace
      literal is a sequence [;] and a union [|] of operation names, delays and
      intervals of delays, e.g. [{Beat; 2 | Beat; [1, 3]}].
    - A number [q] or an interval, e.g. [[1, 2]], [(1/2, 3\]] or the open pair
      [(1, 4)], is a computation without occurrences taking a time in it.
    - [(X, [s, t])] is a specification: consecutive [X]s at least [s] and at
      most [t] apart, and no stretch without [X] longer than [t] at the start or
      the end: lead, tail and silent duration in [[0, t]]. E.g.
      [(Beep, \[2, ∞))] is a rate limit, two [Beep]s at least [2] apart.
    - [(X, lead, gaps, tail)] bounds the three components of the active
      computations by the intervals [lead], [gaps] and [tail], and the silent
      durations by the intersection of [lead] and [tail].
    - These two forms state no count: any number of [X]s, spaced as stated. With
      a count [n] first, a natural number or an interval [[n, m]] or [\[n, ∞)]
      of them, [(n, X, ...)] bounds the number of [X]s by [n] as well, its
      silent computations being those of count [0]: [(n, X, gaps)] is the short
      form, [(n, X, lead, tail)] leaves the gaps unconstrained and
      [(n, X, lead, gaps, tail)] is the full form. E.g.
      [(1, Read, [10, 45], [0, 1.5])] is exactly one [Read], started [10] to
      [45] after the start, the end at most [1.5] after it; [(0, Send, \[0, ∞))]
      performs no [Send]. A pair [(n, X)] is rejected, as is an entry of count
      [0] whose lead and tail do not meet, which admits no computation.
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
    stretches of [t] without [X] may meet, at the end of one part and the start
    of the next. The invariant of a loop whose body starts with [X] and takes at
    most [t] is the full form [(X, [0, 0], [0, t], [0, t])]: no time before the
    first [X], gaps and tail at most [t]; it is closed under sequencing. A rate
    limit [(X, \[s, ∞))] is closed under sequencing.

    Counts add under sequencing, so that an invariant states none, or [\[0, ∞)];
    a count suits a bounded stretch, such as the time from a box to its
    unboxing: [(1, X, lead, tail)] is exactly one [X] between them.

    The grade ["counts-upper-bound"] bounds the numbers of calls from above
    alone, without their times; this one bounds the counts of the occurrences
    together with the times before, between and after them.

    {2 Printing}

    A term built from literals is printed as one: a sequence or a union of
    occurrences and delays as a brace literal, a delay as a number or an
    interval, and a specification as a tuple of entries, in the short form where
    it is one. A product with a specification is printed with [·] and a join
    with [⊔]. A summary that is no specification, such as a counterexample, is
    printed as [⟨X: silent S, active (L, G, T); _: ...; total D⟩], an entry by
    name and one for the names not listed, [_], an absent case being omitted, no
    gaps written [∅] and the total omitted where it is [\[0, ∞)]; the count [K]
    of an active case is written first, [active (K, L, G, T)], where it is
    neither [\[1, ∞)] nor [1], which [∅] shows. These forms do not read back. An
    entry is printed in the first of the forms above that denotes it, those
    without a count first, so that an entry without a count prints without one.

    {2 Running times, durations and inhabitation}

    [needs_op_bounds] holds: an atomic operation declares its running-time
    bounds, its grade being its occurrence [{X}]. [duration_bounds] is the
    interval of the total durations, [\[0, ∞)] where a specification bounds
    none, and [of_bounds b] the delay of a duration in [b]. [inhabited] is
    decided name by name: some silent duration, or the hull of the durations
    [lead + (k - 1) gaps + tail] of the active computations over their counts
    [k], meets the total durations.

    {2 Counterexamples and witnesses}

    A failure of the order is witnessed by the summary of the lesser grade with,
    at the first name where it fails, the failing case alone. The witnesses of a
    condition are its constants and their pairwise products ({!Grade.sampled}),
    and are partial. *)

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
      occurrences, at least [1], and intervals of the leads, of the gaps, [None]
      exactly where the count is [1], and of the tails. *)

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
