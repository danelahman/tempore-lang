(** The trace grades without running times: finite sets of traces (see
    {!TimedTrace}), multiplied by the language product and ordered by inclusion.

    {2 Order}

    A grade [p] is below [q] iff every run of [p] is a run of [q], the runs
    compared in their normal form, so that adjacent delays are merged. The
    operations declare no runtime bounds, and a delay pays for nothing. The
    greatest grade [⊤] is a separate point, permitting any run, and absorbs
    products and joins.

    The runs of a grade are compared by equality, so an upper and a lower bound
    both reduce to inclusion, and an interval to a pair of equal inclusions:
    only the upper-bound grades are provided.

    {2 Representations}

    A set of traces is kept sorted and duplicate-free, which is canonical for
    inclusion: [equal] and [compare] agree, and [is_top] holds of [⊤] alone.

    {2 Literals}

    Those of the upper-bound trace grades of timed operations
    ({!TimedTraceGrades}): a brace literal such as
    [{Read; 3; Send | Send; Send}], a delay [d] abbreviating [{d}], and [⊤]
    (ASCII [top]).

    {2 Counterexamples and witnesses}

    A failure of [p ≾ q] between sets of runs is witnessed by the least run of
    [p] that [q] does not list. The witnesses of a closed condition are its
    constants and their pairwise products ({!Grade.sampled}), which are not
    complete.

    {2 Delays}

    The grades are defined over any monoid of delays ({!Delay.S}), a delay [d]
    being the trace [d]. They are instantiated over the natural numbers of time
    steps ({!Delay.Nat}) and over the non-negative rationals
    ({!Delay.Rational}). *)

(** The trace grades without running times over the delays [D], named by [N]. *)
module Make (D : Delay.S) (N : TimedTraceGrades.NAMES) : sig
  module UpperBound : Grade.S with type Delay.t = D.t
  (** Sets of traces ordered by inclusion, ["traces-upper-bound" ^ N.suffix],
      with a separate greatest point [⊤]. *)
end

module UpperBound : Grade.S with type Delay.t = Delay.Nat.t
(** Sets of traces over whole time steps ordered by inclusion,
    ["traces-upper-bound"]: {!Make} over {!Delay.Nat}. *)

(** The trace grades without running times over rational delays. *)
module Rational : sig
  module UpperBound : Grade.S with type Delay.t = Delay.Rational.t
  (** Sets of traces with rational delays ordered by inclusion,
      ["traces-upper-bound-rational"]: {!Make} over {!Delay.Rational}. *)
end
