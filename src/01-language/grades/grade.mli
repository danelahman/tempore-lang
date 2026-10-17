(** Grades: partially ordered monoids with a greatest element and binary joins.

    The instances the prototype offers are defined in {!TimeGrades},
    {!RationalTimeGrades}, {!TraceInclusionGrades}, {!TimedTraceGrades},
    {!RegularTraceGrade}, {!RegularTraceGradeDerivative},
    {!RegularTraceGradePlain}, {!RegularTraceGradeRational},
    {!RegularTimedTraceGrades}, {!LevelGrades}, {!ResourceLevelGrades},
    {!WindowedScheduleGrades}, {!ModeSwitchCostGrades}, {!ModeTimeGrades},
    {!CountGrades} and {!EventSeparationGrades}, built with the constructions of
    {!GradeConstructions} and {!SummaryTerms}, and listed in {!GradeRegistry};
    the regular trace grades are implementations of the same grade.

    {2 Laws}

    Under all running times, an instance satisfies, [=] being {!S.equal}:
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

    {2 Running times}

    The orders of the trace grades of timed operations read the running-time
    bounds [within [lo, hi]] that operations declare, each end closed or open,
    and those of the regular trace grades of timed operations also the set of
    the operations the program declares, over which their catch-all letter
    ranges: all of them, before or after the grade, so that a grade means the
    same throughout a program. The operations that depend on the order, [leq],
    [equal], [counterexample], [duration_bounds] and [inhabited], take both as
    an argument of type {!bounds}; the other grades ignore it. Running-time
    bounds are kept as the non-negative rationals the source writes
    ({!type-running_time}), and each grade reads them as its delays
    ({!read_bound}).

    {2 Literals}

    All grade positions of the source share one literal syntax,
    {!GradeLiteral.lit}; each grade interprets the literals it understands with
    [of_lit] and rejects the others with {!Invalid_literal}. *)

include module type of struct
  include GradeLiteral
end

type running_time = Rational.t bound * Rational.t bound
(** The running-time bounds [(lo, hi)] of an operation: a non-empty interval of
    non-negative rationals with finite ends, each closed or open, independent of
    the grade. A closed end is attained by the durations of the operation, an
    open one is their strict infimum or supremum. *)

(** The durations of the computations of a grade, as a program reports them to a
    backend. *)
type durations =
  | Duration_interval of Rational.t bound * Rational.t bound
      (** the interval of the durations, each end attained or not, the upper end
          infinite where the grade bounds them only below ({!S.duration_bounds})
      *)
  | Undetermined
      (** the grade system bounds durations, but this grade determines no
          interval of them *)
  | Untimed  (** the grade system does not bound durations *)

val end_value : 'a bound -> 'a
(** [end_value b] is the value of the finite end [b] of an interval.

    Raises [Invalid_argument] if [b] is infinite. *)

val map_end : ('a -> 'b) -> 'a bound -> 'b bound
(** [map_end f b] is the end [b] with its value mapped by [f]. *)

val hull : 'a bound * 'a bound -> 'a * 'a
(** [hull (lo, hi)] is the pair of the values of the ends of the running-time
    bounds [(lo, hi)], the ends of their closure [[lo, hi]]. *)

val add_ends : Rational.t bound -> Rational.t bound -> Rational.t bound
(** [add_ends b b'] is the sum of the finite ends [b] and [b'], attained iff
    both are. *)

val compare_ends : lower:bool -> Rational.t bound -> Rational.t bound -> int
(** [compare_ends ~lower b b'] orders the finite ends [b] and [b'] of intervals
    by value, and at equal values by the sets they bound: a closed lower end
    before an open one, and an open upper end before a closed one. *)

val close_running_time :
  (lower:bool -> 'a -> 'a option) -> 'a bound * 'a bound -> 'a bound * 'a bound
(** [close_running_time adjacent (lo, hi)] is the running-time bounds [(lo, hi)]
    with each open end [q] replaced by the closed end [adjacent ~lower q],
    [lower] being whether it is the lower end, where there is one: over whole
    time steps, [(1, 4)] is [[2, 3]]. *)

