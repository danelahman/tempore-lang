(** The timed regular expressions of the brace literals, over rational delays:
    their denotations as timed regular languages ({!DelayAutomaton}), the delays
    they denote, and the expressions of classes of operations and of words.

    {2 Denotation}

    Over the timed words, the free product of the words over the operation names
    with [(ℚ≥0, +)]:
    - an operation name [A] denotes [{A}];
    - a delay [q] denotes [{q}], [0] the empty word;
    - an interval [[q, r]], [(q, r)], [\[q, r)], [(q, r\]], [\[q, ∞)] or
      [(q, ∞)] denotes the delays in it, the delay [0] being the empty word;
    - [_] denotes every operation and every positive delay;
    - [r; s], [r | s], [r & s], [~r] and [r*] denote concatenation, which adds
      the delays that meet, union, intersection, the complement relative to all
      timed words, and repetition;
    - [r^c] denotes the concatenations of [k] words of [r], [k] in the count
      [c], and [r^0] the empty word.

    Thus [_*] denotes all timed words, [~1] every timed word but the delay [1],
    and [_ & ~Read] every operation but [Read] and every positive delay. *)

val automaton : GradeLiteral.regex -> DelayAutomaton.t
(** [automaton r] is the language [r] denotes, built by recursion on [r] with
    the constructions of {!DelayAutomaton}, a bounded repetition unrolled
    ({!GradeLiteral.unrolled}); a strict delay [idle r] is rejected. A
    subexpression without names, [_] or complements denotes single delays only,
    and its automaton is the single transition on its {!delays}. *)

val delays : GradeLiteral.regex -> DelaySet.t
(** [delays r] is the set [ν(r)] of the delays that [r] denotes, computed by
    recursion on [r]: [ν(A) = ∅], [ν(q) = {q}], [ν(_) = ℚ>0], the sum for [;],
    since a product of timed words is a delay iff both factors are, the Boolean
    operations relative to [ℚ≥0] for [|], [&] and [~], the repetition for [*],
    and [⋃ {k·ν(r) : k ∈ c}] for [r^c] ({!DelaySet.repeat}). *)

val of_word : DelayAutomaton.symbol list -> GradeLiteral.regex
(** [of_word w] is the expression of the timed word [w], a concatenation of its
    non-zero delays and its classes, or [0] if it has none, its runs of equal
    factors joined into bounded repetitions ({!GradeLiteral.sequence}). *)
