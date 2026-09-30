open GradeLiteral

type completeness = Complete | Partial

module type S = sig
  type t

  val zero : t
  val add : t -> t -> t
  val read : lit -> t option
  val rejection : lit -> string
  val equal : t -> t -> bool
  val compare : t -> t -> int
  val hash : t -> int
  val show : t -> string
  val adjacent : lower:bool -> Rational.t -> Rational.t option
end

module type ORDERED = sig
  include S

  val leq : t -> t -> bool
  val min : t -> t -> t
  val max : t -> t -> t
  val witnesses : degree:int -> t list -> t list * completeness
end

module type MONUS = sig
  include ORDERED

  val monus : t -> t -> t
end

module type MEASURED = sig
  include MONUS

  val to_rational : t -> Rational.t
end

module type STEPPED = sig
  include MEASURED

  val step : t
  val steps : int -> t
  val to_int : t -> int
end

(** [negative lit] is whether [lit] is the literal of a negative number. *)
let negative = function
  | Int n -> n < 0
  | Rat q -> Rational.sign q < 0
  | _ -> false

(* Completeness of the witnesses. An expression over the constants [cs], a
   variable [j], sums and one of minima or maxima is the minimum or maximum of
   affine pieces [c + a·j], [a ∈ ℕ] and [c] a sum of some of the constants,
   so that [c ≤ s] for [s] the sum of the constants. Two pieces of different
   slopes cross at [j = (c' - c) / (a - a') ≤ s], so beyond [s] each side of
   an ordering is one piece and their difference keeps its sign: the ordering
   fails at some [j] iff it fails at some [j ≤ s+1]. The argument is for one
   variable; for several no grid is complete, e.g. [j₂ ≥ min(j₁, 2·j₂)] fails
   at [(2, 1)] but nowhere in [{0, 1}²]. *)
module Nat = struct
  type t = int

  let zero = 0
  let add = ( + )
  let step = 1

  let steps n =
    if n < 0 then invalid_arg "Delay.Nat.steps: expected non-negative integer"
    else n

  let read = function
    | Int n when n >= 0 -> Some n
    | Rat q when Rational.sign q >= 0 -> Rational.to_int q
    | _ -> None

  let rejection = function
    | lit when negative lit -> "delays are non-negative"
    | Rat q when Rational.is_integer q ->
        Printf.sprintf "delays are at most %d time steps" max_int
    | _ -> "delays are whole numbers of time steps"

  let equal = Int.equal
  let compare = Int.compare
  let hash = Int.hash
  let show = string_of_int
  let leq (d : int) e = d <= e
  let min = Int.min
  let max = Int.max

  (** [0, ..., s+1], [s] the sum of [cs]. *)
  let witnesses ~degree:_ cs =
    (List.init (List.fold_left ( + ) 0 cs + 2) Fun.id, Complete)

  let monus d e = Int.max 0 (d - e)
  let to_rational = Rational.of_int
  let to_int d = d

  let adjacent ~lower q =
    let q' = Rational.add q (Rational.of_int (if lower then 1 else -1)) in
    if Rational.sign q' < 0 then None else Some q'
end

(* Completeness of the witnesses. As for the natural numbers, each side of an
   ordering is the maximum or minimum of pieces [c + a·j], with [c ∈ (1/D)ℕ],
   [c ≤ s], and [a ≤ K] the number of occurrences of [j] on that side. The
   kinks of a side and the crossings of the two sides lie where two pieces
   meet, at [j = (c' - c)/(a - a')] with [0 ≤ c' - c ≤ s] and
   [1 ≤ a - a' ≤ K]: in the grid [G]. Between two consecutive elements of [G],
   and beyond its greatest, [s], both sides are affine and their difference
   keeps its sign, so an ordering that fails at some [j] fails at an element
   of [G], at the midpoint of an open cell or at [s+1]. No finite set of
   witnesses depending on the constants alone is complete for every degree:
   [1 + j ≤ 1 ⊔ k·j] fails exactly on [(0, 1/(k-1))]. *)

let rec gcd m n = if n = 0 then m else gcd n (m mod n)
let lcm m n = m / gcd m n * n

(** [grid ~degree cs] is the sorted witnesses of the delays [cs] and a rigid
    occurring at most [degree] times on either side. *)
let grid ~degree cs =
  let s = List.fold_left Rational.add Rational.zero cs in
  let d = List.fold_left (fun d c -> lcm d (Rational.denominator c)) 1 cs in
  let steps =
    Option.value ~default:0
      (Rational.to_int (Rational.mul s (Rational.of_int d)))
  in
  let g =
    List.sort_uniq Rational.compare
      (List.concat
         (List.init (Int.max 1 degree) (fun m ->
              List.init (steps + 1) (fun x -> Rational.make x (d * (m + 1))))))
  in
  let rec midpoints = function
    | a :: (b :: _ as rest) ->
        Rational.div (Rational.add a b) (Rational.of_int 2) :: midpoints rest
    | [ _ ] | [] -> []
  in
  List.sort_uniq Rational.compare
    ((Rational.add s (Rational.of_int 1) :: g) @ midpoints g)

module Rational = struct
  type t = Rational.t

  let zero = Rational.zero
  let add = Rational.add

  let read = function
    | Int n when n >= 0 -> Some (Rational.of_int n)
    | Rat q when Rational.sign q >= 0 -> Some q
    | _ -> None

  let rejection = function
    | lit when negative lit -> "delays are non-negative"
    | _ -> "delays are non-negative numbers of time steps"

  let equal = Rational.equal
  let compare = Rational.compare
  let hash = Rational.hash
  let show = Rational.show
  let leq p q = Rational.compare p q <= 0
  let min p q = if Rational.compare p q <= 0 then p else q
  let max p q = if Rational.compare p q >= 0 then p else q
  let witnesses ~degree cs = (grid ~degree cs, Complete)

  let monus p q =
    if Rational.compare p q <= 0 then Rational.zero
    else Rational.add p (Rational.neg q)

  let to_rational q = q
  let adjacent ~lower:_ _ = None
end
