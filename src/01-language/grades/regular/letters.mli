(** Letter sets: the sets of letters of the regular expressions over operation
    names and [tick], each a finite or cofinite set of names, with or without
    [tick]. *)

(** A finite set of names, or the complement of one. *)
type names =
  | Only of string list  (** The names listed, in increasing order *)
  | Except of string list
      (** Every name except those listed, in increasing order *)

type t = private { tick : bool; names : names }
(** The letter set containing [tick] iff [tick] holds, and the [names]. *)

val equal : t -> t -> bool
val compare : t -> t -> int

val hash : t -> int
(** A hash compatible with {!equal}. *)

val empty : t
(** The empty letter set. *)

val any : t
(** The set of all letters. *)

val tick : t
(** The set [{tick}]. *)

val name : string -> t
(** [name n] is the set [{n}]. *)

val others : string list -> t
(** [others names] is the set of the names not among [names]; the names are
    sorted and their duplicates removed. *)

val union : t -> t -> t
val inter : t -> t -> t

val compl : t -> t
(** [compl p] is the set of the letters not in [p]. *)

val is_empty : t -> bool

val mentioned : t -> string list
(** [mentioned p] is the names [p] lists, those it contains or those it leaves
    out. *)

val order : t -> t -> int
(** [order p q] orders letter sets by their least letter: [tick], then the names
    in increasing order, then the names a finite set of names leaves out; it is
    a total order. *)

val partition : t list -> t list
(** [partition sets] is the coarsest partition of the letters into non-empty
    sets that the letter sets [sets] respect, each of them a union of blocks;
    the blocks are listed by {!order}. *)
