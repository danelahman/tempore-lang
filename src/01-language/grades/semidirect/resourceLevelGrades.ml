type bound = Minus_inf | Fin of int | Plus_inf

(** [sum d d'] is [d + d'], a net change beyond the integers being rejected. *)
let sum = Delay.checked_add ~quantity:"net change"

(** [add b b'] is the sum of [b] and [b'], an infinite summand absorbing the
    other; [-∞] and [∞] are never added together. *)
let add b b' =
  match (b, b') with
  | Minus_inf, _ | _, Minus_inf -> Minus_inf
  | Plus_inf, _ | _, Plus_inf -> Plus_inf
  | Fin d, Fin d' -> Fin (sum d d')

let rank = function Minus_inf -> 0 | Fin _ -> 1 | Plus_inf -> 2

let compare_bound b b' =
  match (b, b') with
  | Fin d, Fin d' -> Int.compare d d'
  | _ -> Int.compare (rank b) (rank b')

let hash_bound = function
  | Minus_inf -> -2
  | Fin d -> Int.hash d
  | Plus_inf -> -1

let min_bound b b' = if compare_bound b b' <= 0 then b else b'
let max_bound b b' = if compare_bound b b' <= 0 then b' else b

(* One side of the levels reached, upward or downward, named [name], its
   extremes named [extreme]: [leq] orders the bounds along it, [unbounded] is
   the greatest bound and [unreached] the least, the extreme of no level;
   [of_lit expected] reads a bound, [expected] naming the bounds in
   rejections, and [show] prints one. *)
module type ORIENTATION = sig
  val name : string
  val extreme : string
  val leq : bound -> bound -> bool
  val leq_symbol : string
  val unbounded : bound
  val unreached : bound
  val of_lit : string -> Grade.lit -> bound
  val show : bound -> string
end

(* The bounds of the net change on one side paired with the extremes there, a
   net change shifting a later extreme. *)
module Side (D : Delay.S) (O : ORIENTATION) = struct
  let join b b' = if O.leq b b' then b' else b

  module Net = struct
    type t = bound

    module Delay = D

    let name = O.name ^ "-net-change"
    let one = Fin 0
    let mul = add
    let leq _bounds = O.leq
    let leq_symbol = O.leq_symbol
    let top = O.unbounded
    let join = join
    let of_delay _ = one
    let equal _bounds b b' = compare_bound b b' = 0
    let is_top _bounds b = compare_bound b top = 0
    let compare = compare_bound
    let hash = hash_bound
    let counterexample _bounds _ _ = None
    let unit_least = false
    let commutative = true
    let needs_op_bounds = false
    let implied_bounds _bounds _ = None
    let inhabited _bounds _ = true
    let events _ = []
    let of_lit = O.of_lit "net changes"
    let of_bounds _ = one
    let is_atomic _name _ = true
    let show = O.show
    let witnesses ~degree:_ _bounds cs = Grade.sampled mul cs
  end

  module Extreme = struct
    type t = bound

    let name = O.extreme
    let bottom = O.unreached
    let top = O.unbounded
    let join = join
    let leq = O.leq
    let compare = compare_bound
    let hash = hash_bound
    let of_lit = O.of_lit (O.extreme ^ "s")
    let show = O.show
  end

  module Shift = struct
    type m = bound
    type n = bound

    let act d e = if compare_bound e O.unreached = 0 then e else add d e
  end

  include GradeConstructions.SemiDirect (Net) (Extreme) (Shift)
end

(* The levels reached upward, bounded by the peaks. *)
module Upward = struct
  let name = "upper"
  let extreme = "peak"
  let leq b b' = compare_bound b b' <= 0
  let leq_symbol = "<="
  let unbounded = Plus_inf
  let unreached = Minus_inf

  let of_lit expected = function
    | Grade.Int d -> Fin d
    | Grade.Inf | Grade.Top -> Plus_inf
    | lit ->
        Grade.invalid_lit lit "%s are integers or '∞', not %s" expected
          (Grade.describe_lit lit)

  let show = function
    | Minus_inf -> "-∞"
    | Fin d -> string_of_int d
    | Plus_inf -> "∞"
end

(* The levels reached downward, bounded by the troughs. *)
module Downward = struct
  let name = "lower"
  let extreme = "trough"
  let leq b b' = compare_bound b' b <= 0
  let leq_symbol = ">="
  let unbounded = Minus_inf
  let unreached = Plus_inf

  let of_lit expected = function
    | Grade.Int d -> Fin d
    | Grade.Top -> Minus_inf
    | lit ->
        Grade.invalid_lit lit "%s are integers or '⊤', not %s" expected
          (Grade.describe_lit lit)

  let show = function
    | Minus_inf -> "⊤"
    | Fin d -> string_of_int d
    | Plus_inf -> "∞"
end

module Make (D : Delay.S) = struct
  module Upper = Side (D) (Upward)
  module Lower = Side (D) (Downward)

  module OneResource = struct
    include GradeConstructions.Product (Lower) (Upper)

    let name = "one-resource-levels"
    let one = ((Fin 0, Fin 0), (Fin 0, Fin 0))
    let leq_symbol = "<="
    let of_delay _ = one
    let of_bounds _ = one

    (* The grade of the trough [t], the net change from [low] to [high],
     [low ≤ high], and the peak [h], if they satisfy [t ≤ min(0, low)] and
     [max(0, high) ≤ h]. *)
    let grade lit t (low, high) h =
      if compare_bound t (min_bound (Fin 0) low) > 0 then
        Grade.invalid_lit lit
          "the trough must be at most 0 and at most the net change"
      else if compare_bound (max_bound (Fin 0) high) h > 0 then
        Grade.invalid_lit lit
          "the peak must be at least 0 and at least the net change"
      else ((low, t), (high, h))

    (* An endpoint of a range of net changes, closed or [infinite]. *)
    let net_end infinite = function
      | Grade.Unbounded -> infinite
      | Grade.Closed (Grade.Int d) -> Fin d
      | Grade.Closed lit | Grade.Open lit ->
          Grade.invalid_lit lit "the ends of net changes are integers, not %s"
            (Grade.describe_lit lit)

    (* A range of net changes; an open endpoint abbreviates a closed one by
       [Grade.integer_ends], and a pair of integers is an open range. *)
    let net_of_lit lit =
      match Grade.open_pair lit with
      | Grade.Int d -> (Fin d, Fin d)
      | Grade.Interval (lo, hi) ->
          let lo, hi = Grade.integer_ends lit lo hi in
          (net_end Minus_inf lo, net_end Plus_inf hi)
      | lit ->
          Grade.invalid_lit lit
            "net changes are integers or ranges '[d1, d2]', not %s"
            (Grade.describe_lit lit)

    (* The grade of the literal [lit] of the trough [t], if given, the net change
     [l1] and the peak [l2]. *)
    let of_components lit t l1 l2 =
      let ((low, _) as net) =
        Grade.component_of_lit lit ~context:"in the net change, " net_of_lit l1
      in
      let h =
        Grade.component_of_lit lit ~context:"in the peak, " Upper.Extreme.of_lit
          l2
      in
      grade lit (Option.value t ~default:(min_bound (Fin 0) low)) net h

    let of_lit = function
      | Grade.Top -> top
      | Grade.Tuple [ (Grade.Inf | Grade.Top); l ] as lit -> (
          match
            Grade.component_of_lit lit ~context:"in the peak, "
              Upper.Extreme.of_lit l
          with
          | Plus_inf -> top
          | _ -> Grade.invalid_lit lit "a net change '∞' needs a peak '∞'")
      | Grade.Tuple [ l1; l2 ] as lit -> of_components lit None l1 l2
      | Grade.Tuple [ l0; l1; l2 ] as lit ->
          let t =
            Grade.component_of_lit lit ~context:"in the trough, "
              Lower.Extreme.of_lit l0
          in
          of_components lit (Some t) l1 l2
      | lit ->
          Grade.invalid_lit lit
            "grades are tuples '(d, h)' or '(t, d, h)' of a trough, a net \
             change and a peak, not %s"
            (Grade.describe_lit lit)

    (* The shortest literal: the trough is omitted where it is [min(0, low)],
     and an exact net change is written as a single integer; a range is
     closed at its finite ends. *)
    let show (((low, t), (high, h)) as c) =
      if compare c top = 0 then "(∞, ∞)"
      else
        let net =
          if compare_bound low high = 0 then Upper.Net.show high
          else
            (if compare_bound low Minus_inf = 0 then "(" else "[")
            ^ Upper.Net.show low ^ ", " ^ Upper.Net.show high
            ^ if compare_bound high Plus_inf = 0 then ")" else "]"
        in
        if compare_bound t (min_bound (Fin 0) low) = 0 then
          "(" ^ net ^ ", " ^ Upper.Net.show h ^ ")"
        else "(" ^ Lower.Net.show t ^ ", " ^ net ^ ", " ^ Upper.Net.show h ^ ")"

    (* The exact net changes within one of the sum [s] of the magnitudes of the
     finite components of the constants, each with its greatest trough and a
     few troughs below it, and with its least peak and a few peaks above it;
     and the ranges of net changes from or to each of them, the other end
     being the least or the greatest of them or unbounded, with their greatest
     trough and least peak. *)
    let witnesses ~degree:_ _bounds cs =
      let magnitude = function
        | Fin d -> Int.abs d
        | Minus_inf | Plus_inf -> 0
      in
      let s =
        List.fold_left
          (fun s ((low, t), (high, h)) ->
            List.fold_left sum s (List.map magnitude [ low; t; high; h ]))
          0 cs
      in
      let grid = List.init (sum (sum s s) 3) (fun i -> i - s - 1) in
      let range low high =
        ((low, min_bound (Fin 0) low), (high, max_bound (Fin 0) high))
      in
      let at d =
        let trough = Int.min 0 d and peak = Int.max 0 d in
        List.map
          (fun t -> ((Fin d, t), (Fin d, Fin peak)))
          [ Fin trough; Fin (trough - 1); Fin (-s - 1); Minus_inf ]
        @ List.map
            (fun h -> ((Fin d, Fin trough), (Fin d, h)))
            [ Fin (peak + 1); Fin (Int.max peak (s + 1)); Plus_inf ]
        @ List.filter_map
            (fun (low, high) ->
              if compare_bound low high < 0 then Some (range low high) else None)
            [
              (Fin d, Fin (s + 1));
              (Fin d, Plus_inf);
              (Fin (-s - 1), Fin d);
              (Minus_inf, Fin d);
            ]
      in
      (List.sort_uniq compare (List.concat_map at grid), Grade.Partial)
  end

  module ResourceLevels = struct
    include GradeConstructions.Indexed.OfGrade (OneResource)

    let name = "resource-levels"
  end
end

include Make (Delay.Nat)
