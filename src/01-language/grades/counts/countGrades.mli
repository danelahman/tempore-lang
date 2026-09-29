(** The operation-count grades: how often a computation performs each operation.

    A grade maps the names of the operations to numbers of calls,
    {!GradeConstructions.Indexed.OfGrade} over the time grades, sequencing
    adding the numbers of each operation. An operation counts itself in its
    grade, e.g. [(Send, 1)], and delays count nothing. *)

(** The upper bounds on the counts over any delays [D], as {!UpperBound}. *)
module Make (D : Delay.S) :
  Grade.S
    with type t = TimeGrades.UpperBound.t GradeConstructions.Indexed.t
     and type Delay.t = D.t

(** The upper bounds on the counts, ["counts-upper-bound"], over {!Delay.Nat}:
    each operation performed at most the number of times its entry gives, the
    maps to {!TimeGrades.UpperBound} ordered by [<=] name by name.

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
module UpperBound :
  Grade.S
    with type t = TimeGrades.UpperBound.t GradeConstructions.Indexed.t
     and type Delay.t = Delay.Nat.t
