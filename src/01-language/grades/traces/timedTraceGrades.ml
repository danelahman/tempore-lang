open Grade

(** [steps q] is the number of time steps of the runtime bound [q]. *)
let steps q = Delay.Nat.to_int (read_bound Delay.Nat.read q)

let lo_cost (bounds : bounds) op = steps (fst (bounds.cost op))
let hi_cost (bounds : bounds) op = steps (snd (bounds.cost op))

(** [traces_of_regex lit r] is the set of traces the star-free regular
    expression [r], without [&], [~] or [_], denotes; [lit] is the literal it is
    part of. *)
let rec traces_of_regex lit = function
  | Letter name -> [ [ TimedTrace.Ev name ] ]
  | Tick n -> TimedTrace.of_delay n
  | Seq (r, s) -> binary lit TimedTrace.product r s
  | Union (r, s) -> binary lit TimedTrace.union r s
  | Star _ -> unsupported lit "repetition '*'"
  | Inter _ -> unsupported lit "intersection '&'"
  | Compl _ -> unsupported lit "complement '~'"
  | Any -> unsupported lit "the wildcard '_'"

(* The operands are read left to right, so the leftmost unsupported form is the
   one reported. *)
and binary lit combine r s =
  let p = traces_of_regex lit r in
  let q = traces_of_regex lit s in
  combine p q

and unsupported lit form =
  invalid_lit lit
    "sets of traces are built from operation names and delays with ';' and '|' \
     only, without %s"
    form

(** [traces_of_lit lit] is the set of traces the one-sided literal [lit]
    denotes. *)
let traces_of_lit = function
  | Int n when n < 0 -> invalid_lit (Int n) "grades must be non-negative"
  | Int n -> TimedTrace.of_delay n
  | Braces r as lit -> traces_of_regex lit r
  | lit ->
      invalid_lit lit
        "grades are a single set of traces '{...}' or a plain integer, not %s"
        (describe_lit lit)

(* The delays are whole time steps: the coverage and
   allowance orders subtract them from the budget, which {!Delay.ORDERED}
   does not offer. *)

(** Sets of traces read as lower bounds, in the coverage order. *)
module LowerTraces = struct
  type t = TimedTrace.traces

  let one = TimedTrace.of_delay 0

  (** Coverage order lifted to sets: every guarantee listed on the left has an
      easier one listed on the right. An operation's [lo] bound is what its
      occurrence in the run banks. *)
  let leq bounds = TimedTrace.lower_bound_le (lo_cost bounds)

  (** The unit [{ε}], covered by every run. *)
  let top = one

  let join = TimedTrace.union

  (** A set covering the unit lists the empty run, which is its least. *)
  let is_top _bounds = function [] :: _ -> true | _ -> false

  let compare = TimedTrace.compare
  let hash = TimedTrace.hash
  let of_lit = function Top -> top | lit -> traces_of_lit lit
end

(** Sets of traces read as upper bounds, in the allowance order, with a separate
    greatest point [Unbounded]. *)
module UpperTraces = struct
  type t =
    | Within of TimedTrace.traces  (** every run stays within a listed bound *)
    | Unbounded  (** any run; printed as [⊤] *)

  let one = Within (TimedTrace.of_delay 0)

  let mul p q =
    match (p, q) with
    | Within p, Within q -> Within (TimedTrace.product p q)
    | _ -> Unbounded

  (** Allowance order lifted to sets: every bound listed on the left stays
      within some bound listed on the right. An operation's [hi] bound is what
      it costs to buy with banked time. *)
  let leq bounds p q =
    match (p, q) with
    | _, Unbounded -> true
    | Unbounded, Within _ -> false
    | Within p, Within q -> TimedTrace.upper_bound_le (hi_cost bounds) p q

  let join p q =
    match (p, q) with
    | Within p, Within q -> Within (TimedTrace.union p q)
    | _ -> Unbounded

  (** No set of runs allows every run. *)
  let is_top _bounds = function Unbounded -> true | Within _ -> false

  let compare p q =
    match (p, q) with
    | Within p, Within q -> TimedTrace.compare p q
    | Unbounded, Within _ -> -1
    | Within _, Unbounded -> 1
    | Unbounded, Unbounded -> 0

  let hash = function Within p -> TimedTrace.hash p | Unbounded -> -1
  let events = function Within p -> TimedTrace.events p | Unbounded -> []

  let max_duration bounds = function
    | Within p -> Some (TimedTrace.max_duration (hi_cost bounds) p)
    | Unbounded -> None

  let of_lit = function Top -> Unbounded | lit -> Within (traces_of_lit lit)
  let show = function Within p -> TimedTrace.show p | Unbounded -> "⊤"
