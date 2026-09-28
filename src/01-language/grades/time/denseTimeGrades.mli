(** The dense time grades: bounds on the time a computation takes, measured by
    non-negative rationals.

    Their literals are integers and fractions, written as decimals such as [1.5]
    or quotients such as [1/3], pairs of them for the intervals, [∞] for no
    upper bound, and [⊤] (ASCII [top]) for the greatest grade. A grade is
    printed as an integer, as a decimal if its expansion terminates, and
    otherwise as a quotient. Delays are rationals too.

    {2 Witnesses}

    Let [s] be the sum of the finite constants of a condition, [D] the least
    common multiple of their denominators, and [K ≥ 1] a bound on the number of
    occurrences of the rigid on either side. The witnesses are the grid
    [G = { x/(D·m) : x ∈ 0..s·D, m ∈ 1..K }], the midpoints of its consecutive
    elements and [s+1], with [∞] for the upper bounds; for the intervals the
    lower-bound witnesses are paired with [∞] and [0] with the upper-bound ones.
    They are complete for a condition in one rigid. *)

module LowerBound : Grade.S
(** Lower bounds, ["dense-time-lower-bound"]: [q] is "at least [q]", ordered by
    [≥], so the unit [0] is the top. *)

module UpperBound : Grade.S
(** Upper bounds, ["dense-time-upper-bound"]: [q] is "at most [q]", with [∞]
    imposing no bound, ordered by [≤]; [∞] is the top. *)

module Interval : Grade.S
(** Intervals, ["dense-time-interval"]: [(q, r)] is "between [q] and [r]", with
    [r = ∞] imposing no upper bound, ordered by containment; [(0, ∞)] is the
    top. *)
