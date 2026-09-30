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

(** The grade of a lattice [L] over the delays [D]: [mul] and [join] are both
    the join of [L], [one] its bottom, [top] its top and [leq] its order. A
    delay touches no level of the lattice, so [of_delay] is constantly the
    bottom, and so is [of_bounds]. The unit is least and [mul] commutes. No
    operation needs runtime bounds, every grade is atomic, and no counterexample
    is offered. The witnesses are all the elements, and complete. [is_top] is
    decided by the order, and [compare] and [hash] are those of [L]. *)
module OfLattice (D : Delay.S) (L : LATTICE) :
  Grade.S with type t = L.t and type Delay.t = D.t

(** The product of the grades [G1] and [G2] over the same delays: pairs
    [(g1, g2)], written as such in literals, with [one], [mul], [top], [join],
    [of_delay] and [of_bounds] componentwise; the order is the conjunction of
    the componentwise orders. The unit is least and [mul] commutes iff they do
    so in both components.

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
    - [show] prints [(g1, g2)]. *)
module Product (G1 : Grade.S) (G2 : Grade.S with type Delay.t = G1.Delay.t) :
  Grade.S with type t = G1.t * G2.t and type Delay.t = G1.Delay.t

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
    - the delays of [M], [of_delay d = (M.of_delay d, ⊥)] and
      [of_bounds b = (M.of_bounds b, ⊥)].

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
    being the top of [N]. A literal that is not a pair is rejected as [M]
    rejects it, and so is a pair whose second component [N] rejects but [M]
    reads. [show] prints the top as [⊤], [(m, ⊥)] as [m] and other grades as
    [(m, n)].

    [witnesses] are the witnesses of [M] paired with [⊥], and the constants and
    their pairwise products, and are partial. *)
module SemiDirect
    (M : Grade.S)
    (N : SEMILATTICE)
    (Act : ACTION with type m = M.t and type n = N.t) :
  Grade.S with type t = M.t * N.t and type Delay.t = M.Delay.t

(** Maps from names, free capitalised names such as [Send] or [Files], to the
    elements of a component, each name but finitely many being given a default
    element, and their lifts of the semilattices, actions and grades of the
    component, all pointwise.

    {2 Literals}

    An entry [(Name, c)] gives the name [Name] the element of the literal [c],
    and [(Name, c1, …, ck)] that of the tuple [(c1, …, ck)]. A map is written as
    one entry or as a tuple of entries [((A, a), (B, b))], each name listed
    once, the other names having the default: the least element of a
    semilattice, the unit of a grade, or the element of an entry [(_, c)]. Any
    other literal [c] gives every name the element of [c]. A map is printed
    alike, in increasing order of the names, an element other than the default
    of the other names being printed as an entry of [_].

    {2 Witnesses}

    An ordering of maps is the conjunction of its projections [m ↦ m(s)] on the
    names [s], which are morphisms of the products, joins and actions, and the
    names that no constant of the ordering gives its own element are all alike
    to it. It thus fails at a map iff it fails, at one of the names of the
    constants or at a fresh name ["_"] standing for the others, at the element
    of the map there. The witnesses of {!OfGrade} are, for each such name, the
    witnesses of the component for the elements of the constants there, each
    given to that name alone, or to all the others for ["_"]: they are complete
    whenever those of the component are. *)
module Indexed : sig
  type 'a t
  (** The maps to ['a]. *)

  val fresh : string
  (** The name ["_"], standing for the names that are not given their own
      element. *)

  val everywhere : 'a -> 'a t
  (** [everywhere c] gives every name [c]. *)

  val of_list :
    compare:('a -> 'a -> int) -> others:'a -> (string * 'a) list -> 'a t
  (** [of_list ~compare ~others entries] gives the names of [entries] their
      elements, the first listed for a name listed twice, and the other names
      [others], or the element of an entry of {!fresh}; [compare] tells the
      elements equal to the default. *)

  val at : 'a t -> string -> 'a
  (** [at m s] is the element of the name [s]. *)

  val named : 'a t -> (string * 'a) list
  (** [named m] is the names given an element other than the default, with their
      elements, in increasing order of the names. *)

  val others : 'a t -> 'a
  (** [others m] is the default, the element of the other names. *)

  val names : 'a t list -> string list
  (** [names ms] is the names given their own element by some of [ms], and
      {!fresh}, in increasing order. *)

  val of_entries_lit :
    compare:('a -> 'a -> int) ->
    default:'a ->
    (Grade.lit -> 'a) ->
    Grade.lit ->
    Grade.lit list ->
    'a t
  (** [of_entries_lit ~compare ~default of_lit lit entries] is the map of the
      literals [entries] of entries in the literal [lit], each element read by
      [of_lit], the other names having [default] or the element of an entry
      [(_, c)]; [compare] tells the elements equal to the default.

      @raise Grade.Invalid_literal
        if an entry is malformed or a name is listed twice. *)

  val show_entries : is_default:('a -> bool) -> ('a -> string) -> 'a t -> string
  (** [show_entries ~is_default show m] prints the entries of [m], separated by
      commas, the default as an entry of {!fresh} unless [is_default]. *)

  (** The maps to a semilattice [C], ordered and joined pointwise;
      ["C.name by name"]. *)
  module OfSemilattice (C : SEMILATTICE) : SEMILATTICE with type t = C.t t

  (** The action [A] lifted pointwise to the maps to [C]. *)
  module Action (C : SEMILATTICE) (A : ACTION with type n = C.t) :
    ACTION with type m = A.m and type n = C.t t

  (** The maps to a grade [G], over its delays, with every operation pointwise
      and the default the unit: [one], [top] and [of_delay d] give every name
      those of [G], [mul], [join], [leq] and [equal] are taken name by name, and
      [is_top], [inhabited] and [is_atomic] hold iff they hold at every name.
      The unit is least and [mul] commutes iff they do so in [G];
      [needs_op_bounds] is that of [G], [implied_bounds] is [None] and [events]
      are those of every name. [counterexample] gives the lesser map, at the
      first name where [G] offers one, the witness of [G] there. The witnesses
      are described above, complete iff those of [G] are. The name is
      ["G.name by name"]. *)
  module OfGrade (G : Grade.S) :
    Grade.S with type t = G.t t and type Delay.t = G.Delay.t
end
