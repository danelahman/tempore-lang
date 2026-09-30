open Grade

module type NAMES = sig
  val suffix : string
  val number : string
end

module type COST_NAMES = sig
  include NAMES

  val close : lower:bool -> lit -> lit
end

module Make (D : Delay.MEASURED) (N : COST_NAMES) = struct
  module Trace = TimedTrace.Make (D)

  (* The costs of an operation in the coverage and the allowance orders: the
     values of the ends of its runtime bounds. The delays of a bound are exact,
     so the costs a run is permitted or covered at form a closed set, monotone
     in each cost: a run is permitted at every duration below a supremum iff
     at its value, and covers at every duration above an infimum iff at its
     value. Whether an end is attained is therefore not read. *)
  let lo_cost (bounds : bounds) op =
    read_bound D.read (end_value (fst (bounds.cost op)))

  let hi_cost (bounds : bounds) op =
    read_bound D.read (end_value (snd (bounds.cost op)))

  (** [traces_of_lit lit] is the set of traces the one-sided literal [lit]
      denotes. *)
  let traces_of_lit = Trace.of_lit ~number:N.number

  (** Sets of traces read as lower bounds, in the coverage order. *)
  module LowerTraces = struct
    type t = Trace.traces

    let one = Trace.of_delay D.zero

    (** Coverage order lifted to sets: every guarantee listed on the left has an
        easier one listed on the right. An operation's [lo] bound is what its
        occurrence in the run banks. *)
    let leq bounds = Trace.lower_bound_le (lo_cost bounds)

    (** The unit [{ε}], covered by every run. *)
    let top = one

    let join = Trace.union

    (** A set covering the unit lists the empty run, which is its least. *)
    let is_top _bounds = function [] :: _ -> true | _ -> false

    let compare = Trace.compare
    let hash = Trace.hash
    let of_lit = function Top -> top | lit -> traces_of_lit lit
  end

  (** Sets of traces read as upper bounds, in the allowance order, with a
      separate greatest point [Unbounded]. *)
  module UpperTraces = struct
    type t =
      | Within of Trace.traces  (** every run stays within a listed bound *)
      | Unbounded  (** any run; printed as [⊤] *)

    let one = Within (Trace.of_delay D.zero)

    let mul p q =
      match (p, q) with
      | Within p, Within q -> Within (Trace.product p q)
      | _ -> Unbounded

    (** Allowance order lifted to sets: every bound listed on the left stays
        within some bound listed on the right. An operation's [hi] bound is what
        it costs to buy with banked time. *)
    let leq bounds p q =
      match (p, q) with
      | _, Unbounded -> true
      | Unbounded, Within _ -> false
      | Within p, Within q -> Trace.upper_bound_le (hi_cost bounds) p q

    let join p q =
      match (p, q) with
      | Within p, Within q -> Within (Trace.union p q)
      | _ -> Unbounded

    (** No set of runs allows every run. *)
    let is_top _bounds = function Unbounded -> true | Within _ -> false

    let compare p q =
      match (p, q) with
      | Within p, Within q -> Trace.compare p q
      | Unbounded, Within _ -> -1
      | Within _, Unbounded -> 1
      | Unbounded, Unbounded -> 0

    let hash = function Within p -> Trace.hash p | Unbounded -> -1
    let events = function Within p -> Trace.events p | Unbounded -> []
    let of_lit = function Top -> Unbounded | lit -> Within (traces_of_lit lit)
    let show = function Within p -> Trace.show p | Unbounded -> "⊤"
  end

  (** [extremal_duration ~lower cost p] is the infimum of the durations of the
      runs of [p] if [lower], and their supremum otherwise, each operation
      lasting the end [cost] of its runtime bounds, measured by
      {!Delay.MEASURED.to_rational}: the end of a run is the sum of those of its
      events, attained iff each of them is, and of the runs the least, or the
      greatest, by {!Grade.compare_ends}. *)
  let extremal_duration ~lower cost p =
    let run =
      List.fold_left
        (fun d -> function
          | Trace.Ev o -> add_ends d (cost o)
          | Trace.Wait n -> add_ends d (Closed (D.to_rational n)))
        (Closed Rational.zero)
    in
    let pick d d' =
      let c = compare_ends ~lower d d' in
      if if lower then c <= 0 else c >= 0 then d else d'
    in
    match List.map run p with
    | [] -> invalid_arg "TimedTraceGrades.extremal_duration: no runs"
    | d :: ds -> List.fold_left pick d ds

  (** The runtime bounds implied by a lower-bound component [lo] and an
      upper-bound component [hi]. *)
  let implied_trace_bounds bounds lo = function
    | UpperTraces.Within hi ->
        let cost end_ op = end_ (bounds.cost op) in
        Some
          ( extremal_duration ~lower:true (cost fst) lo,
            extremal_duration ~lower:false (cost snd) hi )
    | UpperTraces.Unbounded -> None

  let atomic_traces name = [ [ Trace.Ev name ] ]

  (* The time shadows [of_bounds] are those of the closed hull of the runtime
     bounds ({!Grade.hull}): a finite set of traces has exact delays, and
     expresses no strict end. *)

  module LowerBound = struct
    include LowerTraces
    module Delay = D

    let name = "traces-cost-lower-bound" ^ N.suffix
    let mul = Trace.product
    let leq_symbol = "<="
    let equal bounds p q = leq bounds p q && leq bounds q p
    let counterexample _bounds _ _ = None
    let unit_least = false
    let commutative = false
    let needs_op_bounds = true
    let events = Trace.events

    let implied_bounds bounds p =
      implied_trace_bounds bounds p (UpperTraces.Within p)

    let inhabited _bounds _ = true
    let of_delay = Trace.of_delay
    let of_bounds b = Trace.of_delay (fst (hull b))
    let is_atomic name p = Trace.equal p (atomic_traces name)
    let show = Trace.show
    let witnesses ~degree:_ _bounds = sampled mul
  end

  module UpperBound = struct
    include UpperTraces
    module Delay = D

    let name = "traces-cost-upper-bound" ^ N.suffix
    let leq_symbol = "<="
    let top = Unbounded
    let equal bounds p q = leq bounds p q && leq bounds q p
    let counterexample _bounds _ _ = None
    let unit_least = true
    let commutative = false
    let needs_op_bounds = true

    let implied_bounds bounds = function
      | Within p -> implied_trace_bounds bounds p (Within p)
      | Unbounded -> None

    let inhabited _bounds _ = true
    let of_delay d = Within (Trace.of_delay d)
    let of_bounds b = Within (Trace.of_delay (snd (hull b)))
    let is_atomic name p = compare p (Within (atomic_traces name)) = 0
    let witnesses ~degree:_ _bounds = sampled mul
  end

  module Interval = struct
    type t = LowerTraces.t * UpperTraces.t

    module Delay = D

    let name = "traces-cost-interval" ^ N.suffix
    let one = (LowerTraces.one, UpperTraces.one)
    let mul (lo, hi) (lo', hi') = (Trace.product lo lo', UpperTraces.mul hi hi')

    let leq bounds (lo, hi) (lo', hi') =
      LowerTraces.leq bounds lo lo' && UpperTraces.leq bounds hi hi'

    let leq_symbol = "<="

    (** The weakest guarantee under an unbounded allowance. *)
    let top = (LowerTraces.top, UpperTraces.Unbounded)

    let join (lo, hi) (lo', hi') =
      (LowerTraces.join lo lo', UpperTraces.join hi hi')

    let equal bounds p q = leq bounds p q && leq bounds q p

    let is_top bounds (lo, hi) =
      LowerTraces.is_top bounds lo && UpperTraces.is_top bounds hi

    let compare (lo, hi) (lo', hi') =
      match LowerTraces.compare lo lo' with
      | 0 -> UpperTraces.compare hi hi'
      | c -> c

    let hash (lo, hi) = combine (LowerTraces.hash lo) (UpperTraces.hash hi)
    let counterexample _bounds _ _ = None
    let unit_least = false
    let commutative = false
    let needs_op_bounds = true

    let events (lo, hi) =
      List.sort_uniq String.compare (Trace.events lo @ UpperTraces.events hi)

    let implied_bounds bounds (lo, hi) = implied_trace_bounds bounds lo hi
    let inhabited _bounds _ = true

    (** [diagonal lit] is the pair of the set of traces [lit] denotes with
        itself. *)
    let diagonal lit =
      let ts = traces_of_lit lit in
      (ts, UpperTraces.Within ts)

    let of_lit = function
      | Top -> top
      | Braces _ as lit -> diagonal lit
      | lit when Option.is_some (Trace.number lit) -> diagonal lit
      | lit ->
          bounds_of_lit lit ~number:Trace.number ~close:N.close
            ~lower:LowerTraces.of_lit ~upper:UpperTraces.of_lit
            ~unbounded:UpperTraces.Unbounded ~bounds:"sets of traces"

    let of_delay d =
      let ts = Trace.of_delay d in
      (ts, UpperTraces.Within ts)

    let of_bounds b =
      let lo, hi = hull b in
      (Trace.of_delay lo, UpperTraces.Within (Trace.of_delay hi))

    let is_atomic name (lo, hi) =
      LowerBound.is_atomic name lo && UpperBound.is_atomic name hi

    let show (lo, hi) =
      show_bounds (Trace.show lo)
        (match hi with
        | UpperTraces.Within p -> Some (Trace.show p)
        | UpperTraces.Unbounded -> None)

    let witnesses ~degree:_ _bounds = sampled mul
  end
end

include
  Make
    (Delay.Nat)
    (struct
      let suffix = ""
      let number = "integer"
      let close = close_integer
    end)

module Rational =
  Make
    (Delay.Rational)
    (struct
      let suffix = "-rational"
      let number = "number"

      let close ~lower:_ a =
        invalid_lit a
          "an open endpoint denotes an infinite set of runs, which these \
           grades do not express"
    end)
