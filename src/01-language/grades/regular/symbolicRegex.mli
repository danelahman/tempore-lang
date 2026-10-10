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
    expression has finitely many derivatives up to it, as symbolic derivatives
    over an effective Boolean algebra do (Zhuchko, Maarand, Veanes and Ebner,
    ITP 2025).

    A word of [n ≥ 2] ticks is one expression, a {e run} [tickⁿ], and
    concatenation joins adjacent runs: [tickᵐ; tickⁿ] is [tickᵐ⁺ⁿ] and
    [tickᵐ; (tickⁿ; s)] is [tickᵐ⁺ⁿ; s], [tick¹] being the letter set [{tick}]
    and [tick⁰] the empty word. A run stands for the concatenation of its
    letters, associated to the right: the normal forms are those of the
    expressions with letters for runs, one to one, with the same derivatives, so
    that the finiteness above holds, the derivative of [tickⁿ] by a block
    containing [tick] being [tickⁿ⁻¹].

    {2 Runs of ticks}

    The {e lead} of an expression ({!S.lead}) is a number [k] of ticks all its
    words begin with, read off its form, and its {e leap} by [k] ({!S.leap}) is
    its derivative by [tickᵏ]: a search from an expression of lead [k ≥ 1] has
    no other way than [tickᵏ] to a nullable derivative, and takes it in one step
    ({!S.Decide}).

    {2 Interning}

    Expressions are hash-consed: each normal form is built once and identified
    by its number, so that equal normal forms are physically equal. The table of
    expressions, the derivatives and the emptiness of the expressions explored
    are recorded in module-level tables, which only ever grow; they are an
    implementation device invisible through this interface, every function being
    pure.

    {2 Letters and alphabets}

    The expressions and decisions above are those of RE#. Two parameters, each a
    single design choice, replace their letters by those of Brzozowski, sharing
    everything else:
    - the {e alphabet} of the decisions ({!S.Decide}): the minterms of the
      letter sets ({!S.Minterms}), or the concrete letters [tick], each name
      mentioned and one catch-all letter for the names not mentioned
      ({!S.Concrete}), the finest partition that the letter sets respect up to
      the names they do not tell apart;
    - the {e letters} of the expressions ({!Make}): letter sets, merged in
      unions ({!Sets}), or single letters ({!Atoms}), a union of letters being a
      union of expressions.

    The module itself is [Make (Sets)] with the decisions by minterms. *)

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

  val hash : t -> int
  (** A hash compatible with {!equal}. *)

  val empty : t
  (** The empty letter set. *)

  val any : t
  (** The set of all letters. *)

  val tick : t
  (** The set [{tick}]. *)

  val name : string -> t
  (** [name n] is the set [{n}]. *)

  val others : string list -> t
  (** [others names] is the set of the names not among [names]; the names are
      sorted and their duplicates removed. *)

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

