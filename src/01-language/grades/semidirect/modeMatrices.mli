(** Matrices over the modes of a device, indexed by pairs of a start and an end
    mode, with entries in a semiring: the representation shared by
    {!ModeSwitchCostGrades} and {!ModeTimeGrades}.

    Besides the ordinary modes there is the absorbing mode {!stuck}: the only
    entry from it is the unit, to itself. A matrix names finitely many modes and
    treats all the others alike, and there are infinitely many of these. An
    entry may record a quantity per mode, such as the time spent in each; the
    entries of the modes not named are kept for representatives of them,
    {!other} and {!another}, and read for any mode not named by renaming the
    representatives ({!ENTRY.rename}). The product is the matrix product over
    the semiring, the sum of the entries being their join, and the order is
    entrywise. *)

(** The semiring of the entries. The entries are those of a start and an end
    mode, and may name modes, a mode not named by an entry having the value an
    entry gives every mode it does not name. *)
module type ENTRY = sig
  type t

  val zero : t
  (** No trace: the unit of {!add}, absorbing for {!mul}. *)

  val one : t
  (** The empty trace: the unit of {!mul}. *)

  val is_zero : t -> bool
  (** [is_zero e] is whether [e] is {!zero}. *)

  val add : t -> t -> t
  (** The join, associative, commutative and idempotent. *)

  val mul : t -> t -> t
  (** Sequencing, associative and distributing over {!add}. *)

  val leq : t -> t -> bool
  (** The order, of which {!add} is the join. *)

  val equal : t -> t -> bool
  (** The equivalence of {!leq}. *)

  val compare : t -> t -> int
  (** A total order on the representations, [0] only on equal entries. *)

  val hash : t -> int
  (** A hash compatible with {!compare}. *)

  val rename : (string -> string) -> t -> t
  (** [rename f e] is [e] with each mode [p] it names renamed [f p], [f] being
      injective on them. *)

  val project : string list -> t -> t
  (** [project modes e] is [e] naming exactly the modes [modes], each mode it
      names besides being taken as one of the modes not named: the join over the
      renamings of such a mode to any mode not named. *)
end

val stuck : string
(** The absorbing mode, ["Stuck"]. *)

val other : string
(** The representative of a mode not named. *)

val another : string
(** The representative of a mode not named other than {!other}. *)

module Make (E : ENTRY) : sig
  type t = {
    modes : string list;  (** the modes named, sorted *)
    within : ((string * string) * E.t) list;
        (** the entries between two modes named *)
    leaving : (string * E.t) list;
        (** from a mode named to {!other}, a mode not named *)
    entering : (string * E.t) list;
        (** from {!other}, a mode not named, to a mode named *)
    staying : E.t;  (** from {!other} to itself *)
    moving : E.t;  (** from {!other} to {!another} *)
    to_stuck : (string * E.t) list;  (** from a mode named into {!stuck} *)
    other_to_stuck : E.t;  (** from {!other} into {!stuck} *)
  }
  (** A matrix. The entries that are {!E.zero} are omitted from the lists, and
      the entries name the modes named and the representatives of their
      positions. A mode whose entries are those of a mode not named is not
      named, so that equal matrices have equal representations. *)

  val entry : t -> string -> string -> E.t
  (** [entry m p q] is the entry of [m] from the mode [p] to the mode [q], the
      representatives renamed to [p] and [q]. *)

  val make : string list -> (string -> string -> E.t) -> t
  (** [make modes f] is the matrix over the modes named [modes] whose entry from
      [p] to [q] is [f p q], [f] treating alike the modes not among [modes] and
      the representatives. *)

  val mul : t -> t -> t
  (** The matrix product: the entry from [p] to [r] is the join over the modes
      [q] of the entry from [p] to [q] followed by that from [q] to [r]. *)

  val join : t -> t -> t
  (** The entrywise join. *)

  val leq : t -> t -> bool
  (** The entrywise order. *)

  val equal : t -> t -> bool
  (** The equivalence of {!leq}. *)

  val compare : t -> t -> int
  (** The order of the representations, field by field, lexicographically. *)

  val hash : t -> int
  (** A hash over all the fields, compatible with {!compare}. *)
end
