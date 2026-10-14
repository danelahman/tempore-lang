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
        Error.runtime "Pair expected but got `%t`"
          (PrettyPrint.print_expression (module GS.R) expr)

  (* The constant of [expr] read by [get], or a run-time error naming
     [expected]. *)
  let constant expected get (expr : _ Ast.expression) =
    match match expr.it with Ast.Const c -> get c | _ -> None with
    | Some x -> x
    | None ->
        Error.runtime "%s expected but got `%t`" expected
          (PrettyPrint.print_expression (module GS.R) expr)

  let get_nat expr =
    constant "Natural number"
      (function Const.Nat n -> Some n | _ -> None)
      expr

  let get_int expr =
    constant "Integer" (function Const.Int n -> Some n | _ -> None) expr

  let get_float expr =
    constant "Float" (function Const.Float x -> Some x | _ -> None) expr

  (* The primitive returning the constant [make (f x)] of the argument read by
     [get] as [x]. *)
  let unary get make f expr = return_const expr.Ast.at (make (f (get expr)))

  (* The primitive returning the constant [make (f x1 x2)] of the pair of
     arguments read by [get] as [x1] and [x2]. *)
  let binary get make f expr =
    binary_function
      (fun expr1 expr2 ->
        let x1 = get expr1 in
        let x2 = get expr2 in
        return_const expr.Ast.at (make (f x1 x2)))
      expr

  let nat_nat_to_nat f expr = binary get_nat (fun n -> Const.Nat n) f expr
  let int_int_to_int f expr = binary get_int (fun n -> Const.Int n) f expr
  let float_to_float f expr = unary get_float (fun x -> Const.Float x) f expr

  let float_float_to_float f expr =
    binary get_float (fun x -> Const.Float x) f expr

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
          Error.runtime "Incomparable expression `%t`"
            (PrettyPrint.print_expression (module GS.R) ~max_level:0 e1)
        else if not (comparable_expression e2) then
          Error.runtime "Incomparable expression `%t`"
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
    | Primitives.FloatOfNat -> unary get_nat (fun x -> Const.Float x) Z.to_float
    | Primitives.NatOfFloat ->
        unary get_float (fun n -> Const.Nat n) nat_of_float
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
    | Primitives.IntNeg -> unary get_int (fun n -> Const.Int n) Z.neg
    | Primitives.IntOfNat -> unary get_nat (fun n -> Const.Int n) Fun.id
    | Primitives.NatOfInt -> unary get_int (fun n -> Const.Nat n) (Z.max Z.zero)
    | Primitives.FloatOfInt -> unary get_int (fun x -> Const.Float x) Z.to_float
    | Primitives.IntOfFloat ->
        unary get_float (fun n -> Const.Int n) int_of_float
    | Primitives.ToString ->
        fun expr ->
          return_const expr.Ast.at
            (Const.String (PrettyPrint.string_of_expression (module GS.R) expr))
end
