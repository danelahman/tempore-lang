(** Run consistency of a guarantee and an allowance given as graphs in gap form
    ({!DelayTimedClosure.type-graph}), over rational delays and running times.

    {2 Statement}

    A guarantee [L] and an allowance [U] are consistent when some trace [x]
    covers a word [p] of [L] and is permitted by a word [q] of [U],
    [p ≼ᶜ x ≼ᵃ q], each operation of [x] running for its lower running time in
    the coverage order and for its upper running time in the allowance order
    ({!DelayTimedClosure}). For single traces this is decided by the joint walk
    of {!TimedTrace.Make.consistent}, which carries the slack [k] of the
    coverage order and the budget [b] of the allowance order. Its moves are
    those of [U] alone (a delay banked as budget; an operation skipped, or
    performed, the budget and its lower running time turned into slack), those
    of [L] alone (a delay spent from the slack, topped up from the budget; an
    operation paid from the budget at its upper running time), and an operation
    both name, which resets both. A state [(k', b')] is at least as good as
    [(k, b)] if [b ≤ b'] and [k + b ≤ k' + b'].

    {2 Procedure}

    The walk is lifted to the two graphs: its states are a node of each graph
    and a Pareto antichain of pairs [(k, b)] under the order above. Every delay
    of [L] is read as the infimum of its set of delays, a demand, and every
    delay of [U] as the supremum of its set, a resource; both are extremal
    values ({!DelaySet.extremum}), a demand met by a resource iff it is less, or
    equal with both attained, as in the bounds of difference-bound matrices.

    The moves of [U] between two moves of [L] are summarised by longest paths
    over the graph of [U] ({!DelayTimedClosure.longest}, infinite through a
    cycle of positive weight): from [(k, b)] at the node [m], the node [m'] is
    reached with [(k, b + B(m, m'))], every delay banked and every operation
    skipped, and, for each transition [v -a-> v'] of an operation, the last one
    performed, with [(k + b + T(m, v) + lo(a), B(v', m'))], [T] weighing the
    operations by their lower running times, every operation before it
    performed.

    The search proceeds in rounds, a round taking one move of [L] from the pairs
    added in the previous one, and stops when a final node of [L] is reached or
    a round adds no pair that is not below one already found. It terminates
    since a cycle of [L] never helps: removing it from a walk, and turning the
    operations it matches into skips of [U], gives a walk whose pairs are at
    least as good at every node after it, the moves of [U] acting alike on both,
    the moves of [L] only lowering the pairs of the original, and a match
    resetting them to [(0, 0)]. Every pair is thus below one found along a path
    of [L] without a repeated node, within as many rounds as [L] has nodes. *)

val consistent :
  lo:DelayTimedClosure.world ->
  hi:DelayTimedClosure.world ->
  DelayTimedClosure.graph ->
  DelayTimedClosure.graph ->
  bool
(** [consistent ~lo ~hi l u] is whether some trace covers a word of [l], its
    operations running for their running times in [lo], and is permitted by a
    word of [u], its operations running for their running times in [hi]. The
    worlds [lo] and [hi] list the same names, the graphs are over them, and the
    running times are finite and attained, each in [lo] at most that in [hi]. *)
