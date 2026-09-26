(** Grades: partially ordered monoids with a greatest element and binary joins,
    after the [Grade] record of the formalisation ([Syntax/Grades.agda]), and
    the instances the prototype offers.

    {2 Cost model}

    The orders of the timed-trace grades read the runtime bounds
    [within (lo, hi)] that operations declare. The operations that depend on the
    order, [leq] and [equal], take them as an argument of type {!bounds}; the
    time grades ignore it.

    {2 Representations}

    A set of timed traces is kept sorted and duplicate-free (see {!TimedTrace}),
    not reduced to the antichain of its extremal members as in the formalisation
    ([Syntax/Grades/Traces/Reduced.agda]), since that reduction depends on the
    order and hence on the cost model. So [mul] and [join] need no cost model,
    but a trace grade may have several representations; [equal] is mutual [leq],
    which is equality of the reduced antichains. *)

(** The events a trace literal is made of, re-exported from {!TimedTrace} so
    that the parser can build literals without a conversion step. *)
type trace_event = TimedTrace.event = Ev of string | Wait of int

(** Concrete representation of grades as they appear in source. *)
type lit =
  | Int of int  (** A single non-negative integer, e.g. [42] *)
  | Pair of int * int
      (** A pair of integers, e.g. [(1, 5)] for interval grades *)
  | Traces of trace_event list list
      (** A set of timed traces, e.g. [{Read; 3; Send | Send; Send}] *)
  | TracePair of trace_event list list * trace_event list list
      (** A pair of sets of timed traces, e.g. [({3}, {Send | 5})] *)

type bounds = string -> int * int
(** A cost model: the runtime bounds [(lo, hi)] declared by each operation,
    given by name. *)

