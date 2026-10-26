(** The rational time grades: bounds on the time a computation takes, measured
    by non-negative rationals.

    Their literals are integers and fractions, written as decimals such as [1.5]
    or quotients such as [1/3], [∞] for no upper bound, the intervals [[q, r]]
    between two of them and [\[q, ∞)] from one on, each finite endpoint closed
    or open, e.g. [(1/2, 3\]], a pair [(q, r)] being the open interval, and [⊤]
    (ASCII [top]) for the greatest grade. A lower bound is written as a number,
    [\[q, ∞)] or [(q, ∞)], an upper bound as a number, [[0, q]], [\[0, q)], [∞]
    or [\[0, ∞)]. A number is printed as an integer, as a decimal if its
    expansion terminates, and otherwise as a quotient. Delays are rationals too:
    the grades are {!TimeGrades.Make} over {!Delay.Rational}.

    {2 Witnesses}

    The witnesses of the finite constants of a condition are those of
    {!Delay.Rational}, with [∞] for the upper bounds; for the intervals the
    lower-bound witnesses are paired with [∞] and [0] with the upper-bound ones,
    all closed. They are complete for a condition in one rigid, the rigid and
    the constants ranging over the bounds and intervals open or closed at their
    finite ends: an ordering that fails at an open end [q] fails at [q] closed
    or at a closed witness next to it. *)

module LowerBound : Grade.S with type Delay.t = Delay.Rational.t
(** Lower bounds, ["time-lower-bound-rational"]: [q] and [\[q, ∞)] are "at least
    [q]", [(q, ∞)] "more than [q]"; ordered by the inclusion of the durations
    they admit, so [(q, ∞)] is below [q] and the unit [0] is the top. The
    product adds the bounds, the sum being open iff a summand is. A closed bound
    is printed as [q], an open one as [(q, ∞)]. *)

module UpperBound : Grade.S with type Delay.t = Delay.Rational.t
(** Upper bounds, ["time-upper-bound-rational"]: [q] and [[0, q]] are "at most
    [q]", [\[0, q)] "less than [q]" for a positive [q], and [∞] and [\[0, ∞)]
    impose no bound; ordered by the inclusion of the durations they admit, so
    [\[0, q)] is below [q] and [∞] is the top. The product adds the bounds, the
    sum being open iff a summand is. A closed bound is printed as [q] or [∞], an
    open one as [\[0, q)]. *)

module Interval : Grade.S with type Delay.t = Delay.Rational.t
(** Intervals, ["time-interval-rational"]: [[q, r]] is "between [q] and [r]",
    [(q, r)] "strictly between [q] and [r]", [\[q, r)] and [(q, r\]] half-open,
    and [\[q, ∞)] and [(q, ∞)] impose no upper bound; the non-empty intervals,
    ordered by containment, with unit [[0, 0]] and top [\[0, ∞)]. The product is
    the Minkowski sum: an endpoint of a sum is open iff one of the endpoints
    summed is. A grade is printed as written, e.g. [(1/2, 3\]]. *)
