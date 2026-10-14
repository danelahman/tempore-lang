(** Terms evaluated to summaries under the running-time bounds.

    The grades whose meaning depends on the running times of the operations, but
    whose product does not receive them, keep a grade as a term: the occurrences
    of operations, delays, fixed summaries (the specifications of the literals),
    products, joins and the top. A term is evaluated, under the running-time
    bounds that the order receives ({!Grade.bounds}), into an algebra of
    summaries ({!SUMMARY}): an occurrence by the summary of the operation at its
    running times, and products and joins by those of the summaries. The order,
    the equality, the top, the durations, the inhabitation and the
    counterexamples are those of the evaluations.

    Evaluation is a monoid morphism into the summaries that preserves joins and
    the top, so that the laws of {!Grade} hold of the terms up to {!Make.equal}
    whenever they hold of the summaries.

    {2 Representation}

    A term is kept in a canonical form: products and joins are flattened, the
    unit [[0, 0]] is dropped from products, adjacent delays are summed, and the
    operands of a join are sorted and duplicate-free, a join with the top being
    the top. {!Make.compare} and {!Make.hash} are those of the canonical forms.

    {2 Evaluation}

    The evaluations of the terms and their subterms are recorded, in a table
    ({!Memo.Make}) for the running-time bounds of the latest evaluation, told by
    physical equality: a table is replaced, and released, when terms are
    evaluated under other running-time bounds. *)

(** Algebras of summaries: monoids with joins and a greatest element, ordered,
    that receive delays and the occurrences of operations.

    Laws, [=] being mutual [leq]:
    - [mul] is associative with unit [one], and monotone in both arguments;
    - [leq] is a preorder, [join] a least upper bound and [top] greatest;
    - [delays] is a monoid morphism from the intervals of durations under the
      Minkowski sum: [delays DurationIntervals.zero = one] and
      [delays (DurationIntervals.add i j) = mul (delays i) (delays j)];
    - [compare s s' = 0] implies [s = s'], and [hash] is compatible with
      [compare]. *)
module type SUMMARY = sig
  type t
  (** The summaries. *)

  type op
  (** The behaviour of an operation that its grade states besides its name, e.g.
      the modes it changes between; [unit] where there is none. *)

  val one : t
  (** The summary of the computations that take no time and perform nothing. *)

  val mul : t -> t -> t
  (** The summary of sequencing. *)

  val join : t -> t -> t
  (** The binary join. *)

  val top : t
  (** The greatest summary. *)

  val delays : DurationIntervals.t -> t
  (** [delays i] is the summary of the computations that perform no operation
      and take a duration in [i]. *)

  val occurrence : string -> op -> Grade.running_time -> t
  (** [occurrence name op running_time] is the summary of one call of the
      operation [name], of behaviour [op], taking a time within [running_time].
  *)

  val leq : t -> t -> bool
  (** The order. *)

  val compare : t -> t -> int
  (** A total order on the representations of the summaries. *)

  val hash : t -> int
  (** A hash compatible with {!compare}. *)

  val compare_op : op -> op -> int
  (** A total order on the behaviours of operations. *)

  val hash_op : op -> int
  (** A hash compatible with {!compare_op}. *)

  val duration : t -> DurationIntervals.t option
  (** [duration s] is the interval of the durations of the computations of [s],
      where [s] determines one. *)

  val inhabited : t -> bool
  (** [inhabited s] is whether [s] summarises some computation. *)

  val events : t -> string list
  (** [events s] is the operation names [s] mentions, in increasing order. *)

  val counterexample : t -> t -> t option
  (** [counterexample s s'], for [s] not below [s'], is a summary below [s] and
      not below [s'] that witnesses the failure, if one is offered; [s] itself
      is one. *)
end

(** The terms over the summaries [S]. *)
module Make (S : SUMMARY) : sig
  type t
  (** The terms, in canonical form. *)

  (** The outermost constructor of a term. *)
  type node =
    | Op of string * S.op  (** The occurrence of an operation *)
    | Delays of DurationIntervals.t
        (** A computation without occurrences, of a duration in the interval;
            [[0, 0]] is the unit *)
    | Fixed of S.t
        (** A summary independent of the running times, e.g. a specification *)
    | Mul of t list  (** A product of at least two factors *)
    | Join of t list  (** A join of at least two operands *)

  val view : t -> node
  (** [view c] is the outermost constructor of [c]. *)

  val op : string -> S.op -> t
  (** [op name op] is the occurrence of the operation [name]. *)

  val delays : DurationIntervals.t -> t
  (** [delays i] is a computation without occurrences, of a duration in [i]. *)

  val fixed : S.t -> t
  (** [fixed s] is the summary [s]. *)

  val one : t
  (** The unit, [delays DurationIntervals.zero]. *)

  val top : t
  (** The greatest term, [fixed S.top]. *)

  val mul : t -> t -> t
  (** The product, in canonical form. *)

  val join : t -> t -> t
  (** The join, in canonical form. *)

  val of_delay : Rational.t -> t
  (** [of_delay q] is [delays (DurationIntervals.point q)]. *)

  val of_bounds : Grade.running_time -> t
  (** [of_bounds b] is [delays b]: the time a call may take, nothing performed.
  *)

  val evaluate : Grade.bounds -> t -> S.t
  (** [evaluate bounds c] is the summary of [c] under the running times
      [bounds]. *)

  val leq : Grade.bounds -> t -> t -> bool
  (** The order of the evaluations. *)

  val equal : Grade.bounds -> t -> t -> bool
  (** Mutual {!leq}. *)

  val is_top : Grade.bounds -> t -> bool
  (** [is_top bounds c] is whether [c] is the top, decided from its canonical
      form where it is [top] and otherwise from its evaluation. *)

  val compare : t -> t -> int
  (** A total order on the canonical forms. *)

  val hash : t -> int
  (** A hash compatible with {!compare}. *)

  val counterexample : Grade.bounds -> t -> t -> t option
  (** [counterexample bounds c d] is [None] if [c] is below [d], and otherwise
      the fixed summary {!SUMMARY.counterexample} offers below the evaluation of
      [c], if any. *)

  val duration_bounds : Grade.bounds -> t -> DurationIntervals.t option
  (** The {!SUMMARY.duration} of the evaluation. *)

  val inhabited : Grade.bounds -> t -> bool
  (** The {!SUMMARY.inhabited} of the evaluation. *)

  val events : t -> string list
  (** The names of the operations occurring in a term and those its fixed
      summaries mention, in increasing order. *)

  val is_atomic : string -> t -> bool
  (** [is_atomic name c] is whether [c] is the occurrence of [name] alone. *)
end
