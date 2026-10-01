(** Extended regular expressions over operation names and sets of rational
    delays, decided by gap derivatives.

    {2 Timed words}

    The timed words are the free product of the words over the names with
    [(ℚ≥0, +)], written in gap form [d₀ a₁ d₁ ⋯ aₖ dₖ]; concatenation adds the
    delays that meet ({!DelayAutomaton}). The expressions are those of
    {!SymbolicRegex} with sets of delays for runs of ticks: the empty language,
    the empty word, {e atoms} [⟨S⟩] denoting the delays of a set [S]
    ({!DelaySet}), the delay [0] being the empty word, sets of names, finite or
    cofinite, denoting their one-operation words, concatenation, union,
    intersection, complement relative to all timed words, and repetition.

    {2 Normal form}

    The expressions are built by smart constructors only, which keep the normal
    form of {!SymbolicRegex} with atoms for runs, sets of names for letter sets
    and [Σ = ⟨ℚ>0⟩ | Σ_names] for the letters, and in addition collapse the
    expressions without names: [⟨∅⟩] is the empty language and [⟨{0}⟩] the empty
    word; [⟨S⟩; ⟨T⟩] is [⟨S + T⟩], also leading a concatenation; the atoms among
    the operands of a union are merged into the atom of the union of their sets;
    an intersection with an atom is the atom of the delays common to all
    operands; an intersection of expressions of single symbols (atoms, sets of
    names and their unions), their complements and repetitions of sets of names,
    one of them of single symbols, is the expression of the single symbols
    common to all, as [_ & ~A] is [⟨ℚ>0⟩ | (Σ_names ∖ A)]; and [⟨S⟩*] is [⟨S*⟩],
    the delay [0] of an atom under a repetition being left out. Each rule is a
    semantic identity, an atom's words being delays, so that every expression
    whose words are all delays is an atom, equal in form to another iff their
    sets of delays are equal.

    {2 Gap derivatives}

    The gap derivative of [r] by a block [m] of names maps each delay [d] to an
    expression of the derivative [(d a)⁻¹r], [a ∈ m]:
    [D(r; s)(d) = D(r)(d); s | ⋃ {D(s)(d - i) : i ∈ N(r), i ≤ d}],
    [D(r* )(d) = ⋃ {D(r)(d - i); r* : i ∈ N(r)*, i ≤ d}], [D] commuting with the
    Boolean operations, the complement taken relative to [ℚ≥0] ({!GapMap}). Then
    [d₀ a₁ ⋯ aₖ dₖ ∈ r] iff [dₖ] is in the delays of the derivative of [r] by
    [d₀ a₁], …, [dₖ₋₁ aₖ] in turn (Brzozowski, JACM 1964, on the alphabet
    [ℚ≥0 × Names]), a symbolic derivative over the finite unions of products of
    sets of delays and blocks of names (D'Antoni and Veanes, POPL 2014).

    {2 Interning}

    Expressions are hash-consed and identified by their numbers. The normal
    forms, the delays, the gap derivatives and the decisions are recorded in
    module-level tables, which only ever grow; they are an implementation device
    invisible through this interface, every function being pure. *)

type t
(** An expression in normal form. *)

type view =
  | Empty
  | Eps
  | Delays of DelaySet.t
      (** An atom: a set of delays, neither empty nor [{0}] *)
  | Names of SymbolicRegex.Letters.t
      (** A non-empty set of names, without [tick] *)
  | Concat of t * t
  | Union of t list
  | Inter of t list
  | Compl of t
  | Star of t

val view : t -> view

val equal_form : t -> t -> bool
(** [equal_form r s] is whether [r] and [s] are the same normal form. *)

val compare_form : t -> t -> int
(** The order of the normal forms by their numbers. *)

val hash : t -> int
(** [hash r] is the number of the normal form [r]. *)

(** {1 Constructions} *)

val empty : t
val eps : t

val top : t
(** [top] is [_*], the language of all timed words. *)

val delays_atom : DelaySet.t -> t
(** [delays_atom s] is the atom of the delays [s]. *)

val names_atom : SymbolicRegex.Letters.t -> t
(** [names_atom p] is the language of the one-operation words of the names of
    [p], [tick] left out. *)

val concat : t -> t -> t
val union : t list -> t
val inter : t list -> t

val compl : t -> t
(** [compl r] is the complement of [r] relative to all timed words. *)

val star : t -> t

val of_regex : GradeLiteral.regex -> t
(** [of_regex r] is the expression of the brace literal [r], denoting the
    language {!DelayRegex.automaton}[ r]: a name [A] is [{A}], a delay [q] the
    atom [⟨{q}⟩], an interval of delays the atom of its delays, and [_] is
    [⟨ℚ>0⟩ | Σ_names]. *)

(** {1 Queries} *)

val nullable : t -> bool
(** [nullable r] is whether the empty word is in [r]. *)

val delays : t -> DelaySet.t
(** [delays r] is the set [N(r)] of the delays [d] such that the word [d] is in
    [r], by structural recursion: [N(∅) = N(p) = ∅], [N(ε) = {0}], [N(⟨S⟩) = S],
    [N(r; s) = N(r) + N(s)], [N(r* ) = N(r)*], [N] commutes with union and
    intersection, and [N(~r) = ℚ≥0 ∖ N(r)], an intersection with complements
    being taken as a difference, [N(r & ~s) = N(r) ∖ N(s)]. Memoised by
    expression. *)

val names : t -> string list
(** [names r] is the names the sets of names of [r] mention, in increasing
    order. *)

val blocks : t list -> SymbolicRegex.Letters.t list
(** [blocks roots] is the minterms of the sets of names of [roots], the coarsest
    partition of the names that they respect, listed by
    {!SymbolicRegex.Letters.order}. *)

type gaps = t GapMap.t

val gap_derivative : SymbolicRegex.Letters.t -> t -> gaps
(** [gap_derivative m r] maps every delay [d] to an expression denoting the
    derivative [(d a)⁻¹r] of [r] by [d] followed by any name [a] of [m], for [m]
    a set of names contained in a block of {!blocks}[ [r]]: [D(∅)], [D(ε)] and
    [D(⟨S⟩)] are empty, [D(p)] maps [0] to [ε] if [m ⊆ p] and is empty
    otherwise, and the other cases are as above. Memoised by block and
    expression. *)

val mem : DelayAutomaton.symbol list -> t -> bool
(** [mem w r] is whether the timed word [w], a sequence of delays and operations
    of single names in any order, is in [r], by its gap derivatives. *)

(** {1 Decisions} *)

val is_empty : t -> bool
(** [is_empty r] is whether [r] has no words, decided by depth-first exploration
    of its gap derivatives by the blocks of {!blocks}[ [r]] ({!GapDecisions}).
*)

val subset : t -> t -> bool
(** [subset r s] is whether [r ⊆ s], i.e. whether [r & ~s] is empty. *)

val equal : t -> t -> bool
(** [equal r s] is whether [r] and [s] denote the same language, decided by
    Hopcroft and Karp's algorithm on the gap derivatives ({!GapDecisions}). *)

val counterexample : t -> t -> DelayAutomaton.symbol list option
(** [counterexample r s] is [None] if [r ⊆ s], and otherwise a word of [r] not
    in [s] in gap form [d₀ c₁ d₁ ⋯ cₖ dₖ] with the fewest operations, found by
    breadth-first search of the gap derivatives of [r & ~s]
    ({!GapDecisions.Make.fewest_operations}): each class [cᵢ] is a block of
    {!blocks}[ [r & ~s]] and each delay the simplest element
    ({!DelaySet.choose}) of the set of delays it is read by; every word
    [d₀ a₁ d₁ ⋯ aₖ dₖ] with [aᵢ ∈ cᵢ] is in [r] and not in [s]. *)

val graph : string list -> t -> DelayTimedClosure.graph
(** [graph names r] is the automaton in gap form of the gap derivatives of [r]
    by [names] ({!GapGraph.Make}), explored in full, breadth-first from [r]. *)
