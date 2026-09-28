(* Completeness of the witnesses. As for the discrete grades, at a finite [j]
   each side of an ordering is the maximum (upper bounds) or minimum (lower
   bounds) of pieces [c + a·j], with [c ∈ (1/D)ℕ], [c ≤ s], and [a ≤ K] the
   number of occurrences of [j] on that side; a piece with an infinite
   constant is constantly [∞]. The kinks of a side and the crossings of the
   two sides lie where two pieces meet, at [j = (c' - c)/(a - a')] with
   [0 ≤ c' - c ≤ s] and [1 ≤ a - a' ≤ K]: in the grid [G]. Between two
   consecutive elements of [G], and beyond its greatest, [s], both sides are
   affine and their difference keeps its sign, so an ordering that fails at
   some [j] fails at an element of [G], at the midpoint of an open cell, at
   [s+1] or, for upper bounds, at [∞]. No finite set of witnesses depending on
   the constants alone is complete: [1 + j ≤ 1 ⊔ k·j] fails exactly on
   [(0, 1/(k-1))]. *)

let rec gcd m n = if n = 0 then m else gcd n (m mod n)
let lcm m n = m / gcd m n * n

(** [grid ~degree cs] is the sorted witnesses of the durations [cs] and a rigid
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

include TimeGrades.Make (struct
  type t = Rational.t

  let module_name = "DenseTimeGrades"
  let prefix = "dense-"
  let zero = Rational.zero
  let add = Rational.add
  let compare = Rational.compare
  let hash = Rational.hash
  let of_int = Rational.of_int

  let of_duration q =
    if Rational.sign q < 0 then
      invalid_arg "DenseTimeGrades.of_duration: expected non-negative duration"
    else q

  let read = function
    | Grade.Int n -> Some (Rational.of_int n)
    | Grade.Rat q -> Some q
    | _ -> None

  let numbers = "numbers"
  let show = Rational.show
  let witnesses = grid
end)
