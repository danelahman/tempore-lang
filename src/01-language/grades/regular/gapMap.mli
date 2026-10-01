(** Maps from delays to expressions, the values of gap derivatives.

    A map is a list of pairs [(S, e)], the sets of delays [S] non-empty and
    pairwise disjoint, the expressions [e] pairwise distinct, not the empty
    language and ordered by their numbers; a delay in none of the sets is mapped
    to the empty language. The delays range over a universe, the set of all
    delays of the words: the integers for words over whole time steps, the
    non-negative rationals for timed words. The operations are pointwise, and
    keep the maps in this form. *)

type 'e t = (DelaySet.t * 'e) list
(** A map from delays to expressions of type ['e]. *)

val support : 'e t -> DelaySet.t
(** [support f] is the union of the sets of delays of [f]. *)

val targets : absent:'e -> 'e t -> 'e t -> ('e * 'e) list
(** [targets ~absent f g] is the pairs [(f(d), g(d))] over all delays [d] of the
    supports of [f] and [g], each pair once per pair of entries meeting at [d],
    an absent delay being mapped to [absent]: the pairs of the entries of [f]
    and [g] whose sets intersect, then those of the entries of [f] not contained
    in the support of [g], paired with [absent], then likewise for [g]. *)

(** The expressions of the maps and the universe of their delays. *)
module type EXPRESSION = sig
  type t

  val universe : DelaySet.t
  (** The set of all delays. *)

  val empty : t
  val top : t
  val union : t list -> t
  val inter : t list -> t
  val compl : t -> t

  val compare_form : t -> t -> int
  (** The order of the expressions by their numbers. *)
end

module Make (E : EXPRESSION) : sig
  val normalise : E.t t -> E.t t
  (** [normalise entries] is the map of the pairs [entries], whose sets are
      pairwise disjoint: the pairs of an empty set or of the empty language left
      out, those of one expression merged. *)

  val full : E.t t
  (** [full] maps every delay of the universe to the language of all words, the
      unit of {!meet}. *)

  val join : E.t t -> E.t t -> E.t t
  (** [join f g] is the pointwise union of the maps [f] and [g]. *)

  val meet : E.t t -> E.t t -> E.t t
  (** [meet f g] is the pointwise intersection of the maps [f] and [g]. *)

  val complement : E.t t -> E.t t
  (** [complement f] is the pointwise complement of the map [f], an absent delay
      of the universe being mapped to the language of all words. *)

  val shift : DelaySet.t -> E.t t -> E.t t
  (** [shift n f] is the map of [f] with its sets of delays summed with [n], the
      expressions of a delay reached from several entries joined by union. *)
end
