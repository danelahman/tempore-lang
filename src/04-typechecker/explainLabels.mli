(** The places the diagnostics of rejected commands ({!Explain}) point at: where
    a variable was bound, where grades accumulated since, where an operation was
    declared, and the links of a chain of orderings. *)

module Make
    (C : Inference.Constraint.S)
    (T : module type of struct
      include ExplainText.Make (C)
    end) : sig
  val accumulated_grade : C.rho Inference.Reason.lock list -> C.rho
  (** [accumulated_grade locks] is the grade accumulated by [locks], oldest
      first: the product of their grades. *)

  val declared_label :
    Language.Ast.OpName.t -> Utils.Location.t -> Utils.Diagnostic.label
  (** [declared_label op signature_at] is the label of the declaration of [op]
      at [signature_at]. *)

  val use_of : C.reason -> C.reason option
  (** [use_of reason] is the use a var-rule atom of [reason] began at, through
      the definitions whose schemes carried it: the reason of the use. *)

  val labels_of_reason : T.printer -> C.reason -> Utils.Diagnostic.label list
  (** [labels_of_reason p reason] is the related places [reason] contributes:
      where a variable was bound, where grades accumulated since, where an
      operation was declared, and the chain of definitions a scheme's atom came
      through. *)

  val chain_labels :
    primary:Utils.Location.t ->
    labels:Utils.Diagnostic.label list ->
    C.reason list ->
    Utils.Diagnostic.label list
  (** [chain_labels ~primary ~labels reasons] is a label at each source of
      grades along the chain of orderings [reasons], a type stated or inferred
      elsewhere rather than a construct passing a grade on, other than [primary]
      and the places of [labels]. *)

  val dedup : Utils.Diagnostic.label list -> Utils.Diagnostic.label list
  (** [dedup labels] is [labels] without the repetitions of a label. *)
end
