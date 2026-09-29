(** The time grades: bounds on the time a computation takes, over a totally
    ordered monoid of delays, the durations.

    Their literals are the delays, pairs of them for the intervals, [∞] for no
    upper bound, and [⊤] (ASCII [top]) for the greatest grade.

    The witnesses of a closed condition are those the delays supply for its
    finite constants, with [∞] for the upper bounds, and for the intervals the
    lower-bound witnesses paired with [∞] and [0] paired with the upper-bound
    ones. They are complete for a condition in one rigid when those of the
    delays are. *)

(** The presentation of the time grades over a kind of delays. *)
module type NAMES = sig
  val suffix : string
  (** The suffix of the names of the grades, e.g. [""] or ["-rational"]. *)

  val numbers : string
  (** The literals of the delays, in the plural, e.g. ["integers"]. *)
end

(** The time grades over the delays [D], named by [N]. A negative literal is
    rejected as such where its absolute value is a delay. *)
module Make (D : Delay.ORDERED) (N : NAMES) : sig
  module LowerBound : Grade.S with type Delay.t = D.t
  (** Lower bounds, ["time-lower-bound" ^ N.suffix]: [n] is "at least [n]",
      ordered by [≥], so the unit [0] is the top. *)

  module UpperBound : Grade.S with type Delay.t = D.t
  (** Upper bounds, ["time-upper-bound" ^ N.suffix]: [n] is "at most [n]", with
      [∞] imposing no bound, ordered by [≤]; [∞] is the top. *)

  module Interval : Grade.S with type Delay.t = D.t
  (** Intervals, ["time-interval" ^ N.suffix]: [(n, m)] is "between [n] and
      [m]", with [m = ∞] imposing no upper bound, ordered by containment;
      [(0, ∞)] is the top. *)
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
(** Intervals, ["time-interval"]: [(n, m)] is "between [n] and [m] time steps",
    with [m = ∞] imposing no upper bound, ordered by containment; [(0, ∞)] is
    the top. *)
