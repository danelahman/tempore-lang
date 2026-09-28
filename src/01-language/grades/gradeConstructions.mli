(** Generic constructions of grades. *)

(** Decidable finite join-semilattices with a least and a greatest element. *)
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

  val compare : t -> t -> int
  (** A total order compatible with the equality of the elements. *)

  val hash : t -> int
  (** A hash compatible with {!compare}. *)

  val elements : t list
  (** Every element. *)

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
    every grade is atomic, and no counterexample is offered. The witnesses are
    all the elements, and complete. [is_top] is decided by the order, and
    [compare] and [hash] are those of [L]. *)
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
    - [is_atomic name] and [is_top bounds] hold iff they hold for both
      components;
    - [compare] is lexicographic, and [hash] combines those of the components;
    - [witnesses] pairs each witness of the first component with each of the
      second, and is complete iff both are: an ordering fails iff it fails in
      one component;
    - [of_lit] reads [⊤] as the top and a pair [(l1, l2)] componentwise, a
      rejection naming the component;
    - [show] prints [(g1,g2)]. *)
module Product (G1 : Grade.S) (G2 : Grade.S) : Grade.S with type t = G1.t * G2.t

(** Decidable join-semilattices with a least and a greatest element. *)
module type SEMILATTICE = sig
  type t
  (** The elements. *)

  val name : string
  (** The name of the semilattice. *)

  val bottom : t
  (** The least element. *)

  val top : t
  (** The greatest element. *)

  val join : t -> t -> t
  (** The binary join. *)

  val leq : t -> t -> bool
  (** The partial order. *)

  val compare : t -> t -> int
  (** A total order on the representations of the elements: [compare l l' = 0]
      implies that [l] and [l'] are equal. *)

  val hash : t -> int
  (** A hash compatible with {!compare}. *)

  val of_lit : Grade.lit -> t
  (** [of_lit lit] is the element the literal [lit] denotes; [⊤] need not be
      handled.

      @raise Grade.Invalid_literal if [lit] denotes no element. *)

  val show : t -> string
  (** [show l] prints [l] in the literal syntax. *)
end

(** Actions of the grades [m] on the elements [n] of a semilattice. *)
module type ACTION = sig
  type m
  (** The acting grades. *)

  type n
  (** The elements acted on. *)

  val act : m -> n -> n
  (** [act m n] is the action of [m] on [n]. *)
end

(** The semidirect product of the grade [M] and the semilattice [N] under the
    action [Act]: pairs [(m, n)] with
    - [one = (M.one, ⊥)] and [(m, n) · (m', n') = (m · m', n ⊔ act m n')];
    - [top], [join] and the order componentwise;
    - [of_nat k = (M.of_nat k, ⊥)] and [of_bounds b = (M.of_bounds b, ⊥)].

    The construction satisfies the laws of {!Grade} if [M] does and, for all
    grades [m], [m'] and elements [n], [n'],
    - (A1) [act M.one n = n];
    - (A2) [act (m · m') n = act m (act m' n)];
    - (A3) [act m ⊥ = ⊥] and [act m (n ⊔ n') = act m n ⊔ act m n'];
    - (A4) [act (m ⊔ m') n = act m n ⊔ act m' n];
    - (A5) [act] is monotone in both arguments.

    The unit is least iff it is in [M], and [mul] is not taken to commute.

    The remaining fields are those of [M] on the first component:
    [needs_op_bounds], [implied_bounds], [inhabited], [events] and [is_atomic];
    [counterexample] pairs a witness in [M] with the second component of the
    lesser grade.

    The name is [M.name ^ "⋉" ^ N.name], and [leq_symbol] is [<=] if it is that
    of [M] and [≾] otherwise. [equal] and [is_top] are decided componentwise,
    [compare] is lexicographic and [hash] combines those of the components.

    [of_lit] reads [⊤] as the top, a literal that [M] reads as [m] as [(m, ⊥)],
    and otherwise a pair [(l1, l2)] componentwise, [⊤] in the second component
    being the top of [N]; [show] prints the top as [⊤], [(m, ⊥)] as [m] and
    other grades as [(m,n)].

    [witnesses] are the witnesses of [M] paired with [⊥], and the constants and
    their pairwise products, and are partial. *)
module SemiDirect
    (M : Grade.S)
    (N : SEMILATTICE)
    (Act : ACTION with type m = M.t and type n = N.t) :
  Grade.S with type t = M.t * N.t
