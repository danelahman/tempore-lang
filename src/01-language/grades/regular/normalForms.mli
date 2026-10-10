(** The parts of the normal forms of extended regular expressions shared by
    {!SymbolicRegex}, over letter sets and runs of ticks, and {!RationalRegex},
    over sets of names and sets of delays: their tables by numbers, their
    hash-consing, and the rules of their Boolean normalisation that do not read
    the atoms. *)

module Pairs : Hashtbl.S with type key = int * int
(** Tables by pairs of numbers. *)

val combine_ids : ('t -> int) -> int -> 't list -> int
(** [combine_ids id tag rs] is a hash of the numbers [id r] of the operands [rs]
    of an operation of tag [tag]. *)

(** The hash-consing of the forms [Form.t] of the views [View.t] (Filliâtre and
    Conchon, ML Workshop 2006), the views being built of forms identified by
    their numbers. *)
module HashCons
    (View : Hashtbl.HashedType)
    (Form : sig
      type t

      val build : int -> View.t -> t
      (** [build id view] is the form of [view] numbered [id]. *)
    end) : sig
  val make : View.t -> Form.t
  (** [make view] is the form of [view], built by [Form.build] on its first
      request with the number of the forms built before it, and the same form on
      every later request. *)
end

(** Expressions in normal form, as the Boolean normalisation reads them. *)
module type FORM = sig
  type t

  val id : t -> int
  (** [id r] is the number of the normal form [r]. *)

  val nullable : t -> bool
  (** [nullable r] is whether the empty word is in [r]. *)

  val eps : t
  (** The empty word. *)

  val compl_operand : t -> t option
  (** [compl_operand r] is [Some s] if [r] is the complement [~s]. *)

  val star_operand : t -> t option
  (** [star_operand r] is [Some s] if [r] is the repetition [s*]. *)
end

(** The rules of the Boolean normalisation over [E]. *)
module Boolean (E : FORM) : sig
  val equal_form : E.t -> E.t -> bool
  (** [equal_form r s] is whether [r] and [s] are the same normal form. *)

  val mem_form : E.t -> E.t list -> bool
  (** [mem_form r rs] is whether the normal form [r] is among [rs]. *)

  val flatten : (E.t -> E.t list option) -> E.t list -> E.t list
  (** [flatten split rs] is the operands of the n-ary operation of the operands
      [rs], by [split]: [Some rs'] to replace an operand by [rs']. *)

  val merge :
    (E.t -> 'a option) ->
    ('a -> 'a -> 'a) ->
    ('a -> E.t) ->
    E.t list ->
    E.t list
  (** [merge part combine build rs] merges the operands [rs] that [part] maps to
      a value into the value they combine to by [combine], built by [build] and
      listed first. *)

  val complementary : (E.t -> E.t list option) -> E.t list -> bool
  (** [complementary split rs] is whether some operand of [rs] is the complement
      of another, or of the operation that [split] splits into operands, all of
      them among [rs]: the operands of a flattened union or intersection. *)

  val subsumed : E.t list -> E.t -> bool
  (** [subsumed rs r] is whether the operand [r] of a union is contained in
      another operand [s] of [rs] by one of the laws [0 ⊆ s] for a nullable [s]
      and [r ⊆ r*]. *)

  val collect : (E.t -> E.t list) -> (E.t -> 'a list) -> E.t list -> 'a list
  (** [collect children leaves roots] is the values [leaves r] of the
      expressions [r] reachable from [roots] by [children], each expression
      visited once, in no particular order. *)
end

(** {1 Structural recursion}

    The sets of delays and the gap derivatives are defined by recursion on the
    operations of the expressions, and differ only at their atoms. *)

(** The top operation of an expression: an atom, the expression itself, or an
    operation on expressions. *)
type 't node =
  | Atom of 't
  | Empty
  | Eps
  | Concat of 't * 't
  | Union of 't list
  | Inter of 't list
  | Compl of 't
  | Star of 't

(** Expressions in normal form, as the structural recursions read them. *)
module type STRUCTURE = sig
  type t

  val id : t -> int
  (** [id r] is the number of the normal form [r]. *)

  val node : t -> t node
  (** [node r] is the top operation of [r]. *)
end

(** The sets of delays of the expressions [E]. *)
module Delays (E : sig
  include STRUCTURE

  val atom_delays : t -> DelaySet.t
  (** [atom_delays a] is the set of the delays [d] such that the word [d] is in
      the atom [a]. *)

  val complement : DelaySet.t -> DelaySet.t
  (** [complement n] is the complement of [n] in the universe of the delays. *)
end) : sig
  val delays : E.t -> DelaySet.t
  (** [delays r] is the set of the delays [d] such that the word [d] is in [r],
      by structural recursion, memoised by expression: [N(r & ~s)] is
      [N(r) ∖ N(s)], and [N(~r)] the complement of [N(r)]. *)
end

(** The gap derivatives of the expressions [E] by the blocks of names [E.block].
*)
module Gaps (E : sig
  include STRUCTURE
  include GapMap.EXPRESSION with type t := t

  type block

  val key : block -> int
  (** [key m] is the number of the block [m]. *)

  val meets : block -> t -> bool
  (** [meets m a] is whether the atom [a] has a one-operation word of a name of
      the block [m]. *)

  val eps : t
  val concat : t -> t -> t

  val delays : t -> DelaySet.t
  (** [delays r] is the set of the delays [d] such that the word [d] is in [r].
  *)
end) : sig
  val gap : E.block -> E.t -> E.t GapMap.t
  (** [gap m r] is the derivative of [r] by the words [d a], [d] a delay and [a]
      a name of [m], symbolic in [d]: a symbolic derivative over the Boolean
      algebra of the finite unions of products of sets of delays and blocks of
      names (D'Antoni and Veanes, POPL 2014), with the derivatives of
      concatenation and repetition of Brzozowski (JACM 1964), the delays before
      the name read by [E.delays]. Memoised by block and expression. *)
end
