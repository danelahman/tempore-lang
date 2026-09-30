(** The regular trace grade over rational delays,
    ["regex-upper-bound-rational"]: non-empty timed regular languages, ordered
    by inclusion and multiplied by concatenation.

    {2 Runs as timed words}

    A run is read as a timed word ({!TimedAutomaton}): its operations, and its
    delays as non-negative rationals, adjacent delays added. A grade bounds the
    runs permitted from above: a run is permitted iff its timed word is in the
    language. The order is inclusion, the product concatenation, which adds the
    delays that meet, the join union, the unit the language [{ε}] of the empty
    word, i.e. of the delay [0], and the top the language of all timed words.
    The top is not absorbing: [{3}] multiplied by [⊤] permits only the runs that
    begin with a delay of at least [3].

    Unlike {!RegularTraceGrade}, a delay is a single letter however long or
    fine: no delay is unrolled into time steps, and no resolution of the
    program's delays is involved, so that the order is exact over the rationals.

    {2 Literals}

    A grade is written as a brace literal holding a timed regular expression
    ({!TimedRegex}): an operation name [Read], a delay such as [3], [1/2] or
    [1.5], a comparison [<q], [<=q] ([≤q]), [>q] or [>=q] ([≥q]) denoting the
    delays below, up to, above or from [q], and [_], every operation and every
    positive delay, combined with [;], [|], [&], [~] and [*], e.g.
    [{Read; (>0 & <1/2); Send | ~Write}]. The complement is taken over all timed
    words: [~1] permits every run but the delay [1]. A plain number [q]
    abbreviates [{q}], and [⊤] (ASCII [top]) is [_*]. A literal denoting the
    empty language, or a negative delay, is rejected.

    {2 Representation and decisions}

    A grade keeps the canonical automaton of its language, which
    {!Grade.S.equal}, {!Grade.S.compare}, {!Grade.S.hash} and {!Grade.S.is_top}
    read, and the expression it was written as, or built as by products and
    joins, which the printing reads. Inclusion is decided on the product of the
    automata, and {!Grade.S.counterexample} [bounds rho rho'] is the grade of a
    word of [rho] not in [rho'] with the fewest operations
    ({!TimedAutomaton.counterexample}), its delays the simplest rationals of the
    sets of delays they are chosen from, and an operation no grade names written
    as [_ & ~(>0 | …)].

    {2 Printing}

    A grade is printed as the expression it was written or built as, [⊤] if it
    denotes all timed words. The expression of a product is the concatenation of
    the factors of both operands, the delays [0] left out and adjacent delays
    added, and that of a product with the unit or of a join with a grade below
    is the other operand's. The printing reads back as the same grade, but
    grades denoting the same language may print differently.

    {2 Witnesses}

    The witnesses of a closed condition are its constants and their pairwise
    products ({!Grade.sampled}), which are not complete.

    {2 Runtime bounds}

    The order does not read the runtime bounds of operations, which therefore
    declare none. {!Grade.S.implied_bounds} is [None]; {!Grade.S.of_bounds}
    [(lo, hi)] is the language of the delays from [lo] to [hi]; the events of a
    grade are the names its automaton tells apart from the others; and a grade
    is atomic for [name] iff it is the language [{name}]. *)

include Grade.S with type Delay.t = Delay.Rational.t

val automaton : t -> TimedAutomaton.t
(** [automaton rho] is the language of [rho]. *)
