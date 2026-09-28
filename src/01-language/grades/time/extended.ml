(** Numbers extended with a greatest element [∞]. *)

(** Totally ordered commutative monoids. *)
module type NUMBERS = sig
  type t

  val add : t -> t -> t
  (** The sum. *)

  val compare : t -> t -> int
  (** The total order [≤], compatible with {!add}. *)

  val hash : t -> int
  (** A hash compatible with {!compare}. *)

  val show : t -> string
  (** [show n] prints [n]. *)
end

(** The numbers [N] with a greatest element [∞], absorbing for the sum. *)
module Make (N : NUMBERS) = struct
  type t = Fin of N.t  (** a number *) | Inf  (** the greatest element [∞] *)

  (** [add m n] is the sum of [m] and [n]; [∞] is absorbing. *)
  let add m n = match (m, n) with Fin m, Fin n -> Fin (N.add m n) | _ -> Inf

  (** [leq m n] decides [m ≤ n]. *)
  let leq m n =
    match (m, n) with
    | _, Inf -> true
    | Inf, Fin _ -> false
    | Fin m, Fin n -> N.compare m n <= 0

  (** [compare m n] is the order [≤]. *)
  let compare m n =
    match (m, n) with
    | Fin m, Fin n -> N.compare m n
    | Fin _, Inf -> -1
    | Inf, Fin _ -> 1
    | Inf, Inf -> 0

  let equal m n = compare m n = 0
  let hash = function Fin n -> N.hash n | Inf -> -1

  (** [max m n] is the greater of [m] and [n]. *)
  let max m n =
    match (m, n) with
    | Fin m, Fin n -> if N.compare m n >= 0 then Fin m else Fin n
    | _ -> Inf

  (** [to_fin n] is [Some n] for a number and [None] for [∞]. *)
  let to_fin = function Fin n -> Some n | Inf -> None

  (** [show n] prints a number by [N.show] and [∞] as [∞]. *)
  let show = function Fin n -> N.show n | Inf -> "∞"
end
