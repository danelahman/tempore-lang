(** The rational time grades: bounds on the time a computation takes, measured
    by non-negative rationals.

    Their literals are integers and fractions, written as decimals such as [1.5]
    or quotients such as [1/3], [∞] for no upper bound, the intervals [[q, r]]
    between two of them and [\[q, ∞)] from one on, and [⊤] (ASCII [top]) for the
    greatest grade. A grade is printed as an integer, as a decimal if its
    expansion terminates, and otherwise as a quotient. Delays are rationals too:
    the grades are {!TimeGrades.Make} over {!Delay.Rational}.

    {2 Witnesses}

    The witnesses of the finite constants of a condition are those of
    {!Delay.Rational}, with [∞] for the upper bounds; for the intervals the
    lower-bound witnesses are paired with [∞] and [0] with the upper-bound ones.
    They are complete for a condition in one rigid. *)

module LowerBound : Grade.S with type Delay.t = Delay.Rational.t
(** Lower bounds, ["time-lower-bound-rational"]: [q] is "at least [q]", ordered
    by [≥], so the unit [0] is the top. *)

module UpperBound : Grade.S with type Delay.t = Delay.Rational.t
(** Upper bounds, ["time-upper-bound-rational"]: [q] is "at most [q]", with [∞]
    imposing no bound, ordered by [≤]; [∞] is the top. *)

module Interval : Grade.S with type Delay.t = Delay.Rational.t
(** Intervals, ["time-interval-rational"]: [[q, r]] is "between [q] and [r]",
    and [\[q, ∞)] imposes no upper bound; ordered by containment, with top
    [\[0, ∞)]. *)
