module Ast = Language.Ast
module Context = Language.Context
module Const = Language.Const
module Primitives = Language.Primitives

module Make (ResourceGrade : Language.Grade.S) = struct
  let poly_type ty =
    let a = Ast.TyParamModule.fresh "poly" in
    ([ a ], [], ty (Ast.TyParam a))

  let unary_integer_op_ty rho =
    ( [],
      [],
      Ast.TyArrow
        ( Ast.TyConst Const.IntegerTy,
          Ast.CompTy (Ast.TyConst Const.IntegerTy, rho) ) )

  let binary_integer_op_ty rho =
    ( [],
      [],
      Ast.TyArrow
        ( Ast.TyTuple
            [ Ast.TyConst Const.IntegerTy; Ast.TyConst Const.IntegerTy ],
          Ast.CompTy (Ast.TyConst Const.IntegerTy, rho) ) )

  let unary_float_op_ty rho =
    ( [],
      [],
      Ast.TyArrow
        (Ast.TyConst Const.FloatTy, Ast.CompTy (Ast.TyConst Const.FloatTy, rho))
    )

  let binary_float_op_ty rho =
    ( [],
      [],
      Ast.TyArrow
        ( Ast.TyTuple [ Ast.TyConst Const.FloatTy; Ast.TyConst Const.FloatTy ],
          Ast.CompTy (Ast.TyConst Const.FloatTy, rho) ) )

  let comparison_ty rho =
    poly_type (fun a ->
        Ast.TyArrow
          (Ast.TyTuple [ a; a ], Ast.CompTy (Ast.TyConst Const.BooleanTy, rho)))

  let primitive_type_scheme = function
    | Primitives.CompareEq -> comparison_ty (Ast.RhoConst ResourceGrade.one)
    | Primitives.CompareLt -> comparison_ty (Ast.RhoConst ResourceGrade.one)
    | Primitives.CompareGt -> comparison_ty (Ast.RhoConst ResourceGrade.one)
    | Primitives.CompareLe -> comparison_ty (Ast.RhoConst ResourceGrade.one)
    | Primitives.CompareGe -> comparison_ty (Ast.RhoConst ResourceGrade.one)
    | Primitives.CompareNe -> comparison_ty (Ast.RhoConst ResourceGrade.one)
    | Primitives.IntegerAdd ->
        binary_integer_op_ty (Ast.RhoConst ResourceGrade.one)
    | Primitives.IntegerMul ->
        binary_integer_op_ty (Ast.RhoConst ResourceGrade.one)
    | Primitives.IntegerSub ->
        binary_integer_op_ty (Ast.RhoConst ResourceGrade.one)
    | Primitives.IntegerDiv ->
        binary_integer_op_ty (Ast.RhoConst ResourceGrade.one)
    | Primitives.IntegerMod ->
        binary_integer_op_ty (Ast.RhoConst ResourceGrade.one)
    | Primitives.IntegerNeg ->
        unary_integer_op_ty (Ast.RhoConst ResourceGrade.one)
    | Primitives.FloatAdd -> binary_float_op_ty (Ast.RhoConst ResourceGrade.one)
    | Primitives.FloatMul -> binary_float_op_ty (Ast.RhoConst ResourceGrade.one)
    | Primitives.FloatSub -> binary_float_op_ty (Ast.RhoConst ResourceGrade.one)
    | Primitives.FloatDiv -> binary_float_op_ty (Ast.RhoConst ResourceGrade.one)
    | Primitives.FloatPow -> binary_float_op_ty (Ast.RhoConst ResourceGrade.one)
    | Primitives.FloatNeg -> unary_float_op_ty (Ast.RhoConst ResourceGrade.one)
    | Primitives.ToString ->
        poly_type (fun a ->
            Ast.TyArrow
              ( a,
                Ast.CompTy
                  (Ast.TyConst Const.StringTy, Ast.RhoConst ResourceGrade.one)
              ))
end
