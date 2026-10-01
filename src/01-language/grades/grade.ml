(** Grades: partially ordered monoids with a greatest element and binary joins.

    The instances the prototype offers are defined in {!TimeGrades},
    {!RationalTimeGrades}, {!TraceInclusionGrades}, {!TimedTraceGrades},
    {!RegularTraceGrade}, {!RegularTraceGradeDerivative},
    {!RegularTraceGradePlain}, {!RegularTraceGradeRational},
    {!RegularCostTraceGrades}, {!LevelGrades}, {!ResourceLevelGrades},
    {!WindowedScheduleGrades}, {!ModeSwitchCostGrades} and {!CountGrades}, built
    with the constructions of {!GradeConstructions}, and listed in
    {!GradeRegistry}; the regular trace grades are implementations of the same
    grade.

    {2 Laws}

    Under every cost model, an instance satisfies, [=] being {!S.equal}:
    - [mul] is associative, with unit [one];
    - [leq] is a preorder, whose equivalence is [equal];
    - [mul] is monotone in both arguments;
    - the unit has the zero-product property: [c · d ≾ one] implies [c ≾ one]
      and [d ≾ one];
    - [join] is a least upper bound and [top] a greatest element;
    - [mul] distributes over [join] on both sides: [c · (d ⊔ e) = c · d ⊔ c · e]
      and [(d ⊔ e) · c = d · c ⊔ e · c];
    - [of_delay] is a monoid morphism from the delays: [of_delay zero = one] and
      [of_delay (add d e) = of_delay d · of_delay e]. It need not be monotone:
      the time upper bounds are monotone in the delay, the lower bounds
      antitone, and the intervals neither.

    {2 Cost model}

    The orders of the trace grades of timed operations read the runtime bounds
    [within [lo, hi]] that operations declare, each end closed or open, and
    those of the regular trace grades of timed operations also the set of the
    operations the program declares, over which their catch-all letter ranges:
    all of them, before or after the grade, so that a grade means the same
    throughout a program. The operations that depend on the order, [leq],
    [equal], [counterexample], [implied_bounds] and [inhabited], take both as an
    argument of type {!bounds}; the other grades ignore it. Runtime bounds are
    kept as the non-negative rationals the source writes ({!runtime}), and each
    grade reads them as its delays ({!read_bound}).

    {2 Literals}

    All grade positions of the source share one literal syntax,
    {!GradeLiteral.lit}; each grade interprets the literals it understands with
    [of_lit] and rejects the others with {!Invalid_literal}. *)

include GradeLiteral

type runtime = Rational.t bound * Rational.t bound
(** The runtime bounds [(lo, hi)] of an operation: a non-empty interval of
    non-negative rationals with finite ends, each closed or open, independent of
    the grade. A closed end is attained by the durations of the operation, an
    open one is their strict infimum or supremum. *)

(** [end_value b] is the value of the finite end [b] of an interval.

    @raise Invalid_argument if [b] is infinite. *)
let end_value = function
  | Closed q | Open q -> q
  | Unbounded -> invalid_arg "Grade.end_value: an infinite end"

(** [map_end f b] is the end [b] with its value mapped by [f]. *)
let map_end f = function
  | Closed q -> Closed (f q)
  | Open q -> Open (f q)
  | Unbounded -> Unbounded

(** [hull (lo, hi)] is the pair of the values of the ends of the runtime bounds
    [(lo, hi)], the ends of their closure [[lo, hi]]. *)
let hull (lo, hi) = (end_value lo, end_value hi)

(** [add_ends b b'] is the sum of the finite ends [b] and [b'], attained iff
    both are. *)
