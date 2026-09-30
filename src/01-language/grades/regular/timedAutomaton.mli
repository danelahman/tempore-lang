(** Timed regular languages: sets of timed words over operation names and
    non-negative rational delays, decided by deterministic normal-form automata
    whose delay transitions are labelled by sets of delays ({!DelaySet}).

    {2 Timed words}

    The timed words are the free product of the words over the operation names
    with the monoid [(ℚ≥0, +)]: a word is written in {e gap form}
    [d₀ a₁ d₁ ⋯ aₙ dₙ], the [aᵢ] operations and the [dᵢ] delays, [0] for none,
    and concatenation adds the two delays that meet. A language of timed words
    is thus a language of words alternating between delays and operations,
    beginning and ending with a delay.

    {2 Automata}

    A normal-form automaton has {e gap states}, where a delay is read next, and
    {e operation states}, where an operation is read next or the word ends. A
    gap state moves to an operation state on the delays of a set, and an
    operation state to a gap state on the operations of a class, a finite or a
    cofinite set of names. The start is a gap state and the final states are
    operation states.

    An automaton with delay and operation transitions in any order, the raw
    automaton of Thompson's construction, is brought to normal form by its
    {e gap closure}: the set of the sums of the delays along the paths of delay
    transitions between each two states, computed by Kleene's algorithm over the
    semiring of the sets of delays under union and sum, with the repetition of
    {!DelaySet.star} (Lehmann, "Algebraic structures for transitive closure",
    TCS 4, 1977). Concatenation and repetition link raw automata by transitions
    on the delay [0], and the gap closure adds the delays that meet.

    Determinisation is the subset construction over the minterms of the labels
    leaving each subset, of the sets of delays and of the classes of names, as
    for symbolic automata (D'Antoni and Veanes, "Minimization of symbolic
    automata", POPL 2014): every delay of a minterm, and every name of a
    minterm, takes the same transitions.

    {2 Canonical form}

    A language is kept as its minimal complete deterministic automaton (Moore's
    partition refinement), the labels of the transitions from a state to the
    same state merged, the transitions of a state ordered by their labels and
    the states numbered in the breadth-first order of their discovery from the
    start. Two automata denote the same language iff they are equal, which
    {!equal}, {!compare} and {!hash} read.

    The results of the binary constructions and of {!counterexample} are
    recorded in module-level tables by their arguments, which only ever grow;
    they are an implementation device invisible through this interface. *)

(** Classes of operations: finite and cofinite sets of names. *)
module Class : sig
  type t = SymbolicRegex.Letters.t
  (** A set of names, without [tick]. *)

  val all : t
  (** The set of all names. *)

  val name : string -> t
  (** [name n] is the set [{n}]. *)

  val union : t -> t -> t
  val inter : t -> t -> t

  val compl : t -> t
  (** [compl c] is the set of the names not in [c]. *)

  val is_empty : t -> bool
  val compare : t -> t -> int

  val names : t -> string list
  (** [names c] is the names [c] lists, in increasing order: its members if it
      is finite, and the names it leaves out otherwise. *)
end

type t
(** A timed regular language, in canonical form. *)

(** {1 Constructions} *)

val empty : t
(** The empty language. *)

val epsilon : t
(** The language [{ε}] of the empty word. *)

val universal : t
(** The language of all timed words. *)

val delays : DelaySet.t -> t
(** [delays s] is the language of the delays of [s], the delay [0] being the
    empty word. *)

val operations : Class.t -> t
(** [operations c] is the language of the one-operation words of [c]. *)

val concat : t -> t -> t
val union : t -> t -> t
val inter : t -> t -> t

val compl : t -> t
(** [compl l] is the complement of [l] relative to all timed words. *)

val star : t -> t
(** [star l] is [⋃ₙ lⁿ], [l⁰ = {ε}]. *)

(** {1 Decisions} *)

val is_empty : t -> bool
val subset : t -> t -> bool

val equal : t -> t -> bool
(** [equal l m] is whether [l] and [m] are the same language. *)

val compare : t -> t -> int
(** A total order compatible with {!equal}. *)

val hash : t -> int
(** A hash compatible with {!equal}. *)

(** A symbol of a word in gap form. *)
type symbol =
  | Delay of Rational.t  (** A delay, [0] for none *)
  | Operation of Class.t
      (** An operation of a class, all of whose names are alike *)

val counterexample : t -> t -> symbol list option
(** [counterexample l m] is [None] if [l ⊆ m], and otherwise a word of [l] not
    in [m] in gap form [d₀ c₁ d₁ ⋯ cₙ dₙ], shortest in its number of operations:
    every word [d₀ a₁ d₁ ⋯ aₙ dₙ] with [aᵢ ∈ cᵢ] is in [l] and not in [m]. It is
    found by breadth-first search of the product of [l] with the complement of
    [m]; each delay is the simplest element ({!DelaySet.choose}) of the
    intersection of the labels it is read by, and each class is the intersection
    of the classes. *)

val mem : symbol list -> t -> bool
(** [mem w l] is whether the timed word [w], a sequence of delays and operations
    of single names in any order, is in [l]. *)

(** {1 Inspection} *)

val delay_part : t -> DelaySet.t
(** [delay_part l] is the set of the delays that are words of [l]. *)

val names : t -> string list
(** [names l] is the names the labels of [l] list, in increasing order: the
    names [l] tells apart from the others. *)

val states : t -> int
(** [states l] is the number of states of the automaton of [l], of both kinds.
*)
