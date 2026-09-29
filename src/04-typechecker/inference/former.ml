(* Type formers and the variance of their parts. *)

module Ast = Language.Ast

type variance = Covariant | Contravariant | Invariant

type ('ty, 'rho, 'eps) t =
  | Param of Ast.ty_param
  | Const of Language.Const.ty
  | Apply of Ast.ty_name * 'ty list
  | Tuple of 'ty list
  | Arrow of 'ty * 'ty * 'eps
  | Box of 'rho * 'ty
  | Handler of ('ty * 'eps) * ('ty * 'eps)

let of_ty : ('rho, 'eps) Ast.ty -> (('rho, 'eps) Ast.ty, 'rho, 'eps) t =
  function
  | Ast.TyParam a -> Param a
  | Ast.TyConst c -> Const c
  | Ast.TyApply (name, tys) -> Apply (name, tys)
  | Ast.TyTuple tys -> Tuple tys
  | Ast.TyArrow (ty, Ast.CompTy (ty', eps)) -> Arrow (ty, ty', eps)
  | Ast.TyBox (rho, ty) -> Box (rho, ty)
  | Ast.TyHandler (Ast.CompTy (ty, eps), Ast.CompTy (ty', eps')) ->
      Handler ((ty, eps), (ty', eps'))

type ('ty, 'rho, 'eps) part =
  | Ty of variance * Ast.step * 'ty * 'ty
  | Rho of variance * 'rho * 'rho
  | Eps of variance * Ast.step option * 'eps * 'eps

(* The pairs of [ts] and [us], of equal length, the [i]-th at [step i]. *)
let pairwise variance step ts us =
  List.mapi
    (fun i (t, u) -> Ty (variance, step (i + 1), t, u))
    (List.combine ts us)

let decompose f g =
  match (f, g) with
  | Const c, Const c' when c = c' -> Some []
  | Tuple ts, Tuple us when List.compare_lengths ts us = 0 ->
      Some (pairwise Covariant (fun i -> Ast.Component i) ts us)
  | Arrow (t, t', eps), Arrow (u, u', eps') ->
      Some
        [
          Ty (Contravariant, Ast.Argument, t, u);
          Ty (Covariant, Ast.Result, t', u');
          Eps (Covariant, None, eps, eps');
        ]
  | Box (rho, t), Box (rho', u) ->
      Some
        [ Rho (Contravariant, rho, rho'); Ty (Covariant, Ast.BoxContent, t, u) ]
  | Apply (name, ts), Apply (name', us)
    when Ast.TyName.compare name name' = 0 && List.compare_lengths ts us = 0 ->
      Some (pairwise Invariant (fun i -> Ast.TypeArgument i) ts us)
  | Handler ((t, eps), (t', delta)), Handler ((u, eps'), (u', delta')) ->
      Some
        [
          Ty (Invariant, Ast.HandlerInput, t, u);
          Eps (Invariant, Some Ast.HandlerInput, eps, eps');
          Ty (Covariant, Ast.HandlerOutput, t', u');
          Eps (Covariant, Some Ast.HandlerOutput, delta, delta');
        ]
  | (Param _ | Const _ | Tuple _ | Arrow _ | Box _ | Apply _ | Handler _), _ ->
      None