val intersect_durations :
  (Rational.t bound * Rational.t bound) option ->
  (Rational.t bound * Rational.t bound) option ->
  (Rational.t bound * Rational.t bound) option
(** [intersect_durations b b'] is the intersection of the intervals of durations
    [b] and [b'], either possibly absent: the greater of the lower ends, which
    are finite, and the lesser of the upper ends, an infinite end being the
    greatest. *)

type bounds = {
  running_time : string -> running_time;
      (** The running-time bounds declared by each operation, or implied by its
          grade, by name. The delays of the grade read each of them. *)
  operations : string list;
      (** The names of the operations the program declares with running-time
          bounds. *)
}
(** The running times of the operations of a program. *)

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
  (** [leq bounds c d] decides the partial order [c ≾ d] under the running times
      [bounds]. *)

  val leq_symbol : string
  (** The notation for {!leq} in printed inequalities. *)

  val top : t
  (** The greatest grade [⊤]. *)

  val join : t -> t -> t
  (** The binary join [_⊔_]. *)

  val plus : t -> t option
  (** [plus c] is the closure [c⁺] of [c], where the grade declares one: the
      least grade [w] with [c ≾ w] and [w · w ≾ w]. It also satisfies, for every
      [d], [c · d ≾ d ⇒ c⁺ · d ≾ d] and [d · c ≾ d ⇒ d · c⁺ ≾ d], as it does
      where the grade is residuated. Both laws hold under all running times. It
      is [None] where the grade declares no closure. *)

  module Delay : Delay.S
  (** The delays. *)

  val of_delay : Delay.t -> t
  (** [of_delay d] is the grade of the computation [delay d]. *)

  val equal : bounds -> t -> t -> bool
  (** [equal bounds c d] decides [c = d] under the running times [bounds]. *)

  val is_top : bounds -> t -> bool
  (** [is_top bounds c] decides [⊤ ≾ c], equivalently [equal bounds c top],
      under the running times [bounds]: from the representation of [c] where
      that decides it, and otherwise by the order once the representation is
      found not to be that of the top. *)

  val compare : t -> t -> int
  (** A total order on the representations of the grades: [compare c d = 0]
      implies [equal bounds c d] under all running times [bounds], and the
      converse holds where the representation is canonical. *)

  val hash : t -> int
  (** A hash of the representation of a grade, compatible with {!compare}. *)

  val counterexample : bounds -> t -> t -> t option
  (** [counterexample bounds c d] is [None] if [c ≾ d] under the running times
      [bounds], and otherwise either a grade [e] such that [e ≾ c] but not
      [e ≾ d], a witness of the failure, or [None] for grades that offer no
      witness. *)

  val unit_least : bool
  (** Whether {!one} is the least grade. *)

  val commutative : bool
  (** Whether {!mul} is commutative. *)

  val needs_op_bounds : bool
  (** Whether operation signatures must carry their running-time bounds
      [within [lo, hi]]. *)

  val duration_bounds :
    bounds -> t -> (Rational.t bound * Rational.t bound) option
  (** [duration_bounds bounds rho] is the interval of the durations of the
      computations of grade [rho], each end attained or not, where [rho]
      determines one. For the time grades it is the interval [rho] denotes, its
      upper end infinite where [rho] imposes no upper bound. For the trace
      grades of timed operations it is the infimum of the durations of the
      traces of [rho], each event counted at the lower end of its [bounds], and
      their supremum, each event counted at the upper end: the fastest trace is
      taken over the lower-bound component of the grade and the slowest over its
      upper-bound component, which coincide for the one-sided grades; the upper
      end is infinite where the durations of the upper-bound component are
      unbounded, and the interval is [None] where either component denotes no
      trace. For a product it is the intersection of those of its components
      ({!intersect_durations}). It is [None] for the grades that do not bound
      durations. *)

  val inhabited : bounds -> t -> bool
  (** [inhabited bounds rho] is whether the grade [rho] denotes at least one
      trace of the operations of [bounds]; the typechecker rejects the grades of
      a program that do not. It holds of every grade whose meaning does not
      depend on the declared operations. *)

  val events : t -> string list
  (** The operation names mentioned by a grade; empty for the time grades. *)

  val of_lit : lit -> t
  (** [of_lit lit] is the grade the literal [lit] denotes.

      Raises [Invalid_literal] if the grade does not understand [lit]. *)

  val accepts : lit -> bool
  (** [accepts lit] is whether {!of_lit} reads [lit] without rejecting it,
      [reads_lit of_lit lit], decided without building the grade where that is
      costly. *)

  val of_bounds : Delay.t bound * Delay.t bound -> t
  (** [of_bounds (lo, hi)] is the "time shadow" of an operation declaring the
      running-time bounds [(lo, hi)], read as delays: the grade that records
      nothing but the time such a call may take. It is the grade a default
      implementation of the operation is checked against, since the operation's
      own grade can only be realised by performing the operation itself. Each
      grade reads the end of the bounds its order uses, the two-sided ones both;
      a grade that expresses no strict ends reads the closed hull ([hull]). *)

  val is_atomic : string -> t -> bool
  (** [is_atomic name rho] is whether [rho] is the grade of an atomic operation
      named [name], i.e. the single trace consisting of [name] alone. The time
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
      {!val-top} and, where the delays read the literal [1], its grade to the
      list. *)
end

val read_bound : (lit -> 'a option) -> Rational.t -> 'a
(** [read_bound read q] is the delay [read] reads the running-time bound [q] as.

    Raises [Invalid_argument] if [read] reads none: the running-time bounds of a
    program are checked to be delays of its grades where they are declared. *)

val fractional_tick : Rational.t -> 'a
(** [fractional_tick q] rejects the delay [q] of a brace literal, a fraction, in
    the grades whose delays are whole numbers of time steps ({!Delay.Nat}).

    @raise Invalid_literal
      on the literal [Rat q], which the grade reports against the brace literal
      with {!component_of_lit}. *)

val tick_interval : Rational.t bound -> Rational.t bound -> int * int option
(** [tick_interval lo hi] is the pair [(a, b)] of the least and the greatest
    whole number of time steps of the interval atom from [lo] to [hi] of a brace
    literal, [b] being [None] for an infinite upper endpoint: an open endpoint
    is shifted by one tick.

    @raise Invalid_literal
      on a fractional endpoint, by {!fractional_tick}, and on the brace literal
      of the atom alone if it contains no whole number of time steps, which the
      grade reports against the enclosing literal with {!component_of_lit}. *)

val tick_delays : Rational.t bound -> Rational.t bound -> regex
(** [tick_delays lo hi] is the expression over whole time steps of the interval
    atom from [lo] to [hi] of a brace literal, of the ends {!tick_interval}
    [lo hi]: [[a, b]] is [a] ticks followed by up to [b - a] more, and [\[a, ∞)]
    is [a] ticks followed by any number. The expression is of size proportional
    to [b - a], and the grades that read interval atoms through it build them in
    time quadratic in [b - a] ({!RegularTraceGrade}).

    @raise Invalid_literal as {!tick_interval}. *)

val check_delays : lit -> regex -> unit
(** [check_delays lit r] rejects the brace literal [lit] with the expression [r]
    if [r] holds a negative delay: a negative number, or an interval atom whose
    lower endpoint is negative or infinite.

    @raise Invalid_literal on [lit] if it does. *)

val whole_braces : names:bool -> regex -> bool
(** [whole_braces ~names r] is whether a grade over whole time steps reads the
    delays of the brace literal [{r}]: they are non-negative, no delay is a
    fraction, each interval atom contains a whole number of time steps
    ({!tick_interval}), and, unless [names], [r] names no operation. It builds
    no expression of the ticks of an interval atom. *)

val positive : regex -> bool
(** [positive r] is whether [r] holds no intersection and no complement. Such an
    expression whose atoms are read ({!whole_braces}) denotes a non-empty
    language. *)

val sampled : ('a -> 'a -> 'a) -> 'a list -> 'a list * completeness
(** [sampled mul cs] is the [Partial] list of the constants [cs] and their
    pairwise products by [mul]. *)

val compare_array : ('a -> 'a -> int) -> 'a array -> 'a array -> int
(** [compare_array compare a b] orders arrays by length, then lexicographically
    by [compare]. *)
