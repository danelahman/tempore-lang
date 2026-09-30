(** The time grades: bounds on the time a computation takes, over a totally
    ordered monoid of delays, the durations.

    Their literals are the delays, [∞] for no upper bound, the intervals
    [[n, m]] between two delays and [\[n, ∞)] from a delay on, each finite
    endpoint closed or open, e.g. [(n, m\]] or [(n, ∞)], a pair [(n, m)] being
    the open interval, and [⊤] (ASCII [top]) for the greatest grade.

    The witnesses of a closed condition are those the delays supply for its
    finite constants, with [∞] for the upper bounds, and for the intervals the
    lower-bound witnesses paired with [∞] and [0] paired with the upper-bound
    ones, all closed. They are complete for a condition in one rigid when those
    of the delays are. *)

(** The presentation of the time grades over a kind of delays. *)
module type NAMES = sig
  type delay
  (** The delays. *)

  val suffix : string
  (** The suffix of the names of the grades, e.g. [""] or ["-rational"]. *)

  val numbers : string
  (** The literals of the delays, in the plural, e.g. ["integers"]. *)

  val step : delay option
  (** The least positive delay, if there is one; an open endpoint [(n] of an
      interval then abbreviates the closed one [\[n + step], and [m)] the closed
      one [m ∸ step\]]. [None] for dense delays. *)
end

(** The time grades over the delays [D], named by [N]. A negative literal is
    rejected as such where its absolute value is a delay. *)
module Make (D : Delay.MONUS) (N : NAMES with type delay = D.t) : sig
  module LowerBound : Grade.S with type Delay.t = D.t
  (** Lower bounds, ["time-lower-bound" ^ N.suffix]: [n] is "at least [n]",
      ordered by [≥], so the unit [0] is the top. *)

  module UpperBound : Grade.S with type Delay.t = D.t
  (** Upper bounds, ["time-upper-bound" ^ N.suffix]: [n] is "at most [n]", with
      [∞] imposing no bound, ordered by [≤]; [∞] is the top. *)

  module Interval : Grade.S with type Delay.t = D.t
  (** Intervals, ["time-interval" ^ N.suffix]: [[n, m]] is "between [n] and
      [m]", [(n, m)] "strictly between [n] and [m]", and [\[n, ∞)] imposes no
      upper bound; the non-empty intervals, ordered by containment, with unit
      [[0, 0]] and top [\[0, ∞)]. The product is the Minkowski sum, an endpoint
      of a sum being open iff one of the endpoints summed is. A grade is printed
      with its endpoints as they are: closed only if [N.step] is a delay. *)
end

(** {1 Time in whole steps}

    The durations are the natural numbers of time steps, written as integers,
    and so are the delays: {!Make} over {!Delay.Nat}. *)

module LowerBound : Grade.S with type Delay.t = Delay.Nat.t
(** Lower bounds, ["time-lower-bound"]: [n] is "at least [n] time steps",
    ordered by [≥], so the unit [0] is the top. *)

module UpperBound : Grade.S with type Delay.t = Delay.Nat.t
(** Upper bounds, ["time-upper-bound"]: [n] is "at most [n] time steps", with
    [∞] imposing no bound, ordered by [≤]; [∞] is the top. *)

module Interval : Grade.S with type Delay.t = Delay.Nat.t
(** Intervals, ["time-interval"]: [[n, m]] is "between [n] and [m] time steps",
    and [\[n, ∞)] imposes no upper bound; ordered by containment, with top
    [\[0, ∞)]. An open endpoint abbreviates a closed one, [(n, m)] being
    [[n + 1, m - 1]], and a grade is printed closed. *)
