(** The regular trace grade decided by automata,
    ["regex-upper-bound-letter-automata"]: non-empty regular languages of words
    over delays and operations, multiplied by concatenation.

    {!RegularTraceGradeDerivative}, ["regex-upper-bound-symbolic"], implements
    the same grade by symbolic derivatives;
    {!RegularTraceGradeDerivative.Concrete},
    ["regex-upper-bound-symbolic-by-letters"], by derivatives by letters, and
    {!RegularTraceGradePlain}, ["regex-upper-bound-letter-derivatives"], by
    derivatives of expressions over single letters.

    {2 Runs as words}

    A run is read as a word: an operation [o] is the letter [o], and a delay of
    [n] time steps is [n] copies of the letter [tick]. A grade bounds the runs
    permitted from above: a run is permitted iff its word is in the language.
    The order is inclusion, the product concatenation, the join union, the unit
    the language [{ε}] of the empty word and the top the language [Σ*] of all
    words. The top is not absorbing: [{3}] multiplied by [⊤] permits only the
    runs that begin with three time steps.

    {2 Alphabet}

    The letters of a grade are [tick], the operation names it mentions, and one
    catch-all letter standing for every other operation; the wildcard [_] and
    the complement [~] range over this alphabet. When two grades are combined or
    compared, both are read over the union of their names, the catch-all letter
    of each also standing for the names only the other mentions.

    {2 Canonical form}

    A grade keeps only the names its language tells apart from the catch-all
    letter, with the minimal automaton over them in the canonical form of
    {!Dfa}. A delay of [n] time steps is unrolled into [n] transitions: the
    minimal automaton of [tickⁿ] has [n + 2] states, and every construction and
    comparison explores them, as do the closures of the cost-model grades over
    it ({!RegularCostTraceGrades.Automata}). Grades denoting the same language
    thus have equal names and automata, which {!Grade.S.equal},
    {!Grade.S.compare}, {!Grade.S.hash} and {!Grade.S.is_top} read. A grade also
    keeps the normal form of the expression it was built from, by the operations
    of {!RegularTraceGradeDerivative}, for its printing only.

    {2 Counterexamples and printing}

    {!Grade.S.counterexample} [bounds rho rho'] is the grade of a shortest word
    of [rho] not in [rho'], in which the catch-all letter, if it occurs, stands
    for any operation neither grade names. A grade is printed as
    {!RegularTraceGradeDerivative} prints the normal form [e] of its expression,
    within the budget [b], the {!LetterRegex.size} of {!LetterRegex.of_symbolic}
    [e], but from its own automaton, over letter sets whose labels join the
    letters of each transition, the catch-all letter standing for the names not
    mentioned: as the canonical candidate {!SymbolicAutomaton.canonical}
    [~budget:b] of that automaton, and otherwise as [e]. The printing thus falls
    back to [e] iff no canonical candidate of the language costs at most [b],
    which is the case if the automaton has more than [b] states; it takes time
    polynomial in [b] besides that of {!LetterRegex.of_symbolic}. Grades
    denoting the same language print alike unless the printing of one of them
    falls back, and a grade prints as under {!RegularTraceGradeDerivative}
    unless the printing falls back there, which it also does when [e] has more
    than [b] derivatives.

    {2 Witnesses}

    The witnesses of a closed condition, in every implementation, are its
    constants and their pairwise products ({!Grade.sampled}), which are not
    complete.

    {2 Literals}

    A grade is written as a brace literal holding a regular expression: an
    operation name [Read] is that letter, an integer [n] is [n] ticks ([0] the
    empty word), an interval [[n, m]] any number of ticks from [n] to [m] and
    [\[n, ∞)] at least [n], an open endpoint abbreviating a closed one
    ({!Grade.tick_delays}), [_] is any single letter, [;] concatenates, [|] is
    union, [&] intersection, [~] complement and a postfix [*] repetition, e.g.
    [{Read; 3; (Send | Write)* & ~{_; Read}}]. A plain integer [n] abbreviates
    [{n}], and [⊤] (ASCII [top]) is [Σ*]. A literal denoting the empty language
    is rejected, since grades are non-empty.

    {2 Runtime bounds}

    The order does not read the runtime bounds of operations, which therefore
    declare none. {!Grade.S.implied_bounds} is [None]; {!Grade.S.of_bounds}
    [(lo, hi)] is the language of the delays of [lo] to [hi] time steps; the
    events of a grade are its names; and a grade is atomic for [name] iff it is
    the language [{name}]. *)

include Grade.S with type Delay.t = Delay.Nat.t

val concrete : string list -> t -> Dfa.t
(** [concrete names rho] is the language of the runs of [rho] that perform only
    operations among [names], over the letters [tick], numbered [0], and
    [names], numbered from [1] in their order, with no catch-all letter: the
    catch-all letter of [rho] stands for each of [names] that [rho] does not
    mention. *)

val canonical : t -> LetterRegex.t option
(** [canonical rho] is the canonical expression printed for [rho], or [None] if
    the printing of [rho] falls back to its expression. *)
