(** The regular trace grade decided by symbolic derivatives,
    ["regex-upper-bound-symbolic"].

    The grade is that of {!RegularTraceGrade}, with the same runs, alphabet,
    order, operations, literals and runtime bounds; only the representation and
    the decision procedures differ.

    {2 Representation}

    A grade is an extended regular expression in the normal form of
    {!SymbolicRegex}: the product is concatenation, the join union, the unit
    [{0}] and the top [_*], each built by a smart constructor without any
    automaton, and a delay of [n] time steps is one run of ticks [tickⁿ]. The
    letters are [tick] and every operation name, a letter set being finite or
    cofinite in the names, so that the names a grade does not mention are all
    alike to it: this is the catch-all letter of {!RegularTraceGrade}, and
    grades over different names need no alignment. {!Grade.S.compare} and
    {!Grade.S.hash} read the number of the normal form, in constant time; grades
    of different normal forms may denote the same language, so {!Grade.S.is_top}
    is decided by inclusion.

    {2 Decisions}

    Inclusion [rho ⊆ rho'] is the emptiness of [rho & ~rho'], decided by
    depth-first exploration of its derivatives by the minterms of its letter
    sets, the symbolic derivatives of RE# (Varatalu, Veanes and Ernits, POPL
    2025); equality is decided by a bisimulation of the derivatives of both
    grades. Deciding extended regular expressions by derivatives follows Keil
    and Thiemann (FSTTCS 2014) and Varatalu, Veanes, Zhuchko and Ernits (CAV
    2025). {!Grade.S.counterexample} [bounds rho rho'] is the grade of a
    shortest word of [rho & ~rho'], found by breadth-first exploration, in which
    a letter is the least letter of its minterm: [tick], else its least name,
    else the minterm itself, the names neither grade mentions. The explorations
    take the runs of ticks that all words of an expression begin with in one
    step, by the leaps of {!SymbolicRegex.S.leap}, so that a delay costs one
    step however long.

    {2 Printing}

    A grade [rho] is printed within a {e budget} [b], the {!LetterRegex.size} of
    its normal form {!LetterRegex.of_symbolic} [rho]: as the canonical candidate
    {!SymbolicAutomaton.canonical} [~budget:b] of the canonical form
    {!SymbolicAutomaton.of_regex} [~limit:b] of the automaton of its
    derivatives, and otherwise as its normal form. The printing thus
    {e falls back} to the normal form iff [rho] has more than [b] derivatives up
    to the normal form, or no canonical candidate of its language costs at most
    [b].

    - The printing computes the normal form, explores the derivatives of at most
      [b + 1] expressions, and then takes time polynomial in [b].
    - The expression printed has size at most [b].
    - The canonical candidate printed is determined by the language: grades
      denoting the same language print alike unless the printing of one of them
      falls back, whatever their normal forms and budgets.
    - The top is printed as [⊤] unless the printing falls back, and the literal
      read back denotes the same language.

    The fallback cannot be dispensed with. The equality of extended regular
    expressions has no elementary bound (Stockmeyer and Meyer, STOC 1973;
    Stockmeyer, PhD thesis, MIT 1974), and a printing determined by the language
    and bounded by an elementary function of the size of the expression would
    decide it.

    {2 Derivatives by letters}

    {!Concrete}, ["regex-upper-bound-symbolic-by-letters"], is the same grade
    decided by the derivatives by the concrete letters of the grades compared,
    {!SymbolicRegex.S.Concrete}, rather than by their minterms, and otherwise
    alike. *)

(** A regular trace grade by derivatives. *)
module type S = sig
  include Grade.S with type t = SymbolicRegex.t and type Delay.t = Delay.Nat.t

  val of_regex : Grade.regex -> t
  (** [of_regex r] is the normal form of the expression [r], which may denote
      the empty language.

      @raise Grade.Invalid_literal
        if [r] has a delay that is not an integer, or an interval of delays with
        no whole number of time steps. *)

  val concrete : string list -> t -> Dfa.t
  (** [concrete names rho] is the language of the runs of [rho] that perform
      only operations among [names], over the letters [tick], numbered [0], and
      [names], numbered from [1] in their order, as
      {!RegularTraceGrade.concrete}: the automaton
      {!SymbolicAutomaton.of_derivatives} of the derivatives of [rho] by the
      blocks of its alphabet, explored in full, each letter following the edge
      whose label contains it. *)

  val runs : string list -> t -> t Dfa.automaton
  (** [runs names rho] is the automaton of the same language over the same
      letters, explored lazily: its states are the normal forms of the
      derivatives of [rho] by these letters, the final ones the nullable ones,
      the dead ones the empty ones, and the leads and leaps those of
      {!SymbolicRegex.S.lead} and {!SymbolicRegex.S.leap}. *)

  val canonical : t -> LetterRegex.t option
  (** [canonical rho] is the canonical expression printed for [rho], or [None]
      if the printing of [rho] falls back to its normal form. *)
end

(** The grade decided by the derivatives by the blocks of [Alphabet], named
    [Name.name]. *)
module Make
    (Alphabet : SymbolicRegex.ALPHABET)
    (Name : sig
      val name : string
    end) : S

include S
(** @inline *)

module Concrete : S
(** ["regex-upper-bound-symbolic-by-letters"], by {!SymbolicRegex.S.Concrete}.
*)
