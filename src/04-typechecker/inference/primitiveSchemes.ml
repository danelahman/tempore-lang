(* The schemes of the primitives. *)

module Ast = Language.Ast
module Const = Language.Const
module Primitives = Language.Primitives
module Location = Utils.Location

module Make (C : Constraint.S) = struct
  let pure ty = Ast.CompTy (ty, C.X.Eps.unit)
  let arrow ty ty' = Ast.TyArrow (ty, pure ty')
  let nat = Ast.TyConst Const.NatTy
  let float = Ast.TyConst Const.FloatTy
  let bool = Ast.TyConst Const.BooleanTy
  let string = Ast.TyConst Const.StringTy

  (* [poly f] is [∀a. f a]. *)
  let poly f =
    let a = Ast.TyParamModule.fresh "poly" in
    { (C.monomorphic (f (Ast.TyParam a))) with C.ty_params = [ a ] }

  let unary ty = C.monomorphic (arrow ty ty)
  let binary ty = C.monomorphic (arrow (Ast.TyTuple [ ty; ty ]) ty)

  (* The place of the primitives, which have no source. *)
  let nowhere =
    let pos = { Location.line = 0; column = 0; offset = 0 } in
    { Location.filename = ""; start = pos; stop = pos }

  (* [∀a. Et(a) ⇒ a × a → bool] *)
  let comparison =
    let scheme = poly (fun a -> arrow (Ast.TyTuple [ a; a ]) bool) in
    let a = List.hd scheme.C.ty_params in
    {
      scheme with
      C.qualifier =
        C.Eternal (Reason.because nowhere Reason.Compared_values, Ast.TyParam a);
    }

  let scheme = function
    | Primitives.CompareEq | Primitives.CompareLt | Primitives.CompareGt
    | Primitives.CompareLe | Primitives.CompareGe | Primitives.CompareNe ->
        comparison
    | Primitives.NatAdd | Primitives.NatMul | Primitives.NatSub
    | Primitives.NatDiv | Primitives.NatMod ->
        binary nat
    | Primitives.FloatAdd | Primitives.FloatMul | Primitives.FloatSub
    | Primitives.FloatDiv | Primitives.FloatPow ->
        binary float
    | Primitives.FloatNeg -> unary float
    | Primitives.ToString -> poly (fun a -> arrow a string)
end
