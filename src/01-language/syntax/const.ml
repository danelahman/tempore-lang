module Error = Utils.Error

type t = Nat of Z.t | String of string | Boolean of bool | Float of float
type ty = NatTy | StringTy | BooleanTy | FloatTy

let is_eternal_ty = function
  | NatTy -> true
  | StringTy -> true
  | BooleanTy -> true
  | FloatTy -> true

let of_nat n = Nat n
let of_string s = String s
let of_boolean b = Boolean b
let of_float f = Float f
let of_true = of_boolean true
let of_false = of_boolean false

let print c ppf =
  match c with
  | Nat n -> Z.pp_print ppf n
  | String s -> Format.fprintf ppf "%S" s
  | Boolean b -> Format.fprintf ppf "%B" b
  | Float f -> Format.fprintf ppf "%F" f

let print_ty c ppf =
  match c with
  | NatTy -> Format.fprintf ppf "nat"
  | StringTy -> Format.fprintf ppf "string"
  | BooleanTy -> Format.fprintf ppf "bool"
  | FloatTy -> Format.fprintf ppf "float"

let infer_ty = function
  | Nat _ -> NatTy
  | String _ -> StringTy
  | Boolean _ -> BooleanTy
  | Float _ -> FloatTy

let compare c1 c2 =
  match (c1, c2) with
  | Nat n1, Nat n2 -> Z.compare n1 n2
  | String s1, String s2 -> String.compare s1 s2
  | Boolean b1, Boolean b2 -> Bool.compare b1 b2
  | Float x1, Float x2 -> Float.compare x1 x2
  | _ -> Error.runtime "Incomparable constants %t and %t" (print c1) (print c2)

let equal c1 c2 = compare c1 c2 = 0
