(** The cost-model regular trace grades: the regular languages of runs of
    {!RegularTraceGrade}, or of its implementations by derivatives
    {!RegularTraceGradeDerivative}, {!RegularTraceGradeDerivative.Concrete} and
    {!RegularTraceGradePlain}, ordered as the trace grades of
    {!TimedTraceGrades} order finite sets of runs, trading time against
    operations at their declared runtime bounds.

    {2 Orders}

    A run is a word over [tick] and operation names, as in {!RegularTraceGrade},
    and the orders on single runs are allowance and coverage, as characterised
    in {!CostClosure}. A grade is ordered below another through the closure of
    the greater one:
    - upper bounds, ["regex-cost-upper-bound"]: [ρ ≾ ρ'] iff every run of [ρ] is
      permitted by some run of [ρ'], i.e. [ρ ⊆ ↓ρ'], operations costing their
      upper runtime bound [hi];
    - lower bounds, ["regex-cost-lower-bound"]: [ρ ≾ ρ'] iff every run of [ρ]
      covers some run of [ρ'], i.e. [ρ ⊆ ↑ρ'], operations costing their lower
      runtime bound [lo];
    - intervals, ["regex-cost-interval"]: pairs of a lower and an upper bound,
      compared componentwise.

    Both are preorders, the closures being closure operators; a grade denotes
    its closure, and [equal] is mutual [≾], coarser than the equality of
    languages: if [Read] declares [within (1, 3)], then [{Read} ≾ {3}] but not
    conversely and [{Read | 3} ≡ {3}] under the upper order, and
    [{Read | 1} ≡ {1}] and [⊤ ≡ {0}] under the lower order. Products and joins
    are those of languages, monotone in the orders, and [≡] is a congruence for
    them; the product of closures is in general strictly smaller than the
    closure of the product: under the upper order the run [Read] is in
    [↓({2}·{2})] but not in [↓{2}·↓{2}]. An operation cannot be excluded while
    unbounded time is allowed: [{(_ & ~Read)*} ≡ ⊤] under the upper order, its
    ticks paying for [Read]. The grades are thus regular languages modulo
    downward closure under a preorder on runs compatible with concatenation
    (allowance, or the converse of coverage), the model of Kleene algebra with
    hypotheses (Doumane, Kuperberg, Pous and Pradic, FoSSaCS 2019).

    {2 Closed world}

    The alphabet of a comparison is [tick], the operations of the cost model and
    the names the grades compared mention, each operation with its own runtime
    bounds; the catch-all letter of each grade stands for each of these
    operations it does not name. The operations of the cost model are those the
    whole program declares with runtime bounds, before or after the grade, so
    that a grade means the same throughout a program. A run of a grade that
    performs its catch-all letter where no such operation exists is no run, and
    a grade must denote at least one run: {!Grade.S.inhabited} [bounds rho] is
    whether [rho] has a run over [tick], the operations of [bounds] and the
    names [rho] mentions, which fails for [{_ & ~1 & ~A}] if [A] is the only
    operation declared. On the grades that have one, the unit [{0}] is least
    under the upper order.

    {2 Grades}

    The literals, the unit [{0}], the product, the join, [of_delay] and the
    printing are those of the underlying regular trace grade. The upper order
    has the language [⊤] of all runs as its top, absorbing up to [≡], and its
    unit is least; the lower order has the unit as its top. The runtime bounds
    implied by a grade are the least weight of its lower-bound runs, at [lo],
    and the greatest weight of its upper-bound runs, at [hi], [None] if the
    latter is unbounded; an operation's time shadow [of_bounds (lo, hi)] is
    [{lo}] under the lower order and [{hi}] under the upper. A counterexample to
    [ρ ≾ ρ'] is the grade of a shortest run of [ρ] outside the closure of [ρ'],
    in which a name stands for itself. The witnesses of a closed condition are
    its constants and their pairwise products ({!Grade.sampled}), which are not
    complete. *)

(** A regular trace grade with the languages of its grades over given names; its
    delays are whole time steps, a delay of [n] steps being the word [tickⁿ]. *)
module type LANGUAGE = sig
  include Grade.S with type Delay.t = Delay.Nat.t

  module State : Map.OrderedType
  (** The states of the automata of {!runs}. *)

  val concrete : string list -> t -> Dfa.t
  (** [concrete names rho] is the language of the runs of [rho] that perform
      only operations among [names], over the letters [tick], numbered [0], and
      [names], numbered from [1] in their order, the catch-all letter of [rho]
      standing for each of [names] that [rho] does not mention. *)

  val runs : string list -> t -> State.t Dfa.automaton
  (** [runs names rho] is an automaton of the same language over the same
      letters, explored only as far as a search needs, whose [dead] holds
      exactly of the states from which no final state is reachable. *)

  val representatives : t list -> (string * int) list -> (string * int) list
  (** [representatives rhos letters] is the least of each class of the names
      [letters], each with its cost and listed in increasing order, under an
      equivalence of names of equal cost for which the languages of [rhos] are
      saturated: a run of one of them stays in it when a name is replaced by an
      equivalent one. The classes are listed in increasing order. *)
end

(** The three grades over the regular trace grade [L], named
    ["regex-cost-lower-bound"], ["regex-cost-upper-bound"] and
    ["regex-cost-interval"], each followed by [Variant.suffix].

    The letters of a comparison are [tick] and the classes of the names of its
    closed world, of equal costs, of {!LANGUAGE.representatives}, each class
    stood for by its least name. [ρ ≾ ρ'] is decided by breadth-first search of
    the product of the automaton {!LANGUAGE.runs} of [ρ] with an automaton of
    the closure of the automaton {!LANGUAGE.runs} of [ρ'], over these letters,
    {!CostClosure.Allowance} under the upper order and {!CostClosure.Coverage}
    under the lower order, both explored only as far as the search needs. The
    searches are tabulated by the least names of the classes, their costs and
    the representations of the grades compared ({!Grade.S.compare} and
    {!Grade.S.hash} of [L]), and the automata {!LANGUAGE.runs} by the least
    names and the representation of the grade, in module-level tables that only
    ever grow. A grade is the top if its representation is that of the top and
    otherwise iff the search decides [⊤ ≾ ρ], since grades of other
    representations may be equivalent to the top; [compare] and [hash] are those
    of [L], componentwise for the intervals. A grade is {!Grade.S.inhabited} iff
    {!LANGUAGE.runs} accepts some word, over the classes of its names of any
    cost, and its runtime bounds are read off {!LANGUAGE.runs} over the classes
    of the costs read ({!CostClosure.Weights}). The searches, the closures and
    the weights take the runs of ticks of the automata {!LANGUAGE.runs} of the
    derivatives in one step each ({!Dfa.automaton}); over {!Automata}, every
    tick is a transition. *)
module Make
    (L : LANGUAGE)
    (Variant : sig
      val suffix : string
    end) : sig
  (** Lower bounds, in the coverage order at [lo]. *)
  module Lower : Grade.S with type t = L.t and type Delay.t = Delay.Nat.t

  (** Upper bounds, in the allowance order at [hi]. *)
  module Upper : Grade.S with type t = L.t and type Delay.t = Delay.Nat.t

  (** Pairs of a lower and an upper bound, compared componentwise, written
      [({...}, {...})]; a brace literal [{...}] abbreviates the pair of a
      language with itself, [n] the pair [({n}, {n})] and [(n, m)] the pair
      [({n}, {m})]. *)
  module Interval :
    Grade.S with type t = L.t * L.t and type Delay.t = Delay.Nat.t
end

module Automata : LANGUAGE with type t = RegularTraceGrade.t
(** {!RegularTraceGrade}, the automata {!LANGUAGE.runs} being the tables
    {!LANGUAGE.concrete}, of leads [0], and every name a class of its own. *)

module Derivatives : LANGUAGE with type t = RegularTraceGradeDerivative.t
(** {!RegularTraceGradeDerivative}, the automata {!LANGUAGE.runs} being those of
    the derivatives {!RegularTraceGradeDerivative.runs}, and the tables
    {!LANGUAGE.concrete} {!RegularTraceGradeDerivative.concrete}, built from the
    automaton of the derivatives by minterms.

    The classes of {!LANGUAGE.representatives} are the minterms of the Boolean
    algebra generated by the letter sets of the grades, [{tick}] and the level
    sets of the cost, the sets of the names of equal cost, as the minterms of
    RE# (Varatalu, Veanes and Ernits, POPL 2025): two names are equivalent iff
    they have equal cost and lie in the same minterms of the letter sets. A
    comparison thus steps its grades by one derivative per class, and its
    closures and weights by one letter per class, however many operations are
    declared; the derivative by the least name of a class is that by any other.

    Correctness: let [~] be this equivalence over the names of a comparison of
    [L] with [M], extended to runs letter by letter, and [h] the map of each
    name to the least of its class. [L] and [M] are saturated for [~], and so
    are [↓M] and [↑M]: if [u ≼ᵃ t] with [t ∈ M] then [h(u) ≼ᵃ h(t)], [h] keeping
    weights and matched operations, and conversely [h(u) ≼ᵃ t] with [t ∈ M]
    gives [u ≼ᵃ t'], [t'] being [t] with each operation matched to one of [u]
    replaced by it, which is in [M] as [t' ~ t]; likewise for [≼ᶜ]. Hence
    [L ⊆ ↓M] iff every run of [L] over the least names is in the closure of the
    runs of [M] over the least names, and a shortest run of [L] outside [↓M]
    stays one under [h], which does not increase it in the order of the letters:
    the least of them is over the least names, and is the one the search over
    the classes finds. Likewise for [↑M]. *)

module ConcreteDerivatives :
  LANGUAGE with type t = RegularTraceGradeDerivative.Concrete.t
(** {!RegularTraceGradeDerivative.Concrete}, as {!Derivatives}, the tables
    {!LANGUAGE.concrete} being built from the automaton of the derivatives by
    concrete letters, and every name a class of its own. *)

module PlainDerivatives : LANGUAGE with type t = RegularTraceGradePlain.t
(** {!RegularTraceGradePlain}, the automata {!LANGUAGE.runs} being those of the
    derivatives {!RegularTraceGradePlain.runs}, the tables {!LANGUAGE.concrete}
    their exploration in full, and every name a class of its own. *)

(** ["regex-cost-lower-bound"], over {!Automata}. *)
module Lower :
  Grade.S with type t = RegularTraceGrade.t and type Delay.t = Delay.Nat.t

(** ["regex-cost-upper-bound"], over {!Automata}. *)
module Upper :
  Grade.S with type t = RegularTraceGrade.t and type Delay.t = Delay.Nat.t

(** ["regex-cost-interval"], over {!Automata}. *)
module Interval :
  Grade.S
    with type t = RegularTraceGrade.t * RegularTraceGrade.t
     and type Delay.t = Delay.Nat.t

(** The grades over {!Derivatives}, named ["regex-cost-lower-bound-symbolic"],
    ["regex-cost-upper-bound-symbolic"] and ["regex-cost-interval-symbolic"]:
    both grades of a comparison are explored by derivatives, by the minterms of
    their letter sets and costs. *)
module Symbolic : sig
  module Lower :
    Grade.S
      with type t = RegularTraceGradeDerivative.t
       and type Delay.t = Delay.Nat.t

  module Upper :
    Grade.S
      with type t = RegularTraceGradeDerivative.t
       and type Delay.t = Delay.Nat.t

  module Interval :
    Grade.S
      with type t =
        RegularTraceGradeDerivative.t * RegularTraceGradeDerivative.t
       and type Delay.t = Delay.Nat.t
end

(** The grades over {!ConcreteDerivatives}, named
    ["regex-cost-lower-bound-derivatives"],
    ["regex-cost-upper-bound-derivatives"] and
    ["regex-cost-interval-derivatives"]: {!Symbolic} with derivatives and
    closures by letters in place of minterms. *)
module Concrete : sig
  module Lower :
    Grade.S
      with type t = RegularTraceGradeDerivative.t
       and type Delay.t = Delay.Nat.t

  module Upper :
    Grade.S
      with type t = RegularTraceGradeDerivative.t
       and type Delay.t = Delay.Nat.t

  module Interval :
    Grade.S
      with type t =
        RegularTraceGradeDerivative.t * RegularTraceGradeDerivative.t
       and type Delay.t = Delay.Nat.t
end

(** The grades over {!PlainDerivatives}, named ["regex-cost-lower-bound-plain"],
    ["regex-cost-upper-bound-plain"] and ["regex-cost-interval-plain"]:
    {!Concrete} with single letters in place of letter sets. *)
module Plain : sig
  module Lower :
    Grade.S
      with type t = RegularTraceGradePlain.t
       and type Delay.t = Delay.Nat.t

  module Upper :
    Grade.S
      with type t = RegularTraceGradePlain.t
       and type Delay.t = Delay.Nat.t

  module Interval :
    Grade.S
      with type t = RegularTraceGradePlain.t * RegularTraceGradePlain.t
       and type Delay.t = Delay.Nat.t
end
