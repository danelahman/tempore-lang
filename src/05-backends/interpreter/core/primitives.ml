module Error = Utils.Error
module Ast = Language.Ast
module Const = Language.Const
module Primitives = Language.Primitives
module PrettyPrint = Language.PrettyPrint

module Make (GS : Grades.GradeSystem.S) = struct
  (* A primitive's result is not written anywhere in the source, so it is
     reported at the span of the argument it was computed from. *)
  let return_const at c =
    Ast.located at (Ast.Return (Ast.located at (Ast.Const c)))

  let binary_function f (expr : _ Ast.expression) =
    match expr.it with
    | Ast.Tuple [ expr1; expr2 ] -> f expr1 expr2
    | _ ->
        Error.runtime "Pair expected but got %t"
          (PrettyPrint.print_expression (module GS.R) expr)

  let get_nat (expr : _ Ast.expression) =
    match expr.it with
    | Ast.Const (Const.Nat n) -> n
    | _ ->
        Error.runtime "Natural number expected but got %t"
          (PrettyPrint.print_expression (module GS.R) expr)

  let get_int (expr : _ Ast.expression) =
    match expr.it with
    | Ast.Const (Const.Int n) -> n
    | _ ->
        Error.runtime "Integer expected but got %t"
          (PrettyPrint.print_expression (module GS.R) expr)

  let get_float (expr : _ Ast.expression) =
    match expr.it with
    | Ast.Const (Const.Float n) -> n
    | _ ->
        Error.runtime "Float expected but got %t"
          (PrettyPrint.print_expression (module GS.R) expr)

  let nat_nat_to f expr =
    binary_function
      (fun expr1 expr2 ->
        let n1 = get_nat expr1 in
        let n2 = get_nat expr2 in
        f n1 n2)
      expr

  let int_int_to_int f expr =
    return_const expr.Ast.at
      (Const.Int
         (binary_function (fun e1 e2 -> f (get_int e1) (get_int e2)) expr))

  let float_to f expr =
    let n = get_float expr in
    f n

  let float_float_to f expr =
    binary_function
      (fun expr1 expr2 ->
        let n1 = get_float expr1 in
        let n2 = get_float expr2 in
        f n1 n2)
      expr

  let nat_nat_to_nat f expr =
    return_const expr.Ast.at (Const.Nat (nat_nat_to f expr))

  let float_to_float f expr =
    return_const expr.Ast.at (Const.Float (float_to f expr))

  let float_float_to_float f expr =
    return_const expr.Ast.at (Const.Float (float_float_to f expr))

  (* The natural number of a float, truncated toward zero; zero for a
     negative float and for NaN, and a run-time error for infinity. *)
  let nat_of_float x =
    if Float.is_nan x || x <= 0.0 then Z.zero
    else if x = Float.infinity then
      Error.runtime "Conversion of infinity to a natural number"
    else Z.of_float x

  (* The integer of a float, truncated toward zero; zero for NaN, and a
     run-time error for infinity. *)
  let int_of_float x =
    if Float.is_nan x then Z.zero
    else if Float.is_finite x then Z.of_float x
    else Error.runtime "Conversion of infinity to an integer"

  (* Which shapes the comparison primitives below accept: everything but a
     function or a handler, which are not values that can be compared. *)
  let rec comparable_expression (expr : _ Ast.expression) =
    match expr.it with
    | Ast.Var _ -> true
    | Const _ -> true
    | Annotated (e, _) -> comparable_expression e
    | Tuple es -> List.for_all comparable_expression es
    | Variant (_, e) -> Option.fold ~none:true ~some:comparable_expression e
    | Lambda _ -> false
    | PureLambda _ -> false
    | RecLambda _ -> false
    | Handler _ -> false

  let comparison f (expr : _ Ast.expression) =
    binary_function
      (fun e1 e2 ->
        if not (comparable_expression e1) then
          Error.runtime "Incomparable expression %t"
            (PrettyPrint.print_expression (module GS.R) ~max_level:0 e1)
        else if not (comparable_expression e2) then
          Error.runtime "Incomparable expression %t"
            (PrettyPrint.print_expression (module GS.R) ~max_level:0 e2)
        else
          return_const expr.at
            (Const.Boolean (f (Ast.compare_expression e1 e2) 0)))
      expr

  let primitive_function = function
    | Primitives.CompareEq -> comparison ( = )
    | Primitives.CompareLt -> comparison ( < )
    | Primitives.CompareGt -> comparison ( > )
    | Primitives.CompareLe -> comparison ( <= )
    | Primitives.CompareGe -> comparison ( >= )
    | Primitives.CompareNe -> comparison ( <> )
    | Primitives.NatAdd -> nat_nat_to_nat Z.add
    | Primitives.NatMul -> nat_nat_to_nat Z.mul
    | Primitives.NatSub -> nat_nat_to_nat (fun m n -> Z.max Z.zero (Z.sub m n))
    | Primitives.NatDiv ->
        nat_nat_to_nat (fun m n ->
            if Z.equal n Z.zero then Error.runtime "Division by zero"
            else Z.div m n)
    | Primitives.NatMod ->
        nat_nat_to_nat (fun m n ->
            if Z.equal n Z.zero then Error.runtime "Modulo by zero"
            else Z.rem m n)
    | Primitives.FloatAdd -> float_float_to_float ( +. )
    | Primitives.FloatMul -> float_float_to_float ( *. )
    | Primitives.FloatSub -> float_float_to_float ( -. )
    | Primitives.FloatDiv -> float_float_to_float ( /. )
    | Primitives.FloatPow -> float_float_to_float ( ** )
    | Primitives.FloatNeg -> float_to_float ( ~-. )
    | Primitives.FloatOfNat ->
        fun expr ->
          return_const expr.Ast.at (Const.Float (Z.to_float (get_nat expr)))
    | Primitives.NatOfFloat ->
        fun expr ->
          return_const expr.Ast.at (Const.Nat (float_to nat_of_float expr))
    | Primitives.FloatSqrt -> float_to_float Float.sqrt
    | Primitives.FloatAtan -> float_to_float Float.atan
    | Primitives.FloatAtan2 -> float_float_to_float Float.atan2
    | Primitives.IntAdd -> int_int_to_int Z.add
    | Primitives.IntMul -> int_int_to_int Z.mul
    | Primitives.IntSub -> int_int_to_int Z.sub
    | Primitives.IntDiv ->
        int_int_to_int (fun m n ->
            if Z.equal n Z.zero then Error.runtime "Division by zero"
            else Z.div m n)
    | Primitives.IntMod ->
        int_int_to_int (fun m n ->
            if Z.equal n Z.zero then Error.runtime "Modulo by zero"
            else Z.rem m n)
    | Primitives.IntNeg ->
        fun expr -> return_const expr.Ast.at (Const.Int (Z.neg (get_int expr)))
    | Primitives.IntOfNat ->
        fun expr -> return_const expr.Ast.at (Const.Int (get_nat expr))
    | Primitives.NatOfInt ->
        fun expr ->
          return_const expr.Ast.at (Const.Nat (Z.max Z.zero (get_int expr)))
    | Primitives.FloatOfInt ->
        fun expr ->
          return_const expr.Ast.at (Const.Float (Z.to_float (get_int expr)))
    | Primitives.IntOfFloat ->
        fun expr ->
          return_const expr.Ast.at (Const.Int (float_to int_of_float expr))
    | Primitives.ToString ->
        fun expr ->
          return_const expr.Ast.at
            (Const.String (PrettyPrint.string_of_expression (module GS.R) expr))
end
