(** Run consistency of the intervals of the timed grades with interval letters:
    whether some run fits an exact word of a lower bound and an exact word of an
    upper bound.

    A run is a sequence of operations, each with an exact running time within
    its bounds, and strict waits. It fits an exact word when the operations of
    the word occur in it at the same time spans, in order, and every other
    operation of the run lies in stretches of the word whose sets contain it,
    the strict waits of the word holding waiting only (the order of
    {!IntervalClosure}). The sets of exact words of both bounds are closed
    downwards, so an interval [[L, U]] is consistent iff the two sets meet, iff
    some run fits a word of each.

    Consistency concerns words, not programs: with [A] within [[1, 3]], the
    interval [[{(≥2 & A)}, {A}]] is consistent, by the run performing [A] for
    [2], although no computation performing [A] once has this grade, since [A]
    may run for [1].

    {2 Decision}

    The words of the two bounds are laid on one timeline, which is reachability
    in a timed automaton with two clocks (Alur and Dill, "A theory of timed
    automata", 1994), each measuring the letter of one bound in progress. Its
    locations pair the nodes of the automata of the partial derivatives of the
    bounds ({!IntervalClosure.graph}), each with the letter in progress, if any,
    and the class of its operation. A letter of one bound begins only where the
    letter of the other bound in progress admits it: an operation lies in
    stretches whose sets contain it, or is matched by the same operation over
    the same span; two stretches overlap freely. A stretch ends within its
    interval, an operation within its running time, and a stretch whose interval
    contains [0] may be passed at length [0]. Time passes only while both bounds
    are inside a letter.

    The search is a forward exploration of zones, represented as
    difference-bound matrices of the two clocks (Dill, "Timing assumptions and
    verification of finite-state concurrent systems", 1989), with inclusion
    subsumption and the extrapolation of each clock by its greatest constant
    (Bengtsson and Yi, "Timed automata: semantics, algorithms and tools", 2004),
    sound and complete for reachability of automata without diagonal guards.
    Over whole time steps every guard is non-strict with an integer constant, so
    a reachable location is reached at whole times (digitization; Henzinger,
    Manna and Pnueli, "What good are digital clocks?", 1992), and the run found
    has whole lengths. A run is read off the path found by fixing the times of
    its transitions one after another in their difference-bound matrix. *)

open IntervalRegex

type world
(** The classes of operations of a decision, each with the lower and the upper
    end of its running time. *)

val world : (string * (cut * cut)) list -> world
(** [world classes] is the world of the representatives [classes], each with the
    lower end of its running time, [Finite (q, attained)], and the upper one,
    [Finite (q, attained)] or [Infinite], hash-consed. *)

val id : world -> int
(** [id w] is the number of [w]. *)

(** An item of a run: an operation with its running time, or a strict wait. *)
type item = Op of string * Rational.t | Wait of Rational.t

val consistent :
  whole:bool ->
  world ->
  lower:IntervalClosure.graph ->
  upper:IntervalClosure.graph ->
  bool
(** [consistent ~whole world ~lower ~upper] is whether some run fits a word of
    the lower bound of the automaton [lower] and a word of the upper bound of
    [upper], over whole time steps if [whole]: the reachability search alone,
    without reading off a run. *)

val witness :
  whole:bool ->
  world ->
  lower:IntervalClosure.graph ->
  upper:IntervalClosure.graph ->
  item list option
(** [witness ~whole world ~lower ~upper] is a run fitting a word of the lower
    bound of the automaton [lower] and a word of the upper bound of [upper],
    over whole time steps if [whole], and [None] if there is none. *)
