(** Skeletons of types, their first-order unification, decoration and the
    expansion of type unknowns that subtyping demands call for.

    A skeleton is a type with its grades erased. Its variables are the type
    unknowns themselves, so a skeleton substitution is a finite map on type
    unknowns and no variable is ever renamed or reindexed. *)

(** {1 Skeletons} *)

(** Skeletons. The result of an arrow and the input and output of a handler are
    the skeletons of the value types of their computation types. *)
type t =
  | Var of Language.Ast.ty_param  (** a type unknown *)
  | Const of Language.Const.ty
  | Apply of Language.Ast.ty_name * t list
      (** a type constructor applied to arguments *)
  | Tuple of t list
  | Arrow of t * t
  | Box of t
  | Handler of t * t

val of_ty : ('rho, 'eps) Language.Ast.ty -> t
(** [of_ty ty] is the skeleton of [ty], its grades erased. *)

val of_comp_ty : ('rho, 'eps) Language.Ast.comp_ty -> t
(** [of_comp_ty cty] is the skeleton of the value type of [cty]. *)

val equal : t -> t -> bool
(** [equal t u] is syntactic equality. *)

val free_vars : t -> Language.Ast.TyParamSet.t
(** [free_vars t] is the set of type unknowns of [t]. *)

val occurs : Language.Ast.ty_param -> t -> bool
(** [occurs a t] is whether the type unknown [a] occurs in [t]. *)

val print : t -> Format.formatter -> unit
(** [print t ppf] prints [t] in the notation of types, without grades. *)

val to_string : t -> string
(** [to_string t] is the text {!print} prints. *)

(** {1 Substitutions} *)

type subst = t Language.Ast.TyParamMap.t
(** A skeleton substitution, the identity outside its domain. Those {!unify}
    returns are idempotent: no unknown of the domain occurs in the range. *)

val apply : subst -> t -> t
(** [apply sigma t] replaces each unknown of [t] by its image under [sigma]. *)

(** {1 Unification} *)

type unfold = Language.Ast.ty_name -> t list -> t option
(** [unfold name args] is the skeleton a transparent type alias [name] applied
    to [args] stands for, and [None] for an inductive or builtin type. *)

type 'info equation = { lhs : t; rhs : t; info : 'info }
(** The equation [lhs = rhs] with the payload [info]. *)

(** Why an equation has no unifier. *)
type mismatch =
  | Clash  (** the two sub-skeletons have different formers or arities *)
  | Occurs of Language.Ast.ty_param
      (** the unknown occurs in the sub-skeleton it is equated with *)

type 'info failure = {
  info : 'info;  (** the payload of the equation that fails *)
  mismatch : mismatch;
  lhs : t;  (** its left sub-skeleton at [path], under the unifier so far *)
  rhs : t;  (** its right sub-skeleton at [path], under the unifier so far *)
  path : Language.Ast.step list;
      (** the position of the two sub-skeletons within the equation, outermost
          first, after the unfolding of aliases *)
}
(** The failure of an equation, the first of the list that has no unifier
    together with those before it. *)

val unify : unfold -> 'info equation list -> (subst, 'info failure) result
(** [unify unfold equations] is the most general unifier of [equations], solved
    left to right, or the failure of the first equation that has none. An alias
    application is unfolded by [unfold] when it meets a skeleton of another
    former or head, and also when it meets an application of its own head, since
    an alias may ignore its arguments. An unknown is bound to a skeleton without
    unfolding. *)

(** {1 Traced unification} *)

(** A side of an equation. *)
type side = Left | Right

(** Where the value an unknown is bound to comes from. *)
type source =
  | Side of side
      (** the sub-skeleton of the given side of the equation, at the position of
          the binding, other than an unknown *)
  | Through of Language.Ast.ty_param
      (** the value of the given unknown, which faced the bound unknown *)

type 'info binding = {
  site : 'info;  (** the payload of the equation whose unification bound it *)
  at : Language.Ast.step list;
      (** the position of the binding within the equation, outermost first,
          after the unfolding of aliases *)
  source : source;
}
(** How an unknown came to be bound in a unification. *)

type 'info bindings = 'info binding Language.Ast.TyParamMap.t
(** The binding of each unknown of the domain of a unifier. *)

val unify_traced :
  unfold ->
  'info equation list ->
  (subst * 'info bindings, 'info failure * 'info bindings) result
(** [unify_traced unfold equations] is {!unify} with the bindings made, those
    made before the failure when there is one. *)

(** {1 Decoration and expansion} *)

(** [Make (X)] decorates and expands with the open grade expressions of [X]. *)
module Make (X : GradeExp.S) : sig
  type ty = (X.rho, X.eps) Language.Ast.ty
  (** Open types. *)

  type comp_ty = (X.rho, X.eps) Language.Ast.comp_ty
  (** Open computation types. *)

  type ty_subst = ty Language.Ast.TyParamMap.t
  (** A substitution of open types for type unknowns, the identity outside its
      domain. *)

  val decorate : t -> ty
  (** [decorate t] is the most general open type of skeleton [t]: a fresh
      resource variable grades each box, a fresh effect variable each
      computation type, and a fresh type unknown stands at each occurrence of a
      skeleton variable. *)

  val substitute : ty_subst -> ty -> ty
  (** [substitute theta ty] replaces each type unknown of [ty] by its image
      under [theta]. *)

  val expand :
    unfold ->
    (ty, 'info) GradeNormal.ordering list ->
    (ty_subst, 'info failure) result
  (** [expand unfold demands] unifies the skeletons of the two sides of every
      subtyping demand, and instantiates each unknown the unifier sends to a
      skeleton other than a variable by a decoration of that skeleton; the other
      unknowns are kept. Under the result the two sides of every demand have the
      same shape, their skeletons with all unknowns identified. A failure names
      the payload of the first demand whose shapes are incompatible with those
      before it. *)

  val expand_traced :
    unfold ->
    (ty, 'info) GradeNormal.ordering list ->
    (ty_subst * 'info bindings, 'info failure * 'info bindings) result
  (** [expand_traced unfold demands] is {!expand} with the bindings of the
      unification of the skeletons ({!unify_traced}). *)
end
