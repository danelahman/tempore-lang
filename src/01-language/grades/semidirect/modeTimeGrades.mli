(** The mode-time grades: the time a computation spends in each mode of a device
    or a material, such as a reagent in or out of a cold block, between a start
    and an end mode.

    {2 Semantics}

    As in {!ModeSwitchCostGrades}, a grade gives each pair of a start and an end
    mode the traces between them, besides the ordinary modes there being the
    absorbing mode [Stuck], in which a trace is stuck. Here each trace is
    summarised by the time it spends in each mode and its total time, and an
    entry of a grade is either no trace, or an interval of the time in each mode
    and an interval of the total time, a box containing the summaries of its
    traces. A grade names finitely many modes and treats all the others alike;
    an entry bounds each mode named on its own, and every mode not named by one
    interval, the mode a trace starts or ends in when it is not named being
    bounded on its own.

    A delay keeps the mode, and its time is spent in it. An operation takes its
    running time, read from its running-time bounds [within [lo, hi]], in the
    mode it starts from, and its change of mode takes effect at its end. An
    operation performed from a mode its grade does not start from gets stuck at
    the start, at no time, and no time is spent in [Stuck]: an entry into
    [Stuck] bounds the time up to the point the trace gets stuck.

    Sequencing is the matrix product ({!ModeMatrices}) over the semiring of the
    boxes, whose sum is the hull and whose product the componentwise sum of
    intervals, which distributes over hulls. The join and the order are taken
    entrywise, the order being the inclusion of boxes, no trace least.

    {2 Laws}

    The grades are total, having a trace from every mode; their only trace from
    [Stuck] is to [Stuck], at no time; and a change between two distinct modes
    other than [Stuck] has a positive upper end of its total time, where every
    running-time bound has a positive upper end, as the typechecker requires.
    These properties are closed under the product and the join, and they give
    the zero-product law: if [x · y ≾ 1], then [x] changes no mode, gets stuck
    from none and spends no time, hence [x ≾ 1] and [y ≾ 1]. The laws hold up to
    equality under the running times, the product and the join being formal
    ({!section-representation}).

    {2:representation Representation}

    The product does not receive the running times, so a grade is kept as a term
    of delays, operations, specifications, products and joins, and evaluated to
    its matrix ({!Summary}) by the order, the equality and the durations, which
    receive them. The evaluations are memoised by the term and the running times
    of the operations it names. An operation's running time is the closed hull
    of its running-time bounds, an open end being read as its value.

    {2 Literals}

    - An operation names itself: [{Take}] is performed in every mode and keeps
      it, [({Take}, Cold, Out)] is performed only in [Cold] and changes the mode
      to [Out], and [({Mix}, (Cold, Cold), (Out, Out))] is performed in [Cold]
      or [Out] and keeps the mode. The modes are written as in
      {!ModeSwitchCostGrades}: [(p, _)] from [p] to a mode not named, [(_, q)]
      from a mode not named to [q], [(_, _)] keeping a mode not named, [(_, ≠)]
      from a mode not named to another and [(p, Stuck)] or [(_, Stuck)] into
      [Stuck]; [({X}, Stuck, Stuck)] is stuck from every mode.
    - A number [d] is a delay of [d], and an interval [[lo, hi]] or [\[lo, ∞)] a
      computation taking a time in it, keeping the mode.
    - A specification [(From, To, (M, [lo, hi]), ..., [lo, hi])] gives the
      traces from [From] to [To], bounding the time in each listed mode [M] and,
      by a bare interval, the total time; a mode not listed and the total
      without an interval are unconstrained, and an entry [(_, [lo, hi])] bounds
      the time in each mode not named by the grade. A mode named only in the
      bounds is named by the grade, and the entries from [_] do not cover it. A
      tuple of such entries, each pair of modes listed once, gives their traces;
      a mode from which no entry starts is stuck at no time. For example,
      [(Cold, Cold, (Out, [0, 30]))] permits the traces from [Cold] back to
      [Cold] that spend at most 30 time units out of the cold block, and gets
      stuck at no time from every other mode.
    - [⊤] is the greatest grade.

    A number in a bound abbreviates the interval [[d, d]]. The intervals are
    closed and their ends non-negative; no time is bounded in [Stuck], no trace
    leaves [Stuck] but [(Stuck, Stuck)], a change of mode takes a positive time,
    and the time in a mode is not bounded below beyond the total time. An upper
    end of the time in a mode beyond that of the total time is lowered to it.

    {2 Relation to the mode-switch costs}

    The grades are those of {!ModeSwitchCostGrades} with the costs replaced by
    the times in the modes, over the same matrices; delays cost nothing there,
    and are counted here. *)

