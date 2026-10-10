(** Symbols: names with an identity of their own. *)

module type S = sig
  type t

  val compare : t -> t -> int
  (** A total order on the identities of the symbols. *)

  val equal : t -> t -> bool
  (** [equal s1 s2] is whether [s1] and [s2] have the same identity. *)

  val fresh : string -> t
  (** [fresh name] is a symbol of a new identity, named [name]. *)

  val fresh_synthetic : string -> t
  (** A symbol the compiler invented rather than read from the source, such as a
      variable the desugarer binds to hoist a subcomputation. Error messages
      must never name one. *)

  val is_synthetic : t -> bool
  (** Whether the symbol came from {!fresh_synthetic}, directly or through
      {!refresh}. *)

  val refresh : t -> t
  (** [refresh s] is a symbol of a new identity with the name and the provenance
      of [s]. *)

  val print : t -> Format.formatter -> unit
  (** Prints the name of the symbol. *)

  val string_of : t -> string
  (** The name of the symbol. *)
end

module Make () : S
(** A fresh family of symbols, with identities of its own. *)
