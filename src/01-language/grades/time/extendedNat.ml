(** Extended natural numbers [ℕ∞], the natural numbers with a greatest element
    [∞]. *)

type t =
  | Fin of int  (** a natural number, non-negative *)
  | Inf  (** the greatest element [∞] *)

(** [add m n] is the sum of [m] and [n]; [∞] is absorbing. *)
let add m n = match (m, n) with Fin m, Fin n -> Fin (m + n) | _ -> Inf

(** [leq m n] decides [m ≤ n]. *)
let leq m n =
  match (m, n) with
  | _, Inf -> true
  | Inf, Fin _ -> false
  | Fin m, Fin n -> m <= n

(** [compare m n] is the order [≤]. *)
let compare m n =
  match (m, n) with
  | Fin m, Fin n -> Int.compare m n
  | Fin _, Inf -> -1
  | Inf, Fin _ -> 1
  | Inf, Inf -> 0

let equal m n = compare m n = 0
let hash = function Fin n -> Int.hash n | Inf -> -1

(** [max m n] is the greater of [m] and [n]. *)
let max m n = match (m, n) with Fin m, Fin n -> Fin (Int.max m n) | _ -> Inf

(** [to_int n] is [Some n] for a natural number and [None] for [∞]. *)
let to_int = function Fin n -> Some n | Inf -> None

(** [show n] prints a natural number in decimal and [∞] as [∞]. *)
let show = function Fin n -> string_of_int n | Inf -> "∞"
