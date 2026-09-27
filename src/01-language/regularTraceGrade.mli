(** The regular trace grade, ["regular-traces"]: non-empty regular languages of
    words over delays and operations, multiplied by concatenation.

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
    {!Dfa}. Grades denoting the same language are thus structurally equal.

    {2 Literals}

    A grade is written as a brace literal holding a regular expression: an
    operation name [Read] is that letter, an integer [n] is [n] ticks ([0] the
    empty word), [_] is any single letter, [;] concatenates, [|] is union, [&]
    intersection, [~] complement and a postfix [*] repetition, e.g.
    [{Read; 3; (Send | Write)* & ~{_; Read}}]. A plain integer [n] abbreviates
    [{n}], and [⊤] (ASCII [top]) is [Σ*]. A literal denoting the empty language
    is rejected, since grades are non-empty.

    {2 Runtime bounds}

    The order does not read the runtime bounds of operations, which therefore
    declare none. {!Grade.S.implied_bounds} is [None]; {!Grade.S.of_bounds}
    [(lo, hi)] is the language of the delays of [lo] to [hi] time steps; the
    events of a grade are its names; and a grade is atomic for [name] iff it is
    the language [{name}]. *)

include Grade.S

val counterexample : t -> t -> t option
(** [counterexample rho rho'] is [None] if [rho] is included in [rho'], and
    otherwise the grade of a shortest word of [rho] that is not in [rho'], in
    which the catch-all letter, if it occurs, stands for any operation neither
    grade names. *)
