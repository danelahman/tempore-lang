(** The time-window grades: the durations of a computation paired with the times
    at which its windowed operations happen.

    A grade [(T, E)] is "takes a number of time steps in [T], and performs its
    windowed operations only at times in [E]", both sets of natural numbers
    counted from the start. A windowed operation is one whose grade has a
    non-empty [E], e.g. [(1, {0})] for an operation taking one time step and
    happening at its start. Sequencing adds the durations and shifts the later
    times by the earlier durations:
    [(T, E) · (T', E') = (T + T', E ∪ (T + E'))], [+] adding sets elementwise.

    The sets are the regular languages over the letter [tick] alone, a number
    [n] being the word of [n] ticks, in the representation of
    {!RegularTraceGradeDerivative}: [+] is concatenation and [∪] union. *)

module Durations : Grade.S with type t = SymbolicRegex.t
(** The durations, ["durations"]: non-empty sets of natural numbers under
    elementwise addition, ordered by inclusion, the join being the union; the
    unit is [{0}], [of_nat n] is [{n}], and the top all natural numbers. Its
    literals are [n] for [{n}], [(n, m)] for the numbers from [n] to [m], [m]
    possibly [∞], and brace literals over ticks, [{3 | 5}] being [{3, 5}]; a set
    is printed in the first of these forms that denotes it. The witnesses are
    the constants and their pairwise products, and partial. *)

module Times : GradeConstructions.SEMILATTICE with type t = SymbolicRegex.t
(** The times, ["times"]: sets of natural numbers ordered by inclusion, the join
    being the union. Its literals are brace literals over ticks. *)

(** The action of the durations [T] on the times [E], adding them elementwise.
*)
module Shift :
  GradeConstructions.ACTION with type m = Durations.t and type n = Times.t

module TimeWindows : Grade.S with type t = SymbolicRegex.t * SymbolicRegex.t
(** The time-window grade, ["time-windows"]: the semidirect product
    {!GradeConstructions.SemiDirect} [(Durations) (Times) (Shift)].

    - The order is componentwise inclusion, so the unit [({0}, ∅)] is not least.
      [mul] does not commute.
    - [of_nat n] is [({n}, ∅)].
    - [of_lit] reads a literal of the durations [T] as [(T, ∅)], and pairs
      [(T, {E})]; the brace literals name no operation, [_] being a single tick.
      [show] prints [(T, ∅)] as [T] and the top as [⊤].
    - No counterexample is offered, and the witnesses are partial. *)
