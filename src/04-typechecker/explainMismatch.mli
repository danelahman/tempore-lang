(** The diagnostics of type mismatches ({!Explain}), and the solutions of a
    command's constraint without its failing atoms, whose types the messages
    show. *)

module Make
    (C : Inference.Constraint.S)
    (T : module type of struct
      include ExplainText.Make (C)
    end)
    (_ : module type of struct
      include ExplainLabels.Make (C) (T)
    end) : sig
  (** {1 Solutions without the failing atoms} *)

  val same_origin : C.reason -> C.reason -> bool
  (** [same_origin r r'] is whether [r] and [r'] name the same construct, rule
      and subject, whatever their paths, stated orderings and grades. *)

  val generated_by : C.reason -> C.reason -> bool
  (** [generated_by failing r] is whether an atom of reason [r] is one [failing]
      was decomposed out of. *)

  val atoms : C.t -> C.t list
  (** [atoms c] is the atoms of [c], from left to right. *)

  val drop : (C.t -> bool) -> C.t -> C.t
  (** [drop dropped c] is [c] with each atom that satisfies [dropped] replaced
      by [True]. *)

  val disjunction_ty : T.source -> C.reason -> C.ty option
  (** [disjunction_ty source reason] is the type of the var-rule atom of
      [reason], in a solution of the constraint of [source] without it. *)

  val root :
    T.source -> C.reason -> (C.reason * C.ty * C.ty * (C.ty -> C.ty)) option
  (** [root source reason] is the subtyping atom of the longest path that a
      failing atom of reason [reason] was decomposed out of: its reason and its
      sides in a solution of the constraint of [source] without the atoms of
      that path, with the instance of that solution. *)

  (** {1 Type mismatches} *)

  val mismatch_message :
    reason:C.reason ->
    path:Inference.Reason.step list ->
    o:string ->
    e:string ->
    non_box:string ->
    Utils.Location.t * string
  (** [mismatch_message ~reason ~path ~o ~e ~non_box] is the place and the
      sentence of a mismatch at [path] between the type [o] the subject offers
      and the type [e] expected, by the construct of [reason] that relates them:
      of the whole types where the construct words them, else of the shape of
      [o], or of [non_box], a type that is not a box, or of the types alone. *)

  val worded :
    C.reason ->
    Inference.Reason.step list ->
    C.ty * C.ty ->
    (Inference.Reason.step list * (C.ty * C.ty)) option
  (** [worded root path sides] is the path and the sides at which the construct
      of the atom [root], generated with sides [sides], words a mismatch between
      whole types within it at [path]: its own, or one step down. *)

  val mismatch :
    T.source -> C.reason Inference.Skeleton.failure -> Utils.Diagnostic.t
  (** [mismatch source f] is the diagnostic of the failed expansion [f]. *)
end
