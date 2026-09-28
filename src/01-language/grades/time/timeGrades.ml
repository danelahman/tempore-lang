open Grade

module type DOMAIN = sig
  type t

  val module_name : string
  val prefix : string
  val zero : t
  val add : t -> t -> t
  val compare : t -> t -> int
  val hash : t -> int
  val of_int : int -> t
  val read : Grade.lit -> t option
  val numbers : string
  val show : t -> string
  val witnesses : degree:int -> t list -> t list
end

module Make (N : DOMAIN) = struct
  module Ext = Extended.Make (N)

  (** [duration_of_lit expected lit] is the non-negative duration the literal
      [lit] denotes; any other form is rejected as not the [expected] one. *)
  let duration_of_lit expected lit =
    match N.read lit with
    | Some n when N.compare n N.zero < 0 ->
        invalid_lit lit "grades must be non-negative"
    | Some n -> n
    | None ->
        invalid_lit lit "grades are %s, not %s" expected (describe_lit lit)

  (** [of_nat who n] is the duration of [n] time steps, checked for [who]. *)
  let of_nat who n = N.of_int (check_nat (N.module_name ^ "." ^ who) n)

  let min n m = if N.compare n m <= 0 then n else m

  module LowerBound = struct
    type t = N.t

    let name = N.prefix ^ "time-lower-bound"
    let one = N.zero
    let mul = N.add
    let leq _bounds n m = N.compare n m >= 0
    let leq_symbol = ">="
    let top = N.zero
    let join = min
    let equal _bounds n m = N.compare n m = 0
    let is_top _bounds n = N.compare top n = 0
    let compare = N.compare
    let hash = N.hash
    let counterexample _bounds _ _ = None
    let unit_least = false
    let commutative = true
    let needs_op_bounds = false
    let events _ = []
    let implied_bounds _bounds _ = None
    let inhabited _bounds _ = true

    let of_lit = function
      | Top -> top
      | lit -> duration_of_lit ("plain " ^ N.numbers) lit

    let of_nat = of_nat "LowerBound"
    let of_bounds (lo, _hi) = N.of_int lo
    let is_atomic _name _ = true
    let show = N.show
    let witnesses ~degree _bounds cs = (N.witnesses ~degree cs, Complete)
  end

  module UpperBound = struct
    type t = Ext.t

    let name = N.prefix ^ "time-upper-bound"
    let one = Ext.Fin N.zero
    let mul = Ext.add
    let leq _bounds = Ext.leq
    let leq_symbol = "<="
    let top = Ext.Inf
    let join = Ext.max
    let equal _bounds = Ext.equal
    let is_top _bounds = Ext.equal top
    let compare = Ext.compare
    let hash = Ext.hash
    let counterexample _bounds _ _ = None
    let unit_least = true
    let commutative = true
    let needs_op_bounds = false
    let events _ = []
    let implied_bounds _bounds _ = None
    let inhabited _bounds _ = true

    let of_lit = function
      | Top | Inf -> top
      | lit -> Ext.Fin (duration_of_lit ("plain " ^ N.numbers ^ " or '∞'") lit)

    let of_nat n = Ext.Fin (of_nat "UpperBound" n)
    let of_bounds (_lo, hi) = Ext.Fin (N.of_int hi)
    let is_atomic _name _ = true
    let show = Ext.show

    let witnesses ~degree _bounds cs =
      let finite = List.filter_map Ext.to_fin cs in
      ( List.map (fun n -> Ext.Fin n) (N.witnesses ~degree finite) @ [ top ],
        Complete )
  end

  module Interval = struct
    type t = N.t * Ext.t

    let name = N.prefix ^ "time-interval"
    let one = (N.zero, Ext.Fin N.zero)
    let mul (n, m) (k, l) = (N.add n k, Ext.add m l)
    let leq _bounds (n, m) (k, l) = N.compare k n <= 0 && Ext.leq m l
    let leq_symbol = "<="
    let top = (N.zero, Ext.Inf)
    let join (n, m) (k, l) = (min n k, Ext.max m l)

    let compare (n, m) (k, l) =
      match N.compare n k with 0 -> Ext.compare m l | c -> c

    let equal _bounds p q = compare p q = 0
    let is_top _bounds p = compare p top = 0
    let hash (n, m) = combine (N.hash n) (Ext.hash m)
    let counterexample _bounds _ _ = None
    let unit_least = false
    let commutative = true
    let needs_op_bounds = false
    let events _ = []
    let implied_bounds _bounds _ = None
    let inhabited _bounds _ = true

    (** [interval lit n m] is the interval from [n] to [m], checked. *)
    let interval lit n m =
      if N.compare n N.zero < 0 then
        invalid_lit lit "interval endpoints must be non-negative"
      else if not (Ext.leq (Ext.Fin n) m) then
        invalid_lit lit "interval endpoints must satisfy n <= m"
      else (n, m)

    let of_lit = function
      | Top -> top
      | Tuple [ l; r ] as lit -> (
          let upper =
            match r with
            | Inf -> Some Ext.Inf
            | r -> Option.map (fun m -> Ext.Fin m) (N.read r)
          in
          match (N.read l, upper) with
          | Some n, Some m -> interval lit n m
          | _ ->
              invalid_lit lit
                "interval endpoints are %s, the upper one possibly '∞'"
                N.numbers)
      | lit ->
          invalid_lit lit "grades are intervals '(n, m)', not %s"
            (describe_lit lit)

    let of_nat n =
      let n = of_nat "Interval" n in
      (n, Ext.Fin n)

    let of_bounds (lo, hi) = (N.of_int lo, Ext.Fin (N.of_int hi))
    let is_atomic _name _ = true
    let show (n, m) = "(" ^ N.show n ^ "," ^ Ext.show m ^ ")"

    (* The endpoints are compared, multiplied and joined separately, so an
       ordering fails iff it fails at the lower endpoints, at the lower-bound
       witnesses paired with [∞], or at the upper ones, at [0] paired with the
       upper-bound witnesses. *)
    let witnesses ~degree bounds cs =
      let lower, _ = LowerBound.witnesses ~degree bounds (List.map fst cs) in
      let upper, _ = UpperBound.witnesses ~degree bounds (List.map snd cs) in
      ( List.map (fun n -> (n, Ext.Inf)) lower
        @ List.map (fun m -> (N.zero, m)) upper,
        Complete )
  end
