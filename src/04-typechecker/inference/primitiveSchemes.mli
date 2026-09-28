(** The type schemes of the primitives: pure functions, of unit effect, the
    comparisons and [to_string] polymorphic in their argument, the comparisons
    at eternal types only. *)

module Make (C : Constraint.S) : sig
  val scheme : Language.Primitives.primitive -> C.scheme
  (** [scheme prim] is the scheme of [prim], qualified by the eternality of the
      compared type for a comparison. *)
end