let add_ends b b' =
  match (b, b') with
  | Closed a, Closed a' -> Closed (Rational.add a a')
  | (Closed a | Open a), (Closed a' | Open a') -> Open (Rational.add a a')
  | Unbounded, _ | _, Unbounded -> Unbounded

(** [compare_ends ~lower b b'] orders the finite ends [b] and [b'] of intervals
    by value, and at equal values by the sets they bound: a closed lower end
    before an open one, and an open upper end before a closed one. *)
let compare_ends ~lower b b' =
  let rank = function
    | Closed _ -> Bool.to_int (not lower)
    | _ -> Bool.to_int lower
  in
  match Rational.compare (end_value b) (end_value b') with
  | 0 -> Int.compare (rank b) (rank b')
  | c -> c

(** [close_runtime adjacent (lo, hi)] is the runtime bounds [(lo, hi)] with each
    open end [q] replaced by the closed end [adjacent ~lower q], [lower] being
    whether it is the lower end, where there is one: over whole time steps,
    [(1, 4)] is [[2, 3]]. *)
let close_runtime adjacent (lo, hi) =
  let close ~lower = function
    | Open q -> (
        match adjacent ~lower q with Some q' -> Closed q' | None -> Open q)
    | b -> b
  in
  (close ~lower:true lo, close ~lower:false hi)

type bounds = {
  cost : string -> runtime;
      (** The runtime bounds declared by each operation, or implied by its
          grade, by name. The delays of the grade read each of them. *)
  operations : string list;
      (** The names of the operations the program declares with runtime bounds.
      *)
}
(** A cost model. *)

(** Whether a list of witnesses decides the conditions it is given for
    ({!S.witnesses}). *)
type completeness = Delay.completeness =
  | Complete
      (** a condition in one rigid that holds at every witness holds at every
          grade *)
  | Partial  (** a condition may hold at every witness and fail elsewhere *)

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

  module Delay : Delay.S
  (** The delays. *)

  val of_delay : Delay.t -> t
  (** [of_delay d] is the grade of the computation [delay d]. *)

  val equal : bounds -> t -> t -> bool
  (** [equal bounds c d] decides [c = d] under the cost model [bounds]. *)

  val is_top : bounds -> t -> bool
  (** [is_top bounds c] decides [⊤ ≾ c], equivalently [equal bounds c top],
      under the cost model [bounds]: from the representation of [c] where that
      decides it, and otherwise by the order once the representation is found
      not to be that of the top. *)

  val compare : t -> t -> int
  (** A total order on the representations of the grades: [compare c d = 0]
      implies [equal bounds c d] under every cost model [bounds], and the
      converse holds where the representation is canonical. *)

  val hash : t -> int
  (** A hash of the representation of a grade, compatible with {!compare}. *)

  val counterexample : bounds -> t -> t -> t option
  (** [counterexample bounds c d] is [None] if [c ≾ d] under the cost model
      [bounds], and otherwise either a grade [e] such that [e ≾ c] but not
      [e ≾ d], a witness of the failure, or [None] for grades that offer no
      witness. *)

  val unit_least : bool
  (** Whether {!one} is the least grade. *)

  val commutative : bool
  (** Whether {!mul} is commutative. *)

  val needs_op_bounds : bool
  (** Whether operation signatures must carry their runtime bounds
      [within [lo, hi]]. *)

  val implied_bounds : bounds -> t -> runtime option
  (** [implied_bounds bounds rho] is the pair of runtime bounds the grade [rho]
      itself implies: the infimum of the durations of its runs, each event
      counted at the lower end of its [bounds], and their supremum, each event
      counted at the upper end, each attained or not. The fastest run is taken
      over the lower-bound component of the grade and the slowest over its
      upper-bound component, which coincide for the one-sided trace grades with
      costs. The time grades imply nothing, since there the grade of an
      operation already is its runtime bound, and return [None]; so does an
      unbounded upper-bound component. *)

  val inhabited : bounds -> t -> bool
  (** [inhabited bounds rho] is whether the grade [rho] denotes at least one run
      of the operations of the cost model [bounds]; the typechecker rejects the
      grades of a program that do not. It holds of every grade whose meaning
      does not depend on the declared operations. *)

  val events : t -> string list
  (** The operation names mentioned by a grade; empty for the time grades. *)

  val of_lit : lit -> t
  (** [of_lit lit] is the grade the literal [lit] denotes.

      @raise Invalid_literal if the grade does not understand [lit]. *)

  val of_bounds : Delay.t bound * Delay.t bound -> t
  (** [of_bounds (lo, hi)] is the "time shadow" of an operation declaring the
      runtime bounds [(lo, hi)], read as delays: the grade that records nothing
      but the time such a call may take. It is the grade a default
      implementation of the operation is checked against, since the operation's
      own grade can only be realised by performing the operation itself. Each
      grade reads the end of the bounds its order uses, the two-sided ones both;
      a grade that expresses no strict ends reads the closed hull ({!hull}). *)

  val is_atomic : string -> t -> bool
  (** [is_atomic name rho] is whether [rho] is the grade of an atomic operation
      named [name], i.e. the single run consisting of [name] alone. The time
      grades name no operations and are all atomic. *)

  val show : t -> string
  (** [show rho] prints [rho] in the literal syntax, the greatest grade as [⊤]
      and infinity as [∞] where they have no other literal. *)

  val witnesses : degree:int -> bounds -> t list -> t list * completeness
  (** [witnesses ~degree bounds cs] is a finite list of grades at which a closed
      condition [∀j. O] whose constants are [cs] is evaluated, the rigid [j]
      ranging over the list, and its completeness: [Complete] when [O] holding
      at every witness implies [∀j. O]. A condition is an ordering between
      expressions built from the constants, [j], products and joins, [j]
      occurring at most [degree] times on either side. The solver adds {!one},
      {!top} and, where the delays read the literal [1], its grade to the list.
  *)
end

(** [read_bound read q] is the delay [read] reads the runtime bound [q] as.

    @raise Invalid_argument
      if [read] reads none: the runtime bounds of a program are checked to be
      delays of its grades where they are declared. *)
let read_bound read q =
  match read (rational_lit q) with
  | Some d -> d
  | None -> invalid_arg ("Grade.read_bound: " ^ Rational.show q)

(** [fractional_tick q] rejects the delay [q] of a brace literal, a fraction, in
    the grades whose delays are whole numbers of time steps ({!Delay.Nat}).

    @raise Invalid_literal
      on the literal [Rat q], which the grade reports against the brace literal
      with {!component_of_lit}. *)
let fractional_tick q = invalid_lit (Rat q) "%s" (Delay.Nat.rejection (Rat q))

(** [tick_delays lo hi] is the expression over whole time steps of the interval
    atom from [lo] to [hi] of a brace literal: [[a, b]] is [a] ticks followed by
    up to [b - a] more, [\[a, ∞)] is [a] ticks followed by any number, and an
    open endpoint is shifted by one tick.

    @raise Invalid_literal
      on a fractional endpoint, by {!fractional_tick}, and on the brace literal
      of the atom alone if it contains no whole number of time steps, which the
      grade reports against the enclosing literal with {!component_of_lit}. *)
let tick_delays lo hi =
  let whole q =
    match Rational.to_int q with Some n -> n | None -> fractional_tick q
  in
  let a =
    match lo with Closed a -> whole a | Open a -> whole a + 1 | Unbounded -> 0
  in
  let b =
    match hi with
    | Closed b -> Some (whole b)
    | Open b -> Some (whole b - 1)
    | Unbounded -> None
  in
  match b with
  | None -> Seq (Tick a, Star (Tick 1))
  | Some b when b < a ->
      invalid_lit
        (Braces (Delays (lo, hi)))
        "the interval '%s' contains no whole number of time steps"
        (show_interval Rational.show lo hi)
  | Some b ->
      List.fold_left
        (fun r _ -> Seq (r, Union (Tick 0, Tick 1)))
        (Tick a)
        (List.init (b - a) Fun.id)

(** [sampled mul cs] is the [Partial] list of the constants [cs] and their
    pairwise products by [mul]. *)
let sampled mul cs =
  (cs @ List.concat_map (fun c -> List.map (mul c) cs) cs, Partial)

(** [compare_array compare a b] orders arrays by length, then lexicographically
    by [compare]. *)
let compare_array compare a b =
  let n = Array.length a in
  let rec from i =
    if i = n then 0
    else match compare a.(i) b.(i) with 0 -> from (i + 1) | c -> c
  in
  match Int.compare n (Array.length b) with 0 -> from 0 | c -> c

(** [combine h h'] is a hash of a pair whose components hash to [h] and [h']. *)
let combine h h' = (h * 65599) + h'

(** [hash_list hash xs] is a hash of the list [xs] whose elements hash by
    [hash]. *)
let hash_list hash xs = List.fold_left (fun h x -> combine h (hash x)) 0 xs
