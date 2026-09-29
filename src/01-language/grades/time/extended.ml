(** Delays extended with a greatest element [∞]. *)

(** The delays [D] with a greatest element [∞], absorbing for the sum. *)
module Make (D : Delay.ORDERED) = struct
  type t = Fin of D.t  (** a delay *) | Inf  (** the greatest element [∞] *)

  (** [add m n] is the sum of [m] and [n]; [∞] is absorbing. *)
  let add m n = match (m, n) with Fin m, Fin n -> Fin (D.add m n) | _ -> Inf

  (** [leq m n] decides [m ≤ n]. *)
  let leq m n =
    match (m, n) with
    | _, Inf -> true
    | Inf, Fin _ -> false
    | Fin m, Fin n -> D.leq m n

  (** [compare m n] orders the representations, [∞] last. *)
  let compare m n =
    match (m, n) with
    | Fin m, Fin n -> D.compare m n
    | Fin _, Inf -> -1
    | Inf, Fin _ -> 1
    | Inf, Inf -> 0

  (** [equal m n] decides [m = n]. *)
  let equal m n =
    match (m, n) with
    | Fin m, Fin n -> D.equal m n
    | Inf, Inf -> true
    | Fin _, Inf | Inf, Fin _ -> false

  let hash = function Fin n -> D.hash n | Inf -> -1

  (** [max m n] is the greater of [m] and [n]. *)
  let max m n = match (m, n) with Fin m, Fin n -> Fin (D.max m n) | _ -> Inf

  (** [to_fin n] is [Some n] for a delay and [None] for [∞]. *)
  let to_fin = function Fin n -> Some n | Inf -> None

  (** [show n] prints a delay by [D.show] and [∞] as [∞]. *)
  let show = function Fin n -> D.show n | Inf -> "∞"
end
