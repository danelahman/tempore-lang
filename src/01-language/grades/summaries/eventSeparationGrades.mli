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
    - [Silent d]: it performs no [X] and takes the time [d];
    - [Active (a, G, b)]: it takes the time [a] before the first [X], the times
      [G] between the starts of consecutive [X]s, none with one [X], and the
      time [b] from the start of the last [X] to its end.

    Sequencing is the longest-gap monoid: [Silent d · Silent d'] is
    [Silent (d + d')], [Silent d · Active (a, G, b)] is [Active (d + a, G, b)],
    [Active (a, G, b) · Silent d] is [Active (a, G, b + d)], and
    [Active (a, G, b) · Active (a', G', b')] is
    [Active (a, G ∪ G' ∪ {b + a'}, b')], the tail of the first part and the lead
    of the second forming a gap.

    A grade over-approximates a set of computations by, for each name, an
    interval of their silent durations or none, and a triple of intervals
    containing their leads, their gaps (or none, without gaps) and their tails,
    or none; and by an interval of their total durations. Products and joins are
    taken case by case with the Minkowski sums and the hulls of intervals; the
    sums distribute over the hulls, so that the product is associative and
    distributes over the join. The order is inclusion, component by component
    and name by name. The unit is silent for every name, of duration [0]; it is
    not least, and the product does not commute. The top bounds nothing.

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
    - A tuple of entries of either form, each name listed once, and at most one
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

    {2 Printing}

    A term built from literals is printed as one: a sequence or a union of
    occurrences and delays as a brace literal, a delay as a number or an
    interval, and a specification as a tuple of entries, in the short form where
    it is one. A product with a specification is printed with [·] and a join
    with [⊔]. A summary that is no specification, such as a counterexample, is
    printed as [⟨X: silent S, active (L, G, T); _: ...; total D⟩], an entry by
    name and one for the names not listed, [_], an absent case being omitted, no
    gaps written [∅] and the total omitted where it is [\[0, ∞)]. These forms do
    not read back.

    {2 Running times, durations and inhabitation}

    [needs_op_bounds] holds: an atomic operation declares its running-time
    bounds, its grade being its occurrence [{X}]. [duration_bounds] is the
    interval of the total durations, [\[0, ∞)] where a specification bounds
    none, and [of_bounds b] the delay of a duration in [b]. [inhabited] is
    decided name by name: some silent duration, or the shortest active
    computation, lies within the total durations.

    {2 Counterexamples and witnesses}

    A failure of the order is witnessed by the summary of the lesser grade with,
    at the first name where it fails, the failing case alone. The witnesses of a
    condition are its constants and their pairwise products ({!Grade.sampled}),
    and are partial. *)

module Summary : sig
  type active = {
    lead : DurationIntervals.t;
    gaps : DurationIntervals.t option;
    tail : DurationIntervals.t;
  }
  (** The active computations of a name: intervals of the leads, of the gaps,
      [None] without gaps, and of the tails. *)

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
