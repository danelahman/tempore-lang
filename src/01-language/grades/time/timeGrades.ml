open Grade

module type NAMES = sig
  type delay

  val suffix : string
  val numbers : string
  val step : delay option
end

module Make (D : Delay.MONUS) (N : NAMES with type delay = D.t) = struct
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

  (* An interval is a pair of endpoints, each a delay, or [∞] above, with a
     flag for whether the interval contains it; [∞] is never contained. The
     endpoints are compared as cuts: a closed lower endpoint [d] is below the
     open one, which is below any greater delay; a closed upper endpoint [d] is
     above the open one. Over delays with a least positive one, [N.step], every
     endpoint is closed. *)
  module Interval = struct
    type t = { lo : D.t; lo_closed : bool; hi : Ext.t; hi_closed : bool }

    module Delay = D

    let name = "time-interval" ^ N.suffix

    (** [closed lo hi] is the closed interval from [lo] to [hi]. *)
    let closed lo hi =
      { lo; lo_closed = true; hi; hi_closed = not (Ext.equal hi Ext.Inf) }

    let one = closed D.zero (Ext.Fin D.zero)

    (* The sum of two intervals, their Minkowski sum: an endpoint of the sum is
       open iff one of those it sums is. *)
    let mul c d =
      {
        lo = D.add c.lo d.lo;
        lo_closed = c.lo_closed && d.lo_closed;
        hi = Ext.add c.hi d.hi;
        hi_closed = c.hi_closed && d.hi_closed;
      }

    (** [lower_leq c d] decides whether the lower endpoint of [c] is below that
        of [d] as a cut. *)
    let lower_leq c d =
      D.leq c.lo d.lo
      && ((not (D.leq d.lo c.lo)) || c.lo_closed || not d.lo_closed)

    (** [upper_leq c d] decides whether the upper endpoint of [c] is below that
        of [d] as a cut. *)
    let upper_leq c d =
      Ext.leq c.hi d.hi
      && ((not (Ext.leq d.hi c.hi)) || d.hi_closed || not c.hi_closed)

    let leq _bounds c d = lower_leq d c && upper_leq c d
    let leq_symbol = "<="
    let top = closed D.zero Ext.Inf

    let join c d =
      let l = if lower_leq c d then c else d in
      let u = if upper_leq c d then d else c in
      { lo = l.lo; lo_closed = l.lo_closed; hi = u.hi; hi_closed = u.hi_closed }

    let compare c d =
      match D.compare c.lo d.lo with
      | 0 -> (
          match Bool.compare c.lo_closed d.lo_closed with
          | 0 -> (
              match Ext.compare c.hi d.hi with
              | 0 -> Bool.compare c.hi_closed d.hi_closed
              | k -> k)
          | k -> k)
      | k -> k

    let equal _bounds c d = compare c d = 0
    let is_top bounds = equal bounds top

    let hash c =
      combine
        (combine (D.hash c.lo) (Bool.to_int c.lo_closed))
        (combine (Ext.hash c.hi) (Bool.to_int c.hi_closed))

    let counterexample _bounds _ _ = None
    let unit_least = false
    let commutative = true
    let needs_op_bounds = false
    let events _ = []
    let implied_bounds _bounds _ = None
    let inhabited _bounds _ = true

    (** [interval lit lo hi] is the interval of the literal [lit] from [lo] to
        [hi], each a delay or [∞] with a flag for whether it is contained, and
        an open endpoint replaced by the closed one [N.step] away if [N.step] is
        a delay.

        @raise Invalid_literal if the interval is empty. *)
    let interval lit (lo, lo_closed) (hi, hi_closed) =
      let lo, lo_closed =
        match N.step with
        | Some step when not lo_closed -> (D.add lo step, true)
        | _ -> (lo, lo_closed)
      in
      let hi, hi_closed =
        match (N.step, hi) with
        | Some step, Ext.Fin m when not hi_closed ->
            (Ext.Fin (D.monus m step), true)
        | _ -> (hi, hi_closed)
      in
      if Ext.leq (Ext.Fin lo) hi then { lo; lo_closed; hi; hi_closed }
      else invalid_lit lit "the interval contains no integer"

    let of_lit lit =
      match open_pair lit with
      | Top -> top
      | Interval (Unbounded, _) ->
          invalid_lit lit "interval endpoints must be non-negative"
      | Interval (((Closed l | Open l) as lo), hi) -> (
          let upper =
            match hi with
            | Unbounded -> Some (false, Ext.Inf)
            | Closed r | Open r ->
                Option.map (fun (s, m) -> (s, Ext.Fin m)) (signed r)
          in
          let closed = function Closed _ -> true | _ -> false in
          match (signed l, upper) with
          | Some (true, _), Some _ ->
              invalid_lit lit "interval endpoints must be non-negative"
          | Some (false, n), Some (false, m) when Ext.leq (Ext.Fin n) m ->
              if Ext.leq m (Ext.Fin n) && not (closed lo && closed hi) then
                invalid_lit lit
                  "interval endpoints must satisfy n < m at an open endpoint"
              else interval lit (n, closed lo) (m, closed hi)
          | Some _, Some _ ->
              invalid_lit lit "interval endpoints must satisfy n <= m"
          | _ -> invalid_lit lit "interval endpoints are %s" N.numbers)
      | _ ->
          invalid_lit lit "grades are intervals %s, not %s" interval_forms
            (describe_lit lit)

    let of_delay d = closed d (Ext.Fin d)
    let of_bounds (lo, hi) = closed lo (Ext.Fin hi)
    let is_atomic _name _ = true

    let show c =
      (if c.lo_closed then "[" else "(")
      ^ D.show c.lo ^ ", " ^ Ext.show c.hi
      ^ if c.hi_closed then "]" else ")"

    (* The endpoints are compared, multiplied and joined separately, so an
       ordering fails iff it fails at the lower endpoints, at the lower-bound
       witnesses paired with [∞], or at the upper ones, at [0] paired with the
       upper-bound witnesses. The closed witnesses suffice: an open endpoint
       [(q] acts as the limit of the closed ones [\[x] as [x] decreases to [q],
       and [q)] as that of [x\]] as [x] increases to [q], so an ordering that
       fails at an open endpoint fails at [q] itself or at the closed endpoints
       of the cell of the delay witnesses next to [q], where both sides are
       affine. *)
    let witnesses ~degree bounds cs =
      let lower, completeness =
        LowerBound.witnesses ~degree bounds (List.map (fun c -> c.lo) cs)
      in
      let upper, _ =
        UpperBound.witnesses ~degree bounds (List.map (fun c -> c.hi) cs)
      in
      ( List.map (fun n -> closed n Ext.Inf) lower
        @ List.map (fun m -> closed D.zero m) upper,
        completeness )
  end
end

include
  Make
    (Delay.Nat)
    (struct
      type delay = Delay.Nat.t

      let suffix = ""
      let numbers = "integers"
      let step = Some Delay.Nat.step
    end)
