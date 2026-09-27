(** Minimal deterministic automata over letter sets, in canonical form, and
    their regular expressions by state elimination.

    {2 Canonical form}

    An automaton is complete and deterministic: the edges out of a state are
    labelled by non-empty, pairwise disjoint letter sets covering all letters,
    one edge per target, the label of an edge being the set of all letters that
    lead to its target. The automata this module returns are minimal (Moore
    partition refinement), and their states are numbered in the breadth-first
    order in which they are discovered from the start, the edges out of a state
    being explored in the order {!SymbolicRegex.Letters.order} of their labels;
    state [0] is the start. The minimal automaton of a language, its labels and
    this numbering are determined by the language alone, so that two automata
    denote the same language iff they are equal. *)

module Letters = SymbolicRegex.Letters

type t
(** An automaton in canonical form. *)

val equal : t -> t -> bool
(** [equal a b] is whether [a] and [b] are the same automaton, i.e. denote the
    same language. *)

val states : t -> int
(** [states a] is the number of states of [a]. *)

val final : t -> int -> bool
(** [final a q] is whether the state [q] of [a] is final. *)

val edges : t -> int -> (Letters.t * int) list
(** [edges a q] lists the edges out of the state [q] of [a], each as its label
    and its target, in the order of their labels. *)

(** {1 Constructions} *)

val of_table : final:bool array -> edges:(Letters.t * int) list array -> t
(** [of_table ~final ~edges] is the canonical form of the complete deterministic
    automaton of the states [0], …, [n - 1], [n] the length of both arrays, the
    start [0], the final states those [final] marks, and the edges out of each
    state [q] listed by [edges.(q)]: labels that are non-empty, pairwise
    disjoint and cover all letters, several edges possibly sharing a target.

    @raise Invalid_argument if the arrays are empty or of different lengths. *)

val of_regex : limit:int -> SymbolicRegex.t -> t option
(** [of_regex ~limit r] is the canonical form of the automaton of the
    derivatives of [r]: its states are the normal forms of the derivatives of
    [r] by words, explored breadth-first by the blocks of the minterms of [r],
    the final states the nullable ones. It is [None] if [r] has more than
    [limit] derivatives up to the normal form. *)

val complement : t -> t
(** [complement a] is the automaton of the complement of the language of [a],
    whose final states are the other states of [a]. *)

(** {1 State elimination} *)

val to_regex : t -> LetterRegex.t
(** [to_regex a] is a regular expression for the language of [a], obtained by
    state elimination (Brzozowski and McCluskey): the states from which no final
    state is reachable are dropped, a source and a sink are joined to the start
    and from the final states by the empty word, and the other states are
    eliminated one by one, each time the one with the fewest paths through it,
    the lowest-numbered of those with equally few; the paths through a state [q]
    become edges [x; y*; z], [y] the label of the loop at [q]. The labels are
    letter sets and the expressions built of them by the smart constructors of
    {!LetterRegex}. The expression is thus determined by the automaton, and so
    by the language. *)

(** {1 Printing} *)

val show : others:LetterRegex.t list -> t -> string
(** [show ~others a] prints the language of [a] in the literal syntax of the
    regular trace grade: [⊤] if it has all words, and otherwise, in braces, the
    smallest by {!LetterRegex.size} of {!to_regex} [a], the complement of
    {!to_regex} [(complement a)] and the expressions [others] for the same
    language, the first of these on a tie. *)
