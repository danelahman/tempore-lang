(* The counts bounded by the time grades [C], name by name, delays counting
   nothing. *)
module Counts (C : Grade.S) =
  GradeConstructions.Untimed (GradeConstructions.Indexed.OfGrade (C))

(* [of_counts (module C) counts] is the map giving each operation of the list
   [counts] of operations and numbers of calls the delay of its number in
   [C], and every other operation the unit. *)
let of_counts (type a)
    (module C : Grade.S with type t = a and type Delay.t = int) counts =
  GradeConstructions.Indexed.of_list ~compare:C.compare ~others:C.one
    (List.map (fun (name, n) -> (name, C.of_delay n)) counts)

module AtMost = struct
  include Counts (TimeGrades.UpperBound)

  let name = "at-most-counts"
  let of_counts = of_counts (module TimeGrades.UpperBound)
end

module AtLeast = struct
  include Counts (TimeGrades.LowerBound)

  let name = "at-least-counts"
  let of_counts = of_counts (module TimeGrades.LowerBound)
end

module AtLeastWithTop = struct
  type t = Counted of AtLeast.t | Top

  module Delay = AtLeast.Delay

  let name = "at-least-counts-with-top"
  let one = Counted AtLeast.one
  let top = Top

  (* [lift f] is the binary operation [f] of the at-least counts, absorbed by
     [Top]. *)
  let lift f c d =
    match (c, d) with Counted c, Counted d -> Counted (f c d) | _ -> Top

  let mul = lift AtLeast.mul
  let join = lift AtLeast.join

  let leq bounds c d =
    match (c, d) with
    | _, Top -> true
    | Top, Counted _ -> false
    | Counted c, Counted d -> AtLeast.leq bounds c d

  let leq_symbol = AtLeast.leq_symbol

  let equal bounds c d =
    match (c, d) with
    | Top, Top -> true
    | Counted c, Counted d -> AtLeast.equal bounds c d
    | Top, Counted _ | Counted _, Top -> false

  let is_top _bounds = function Top -> true | Counted _ -> false

  let compare c d =
    match (c, d) with
    | Counted c, Counted d -> AtLeast.compare c d
    | Top, Counted _ -> -1
    | Counted _, Top -> 1
    | Top, Top -> 0

  let hash = function Counted c -> AtLeast.hash c | Top -> -1

  (* [Top] itself where the right side alone is counted. *)
  let counterexample bounds c d =
    match (c, d) with
    | _, Top -> None
    | Top, Counted _ -> Some Top
    | Counted c, Counted d ->
        Option.map (fun e -> Counted e) (AtLeast.counterexample bounds c d)

  let plus = function
    | Counted c -> Option.map (fun c -> Counted c) (AtLeast.plus c)
    | Top -> Some Top

  let unit_least = false
  let commutative = true
  let needs_op_bounds = AtLeast.needs_op_bounds
  let duration_ends = AtLeast.duration_ends
  let duration_bounds _bounds _ = None
  let vacuous _bounds _ = None
  let inhabited bounds c = Grade.inhabited_of vacuous bounds c
  let events = function Counted c -> AtLeast.events c | Top -> []
  let of_delay d = Counted (AtLeast.of_delay d)
  let of_bounds b = Counted (AtLeast.of_bounds b)
  let of_lit = function Grade.Top -> Top | lit -> Counted (AtLeast.of_lit lit)
  let accepts = Grade.reads_lit of_lit

  let is_atomic name = function
    | Counted c -> AtLeast.is_atomic name c
    | Top -> false

  let show = function Counted c -> AtLeast.show c | Top -> "⊤"

  let witnesses ~degree bounds cs =
    let counted =
      List.filter_map (function Counted c -> Some c | Top -> None) cs
    in
    ( Top
      :: List.map
           (fun c -> Counted c)
           (fst (AtLeast.witnesses ~degree bounds counted)),
      Grade.Partial )

  let of_counts counts = Counted (AtLeast.of_counts counts)
end
