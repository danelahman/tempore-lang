(** The order of the timed grades with interval letters, decided on the
    expressions of {!IntervalRegex}.

    [x ≾ y] iff every exact word of [x] fits some exact word of [y]: the
    operations of the word of [y] occur in that of [x] at the same time spans,
    in order; a strict wait of [y] holds waiting only; a stretch of [y] holds
    the items of [x] that its set admits, an item overlapping several stretches
    admitted by each; running times are positive. On one-sided intervals the
    closures are monotone in every length, so that a word of [x] is read at its
    extremal lengths: its suprema on the upper side, its infima on the lower
    side, where a stretch that may have length [0] is read both as absent and as
    positive.

    {2 Decision}

    Breadth-first search of the pairs of a node of the automaton of partial
    derivatives of [x] and a configuration of the reader of [y] (described in
    the implementation) for a final node at which the reader rejects. The
    automata are linear in the counts of bounded repetitions, whose lengths are
    not unrolled. The reader's configurations and transitions are tabulated per
    world and bound, and the verdicts per world and pair of grades, in
    module-level tables that only ever grow. *)

open IntervalRegex

type world
(** The operations of a comparison: classes of names, each with its running time
    read at the end of the side. *)

val world : (string * cut) list -> world
(** [world classes] is the world of the representatives [classes], each with its
    running time, hash-consed. *)

(** A step of a counterexample: an operation, or a stretch of an exact length
    with its set. *)
type concrete = Name of string | Length of Ops.t * Rational.t

module Make
    (E : IntervalRegex.S)
    (_ : sig
      val whole : bool
      (** Whether the lengths are whole time steps. *)
    end) : sig
  val leq : world -> E.t -> E.t -> bool
  (** [leq world x y] decides [x ≾ y] over [world]. *)

  val counterexample : world -> E.t -> E.t -> concrete list option
  (** [counterexample world x y] is [None] if [x ≾ y], and otherwise a word of
      [x], its lengths exact, that fits no word of [y]: a shortest path of the
      search, each length chosen close enough to its end. *)

  val max_weight : world -> E.t -> cut option
  (** [max_weight world e] is the supremum of the durations of the words of [e],
      [None] if it has none over [world]: infinite on the lower side where [e]
      has a stretch. *)

  val min_weight : world -> E.t -> cut option
  (** [min_weight world e] is the infimum of the durations of the words of [e],
      [None] if it has none over [world]: its stretches of length [0] on the
      upper side. *)

  val inhabited : world -> E.t -> bool
  (** [inhabited world e] is whether [e] has a word over [world]. *)
end
