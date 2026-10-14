(** Emptiness, inclusion and equivalence of the languages of expressions, by
    exploration of the graph of their derivatives.

    The states of the graph are normal forms, numbered; a state is final if the
    language of the expression has a word that the exploration reads off it
    without further derivatives, and two states agree if they have the same such
    words. The decisions depend on the expressions only through the operations
    of {!GRAPH}. *)

(** The graph of the derivatives of expressions. *)
module type GRAPH = sig
  type t

  type block
  (** A block of letters, by which the derivatives are taken. *)

  val id : t -> int
  (** [id r] is the number of the normal form [r], injective on normal forms:
      [id r = id s] iff [r] and [s] are the same normal form. *)

  val empty : t
  val is_top : t -> bool
  val inter : t list -> t
  val compl : t -> t

  val nullable : t -> bool
  (** [nullable r] is whether the empty word is in [r]. *)

  val final : t -> bool
  (** [final r] is whether [r] has a word read off it without derivatives. *)

  val agree : t -> t -> bool
  (** [agree r s] is whether [r] and [s] have the same words read off them
      without derivatives. *)

  val blocks : t list -> block list
  (** [blocks roots] is the blocks the derivatives of [roots] are taken by. *)

  val successors : block list -> t -> t list
  (** [successors ms r] is the derivatives of [r] the exploration of the
      emptiness of [r] follows, by the blocks [ms]: [r] has a word iff it is
      final or one of them has. *)

  val pairs : block list -> t -> t -> (t * t) list
  (** [pairs ms r s] is the pairs of derivatives of [r] and [s] by the same
      words the exploration of the equivalence of [r] and [s] follows, by the
      blocks [ms]: if [r] and [s] agree, they denote the same language iff the
      two expressions of each pair do. *)
end

(** The decisions over [G], with their own tables of the emptiness and
    equivalence of the expressions explored. *)
module Make (G : GRAPH) : sig
  val known_empty : G.t -> bool
  (** [known_empty r] is whether [r] is recorded as empty. *)

  val record : G.t -> (int, 'a) Hashtbl.t -> bool -> unit
  (** [record r seen found] records [r] as not empty if [found], and otherwise
      every expression of [seen], by its number, as empty. *)

  val is_empty : G.t -> bool
  (** [is_empty r] is whether [r] has no words, decided by depth-first
      exploration of {!GRAPH.successors}, which stops at the first final
      expression; the expressions known to be empty are not explored, and if
      none is final every expression explored is recorded as empty. *)

  val subset : G.t -> G.t -> bool
  (** [subset r s] is whether [r ⊆ s], i.e. whether [r & ~s] is empty. *)

  val equal : G.t -> G.t -> bool
  (** [equal r s] is whether [r] and [s] denote the same language, decided by
      Hopcroft and Karp's algorithm (Cornell TR 1971): the pairs of
      {!GRAPH.pairs} are explored breadth-first, until the expressions of a pair
      do not agree or no pair is left, a bisimulation up to equivalence whose
      classes are kept in a union–find forest with path compression. The results
      are recorded by the pair of the numbers of [r] and [s]. *)
end
