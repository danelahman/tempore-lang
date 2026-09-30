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

val next : t -> int -> int -> int
(** [next l q a] is the successor of the state [q] of [l] by the letter [a]. *)

val final : t -> int -> bool
(** [final l q] is whether the state [q] of [l] is final. *)

val equal : t -> t -> bool
(** [equal l m] is whether [l] and [m] are the same language over the same
    alphabet. *)

val compare : t -> t -> int
(** A total order compatible with {!equal}. *)

val hash : t -> int
(** A hash compatible with {!equal}. *)

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

(** First-in first-out queues, as a front list and a reversed back list, with
    amortised constant-time operations (Burton, IPL 1982). *)
module Fifo : sig
  type 'a t

  val empty : 'a t
  val push : 'a -> 'a t -> 'a t

  val pop : 'a t -> ('a * 'a t) option
  (** [pop q] is the first element of [q] and the rest, if any. *)
end

(** {1 Implicit automata}

    Deterministic automata given by their start state and transition and
    acceptance functions rather than by a table, their states being explored
    only as needed. The letter [0] is a tick, and an automaton may tell the runs
    of ticks its states begin with, so that a search takes a run of ticks at
    once: from a state [q] of lead [k ≥ 1], every word accepted begins with
    [0ᵏ], so that the words of length at most [k] other than [0ʲ] lead to states
    that accept no word, and [q] and its successors by [0ʲ], [j < k], accept no
    word. *)

type 'state automaton = {
  start : 'state;  (** The start state. *)
  step : 'state -> int -> 'state;
      (** [step q a] is the successor of the state [q] by the letter [a]. *)
  accepts : 'state -> bool;  (** [accepts q] is whether [q] is final. *)
  dead : 'state -> bool;
      (** [dead q] holds only if no final state is reachable from [q]; it need
          not hold of every such state. *)
  lead : 'state -> int;
      (** [lead q] is a number [k] such that every word accepted from [q] begins
          with [0ᵏ], [Int.max_int] only if [q] accepts no word, e.g. [0] if
          unknown. *)
  leap : 'state -> int -> 'state;
      (** [leap q k] is the successor of [q] by the word [0ᵏ], up to the
          language accepted. *)
}
(** A deterministic automaton over the states ['state], which must be finitely
    many from the start, the successors by [leap] included. *)

val unrolled : ('state -> int -> 'state) -> 'state -> int -> 'state
(** [unrolled step q k] is the successor of [q] by [0ᵏ], by [k] steps of [step]:
    the [leap] of an automaton whose leads are [0]. *)

val automaton : t -> int automaton
(** [automaton l] is the automaton of [l] over the states of its table, [dead]
    holding exactly of the state from which no final state is reachable, every
    lead being [0]. *)

(** The implicit automata over states ordered by [State.compare], equal states
    being one state. *)
module Implicit (State : Map.OrderedType) : sig
  val canonical : int -> State.t automaton -> t
  (** [canonical n a] is the language of [a] over [n] letters, by breadth-first
      exploration of the states reachable from the start by [step] and
      minimisation; the leads are not read. *)

  val is_empty : int -> State.t automaton -> bool
  (** [is_empty n a] is whether [a] accepts no word over [n] letters, by
      depth-first exploration of the states reachable from the start that are
      not dead, a state of lead [k ≥ 1] followed by its [leap] by [k] alone. *)
end

(** The products of the implicit automata over states ordered by [Left.compare]
    with those over states ordered by [Right.compare]. *)
module Product (Left : Map.OrderedType) (Right : Map.OrderedType) : sig
  val counterexample :
    int -> Left.t automaton -> Right.t automaton -> int list option
  (** [counterexample n a b] is a shortest word over [n] letters accepted by [a]
      and not by [b], the least of them in the order of the letters, found by
      breadth-first search of the product of [a] and [b], which explores only
      the pairs of states reachable from the start whose state of [a] is not
      dead; it is [None] iff every word over [n] letters accepted by [a] is
      accepted by [b]. The search proceeds by depths, and when the states of [a]
      of all the pairs of a depth have a lead of at least [k ≥ 1], it moves on
      to the depth [k] further by the [leap]s of both states by [k]: the depths
      in between have no pair to find, and their words are those of the depth
      extended by the letter [0] alike. *)
end
