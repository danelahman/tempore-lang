(** Delays extended with a greatest element [∞]. *)

(** The delays [D] with a greatest element [∞], absorbing for the sum. *)
module Make (D : Delay.ORDERED) : sig
  type t = Fin of D.t  (** a delay *) | Inf  (** the greatest element [∞] *)

  val add : t -> t -> t
  (** [add m n] is the sum of [m] and [n]; [∞] is absorbing. *)

  val leq : t -> t -> bool
  (** [leq m n] decides [m ≤ n]. *)

  val compare : t -> t -> int
  (** [compare m n] orders the representations, [∞] last. *)

  val equal : t -> t -> bool
  (** [equal m n] decides [m = n]. *)

  val hash : t -> int
  (** A hash compatible with {!equal}. *)

  val max : t -> t -> t
  (** [max m n] is the greater of [m] and [n]. *)

  val to_fin : t -> D.t option
  (** [to_fin n] is [Some n] for a delay and [None] for [∞]. *)

  val show : t -> string
  (** [show n] prints a delay by [D.show] and [∞] as [∞]. *)
end
