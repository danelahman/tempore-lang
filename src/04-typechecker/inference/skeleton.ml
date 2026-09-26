(* Skeletons, their unification, decoration and expansion. *)

module Ast = Language.Ast
module Const = Language.Const
module TyParam = Ast.TyParamModule
module TyParamMap = Ast.TyParamMap
module TyParamSet = Ast.TyParamSet

type t =
  | Var of Ast.ty_param
  | Const of Const.ty
  | Apply of Ast.ty_name * t list
  | Tuple of t list
  | Arrow of t * t
  | Box of t
  | Handler of t * t

(* The skeleton of a type, its grades erased. *)
let rec of_ty : ('rho, 'eps) Ast.ty -> t = function
  | Ast.TyConst c -> Const c
  | Ast.TyParam a -> Var a
  | Ast.TyApply (name, tys) -> Apply (name, List.map of_ty tys)
  | Ast.TyTuple tys -> Tuple (List.map of_ty tys)
  | Ast.TyArrow (ty, cty) -> Arrow (of_ty ty, of_comp_ty cty)
  | Ast.TyBox (_, ty) -> Box (of_ty ty)
  | Ast.TyHandler (cty, cty') -> Handler (of_comp_ty cty, of_comp_ty cty')

and of_comp_ty : ('rho, 'eps) Ast.comp_ty -> t = function
  | Ast.CompTy (ty, _) -> of_ty ty

let rec equal t u =
  match (t, u) with
  | Var a, Var b -> TyParam.compare a b = 0
  | Const c, Const c' -> c = c'
  | Apply (name, ts), Apply (name', us) ->
      Ast.TyName.compare name name' = 0 && List.equal equal ts us
  | Tuple ts, Tuple us -> List.equal equal ts us
  | Arrow (t1, t2), Arrow (u1, u2) | Handler (t1, t2), Handler (u1, u2) ->
      equal t1 u1 && equal t2 u2
  | Box t, Box u -> equal t u
  | (Var _ | Const _ | Apply _ | Tuple _ | Arrow _ | Box _ | Handler _), _ ->
      false

let rec fold_vars f t acc =
  match t with
  | Var a -> f a acc
  | Const _ -> acc
  | Apply (_, ts) | Tuple ts ->
      List.fold_left (fun acc t -> fold_vars f t acc) acc ts
  | Arrow (t, u) | Handler (t, u) -> fold_vars f u (fold_vars f t acc)
  | Box t -> fold_vars f t acc

let free_vars t = fold_vars TyParamSet.add t TyParamSet.empty

let rec occurs a = function
  | Var b -> TyParam.compare a b = 0
  | Const _ -> false
  | Apply (_, ts) | Tuple ts -> List.exists (occurs a) ts
  | Arrow (t, u) | Handler (t, u) -> occurs a t || occurs a u
  | Box t -> occurs a t

(* The type of [t] with every grade [()]. *)
let rec to_ty : t -> (unit, unit) Ast.ty = function
  | Var a -> Ast.TyParam a
  | Const c -> Ast.TyConst c
  | Apply (name, ts) -> Ast.TyApply (name, List.map to_ty ts)
  | Tuple ts -> Ast.TyTuple (List.map to_ty ts)
  | Arrow (t, u) -> Ast.TyArrow (to_ty t, to_comp_ty u)
  | Box t -> Ast.TyBox ((), to_ty t)
  | Handler (t, u) -> Ast.TyHandler (to_comp_ty t, to_comp_ty u)

and to_comp_ty t = Ast.CompTy (to_ty t, ())

let print t ppf =
  let blank () ppf = Format.pp_print_string ppf "_" in
  let grades =
    { Language.PrettyPrint.rho = blank; eps = blank; pure = (fun () -> true) }
  in
  Language.PrettyPrint.print_ty grades TyParam.print (to_ty t) ppf

let to_string t = Format.asprintf "%t" (print t)

type subst = t TyParamMap.t

let rec apply sigma t =
  match t with
  | Var a -> Option.value (TyParamMap.find_opt a sigma) ~default:t
  | Const _ -> t
  | Apply (name, ts) -> Apply (name, List.map (apply sigma) ts)
  | Tuple ts -> Tuple (List.map (apply sigma) ts)
  | Arrow (t, u) -> Arrow (apply sigma t, apply sigma u)
  | Box t -> Box (apply sigma t)
  | Handler (t, u) -> Handler (apply sigma t, apply sigma u)

type unfold = Ast.ty_name -> t list -> t option
type 'info equation = { lhs : t; rhs : t; info : 'info }
type mismatch = Clash | Occurs of Ast.ty_param

type 'info failure = {
  info : 'info;
  mismatch : mismatch;
  lhs : t;
  rhs : t;
  path : Ast.step list;
}

(* One equation of the problem being solved: its payload and the reversed path
   of the sub-skeletons being unified. *)
type 'info site = { info : 'info; rev_path : Ast.step list }

let descend site step = { site with rev_path = step :: site.rev_path }

let fail site mismatch sigma lhs rhs =
  Error
    {
      info = site.info;
      mismatch;
      lhs = apply sigma lhs;
      rhs = apply sigma rhs;
      path = List.rev site.rev_path;
    }

(* The binding of [a] to [t], composed with the idempotent [sigma] so that the
   result is idempotent. *)
let bind site sigma a t ~lhs ~rhs =
  let t = apply sigma t in
  if occurs a t then fail site (Occurs a) sigma lhs rhs
  else
    let single = TyParamMap.singleton a t in
    Ok (TyParamMap.add a t (TyParamMap.map (apply single) sigma))

