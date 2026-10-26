open Grade

module type NAMES = sig
  type delay

  val suffix : string
  val numbers : string
  val step : delay option
end

module Make (D : Delay.MEASURED) (N : NAMES with type delay = D.t) = struct
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

  (** [is_closed b] is whether the finite end [b] is attained. *)
  let is_closed = function Closed _ -> true | Open _ | Unbounded -> false

  (* The ends of an interval of delays: a lower end is a delay with a flag for
     whether the interval contains it, an upper end a delay or [∞] with such a
     flag, [∞] never contained. The ends are compared as cuts: a closed lower
     end [d] is below the open one, which is below any greater delay; a closed
     upper end [d] is above the open one. Over delays with a least positive
     one, [N.step], every end is closed. *)

  (** [lower_end (d, closed)] is the lower end [d], attained iff [closed], an
      open one replaced by the closed one [N.step] above it if [N.step] is a
      delay. *)
  let lower_end (d, closed) =
    match N.step with
    | Some step when not closed -> (D.add d step, true)
    | _ -> (d, closed)

  (** [upper_end (m, closed)] is the upper end [m], attained iff [closed], an
      open finite one replaced by the closed one [N.step] below it if [N.step]
      is a delay. *)
  let upper_end (m, closed) =
    match (N.step, m) with
    | Some step, Ext.Fin m when not closed -> (Ext.Fin (D.monus m step), true)
    | _ -> (m, closed)

  (** [interval_ends lit lo hi] is the pair of the lower and the upper end of
      the interval literal [lit] from [lo] to [hi], normalised by {!lower_end}
      and {!upper_end}.

      @raise Invalid_literal
        if an endpoint is not a delay or the interval is empty. *)
  let interval_ends lit lo hi =
    match lo with
    | Unbounded -> invalid_lit lit "interval endpoints must be non-negative"
    | Closed l | Open l -> (
        let upper =
          match hi with
          | Unbounded -> Some (false, Ext.Inf)
          | Closed r | Open r ->
              Option.map (fun (s, m) -> (s, Ext.Fin m)) (signed r)
        in
        match (signed l, upper) with
        | Some (true, _), Some _ ->
            invalid_lit lit "interval endpoints must be non-negative"
        | Some (false, n), Some (false, m) when Ext.leq (Ext.Fin n) m ->
            if Ext.leq m (Ext.Fin n) && not (is_closed lo && is_closed hi) then
              invalid_lit lit
                "interval endpoints must satisfy n < m at an open endpoint"
            else
              let ((n, _) as lower) = lower_end (n, is_closed lo)
              and ((m, _) as upper) = upper_end (m, is_closed hi) in
              if Ext.leq (Ext.Fin n) m then (lower, upper)
              else invalid_lit lit "the interval contains no integer"
        | Some _, Some _ ->
            invalid_lit lit "interval endpoints must satisfy n <= m"
        | _ -> invalid_lit lit "interval endpoints are %s" N.numbers)

  (* A lower bound is the lower end of an interval unbounded above. *)
  module LowerBound = struct
    type t = { lo : D.t; lo_closed : bool }

    module Delay = D

    let name = "time-lower-bound" ^ N.suffix

    (** [at_least d] is the closed lower bound [d]. *)
    let at_least lo = { lo; lo_closed = true }

    let one = at_least D.zero

    let mul c d =
      { lo = D.add c.lo d.lo; lo_closed = c.lo_closed && d.lo_closed }

    (** [cut_leq c d] decides whether the end of [c] is below that of [d] as a
        cut. *)
    let cut_leq c d =
      D.leq c.lo d.lo
      && ((not (D.leq d.lo c.lo)) || c.lo_closed || not d.lo_closed)

    let leq _bounds c d = cut_leq d c
    let leq_symbol = ">="
    let top = one
    let join c d = if cut_leq c d then c else d

    let compare c d =
      match D.compare c.lo d.lo with
      | 0 -> Bool.compare c.lo_closed d.lo_closed
      | k -> k

    let equal _bounds c d = compare c d = 0
    let is_top bounds = equal bounds top
    let hash c = Hashing.combine (D.hash c.lo) (Bool.to_int c.lo_closed)
    let counterexample _bounds _ _ = None
    let unit_least = false

    (* Every lower bound is its own closure: [c · c ≾ c]. *)
    let plus c = Some c
    let commutative = true
    let needs_op_bounds = false
    let duration_ends = Grade.Both_ends
    let events _ = []

    (** [end_bound c] is the end of the durations of [c]. *)
    let end_bound c =
      let q = D.to_rational c.lo in
      if c.lo_closed then Closed q else Open q

    let duration_bounds _bounds c = Some (end_bound c, Unbounded)
    let vacuous _bounds _ = None
    let inhabited bounds rho = Grade.inhabited_of vacuous bounds rho

    let of_lit lit =
      match open_pair lit with
      | Top -> top
      | Interval (lo, hi) -> (
          match interval_ends lit lo hi with
          | (lo, lo_closed), (Ext.Inf, _) -> { lo; lo_closed }
          | _ ->
              invalid_lit lit
                "lower bounds are unbounded above, written `n`, `[n, ∞)` or \
                 `(n, ∞)`")
      | lit -> at_least (duration_of_lit ("plain " ^ N.numbers) lit)

    let accepts = reads_lit of_lit
    let of_delay = at_least

    let of_bounds (lo, _) =
      let lo, lo_closed = lower_end (end_value lo, is_closed lo) in
      { lo; lo_closed }

    let is_atomic _name _ = true
    let show c = if c.lo_closed then D.show c.lo else "(" ^ D.show c.lo ^ ", ∞)"

    (* The ends are compared, multiplied and joined as cuts, so the closed
       witnesses of the delays suffice: an open end [(q] acts as the limit of
       the closed ones [\[x] as [x] decreases to [q], so an ordering that fails
       at an open end fails at [q] itself or at the closed ends of the cell of
       the delay witnesses next to [q], where both sides are affine. *)
    let witnesses ~degree _bounds cs =
      let ds, completeness =
        D.witnesses ~degree (List.map (fun c -> c.lo) cs)
      in
      (List.map at_least ds, completeness)
  end

  (* An upper bound is the upper end of an interval from a closed [0]. *)
  module UpperBound = struct
    type t = { hi : Ext.t; hi_closed : bool }

    module Delay = D

    let name = "time-upper-bound" ^ N.suffix

    (** [at_most m] is the upper bound [m], closed unless [m] is [∞]. *)
    let at_most hi = { hi; hi_closed = not (Ext.equal hi Ext.Inf) }

    let one = at_most (Ext.Fin D.zero)

    let mul c d =
      { hi = Ext.add c.hi d.hi; hi_closed = c.hi_closed && d.hi_closed }

    (** [cut_leq c d] decides whether the end of [c] is below that of [d] as a
        cut. *)
    let cut_leq c d =
      Ext.leq c.hi d.hi
      && ((not (Ext.leq d.hi c.hi)) || d.hi_closed || not c.hi_closed)

    let leq _bounds = cut_leq
    let leq_symbol = "<="
    let top = at_most Ext.Inf
    let join c d = if cut_leq c d then d else c

    let compare c d =
      match Ext.compare c.hi d.hi with
      | 0 -> Bool.compare c.hi_closed d.hi_closed
      | k -> k

    let equal _bounds c d = compare c d = 0
    let is_top bounds = equal bounds top
    let hash c = Hashing.combine (Ext.hash c.hi) (Bool.to_int c.hi_closed)
    let counterexample _bounds _ _ = None
    let unit_least = true

    (* The closure of a positive bound is [∞], that of [0] itself. *)
    let plus c = Some (if compare c one = 0 then one else top)
    let commutative = true
    let needs_op_bounds = false
    let duration_ends = Grade.Both_ends
    let events _ = []

    (** [end_bound c] is the end of the durations of [c]. *)
    let end_bound c =
      match c.hi with
      | Ext.Fin m ->
          let q = D.to_rational m in
          if c.hi_closed then Closed q else Open q
      | Ext.Inf -> Unbounded

    let duration_bounds _bounds c = Some (Closed Rational.zero, end_bound c)
    let vacuous _bounds _ = None
    let inhabited bounds rho = Grade.inhabited_of vacuous bounds rho

    let of_lit lit =
      match open_pair lit with
      | Top | Inf -> top
      | Interval (lo, hi) -> (
          match interval_ends lit lo hi with
          | (lo, true), (hi, hi_closed) when D.equal lo D.zero ->
              { hi; hi_closed }
          | _ ->
              invalid_lit lit
                "upper bounds start at a closed 0, written `n`, `[0, n]`, `[0, \
                 n)` or `∞`")
      | lit ->
          at_most
            (Ext.Fin (duration_of_lit ("plain " ^ N.numbers ^ " or `∞`") lit))

    let accepts = reads_lit of_lit
    let of_delay d = at_most (Ext.Fin d)

    let of_bounds (_, hi) =
      let hi, hi_closed = upper_end (Ext.Fin (end_value hi), is_closed hi) in
      { hi; hi_closed }

    let is_atomic _name _ = true

    let show c =
      match c.hi with
      | Ext.Fin m when not c.hi_closed -> "[0, " ^ D.show m ^ ")"
      | hi -> Ext.show hi

    (* A piece of an expression with an infinite constant is constantly [∞],
       so the witnesses of the finite constants decide the finite rigids, and
       [∞] the infinite one. The closed witnesses suffice: an open end [q)]
       acts as the limit of the closed ones [x\]] as [x] increases to [q], so
       an ordering that fails at an open end fails at [q] itself or at the
       closed ends of the cell of the delay witnesses next to [q], where both
       sides are affine. *)
    let witnesses ~degree _bounds cs =
      let finite, completeness =
        D.witnesses ~degree (List.filter_map (fun c -> Ext.to_fin c.hi) cs)
      in
      (List.map (fun n -> at_most (Ext.Fin n)) finite @ [ top ], completeness)
  end

  (* An interval is a pair of a lower and an upper end, compared, multiplied
     and joined separately. *)
  module Interval = struct
    type t = { lower : LowerBound.t; upper : UpperBound.t }

    module Delay = D

    let name = "time-interval" ^ N.suffix
    let one = { lower = LowerBound.one; upper = UpperBound.one }

    (* The sum of two intervals, their Minkowski sum: an endpoint of the sum is
       open iff one of those it sums is. *)
    let mul c d =
      {
        lower = LowerBound.mul c.lower d.lower;
        upper = UpperBound.mul c.upper d.upper;
      }

    let leq bounds c d =
      LowerBound.leq bounds c.lower d.lower
      && UpperBound.leq bounds c.upper d.upper

    let leq_symbol = "<="
    let top = { lower = LowerBound.top; upper = UpperBound.top }

    let join c d =
      {
        lower = LowerBound.join c.lower d.lower;
        upper = UpperBound.join c.upper d.upper;
      }

    let compare c d =
      match LowerBound.compare c.lower d.lower with
      | 0 -> UpperBound.compare c.upper d.upper
      | k -> k

    let equal _bounds c d = compare c d = 0
    let is_top bounds = equal bounds top

    let hash c =
      Hashing.combine (LowerBound.hash c.lower) (UpperBound.hash c.upper)

    let counterexample _bounds _ _ = None
    let unit_least = false

    (* An interval with a positive upper endpoint closes to the same lower
       endpoint and no upper one; the unit is its own closure. *)
    let plus c =
      Some
        (if UpperBound.compare c.upper UpperBound.one = 0 then c
         else { c with upper = UpperBound.top })

    let commutative = true
    let needs_op_bounds = false
    let duration_ends = Grade.Both_ends
    let events _ = []

    let duration_bounds _bounds c =
      Some (LowerBound.end_bound c.lower, UpperBound.end_bound c.upper)

    let vacuous _bounds _ = None
    let inhabited bounds rho = Grade.inhabited_of vacuous bounds rho

    let of_lit lit =
      match open_pair lit with
      | Top -> top
      | Interval (lo, hi) ->
          let (lo, lo_closed), (hi, hi_closed) = interval_ends lit lo hi in
          { lower = { lo; lo_closed }; upper = { hi; hi_closed } }
      | _ ->
          invalid_lit lit "grades are intervals %s, not %s" interval_forms
            (describe_lit lit)

    let accepts = reads_lit of_lit

    let of_delay d =
      { lower = LowerBound.of_delay d; upper = UpperBound.of_delay d }

    let of_bounds b =
      { lower = LowerBound.of_bounds b; upper = UpperBound.of_bounds b }

    let is_atomic _name _ = true

    let show { lower; upper } =
      (if lower.lo_closed then "[" else "(")
      ^ D.show lower.lo ^ ", " ^ Ext.show upper.hi
      ^ if upper.hi_closed then "]" else ")"

    (* An ordering fails iff it fails at the lower endpoints, at the
       lower-bound witnesses paired with [∞], or at the upper ones, at [0]
       paired with the upper-bound witnesses. *)
    let witnesses ~degree bounds cs =
      let lower, lower_completeness =
        LowerBound.witnesses ~degree bounds (List.map (fun c -> c.lower) cs)
      in
      let upper, upper_completeness =
        UpperBound.witnesses ~degree bounds (List.map (fun c -> c.upper) cs)
      in
      ( List.map (fun lower -> { lower; upper = UpperBound.top }) lower
        @ List.map (fun upper -> { lower = LowerBound.one; upper }) upper,
        match (lower_completeness, upper_completeness) with
        | Grade.Complete, Grade.Complete -> Grade.Complete
        | Grade.Partial, _ | _, Grade.Partial -> Grade.Partial )
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
