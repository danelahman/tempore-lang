(** The regular trace grade, ["regular-traces"], decided by symbolic
    derivatives.

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
    grades. Grades denoting the same language need not have the same normal
    form, and are then printed differently.

    {2 Printing}

    A grade is printed as its normal form in the literal syntax, the top as [⊤],
    runs of ticks as integers, the empty word as [0], and letter sets as unions
    of letters or as [_ & ~(…)]; a group ending with a repetition is printed in
    braces rather than parentheses, e.g. [~{_*; Revoke; _*}], so that a printed
    grade can be quoted in a comment. The literal read back denotes the same
    language. *)

include Grade.S

val counterexample : t -> t -> t option
(** [counterexample rho rho'] is [None] if [rho] is included in [rho'], and
    otherwise the grade of a shortest word of [rho] that is not in [rho'], in
    which the catch-all letter, if it occurs, stands for any operation neither
    grade names. *)
