open Grade

(** [nat_of_lit expected lit] is the non-negative integer the literal [lit]
    denotes; any other form is rejected as not the [expected] one. *)
let nat_of_lit expected = function
  | Int n when n < 0 -> invalid_lit (Int n) "grades must be non-negative"
  | Int n -> n
  | lit -> invalid_lit lit "grades are %s, not %s" expected (describe_lit lit)

module LowerBound = struct
  type t = int

  let name = "time-lower-bound"
  let one = 0
  let mul = ( + )
  let leq _bounds = ( >= )
  let leq_symbol = ">="
  let top = 0
  let join = Int.min
  let equal _bounds = Int.equal
  let counterexample _bounds _ _ = None
  let unit_least = false
  let commutative = true
  let needs_op_bounds = false
  let events _ = []
  let implied_bounds _bounds _ = None
  let inhabited _bounds _ = true
  let of_lit = function Top -> top | lit -> nat_of_lit "plain integers" lit
  let of_nat = check_nat "TimeGrades.LowerBound"
  let of_bounds (lo, _hi) = lo
  let is_atomic _name _ = true
  let show = string_of_int
end

module UpperBound = struct
  type t = ExtendedNat.t

  let name = "time-upper-bound"
  let one = ExtendedNat.Fin 0
  let mul = ExtendedNat.add
  let leq _bounds = ExtendedNat.leq
  let leq_symbol = "<="
  let top = ExtendedNat.Inf
  let join = ExtendedNat.max
  let equal _bounds = ( = )
  let counterexample _bounds _ _ = None
  let unit_least = true
  let commutative = true
  let needs_op_bounds = false
  let events _ = []
  let implied_bounds _bounds _ = None
  let inhabited _bounds _ = true

  let of_lit = function
    | Top | Inf -> top
    | lit -> ExtendedNat.Fin (nat_of_lit "plain integers or '∞'" lit)

  let of_nat n = ExtendedNat.Fin (check_nat "TimeGrades.UpperBound" n)
  let of_bounds (_lo, hi) = ExtendedNat.Fin hi
  let is_atomic _name _ = true
  let show = ExtendedNat.show
end

module Interval = struct
  type t = int * ExtendedNat.t

  let name = "time-interval"
  let one = (0, ExtendedNat.Fin 0)
  let mul (n, m) (k, l) = (n + k, ExtendedNat.add m l)
  let leq _bounds (n, m) (k, l) = k <= n && ExtendedNat.leq m l
  let leq_symbol = "<="
  let top = (0, ExtendedNat.Inf)
  let join (n, m) (k, l) = (Int.min n k, ExtendedNat.max m l)
  let equal _bounds = ( = )
  let counterexample _bounds _ _ = None
  let unit_least = false
  let commutative = true
  let needs_op_bounds = false
  let events _ = []
  let implied_bounds _bounds _ = None
  let inhabited _bounds _ = true

  (** [interval lit n m] is the interval from [n] to [m], checked. *)
  let interval lit n m =
    if n < 0 then invalid_lit lit "interval endpoints must be non-negative"
    else if not (ExtendedNat.leq (ExtendedNat.Fin n) m) then
      invalid_lit lit "interval endpoints must satisfy n <= m"
    else (n, m)

  let of_lit = function
    | Top -> top
    | Tuple [ Int n; Int m ] as lit -> interval lit n (ExtendedNat.Fin m)
    | Tuple [ Int n; Inf ] as lit -> interval lit n ExtendedNat.Inf
    | Tuple [ _; _ ] as lit ->
        invalid_lit lit
          "interval endpoints are integers, the upper one possibly '∞'"
    | lit ->
        invalid_lit lit "grades are intervals '(n, m)', not %s"
          (describe_lit lit)

  let of_nat n =
    let n = check_nat "TimeGrades.Interval" n in
    (n, ExtendedNat.Fin n)

  let of_bounds (lo, hi) = (lo, ExtendedNat.Fin hi)
  let is_atomic _name _ = true
  let show (n, m) = "(" ^ string_of_int n ^ "," ^ ExtendedNat.show m ^ ")"
end
