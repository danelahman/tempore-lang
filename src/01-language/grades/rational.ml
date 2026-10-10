type t = Q.t

let zero = Q.zero
let of_int = Q.of_int
let of_z = Q.of_bigint
let make_z n d = if Z.equal d Z.zero then raise Division_by_zero else Q.make n d
let make n d = make_z (Z.of_int n) (Z.of_int d)

(* [is_decimal s] is whether [s] is a decimal numeral: an optional [-], a
   digit, then digits, an optional fraction part [.] and an optional exponent
   [e] or [E] with an optional sign and a digit, the digits after the first of
   each part possibly separated by underscores. *)
let is_decimal s =
  let n = String.length s in
  let is c i = i < n && Char.equal s.[i] c in
  let digit i = i < n && match s.[i] with '0' .. '9' -> true | _ -> false in
  let rec digits i = if digit i || is '_' i then digits (i + 1) else i in
  let number i = if digit i then Some (digits (i + 1)) else None in
  let fraction i = if is '.' i then digits (i + 1) else i in
  let exponent i =
    if is 'e' i || is 'E' i then
      number (if is '-' (i + 1) || is '+' (i + 1) then i + 2 else i + 1)
    else Some i
  in
  match number (if is '-' 0 then 1 else 0) with
  | Some i -> Option.equal Int.equal (exponent (fraction i)) (Some n)
  | None -> false

let of_decimal s =
  let invalid () = invalid_arg ("Rational.of_decimal: " ^ s) in
  if not (is_decimal s) then invalid ()
  else
    match Q.of_string s with
    | q when Z.equal (Q.den q) Z.zero -> invalid ()
    | q -> q
    | exception (Invalid_argument _ | Failure _) -> invalid ()

let add = Q.add
let neg = Q.neg
let sub = Q.sub
let mul = Q.mul
let div p q = if Q.sign q = 0 then raise Division_by_zero else Q.div p q
let sign = Q.sign

(* The rationals kept are finite, with positive denominators, so that equal
   denominators compare by the numerators alone. *)
let compare p q =
  if Z.equal (Q.den p) (Q.den q) then Z.compare (Q.num p) (Q.num q)
  else Q.compare p q

let equal = Q.equal
let hash_terms n d = (Z.hash n * 65599) + Z.hash d
let hash q = hash_terms (Q.num q) (Q.den q)
let hash_one = Z.hash Z.one

let hash_fraction n d =
  if Z.equal d Z.one then (Z.hash n * 65599) + hash_one
  else
    let g = Z.gcd n d in
    hash_terms (Z.divexact n g) (Z.divexact d g)

let is_integer q = Z.equal (Q.den q) Z.one

let to_int q =
  if Z.equal (Q.den q) Z.one && Z.fits_int (Q.num q) then
    Some (Z.to_int (Q.num q))
  else None

let num = Q.num
let den = Q.den

let denominator q =
  if Z.fits_int (Q.den q) then Z.to_int (Q.den q)
  else invalid_arg "Rational.denominator"

(** [multiplicity p d] is [(k, d')] with [d = pᵏ · d'] and [p] not dividing
    [d']. *)
let multiplicity p d =
  let rec go k d =
    if Z.equal (Z.rem d p) Z.zero then go (k + 1) (Z.divexact d p) else (k, d)
  in
  go 0 d

(* The decimal expansion of [n/d] terminates iff [d = 2ᵃ5ᵇ], with [k = max a b]
   digits after the point, the last of which is not [0]. *)
let show q =
  let num = Q.num q and den = Q.den q in
  let a, d = multiplicity (Z.of_int 2) den in
  let b, d = multiplicity (Z.of_int 5) d in
  if Z.equal den Z.one then Z.to_string num
  else if not (Z.equal d Z.one) then Q.to_string q
  else
    let k = Int.max a b in
    let digits =
      Z.to_string (Z.divexact (Z.mul (Z.abs num) (Z.pow (Z.of_int 10) k)) den)
    in
    let digits =
      String.make (Int.max 0 (k + 1 - String.length digits)) '0' ^ digits
    in
    let point = String.length digits - k in
    (if Q.sign q < 0 then "-" else "")
    ^ String.sub digits 0 point ^ "." ^ String.sub digits point k
