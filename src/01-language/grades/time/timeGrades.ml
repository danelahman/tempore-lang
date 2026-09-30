open Grade

module type NAMES = sig
  val suffix : string
  val numbers : string
end

module Make (D : Delay.ORDERED) (N : NAMES) = struct
  module Ext = Extended.Make (D)

  (** [negate lit] is the literal of the negation of the number [lit]. *)
  let negate = function
    | Int n -> Some (rational_lit (Rational.neg (Rational.of_int n)))
    | Rat q -> Some (rational_lit (Rational.neg q))
    | _ -> None

  (** [signed lit] is [Some (false, d)] if the literal [lit] denotes the delay
      [d], [Some (true, d)] if it denotes the negation of a positive delay [d],
      and [None] otherwise. *)
  let signed lit =
    match D.read lit with
    | Some d -> Some (false, d)
    | None -> (
        match Option.bind (negate lit) D.read with
        | Some d when not (D.leq d D.zero) -> Some (true, d)
        | _ -> None)

  (** [duration_of_lit expected lit] is the delay the literal [lit] denotes; any
      other form is rejected as not the [expected] one. *)
  let duration_of_lit expected lit =
    match signed lit with
    | Some (false, d) -> d
    | Some (true, _) -> invalid_lit lit "grades must be non-negative"
    | None ->
        invalid_lit lit "grades are %s, not %s" expected (describe_lit lit)

  module LowerBound = struct
    type t = D.t

    module Delay = D

    let name = "time-lower-bound" ^ N.suffix
    let one = D.zero
    let mul = D.add
    let leq _bounds n m = D.leq m n
    let leq_symbol = ">="
    let top = D.zero
    let join = D.min
    let equal _bounds = D.equal
    let is_top _bounds n = D.equal top n
    let compare = D.compare
    let hash = D.hash
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

    let of_delay d = d
    let of_bounds (lo, _hi) = lo
    let is_atomic _name _ = true
    let show = D.show
    let witnesses ~degree _bounds cs = D.witnesses ~degree cs
  end

  module UpperBound = struct
    type t = Ext.t

    module Delay = D

    let name = "time-upper-bound" ^ N.suffix
    let one = Ext.Fin D.zero
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

    let of_delay d = Ext.Fin d
    let of_bounds (_lo, hi) = Ext.Fin hi
    let is_atomic _name _ = true
    let show = Ext.show

    (* A piece of an expression with an infinite constant is constantly [∞],
       so the witnesses of the finite constants decide the finite rigids, and
       [∞] the infinite one. *)
    let witnesses ~degree _bounds cs =
      let finite, completeness =
        D.witnesses ~degree (List.filter_map Ext.to_fin cs)
      in
      (List.map (fun n -> Ext.Fin n) finite @ [ top ], completeness)
  end

  module Interval = struct
    type t = D.t * Ext.t

    module Delay = D

    let name = "time-interval" ^ N.suffix
    let one = (D.zero, Ext.Fin D.zero)
    let mul (n, m) (k, l) = (D.add n k, Ext.add m l)
    let leq _bounds (n, m) (k, l) = D.leq k n && Ext.leq m l
    let leq_symbol = "<="
    let top = (D.zero, Ext.Inf)
    let join (n, m) (k, l) = (D.min n k, Ext.max m l)

    let compare (n, m) (k, l) =
      match D.compare n k with 0 -> Ext.compare m l | c -> c

    let equal _bounds (n, m) (k, l) = D.equal n k && Ext.equal m l
    let is_top _bounds (n, m) = D.equal n D.zero && Ext.equal m Ext.Inf
    let hash (n, m) = combine (D.hash n) (Ext.hash m)
    let counterexample _bounds _ _ = None
    let unit_least = false
    let commutative = true
    let needs_op_bounds = false
    let events _ = []
    let implied_bounds _bounds _ = None
    let inhabited _bounds _ = true

    (** [interval lit l r] is the interval from the signed delay [l] to the
        signed delay or [∞] [r], checked. *)
    let interval lit l r =
      match (l, r) with
      | (true, _), _ ->
          invalid_lit lit "interval endpoints must be non-negative"
      | (false, n), (false, m) when Ext.leq (Ext.Fin n) m -> (n, m)
      | _ -> invalid_lit lit "interval endpoints must satisfy n <= m"

    let of_lit = function
      | Top -> top
      | Interval (None, _) as lit ->
          invalid_lit lit "interval endpoints must be non-negative"
      | Interval (Some l, r) as lit -> (
          let upper =
            match r with
            | None -> Some (false, Ext.Inf)
            | Some r -> Option.map (fun (s, m) -> (s, Ext.Fin m)) (signed r)
          in
          match (signed l, upper) with
          | Some l, Some r -> interval lit l r
          | _ -> invalid_lit lit "interval endpoints are %s" N.numbers)
      | lit when is_pair_interval lit -> reject_pair_interval lit
      | lit ->
          invalid_lit lit "grades are intervals %s, not %s" interval_forms
            (describe_lit lit)

    let of_delay d = (d, Ext.Fin d)
    let of_bounds (lo, hi) = (lo, Ext.Fin hi)
    let is_atomic _name _ = true

    let show (n, m) =
      match m with
      | Ext.Fin m -> "[" ^ D.show n ^ "," ^ D.show m ^ "]"
      | Ext.Inf -> "[" ^ D.show n ^ ",∞)"

    (* The endpoints are compared, multiplied and joined separately, so an
       ordering fails iff it fails at the lower endpoints, at the lower-bound
       witnesses paired with [∞], or at the upper ones, at [0] paired with the
       upper-bound witnesses. *)
    let witnesses ~degree bounds cs =
      let lower, completeness =
        LowerBound.witnesses ~degree bounds (List.map fst cs)
      in
      let upper, _ = UpperBound.witnesses ~degree bounds (List.map snd cs) in
      ( List.map (fun n -> (n, Ext.Inf)) lower
        @ List.map (fun m -> (D.zero, m)) upper,
        completeness )
  end
end

include
  Make
    (Delay.Nat)
    (struct
      let suffix = ""
      let numbers = "integers"
    end)
