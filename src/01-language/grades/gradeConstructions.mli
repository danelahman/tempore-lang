(** Generic constructions of grades. *)

(** Decidable bounded join-semilattices. *)
module type LATTICE = sig
  type t
  (** The elements. *)

  val name : string
  (** The name of the grade the lattice gives. *)

  val bottom : t
  (** The least element. *)

  val top : t
  (** The greatest element. *)

  val join : t -> t -> t
  (** The binary join. *)

  val leq : t -> t -> bool
  (** The partial order. *)

  val of_lit : Grade.lit -> t
  (** [of_lit lit] is the element the literal [lit] denotes; [⊤] need not be
      handled.

      @raise Grade.Invalid_literal if [lit] denotes no element. *)

  val show : t -> string
  (** [show l] prints [l] in the literal syntax. *)
end

(** The grade of a lattice [L]: [mul] and [join] are both the join of [L], [one]
    its bottom, [top] its top and [leq] its order. A tick touches no level of
    the lattice, so [of_nat] is constantly the bottom, and so is [of_bounds].
    The unit is least and [mul] commutes. No operation needs runtime bounds,
    every grade is atomic, and no counterexample is offered. *)
module OfLattice (L : LATTICE) : Grade.S with type t = L.t

(** The product of the grades [G1] and [G2]: pairs [(g1, g2)], written as such
    in literals, with [one], [mul], [top], [join], [of_nat] and [of_bounds]
    componentwise and the order the conjunction of the componentwise orders. The
    unit is least and [mul] commutes iff they do so in both components.

    The remaining fields combine those of the components as follows:
    - [name] is [G1.name ^ "×" ^ G2.name];
    - [leq_symbol] is the components' symbol if they share it, and [≾]
      otherwise;
    - [needs_op_bounds] holds iff it holds for either component;
    - [counterexample] pairs a witness in the first component with the second
      component of the lesser grade, or else the first component of the lesser
      grade with a witness in the second component;
    - [implied_bounds] intersects the bounds the components imply, the greater
      lower bound and the lesser upper bound, and is [None] only if neither
      implies any;
    - [inhabited] holds iff it holds for both components;
    - [events] are the events of either component;
    - [is_atomic name] holds iff it holds for both components;
    - [of_lit] reads [⊤] as the top and a pair [(l1, l2)] componentwise, a
      rejection naming the component;
    - [show] prints [(g1,g2)]. *)
module Product (G1 : Grade.S) (G2 : Grade.S) : Grade.S with type t = G1.t * G2.t
