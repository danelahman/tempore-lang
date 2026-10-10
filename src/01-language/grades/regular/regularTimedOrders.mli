(** The three regular trace grades of timed operations over a regular trace
    grade, lower bounds, upper bounds and intervals, given the decisions of the
    orders on traces over the worlds of comparisons. They are shared by
    {!RegularTimedTraceGrades}, over whole time steps, and
    {!RegularTimedTraceGradesRational}, over rational delays, which differ in
    their worlds, decisions, time shadows and literals of intervals.

    [ρ ≾ ρ'] holds if [ρ] and [ρ'] are equal under the underlying grade or [ρ']
    is represented as the top, and otherwise iff the decision of the order holds
    over the world of the comparison; a counterexample is the grade of the word
    the search of the order finds, and a grade is the top if it is represented
    as the top and otherwise iff the top is below it. *)

open Grade

(** The worlds of the comparisons of the grades [grade] and the decisions of the
    orders on traces over them. *)
module type WORLD = sig
  type grade
  type delay

  type world
  (** The operations of a comparison with their running times. *)

  type word
  (** A trace, as a search finds it. *)

  val suffix : string
  (** The suffix of the names of the three grades. *)

  val world :
    (running_time -> Rational.t bound) -> bounds -> grade list -> world
  (** [world endpoint bounds rhos] is the world of a comparison of [rhos], each
      operation running for the [endpoint] of its running-time bounds. *)

  val in_allowance : world -> grade -> grade -> bool
  (** [in_allowance w rho rho'] is whether every trace of [rho] over [w] is in
      the downward closure of [rho'] under allowance. *)

  val in_coverage : world -> grade -> grade -> bool
  (** [in_coverage w rho rho'] is whether every trace of [rho] over [w] is in
      the upward closure of [rho'] under coverage. *)

  val allowance : world -> grade -> grade -> word option
  (** [allowance w rho rho'] is a trace of [rho] over [w] outside the downward
      closure of [rho'], if any. *)

  val coverage : world -> grade -> grade -> word option
  (** [coverage w rho rho'] is a trace of [rho] over [w] outside the upward
      closure of [rho'], if any. *)

  val min_weight : world -> grade -> Rational.t bound option
  (** [min_weight w rho] is the least weight of the traces of [rho] over [w], as
      an end of running-time bounds, if any. *)

  val max_weight : world -> grade -> Rational.t bound option
  (** [max_weight w rho] is the greatest weight of the traces of [rho] over [w],
      as an end of running-time bounds, [None] if unbounded. *)

  val inhabited : bounds -> grade -> bool
  (** [inhabited bounds rho] is whether [rho] has a trace over the declared
      operations and the names it mentions, the running times aside. *)

  val grade_of_word : word -> grade
  (** [grade_of_word w] is the grade of the single trace [w]. *)

  val single : lit -> bool
  (** [single lit] is whether the literal [lit] of an interval abbreviates the
      interval of a language with itself. *)

  val number : lit -> Rational.t option
  (** [number lit] is the value of the numeric endpoint [lit] of an interval
      literal ({!Grade.bounds_of_lit}). *)

  val close : lower:bool -> lit -> lit
  (** [close ~lower a] is the bound of the open endpoint [a] of an interval
      literal ({!Grade.bounds_of_lit}). *)

  val lower_shadow : delay bound -> grade
  (** [lower_shadow lo] is the lower time shadow of the lower end [lo] of
      running-time bounds. *)

  val upper_shadow : delay bound -> grade
  (** [upper_shadow hi] is the upper time shadow of the upper end [hi] of
      running-time bounds. *)
end

(** The grades over [L] in the world [W], named ["regex-timed-lower-bound"],
    ["regex-timed-upper-bound"] and ["regex-timed-interval"], each followed by
    [W.suffix]. *)
module Make
    (L : Grade.S)
    (W : WORLD with type grade = L.t and type delay = L.Delay.t) : sig
  (** Lower bounds, in the coverage order at [lo]. *)
  module Lower : Grade.S with type t = L.t and type Delay.t = L.Delay.t

  (** Upper bounds, in the allowance order at [hi]. *)
  module Upper : Grade.S with type t = L.t and type Delay.t = L.Delay.t

  (** Closed intervals of a lower and an upper bound, compared componentwise. *)
  module Interval : Grade.S with type t = L.t * L.t and type Delay.t = L.Delay.t
end
