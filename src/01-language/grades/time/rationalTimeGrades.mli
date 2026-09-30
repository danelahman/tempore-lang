(** The rational time grades: bounds on the time a computation takes, measured
    by non-negative rationals.

    Their literals are integers and fractions, written as decimals such as [1.5]
    or quotients such as [1/3], [∞] for no upper bound, the intervals [[q, r]]
    between two of them and [\[q, ∞)] from one on, each finite endpoint closed
    or open, e.g. [(1/2, 3\]], a pair [(q, r)] being the open interval, and [⊤]
    (ASCII [top]) for the greatest grade. A grade is printed as an integer, as a
    decimal if its expansion terminates, and otherwise as a quotient. Delays are
    rationals too: the grades are {!TimeGrades.Make} over {!Delay.Rational}.

    {2 Witnesses}

    The witnesses of the finite constants of a condition are those of
    {!Delay.Rational}, with [∞] for the upper bounds; for the intervals the
    lower-bound witnesses are paired with [∞] and [0] with the upper-bound ones,
    all closed. They are complete for a condition in one rigid, the rigid
    ranging over intervals open or closed at either endpoint. *)

module LowerBound : Grade.S with type Delay.t = Delay.Rational.t
(** Lower bounds, ["time-lower-bound-rational"]: [q] is "at least [q]", ordered
    by [≥], so the unit [0] is the top. *)

module UpperBound : Grade.S with type Delay.t = Delay.Rational.t
(** Upper bounds, ["time-upper-bound-rational"]: [q] is "at most [q]", with [∞]
    imposing no bound, ordered by [≤]; [∞] is the top. *)

module Interval : Grade.S with type Delay.t = Delay.Rational.t
(** Intervals, ["time-interval-rational"]: [[q, r]] is "between [q] and [r]",
    [(q, r)] "strictly between [q] and [r]", [\[q, r)] and [(q, r\]] half-open,
    and [\[q, ∞)] and [(q, ∞)] impose no upper bound; the non-empty intervals,
    ordered by containment, with unit [[0, 0]] and top [\[0, ∞)]. The product is
    the Minkowski sum: an endpoint of a sum is open iff one of the endpoints
    summed is. A grade is printed as written, e.g. [(1/2, 3\]]. *)
