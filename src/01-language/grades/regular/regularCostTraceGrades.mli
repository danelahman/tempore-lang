(** The cost-model regular trace grades: the regular languages of runs of
    {!RegularTraceGrade}, ordered as the timed-trace grades of
    {!TimedTraceGrades} order finite sets of runs, trading time against
    operations at their declared runtime bounds.

    {2 Orders}

    A run is a word over [tick] and operation names, as in {!RegularTraceGrade},
    and the orders on single runs are allowance and coverage, as characterised
    in {!CostClosure}. A grade is ordered below another through the closure of
    the greater one:
    - upper bounds, ["traces-regex-upper"]: [ρ ≾ ρ'] iff every run of [ρ] is
      permitted by some run of [ρ'], i.e. [ρ ⊆ ↓ρ'], operations costing their
      upper runtime bound [hi];
    - lower bounds, ["traces-regex-lower"]: [ρ ≾ ρ'] iff every run of [ρ] covers
      some run of [ρ'], i.e. [ρ ⊆ ↑ρ'], operations costing their lower runtime
      bound [lo];
    - intervals, ["traces-regex-interval"]: pairs of a lower and an upper bound,
      compared componentwise.

    Both are preorders, the closures being closure operators; a grade denotes
    its closure, and [equal] is mutual [≾], coarser than the equality of
    languages: if [Read] declares [within (1, 3)], then [{Read} ≾ {3}] but not
    conversely and [{Read | 3} ≡ {3}] under the upper order, and
    [{Read | 1} ≡ {1}] and [⊤ ≡ {0}] under the lower order. Products and joins
    are those of languages, monotone in the orders, and [≡] is a congruence for
    them; the product of closures is in general strictly smaller than the
    closure of the product.

    {2 Closed world}

    The alphabet of a comparison is [tick], the declared operations of the cost
    model and the names the grades compared mention, each operation with its own
    runtime bounds; the catch-all letter of each grade stands for each of these
    operations it does not name. A run of a grade that performs its catch-all
    letter where no such operation exists is no run.

    {2 Grades}

    The literals, the unit [{0}], the product, the join, [of_nat] and the
    printing are those of the underlying regular trace grade. The upper order
    has the language [⊤] of all runs as its top, absorbing up to [≡], and its
    unit is least; the lower order has the unit as its top. The runtime bounds
    implied by a grade are the least weight of its lower-bound runs, at [lo],
    and the greatest weight of its upper-bound runs, at [hi], [None] if the
    latter is unbounded; an operation's time shadow [of_bounds (lo, hi)] is
    [{lo}] under the lower order and [{hi}] under the upper. A counterexample to
    [ρ ≾ ρ'] is the grade of a shortest run of [ρ] outside the closure of [ρ'],
    in which a name stands for itself. *)

(** A regular trace grade with the concrete languages of its grades. *)
module type LANGUAGE = sig
  include Grade.S

  val concrete : string list -> t -> Dfa.t
  (** [concrete names rho] is the language of the runs of [rho] that perform
      only operations among [names], over the letters [tick], numbered [0], and
      [names], numbered from [1] in their order, the catch-all letter of [rho]
      standing for each of [names] that [rho] does not mention. *)
end

(** The three grades over the regular trace grade [L], named
    ["traces-regex-lower"], ["traces-regex-upper"] and
    ["traces-regex-interval"], each followed by [Variant.suffix]. *)
module Make
    (L : LANGUAGE)
    (Variant : sig
      val suffix : string
    end) : sig
  module Lower : Grade.S with type t = L.t
  (** Lower bounds, in the coverage order at [lo]. *)

  module Upper : Grade.S with type t = L.t
  (** Upper bounds, in the allowance order at [hi]. *)

  module Interval : Grade.S with type t = L.t * L.t
  (** Pairs of a lower and an upper bound, compared componentwise, written
      [({...}, {...})]; a brace literal [{...}] abbreviates the pair of a
      language with itself, [n] the pair [({n}, {n})] and [(n, m)] the pair
      [({n}, {m})]. *)
end

module Lower : Grade.S with type t = RegularTraceGrade.t
(** ["traces-regex-lower"], over {!RegularTraceGrade}. *)

module Upper : Grade.S with type t = RegularTraceGrade.t
(** ["traces-regex-upper"], over {!RegularTraceGrade}. *)

module Interval :
  Grade.S with type t = RegularTraceGrade.t * RegularTraceGrade.t
(** ["traces-regex-interval"], over {!RegularTraceGrade}. *)
