(** Hashes of compound values from the hashes of their components, combined
    multiplicatively as in the sdbm hash: [combine h h' = h · 65599 + h']. *)

val combine : int -> int -> int
(** [combine h h'] is a hash of a pair whose components hash to [h] and [h']. *)

val list : ('a -> int) -> 'a list -> int
(** [list hash xs] is a hash of the list [xs] whose elements hash by [hash]. *)
