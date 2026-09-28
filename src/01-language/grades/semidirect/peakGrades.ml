type bound = Minus_inf | Fin of int | Plus_inf

(** [add b b'] is the sum of [b] and [b']; [-∞] is absorbing, and then [∞]. *)
let add b b' =
  match (b, b') with
  | Minus_inf, _ | _, Minus_inf -> Minus_inf
  | Plus_inf, _ | _, Plus_inf -> Plus_inf
  | Fin d, Fin d' -> Fin (d + d')

let rank = function Minus_inf -> 0 | Fin _ -> 1 | Plus_inf -> 2

let compare b b' =
  match (b, b') with
  | Fin d, Fin d' -> Int.compare d d'
  | _ -> Int.compare (rank b) (rank b')

let leq b b' = compare b b' <= 0
let max b b' = if leq b b' then b' else b
let hash = function Minus_inf -> -2 | Fin d -> Int.hash d | Plus_inf -> -1

let show = function
  | Minus_inf -> "-∞"
  | Fin d -> string_of_int d
  | Plus_inf -> "∞"

(** [bound_of_lit expected lit] is the integer or [∞] the literal [lit] denotes;
    any other form is rejected as not the [expected] one. *)
let bound_of_lit expected = function
  | Grade.Int d -> Fin d
  | Grade.Inf | Grade.Top -> Plus_inf
  | lit ->
      Grade.invalid_lit lit "%s are integers or '∞', not %s" expected
        (Grade.describe_lit lit)

module NetChange = struct
  type t = bound

  let name = "net-change"
  let one = Fin 0
  let mul = add
  let leq _bounds = leq
  let leq_symbol = "<="
  let top = Plus_inf
  let join = max

  let of_nat n =
    let (_ : int) = Grade.check_nat "PeakGrades.NetChange" n in
    one

  let equal _bounds b b' = compare b b' = 0
  let is_top _bounds b = compare b top = 0
  let compare = compare
  let hash = hash
  let counterexample _bounds _ _ = None
  let unit_least = false
  let commutative = true
  let needs_op_bounds = false
  let implied_bounds _bounds _ = None
  let inhabited _bounds _ = true
  let events _ = []
  let of_lit = bound_of_lit "net changes"
  let of_bounds _ = one
  let is_atomic _name _ = true
  let show = show
  let witnesses ~degree:_ _bounds cs = Grade.sampled mul cs
end

module Peak = struct
  type t = bound

  let name = "peak"
  let bottom = Minus_inf
  let top = Plus_inf
  let join = max
  let leq = leq
  let compare = compare
  let hash = hash
  let of_lit = bound_of_lit "peaks"
  let show = show
end

module Shift = struct
  type m = bound
  type n = bound

  let act d h = match h with Minus_inf -> Minus_inf | h -> add d h
end

module Product = GradeConstructions.SemiDirect (NetChange) (Peak) (Shift)

module OneResource = struct
  include Product

  let name = "resource-peak"
  let one = (Fin 0, Fin 0)

  let of_nat n =
    let (_ : int) = Grade.check_nat "PeakGrades.OneResource" n in
    one

  let of_bounds _ = one

  let of_lit = function
    | Grade.Top -> top
    | Grade.Tuple [ l1; l2 ] as lit -> (
        let d =
          Grade.component_of_lit lit ~context:"in the net change, "
            NetChange.of_lit l1
        in
        let h =
          Grade.component_of_lit lit ~context:"in the peak, " Peak.of_lit l2
        in
        match (d, h) with
        | Plus_inf, Plus_inf -> top
        | Plus_inf, _ ->
            Grade.invalid_lit lit "a net change '∞' needs a peak '∞'"
        | _ when Peak.leq (Peak.join (Fin 0) d) h -> (d, h)
        | _ ->
            Grade.invalid_lit lit
              "the peak must be at least 0 and at least the net change")
    | lit ->
        Grade.invalid_lit lit
          "grades are pairs '(d, h)' of a net change and a peak, not %s"
          (Grade.describe_lit lit)

  let show (d, h) = "(" ^ Peak.show d ^ "," ^ Peak.show h ^ ")"

  (* The grid of the net changes within one of the sum of the constants, each
     with a few peaks at and above its least one. *)
  let witnesses ~degree:_ _bounds cs =
    let magnitude = function Fin d -> Int.abs d | Minus_inf | Plus_inf -> 0 in
    let s =
      List.fold_left (fun s (d, h) -> s + magnitude d + magnitude h) 0 cs
    in
    let at d =
      let least = Int.max 0 d in
      List.sort_uniq compare
        (List.map (fun h -> (Fin d, h)) [ Fin least; Fin (least + 1); Plus_inf ]
        @ if s + 1 >= least then [ (Fin d, Fin (s + 1)) ] else [])
    in
    ( List.concat_map at (List.init ((2 * s) + 3) (fun i -> i - s - 1)),
      Grade.Partial )
end

module PeakUsage = struct
  include GradeConstructions.Indexed.OfGrade (OneResource)

  let name = "peak-usage"
end
