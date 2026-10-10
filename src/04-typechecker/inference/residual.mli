(** The residual of constraint solving: the atoms not yet decided, each with its
    {!Reason.t}, their decomposition, and their reading as hypotheses.

    {2 Atoms}

    The residual holds subtyping demands, eternality demands, var-rule
    disjunctions [Et(A) ∨ ρ ≾ 1], orderings of both grade sorts and deferred
    rigid conditions. Once decomposed, a subtyping demand relates two type
    unknowns and an eternality demand is on a type unknown.

    {2 Decomposition}

    Subtyping between types of the same shape decomposes as recorded in
    {!Constraint}: function domains contravariantly, box grades contravariantly,
    computation effects covariantly, tuples componentwise, type-application
    arguments and handler inputs as equations, handler outputs covariantly,
    constants by equality. An application of an alias is unfolded first.

    A type reduces to the type unknowns its eternality depends on, or is never
    eternal: an arrow, a box, a handler and a type declared [noneternal] never
    are; a type application is unfolded through its definition, a recursive
    occurrence being eternal.

    {2 Eager decisions}

    An ordering between variable-free sides is decided when it is pushed:
    dropped when true, refuting when false. An ordering with an unknown is kept
    even when decided at no hypotheses, as a bound on its unknowns that the
    simplification of a report reads ({!Report}). A var-rule disjunction is
    dropped when its grade is decided below the unit; otherwise, of a type never
    eternal, it becomes the ordering of its grade below the unit; of a type
    eternal outright, it is dropped; otherwise it is kept. *)

module Ast = Language.Ast

