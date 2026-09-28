(** The time grades: bounds on the time a computation takes, over a domain of
    durations.

    Their literals are the durations of the domain, pairs of them for the
    intervals, [∞] for no upper bound, and [⊤] (ASCII [top]) for the greatest
    grade.

    The witnesses of a closed condition are those the domain supplies for its
    finite constants, with [∞] for the upper bounds, and for the intervals the
    lower-bound witnesses paired with [∞] and [0] paired with the upper-bound
    ones. They are complete for a condition in one rigid when those of the
    domain are. *)

(** Domains of durations: totally ordered commutative monoids containing the
    natural numbers, with their literals and witnesses. *)
module type DOMAIN = sig
  type t
  (** The durations. *)

  val module_name : string
  (** The module of the grades, named in messages, e.g. ["TimeGrades"]. *)

  val suffix : string
  (** The suffix of the names of the grades, e.g. [""] or ["-rational"]. *)

  val zero : t
  (** The duration [0], the unit of {!add}. *)

  val add : t -> t -> t
  (** The sum of durations. *)

  val compare : t -> t -> int
  (** The total order [≤], compatible with {!add}: canonical, [compare d d' = 0]
      iff [d] and [d'] are equal. *)

  val hash : t -> int
  (** A hash compatible with {!compare}. *)

  val of_int : int -> t
  (** [of_int n] is the duration of [n ≥ 0] time steps; a monoid morphism from
      [(ℕ, +, 0)]. *)

  val of_duration : Rational.t -> t
  (** [of_duration q] is the duration [q ≥ 0]; a monoid morphism from
      [(ℚ≥0, +, 0)] on its domain, a submonoid containing [ℕ], agreeing with
      {!of_int} there.

      @raise Grade.Invalid_literal if [q] is not a duration.
      @raise Invalid_argument if [q] is negative. *)

  val read : Grade.lit -> t option
  (** [read lit] is the duration, possibly negative, the literal [lit] denotes,
      and [None] if it does not denote one. *)

  val numbers : string
  (** The literals {!read} accepts, in the plural, e.g. ["integers"]. *)

  val show : t -> string
  (** [show d] prints [d] in a form {!read} accepts. *)

  val witnesses : degree:int -> t list -> t list
  (** [witnesses ~degree cs] is a finite list of durations such that an ordering
      [L ≤ R] between expressions built from the durations [cs], a variable [j],
      sums and one of minima or maxima, each side with at most [degree]
      occurrences of [j], holds at every duration [j] iff it holds at every
      witness. *)
end

(** The time grades over the durations [N]. *)
module Make (N : DOMAIN) : sig
  module LowerBound : Grade.S
  (** Lower bounds, ["time-lower-bound" ^ N.suffix]: [n] is "at least [n]",
      ordered by [≥], so the unit [0] is the top. *)

  module UpperBound : Grade.S
  (** Upper bounds, ["time-upper-bound" ^ N.suffix]: [n] is "at most [n]", with
      [∞] imposing no bound, ordered by [≤]; [∞] is the top. *)

  module Interval : Grade.S
  (** Intervals, ["time-interval" ^ N.suffix]: [(n, m)] is "between [n] and
      [m]", with [m = ∞] imposing no upper bound, ordered by containment;
      [(0, ∞)] is the top. *)
end

(** {1 Discrete time}

    The durations are the natural numbers of time steps, written as integers,
    and so are the delays. The witnesses of the finite constants summing to [s]
    are [0], ..., [s+1], whatever the degree. *)

module LowerBound : Grade.S
(** Lower bounds, ["time-lower-bound"]: [n] is "at least [n] time steps",
    ordered by [≥], so the unit [0] is the top. *)

module UpperBound : Grade.S
(** Upper bounds, ["time-upper-bound"]: [n] is "at most [n] time steps", with
    [∞] imposing no bound, ordered by [≤]; [∞] is the top. *)

module Interval : Grade.S
(** Intervals, ["time-interval"]: [(n, m)] is "between [n] and [m] time steps",
    with [m = ∞] imposing no upper bound, ordered by containment; [(0, ∞)] is
    the top. *)
