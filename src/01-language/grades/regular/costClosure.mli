(** Closures of regular languages of runs under the cost-aware orders of timed
    traces.

    {2 Runs and costs}

    A run is a word over the letters of a {!Dfa}: the letter [0] is a tick and
    every other letter [a] an operation of cost [cost a], a non-negative
    integer. The weight of a word is its number of ticks plus the costs of its
    operations.

    {2 Orders}

    The two orders are those of {!TimedTrace.allowance} and
    {!TimedTrace.coverage} at budget [0], read on words, a delay of [n] time
    steps being [n] ticks. By their segment characterisation, a run [s] is
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
    determinisation is exponential in the worst case. *)

val allowance : cost:(int -> int) -> Dfa.t -> int list Dfa.automaton
(** [allowance ~cost m] is the automaton of the downward closure [↓m], by the
    construction [D↓]: its states are the sets [S] of states of [m] closed under
    reachability, the start is the set of the states reachable from the start of
    [m], [S] is final iff it holds a final state of [m], and the letter [x] of
    weight [w] leads from [S] to the states reachable from [S] by a word with at
    least [w] ticks (buying [x]), together with, if [x] is an operation, the
    states reachable from the successors of [S] by [x] (matching [x]). The chain
    of the states reachable with at least [0, 1, 2, …] ticks is descending, and
    is followed only until it is stationary, so that large costs are cheap. The
    closure is prefix-closed, and all sets without a final state, which reject
    every word, are the empty set, the one dead state. *)

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
      an operation, by [y]. *)
end

val coverage : cost:(int -> int) -> Dfa.t -> int list Dfa.automaton
(** [coverage ~cost m] is {!Coverage.closure} over the table of [m]. *)

val min_weight : cost:(int -> int) -> Dfa.t -> int option
(** [min_weight ~cost m] is the least weight of a word of [m], or [None] if [m]
    is empty, by Bellman–Ford relaxation. *)

val max_weight : cost:(int -> int) -> Dfa.t -> int option
(** [max_weight ~cost m] is the greatest weight of a word of [m], or [None] if
    [m] is empty or its words have unbounded weights, i.e. a cycle of positive
    weight lies on a path to a final state, by Bellman–Ford relaxation, the
    weights of the words of [m] being unbounded iff it has not stabilised after
    as many rounds as [m] has states. *)
