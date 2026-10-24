(** The grades of a grade lattice, their products with the time grades, and the
    flow-sensitive outputs, over the grade lattice that a program declares, or
    else [Low < High].

    The grade of a computation is the highest element it touches; a box with
    element [ℓ] may be unboxed only while nothing above [ℓ] has been touched
    since it was boxed. Delays touch no element. *)

type element = int
(** An element of a {!GradeLattice.t}, by its number. *)

(** The grades over a grade lattice. *)
module type S = sig
  val lattice : GradeLattice.t
  (** The grade lattice. *)

  module WrittenAt : GradeConstructions.SEMILATTICE with type t = element option
  (** The element at which a sink is written, ["written"]: [None] if it is not,
      below [Some l] for every element [l], ordered as the elements. Its
      literals are the elements. *)

  module Outputs :
    GradeConstructions.SEMILATTICE
      with type t = element option GradeConstructions.Indexed.t
  (** The outputs a computation writes, each sink at the highest element touched
      before writing it, the other sinks unwritten:
      {!GradeConstructions.Indexed.OfSemilattice} [(WrittenAt)]. Its top writes
      every sink at the greatest element. *)

  (** The action of an element [l] on the outputs, raising each written sink to
      at least [l]: {!GradeConstructions.Indexed.Action}. *)
  module Raise :
    GradeConstructions.ACTION with type m = element and type n = Outputs.t

  (** The lattice grades over any delays [D], which touch no element. *)
  module Make (D : Delay.S) : sig
    (** {!LatticeGrades.Lattice} over [D]. *)
    module Lattice : Grade.S with type t = element and type Delay.t = D.t

    (** {!LatticeGrades.FlowLattice} over [D]. *)
    module FlowLattice :
      Grade.S with type t = element * Outputs.t and type Delay.t = D.t
  end

  (** The lattice as a grade, ["lattice"] (see {!GradeConstructions.OfLattice});
      [⊤] is the greatest element. Its literals are the names of the elements,
      and its delays the rationals, which touch no element. *)
  module Lattice :
    Grade.S with type t = element and type Delay.t = Delay.Rational.t

  (** The product of [time-lower-bound] and [lattice],
      ["time-lower-bound-lattice"]: [(n, ℓ)] is "at least [n] time steps,
      touching nothing above [ℓ]", an embargo with a taint check. *)
  module TimeLowerBoundLattice :
    Grade.S
      with type t = TimeGrades.LowerBound.t * element
       and type Delay.t = Delay.Nat.t

  (** The product of [time-upper-bound] and [lattice],
      ["time-upper-bound-lattice"]: [(n, ℓ)] is "at most [n] time steps,
      touching nothing above [ℓ]", an expiring untainted capability. *)
  module TimeUpperBoundLattice :
    Grade.S
      with type t = TimeGrades.UpperBound.t * element
       and type Delay.t = Delay.Nat.t

  (** The product of [time-interval-rational] and [lattice],
      ["time-interval-lattice"]: [(i, ℓ)] is "taking a time in the rational
      interval [i], touching nothing above [ℓ]". The product adds the intervals
      (the Minkowski sum) and joins the elements; a delay [d] is [([d, d], ⊥)].
  *)
  module TimeIntervalLattice :
    Grade.S
      with type t = RationalTimeGrades.Interval.t * element
       and type Delay.t = Delay.Rational.t

  (** The flow-sensitive outputs, ["flow-lattice"]: the semidirect product
      {!GradeConstructions.SemiDirect} [(Lattice) (Outputs) (Raise)]. [(l, W)]
      is "touches nothing above [l], and writes each sink at most at the element
      [W] gives it", and [(l, W) · (l', W') = (l ⊔ l', W ⊔ raise_l W')]: the
      later outputs are written after [l] has been touched.

      - The order is componentwise, the unit [(⊥, ∅)] is least, and [mul] does
        not commute.
      - Its delays are those of {!Lattice}, and [of_delay] is constantly the
        unit.
      - [of_lit] reads [⊤] as the top, an element [l] as [(l, ∅)] and a tuple
        [(l, (S₁, l₁), …, (Sₖ, lₖ))] as [l] with the sinks [Sᵢ] written at [lᵢ],
        each sink listed once, an entry [(_, l')] writing every other sink at
        [l']; [show] prints alike, the sinks in increasing order.
      - No counterexample is offered.
      - The witnesses of the constants [cs] are complete: the pairs of an
        element with no output or with one sink written at an element, the sinks
        being those of [cs] and a sink ["_"] standing for the others. An
        ordering is the conjunction of its projections [(l, W) ↦ (l, W(s))] on
        the sinks, morphisms preserving the joins, so that it fails at a rigid
        iff it fails at the witness of the element and one sink of the rigid. *)
  module FlowLattice :
    Grade.S
      with type t = element * Outputs.t
       and type Delay.t = Delay.Rational.t
end

(** The lattice grades over the grade lattice [L.lattice]. *)
module Over (L : sig
  val lattice : GradeLattice.t
end) : S

include S
(** The lattice grades over {!GradeLattice.default}, [Low < High]. *)
