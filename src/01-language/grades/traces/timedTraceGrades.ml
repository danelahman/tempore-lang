open Grade

module type NAMES = sig
  val suffix : string
  val number : string
end

module Make (D : Delay.MEASURED) (N : NAMES) = struct
  module Trace = TimedTrace.Make (D)

  let lo_cost (bounds : bounds) op = read_bound D.read (fst (bounds.cost op))
  let hi_cost (bounds : bounds) op = read_bound D.read (snd (bounds.cost op))

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

    let max_duration bounds = function
      | Within p -> Some (Trace.max_duration (hi_cost bounds) p)
      | Unbounded -> None

    let of_lit = function Top -> Unbounded | lit -> Within (traces_of_lit lit)
    let show = function Within p -> Trace.show p | Unbounded -> "⊤"
  end

  (** The runtime bounds implied by a lower-bound component [lo] and an
      upper-bound component [hi], measured by {!Delay.MEASURED.to_rational}. *)
  let implied_trace_bounds bounds lo hi =
    Option.map
      (fun slowest ->
        ( D.to_rational (Trace.min_duration (lo_cost bounds) lo),
          D.to_rational slowest ))
      (UpperTraces.max_duration bounds hi)

  let atomic_traces name = [ [ Trace.Ev name ] ]

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
    let of_bounds (lo, _hi) = Trace.of_delay lo
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
    let of_bounds (_lo, hi) = Within (Trace.of_delay hi)
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
          bounds_of_lit lit ~number:Trace.number ~lower:LowerTraces.of_lit
            ~upper:UpperTraces.of_lit ~unbounded:UpperTraces.Unbounded
            ~bounds:"sets of traces"

    let of_delay d =
      let ts = Trace.of_delay d in
      (ts, UpperTraces.Within ts)

    let of_bounds (lo, hi) =
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
    end)

module Rational =
  Make
    (Delay.Rational)
    (struct
      let suffix = "-rational"
      let number = "number"
    end)
