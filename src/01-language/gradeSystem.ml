(** Grade systems: a grade for resources, a grade for effects, and a grade
    morphism [∣_∣] from the latter to the former. *)

module type S = sig
  module R : Grade.S
  (** The resource grades. *)

  module E : Grade.S
  (** The effect grades. *)

  val map : E.t -> R.t
  (** The grade morphism [∣_∣]: monotone, and preserving the unit, the product,
      the top, joins and [of_nat]. *)
end

(** The grade system in which effects and resources are graded alike by [G],
    [map] being the identity. *)
module Identity (G : Grade.S) : S with module R = G and module E = G = struct
  module R = G
  module E = G

  let map c = c
end
