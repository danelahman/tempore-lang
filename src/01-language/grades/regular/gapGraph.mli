(** The automata of the symbolic regular expressions in gap form, over the names
    of a comparison: the automata of their gap derivatives.

    A trace over whole time steps is a word in gap form [tickᵈ⁰ a₁ ⋯ aₖ tickᵈᵏ],
    its delays integers, as a timed word of {!DelayTimedClosure}. The graph of
    an expression [ρ] over a list of names has the expressions reached from [ρ]
    by the gap derivatives by these names ({!SymbolicRegex.S.gap_derivative}) as
    its gap states, [ρ] the start. A gap state [r] has, for each name [a] and
    each pair [(S, e)] of the gap derivative of [r] by [a], a transition by the
    set of delays [S] to an operation state whose one transition, by [a], leads
    to [e]; and, if its delays [N(r)] ({!SymbolicRegex.S.delays}) are not empty,
    a transition by [N(r)] to a final operation state without transitions. The
    graph thus recognises the traces of [ρ] over the names, and has finitely
    many states, by the finiteness of the derivatives, whatever the delays of
    [ρ]. *)

val graph : string list -> SymbolicRegex.t -> DelayTimedClosure.graph
(** [graph names rho] is the graph of [rho] over [names], explored in full,
    breadth-first from [rho]. *)
