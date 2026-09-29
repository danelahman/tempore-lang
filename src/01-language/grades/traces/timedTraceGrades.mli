(** The trace grades with costs: finite sets of traces (see {!TimedTrace}),
    multiplied by the language product and ordered by the runtime bounds of the
    operations. The trace grades ordered by inclusion, without costs, are those
    of {!TraceInclusionGrades}.

    {2 Cost model}

    An operation declares a pair of runtime bounds [within (lo, hi)], and the
    two orders read different endpoints: [lo] feeds the coverage (lower-bound)
    order and [hi] the allowance (upper-bound) order. The runtime bounds are
    read as delays ({!Grade.read_bound}), and the runtime bounds a compound
    operation's grade implies are measured by {!Delay.MEASURED.to_rational}.

    {2 Representations}

    A set of traces is kept sorted and duplicate-free, not reduced to the
    antichain of its extremal members, since that reduction depends on the order
    and hence on the cost model. So [mul] and [join] need no cost model, but a
    grade may have several representations; [equal] is mutual [leq], which is
    equality of the reduced antichains, and [compare] and [hash] are those of
    the representations. The top alone is decided from the representation: a
    lower bound is the top iff it lists the empty run, and an upper bound iff it
    is [⊤].

    {2 Literals}

    A set of traces is written as a brace literal, a union with [|] of sequences
    with [;] of operation names and delays, e.g. [{Read; 3; Send | Send; Send}];
    parentheses group, and a concatenation of unions denotes the set of the
    concatenations of their members. A delay [d] abbreviates [{d}], and [⊤]
    (ASCII [top]) is the greatest grade. The delays of a literal are read by
    those of the grades ({!Delay.S.read}): integers over {!Delay.Nat}, integers
    and fractions over {!Delay.Rational}. The other regular-expression forms,
    [*], [&], [~] and [_], are rejected.

    {2 Witnesses}

    The witnesses of a closed condition are its constants and their pairwise
    products ({!Grade.sampled}), which are not complete.

    {2 Delays}

    The grades are defined over an ordered monoid of delays with monus
    ({!Delay.MEASURED}), a delay [d] being the trace [d]: the orders add the
    delays of a bound to a budget and subtract those of a run from it with the
    monus. They are instantiated over the natural numbers of time steps
    ({!Delay.Nat}) and over the non-negative rationals ({!Delay.Rational}). *)

(** The presentation of trace grades over a kind of delays. *)
module type NAMES = sig
  val suffix : string
  (** The suffix of the names of the grades, e.g. [""] or ["-rational"]. *)

  val number : string
  (** The literals of the delays, in the singular, e.g. ["integer"]. *)
end

(** The trace grades with costs over the delays [D], named by [N]. *)
module Make (D : Delay.MEASURED) (N : NAMES) : sig
  module LowerBound : Grade.S with type Delay.t = D.t
  (** Sets of traces read as lower bounds,
      ["traces-cost-lower-bound" ^ N.suffix], in the coverage order; the unit
      [{0}] is the top. *)

  module UpperBound : Grade.S with type Delay.t = D.t
  (** Sets of traces read as upper bounds,
      ["traces-cost-upper-bound" ^ N.suffix], in the allowance order, with a
      separate greatest point [⊤] permitting any run. *)

  module Interval : Grade.S with type Delay.t = D.t
  (** Pairs of a lower and an upper bound, ["traces-cost-interval" ^ N.suffix],
      compared componentwise, written [({...}, {...})]. A brace literal [{...}]
      abbreviates the pair of a set with itself, a delay [d] the pair
      [({d}, {d})] and [(d, e)] the pair [({d}, {e})]; either component may be
      [⊤], its top. *)
end

(** {1 Traces over whole time steps}

    The delays are the natural numbers of time steps, written as integers, and
    so are the runtime bounds: {!Make} over {!Delay.Nat}. *)

module LowerBound : Grade.S with type Delay.t = Delay.Nat.t
(** Sets of traces read as lower bounds, ["traces-cost-lower-bound"], in the
    coverage order; the unit [{0}] is the top. *)

module UpperBound : Grade.S with type Delay.t = Delay.Nat.t
(** Sets of traces read as upper bounds, ["traces-cost-upper-bound"], in the
    allowance order, with a separate greatest point [⊤] permitting any run. *)

module Interval : Grade.S with type Delay.t = Delay.Nat.t
(** Pairs of a lower and an upper bound, ["traces-cost-interval"], compared
    componentwise, written [({...}, {...})]. A brace literal [{...}] abbreviates
    the pair of a set with itself, [n] the pair [({n}, {n})] and [(n, m)] the
    pair [({n}, {m})]; either component may be [⊤], its top. *)

(** {1 Traces over rational delays}

    The delays are the non-negative rationals, written as integers and
    fractions, e.g. [{Read; 1/2; Send}] or [(0.5, 3/2)], and so are the runtime
    bounds, e.g. [within (1/2, 3/2)]: {!Make} over {!Delay.Rational}. *)
module Rational : sig
  module LowerBound : Grade.S with type Delay.t = Delay.Rational.t
  (** Sets of traces read as lower bounds, ["traces-cost-lower-bound-rational"],
      in the coverage order. *)

  module UpperBound : Grade.S with type Delay.t = Delay.Rational.t
  (** Sets of traces read as upper bounds, ["traces-cost-upper-bound-rational"],
      in the allowance order. *)

  module Interval : Grade.S with type Delay.t = Delay.Rational.t
  (** Pairs of a lower and an upper bound, ["traces-cost-interval-rational"],
      compared componentwise. *)
end
