(** Timed regular expressions with interval letters, the grades of the rigid
    families of timed operations.

    {2 Letters}

    A letter is an operation set, of which exactly one operation occurs, or a
    stretch: a set of operations and an interval of lengths, during which only
    operations of the set may run. A stretch with the empty set is a strict
    wait, and one with every operation an unrestricted budget. The intervals of
    an expression are one-sided, on the side of the expression ({!type-side}):
    from [0] to an upper end on the upper side, and from a lower end to [∞] on
    the lower side; either is one end, a {!type-cut}.

    {2 Normal form}

    The expressions are built by smart constructors only, hash-consed and
    identified by their numbers. Every rule is an identity of the languages of
    exact words, in which a stretch of length [0] vanishes and adjacent
    stretches of one set merge:
    - adjacent stretches of one set merge, their cuts added (the Minkowski sum:
      an end is open iff an end summed is);
    - concatenation is associated to the right, with the unit and zero laws, and
      adjacent factors of one base other than a stretch are joined into a
      bounded repetition, [x; x^c] being [x^(c + 1)];
    - a union is flattened, ordered and without duplicates; its operation sets
      merge into their union, its stretches of one set into the widest, [r] is
      left out beside [r*], and [0] beside a nullable operand;
    - the repetition of a stretch is a stretch: on the upper side [≤d*] is [≥0],
      the stretch of every length, and [≤d^[m, n]] is [≤n·d]; on the lower side
      [≥d*] is [0 | ≥d], [≥0*] is [≥0], [≥d^[m, n]] is [≥m·d] for [m ≥ 1] and
      [0 | ≥d] for [m = 0];
    - on the upper side a stretch [≤0] is the empty word; on the lower side [≥0]
      is kept, a stretch, not the empty word;
    - the laws of repetition of {!SymbolicRegex.S.repeat}.

    There is no complement and no intersection of expressions: they apply to
    operation sets and intervals only.

    {2 Literals}

    A brace literal is read on a side: an operation name, a union of names, [_],
    [~A] and [_ & ~A] are operation sets; a delay [d], an interval [[a, b]] and
    the one-sided intervals [≤d], [<d], [≥d] and [>d] are budgets, and under
    [idle] strict waits; the intersection [(I & S)] of an interval [I] with an
    operation set [S] is a budget restricted to [S], as [≥0 & ~Read] or
    [(≤5 & (Scan | Turn))]; a two-sided interval is read by its hull on the
    side, [[a, b]] as [≤b] on the upper side and [≥a] on the lower one, and a
    one-sided interval of the other side is rejected, [≥0] and [≤∞] being both.
    [r?] is [r | 0], and [0] the empty word. Over whole time steps, an open end
    is closed at the next integer inward, [<3] being [≤2], and fractions are
    rejected. *)

open Grade

(** Operation sets: finite sets of names and their complements. *)
module Ops : sig
  type t = private
    | Only of string list  (** The names listed, in increasing order *)
    | Except of string list
        (** Every name except those listed, in increasing order *)

  val empty : t
  val all : t
  val name : string -> t

  val of_list : string list -> t
  (** [of_list names] is the set of [names]. *)

  val union : t -> t -> t
  val inter : t -> t -> t
  val compl : t -> t
  val mem : string -> t -> bool
  val is_empty : t -> bool

  val subset : t -> t -> bool
  (** [subset s s'] is whether [s] is contained in [s']. *)

  val equal : t -> t -> bool
  val compare : t -> t -> int
  val hash : t -> int

  val mentioned : t -> string list
  (** [mentioned s] is the names [s] lists, in increasing order. *)
end

(** An end of a one-sided interval of lengths: [Finite (q, attained)], [q]
    attained or not, or [Infinite], the end [∞] of an upper interval. *)
type cut = DelaySet.extremum = Finite of Rational.t * bool | Infinite

(** The side of the intervals of an expression: [Upper], [[0, c]] or [\[0, c)],
    and [Lower], [\[c, ∞)] or [(c, ∞)]. *)
type side = Upper | Lower

val add_cuts : cut -> cut -> cut
(** [add_cuts c c'] is the cut of the sum of the intervals of [c] and [c'], on
    either side. *)

val wider : side -> cut -> cut -> bool
(** [wider side c c'] is whether the interval of [c] contains that of [c'] on
    [side]. *)

(** Expressions in normal form on one side. *)
module type S = sig
  val side : side

  type t
  (** An expression in normal form. *)

  (** The top-level form of an expression. *)
  type view =
    | Empty  (** The empty language *)
    | Eps  (** The empty word *)
    | Op of Ops.t  (** One operation of a non-empty set *)
    | Stretch of Ops.t * cut
        (** A stretch of a length in the interval of the cut, with operations of
            the set; the empty set is a strict wait *)
    | Concat of t * t
        (** Concatenation, the first operand neither a concatenation, the empty
            word nor the empty language *)
    | Union of t list  (** Union of at least two operands *)
    | Star of t  (** Repetition *)
    | Repeat of t * Count.t  (** Bounded repetition [r^c] *)

  val view : t -> view
  val id : t -> int

  val hash : t -> int
  (** [hash r] is the number of [r]. *)

  val equal : t -> t -> bool
  (** [equal r s] is whether [r] and [s] are the same normal form. *)

  val compare : t -> t -> int
  (** The order of the normal forms by their numbers. *)

  val empty : t
  val eps : t

  val op : Ops.t -> t
  (** [op s] is one operation of [s]. *)

  val stretch : Ops.t -> cut -> t
  (** [stretch s c] is a stretch with the operations [s] and the cut [c]. *)

  val concat : t -> t -> t
  val union : t list -> t
  val star : t -> t
  val repeat : t -> Count.t -> t
  val nullable : t -> bool

  val factors : t -> t list
  (** [factors r] is the factors of the concatenation [r], [[r]] if [r] is none.
  *)

  val names : t -> string list
  (** [names r] is the names [r] mentions, in increasing order. *)

  val of_regex : whole:bool -> finite:bool -> lit -> regex -> t
  (** [of_regex ~whole ~finite lit r] is the expression of the contents [r] of
      the brace literal [lit] on this side, over whole time steps if [whole],
      and star-free, of finite counts and finite operation sets if [finite].

      @raise Invalid_literal
        on [lit] if [r] has a fraction over whole time steps, a one-sided
        interval of the other side, [idle _], a complement or an intersection of
        expressions, the complement of an interval, or, if [finite], a
        repetition [*], an unbounded count or a cofinite operation set as a
        letter. *)

  val show : t -> string
  (** [show r] prints [r] as the contents of a brace literal: [idle ≤2] or
      [idle <2] and [≤5] on the upper side, [idle ≥2] or [idle >2] and [≥5] on
      the lower, the stretch of every length [≥0], [r | 0] as [r?], and the
      empty language as [_ & ~_]. *)
end

module Upper : S
module Lower : S

val zip : Lower.t -> Upper.t -> string option
(** [zip lo hi] prints the interval of the lower bound [lo] and the upper bound
    [hi] as the contents of one brace literal, if they differ only in the cuts
    of their stretches and each pair of cuts bounds a non-empty interval: the
    stretches [≥a] and [≤b] as [[a, b]], [≥a] and [≤a] as [a], [≥0] and [≥0] as
    [≥0]. Reading the literal by the hull on each side gives [lo] and [hi] back.
*)
