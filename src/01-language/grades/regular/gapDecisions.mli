(** Decisions on expressions by their gap derivatives.

    The decisions explore the graph of gap derivatives of an expression: the
    states are normal forms, numbered, the edges those of the gap derivatives by
    the blocks of names of an alphabet of the start, labelled by sets of delays,
    and the final delays of a state its delays. They depend on the expressions
    only through the operations of {!EXPRESSION}. *)

(** The expressions, their delays and gap derivatives. *)
module type EXPRESSION = sig
  type t

  type block
  (** A block of names. *)

  val hash : t -> int
  (** [hash r] is the number of the normal form [r]. *)

  val empty : t
  val is_top : t -> bool
  val inter : t list -> t
  val compl : t -> t

  val nullable : t -> bool
  (** [nullable r] is whether the empty word is in [r]. *)

  val delays : t -> DelaySet.t
  (** [delays r] is the set of the delays [d] such that the word [d] is in [r].
  *)

  val gap : block -> t -> t GapMap.t
  (** [gap m r] maps each delay [d] to the derivative of [r] by [d] followed by
      any name of [m]. *)

  val blocks : t list -> block list
  (** [blocks roots] is the blocks of names the derivatives of [roots] are taken
      by. *)
end

(** The decisions over [E], with their own tables of the emptiness and equality
    of the expressions explored. *)
module Make (E : EXPRESSION) : sig
  val edges : E.block list -> E.t -> (DelaySet.t * E.block * E.t) list
  (** [edges ms r] is the gap derivatives of [r] by the blocks [ms], as triples
      of a set of delays, a block and an expression. *)

  val known_empty : E.t -> bool
  (** [known_empty r] is whether [r] is recorded as empty. *)

  val record : E.t -> (int, 'a) Hashtbl.t -> bool -> unit
  (** [record r seen found] records [r] as not empty if [found], and otherwise
      every expression of [seen], by its number, as empty. *)

  val is_empty : E.t -> bool
  (** [is_empty r] is whether [r] has no words, decided by depth-first
      exploration of its gap derivatives, which stops at the first expression
      with a delay; the expressions known to be empty are not explored. *)

  val subset : E.t -> E.t -> bool
  (** [subset r s] is whether [r ⊆ s], i.e. whether [r & ~s] is empty. *)

  val fewest_operations :
    E.t -> ((DelaySet.t * E.block) list * DelaySet.t) option
  (** [fewest_operations r] is [None] if [r] is empty, and otherwise a word of
      [r] with the fewest operations, as the sets it is read by: the pairs
      [(Sᵢ, mᵢ)] of the gap derivatives followed from [r], every word
      [d₀ a₁ ⋯ dₖ₋₁ aₖ dₖ] with [dᵢ₋₁ ∈ Sᵢ], [aᵢ ∈ mᵢ] and [dₖ] in the final set
      being in [r]. Found by breadth-first search of the gap derivatives by the
      blocks of [r], the edges in the order of {!edges}, stopped at the first
      expression with a delay. *)

  val equal : E.t -> E.t -> bool
  (** [equal r s] is whether [r] and [s] denote the same language, decided by
      Hopcroft and Karp's algorithm (Cornell TR 1971) on the gap derivatives:
      the pairs of gap derivatives of [r] and [s] by the same words are explored
      breadth-first, two expressions related only if they have the same delays,
      their gap derivatives by each block paired on the common refinement of
      their sets of delays, and the classes of the two expressions of each pair
      merged in a union–find forest with path compression. *)
end
