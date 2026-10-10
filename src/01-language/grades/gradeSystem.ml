(** Grade systems: a grade for resources, a grade for effects, and a grade
    morphism [∣_∣] from the latter to the former. *)

module type S = sig
  module R : Grade.S
  (** The resource grades. *)

  module E : Grade.S with type Delay.t = R.Delay.t
  (** The effect grades, over the delays of the resource grades. *)

  val map : E.t -> R.t
  (** The grade morphism [∣_∣]: monotone, and preserving the unit, the product,
      the top, joins and delays: [map (E.of_delay d) = R.of_delay d]. *)

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
    [map] being the identity. *)
module Identity (G : Grade.S) : S with module R = G and module E = G = struct
  module R = G
  module E = G

  let map c = c
  let unit_reflecting = true
  let witnesses ~degree bounds rcs ecs = G.witnesses ~degree bounds (rcs @ ecs)
end
