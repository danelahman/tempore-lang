(** The security-level grades, their products with the time grades, and the
    flow-sensitive levels, over a finite lattice of levels: that a program
    declares, or else [Low < High].

    The level of a computation is the highest level it touches; a box at level
    [ℓ] may be unboxed only while the level has not risen above [ℓ] since it was
    boxed. Delays touch no level. *)

type level = int
(** A level of a {!LevelLattice.t}, by its number. *)

(** The level grades over a lattice of levels. *)
module type S = sig
  val lattice : LevelLattice.t
  (** The lattice of the levels. *)

  module WrittenAt : GradeConstructions.SEMILATTICE with type t = level option
  (** The level at which a sink is written, ["written"]: [None] if it is not,
      below [Some l] for every level [l], ordered as the levels. Its literals
      are the levels. *)

  module Outputs :
    GradeConstructions.SEMILATTICE
      with type t = level option GradeConstructions.Indexed.t
  (** The outputs a computation writes, each sink at the highest level touched
      before writing it, the other sinks unwritten:
      {!GradeConstructions.Indexed.OfSemilattice} [(WrittenAt)]. Its top writes
      every sink at the greatest level. *)

  (** The action of a level [l] on the outputs, raising each written sink to at
      least [l]: {!GradeConstructions.Indexed.Action}. *)
  module Raise :
    GradeConstructions.ACTION with type m = level and type n = Outputs.t

  (** The level grades over any delays [D], which touch no level. *)
  module Make (D : Delay.S) : sig
    (** {!LevelGrades.SecurityLevels} over [D]. *)
    module SecurityLevels : Grade.S with type t = level and type Delay.t = D.t

    (** {!LevelGrades.FlowLevels} over [D]. *)
    module FlowLevels :
      Grade.S with type t = level * Outputs.t and type Delay.t = D.t
  end

  (** The lattice as a grade, ["security-levels"] (see
      {!GradeConstructions.OfLattice}); [⊤] is the greatest level. Its literals
      are the names of the levels, and its delays the rationals, which touch no
      level. *)
  module SecurityLevels :
    Grade.S with type t = level and type Delay.t = Delay.Rational.t

  (** The product of [time-lower-bound] and [security-levels],
      ["time-lower-bound-levels"]: [(n, ℓ)] is "at least [n] time steps,
      touching nothing above [ℓ]", an embargo with a taint check. *)
  module TimeLowerBoundLevels :
    Grade.S
      with type t = TimeGrades.LowerBound.t * level
       and type Delay.t = Delay.Nat.t

  (** The product of [time-upper-bound] and [security-levels],
      ["time-upper-bound-levels"]: [(n, ℓ)] is "at most [n] time steps, touching
      nothing above [ℓ]", an expiring untainted capability. *)
  module TimeUpperBoundLevels :
    Grade.S
      with type t = TimeGrades.UpperBound.t * level
       and type Delay.t = Delay.Nat.t

  (** The product of [time-interval-rational] and [security-levels],
      ["time-interval-levels"]: [(i, ℓ)] is "taking a time in the rational
      interval [i], touching nothing above [ℓ]". The product adds the intervals
      (the Minkowski sum) and joins the levels; a delay [d] is [([d, d], ⊥)]. *)
  module TimeIntervalLevels :
    Grade.S
      with type t = RationalTimeGrades.Interval.t * level
       and type Delay.t = Delay.Rational.t

  (** The flow-sensitive levels, ["flow-levels"]: the semidirect product
      {!GradeConstructions.SemiDirect} [(SecurityLevels) (Outputs) (Raise)].
      [(l, W)] is "touches nothing above [l], and writes each sink at most at
      the level [W] gives it", and
      [(l, W) · (l', W') = (l ⊔ l', W ⊔ raise_l W')]: the later outputs are
      written after [l] has been touched.

      - The order is componentwise, the unit [(⊥, ∅)] is least, and [mul] does
        not commute.
      - Its delays are those of {!SecurityLevels}, and [of_delay] is constantly
        the unit.
      - [of_lit] reads [⊤] as the top, a level [l] as [(l, ∅)] and a tuple
        [(l, (S₁, l₁), …, (Sₖ, lₖ))] as [l] with the sinks [Sᵢ] written at [lᵢ],
        each sink listed once, an entry [(_, l')] writing every other sink at
        [l']; [show] prints alike, the sinks in increasing order.
      - No counterexample is offered.
      - The witnesses of the constants [cs] are complete: the pairs of a level
        with no output or with one sink written at a level, the sinks being
        those of [cs] and a sink ["_"] standing for the others. An ordering is
        the conjunction of its projections [(l, W) ↦ (l, W(s))] on the sinks,
        morphisms preserving the joins, so that it fails at a rigid iff it fails
        at the witness of the level and one sink of the rigid. *)
  module FlowLevels :
    Grade.S with type t = level * Outputs.t and type Delay.t = Delay.Rational.t
end

(** The level grades over the lattice [L.lattice]. *)
module Over (L : sig
  val lattice : LevelLattice.t
end) : S

include S
(** The level grades over {!LevelLattice.default}, [Low < High]. *)