(* The head of [t] under [sigma]. *)
let resolve sigma = function
  | Var a as t -> Option.value (TyParamMap.find_opt a sigma) ~default:t
  | t -> t

(* [unify_at unfold site sigma lhs rhs] extends [sigma] to a most general
   unifier of [lhs] and [rhs], both the rigid-rigid and the flexible cases. *)
let rec unify_at unfold site sigma lhs rhs =
  let open Result.Syntax in
  match (resolve sigma lhs, resolve sigma rhs) with
  | Var a, Var b when TyParam.compare a b = 0 -> Ok sigma
  | Var a, t | t, Var a -> bind site sigma a t ~lhs ~rhs
  | Apply (name, ts), Apply (name', us) ->
      unify_applications unfold site sigma (name, ts) (name', us)
  | Apply (name, ts), u -> unfold_left unfold site sigma (name, ts) u
  | t, Apply (name, us) -> unfold_right unfold site sigma t (name, us)
  | Const c, Const c' when c = c' -> Ok sigma
  | Tuple ts, Tuple us when List.compare_lengths ts us = 0 ->
      unify_args unfold site sigma (fun i -> Ast.Component i) ts us
  | Arrow (t1, t2), Arrow (u1, u2) ->
      let* sigma = unify_at unfold (descend site Ast.Argument) sigma t1 u1 in
      unify_at unfold (descend site Ast.Result) sigma t2 u2
  | Handler (t1, t2), Handler (u1, u2) ->
      let* sigma =
        unify_at unfold (descend site Ast.HandlerInput) sigma t1 u1
      in
      unify_at unfold (descend site Ast.HandlerOutput) sigma t2 u2
  | Box t, Box u -> unify_at unfold (descend site Ast.BoxContent) sigma t u
  | (Const _ | Tuple _ | Arrow _ | Handler _ | Box _), _ ->
      fail site Clash sigma lhs rhs

(* Two applications: an alias on either side is unfolded, otherwise the heads
   and arities must agree and the arguments are unified. *)
and unify_applications unfold site sigma (name, ts) (name', us) =
  match (unfold name ts, unfold name' us) with
  | Some t, _ -> unify_at unfold site sigma t (Apply (name', us))
  | None, Some u -> unify_at unfold site sigma (Apply (name, ts)) u
  | None, None
    when Ast.TyName.compare name name' = 0 && List.compare_lengths ts us = 0 ->
      unify_args unfold site sigma (fun i -> Ast.TypeArgument i) ts us
  | None, None -> fail site Clash sigma (Apply (name, ts)) (Apply (name', us))

and unfold_left unfold site sigma (name, ts) u =
  match unfold name ts with
  | Some t -> unify_at unfold site sigma t u
  | None -> fail site Clash sigma (Apply (name, ts)) u

and unfold_right unfold site sigma t (name, us) =
  match unfold name us with
  | Some u -> unify_at unfold site sigma t u
  | None -> fail site Clash sigma t (Apply (name, us))

(* The pairwise unification of [ts] and [us], of equal length, the [i]-th pair
   at [step i], counted from 1. *)
and unify_args unfold site sigma step ts us =
  let unify_pair (i, sigma) t u =
    ( i + 1,
      Result.bind sigma (fun sigma ->
          unify_at unfold (descend site (step i)) sigma t u) )
  in
  snd (List.fold_left2 unify_pair (1, Ok sigma) ts us)

(* The equations solved left to right under one growing unifier. *)
let unify unfold equations =
  let unify_equation sigma ({ lhs; rhs; info } : _ equation) =
    Result.bind sigma (fun sigma ->
        unify_at unfold { info; rev_path = [] } sigma lhs rhs)
  in
  List.fold_left unify_equation (Ok TyParamMap.empty) equations

module Make (X : GradeExp.S) = struct
  type ty = (X.rho, X.eps) Ast.ty
  type comp_ty = (X.rho, X.eps) Ast.comp_ty
  type ty_subst = ty TyParamMap.t

  let fresh_ty () = Ast.TyParam (TyParam.fresh "ty")
  let fresh_rho () = X.Rho.var (X.Rho_var.fresh_indexed ())
  let fresh_eps () = X.Eps.var (X.Eps_var.fresh_indexed ())

  (* Fresh variables are drawn left to right. *)
  let rec decorate : t -> ty = function
    | Var _ -> fresh_ty ()
    | Const c -> Ast.TyConst c
    | Apply (name, ts) -> Ast.TyApply (name, List.map decorate ts)
    | Tuple ts -> Ast.TyTuple (List.map decorate ts)
    | Arrow (t, u) ->
        let ty = decorate t in
        Ast.TyArrow (ty, decorate_comp u)
    | Box t ->
        let rho = fresh_rho () in
        Ast.TyBox (rho, decorate t)
    | Handler (t, u) ->
        let cty = decorate_comp t in
        Ast.TyHandler (cty, decorate_comp u)

  and decorate_comp t : comp_ty =
    let ty = decorate t in
    Ast.CompTy (ty, fresh_eps ())

  let substitute theta ty =
    Ast.substitute_ty theta ~on_rho:Fun.id ~on_eps:Fun.id ty

  (* Unifies the skeletons of every demand and instantiates the unknowns the
     unifier sends to a non-variable skeleton, by a decoration of it. *)
  let expand unfold demands =
    let equation ({ lhs; rhs; info } : (ty, _) GradeNormal.ordering) =
      { lhs = of_ty lhs; rhs = of_ty rhs; info }
    in
    let instantiate _ = function Var _ -> None | t -> Some (decorate t) in
    Result.map
      (TyParamMap.filter_map instantiate)
      (unify unfold (List.map equation demands))
end