module type S = sig
  type t
  (** The carrier. *)

  val name : string
  (** The name of the grade, e.g. ["time-interval"]. *)

  val one : t
  (** The unit [u] of {!mul}. *)

  val mul : t -> t -> t
  (** The monoid product [_·_]. *)

  val leq : bounds -> t -> t -> bool
  (** [leq bounds c d] decides the partial order [c ≾ d] under the cost model
      [bounds]. *)

  val leq_symbol : string
  (** The notation for {!leq} in printed inequalities. *)

  val top : t
  (** The greatest grade [⊤]. *)

  val join : t -> t -> t
  (** The binary join [_⊔_]. *)

  val of_nat : int -> t
  (** [of_nat n] is the grade of [n] time steps; [of_nat 0] is {!one}. *)

  val equal : bounds -> t -> t -> bool
  (** [equal bounds c d] decides [c = d] under the cost model [bounds]. *)

  val unit_least : bool
  (** Whether {!one} is the least grade (the formalisation's [u-least?]). *)

  val commutative : bool
  (** Whether {!mul} is commutative (the formalisation's [·-comm?]). *)

  val needs_op_bounds : bool
  (** Whether operation signatures must carry their runtime bounds
      [within (lo, hi)]. *)

  val implied_bounds : bounds -> t -> (int * int) option
  (** [implied_bounds bounds rho] is the pair of runtime bounds the grade [rho]
      itself implies: the duration of its fastest run, each event counted at the
      lower end of its [bounds], and the duration of its slowest run, each event
      counted at the upper end. The fastest run is taken over the lower-bound
      component of the grade and the slowest over its upper-bound component,
      which coincide for the one-sided trace grades. The time grades imply
      nothing, since there the grade of an operation already is its runtime
      bound, and return [None]; so does an unbounded upper-bound component. *)

  val events : t -> string list
  (** The operation names mentioned by a grade; empty for the time grades. *)

  val of_lit : lit -> t
  (** Converts a parsed grade literal to a value of type [t]. *)

  val of_bounds : int * int -> t
  (** [of_bounds (lo, hi)] is the "time shadow" of an operation declaring the
      runtime bounds [within (lo, hi)]: the grade that records nothing but the
      time such a call may take. It is the grade a default implementation of the
      operation is checked against, since the operation's own grade can only be
      realised by performing the operation itself. Each grade reads the end of
      the bounds its order uses, the two-sided ones both. *)

  val is_atomic : string -> t -> bool
  (** [is_atomic name rho] is whether [rho] is the grade of an atomic operation
      named [name], i.e. the single run consisting of [name] alone. The time
      grades name no operations and are all atomic. *)

  val show : t -> string
end

(** The literal forms the time grades do not understand. Their messages are
    surfaced to the user as located syntax errors naming the grade in use (see
    [Loader.parse_commands]). *)
let reject_trace_lit which =
  invalid_arg
    ("grades are " ^ which
   ^ ", not sets of timed traces; did you mean to use one of the \
      'traces-lower-bound', 'traces-upper-bound' or 'traces-interval' grading \
      monoids?")

let reject_pair_lit () =
  invalid_arg
    "grades are plain integers, not pairs; did you mean to use the \
     'time-interval' grading monoid?"

(** [nat_of_lit lit] is the non-negative integer the literal [lit] denotes. *)
let nat_of_lit = function
  | Int n ->
      if n < 0 then invalid_arg "grades must be non-negative integers" else n
  | Pair _ -> reject_pair_lit ()
  | Traces _ | TracePair _ -> reject_trace_lit "plain integers"

let check_nat who n =
  if n < 0 then invalid_arg (who ^ ".of_nat: expected non-negative integer")
  else n

(** Lower bounds on time (after [Time/LeftSided.agda]): [n] is "at least [n]
    time steps", ordered by [≥], so the unit [0] is the top. *)
module TimeLowerBoundGrade : S = struct
  type t = int

  let name = "time-lower-bound"
  let one = 0
  let mul = ( + )
  let leq _bounds = ( >= )
  let leq_symbol = ">="
  let top = 0
  let join = Int.min
  let equal _bounds = Int.equal
  let unit_least = false
  let commutative = true
  let needs_op_bounds = false
  let events _ = []
  let implied_bounds _bounds _ = None
  let of_lit = nat_of_lit
  let of_nat = check_nat "TimeLowerBoundGrade"
  let of_bounds (lo, _hi) = lo
  let is_atomic _name _ = true
  let show = string_of_int
end

(** Upper bounds on time (after [Time/RightSided.agda]): [n] is "at most [n]
    time steps", with [∞] imposing no bound, ordered by [≤]. *)
module TimeUpperBoundGrade : S = struct
  type t = ExtendedNat.t

  let name = "time-upper-bound"
  let one = ExtendedNat.Fin 0
  let mul = ExtendedNat.add
  let leq _bounds = ExtendedNat.leq
  let leq_symbol = "<="
  let top = ExtendedNat.Inf
  let join = ExtendedNat.max
  let equal _bounds = ( = )
  let unit_least = true
  let commutative = true
  let needs_op_bounds = false
  let events _ = []
  let implied_bounds _bounds _ = None
  let of_lit lit = ExtendedNat.Fin (nat_of_lit lit)
  let of_nat n = ExtendedNat.Fin (check_nat "TimeUpperBoundGrade" n)
  let of_bounds (_lo, hi) = ExtendedNat.Fin hi
  let is_atomic _name _ = true
  let show = ExtendedNat.show
end

(** Intervals of time (after the [two-sided-intervals-with-∞] grade of
    [Time/TwoSidedWithInfinity.agda]): [(n, m)] is "between [n] and [m] time
    steps", with [m = ∞] imposing no upper bound, ordered by containment. *)
module IntervalResourceGrade : S = struct
  type t = int * ExtendedNat.t

  let name = "time-interval"
  let one = (0, ExtendedNat.Fin 0)
  let mul (n, m) (k, l) = (n + k, ExtendedNat.add m l)
  let leq _bounds (n, m) (k, l) = k <= n && ExtendedNat.leq m l
  let leq_symbol = "<="
  let top = (0, ExtendedNat.Inf)
  let join (n, m) (k, l) = (Int.min n k, ExtendedNat.max m l)
  let equal _bounds = ( = )
  let unit_least = false
  let commutative = true
  let needs_op_bounds = false
  let events _ = []
  let implied_bounds _bounds _ = None

  let of_lit = function
    | Int _ ->
        invalid_arg
          "grades are intervals '(n, m)', not plain integers; did you mean to \
           use the 'time-lower-bound' or 'time-upper-bound' grading monoid?"
    | Pair (n, m) ->
        if n < 0 then invalid_arg "interval endpoints must be non-negative"
        else if n > m then invalid_arg "interval endpoints must satisfy n <= m"
        else (n, ExtendedNat.Fin m)
    | Traces _ | TracePair _ -> reject_trace_lit "intervals '(n, m)'"

  let of_nat n =
    let n = check_nat "IntervalResourceGrade" n in
    (n, ExtendedNat.Fin n)

  let of_bounds (lo, hi) = (lo, ExtendedNat.Fin hi)
  let is_atomic _name _ = true
  let show (n, m) = "(" ^ string_of_int n ^ "," ^ ExtendedNat.show m ^ ")"
end

(* The three grades below are graded by sets of timed traces (see
   {!TimedTrace}); their product is the language product.

   Cost model: an operation declares a pair of runtime bounds [within (lo, hi)],
   and the two orders read *different* endpoints — [lo] feeds the coverage
   (lower-bound) order, [hi] feeds the allowance (upper-bound) order. Reading
   a different endpoint in each order is sound because each order only ever
   needs its own direction of the bound. *)

let lo_cost (bounds : bounds) op = fst (bounds op)
let hi_cost (bounds : bounds) op = snd (bounds op)

let trace_of_lit_pair_msg =
  "grades are a single set of timed traces '{...}' or a plain integer; did you \
   mean to use the 'traces-interval' grading monoid?"

(** [traces_of_lit lit] is the set of timed traces the one-sided literal [lit]
    denotes. *)
let traces_of_lit = function
  | Int n ->
      if n < 0 then invalid_arg "grades must be non-negative integers"
      else TimedTrace.of_nat n
  | Traces ts -> TimedTrace.of_list ts
  | Pair _ | TracePair _ -> invalid_arg trace_of_lit_pair_msg

(** Sets of timed traces read as lower bounds, in the coverage order (after
    [Traces/Lifted/LeftSided.agda]). *)
module LowerTraces = struct
  type t = TimedTrace.traces

  let one = TimedTrace.of_nat 0

  (** Coverage order lifted to sets: every guarantee listed on the left has an
      easier one listed on the right. An operation's [lo] bound is what its
      occurrence in the run banks. *)
  let leq bounds = TimedTrace.lower_bound_le (lo_cost bounds)

  (** The unit [{ε}], covered by every run. *)
  let top = one

  let join = TimedTrace.union
end

(** Sets of timed traces read as upper bounds, in the allowance order, with a
    separate greatest point [Unbounded] (the [Bounds] of
    [Traces/Lifted/RightSided.agda]). *)
module UpperTraces = struct
  type t =
    | Within of TimedTrace.traces  (** every run stays within a listed bound *)
    | Unbounded  (** any run; printed as [⊤] *)

  let one = Within (TimedTrace.of_nat 0)

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

  let events = function Within p -> TimedTrace.events p | Unbounded -> []

  let max_duration bounds = function
    | Within p -> Some (TimedTrace.max_duration (hi_cost bounds) p)
    | Unbounded -> None

  let show = function Within p -> TimedTrace.show p | Unbounded -> "⊤"
end

(** The runtime bounds implied by a lower-bound component [lo] and an
    upper-bound component [hi]. *)
let implied_trace_bounds bounds lo hi =
  Option.map
    (fun slowest -> (TimedTrace.min_duration (lo_cost bounds) lo, slowest))
    (UpperTraces.max_duration bounds hi)

let atomic_traces name = [ [ TimedTrace.Ev name ] ]

module TimedTracesLowerBoundGrade : S = struct
  include LowerTraces

  let name = "traces-lower-bound"
  let mul = TimedTrace.product
  let leq_symbol = "<="
  let equal bounds p q = leq bounds p q && leq bounds q p
  let unit_least = false
  let commutative = false
  let needs_op_bounds = true
  let events = TimedTrace.events

  let implied_bounds bounds p =
    implied_trace_bounds bounds p (UpperTraces.Within p)

  let of_lit = traces_of_lit
  let of_nat n = TimedTrace.of_nat (check_nat "TimedTracesLowerBoundGrade" n)
  let of_bounds (lo, _hi) = TimedTrace.of_nat lo
  let is_atomic name p = p = atomic_traces name
  let show = TimedTrace.show
end

module TimedTracesUpperBoundGrade : S = struct
  include UpperTraces

  let name = "traces-upper-bound"
  let leq_symbol = "<="
  let top = Unbounded
  let equal bounds p q = leq bounds p q && leq bounds q p
  let unit_least = true
  let commutative = false
  let needs_op_bounds = true

  let implied_bounds bounds = function
    | Within p -> implied_trace_bounds bounds p (Within p)
    | Unbounded -> None

  let of_lit lit = Within (traces_of_lit lit)

  let of_nat n =
    Within (TimedTrace.of_nat (check_nat "TimedTracesUpperBoundGrade" n))

  let of_bounds (_lo, hi) = Within (TimedTrace.of_nat hi)
  let is_atomic name p = p = Within (atomic_traces name)
end

(** Pairs of a lower and an upper bound, each endpoint at its own order (after
    [Traces/Lifted/TwoSided.agda]). *)
module TimedTracesIntervalGrade : S = struct
  type t = LowerTraces.t * UpperTraces.t

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
  let unit_least = false
  let commutative = false
  let needs_op_bounds = true

  let events (lo, hi) =
    List.sort_uniq compare (TimedTrace.events lo @ UpperTraces.events hi)

  let implied_bounds bounds (lo, hi) = implied_trace_bounds bounds lo hi

  let of_lit lit =
    let lo, hi =
      match lit with
      | Int n ->
          if n < 0 then invalid_arg "grades must be non-negative integers"
          else (TimedTrace.of_nat n, TimedTrace.of_nat n)
      | Pair (n, m) ->
          if n < 0 then invalid_arg "interval endpoints must be non-negative"
          else if n > m then
            invalid_arg "interval endpoints must satisfy n <= m"
          else (TimedTrace.of_nat n, TimedTrace.of_nat m)
      | Traces ts ->
          let ts' = TimedTrace.of_list ts in
          (ts', ts')
      | TracePair (ts1, ts2) -> (TimedTrace.of_list ts1, TimedTrace.of_list ts2)
    in
    (lo, UpperTraces.Within hi)

  let of_nat n =
    let n = TimedTrace.of_nat (check_nat "TimedTracesIntervalGrade" n) in
    (n, UpperTraces.Within n)

  let of_bounds (lo, hi) =
    (TimedTrace.of_nat lo, UpperTraces.Within (TimedTrace.of_nat hi))

  let is_atomic name (lo, hi) =
    lo = atomic_traces name && hi = UpperTraces.Within (atomic_traces name)

  let show (lo, hi) = "(" ^ TimedTrace.show lo ^ "," ^ UpperTraces.show hi ^ ")"
end

(** All available grades, in order of definition. The names accepted by the
    CLI's [--grades] option and listed by the web interface's grade selector are
    taken from the [name] fields of these modules. *)
let grade_modules : (string * (module S)) list =
  [
    (TimeLowerBoundGrade.name, (module TimeLowerBoundGrade));
    (TimeUpperBoundGrade.name, (module TimeUpperBoundGrade));
    (IntervalResourceGrade.name, (module IntervalResourceGrade));
    (TimedTracesLowerBoundGrade.name, (module TimedTracesLowerBoundGrade));
    (TimedTracesUpperBoundGrade.name, (module TimedTracesUpperBoundGrade));
    (TimedTracesIntervalGrade.name, (module TimedTracesIntervalGrade));
  ]
