(** The regular trace grade decided by symbolic derivatives,
    ["traces-regex-symbolic"].

    The grade is that of {!RegularTraceGrade}, with the same runs, alphabet,
    order, operations, literals and runtime bounds; only the representation and
    the decision procedures differ.

    {2 Representation}

    A grade is an extended regular expression in the normal form of
    {!SymbolicRegex}: the product is concatenation, the join union, the unit
    [{0}] and the top [_*], each built by a smart constructor without any
    automaton. The letters are [tick] and every operation name, a letter set
    being finite or cofinite in the names, so that the names a grade does not
    mention are all alike to it: this is the catch-all letter of
    {!RegularTraceGrade}, and grades over different names need no alignment.

    {2 Decisions}

    Inclusion [rho ⊆ rho'] is the emptiness of [rho & ~rho'], decided by
    breadth-first exploration of its derivatives by the minterms of its letter
    sets; equality is decided by a bisimulation of the derivatives of both
    grades. {!Grade.S.counterexample} [bounds rho rho'] is the grade of a
    shortest word of [rho & ~rho'], found by the same exploration, in which a
    letter is the least letter of its minterm: [tick], else its least name, else
    the minterm itself, the names neither grade mentions.

    {2 Printing}

    A grade is printed as the smallest, by {!LetterRegex.size}, of three regular
    expressions: the expression of its automaton, the complement of the
    expression of the automaton of its complement, and its normal form, the
    first of these on a tie. The automaton is the canonical form
    {!SymbolicAutomaton.of_regex} of the automaton of its derivatives, and its
    expression is obtained by state elimination ({!SymbolicAutomaton.to_regex});
    both are determined by the language, so that grades denoting the same
    language print alike unless the normal form of one of them is printed. A
    grade with more than 256 derivatives is printed as its normal form. The top
    is printed as [⊤]. The literal read back denotes the same language. *)

include Grade.S with type t = SymbolicRegex.t
