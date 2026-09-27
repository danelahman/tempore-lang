(** Regular languages over the letters [0, …, n - 1], represented by complete
    deterministic finite automata in canonical form.

    {2 Canonical form}

    An automaton is a table: row [q] lists the successors of state [q] in letter
    order, and a flag marks each state final or not; state [0] is the start. The
    automata this module returns are minimal (Moore partition refinement) and
    their states are numbered in the breadth-first order in which they are
    discovered from the start, the letters of a state being explored in
    increasing order. Two automata over the same letters thus denote the same
    language iff their tables are equal.

    Every construction builds its automaton by breadth-first exploration of the
    reachable states only, then minimises it. *)

type t
(** A regular language over a fixed number of letters, in canonical form. *)

val letters : t -> int
(** [letters l] is the number of letters of the alphabet of [l]. *)

val states : t -> int
(** [states l] is the number of states of the minimal automaton of [l]. *)

val equal : t -> t -> bool
(** [equal l m] is whether [l] and [m] are the same language over the same
    alphabet. *)

val compare : t -> t -> int
(** A total order compatible with {!equal}. *)

(** {1 Constructions}

    The binary constructions take two languages over the same alphabet.

    @raise Invalid_argument if the alphabets differ. *)

val empty : int -> t
(** [empty n] is the empty language over [n] letters. *)

val all : int -> t
(** [all n] is the language [Σ*] of all words over [n] letters. *)

val word : int -> int list -> t
(** [word n w] is the language [{w}] over [n] letters. *)

val letter_set : int -> int list -> t
(** [letter_set n s] is the language of the one-letter words [a] with [a] in
    [s], over [n] letters. *)

val union : t -> t -> t
(** [union l m] is [l ∪ m], by the product automaton. *)

val inter : t -> t -> t
(** [inter l m] is [l ∩ m], by the product automaton. *)

val complement : t -> t
(** [complement l] is [Σ* \ l], by flipping the final states. *)

val concat : t -> t -> t
(** [concat l m] is [l · m], by the subset construction: a state pairs a state
    of [l] with the set of states of [m] reached so far. *)

val star : t -> t
(** [star l] is [l*], by the subset construction. *)

val relabel : int -> (int -> int) -> t -> t
(** [relabel n f l] is the language over [n] letters in which each letter [a]
    acts as the letter [f a] of [l]: the words [a₁ … aₖ] such that [f a₁ … f aₖ]
    is in [l].

    @raise Invalid_argument if some [f a] is not a letter of [l]. *)

(** {1 Decisions} *)

val is_empty : t -> bool
(** [is_empty l] is whether [l] has no words. *)

val is_all : t -> bool
(** [is_all l] is whether [l] is [Σ*]. *)

val alike : t -> int -> int -> bool
(** [alike l a b] is whether the letters [a] and [b] are interchangeable in [l]:
    every word of [l] stays in [l] when an occurrence of one is replaced by the
    other. *)

val counterexample : t -> t -> int list option
(** [counterexample l m] is a shortest word in [l] and not in [m], found by
    breadth-first search of the product of [l] with the complement of [m]; it is
    [None] iff [l ⊆ m]. *)

val subset : t -> t -> bool
(** [subset l m] is whether [l ⊆ m]. *)

(** {1 Regular expressions} *)

(** Regular expressions over letter sets, as read off an automaton. *)
type regex =
  | Letters of int list
      (** One letter out of a non-empty set, listed in increasing order *)
  | Seq of regex list  (** Concatenation; [Seq []] is the empty word *)
  | Union of regex list  (** Union; [Union []] is the empty language *)
  | Star of regex  (** Repetition *)

val to_regex : t -> regex
(** [to_regex l] is a regular expression for [l], obtained by state elimination:
    the states that reach no final state are dropped, the transitions between
    two states are labelled by the set of their letters, and the remaining
    states are eliminated fewest paths first. The expression is simplified as it
    is built, so that the languages of single words and of small unions print as
    such. *)
