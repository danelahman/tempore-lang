(** Memoisation tables.

    {2 Retention}

    A table holds every entry recorded in it for as long as the table itself is
    reachable: a table bound at module level for the run of the program, and a
    table created by a function, as by {!S.memoise}, for as long as the function
    it returns is. Tables are never cleared. Most keys are numbers of
    hash-consed normal forms, or values built of them, which the hash-consing
    tables retain for the run of the program in any case.

    The tables of {!Weak} and {!Weak2} are the one exception: they hold an entry
    only while its keys are reachable (ephemerons), for keys that are values
    retained by nothing else, such as sets of delays. *)

(** A table from keys to values. *)
module type S = sig
  type key
  type 'a t

  val create : int -> 'a t
  (** [create n] is an empty table of initial size [n]. *)

  val find_opt : 'a t -> key -> 'a option
  (** [find_opt table key] is the value recorded for [key], if any. *)

  val replace : 'a t -> key -> 'a -> unit
  (** [replace table key v] records [v] for [key], in place of any value
      recorded for it. *)

  val find_or_add : 'a t -> key -> (unit -> 'a) -> 'a
  (** [find_or_add table key compute] is the value recorded for [key], and
      otherwise [compute ()], recorded for [key]. *)

  val memoise : (key -> 'a) -> key -> 'a
  (** [memoise f] is [f], its results recorded by their arguments in a table of
      its own. *)
end

(** Tables by hashing, holding their keys strongly. *)
module Make (K : Hashtbl.HashedType) : S with type key = K.t

(** Tables by balanced search trees, holding their keys strongly, for keys that
    are ordered but not hashed. *)
module Ordered (K : Map.OrderedType) : S with type key = K.t

(** Tables by hashing whose entries last while their keys are reachable. *)
module Weak (K : Hashtbl.HashedType) : S with type key = K.t

(** Tables by hashing of pairs, whose entries last while both components of
    their keys are reachable. *)
module Weak2 (K1 : Hashtbl.HashedType) (K2 : Hashtbl.HashedType) :
  S with type key = K1.t * K2.t

module Ints : S with type key = int
(** Tables by numbers. *)

module Pairs : S with type key = int * int
(** Tables by pairs of numbers. *)

module Triples : S with type key = int * int * int
(** Tables by triples of numbers. *)
