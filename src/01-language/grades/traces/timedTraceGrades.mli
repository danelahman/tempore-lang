(** The timed-trace grades: finite sets of timed traces (see {!TimedTrace}),
    multiplied by the language product.

    {2 Cost model}

    An operation declares a pair of runtime bounds [within (lo, hi)], and the
    two orders read different endpoints: [lo] feeds the coverage (lower-bound)
    order and [hi] the allowance (upper-bound) order.

    {2 Representations}

    A set of timed traces is kept sorted and duplicate-free, not reduced to the
    antichain of its extremal members, since that reduction depends on the order
    and hence on the cost model. So [mul] and [join] need no cost model, but a
    grade may have several representations; [equal] is mutual [leq], which is
    equality of the reduced antichains, and [compare] and [hash] are those of
    the representations. The top alone is decided from the representation: a
    lower bound is the top iff it lists the empty run, and an upper bound iff it
    is [⊤].

    {2 Literals}

    A set of timed traces is written as a brace literal, a union with [|] of
    sequences with [;] of operation names and delays, e.g.
    [{Read; 3; Send | Send; Send}]; parentheses group, and a concatenation of
    unions denotes the set of the concatenations of their members. An integer
    [n] abbreviates [{n}], and [⊤] (ASCII [top]) is the greatest grade. The
    other regular-expression forms, [*], [&], [~] and [_], are rejected.

    {2 Witnesses}

    The witnesses of a closed condition are its constants and their pairwise
    products ({!Grade.sampled}), which are not complete. *)

module LowerBound : Grade.S
(** Sets of timed traces read as lower bounds, ["traces-lower-bound"], in the
    coverage order; the unit [{0}] is the top. *)

module UpperBound : Grade.S
(** Sets of timed traces read as upper bounds, ["traces-upper-bound"], in the
    allowance order, with a separate greatest point [⊤] permitting any run. *)

module Interval : Grade.S
(** Pairs of a lower and an upper bound, ["traces-interval"], compared
    componentwise, written [({...}, {...})]. A brace literal [{...}] abbreviates
    the pair of a set with itself, [n] the pair [({n}, {n})] and [(n, m)] the
    pair [({n}, {m})]; either component may be [⊤], its top. *)
