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
module AtMost :
  Grade.S
    with type t = TimeGrades.UpperBound.t GradeConstructions.Indexed.t
     and type Delay.t = Delay.Nat.t

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
module AtLeast :
  Grade.S
    with type t = TimeGrades.LowerBound.t GradeConstructions.Indexed.t
     and type Delay.t = Delay.Nat.t
