(** The trace grades with costs: finite sets of traces (see {!TimedTrace}),
    multiplied by the language product and ordered by the runtime bounds of the
    operations. The trace grades ordered by inclusion, without costs, are those
    of {!TraceInclusionGrades}.

    {2 Cost model}

    An operation declares a pair of runtime bounds [within [lo, hi]], and the
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

(** The presentation of trace grades with costs over a kind of delays. *)
module type COST_NAMES = sig
  include NAMES

  val close : lower:bool -> GradeLiteral.lit -> GradeLiteral.lit
  (** [close ~lower a] is the closed endpoint that abbreviates the open numeric
      endpoint [a] of an interval, [lower] being whether it is the lower one.

      @raise Grade.Invalid_literal if no closed endpoint does. *)
end

(** The trace grades with costs over the delays [D], named by [N]. *)
module Make (D : Delay.MEASURED) (N : COST_NAMES) : sig
  module LowerBound : Grade.S with type Delay.t = D.t
  (** Sets of traces read as lower bounds,
      ["traces-cost-lower-bound" ^ N.suffix], in the coverage order; the unit
      [{0}] is the top. *)

  module UpperBound : Grade.S with type Delay.t = D.t
  (** Sets of traces read as upper bounds,
      ["traces-cost-upper-bound" ^ N.suffix], in the allowance order, with a
      separate greatest point [⊤] permitting any run. *)

  module Interval : Grade.S with type Delay.t = D.t
  (** Closed intervals of a lower and an upper bound,
      ["traces-cost-interval" ^ N.suffix], compared componentwise, written
      [[{...}, {...}]], and [\[{...}, ∞)] without an upper bound. A brace
      literal [{...}] abbreviates the interval of a set with itself, a delay [d]
      the interval [[{d}, {d}]] and [[d, e]] the interval [[{d}, {e}]]; an open
      numeric endpoint is read by [N.close]. Either end may be [⊤], the top of
      its order. *)
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
(** Closed intervals of a lower and an upper bound, ["traces-cost-interval"],
    compared componentwise, written [[{...}, {...}]], and [\[{...}, ∞)] without
    an upper bound. A brace literal [{...}] abbreviates the interval of a set
    with itself, [n] the interval [[{n}, {n}]] and [[n, m]] the interval
    [[{n}, {m}]]; an open endpoint abbreviates a closed one, [(n, m)] being
    [[n + 1, m - 1]]. Either end may be [⊤], the top of its order. *)

(** {1 Traces over rational delays}

    The delays are the non-negative rationals, written as integers and
    fractions, e.g. [{Read; 1/2; Send}] or [[0.5, 3/2]], and so are the runtime
    bounds, e.g. [within [1/2, 3/2]]: {!Make} over {!Delay.Rational}. *)
module Rational : sig
  module LowerBound : Grade.S with type Delay.t = Delay.Rational.t
  (** Sets of traces read as lower bounds, ["traces-cost-lower-bound-rational"],
      in the coverage order. *)

  module UpperBound : Grade.S with type Delay.t = Delay.Rational.t
  (** Sets of traces read as upper bounds, ["traces-cost-upper-bound-rational"],
      in the allowance order. *)

  module Interval : Grade.S with type Delay.t = Delay.Rational.t
  (** Closed intervals of a lower and an upper bound,
      ["traces-cost-interval-rational"], compared componentwise. An open
      endpoint, a set of delays, is no finite set of runs, and is rejected. *)
end
