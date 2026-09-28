type t = Q.t

let zero = Q.zero
let of_int = Q.of_int

let make n d =
  if d = 0 then raise Division_by_zero else Q.make (Z.of_int n) (Z.of_int d)

let of_decimal s =
  let invalid () = invalid_arg ("Rational.of_decimal: " ^ s) in
  if String.contains s '/' then invalid ()
  else
    match Q.of_string s with
    | q when Z.equal (Q.den q) Z.zero -> invalid ()
    | q -> q
    | exception (Invalid_argument _ | Failure _) -> invalid ()

let add = Q.add
let mul = Q.mul
let div p q = if Q.sign q = 0 then raise Division_by_zero else Q.div p q
let sign = Q.sign
let compare = Q.compare
let equal = Q.equal
let hash q = (Z.hash (Q.num q) * 65599) + Z.hash (Q.den q)

let to_int q =
  if Z.equal (Q.den q) Z.one && Z.fits_int (Q.num q) then
    Some (Z.to_int (Q.num q))
  else None

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
