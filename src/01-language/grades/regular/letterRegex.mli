(** Regular expressions over letter sets, as the regular trace grade prints
    them: normalised by a terminating rewrite system of Kleene-algebra
    identities, measured by their size, and printed in the literal syntax.

    {2 Rewrite system}

    The expressions are built by smart constructors only, which apply the
    following identities from left to right, [x], [y] and [z] standing for
    expressions and [p] and [q] for letter sets:

    - units and zeros: [0; x = x; 0 = 0], [ε; x = x; ε = x], [0 | x = x],
      [x & _* = x], [x & 0 = 0], [~~x = x], [ε* = 0* = ε];
    - associativity, commutativity and idempotence: nested concatenations,
      unions and intersections are flattened, and the operands of a union or an
      intersection are sorted by {!compare} without duplicates;
    - letter sets: [p | q] is the union and [p & q] the intersection of [p] and
      [q] in the Boolean algebra of letter sets;
    - repetition: [x*; x* = x*], [{x*}* = x*], [(ε | x)* = x*],
      [{x | y*}* = (x | y)*], [{x; x*}* = x*], and [(x; y)* = (x | y)*] for
      nullable [x] and [y], braces grouping as in the literal syntax;
    - absorption in unions: [x | x* = x*], [ε | x = x] for a nullable [x], and
      [y | x; x* = y | x*; x = y | x*] for a nullable [y];
    - distributivity: [x; y | x; z = x; (y | z)] and [y; x | z; x = (y | z); x],
      with [x = x; ε = ε; x], the common first factors of the operands of a
      union being factored out before the common last factors; a run of ticks
      counts as one factor, as it is printed as one integer.

    Each identity other than the reordering of operands strictly decreases the
    number of occurrences of letter sets, the {!size} and the number of
    concatenations, ordered lexicographically, so that rewriting terminates. The
    smart constructors apply the identities to operands already in normal form,
    so that the normal form of an expression is determined by its operands. *)

module Letters = SymbolicRegex.Letters

(** An expression in normal form. *)
type t = private
  | Empty  (** The empty language *)
  | Eps  (** The empty word *)
  | Letters of Letters.t  (** The one-letter words of a non-empty letter set *)
  | Seq of t list  (** Concatenation of at least two factors *)
  | Union of t list  (** Union of at least two operands *)
  | Inter of t list  (** Intersection of at least two operands *)
  | Compl of t  (** Complement *)
  | Star of t  (** Repetition *)

val compare : t -> t -> int
(** A total order on normal forms, independent of any numbering of expressions:
    by the outermost operator, then by the operands; letter sets are ordered by
    {!Letters.order}. *)

val equal : t -> t -> bool

(** {1 Constructions} *)

val empty : t
val eps : t

val letters : Letters.t -> t
(** [letters p] is the language of the one-letter words of [p]. *)

val seq : t list -> t
val union : t list -> t
val inter : t list -> t
val compl : t -> t
val star : t -> t

val of_symbolic : SymbolicRegex.t -> t
(** [of_symbolic r] is the normal form of the expression [r]. *)

val reverse : t -> t
(** [reverse r] is the normal form of the reversal of [r], whose words are those
    of [r] read backwards: the factors of every concatenation are reversed. *)

(** {1 Printing} *)

val size : t -> int
(** [size r] is the number of atoms and operators of the printed form of [r]: a
    run of ticks counts as the one integer it is printed as, and a letter set as
    its printed form [A | B], [_] or [_ & ~(A | B)]. *)

val to_string : t -> string
(** [to_string r] prints [r] in the literal syntax, without the enclosing
    braces: runs of ticks as integers, the empty word as [0], the empty language
    as [~_*], and letter sets as unions of letters, as [_] or as [_ & ~(…)]. A
    group ending with a repetition is printed in braces rather than parentheses,
    e.g. [~{_*; Revoke; _*}], so that no printed expression contains a
    repetition followed by a closing parenthesis, which would close a comment
    quoting it. *)

val literal : t -> string
(** [literal r] is the literal of the regular trace grade [r]: [⊤] if [r] is
    [_*], and otherwise {!to_string} [r] in braces. *)
