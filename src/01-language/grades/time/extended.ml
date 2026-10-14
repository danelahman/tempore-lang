module Make (D : Delay.ORDERED) = struct
  type t = Fin of D.t | Inf

  let add m n = match (m, n) with Fin m, Fin n -> Fin (D.add m n) | _ -> Inf

  let leq m n =
    match (m, n) with
    | _, Inf -> true
    | Inf, Fin _ -> false
    | Fin m, Fin n -> D.leq m n

  let compare m n =
    match (m, n) with
    | Fin m, Fin n -> D.compare m n
    | Fin _, Inf -> -1
    | Inf, Fin _ -> 1
    | Inf, Inf -> 0

  let equal m n =
    match (m, n) with
    | Fin m, Fin n -> D.equal m n
    | Inf, Inf -> true
    | Fin _, Inf | Inf, Fin _ -> false

  let hash = function Fin n -> D.hash n | Inf -> -1
  let max m n = match (m, n) with Fin m, Fin n -> Fin (D.max m n) | _ -> Inf
  let to_fin = function Fin n -> Some n | Inf -> None
  let show = function Fin n -> D.show n | Inf -> "∞"
end