end

(* Completeness of the witnesses. Products being sums and joins minima
   (lower bounds) or maxima (upper bounds), an expression over the constants
   [cs] and a rigid [j] is, at a finite [j], the minimum or maximum of affine
   pieces [c + a·j], [a ∈ ℕ] and [c] a sum of some of the constants, so that
   [c ≤ s] for [s] the sum of the finite ones; a piece with an infinite
   constant is constantly [∞]. Two pieces of different slopes cross at
   [j = (c' - c) / (a - a') ≤ s], so beyond [s] each side of an ordering is
   one piece and their difference keeps its sign: the ordering fails at some
   [j] iff it fails at some [j ≤ s+1] or, for upper bounds, at [j = ∞]. The
   argument is for one rigid; for several no grid is complete, e.g.
   [j₂ ≥ min(j₁, 2·j₂)] fails at [(2, 1)] but nowhere in [{0, 1}²]. *)
include Make (struct
  type t = int

  let module_name = "TimeGrades"
  let prefix = ""
  let zero = 0
  let add = ( + )
  let compare = Int.compare
  let hash = Int.hash
  let of_int n = n
  let read = function Int n -> Some n | _ -> None
  let numbers = "integers"
  let show = string_of_int

  (** [0, ..., s+1], [s] the sum of [cs]. *)
  let witnesses ~degree:_ cs = List.init (List.fold_left ( + ) 0 cs + 2) Fun.id
end)
