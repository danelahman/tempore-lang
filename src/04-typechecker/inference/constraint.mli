(** Constraints over open types and grade expressions, and qualified type
    schemes.

    Open types are the types of {!Language.Ast} graded by open grade
    expressions; their type unknowns are the parameters [TyParam]. A constraint
    is a formula built from value-type subtyping, orderings of either grade
    sort, eternality atoms, the disjunctions of the variable rule, conjunction,
    existential scopes of fresh unknowns and rigid scopes of effect variables.
    Every atom carries its {!Reason.t}.

    {2 Subtyping}

    [Sub] is shape-preserving subtyping. The solver decomposes a demand between
    two types of one former into demands between their value parts and orderings
    between their grades, each in the direction of its variance, as
    {!Former.decompose} states; an application of an alias is unfolded first,
    and a demand between distinct formers is unsatisfiable.

    A type equation is mutual subtyping ({!S.equal_ty}).

    {2 Variables}

    Unknowns are named symbols of three sorts: type parameters, resource
    variables and effect variables. A variable is bound by at most one binder of
    a constraint; substitution does not enter a binder for the variables it
    binds. *)

module Ast = Language.Ast

type part = Format.formatter -> unit

(** A conjunct of the qualifier of a scheme. *)
type conjunct =
  | Formula of part  (** printed on one line, as a conjunct of a formula *)
  | Ordering of { binder : part option; left : part; right : part }
      (** [left ≾ right], or [(∀ε_Op. left ≾ right)] with the [binder] [ε_Op] of
          a rigid variable *)

type layout = {
  parameters : part option;  (** [α ρ₀ ε₀], when present *)
  conjuncts : conjunct list;  (** those of the qualifier [Q ∧ R] *)
  arrows : part Language.PrettyPrint.arrows;
      (** the type, in parts around its arrows *)
}
(** The parts of a scheme, for a layout of its own. *)

