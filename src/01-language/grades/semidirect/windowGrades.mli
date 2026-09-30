(** The time-window grades: the durations of a computation paired with the times
    at which each operation happens.

    A grade [(T, E)] is "takes a number of time steps in [T], and performs each
    operation [A] only at times in [E(A)]", all sets of natural numbers counted
    from the start, [E] mapping the names of the operations to sets of times. An
    operation names itself in its grade, e.g. [(1, (Send, {0}))] for an
    operation [Send] taking one time step and happening at its start. Sequencing
    adds the durations and shifts the later times by the earlier durations:
    [(T, E) · (T', E') = (T + T', E ∪ (T + E'))], [+] adding sets elementwise
    and [∪] and [T + _] taken operation by operation.

    The sets are the regular languages over the letter [tick] alone, a number
    [n] being the word of [n] ticks, in the representation of
    {!RegularTraceGradeDerivative}: [+] is concatenation and [∪] union. *)

(** The durations, ["durations"]: non-empty sets of natural numbers under
    elementwise addition, ordered by inclusion, the join being the union; the
    delays are whole time steps, the unit is [{0}], [of_delay n] is [{n}], and
    the top all natural numbers. Its literals are [n] for [{n}], [[n, m]] for
    the numbers from [n] to [m], [\[n, ∞)] for those from [n] on, an open
    endpoint abbreviating a closed one, [(n, m)] being [[n + 1, m - 1]], and
    brace literals over ticks, [{3 | 5}] being [{3, 5}], in which an interval of
    delays is the numbers in it; a set is printed in the first of these forms
    that denotes it. The witnesses are the constants and their pairwise
    products, and partial. *)
module Durations :
  Grade.S with type t = SymbolicRegex.t and type Delay.t = Delay.Nat.t

module Times : GradeConstructions.SEMILATTICE with type t = SymbolicRegex.t
(** The times, ["times"]: sets of natural numbers ordered by inclusion, the join
    being the union. Its literals are brace literals over ticks. *)

(** The action of the durations [T] on the times [E], adding them elementwise.
*)
module Shift :
  GradeConstructions.ACTION with type m = Durations.t and type n = Times.t

module TimesByName :
  GradeConstructions.SEMILATTICE
    with type t = SymbolicRegex.t GradeConstructions.Indexed.t
(** The times of each operation, by its name:
    {!GradeConstructions.Indexed.OfSemilattice} [(Times)]. *)

(** The action {!Shift} on the times of every operation. *)
module ShiftByName :
  GradeConstructions.ACTION with type m = Durations.t and type n = TimesByName.t

(** The time-window grade, ["time-windows"]: the semidirect product
    {!GradeConstructions.SemiDirect} [(Durations) (TimesByName) (ShiftByName)].

    - The order is componentwise inclusion, so the unit [({0}, ∅)] is not least.
      [mul] does not commute.
    - [of_delay n] is [({n}, ∅)].
    - [of_lit] reads a literal of the durations [T] as [T] with no operation,
      and a tuple [(T, (A, {E_A}), …)] of the durations and entries of
      {!GradeConstructions.Indexed} as [T] with each operation [A] at the times
      [E_A], an entry [(_, {E})] giving the other operations the times [E]; the
      brace literals name no operation, [_] being a single tick. [show] prints
      alike, and the top as [⊤].
    - No counterexample is offered, and the witnesses are partial. *)
module TimeWindows :
  Grade.S
    with type t = Durations.t * TimesByName.t
     and type Delay.t = Delay.Nat.t
