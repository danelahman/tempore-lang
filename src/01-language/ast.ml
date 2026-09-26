module Location = Utils.Location
module Symbol = Utils.Symbol
module Variable = Symbol.Make ()
module VariableMap = Map.Make (Variable)
module Label = Symbol.Make ()
module TyName = Symbol.Make ()

type ty_name = TyName.t

module TyNameMap = Map.Make (TyName)
module TyNameSet = Set.Make (TyName)
module TyParamModule = Symbol.Make ()
module TyParamMap = Map.Make (TyParamModule)
module TyParamSet = Set.Make (TyParamModule)

type ty_param = TyParamModule.t

module RhoParamModule = Symbol.Make ()
module RhoParamMap = Map.Make (RhoParamModule)
module RhoParamSet = Set.Make (RhoParamModule)

type rho_param = RhoParamModule.t

module EpsParamModule = Symbol.Make ()
module EpsParamMap = Map.Make (EpsParamModule)
module EpsParamSet = Set.Make (EpsParamModule)

type eps_param = EpsParamModule.t

module OpName = Symbol.Make ()
module OpNameMap = Map.Make (OpName)
module OpNameSet = Set.Make (OpName)

type operation = OpName.t

(** Resource grade expressions over the resource grades ['rho]. *)
type 'rho rho =
  | RhoConst of 'rho
  | RhoParam of rho_param  (** an unknown grade, solved by unification *)
  | RhoAdd of 'rho rho * 'rho rho  (** the product of two grades *)

(** Effect grade expressions over the effect grades ['eps]. *)
type 'eps eps =
  | EpsConst of 'eps
  | EpsParam of eps_param  (** an unknown grade, solved by unification *)
  | EpsRigid of eps_param
      (** the grade of a handler continuation: universally quantified, so it is
          never substituted and may not occur in the type of a definition *)
  | EpsAdd of 'eps eps * 'eps eps  (** the product of two grades *)

(** Types, over the grades ['rho] of resources and ['eps] of effects: a box is
    graded by a resource grade, a computation by an effect grade. Nothing else
    is assumed about ['rho] and ['eps]. *)
type ('rho, 'eps) ty =
  | TyConst of Const.ty
  | TyApply of ty_name * ('rho, 'eps) ty list
      (** [(ty1, ty2, ..., tyn) type_name] *)
  | TyParam of ty_param  (** ['a] *)
  | TyArrow of ('rho, 'eps) ty * ('rho, 'eps) comp_ty  (** [ty1 -> ty2 ! eps] *)
  | TyTuple of ('rho, 'eps) ty list  (** [ty1 * ty2 * ... * tyn] *)
  | TyBox of 'rho * ('rho, 'eps) ty  (** [ [rho]ty ] *)
  | TyHandler of ('rho, 'eps) comp_ty * ('rho, 'eps) comp_ty

and ('rho, 'eps) comp_ty = CompTy of ('rho, 'eps) ty * 'eps  (** [ty ! eps] *)

let bool_ty_name = TyName.fresh "bool"
let int_ty_name = TyName.fresh "int"
let unit_ty_name = TyName.fresh "unit"
let string_ty_name = TyName.fresh "string"
let float_ty_name = TyName.fresh "float"
let list_ty_name = TyName.fresh "list"
let empty_ty_name = TyName.fresh "empty"

type variable = Variable.t
type label = Label.t

let nil_label_string = "$nil$"
let nil_label = Label.fresh nil_label_string
let cons_label_string = "$cons$"
let cons_label = Label.fresh cons_label_string

type rigid_origin = {
  op : operation;
  continuation : variable option;
  case_at : Location.t;
  continuation_at : Location.t;
}
(** Where a rigid continuation grade was introduced, so that a message can name
    the continuation it belongs to. [continuation] is the variable the case
    binds it to, when the pattern is one. *)

(** How a grade came to be accumulated, for the messages that explain why a
    variable may no longer be used. *)
type elapsed_kind =
  | Delayed of int  (** [delay n] *)
  | Performed of operation  (** [perform Op] *)
  | Sequenced  (** the grade of a computation bound by [let] or [;] *)
  | Boxed  (** the value of a [box ρ] is checked ρ ahead *)
  | Handled
      (** the return clause of a handler runs after the handled computation *)

(** The position within a type equation a decomposed equation came from. *)
type step =
  | Argument
  | Result  (** of a function type *)
  | Component of int  (** of a tuple, from 1 *)
  | TypeArgument of int  (** of a type application, from 1 *)
  | BoxContent
  | HandlerInput
  | HandlerOutput

(** Why a constraint was generated. Each constructor carries the places its
    messages point at, so a message cannot ask for one the reason lacks. *)
type 'a why =
  | Application of { func_at : Location.t; arg_at : Location.t }
  | MatchScrutinee of { scrutinee_at : Location.t }  (** at = the pattern *)
  | MatchBranch
      (** at = the branch body; its type and grade must agree with the earlier
          branches *)
  | Annotation  (** at = the annotated expression *)
  | PatternAnnotation
  | VariantArgument of label
  | BoxedValue  (** at = the box *)
  | Unboxed of {
      var : variable;
      bound_at : Location.t option;
      elapsed : ('a eps * Location.t * elapsed_kind) list;
    }
  | UseAfterTime of {
      var : variable;
      bound_at : Location.t;
      elapsed : ('a eps * Location.t * elapsed_kind) list;
    }
  | InstanceOf of {
      var : variable;
      defined_at : Location.t option;
      inner : 'a reason;
    }
  | HandlerCase of { op : operation; signature_at : Location.t }
  | ContinuationGrade of { op : operation; signature_at : Location.t }
      (** the case's grade ≾ the grade of [Op] plus the continuation's *)
  | OpCaseCapture of {
      var : variable;
      bound_at : Location.t;
      op : operation;
      signature_at : Location.t;
      case_at : Location.t;
      elapsed : ('a eps * Location.t * elapsed_kind) list;
    }
      (** a variable bound outside the case for [op] is used inside it, where
          only an eternal type survives *)
  | PerformArgument of { op : operation; signature_at : Location.t }
  | PerformContinuation of { op : operation; signature_at : Location.t }
  | HandleWith  (** at = the handler expression of a [handle] *)
  | RecursiveDefinition of variable
  | PureBody  (** a pure or recursive function body has grade 0 *)
  | Sequencing
      (** [Do]: the bound computation's grade names the context entry *)
  | DefaultOf of { op : operation; signature_at : Location.t }

and 'a reason = {
  at : Location.t;
  why : 'a why;
  path : step list;
  stated : ('a eps * 'a eps) option;
      (** An inequality as it was generated, before the solver cancelled what
          its two sides have in common; [None] for the other constraints and for
          one that was never cancelled, which states itself. *)
}
(** [at] is the construct the constraint was generated for, [path] the position
    within it a decomposed equation came from, innermost last.

    The elapsed grades are the one thing a reason carries that inference has yet
    to decide; {!substitute_constr} solves them along with the constraint.
    Everything else is plain data — no types, no closures — so that two reasons
    may be compared with polymorphic equality. *)

(** The constraints of a typing derivation besides the equations unification
    solves. Those left over qualify the definition's generalised scheme.

    The typechecker that generates them grades resources and effects alike by
    the one carrier ['a], and represents the grades of both sorts as effect
    grade expressions: a constraint does not record the sort of the grades it
    compares. *)
type 'a constr =
  | Ineq of 'a eps * 'a eps * 'a reason  (** [eps1] is a sub-grade of [eps2] *)
  | Eternal of ('a eps, 'a eps) ty * 'a reason  (** the type is eternal *)
  | EternalOrIneq of ('a eps, 'a eps) ty * 'a eps * 'a eps * 'a reason
      (** the type is eternal, or [eps1] is a sub-grade of [eps2] *)

type 'a ty_scheme = {
  ty_params : ty_param list;
  eps_params : eps_param list;
  constrs : 'a constr list;
  ty : ('a eps, 'a eps) ty;
}
(** A generalised type. It lives here rather than in the typechecker because
    {!PrettyPrint} prints it and the variable context stores it. *)

(* After [reason], which has an [at] of its own: an unannotated [.at] resolves
   to the last declared, and almost every [.at] wants a syntax node's span. *)
type 'a located = 'a Location.located = { it : 'a; at : Location.t }

let located at it = { it; at }

(* Patterns, expressions and computations carry the span they were desugared
   from; types do not, since unification rebuilds them out of no source. The
   grade of [box ρ] is a resource grade, that of an operation signature an
   effect grade. *)
type ('rho, 'eps) pattern = ('rho, 'eps) plain_pattern located

and ('rho, 'eps) plain_pattern =
  | PVar of variable
  | PAnnotated of ('rho, 'eps) pattern * ('rho, 'eps) ty
  | PAs of ('rho, 'eps) pattern * variable
  | PTuple of ('rho, 'eps) pattern list
  | PVariant of label * ('rho, 'eps) pattern option
  | PConst of Const.t
  | PNonbinding

type ('rho, 'eps) expression = ('rho, 'eps) plain_expression located

and ('rho, 'eps) plain_expression =
  | Var of variable
  | Const of Const.t
  | Annotated of ('rho, 'eps) expression * ('rho, 'eps) ty
  | Tuple of ('rho, 'eps) expression list
  | Variant of label * ('rho, 'eps) expression option
  | Lambda of ('rho, 'eps) abstraction
  | PureLambda of ('rho, 'eps) abstraction
  | RecLambda of variable * ('rho, 'eps) abstraction
  | Handler of ('rho, 'eps) abstraction * ('rho, 'eps) abstraction OpNameMap.t

and ('rho, 'eps) computation = ('rho, 'eps) plain_computation located

and ('rho, 'eps) plain_computation =
  | Return of ('rho, 'eps) expression
  | Do of ('rho, 'eps) computation * ('rho, 'eps) abstraction
  | Match of ('rho, 'eps) expression * ('rho, 'eps) abstraction list
  | Apply of ('rho, 'eps) expression * ('rho, 'eps) expression
  | Delay of int * ('rho, 'eps) computation
  | Box of 'rho * ('rho, 'eps) expression * ('rho, 'eps) abstraction
  | Unbox of ('rho, 'eps) expression * ('rho, 'eps) abstraction
  | Perform of operation * ('rho, 'eps) expression * ('rho, 'eps) abstraction
  | Handle of ('rho, 'eps) computation * ('rho, 'eps) expression

and ('rho, 'eps) abstraction = ('rho, 'eps) pattern * ('rho, 'eps) computation

(* A stable order on expressions built from different constructors.
   [Annotated] is looked through before a rank is ever taken. *)
let expression_rank = function
  | Var _ -> 0
  | Const _ -> 1
  | Annotated _ -> 2
  | Tuple _ -> 3
  | Variant _ -> 4
  | Lambda _ -> 5
  | PureLambda _ -> 6
  | RecLambda _ -> 7
  | Handler _ -> 8

(** Structural comparison of value expressions, ignoring their spans: the
    comparison primitives must not tell two equal constants on different lines
    apart. Functions and handlers, rejected by the caller, are only ranked. *)
let rec compare_expression e1 e2 =
  match (e1.it, e2.it) with
  | Annotated (e1', _), _ -> compare_expression e1' e2
  | _, Annotated (e2', _) -> compare_expression e1 e2'
  | Var x, Var y -> Variable.compare x y
  | Const c1, Const c2 -> Stdlib.compare c1 c2
  | Tuple es1, Tuple es2 -> compare_expressions es1 es2
  | Variant (lbl1, arg1), Variant (lbl2, arg2) -> (
      match Label.compare lbl1 lbl2 with
      | 0 -> (
          match (arg1, arg2) with
          | None, None -> 0
          | None, Some _ -> -1
          | Some _, None -> 1
          | Some arg1, Some arg2 -> compare_expression arg1 arg2)
      | c -> c)
  | plain1, plain2 ->
      Int.compare (expression_rank plain1) (expression_rank plain2)

and compare_expressions es1 es2 =
  match (es1, es2) with
  | [], [] -> 0
  | [], _ :: _ -> -1
  | _ :: _, [] -> 1
  | e1 :: es1, e2 :: es2 -> (
      match compare_expression e1 e2 with
      | 0 -> compare_expressions es1 es2
      | c -> c)

type ('rho, 'eps) ty_def =
  | TySum of (label * ('rho, 'eps) ty option) list
  | TyInline of ('rho, 'eps) ty

(* Whether the eternality of a type definition is computed from its structure,
   as usual ([Derived]), or fixed to non-eternal by a [noneternal type ...]
   declaration ([Noneternal]). *)
type eternality = Derived | Noneternal

type ('rho, 'eps) plain_command =
  | TyDef of eternality * (ty_param list * ty_name * ('rho, 'eps) ty_def) list
  | OpSig of
      (operation
      * ('rho, 'eps) ty
      * ('rho, 'eps) ty
      * 'eps
      * (int * int) option)
  | OpDefault of operation * ('rho, 'eps) abstraction
  | TopLet of variable * ('rho, 'eps) expression
  | TopDo of ('rho, 'eps) computation

type ('rho, 'eps) command = ('rho, 'eps) plain_command located

(** The types and terms of a program graded by [GS], whose grades are grade
    expressions over the resource grades [GS.R] ({!rho}) and the effect grades
    [GS.E] ({!eps}): the program as the parser, the desugarer and the
    interpreter handle it. *)
module Graded (GS : GradeSystem.S) = struct
  type nonrec rho = GS.R.t rho
  type nonrec eps = GS.E.t eps
  type nonrec ty = (rho, eps) ty
  type nonrec comp_ty = (rho, eps) comp_ty
  type nonrec pattern = (rho, eps) pattern
  type nonrec expression = (rho, eps) expression
  type nonrec computation = (rho, eps) computation
  type nonrec abstraction = (rho, eps) abstraction
  type nonrec ty_def = (rho, eps) ty_def
  type nonrec command = (rho, eps) command
end

(* [Barrier] marks where an operation case restricts the ambient context. It
   carries no grade and takes no part in the grade arithmetic. *)
type ('var, 'map, 'rho, 'bar) context_elem_ty =
  | VarMap of 'map
  | Rho of 'rho
  | Barrier of 'bar

type ('var, 'map, 'rho, 'bar) context =
  ('var, 'map, 'rho, 'bar) context_elem_ty list

(** [map_ty ~on_rho ~on_eps ty] applies [on_rho] to the resource grades of [ty]
    and [on_eps] to its effect grades. *)
let rec map_ty ~on_rho ~on_eps = function
  | TyConst c -> TyConst c
  | TyParam a -> TyParam a
  | TyApply (ty_name, tys) ->
      TyApply (ty_name, List.map (map_ty ~on_rho ~on_eps) tys)
  | TyTuple tys -> TyTuple (List.map (map_ty ~on_rho ~on_eps) tys)
  | TyArrow (ty, cty) ->
      TyArrow (map_ty ~on_rho ~on_eps ty, map_comp_ty ~on_rho ~on_eps cty)
  | TyBox (rho, ty) -> TyBox (on_rho rho, map_ty ~on_rho ~on_eps ty)
  | TyHandler (cty1, cty2) ->
      TyHandler
        (map_comp_ty ~on_rho ~on_eps cty1, map_comp_ty ~on_rho ~on_eps cty2)

and map_comp_ty ~on_rho ~on_eps (CompTy (ty, eps)) =
  CompTy (map_ty ~on_rho ~on_eps ty, on_eps eps)

(** [substitute_ty ty_subst ~on_rho ~on_eps ty] replaces the type parameters of
    [ty] bound in [ty_subst], and applies [on_rho] to its resource grades and
    [on_eps] to its effect grades. *)
let rec substitute_ty ty_subst ~on_rho ~on_eps = function
  | TyConst _ as ty -> ty
  | TyParam a as ty -> (
      match TyParamMap.find_opt a ty_subst with None -> ty | Some ty' -> ty')
  | TyApply (ty_name, tys) ->
      TyApply (ty_name, List.map (substitute_ty ty_subst ~on_rho ~on_eps) tys)
  | TyTuple tys ->
      TyTuple (List.map (substitute_ty ty_subst ~on_rho ~on_eps) tys)
  | TyArrow (ty, cty) ->
      TyArrow
        ( substitute_ty ty_subst ~on_rho ~on_eps ty,
          substitute_comp_ty ty_subst ~on_rho ~on_eps cty )
  | TyBox (rho, ty) ->
      TyBox (on_rho rho, substitute_ty ty_subst ~on_rho ~on_eps ty)
  | TyHandler (cty1, cty2) ->
      TyHandler
        ( substitute_comp_ty ty_subst ~on_rho ~on_eps cty1,
          substitute_comp_ty ty_subst ~on_rho ~on_eps cty2 )

and substitute_comp_ty ty_subst ~on_rho ~on_eps (CompTy (ty, eps)) =
  CompTy (substitute_ty ty_subst ~on_rho ~on_eps ty, on_eps eps)

(** [fold_ty ~on_param ~on_rho ~on_eps ty acc] folds [on_param] over the type
    parameters of [ty], [on_rho] over its resource grades and [on_eps] over its
    effect grades. *)
let rec fold_ty ~on_param ~on_rho ~on_eps ty acc =
  match ty with
  | TyConst _ -> acc
  | TyParam a -> on_param a acc
  | TyApply (_, tys) | TyTuple tys ->
      List.fold_left
        (fun acc ty -> fold_ty ~on_param ~on_rho ~on_eps ty acc)
        acc tys
  | TyArrow (ty, cty) ->
      fold_comp_ty ~on_param ~on_rho ~on_eps cty
        (fold_ty ~on_param ~on_rho ~on_eps ty acc)
  | TyBox (rho, ty) -> fold_ty ~on_param ~on_rho ~on_eps ty (on_rho rho acc)
  | TyHandler (cty1, cty2) ->
      fold_comp_ty ~on_param ~on_rho ~on_eps cty2
        (fold_comp_ty ~on_param ~on_rho ~on_eps cty1 acc)

and fold_comp_ty ~on_param ~on_rho ~on_eps (CompTy (ty, eps)) acc =
  on_eps eps (fold_ty ~on_param ~on_rho ~on_eps ty acc)

(* What follows serves the typechecker that grades resources and effects alike,
   representing the grades of both sorts as effect grade expressions. *)

let rec substitute_eps subst = function
  | (EpsConst _ | EpsRigid _) as eps -> eps
  | EpsParam p as eps -> (
      match EpsParamMap.find_opt p subst with None -> eps | Some eps' -> eps')
  | EpsAdd (eps, eps') ->
      EpsAdd (substitute_eps subst eps, substitute_eps subst eps')

(** [substitute_eps_ty ty_subst eps_subst ty] is {!substitute_ty} substituting
    by [eps_subst] in the grades of both sorts. *)
let substitute_eps_ty ty_subst eps_subst =
  substitute_ty ty_subst ~on_rho:(substitute_eps eps_subst)
    ~on_eps:(substitute_eps eps_subst)

let substitute_eps_comp_ty ty_subst eps_subst =
  substitute_comp_ty ty_subst ~on_rho:(substitute_eps eps_subst)
    ~on_eps:(substitute_eps eps_subst)

(** Elapsed grades are solved like any other, so reasons are substituted into
    too: else a label would report the parameter a [let] contributed rather than
    the grade it stands for, which is often nothing at all. *)
let rec substitute_reason eps_subst reason =
  let elapsed =
    List.map (fun (eps, at, kind) -> (substitute_eps eps_subst eps, at, kind))
  in
  let why =
    match reason.why with
    | Unboxed u -> Unboxed { u with elapsed = elapsed u.elapsed }
    | UseAfterTime u -> UseAfterTime { u with elapsed = elapsed u.elapsed }
    | OpCaseCapture u -> OpCaseCapture { u with elapsed = elapsed u.elapsed }
    | InstanceOf i ->
        InstanceOf { i with inner = substitute_reason eps_subst i.inner }
    | why -> why
  in
  let stated =
    Option.map
      (fun (eps1, eps2) ->
        (substitute_eps eps_subst eps1, substitute_eps eps_subst eps2))
      reason.stated
  in
  { reason with why; stated }

let substitute_constr ty_subst eps_subst =
  let reason_of = substitute_reason eps_subst in
  function
  | Ineq (eps1, eps2, reason) ->
      Ineq
        ( substitute_eps eps_subst eps1,
          substitute_eps eps_subst eps2,
          reason_of reason )
  | Eternal (ty, reason) ->
      Eternal (substitute_eps_ty ty_subst eps_subst ty, reason_of reason)
  | EternalOrIneq (ty, eps1, eps2, reason) ->
      EternalOrIneq
        ( substitute_eps_ty ty_subst eps_subst ty,
          substitute_eps eps_subst eps1,
          substitute_eps eps_subst eps2,
          reason_of reason )

(** [wrap_reason f c] rewrites the reason of [c] with [f]: instantiating a
    scheme's qualifier nests the definition's reason inside the use's. *)
let wrap_reason f = function
  | Ineq (eps1, eps2, reason) -> Ineq (eps1, eps2, f reason)
  | Eternal (ty, reason) -> Eternal (ty, f reason)
  | EternalOrIneq (ty, eps1, eps2, reason) ->
      EternalOrIneq (ty, eps1, eps2, f reason)

let rec free_eps_params = function
  | EpsConst _ | EpsRigid _ -> EpsParamSet.empty
  | EpsParam p -> EpsParamSet.singleton p
  | EpsAdd (l, r) -> EpsParamSet.union (free_eps_params l) (free_eps_params r)

(** The type and grade parameters of a type, the latter of either sort. *)
let free_vars ty =
  let grade eps (ty_params, eps_params) =
    (ty_params, EpsParamSet.union eps_params (free_eps_params eps))
  in
  fold_ty
    ~on_param:(fun a (ty_params, eps_params) ->
      (TyParamSet.add a ty_params, eps_params))
    ~on_rho:grade ~on_eps:grade ty
    (TyParamSet.empty, EpsParamSet.empty)

(** The rigid grades of a grade or a type. They are never substituted or
    generalised, so [free_vars] leaves them out. *)
let rec rigid_eps_params = function
  | EpsConst _ | EpsParam _ -> EpsParamSet.empty
  | EpsRigid p -> EpsParamSet.singleton p
  | EpsAdd (l, r) -> EpsParamSet.union (rigid_eps_params l) (rigid_eps_params r)

(** [instantiate_rigid w eps] takes the instance of [eps] in which every rigid
    grade is [w]. A failing ground instance refutes the universal statement. *)
let rec instantiate_rigid w = function
  | EpsRigid _ -> EpsConst w
  | EpsAdd (l, r) -> EpsAdd (instantiate_rigid w l, instantiate_rigid w r)
  | eps -> eps

let rigid_eps_params_ty ty =
  let grade eps acc = EpsParamSet.union acc (rigid_eps_params eps) in
  fold_ty
    ~on_param:(fun _ acc -> acc)
    ~on_rho:grade ~on_eps:grade ty EpsParamSet.empty

let rigid_eps_params_comp_ty cty =
  let grade eps acc = EpsParamSet.union acc (rigid_eps_params eps) in
  fold_comp_ty
    ~on_param:(fun _ acc -> acc)
    ~on_rho:grade ~on_eps:grade cty EpsParamSet.empty

(* The reasons are not looked at: their only grades are the elapsed entries,
   the summands of a grade the constraint already states. *)
let free_vars_constr = function
  | Ineq (eps1, eps2, _) ->
      ( TyParamSet.empty,
        EpsParamSet.union (free_eps_params eps1) (free_eps_params eps2) )
  | Eternal (ty, _) -> free_vars ty
  | EternalOrIneq (ty, eps1, eps2, _) ->
      let fv_ty, fv_eps = free_vars ty in
      ( fv_ty,
        EpsParamSet.union fv_eps
          (EpsParamSet.union (free_eps_params eps1) (free_eps_params eps2)) )
