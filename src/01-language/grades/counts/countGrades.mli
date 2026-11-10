(** The counts of operations: how often a computation performs each operation.

    A grade maps the names of the operations to bounds on their numbers of
    calls, {!GradeConstructions.Indexed.OfGrade} over the time grades whose
    delays are not measured ({!GradeConstructions.Untimed}), sequencing adding
    the numbers of each operation. An operation counts itself in its grade, e.g.
    [(Send, 1)], and delays count nothing. *)

(** The at-most counts, ["at-most-counts"], over {!Delay.Nat}: each operation
    performed at most the number of times its entry gives, the maps to
    {!TimeGrades.UpperBound} ordered by [<=] name by name.

    - An entry [(A, n)] bounds the operation [A] by [n], [n] possibly [∞], an
      entry [(_, n)] every operation not listed, and a plain number [n] every
      operation; an operation neither listed nor bounded by an entry [(_, n)] is
      bounded by [0], so that [((Auth, 1), (Send, 3))] allows at most one
      [Auth], three [Send] and nothing else.
    - The unit, every count [0], is least, and [mul] commutes; the top is [∞]
      for every operation.
    - [of_delay] and [of_bounds] are constantly the unit.
    - No counterexample is offered, and the witnesses are complete, as those of
      {!TimeGrades.UpperBound} are. *)
module AtMost : sig
  include
    Grade.S
      with type t = TimeGrades.UpperBound.t GradeConstructions.Indexed.t
       and type Delay.t = Delay.Nat.t

  val of_counts : (string * int) list -> t
  (** [of_counts counts] bounds each operation of [counts] by its number of
      calls there, the first listed for an operation listed twice, and every
      other operation by [0]. *)
end

(** The at-least counts, ["at-least-counts"], over {!Delay.Nat}: each operation
    performed at least the number of times its entry gives, the maps to
    {!TimeGrades.LowerBound} ordered by [>=] name by name.

    - An entry [(A, n)] guarantees [n] calls of the operation [A], also written
      [[n, ∞)], [(n, ∞)] being [n + 1], an entry [(_, n)] [n] calls of every
      operation not listed, and a plain number [n] [n] calls of every operation;
      an operation neither listed nor counted by an entry [(_, n)] is guaranteed
      no call, so that [((Approve, 2), (Test, 1))] guarantees two [Approve] and
      one [Test].
    - The unit, every count [0], is also the top; it is not least, and [mul]
      commutes. The join is the least count name by name.
    - Every grade is its own closure.
    - [of_delay] and [of_bounds] are constantly the unit.
    - No counterexample is offered, and the witnesses are complete, as those of
      {!TimeGrades.LowerBound} are. *)
module AtLeast : sig
  include
    Grade.S
      with type t = TimeGrades.LowerBound.t GradeConstructions.Indexed.t
       and type Delay.t = Delay.Nat.t

  val of_counts : (string * int) list -> t
  (** [of_counts counts] guarantees each operation of [counts] its number of
      calls there, the first listed for an operation listed twice, and every
      other operation no call. *)
end

(** The at-least counts with a separate greatest point,
    ["at-least-counts-with-top"], over {!Delay.Nat}: the grades of {!AtLeast}
    and [⊤] above them all, absorbing products and joins.

    - The unit, every count [0], is no longer the top: [⊤] is above it, and is
      written [⊤] (ASCII [top]); every other literal is read by {!AtLeast}, the
      unit being written [0].
    - [mul] commutes; every grade is its own closure.
    - [of_delay] and [of_bounds] are constantly the unit.
    - A failure of [⊤ ≾ c] is witnessed by [⊤], and no other counterexample is
      offered; the witnesses are [⊤] and those of {!AtLeast} for the other
      constants, and are not complete. *)
module AtLeastWithTop : sig
  type t =
    | Counted of AtLeast.t  (** the grade of the at-least counts *)
    | Top  (** the greatest grade, printed as [⊤] *)

  include Grade.S with type t := t and type Delay.t = Delay.Nat.t

  val of_counts : (string * int) list -> t
  (** [of_counts counts] is {!AtLeast.of_counts} [counts]. *)
end
