(** The security-level grades, their products with the time grades, and the
    flow-sensitive levels.

    The level of a computation is the highest level it touches; a box at level
    [ℓ] may be unboxed only while the level has not risen above [ℓ] since it was
    boxed. Ticks touch no level. *)

(** The two security levels, [Low < High], written [Low] and [High]. *)
type level = Low | High

module SecurityLevels : Grade.S with type t = level
(** The two-point lattice [Low < High] as a grade, ["security-levels"] (see
    {!GradeConstructions.OfLattice}); [⊤] is [High]. *)

module TimeLowerBoundLevels :
  Grade.S with type t = TimeGrades.LowerBound.t * level
(** The product of [time-lower-bound] and [security-levels],
    ["time-lower-bound-levels"]: [(n, ℓ)] is "at least [n] time steps, touching
    nothing above [ℓ]", an embargo with a taint check. *)

module TimeUpperBoundLevels :
  Grade.S with type t = TimeGrades.UpperBound.t * level
(** The product of [time-upper-bound] and [security-levels],
    ["time-upper-bound-levels"]: [(n, ℓ)] is "at most [n] time steps, touching
    nothing above [ℓ]", an expiring untainted capability. *)

module WrittenAt : GradeConstructions.SEMILATTICE with type t = level option
(** The level at which a sink is written, ["written"]: [None] if it is not,
    below [Some Low], below [Some High]. Its literals are the levels. *)

module Outputs :
  GradeConstructions.SEMILATTICE
    with type t = level option GradeConstructions.Indexed.t
(** The outputs a computation writes, each sink at the highest level touched
    before writing it, the other sinks unwritten:
    {!GradeConstructions.Indexed.OfSemilattice} [(WrittenAt)]. Its top writes
    every sink at [High]. *)

(** The action of a level [l] on the outputs, raising each written sink to at
    least [l]: {!GradeConstructions.Indexed.Action}. *)
module Raise :
  GradeConstructions.ACTION with type m = level and type n = Outputs.t

module FlowLevels : Grade.S with type t = level * Outputs.t
(** The flow-sensitive levels, ["flow-levels"]: the semidirect product
    {!GradeConstructions.SemiDirect} [(SecurityLevels) (Outputs) (Raise)].
    [(l, W)] is "touches nothing above [l], and writes each sink at most at the
    level [W] gives it", and [(l, W) · (l', W') = (l ⊔ l', W ⊔ raise_l W')]: the
    later outputs are written after [l] has been touched.

    - The order is componentwise, the unit [(Low, ∅)] is least, and [mul] does
      not commute.
    - [of_nat] is constantly the unit.
    - [of_lit] reads [⊤] as the top, a level [l] as [(l, ∅)] and a tuple
      [(l, (S₁, l₁), …, (Sₖ, lₖ))] as [l] with the sinks [Sᵢ] written at [lᵢ],
      each sink listed once, an entry [(_, l')] writing every other sink at
      [l']; [show] prints alike, the sinks in increasing order.
    - No counterexample is offered.
    - The witnesses of the constants [cs] are complete: the pairs of a level
      with no output or with one sink written at a level, the sinks being those
      of [cs] and a sink ["_"] standing for the others. An ordering is the
      conjunction of its projections [(l, W) ↦ (l, W(s))] on the sinks,
      morphisms preserving the joins, so that it fails at a rigid iff it fails
      at the witness of the level and one sink of the rigid. *)
