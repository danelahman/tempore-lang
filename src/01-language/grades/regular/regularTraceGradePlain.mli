(** The regular trace grade decided by plain derivatives,
    ["regex-upper-bound-letter-derivatives"]:
    {!RegularTraceGradeDerivative.Concrete} with single letters in place of
    letter sets.

    The grade is that of {!RegularTraceGrade}, with the same runs, alphabet,
    order, operations, literals, runtime bounds and printing; only the
    representation and the decision procedures differ.

    {2 Representation}

    A grade is a finite set [N] of names and an extended regular expression over
    single letters, in the normal form of {!SymbolicRegex.Make} [(Atoms)]:
    [tick], the names of [N], and one catch-all letter standing for every name
    not in [N], as in {!RegularTraceGrade}. [N] is the set of the names a
    literal mentions, the wildcard [_] being the union of these letters, and
    [Σ*] is [~∅]. When two grades are combined or compared, both are expressed
    over the union of their names, the catch-all letter of each being replaced
    by the union of the catch-all letter over the union and the names only the
    other grade has. {!Grade.S.compare} and {!Grade.S.hash} read [N] and the
    number of the normal form; grades of different representations may denote
    the same language, so {!Grade.S.is_top} is decided by inclusion.

    {2 Decisions}

    Inclusion, equality and counterexamples are decided as in
    {!RegularTraceGradeDerivative.Concrete}, by the derivatives by the concrete
    letters of the expressions compared, {!SymbolicRegex.S.Concrete}, runs of
    ticks taken in one step; in a counterexample, the catch-all letter stands
    for the names neither grade has.

    {2 Printing}

    A grade is printed, and its events read off, as the grade of
    {!RegularTraceGradeDerivative} of its expression rebuilt over letter sets by
    the smart constructors of {!SymbolicRegex}, each letter being the letter set
    of its letters. The normal form rebuilt, and so the budget of the printing,
    may differ from that of the same literal read by
    {!RegularTraceGradeDerivative}: the two print a grade alike unless the
    printing of one of them falls back. *)

include Grade.S with type Delay.t = Delay.Nat.t

module Regex : SymbolicRegex.S
(** The expressions over single letters. *)

val concrete : string list -> t -> Dfa.t
(** [concrete names rho] is the language of the runs of [rho] that perform only
    operations among [names], as {!RegularTraceGrade.concrete}: the automaton
    {!runs}, explored in full. *)

val runs : string list -> t -> Regex.t Dfa.automaton
(** [runs names rho] is the automaton of the same language over the same
    letters, explored lazily: its states are the normal forms of the derivatives
    of the expression of [rho] by these letters, each name not of [rho] acting
    as its catch-all letter, the final ones the nullable ones, the dead ones the
    empty ones, and the leads and leaps those of {!SymbolicRegex.S.lead} and
    {!SymbolicRegex.S.leap}. *)

val canonical : t -> LetterRegex.t option
(** [canonical rho] is the canonical expression printed for [rho], or [None] if
    the printing of [rho] falls back to its normal form. *)