type ('rho, 'eps) types = {
  bounds : Grades.Grade.bounds;
      (** the running times the grades' order reads *)
  find_definition :
    Ast.ty_name -> (Ast.ty_param list * ('rho, 'eps) Ast.ty_def) option;
      (** the parameters and definition of a type name *)
  is_noneternal : Ast.ty_name -> bool;
      (** whether a type name is declared [noneternal] *)
}
(** What decomposition reads of the program: the running times and the type
    definitions. *)

module Make (C : Constraint.S) : sig
  type rho = C.rho
  (** Resource-grade expressions. *)

  type eps = C.eps
  (** Effect-grade expressions. *)

  type ty = C.ty
  (** Open types. *)

  type reason = C.reason
  (** Reasons. *)

  type context = (rho, eps) types
  (** The running times and type definitions at open grades. *)

  (** {1 Atoms} *)

  type rho_ordering = (rho, reason) GradeNormal.ordering
  (** A resource-grade ordering. *)

  type eps_ordering = (eps, reason) GradeNormal.ordering
  (** An effect-grade ordering. *)

  type sub = (ty, reason) GradeNormal.ordering
  (** A subtyping demand [lhs <: rhs]. *)

  type eternal = { eternal_ty : ty; eternal_reason : reason }
  (** An eternality demand. *)

  type disjunction = { disj_ty : ty; disj_grade : rho; disj_reason : reason }
  (** A var-rule disjunction [Et(disj_ty) ∨ disj_grade ≾ 1]. *)

  type deferred = {
    origin : Reason.rigid_origin;
        (** the clause whose scope deferred the conditions *)
    rigids : (C.X.Eps_var.t * Reason.rigid_origin) list;
        (** the rigid variables the conditions are universally quantified over,
            outermost first, each with its clause *)
    rho_conditions : rho_ordering list;
    eps_conditions : eps_ordering list;
  }
  (** A deferred rigid condition: orderings over outer unknowns and rigid
      variables that must hold for every value of the rigids. The rigids are
      bound: distinct from every unknown outside the condition. *)

  type t = {
    rho_orderings : rho_ordering list;
    eps_orderings : eps_ordering list;
    eternals : eternal list;
    subs : sub list;
    disjunctions : disjunction list;
    deferred : deferred list;
  }
  (** A residual. *)

  val empty : t
  (** The residual with no atoms. *)

  val union : t -> t -> t
  (** [union r r'] has the atoms of [r] followed by those of [r']. *)

  val subst : C.subst -> t -> t
  (** [subst sigma r] applies [sigma] to every atom of [r] and to the grades of
      its reasons. *)

  val free_vars_deferred : deferred -> C.free
  (** [free_vars_deferred d] is the unknowns of the conditions of [d] other than
      its rigids. *)

  (** {1 Grade unknowns} *)

  (** A grade unknown of either sort. *)
  type grade_unknown =
    | Rho_unknown of C.X.Rho_var.t
    | Eps_unknown of C.X.Eps_var.t

  val in_rho : grade_unknown -> rho -> bool
  (** [in_rho u rho] is whether [u] occurs in [rho], an effect unknown under an
      image. *)

  val in_eps : grade_unknown -> eps -> bool
  (** [in_eps u eps] is whether [u] occurs in [eps]. *)

  val assign_rho : C.X.Rho_var.t -> rho -> C.X.subst
  (** [assign_rho k rho] is the substitution sending [k] to [rho]. *)

  val assign_eps : C.X.Eps_var.t -> eps -> C.X.subst
  (** [assign_eps k eps] is the substitution sending [k] to [eps]. *)

  (** {1 Failures} *)

  (** Why a constraint has no solution, or, for a run, is not shown to have one.
  *)
  type failure =
    | Shape_mismatch of reason Skeleton.failure
        (** two types of different shapes are related *)
    | Occurs_check of reason Skeleton.failure
        (** a type unknown is related to a type that contains it *)
    | Refuted_rho of (rho, reason list) GradeNormal.ordering
        (** a resource ordering between variable-free sides fails; the reasons
            are those of the atoms it follows from, along the chain *)
    | Refuted_eps of (eps, reason list) GradeNormal.ordering
        (** an effect ordering between variable-free sides fails *)
    | Never_eternal of { ty : ty; reason : reason }
        (** a type demanded eternal is eternal at no instance *)
    | Refuted_condition of {
        condition : deferred;
            (** the deferred condition, with the failing ordering alone *)
        witness : C.X.GS.E.t list;
            (** the values of its rigids at which the ordering fails *)
      }  (** a deferred condition fails at some value of its rigids *)
    | Undecided_condition of deferred
        (** a deferred condition of a run, closed, that is neither discharged
            nor refuted; its first ordering is reported *)
    | Unestablished of {
        rho_orderings : rho_ordering list;
            (** the resource orderings of a component of unknowns *)
        eps_orderings : eps_ordering list;  (** its effect orderings *)
        conditions : deferred list;  (** its deferred conditions *)
        abandoned : bool;
            (** whether the trials ran out before every candidate was tried *)
      }
        (** a run's qualifier has no closed instance among the grades tried: the
            atoms of a component hold together at none of them *)
    | Rigid_escape of Reason.rigid_origin
        (** the rigid variable of the clause occurs in the value of an unknown
            outside it *)

  (** {1 Decomposition} *)

  val unfold_alias : context -> ty -> ty option
  (** [unfold_alias context ty] is the definition of the alias [ty] applies at
      its arguments, and [None] for another type. *)

  val skeleton_unfold : context -> Skeleton.unfold
  (** [skeleton_unfold context] unfolds the skeletons of alias applications. *)

  (** {1 Disjunctions} *)

  type settling = {
    below_unit : rho -> bool;
        (** whether a grade is decided below the unit at this stage *)
    eternal : Ast.ty_param -> bool;
        (** whether a type unknown is entailed eternal at this stage *)
    refute : bool;
        (** whether a grade refuted below the unit by the zero-product law
            ({!Entail.Make.SORT.refute_leq_unit}) settles the disjunction by
            eternality *)
  }
  (** The evidence a stage of solving settles disjunctions with. *)

  (** The outcome of settling a disjunction [Et(A) ∨ ρ ≾ 1]. *)
  type settled =
    | Drop  (** it holds *)
    | Below_unit of rho_ordering  (** it is equivalent to [ρ ≾ 1] *)
    | Eternal of eternal list
        (** it is equivalent to the eternality of these type unknowns *)
    | Keep  (** it is not settled *)

  val by_grade : (rho -> bool) -> settling
  (** [by_grade below_unit] settles by [below_unit] alone: no type unknown is
      taken to be eternal, and no grade refuted below the unit. *)

  val settle : context -> settling -> disjunction -> settled
  (** [settle context s d] settles [d]: dropped when its grade is below the unit
      by [s.below_unit]; its grade below the unit when its type is never
      eternal; dropped when the type unknowns its type's eternality depends on
      are all eternal by [s.eternal], in particular when there are none; their
      eternality when [s.refute] and its grade is refuted below the unit; and
      kept otherwise. *)

  val push_rho : context -> rho_ordering -> t -> (t, failure) result
  (** [push_rho context o r] adds [o] to [r]; when [o] is variable-free it is
      dropped when true and refuting when false. *)

  val push_eps : context -> eps_ordering -> t -> (t, failure) result
  (** [push_eps context o r] is {!push_rho} for an effect ordering. *)

  val push_eternal : context -> eternal -> t -> (t, failure) result
  (** [push_eternal context e r] adds to [r] the demands on the type unknowns
      the eternality of [e] depends on.

      [Error (Never_eternal _)] when its type is eternal at no instance. *)

  val push_disjunction : context -> disjunction -> t -> (t, failure) result
  (** [push_disjunction context d r] adds [d] to [r] by the var rule: dropped
      when its grade is decided below the unit or its type is eternal outright,
      its grade below the unit when its type is never eternal, and kept
      otherwise. *)

  val push_sub : context -> sub -> t -> (t, failure) result
  (** [push_sub context s r] adds to [r] the atoms of the subtyping demand [s],
      whose two sides have the same shape: demands between type unknowns and
      grade orderings along {!Former.decompose}, each reason extended by the
      position it comes from.

      [Error (Shape_mismatch _)] when the shapes differ. *)

  val atomise : context -> t -> (t, failure) result
  (** [atomise context r] decomposes again the subtyping and eternality demands
      of [r] that are not on type unknowns, and decides again the types of its
      disjunctions. *)

  (** {1 Hypotheses} *)

  type hyps = {
    eternal_hyps : eternal list;  (** type unknowns assumed eternal *)
    sub_vars : sub list;  (** subtyping assumed between type unknowns *)
    rho_hyps : rho_ordering list;
    eps_hyps : eps_ordering list;
    disj_hyps : disjunction list;
  }
  (** Assumptions on the unknowns: the atoms a solution leaves. *)

  val to_hyps : context -> t -> (hyps, failure) result
  (** [to_hyps context r] reads the atoms of [r] other than its deferred
      conditions as hypotheses, decomposing them first. *)

  val check_closed : ?factors:bool -> context -> hyps -> (hyps, failure) result
  (** [check_closed ~factors context hyps] decides by the grades' order every
      ordering between variable-free sides, of the hypotheses and of the chains
      of two or more steps. The chains run along the hypotheses and, when
      [factors] (the default), from a factor of a product to the product when
      the other factors are above the unit, by the grade or along the grade
      orderings of [hyps] ({!Entail.Make.check_closed}); the disjunctions of
      [hyps] do not serve as evidence. A disjunction is then dropped when its
      grade follows below the unit from the grade orderings left
      ({!Entail.Make.SORT.follows}), and refutes when its grade is variable-free
      and not below the unit and its type never eternal. It is the hypotheses
      less those decided true, or the failure of the first decided false. *)

  val hyps_to_constraint : hyps -> C.t
  (** [hyps_to_constraint hyps] is the conjunction of the atoms of [hyps]. *)

  val deferred_to_constraint : deferred -> C.t
  (** [deferred_to_constraint d] is the conditions of [d] under a rigid scope of
      each of its rigids. *)

  (** {1 Printing} *)

  val print_failure : failure -> Format.formatter -> unit
  (** [print_failure failure ppf] prints [failure], for debugging. *)
end