(** The letters of the expressions. *)
type letters =
  | Sets
      (** Letter sets, the letter sets among the operands of a union being
          merged into their union: the predicates of RE#. *)
  | Atoms
      (** Single letters: [tick], a name, or a catch-all letter given as a set
          {!Letters.others}; a union of letters is a union of expressions, and
          [Σ*] is [~∅], as is the repetition of a union of letters that holds
          every letter. *)

(** Extended regular expressions in normal form. *)
module type S = sig
  type t
  (** An expression in normal form. *)

  (** The top-level form of an expression. *)
  type view =
    | Empty  (** The empty language *)
    | Eps  (** The language of the empty word *)
    | Letters of Letters.t
        (** The one-letter words of a non-empty letter set *)
    | Ticks of int  (** The word [tickⁿ], a run of [n ≥ 2] ticks *)
    | Concat of t * t
        (** Concatenation, the first operand neither a concatenation, the empty
            word nor the empty language, and the second not led by a run of
            ticks if the first is one *)
    | Union of t list  (** Union of at least two operands *)
    | Inter of t list  (** Intersection of at least two operands *)
    | Compl of t  (** Complement *)
    | Star of t  (** Repetition *)

  val view : t -> view
  (** [view r] is the top-level form of [r]. *)

  val equal_form : t -> t -> bool
  (** [equal_form r s] is whether [r] and [s] have the same normal form, in
      constant time. It implies, but is stronger than, {!DECISIONS.equal}. *)

  val compare_form : t -> t -> int
  (** A total order on normal forms compatible with {!equal_form}, in constant
      time. *)

  val hash : t -> int
  (** [hash r] is a hash of the normal form of [r], compatible with
      {!equal_form}. *)

  val id : t -> int
  (** [id r] is the number of the normal form of [r], injective on normal forms:
      [id r = id s] iff [equal_form r s]. *)

  (** {1 Constructions} *)

  val empty : t
  (** The empty language. *)

  val eps : t
  (** The language of the empty word. *)

  val top : t
  (** The language [Σ*] of all words: [_*] over letter sets, [~∅] over single
      letters. *)

  val letters : Letters.t -> t
  (** [letters p] is the language of the one-letter words of [p]. *)

  val ticks : int -> t
  (** [ticks n] is the word [tickⁿ]: the empty word, the letter set [{tick}] or
      a run of [n] ticks. *)

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
      union of blocks. The blocks are listed by their least letter, [tick]
      before the names in increasing order before the names [r] does not
      mention. *)

  val derivative : Letters.t -> t -> t
  (** [derivative m r] is the derivative [a⁻¹r] of [r] by any letter [a] of [m],
      the words [w] such that [a w] is in [r], for [m] contained in a block of
      [minterms r]. *)

  val lead : t -> int
  (** [lead r] is a number [k] of ticks every word of [r] begins with, read off
      its form: [n] for a run of [n] ticks, [n] plus the lead of [s] for
      [tickⁿ; s], the lead of [r] for another concatenation [r; s], the least
      lead of the operands of a union and the greatest of those of an
      intersection, [Int.max_int] for the empty language and [0] otherwise. The
      derivatives of [r] by the words of length at most [k] other than the runs
      of ticks are thus empty, and those by [tickʲ] for [j < k] are not
      nullable. *)

  val leap : int -> t -> t
  (** [leap k r] is the derivative [(tickᵏ)⁻¹r] of [r] by [tickᵏ], denoting the
      language of [k] derivatives by [tick] in turn. It is taken at once where
      the form of [r] tells it: [tickⁿ⁻ᵏ] for a run of [n ≥ k] ticks,
      [tickⁿ⁻ᵏ; s] or [leap (k - n) s] for [tickⁿ; s], [leap k r; s] for another
      concatenation [r; s] if [k] is at most the lead of [r],
      [tickᶜ⁻ʲ; (tickᶜ)*] for the repetition [(tickᶜ)*] of a run,
      [j = k mod c ≠ 0], and the complement, union or intersection of the leaps
      of the operands; and otherwise by [k] derivatives, until a derivative is
      its own. It is the normal form of [k] derivatives on runs, concatenations
      led by runs, repetitions of runs and complements of these, and denotes the
      same language elsewhere. *)

  (** {1 Gap derivatives}

      A word is read in {e gap form} [tickᵈ⁰ a₁ tickᵈ¹ ⋯ aₖ tickᵈᵏ], its names
      [aᵢ] separated by maximal runs of ticks: a word over the letters
      [tickⁿ a], [n ∈ ℕ] and [a] a name, followed by a final delay [dₖ]. The gap
      derivatives are the derivatives by these letters, symbolic in [n] and [a]:
      by the products of a set of delays and a block of names, as symbolic
      derivatives over the Boolean algebra of the finite unions of such products
      (D'Antoni and Veanes, POPL 2014). The sets of delays are ultimately
      periodic (Chrobak, "Finite automata and unary languages", TCS 47, 1986),
      {!DelaySet} values of integers. Then [tickᵈ⁰ a₁ ⋯ aₖ tickᵈᵏ ∈ r] iff [dₖ]
      is in the {!delays} of the derivative of [r] by [tickᵈ⁰ a₁], …,
      [tickᵈᵏ⁻¹ aₖ] in turn. *)

  val delays : t -> DelaySet.t
  (** [delays r] is the set [N(r)] of the [n ∈ ℕ] such that [tickⁿ ∈ r], by
      structural recursion: [N(∅) = ∅], [N(ε) = {0}], [N(p)] is [{1}] if
      [tick ∈ p] and [∅] otherwise, [N(tickⁿ) = {n}], [N(r; s) = N(r) + N(s)],
      [N(r* ) = N(r)*], [N] commutes with union and intersection, and
      [N(~r) = ℕ ∖ N(r)], an intersection with complements being taken as a
      difference, [N(r & ~s) = N(r) ∖ N(s)]. Memoised by expression. *)

  type gaps = (DelaySet.t * t) list
  (** A map from delays to expressions: pairs [(S, e)], the sets [S] non-empty
      and pairwise disjoint sets of integers, the expressions [e] pairwise
      distinct, not the empty language and ordered by {!compare_form}. A delay
      in none of the sets is mapped to the empty language. *)

  val gap_derivative : Letters.t -> t -> gaps
  (** [gap_derivative m r] maps every delay [n] to an expression denoting the
      derivative [(tickⁿ a)⁻¹r] of [r] by [tickⁿ] followed by any name [a] of
      [m], for [m] a set of names contained in a block of [minterms r]. Writing
      [D(r)(n)] for it: [D(∅)], [D(ε)] and [D(tickⁿ)] are empty, [D(p)] maps [0]
      to [ε] if [m ⊆ p] and is empty otherwise,
      [D(r; s)(n) = D(r)(n); s | ⋃ {D(s)(n - i) : i ∈ N(r), i ≤ n}],
      [D(r* )(n) = ⋃ {D(r)(n - i); r* : i ∈ N(r)*, i ≤ n}], and [D] commutes
      with union, intersection and complement, the complement of the empty
      language being [Σ*]. Memoised by block and expression.

      @raise Invalid_argument if [m] contains [tick]. *)

  val gaps : t -> (Letters.t * gaps) list
  (** [gaps r] is the list of the blocks of names of [minterms r], the blocks
      without [tick], each with the gap derivative of [r] by it, listed by
      {!Letters.order}. *)

  (** {1 Alphabets} *)

  (** An alphabet of the decisions. *)
  module type ALPHABET = sig
    val blocks : t list -> Letters.t list
    (** [blocks roots] is a partition of the letters into non-empty sets that
        every letter set occurring in [roots] respects, listed by
        {!Letters.order}: the derivatives of [roots] are taken by one letter of
        each block. *)
  end

  module Minterms : ALPHABET
  (** The minterms of the letter sets of the roots, the coarsest such partition,
      as in RE#. *)

  module Concrete : ALPHABET
  (** The concrete letters of the roots: [tick], each name they mention, and one
      catch-all letter, the set of the names they do not mention, as in
      Brzozowski's derivatives over a finite alphabet. *)

  (** {1 Decisions}

      The decisions explore the graph of derivatives, the states being normal
      forms and the edges labelled by the blocks of an alphabet of the start,
      the derivatives by minterms being those of RE#. Deciding the inclusion and
      equivalence of extended regular expressions by derivatives follows Keil
      and Thiemann (FSTTCS 2014) and Varatalu, Veanes, Zhuchko and Ernits (CAV
      2025). From an expression of lead [k ≥ 1] the only edges to expressions
      that are not empty are those of the word [tickᵏ], none of whose proper
      prefixes leads to a nullable expression: the explorations follow the word
      at once, by the {!leap} by [k], and label it by [k] times the block
      containing [tick]. *)

  module type DECISIONS = sig
    val is_empty : t -> bool
    (** [is_empty r] is whether [r] has no words, decided by depth-first
        exploration, which stops at the first nullable derivative. *)

    val shortest : t -> Letters.t list option
    (** [shortest r] is [None] if [r] is empty, and otherwise the least of the
        shortest words of [r] in the order of the blocks, each letter given as
        the block of the alphabet it is taken from, found by breadth-first
        exploration by depths: when all the expressions of a depth have a lead
        of at least [k ≥ 1], it moves on [k] depths at once, by their leaps by
        [k], the depths in between having no nullable expression. *)

    val subset : t -> t -> bool
    (** [subset r s] is whether [r ⊆ s], i.e. whether [r & ~s] is empty. *)

    val equal : t -> t -> bool
    (** [equal r s] is whether [r] and [s] denote the same language, decided by
        a bisimulation up to the normal form (Hopcroft and Karp): the pairs of
        derivatives of [r] and [s] by the same words are explored breadth-first,
        the classes of the expressions found equal being merged as they go; a
        pair of expressions of leads at least [k ≥ 1] is followed by their leaps
        by [k] only, which denote the same language iff the pair does. *)
  end

  (** The decisions by the alphabet [A], with their own tables of the emptiness
      and equality of the expressions explored. *)
  module Decide (A : ALPHABET) : DECISIONS

  (** {1 Decisions in gap form}

      The decisions in gap form explore the graph of gap derivatives, the states
      being normal forms, the edges those of {!gap_derivative} by the blocks of
      names of an alphabet of the start (its blocks without [tick]), labelled by
      sets of delays, and the final delays of a state its {!delays}. The graph
      has one state for every derivative by a word ending in a name, whatever
      the delays of the expression, and is finite by the finiteness of the
      derivatives. *)

  type gap_word = (int * Letters.t) list * int
  (** A word in gap form [tickᵈ⁰ a₁ ⋯ tickᵈᵏ⁻¹ aₖ tickᵈᵏ]: the pairs
      [(dᵢ₋₁, aᵢ)], each name given as the block of names it is taken from, and
      the final delay [dₖ]. *)

  module type GAP_DECISIONS = sig
    val is_empty : t -> bool
    (** [is_empty r] is whether [r] has no words, decided by depth-first
        exploration of its gap derivatives, which stops at the first expression
        with a delay. *)

    val shortest : t -> gap_word option
    (** [shortest r] is [None] if [r] is empty, and otherwise the least of the
        shortest words of [r] in the order of the blocks, in gap form: the word
        of {!DECISIONS.shortest} by the same alphabet, its blocks containing
        [tick] read as [tick] and its other blocks as names. A word [tickᵈ a]
        has [d + 1] letters and a final delay [d] has [d]; the length [L] of the
        shortest words is found by Dijkstra's algorithm from [r], stopped at
        [L], the length of the shortest words of each expression reached by
        Dijkstra's algorithm on the reversed edges, and the word is built from
        [r] by taking at each expression the final delay if it is the length
        left, and otherwise the word [tickᵈ a] of greatest [d], then least
        block, that leaves a shortest word of the rest. *)

    val subset : t -> t -> bool
    (** [subset r s] is whether [r ⊆ s], i.e. whether [r & ~s] is empty. *)

    val equal : t -> t -> bool
    (** [equal r s] is whether [r] and [s] denote the same language, decided by
        a bisimulation up to the normal form (Hopcroft and Karp) of the gap
        derivatives: two expressions are related only if they have the same
        delays, and their gap derivatives by each block of names are paired on
        the common refinement of their sets of delays. *)
  end

  (** The decisions in gap form by the blocks of names of the alphabet [A], with
      their own tables of the emptiness and equality of the expressions
      explored. *)
  module GapDecide (A : ALPHABET) : GAP_DECISIONS
end

(** The expressions over the letters [L.letters], in a normal form of their own,
    with their own tables. With {!Atoms}, the letter sets given to {!S.letters}
    are single letters, and the catch-all letters of the expressions combined
    the same. *)
module Make (L : sig
  val letters : letters
end) : S

include S
(** @inline *)

include DECISIONS
(** The decisions by {!Minterms}. *)
