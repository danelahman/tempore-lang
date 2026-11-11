(** Time with an energy budget: how long a computation takes and how much energy
    it draws. *)

(** The energy budgets, ["energy"]: at most [e] units of energy, the upper
    bounds {!TimeGrades.UpperBound} over delays that draw none
    ({!GradeConstructions.Untimed}). *)
module Energy :
  Grade.S with type t = TimeGrades.UpperBound.t and type Delay.t = Delay.Nat.t

(** The product of [time-upper-bound] and {!Energy},
    ["time-upper-bound-energy"]: [(t, e)] is "at most [t] time steps, drawing at
    most [e] units of energy".

    - Sequencing adds both components, and the order, the join, the top [(∞, ∞)]
      and the closure are componentwise; the unit [(0, 0)] is least, and [mul]
      commutes.
    - A delay [d] is [(d, 0)], and the time shadow of the running-time bounds
      [(lo, hi)] is [(hi, 0)].
    - The durations of [(t, e)] are those of [t], [[0, t]], so that the grade of
      an operation gives its running time as under [time-upper-bound], and its
      energy draw.
    - Each component is written as a [time-upper-bound] grade, [n], [[0, n]],
      [\[0, n)] or [∞]; the top is also written [⊤].
    - No counterexample is offered, and the witnesses are complete. *)
module TimeUpperBoundEnergy :
  Grade.S
    with type t = TimeGrades.UpperBound.t * TimeGrades.UpperBound.t
     and type Delay.t = Delay.Nat.t
