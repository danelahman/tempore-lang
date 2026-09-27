(** Extended regular expressions over the letters [tick] and operation names,
    with letter sets as predicates, decided by symbolic derivatives.

    The expressions are those of RE# (Varatalu, Veanes and Ernits, "RE#: High
    Performance Derivative-Based Regex Matching with Intersection, Complement,
    and Restricted Lookarounds", POPL 2025): letter sets, the empty word, the
    empty language, concatenation, union, intersection, complement and
    repetition, the complement being taken over all words.

    {2 Alphabet}

    The letters are [tick] and every operation name. A letter set is [tick] or
    not together with a finite or a cofinite set of names, so that the letter
    sets form a Boolean algebra and the names an expression does not mention are
    all alike to it.

    {2 Normal form}

    The expressions are built by smart constructors only, which keep them in a
    normal form: unions and intersections are flattened into sets of at least
    two operands, ordered and without duplicates; the letter sets among the
    operands of a union are merged into their union, and in an intersection with
    a letter set, the letter sets, their complements and their repetitions are
    merged into the intersection of their one-letter words; concatenation is
    associated to the right. The empty language, the empty word and [Σ*] obey
    their unit and zero laws, an intersection with the empty word being the
    empty word or the empty language; [~~r] is [r], [r | ~r] is [Σ*] and
    [r & ~r] the empty language, also where [r] is a union, respectively an
    intersection, whose operands are flattened among those of the other; [0 | r]
    is [r] for a nullable [r] and [r | r*] is [r*]; [r**], [(0 | r)*] and
    [r*; r*] are [r*], and the repetition of the empty word or language is the
    empty word. Brzozowski's similarity is thus decided syntactically, and every
    expression has finitely many derivatives up to it.

    {2 Interning}

    Expressions are hash-consed: each normal form is built once and identified
    by its number, so that equal normal forms are physically equal. The table of
    expressions, the derivatives and the emptiness of the expressions explored
    are recorded in module-level tables, which only ever grow; they are an
    implementation device invisible through this interface, every function being
    pure. *)

(** Letter sets. *)
module Letters : sig
  (** A finite set of names, or the complement of one. *)
  type names =
    | Only of string list  (** The names listed, in increasing order *)
    | Except of string list
        (** Every name except those listed, in increasing order *)

  type t = private { tick : bool; names : names }
  (** The letter set containing [tick] iff [tick] holds, and the [names]. *)

  val equal : t -> t -> bool
  val compare : t -> t -> int

  val empty : t
  (** The empty letter set. *)

  val any : t
  (** The set of all letters. *)

  val tick : t
  (** The set [{tick}]. *)

  val name : string -> t
  (** [name n] is the set [{n}]. *)

  val union : t -> t -> t
  val inter : t -> t -> t

  val compl : t -> t
  (** [compl p] is the set of the letters not in [p]. *)

  val is_empty : t -> bool

  val order : t -> t -> int
  (** [order p q] orders letter sets by their least letter: [tick], then the
      names in increasing order, then the names a finite set of names leaves
      out; it is a total order. *)

  val partition : t list -> t list
  (** [partition sets] is the coarsest partition of the letters into non-empty
      sets that the letter sets [sets] respect, each of them a union of blocks;
      the blocks are listed by {!order}. *)
end

type t
(** An expression in normal form. *)

(** The top-level form of an expression. *)
type view =
  | Empty  (** The empty language *)
  | Eps  (** The language of the empty word *)
  | Letters of Letters.t  (** The one-letter words of a non-empty letter set *)
  | Concat of t * t
      (** Concatenation, the first operand neither a concatenation, the empty
          word nor the empty language *)
  | Union of t list  (** Union of at least two operands *)
  | Inter of t list  (** Intersection of at least two operands *)
  | Compl of t  (** Complement *)
  | Star of t  (** Repetition *)

val view : t -> view
(** [view r] is the top-level form of [r]. *)

val equal_form : t -> t -> bool
(** [equal_form r s] is whether [r] and [s] have the same normal form, in
    constant time. It implies, but is stronger than, {!equal}. *)

val hash : t -> int
(** [hash r] is a hash of the normal form of [r], compatible with {!equal_form}.
*)

(** {1 Constructions} *)

val empty : t
(** The empty language. *)

val eps : t
(** The language of the empty word. *)

val top : t
(** The language [Σ*] of all words, [_*]. *)

val letters : Letters.t -> t
(** [letters p] is the language of the one-letter words of [p]. *)

val concat : t -> t -> t
val union : t list -> t
val inter : t list -> t
val compl : t -> t
val star : t -> t

val names : t -> string list
(** [names r] is the list of the names [r] mentions, in increasing order. *)

(** {1 Derivatives} *)

val nullable : t -> bool
(** [nullable r] is whether [r] contains the empty word. *)

val minterms : t -> Letters.t list
(** [minterms r] is the coarsest partition of the letters into non-empty sets
    that every letter set occurring in [r] respects: each such letter set is a
    union of blocks. The blocks are listed by their least letter, [tick] before
    the names in increasing order before the names [r] does not mention. *)

val derivative : Letters.t -> t -> t
(** [derivative m r] is the derivative [a⁻¹r] of [r] by any letter [a] of [m],
    the words [w] such that [a w] is in [r], for [m] contained in a block of
    [minterms r]. *)

(** {1 Decisions}

    The decisions explore the graph of derivatives, the states being normal
    forms and the edges labelled by the minterms of the start. *)

val is_empty : t -> bool
(** [is_empty r] is whether [r] has no words, decided by depth-first
    exploration, which stops at the first nullable derivative. *)

val shortest : t -> Letters.t list option
(** [shortest r] is [None] if [r] is empty, and otherwise a shortest word of
    [r], each letter given as the block of {!minterms} it is taken from, found
    by breadth-first exploration. *)

val subset : t -> t -> bool
(** [subset r s] is whether [r ⊆ s], i.e. whether [r & ~s] is empty. *)

val equal : t -> t -> bool
(** [equal r s] is whether [r] and [s] denote the same language, decided by a
    bisimulation up to the normal form (Hopcroft and Karp): the pairs of
    derivatives of [r] and [s] by the same words are explored breadth-first, the
    classes of the expressions found equal being merged as they go. *)
