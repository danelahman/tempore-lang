(** Grade systems: a grade algebra for resources, a grade algebra for effects,
    and a morphism [∣_∣] of grade algebras from the latter to the former. *)

module type S = sig
  module R : Grade.S
  (** The grade algebra of the resource grades. *)

  module E : Grade.S with type Delay.t = R.Delay.t
  (** The grade algebra of the effect grades, over the delays of the resource
      grades. *)

  val map : Grade.bounds -> E.t -> R.t
  (** [map bounds] is the morphism [∣_∣] of grade algebras under the running
      times [bounds]: monotone, and preserving the unit, the product, the top,
      joins and delays: [map bounds (E.of_delay d) = R.of_delay d]. The image of
      a grade depends on the running times of the operations it mentions only.
  *)

  val lattice : GradeLattice.t option
  (** The grade lattice the program declares, over which the lattice grades are
      built; [None] where it declares none. *)

  val unit_reflecting : bool
  (** Whether [map] reflects the order at the unit: [∣e∣ ≾ one] implies
      [e ≾ one]. *)

  val witnesses :
    degree:int ->
    Grade.bounds ->
    R.t list ->
    E.t list ->
    E.t list * Grade.completeness
  (** [witnesses ~degree bounds rcs ecs] is [Grade.S.witnesses] for a condition
      over an effect rigid [j] whose orderings are of either sort, [j] occurring
      under images on the resource side at most [degree] times on either side of
      each, with resource constants [rcs] and effect constants [ecs]. *)
end

(** The grade system in which effects and resources are graded alike by [G],
    [map] being the identity, in a program declaring the grade lattice
    [L.lattice]. *)
module Declaring
    (L : sig
      val lattice : GradeLattice.t option
    end)
    (G : Grade.S) : S with module R = G and module E = G = struct
  module R = G
  module E = G

  let map _bounds c = c
  let lattice = L.lattice
  let unit_reflecting = true
  let witnesses ~degree bounds rcs ecs = G.witnesses ~degree bounds (rcs @ ecs)
end

(** The grade system in which effects and resources are graded alike by [G],
    [map] being the identity, in a program declaring no grade lattice. *)
module Identity (G : Grade.S) : S with module R = G and module E = G =
  Declaring
    (struct
      let lattice = None
    end)
    (G)