type interval = {
  lo : Rational.t;  (** the lower end, attained *)
  hi : Rational.t option;  (** the upper end, attained, or [None] if infinite *)
}
(** A closed interval of non-negative times. *)

(** The matrices of the boxes between the modes, the values of the grades under
    the running times. *)
module Summary : sig
  type t
  (** A matrix. *)

  type op = (string * string) list
  (** The behaviour of an operation: the pairs of modes it takes, written as in
      the literals, sorted. *)

  val one : t
  (** The unit: keeping every mode at no time. *)

  val top : t
  (** The greatest matrix: every pair of modes at any times. *)

  val mul : t -> t -> t
  (** The matrix product. *)

  val join : t -> t -> t
  (** The entrywise hull. *)

  val leq : t -> t -> bool
  (** The entrywise inclusion. *)

  val equal : t -> t -> bool
  (** The equivalence of {!leq}. *)

  val compare : t -> t -> int
  (** A total order on the representations, which are canonical. *)

  val hash : t -> int
  (** A hash compatible with {!compare}. *)

  val compare_op : op -> op -> int
  (** A total order on the behaviours. *)

  val hash_op : op -> int
  (** A hash compatible with {!compare_op}. *)

  val delays : interval -> t
  (** [delays i] keeps every mode, spending a time in [i] in it. *)

  val occurrence : string -> op -> Grade.running_time -> t
  (** [occurrence name op bounds] is a call of the operation [name] of the
      behaviour [op], with a running time in the closed hull of [bounds] spent
      in the mode it starts from; it gets stuck at no time from a mode [op] does
      not start from. *)

  val times : t -> string -> string -> ((string -> interval) * interval) option
  (** [times m p q] is the entry of [m] from the mode [p] to the mode [q]: the
      interval of the time in each mode and the interval of the total time, or
      [None] if it has no trace. *)

  val duration : t -> interval option
  (** [duration m] is the hull of the total times of the entries of [m] other
      than those into [Stuck], from every mode, or [None] if there are none. *)

  val inhabited : t -> bool
  (** Every matrix has a trace from every mode. *)

  val events : t -> string list
  (** A matrix names no operation. *)

  val counterexample : t -> t -> t option
  (** No counterexample is offered. *)
end

module ModeTimes : Grade.S with type Delay.t = Delay.Rational.t
(** The mode-time grade, ["mode-times"], over {!Delay.Rational}.

    - The unit keeps every mode at no time, and the top permits any times
      between any two modes and into [Stuck]. The unit is not least, and [mul]
      does not commute.
    - [of_delay d] is the delay [d], and [of_bounds (lo, hi)] the computation
      taking a time in the closed hull [[lo, hi]], keeping the mode.
    - [of_lit] reads the literals above. [show] prints alike, a product as
      [x · y] and a join as [x ⊔ y], which do not read back; every printed
      operation, delay and specification reads back as itself. A specification
      is printed with the entry [(From, Stuck)] at no time of a mode from which
      it is the only trace left implicit, where another entry names the mode, a
      bound equal to the total omitted, and the grade stuck at no time from
      every mode as [(Stuck, Stuck)].
    - [duration_bounds] is {!Summary.duration} of the evaluated grade: the
      traces that get stuck are not executions of the computation.
    - [events] is the operations a grade names, and [is_atomic name x] holds of
      the operations named [name]. [inhabited] holds of every grade, a grade
      having a trace from every mode.
    - No counterexample is offered, and the witnesses are the constants and
      their pairwise products, and partial. *)

val evaluate : Grade.bounds -> ModeTimes.t -> Summary.t
(** [evaluate bounds x] is the matrix of the grade [x] under the running times
    [bounds]. *)