end

(** The runtime bounds implied by a lower-bound component [lo] and an
    upper-bound component [hi]. *)
let implied_trace_bounds bounds lo hi =
  Option.map
    (fun slowest ->
      ( Rational.of_int (TimedTrace.min_duration (lo_cost bounds) lo),
        Rational.of_int slowest ))
    (UpperTraces.max_duration bounds hi)

let atomic_traces name = [ [ TimedTrace.Ev name ] ]

module LowerBound = struct
  include LowerTraces
  module Delay : Delay.STEPPED with type t = int = Delay.Nat

  let name = "traces-lower-bound"
  let mul = TimedTrace.product
  let leq_symbol = "<="
  let equal bounds p q = leq bounds p q && leq bounds q p
  let counterexample _bounds _ _ = None
  let unit_least = false
  let commutative = false
  let needs_op_bounds = true
  let events = TimedTrace.events

  let implied_bounds bounds p =
    implied_trace_bounds bounds p (UpperTraces.Within p)

  let inhabited _bounds _ = true
  let of_delay d = TimedTrace.of_delay (Delay.to_int d)
  let of_bounds (lo, _hi) = TimedTrace.of_delay (Delay.to_int lo)
  let is_atomic name p = TimedTrace.equal p (atomic_traces name)
  let show = TimedTrace.show
  let witnesses ~degree:_ _bounds = sampled mul
end

module UpperBound = struct
  include UpperTraces
  module Delay : Delay.STEPPED with type t = int = Delay.Nat

  let name = "traces-upper-bound"
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
  let of_delay d = Within (TimedTrace.of_delay (Delay.to_int d))
  let of_bounds (_lo, hi) = Within (TimedTrace.of_delay (Delay.to_int hi))
  let is_atomic name p = compare p (Within (atomic_traces name)) = 0
  let witnesses ~degree:_ _bounds = sampled mul
end

module Interval = struct
  type t = LowerTraces.t * UpperTraces.t

  module Delay : Delay.STEPPED with type t = int = Delay.Nat

  let name = "traces-interval"
  let one = (LowerTraces.one, UpperTraces.one)

  let mul (lo, hi) (lo', hi') =
    (TimedTrace.product lo lo', UpperTraces.mul hi hi')

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
    List.sort_uniq String.compare (TimedTrace.events lo @ UpperTraces.events hi)

  let implied_bounds bounds (lo, hi) = implied_trace_bounds bounds lo hi
  let inhabited _bounds _ = true

  let of_lit = function
    | Top -> top
    | (Int _ | Braces _) as lit ->
        let ts = traces_of_lit lit in
        (ts, UpperTraces.Within ts)
    | Tuple [ Int n; Int m ] as lit when n > m ->
        invalid_lit lit "interval endpoints must satisfy n <= m"
    | Tuple [ lo; hi ] as lit ->
        let lo = component_of_lit lit ~context:"" LowerTraces.of_lit lo in
        let hi = component_of_lit lit ~context:"" UpperTraces.of_lit hi in
        (lo, hi)
    | lit ->
        invalid_lit lit
          "grades are pairs '({...}, {...})' of sets of traces, or \
           abbreviations of them, not %s"
          (describe_lit lit)

  let of_delay d =
    let ts = TimedTrace.of_delay (Delay.to_int d) in
    (ts, UpperTraces.Within ts)

  let of_bounds (lo, hi) =
    ( TimedTrace.of_delay (Delay.to_int lo),
      UpperTraces.Within (TimedTrace.of_delay (Delay.to_int hi)) )

  let is_atomic name (lo, hi) =
    LowerBound.is_atomic name lo && UpperBound.is_atomic name hi

  let show (lo, hi) = "(" ^ TimedTrace.show lo ^ "," ^ UpperTraces.show hi ^ ")"
  let witnesses ~degree:_ _bounds = sampled mul
end
