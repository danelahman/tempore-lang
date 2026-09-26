(** The type schemes of the primitives: pure functions, of unit effect, the
    comparisons and [to_string] polymorphic in their argument. *)

module Make (C : Constraint.S) : sig
  val scheme : Language.Primitives.primitive -> C.scheme
  (** [scheme prim] is the unqualified scheme of [prim]. *)
end
