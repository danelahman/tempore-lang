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

module OpName = Symbol.Make ()
module OpNameMap = Map.Make (OpName)
module OpNameSet = Set.Make (OpName)

type operation = OpName.t

(** Resource grade expressions over the resource grades ['rho]. *)
type 'rho rho =
  | RhoConst of 'rho
  | RhoAdd of 'rho rho * 'rho rho  (** the product of two grades *)

(** Effect grade expressions over the effect grades ['eps]. *)
type 'eps eps =
  | EpsConst of 'eps
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

(** A position within a type, where the unification of two types fails. *)
type step =
  | Argument
  | Result  (** of a function type *)
  | Component of int  (** of a tuple, from 1 *)
  | TypeArgument of int  (** of a type application, from 1 *)
  | BoxContent
  | HandlerInput
  | HandlerOutput

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

type ('var, 'map, 'rho) context_elem_ty = VarMap of 'map | Rho of 'rho
type ('var, 'map, 'rho) context = ('var, 'map, 'rho) context_elem_ty list

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
