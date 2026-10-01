(** Inclusion of timed regular languages in the closures of others under the
    allowance and coverage orders of timed traces, over rational delays and
    rational costs.

    {2 Orders}

    A timed word ({!DelayAutomaton}) is written in gap form [d₀ a₁ d₁ ⋯ aₙ dₙ].
    Every operation [a] has a cost [c(a) ≥ 0]; the duration of a word is the sum
    of its delays, and its weight the sum of its delays and of the costs of its
    operations. A cost is an extremal value (see below): the supremum of the
    durations of the operation under the allowance order and their infimum under
    the coverage order, attained or not; a word is permitted, or covers, iff it
    does at every duration of each of its operations. As in {!CostClosure}, over
    whole time steps, a run [s] is permitted by a bound [t], [s ≼ᵃ t], iff they
    factor as [s = s₀ o₁ s₁ ⋯ oₙ sₙ] and [t = t₀ o₁ t₁ ⋯ oₙ tₙ], the operations
    [oᵢ] matched, such that the weight of each [sᵢ] is at most the duration of
    [tᵢ]; and a run [t] covers a guarantee [s], [s ≼ᶜ t], iff they so factor
    with each [sᵢ] a delay at most the weight of [tᵢ]. The downward closure of a
    language [M] is [↓M = {s | s ≼ᵃ t for some t ∈ M}] and its upward closure
    [↑M = {s | t ≼ᶜ s for some t ∈ M}]. Neither is in general a timed regular
    language: with [c(A) = 1], the words [d A e] of [↓{3}] are those with
    [d + 1 + e ≤ 3], which no automaton over finitely many sets of delays tells
    apart for every [d]. Inclusion in a closure is therefore decided relative to
    the language included.

    {2 Extremal values}

    Both closures are monotone in each single delay: [↓M] is closed under
    decreasing a delay of a word, and [↑M] under increasing one. So a path of an
    automaton of [L] has a word outside [↓M] iff its words whose delays approach
    the suprema of the sets of delays read are eventually outside [↓M], and
    dually for [↑M] with the infima. A supremum is kept as an extremal value: a
    rational, attained or approached from below only, or infinity
    ({!DelaySet.extremum}); a sum of values is approached from below iff one of
    its summands is. The costs of the operations of a word of [L] enter the
    weights as the delays of [L] do, since [↓M] is closed under decreasing a
    cost as well, and [↑M] under increasing one. The value [a] approached from
    below stands for [a - kε], [ε] an infinitesimal, and the flag records
    [k ≥ 1] alone: for every comparison made along a path, a small enough [ε]
    makes the comparisons of the words [a - kε] agree with those of the flags.
    Dually for infima, approached from above.

    {2 Readers}

    [↓M] is recognised by a deterministic reader whose configuration maps each
    gap state [q] of the automaton of [M] to the least weight read since the
    last matched operation along the factorisations that lead [M] to [q]: a
    delay adds to every weight; an operation [a] adds [c(a)] to every weight
    (the operation bought) and sets to [0] every state [q'] that [M] enters by
    [a] from a state reachable from some [q] with a weight within the durations
    of [M] from [q] to it (the operation matched); a configuration is accepting
    iff some weight is within the durations of [M] from its state to a final
    state. The durations from a gap state to an operation state enter only
    through their supremum, a longest path over the extremal values
    (Bellman–Ford, infinity where a cycle of positive weight is on the way). A
    weight that no duration from its state admits is dropped, and one that no
    finite supremum admits, where an infinite one does, is set to infinity, so
    that the configurations reached relative to [L] are finite in number.

    [↑M] is recognised dually: the configuration maps each gap state of [M] to
    the greatest weight read since the last matched operation, every operation
    of the guarantee being matched, so that a segment of the guarantee is a
    single delay of [M]; a weight is set to infinity once it covers every delay
    that [M] reads from its state.

    Inclusion is decided by breadth-first search of the pairs of a state of the
    automaton of [L] and a configuration of the reader, the delays of [L] read
    as their extremal values, for a final state of [L] with a rejecting
    configuration; the path found is concretised by choosing each delay close
    enough to its extremal value, which the reader then rejects in exact
    arithmetic.

    {2 Closed world}

    The operations of a comparison are given as a list of names with their
    costs; a name may stand for a class of names of equal cost that the
    languages compared do not tell apart, as in {!RegularCostTraceGrades}. The
    words considered, of [L] and of [M], perform only these operations. *)

type world = (string * DelaySet.extremum) list
(** The operations of a comparison, each name with its cost, finite and
    non-negative: the supremum of its durations in {!allowance}, {!permits} and
    {!max_weight}, and their infimum in {!coverage}, {!covers} and
    {!min_weight}. *)

val allowance :
  world ->
  DelayAutomaton.t ->
  DelayAutomaton.t ->
  DelayAutomaton.symbol list option
(** [allowance world l m] is [None] if every word of [l] over [world] is in
    [↓m], and otherwise such a word outside [↓m], in gap form, its operations
    single names of [world], shortest in its number of symbols. The results are
    tabulated by the arguments in a module-level table that only ever grows. *)

val coverage :
  world ->
  DelayAutomaton.t ->
  DelayAutomaton.t ->
  DelayAutomaton.symbol list option
(** [coverage world l m] is [None] if every word of [l] over [world] is in [↑m],
    and otherwise such a word outside [↑m], as {!allowance}. *)

val permits : world -> DelayAutomaton.t -> DelayAutomaton.symbol list -> bool
(** [permits world m w] is whether the word [w], its operations single names of
    [world], is in [↓m], by the reader of [↓m] in exact arithmetic. *)

val covers : world -> DelayAutomaton.t -> DelayAutomaton.symbol list -> bool
(** [covers world m w] is whether the word [w], its operations single names of
    [world], is in [↑m], by the reader of [↑m] in exact arithmetic. *)

val max_weight : world -> DelayAutomaton.t -> (Rational.t * bool) option
(** [max_weight world l] is the supremum of the weights of the words of [l] over
    [world] and whether it is attained, [None] if [l] has none or their weights
    are unbounded; a longest path from the start to a final state over the
    suprema of the sets of delays and the costs, by Bellman–Ford. *)

val min_weight : world -> DelayAutomaton.t -> (Rational.t * bool) option
(** [min_weight world l] is the infimum of the weights of the words of [l] over
    [world] and whether it is attained, [None] if [l] has none; a shortest path
    over the infima of the sets of delays and the costs, by Bellman–Ford. *)

val inhabited : world -> DelayAutomaton.t -> bool
(** [inhabited world l] is whether [l] has a word over [world]. *)
