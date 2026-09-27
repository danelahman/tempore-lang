module type LATTICE = sig
  type t

  val name : string
  val bottom : t
  val top : t
  val join : t -> t -> t
  val leq : t -> t -> bool
  val of_lit : Grade.lit -> t
  val show : t -> string
end

module OfLattice (L : LATTICE) = struct
  type t = L.t

  let name = L.name
  let one = L.bottom
  let mul = L.join
  let leq _bounds = L.leq
  let leq_symbol = "<="
  let top = L.top
  let join = L.join

  let of_nat n =
    let (_ : int) = Grade.check_nat L.name n in
    L.bottom

  let equal _bounds l l' = L.leq l l' && L.leq l' l
  let unit_least = true
  let commutative = true
  let needs_op_bounds = false
  let implied_bounds _bounds _ = None
  let events _ = []
  let of_lit = function Grade.Top -> L.top | lit -> L.of_lit lit
  let of_bounds _ = L.bottom
  let is_atomic _name _ = true
  let show = L.show
end

(** [intersect b b'] is the intersection of the runtime bounds [b] and [b'],
    either possibly absent. *)
let intersect b b' =
  match (b, b') with
  | Some (lo, hi), Some (lo', hi') -> Some (Int.max lo lo', Int.min hi hi')
  | Some b, None | None, Some b -> Some b
  | None, None -> None

module Product (G1 : Grade.S) (G2 : Grade.S) = struct
  type t = G1.t * G2.t

  let name = G1.name ^ "×" ^ G2.name
  let one = (G1.one, G2.one)
  let mul (a, b) (a', b') = (G1.mul a a', G2.mul b b')
  let leq bounds (a, b) (a', b') = G1.leq bounds a a' && G2.leq bounds b b'
  let leq_symbol = if G1.leq_symbol = G2.leq_symbol then G1.leq_symbol else "≾"
  let top = (G1.top, G2.top)
  let join (a, b) (a', b') = (G1.join a a', G2.join b b')
  let of_nat n = (G1.of_nat n, G2.of_nat n)

  let equal bounds (a, b) (a', b') =
    G1.equal bounds a a' && G2.equal bounds b b'

  let unit_least = G1.unit_least && G2.unit_least
  let commutative = G1.commutative && G2.commutative
  let needs_op_bounds = G1.needs_op_bounds || G2.needs_op_bounds

  let implied_bounds bounds (a, b) =
    intersect (G1.implied_bounds bounds a) (G2.implied_bounds bounds b)

  let events (a, b) = List.sort_uniq String.compare (G1.events a @ G2.events b)

  let of_lit = function
    | Grade.Top -> top
    | Grade.Tuple [ l1; l2 ] as lit ->
        let component ordinal name =
          Printf.sprintf "in the %s component ('%s'), " ordinal name
        in
        let a =
          Grade.component_of_lit lit
            ~context:(component "first" G1.name)
            G1.of_lit l1
        in
        let b =
          Grade.component_of_lit lit
            ~context:(component "second" G2.name)
            G2.of_lit l2
        in
        (a, b)
    | lit ->
        Grade.invalid_lit lit
          "grades are pairs '(g1, g2)' of a '%s' and a '%s' grade, not %s"
          G1.name G2.name (Grade.describe_lit lit)

  let of_bounds b = (G1.of_bounds b, G2.of_bounds b)
  let is_atomic name (a, b) = G1.is_atomic name a && G2.is_atomic name b
  let show (a, b) = "(" ^ G1.show a ^ "," ^ G2.show b ^ ")"
end
