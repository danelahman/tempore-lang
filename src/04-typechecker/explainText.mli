(** The printers and the phrases of the diagnostics of rejected commands
    ({!Explain}): grades and types as a message shows them, the two sorts of
    grade expressions, the words for variables and operations, the rigid effect
    variables of handler clauses and the notes of a failing ordering. *)

module Make (C : Inference.Constraint.S) : sig
  (** The residuals of the constraints explained. *)
  module R : module type of struct
    include Inference.Residual.Make (C)
  end

  (** Their rigid scopes. *)
  module RS : module type of struct
    include Inference.RigidScope.Make (C)
  end

  (** Their solver. *)
  module S : module type of struct
    include Inference.Solver.Make (C)
  end

  type source = {
    context : S.context;
    constr : C.t option;
    solution : S.solution option;
    mismatch : S.mismatch option;
  }
  (** What a failure is explained against ({!Explain.Make.source}). *)

  (** {1 Printing} *)

  type printer = {
    bounds : Grades.Grade.bounds;
    values : C.X.subst;  (** the values of the unknowns explained against *)
    ty_name : Language.Ast.ty_param -> Format.formatter -> unit;
    rho_name : C.X.Rho_var.t -> Format.formatter -> unit;
    eps_name : C.X.Eps_var.t -> Format.formatter -> unit;
  }
  (** The printers of one diagnostic, which name the unknowns in the order they
      are first printed, so that a name means the same unknown in the headline,
      the labels and the notes. *)

  val instance_values : S.context -> S.solution -> C.X.subst
  (** [instance_values context solution] is the values of the grade unknowns of
      [solution] in the search for a closed instance of its qualifier, except
      those sent to the top for want of any bound, which stay unknown. *)

  val rigid_origins :
    C.t -> (C.X.Eps_var.t * Inference.Reason.rigid_origin) list
  (** [rigid_origins c] is the rigid effect variables of [c], each with its
      clause. *)

  val printer : source -> printer
  (** [printer source] is a fresh printer for a diagnostic against [source]; a
      rigid variable is named after the operation of its clause. *)

  val canon_rho : printer -> C.rho -> C.rho
  (** [canon_rho p rho] is the canonical form of [rho], in which grades are
      shown, or [rho] itself where its delays exceed the supported range. *)

  val rho_raw : printer -> C.rho -> string
  (** [rho_raw p rho] is the text of [rho] in canonical form. *)

  val eps_raw : printer -> C.eps -> string
  (** [eps_raw p eps] is the text of [eps] in canonical form. *)

  val is_unit_rho : printer -> C.rho -> bool
  (** [is_unit_rho p rho] is whether the canonical form of [rho] is a constant
      equal to the unit. *)

  val skeleton_raw : printer -> Inference.Skeleton.t -> string
  (** [skeleton_raw p t] is the text of the skeleton [t], its box grades shown
      as [_]. *)

  val code : string -> string
  (** [code text] is the fragment [text] of the user's code inside a sentence,
      marked as {!Utils.Diagnostic} marks it. *)

  val ty_code : printer -> C.ty -> string
  (** [ty_code p ty] is the type [ty] marked as code, a computation's effect of
      the unit not shown. *)

  val rho_code : printer -> C.rho -> string
  (** [rho_code p rho] is the text of [rho] marked as code. *)

  (** {1 Grade sorts} *)

  (** The two sorts of grade expressions. *)
  type _ tag = Rho_tag : C.rho tag | Eps_tag : C.eps tag

  type 'e sort = {
    tag : 'e tag;
    noun : string;  (** the sort in a sentence *)
    leq_symbol : string;
    raw : printer -> 'e -> string;
    eps_vars : 'e -> C.X.Eps_var.Set.t;  (** the effect unknowns *)
    subst : C.X.subst -> 'e -> 'e;
    stated_of : C.reason -> ('e * 'e) option;
        (** the ordering of this sort a reason records as stated *)
    shares : 'e -> 'e -> bool;
        (** whether two grades have an unknown in common *)
    hyps_of : R.hyps -> ('e, C.reason) Inference.GradeNormal.ordering list;
        (** the hypotheses of this sort *)
    counterexample : printer -> 'e * 'e -> string option;
        (** a grade below the first of two constant grades but not below the
            second, other than the first itself, printed, if the grades offer
            one *)
  }
  (** The operations a message needs on the grades of one sort. *)

  val rho_sort : C.rho sort
  (** The resource grades. *)

  val eps_sort : C.eps sort
  (** The effect grades. *)

  (** {1 Words} *)

  val label : Utils.Location.t -> string -> Utils.Diagnostic.label
  (** [label span text] is the label [text] at [span]. *)

  val here : string
  (** The word that refers to the place a label points at
      ({!Utils.Diagnostic.place}). *)

  val diagnostic :
    primary:Utils.Location.t ->
    labels:Utils.Diagnostic.label list ->
    notes:string list ->
    string ->
    Utils.Diagnostic.t
  (** [diagnostic ~primary ~labels ~notes message] is the typing error [message]
      at [primary]. *)

  val var_name : Language.Ast.variable -> string option
  (** [var_name x] is the variable [x] as a message may name it; a
      compiler-invented one is not named, the message talking about the
      expression instead. *)

  val op_name : Language.Ast.OpName.t -> string
  (** [op_name op] is the operation [op] marked as code. *)

  val label_name : Language.Ast.Label.t -> string
  (** [label_name lbl] is the constructor [lbl] marked as code. *)

  val subject : Language.Ast.variable -> string
  (** [subject x] is "Variable x" or "This expression", either starting a
      sentence. *)

  val holder : Language.Ast.variable -> string
  (** [holder x] is the name of [x] or "This expression", either starting a
      sentence. *)

  val describe : Language.Ast.variable -> string
  (** [describe x] is the name of [x] or "this expression". *)

  val needed_eternal : Language.Ast.variable -> string
  (** [needed_eternal x] is what a definition needs eternal, as "f needs ... to
      be eternal" continues. *)

  (** {1 Continuation grades} *)

  val continuation_phrase : Inference.Reason.rigid_origin -> string
  (** [continuation_phrase o] is the continuation of the clause of [o] as a noun
      phrase, named only when the clause binds it to a variable. *)

  type rigid = {
    var : C.X.Eps_var.t;
    origin : Inference.Reason.rigid_origin;
    value : C.X.GS.E.t;  (** the grade at which the ordering fails *)
  }
  (** A rigid effect variable an ordering is quantified over. *)

  val rigids_of :
    source ->
    C.X.Eps_var.Set.t ->
    value:(C.X.Eps_var.t -> C.X.GS.E.t) ->
    rigid list
  (** [rigids_of source vars ~value] is the rigids of [vars] whose clause is
      known, outermost clause first, each at its [value]. *)

  val rigid_raw : printer -> rigid -> string
  (** [rigid_raw p r] is the name of the rigid [r]. *)

  val for_every : printer -> rigid list -> string
  (** [for_every p rs] is the form the messages quantify over the rigids [rs]
      with. *)

  val rigid_labels : printer -> rigid list -> Utils.Diagnostic.label list
  (** [rigid_labels p rs] is a label at the continuation of the clause of each
      rigid of [rs]. *)

  val mentioned_rigids : source -> C.reason list -> rigid list
  (** [mentioned_rigids source reasons] is the rigids whose grades [reasons]
      mention. *)

  val ty_rigids : source -> C.ty option -> rigid list
  (** [ty_rigids source ty] is the rigids a type mentions. *)

  val union_rigids : rigid list -> rigid list -> rigid list
  (** [union_rigids rs rs'] is the rigids of [rs] followed by those of [rs'] not
      among them. *)

  val with_rigid_labels :
    printer ->
    rigid list ->
    Utils.Diagnostic.label list ->
    Utils.Diagnostic.label list
  (** [with_rigid_labels p rs labels] is the labels [labels] and those of the
      rigids [rs], a label of a binding giving way to that of a rigid on the
      same span. *)

  val quantified : printer -> rigid list -> string -> string
  (** [quantified p rs text] is the fragment [text] quantified over the rigids
      [rs], marked as code. *)

  (** {1 Refutations} *)

  type 'e refutation = {
    sort : 'e sort;
    stated : 'e * 'e;  (** the sides as generated *)
    instance : 'e * 'e;  (** the variable-free sides that fail *)
    rigids : rigid list;  (** the rigids of [stated] and their values *)
    reasons : C.reason list;  (** the atoms it follows from, in chain order *)
  }
  (** A failing ordering. Where it is quantified over rigids, [instance] is
      [stated] at their values. *)

  val ineq_text : printer -> 'e sort -> 'e * 'e -> string
  (** [ineq_text p sort (lhs, rhs)] is the text of the ordering [lhs ≾ rhs]. *)

  val ineq_note : printer -> 'e refutation -> string
  (** [ineq_note p f] is the note spelling out the ordering of [f]: quantified
      over the rigids, with the instance that refutes it. *)

  val counterexample_notes : printer -> 'e refutation -> string list
  (** [counterexample_notes p f] is the note naming a counterexample to the
      refuted ordering between the constant grades of the instance of [f], if
      the grades offer one. *)

  val ineq_notes : printer -> 'e refutation -> string list
  (** [ineq_notes p f] is the notes spelling out the ordering of [f] and a
      counterexample to it. *)
end
