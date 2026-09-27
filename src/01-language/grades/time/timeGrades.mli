(** The time grades: bounds on the number of time steps a computation takes.

    Their literals are integers, pairs of integers for the intervals, [∞] for no
    upper bound, and [⊤] (ASCII [top]) for the greatest grade. *)

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
