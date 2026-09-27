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

val next : t -> int -> Letters.t -> int
(** [next a q p] is the target of the edge out of the state [q] of [a] whose
    label meets the letter set [p], which lies within one label, e.g. a single
    letter. *)

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
    [limit] derivatives up to the normal form, the exploration stopping as soon
    as it finds them: their number is bounded by no elementary function of the
    size of [r]. *)

val of_derivatives :
  limit:int -> blocks:Letters.t list -> SymbolicRegex.t -> t option
(** [of_derivatives ~limit ~blocks r] is as [of_regex ~limit r], the derivatives
    being explored by the blocks of [blocks], a partition of the letters into
    non-empty sets that every letter set occurring in [r] respects. *)

val complement : t -> t
(** [complement a] is the automaton of the complement of the language of [a],
    whose final states are the other states of [a]. *)

val reverse : limit:int -> t -> t option
(** [reverse ~limit a] is the canonical form of the automaton of the reversal of
    the language of [a], the words of [a] read backwards, by Brzozowski's
    reversal: the subset construction on the reverse of [a], whose states are
    the sets of states of [a] from which the words read so far, reversed, lead
    to a final state. As [a] is deterministic and its states reachable, these
    sets are as many as the states of the minimal automaton of the reversal. It
    is [None] if there are more than [limit] of them, the construction stopping
    as soon as it finds them. *)

(** {1 State elimination} *)

val to_regex : budget:int -> t -> LetterRegex.t option
(** [to_regex ~budget a] is a regular expression for the language of [a],
    obtained by state elimination (Brzozowski and McCluskey): the states from
    which no final state is reachable are dropped, a source and a sink are
    joined to the start and from the final states by the empty word, and the
    other states are eliminated one by one, each time the one with the fewest
    paths through it, the lowest-numbered of those with equally few; the paths
    through a state [q] become edges [x; y*; z], [y] the label of the loop at
    [q]. The labels are letter sets and the expressions built of them by the
    smart constructors of {!LetterRegex}. The elimination {e uses} the labels of
    the edges into, out of and looping at each state it eliminates, and the
    final label of the edge from the source to the sink, which is the
    expression. The expression is thus determined by the automaton, and so by
    the language.

    It is [None] if a label used has a {!LetterRegex.size} greater than
    [budget], the elimination stopping at the first state whose labels do: each
    label then has size at most [budget], and each edge at most one alternative
    per state eliminated, so that the time is polynomial in [budget] and the
    number of states of [a]. *)

(** {1 Printing}

    The regular trace grades print a language by one of three expressions
    determined by the language, its {e canonical candidates}, with [A] its
    automaton and [Aᴿ] that of its reversal ({!reverse}):

    + the expression of [A] by state elimination ({!to_regex});
    + the complement [~r] of the expression [r] of the automaton of the
      complement ({!complement});
    + the reversal ({!LetterRegex.reverse}) of the expression of [Aᴿ].

    The {e cost} of a candidate is the largest of the number of states of the
    automata it is computed from ([A] for the first two, [A] and [Aᴿ] for the
    third), the sizes of the labels its elimination uses and its own
    {!LetterRegex.size}; it is at least the size of the candidate. Every part of
    the cost is determined by the language, and so is the cost. *)

val canonical : budget:int -> t -> LetterRegex.t option
(** [canonical ~budget a] is the canonical candidate of the language of [a] of
    least cost, then of least size, then first in the order above, among those
    of cost at most [budget]; it is [None] if there is none. The computation of
    a candidate stops as soon as its cost exceeds [budget] ({!reverse},
    {!to_regex}), and none is computed if [a] has more than [budget] states, so
    that the time is polynomial in [budget].

    As the candidates within the budget are exactly those of cost at most
    [budget], a set that grows with [budget], the candidate chosen, when there
    is one, is the same for every budget: the candidate of least cost, size and
    position. The expressions [canonical ~budget a] and [canonical ~budget' a']
    for automata [a] and [a'] of the same language are thus equal whenever
    neither is [None]. *)