module type S = sig
  module X : GradeExp.S
  (** The grade expressions. *)

  type rho = X.rho
  (** Resource-grade expressions. *)

  type eps = X.eps
  (** Effect-grade expressions. *)

  type ty = (rho, eps) Ast.ty
  (** Open value types. *)

  type comp_ty = (rho, eps) Ast.comp_ty
  (** Open computation types. *)

  type reason = (rho, eps) Reason.t
  (** Reasons at open grades. *)

  type vars = {
    ty_vars : Ast.ty_param list;
    rho_vars : X.Rho_var.t list;
    eps_vars : X.Eps_var.t list;
  }
  (** Unknowns of the three sorts. *)

  val no_vars : vars
  (** No unknowns. *)

  val union_vars : vars -> vars -> vars
  (** [union_vars vs vs'] is the unknowns of [vs] followed by those of [vs']. *)

  (** Constraints. *)
  type t =
    | True  (** trivially satisfied *)
    | And of t * t  (** conjunction *)
    | Sub of reason * ty * ty  (** value-type subtyping [A <: B] *)
    | Rho_leq of reason * rho * rho  (** resource-grade ordering [ρ ≾ ρ'] *)
    | Eps_leq of reason * eps * eps  (** effect-grade ordering [ε ≾ ε'] *)
    | Eternal of reason * ty  (** eternality of a type *)
    | Eternal_or_unit of reason * ty * rho
        (** the disjunction [Et(A) ∨ ρ ≾ 1] of the variable rule *)
    | Exists of vars * t  (** a scope of fresh unknowns *)
    | Forall_eps of X.Eps_var.t * Reason.rigid_origin * t
        (** a rigid effect variable, the continuation effect of the handler
            clause it originates from *)

  val conj : t -> t -> t
  (** [conj c d] is the conjunction of [c] and [d], [True] being dropped. *)

  val conj_all : t list -> t
  (** [conj_all cs] is the conjunction of [cs], [True] for none. *)

  val exists : vars -> t -> t
  (** [exists vs c] is [c] in a scope of [vs], merged with a scope directly
      below and omitted when [vs] is empty. *)

  val equal_ty : reason -> ty -> ty -> t
  (** [equal_ty reason a b] is the type equation [a ≐ b], [a <: b ∧ b <: a]. *)

  val map_reasons : (reason -> reason) -> t -> t
  (** [map_reasons f c] replaces the reason of each atom of [c] by its image
      under [f]. *)

  type subst = { ty_subst : ty Ast.TyParamMap.t; grade_subst : X.subst }
  (** A simultaneous substitution of the three sorts, the identity outside its
      domain. *)

  val empty_subst : subst
  (** The identity substitution. *)

  val subst_ty : subst -> ty -> ty
  (** [subst_ty sigma a] applies [sigma] to [a]. *)

  val subst_reason : subst -> reason -> reason
  (** [subst_reason sigma reason] applies [sigma] to the grades of [reason]. *)

  val subst : subst -> t -> t
  (** [subst sigma c] applies [sigma] to the free unknowns of [c] and to the
      grades of its reasons. *)

  val freshen : subst -> t -> t
  (** [freshen sigma c] is [subst sigma c] with every unknown bound in [c]
      renamed to a fresh one. *)

  type free = {
    free_tys : Ast.TyParamSet.t;
    free_rhos : X.Rho_var.Set.t;
    free_eps : X.Eps_var.Set.t;
  }
  (** Sets of unknowns of the three sorts. *)

  val no_free : free
  (** The empty sets. *)

  val union_free : free -> free -> free
  (** [union_free f f'] is the sortwise union. *)

  val free_vars_ty : ty -> free
  (** [free_vars_ty a] is the unknowns of [a]. *)

  val free_vars_comp_ty : comp_ty -> free
  (** [free_vars_comp_ty c] is the unknowns of [c]. *)

  val free_vars : t -> free
  (** [free_vars c] is the unknowns of the atoms of [c] outside its binders;
      reasons are not consulted. *)

  type scheme = {
    ty_params : Ast.ty_param list;
    rho_params : X.Rho_var.t list;
    eps_params : X.Eps_var.t list;
    qualifier : t;
        (** the atoms and rigid obligations an instance owes, [Q ∧ R] *)
    ty : ty;
  }
  (** A qualified type scheme [∀ᾱ ρ̄ ε̄. Q ∧ R ⇒ A]. *)

  val monomorphic : ty -> scheme
  (** [monomorphic a] is [a] as a scheme without parameters or qualifier. *)

  val instantiate : scheme -> ty * t
  (** [instantiate scheme] renames the parameters of [scheme] and the unknowns
      bound in its qualifier to fresh ones, and is the renamed type and
      qualifier. *)

  type names
  (** The names a printer gives to unknowns, by order of first occurrence. *)

  val is_unit_eps : Grades.Grade.bounds -> eps -> bool
  (** [is_unit_eps bounds eps] decides whether the canonical form of [eps] is a
      constant equal to the unit under the running times [bounds]. *)

  val names : ?bounds:Grades.Grade.bounds -> unit -> names
  (** [names ~bounds ()] is a fresh naming. A computation type whose effect is
      the unit ({!is_unit_eps} under [bounds], by default the running times of
      no operations) is printed without its effect. *)

  val print_rho : ?names:names -> rho -> Format.formatter -> unit
  (** [print_rho ~names rho ppf] prints [rho]. *)

  val print_eps : ?names:names -> eps -> Format.formatter -> unit
  (** [print_eps ~names eps ppf] prints [eps]. *)

  val print_ty : ?names:names -> ty -> Format.formatter -> unit
  (** [print_ty ~names a ppf] prints [a], every effect shown. *)

  val print : ?names:names -> t -> Format.formatter -> unit
  (** [print ~names c ppf] prints [c], one atom per line, binders indented:
      [A <: B], [ρ ≾ ρ'], [Et(A)], [Et(A) ∨ ρ ≾ 1], [∃α ρ₀ ε₀.], [∀ε_Op.], a
      rigid variable named after the operation of its clause. Without [names],
      unknowns are numbered afresh. *)

  val to_string : t -> string
  (** [to_string c] is the text {!print} prints. *)

  val print_inline : ?names:names -> t -> Format.formatter -> unit
  (** [print_inline ~names c ppf] prints [c] as one formula, its conjuncts
      joined by [∧], a binder or a disjunction within a conjunction in
      parentheses. *)

  val print_scheme : ?names:names -> scheme -> Format.formatter -> unit
  (** [print_scheme ~names scheme ppf] prints [scheme] as
      [∀ α ρ₀ ε₀. Q ∧ R ⇒ A], the quantifier omitted when it binds nothing and
      the qualifier when it is [⊤]. The parameters are listed, and named, in the
      order of their first occurrence in [A] and then in [Q ∧ R]. *)

  val scheme_layout : ?names:names -> scheme -> layout
  (** [scheme_layout ~names scheme] is the parts of [scheme] that
      {!print_scheme} prints. The printers share one naming and are applied in
      the order of the fields, the binder of an ordering before its sides. *)
end

(** [Make (X)] is the constraints over the grade expressions [X]. *)
module Make (X : GradeExp.S) : S with module X = X
