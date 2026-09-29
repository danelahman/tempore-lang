(** Closures of regular languages of runs under the cost-aware orders of timed
    traces.

    {2 Runs and costs}

    A run is a word over the letters of a {!Dfa}: the letter [0] is a tick and
    every other letter [a] an operation of cost [cost a], a non-negative
    integer. The weight of a word is its number of ticks plus the costs of its
    operations. A letter may stand for a class of operations of equal cost for
    which the language closed is saturated, the closure then being saturated for
    it too ({!RegularCostTraceGrades.Derivatives}): the closures step by one
    letter per class.

    {2 Orders}

    The two orders are those of {!TimedTrace.Make.allowance} and
    {!TimedTrace.Make.coverage} at budget [0], read on words, a delay of [n]
    time steps being [n] ticks. By their segment characterisation, a run [s] is
    permitted by a bound [t], [s ≼ᵃ t], iff they factor as
    [s = s₀ o₁ s₁ ⋯ oₙ sₙ] and [t = t₀ o₁ t₁ ⋯ oₙ tₙ], the operations [oᵢ]
    matched, such that the weight of each [sᵢ] is at most the number of ticks of
    [tᵢ]; and a run [t] covers a guarantee [s], [s ≼ᶜ t], iff they so factor
    with each [sᵢ] a word of ticks whose length is at most the weight of [tᵢ].

    {2 Closures}

    The downward closure of a language [M] is [↓M = {s | s ≼ᵃ t for some t ∈ M}]
    and its upward closure [↑M = {s | t ≼ᶜ s for some t ∈ M}]. Both are regular.
    They are returned as implicit automata over sets of states of an automaton
    of [M], as sorted lists, explored only as far as a search needs; their
    determinisation is exponential in the worst case, as for the closures under
    the scattered-subword order, a special case.

    {2 Runs of ticks}

    A state [y] of lead [k ≥ 1] ({!Dfa.automaton}) has one live successor by a
    word of length at most [k], by [0ʲ]; its {e run} is the sequence of its
    successors by [0ʲ] for [0 < j ≤ k], taken by [leap], [x] lying on it iff [x]
    is the [leap] of [y] by the difference of their leads. The closures are
    automata of lead [0] whose [leap] by [k] reads [k] ticks at once. Over the
    tables of {!Dfa}, whose leads are [0], no state has a run, and the
    representations below are the sets themselves. *)

(** The downward closures of the languages of implicit automata over [letters]
    letters, over sets of their states ordered by [State.compare]. *)
module Allowance (State : Map.OrderedType) : sig
  val closure :
    cost:(int -> int) ->
    letters:int ->
    State.t Dfa.automaton ->
    State.t list Dfa.automaton
  (** [closure ~cost ~letters m] is the automaton of the downward closure [↓m],
      by the construction [D↓]: its states are the sets [S] of states of [m]
      closed under reachability, [S] is final iff it holds a final state of [m],
      and the letter [x] of weight [w] leads from [S] to the states reachable
      from [S] by a word with at least [w] ticks (buying [x]), together with, if
      [x] is an operation, the states reachable from the successors of [S] by
      [x] (matching [x]). The closure is prefix-closed, and all sets without a
      final state, which reject every word, are the empty set, the one dead
      state.

      The sets hold only live states: [dead] must hold exactly of the states of
      [m] from which no final state is reachable. A set [S] is represented by
      its states that lie strictly within the run of no other state of [S]: the
      states reached from them, a state of lead [k ≥ 1] followed by its [leap]
      by [k] alone, less those within the run of another. [S] is the set of the
      states reachable from its representation, and the representation is
      determined by [S]. The states within a run are not final, so that [S] is
      final iff its representation holds a final state.

      Buying [x] follows the descending chain of the sets reached with at least
      [0, 1, 2, …] ticks, each reached from the successors by [0] of the last,
      until [w] or until it is stationary, so that large costs are cheap. The
      states of the representation without a live successor by [0] leave the
      chain, those that are their own successor by [0] stay, and where the
      others all have leads of at least [k ≥ 1] the chain moves on [min w k]
      ticks at once, by their [leap]s. Matching [x] takes the successors by [x]
      of the states of lead [0] of the representation, the others having no live
      successor by [x]. *)
end

val allowance : cost:(int -> int) -> Dfa.t -> int list Dfa.automaton
(** [allowance ~cost m] is {!Allowance.closure} over the table of [m]. *)

(** The upward closures of the languages of implicit automata, over sets of
    their states ordered by [State.compare]. *)
module Coverage (State : Map.OrderedType) : sig
  val closure :
    cost:(int -> int) -> State.t Dfa.automaton -> State.t list Dfa.automaton
  (** [closure ~cost m] is the automaton of the upward closure [↑m], by the
      subset construction of the non-deterministic automaton over the states of
      [m] in which the letter [y] of weight [w] leads from [q] to the successors
      of [q] by [j] ticks for every [j ≤ w] (banking [y] towards a delay of
      [m]), and, if [y] is an operation, to the successor of [q] by [y]
      (matching [y]). The states of [m] are explored only as far as the closure
      is. The closure is a right ideal, and a set with a final state, which
      accepts every word, is its own successor; a set is dead if all its states
      are dead in [m].

      Over the automaton of the derivatives of an expression, this is the
      derivative of the closure: the derivative of the closure of the union of a
      set [S] of expressions by [y] is the closure of the union of the
      derivatives of the members of [S] by [j] ticks for [j ≤ w] and, if [y] is
      an operation, by [y].

      As [↑(0 L) ⊆ ↑L], a state whose run holds another state of the set is left
      out of it: a set is represented by its states on whose run no other state
      of the set lies, the end included, and the representation denotes the same
      closure and is determined by the set. The successors of a state [q] of
      lead [k ≥ 1] by [j ≤ min w k] ticks are thus represented by that by
      [min w k] alone, taken by the [leap] of [q]. *)
end

val coverage : cost:(int -> int) -> Dfa.t -> int list Dfa.automaton
(** [coverage ~cost m] is {!Coverage.closure} over the table of [m]. *)

(** The least and greatest weights of the words of implicit automata over
    [letters] letters, over their states ordered by [State.compare], by
    Bellman–Ford relaxation over the graph of the live states reachable from the
    start, in which a state of lead [k ≥ 1] has one edge, of weight [k], to its
    [leap] by [k]. *)
module Weights (State : Map.OrderedType) : sig
  val min_weight :
    cost:(int -> int) -> letters:int -> State.t Dfa.automaton -> int option
  (** [min_weight ~cost ~letters m] is the least weight of a word of [m], or
      [None] if [m] is empty. *)

  val max_weight :
    cost:(int -> int) -> letters:int -> State.t Dfa.automaton -> int option
  (** [max_weight ~cost ~letters m] is the greatest weight of a word of [m], or
      [None] if [m] is empty or its words have unbounded weights, i.e. a cycle
      of positive weight lies on a path to a final state, the weights of the
      words of [m] being unbounded iff the relaxation has not stabilised after
      as many rounds as the graph has states. *)
end

val min_weight : cost:(int -> int) -> Dfa.t -> int option
(** [min_weight ~cost m] is {!Weights.min_weight} over the table of [m]. *)

val max_weight : cost:(int -> int) -> Dfa.t -> int option
(** [max_weight ~cost m] is {!Weights.max_weight} over the table of [m]. *)
