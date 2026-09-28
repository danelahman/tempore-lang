type level = Low | High

(** The two-point lattice [Low < High]. *)
module LowHigh = struct
  type t = level

  let name = "security-levels"
  let bottom = Low
  let top = High
  let join l l' = match (l, l') with Low, Low -> Low | _ -> High
  let leq l l' = match (l, l') with High, Low -> false | _ -> true
  let rank = function Low -> 0 | High -> 1
  let compare l l' = Int.compare (rank l) (rank l')
  let hash = rank
  let elements = [ Low; High ]

  let of_lit = function
    | Grade.Name "Low" -> Low
    | Grade.Name "High" -> High
    | Grade.Name name as lit ->
        Grade.invalid_lit lit
          "unknown level '%s'; the levels are 'Low' and 'High'" name
    | lit ->
        Grade.invalid_lit lit "grades are the levels 'Low' and 'High', not %s"
          (Grade.describe_lit lit)

  let show = function Low -> "Low" | High -> "High"
end

module SecurityLevels = GradeConstructions.OfLattice (LowHigh)

module TimeLowerBoundLevels = struct
  include GradeConstructions.Product (TimeGrades.LowerBound) (SecurityLevels)

  let name = "time-lower-bound-levels"
end

module TimeUpperBoundLevels = struct
  include GradeConstructions.Product (TimeGrades.UpperBound) (SecurityLevels)

  let name = "time-upper-bound-levels"
end

type outputs = Written of (string * level) list | Anywhere

(** [join_level l l'] is the join of the levels [l] and [l']. *)
let join_level = LowHigh.join

(* The outputs, each sink by the highest level it is written at; [Written]
   lists the sinks written, in increasing order, and [Anywhere] is every sink
   at [High]. *)
module Outputs = struct
  type t = outputs

  let name = "outputs"
  let bottom = Written []
  let top = Anywhere

  let rec merge ws ws' =
    match (ws, ws') with
    | [], ws | ws, [] -> ws
    | ((s, l) as w) :: rest, ((s', l') as w') :: rest' -> (
        match String.compare s s' with
        | 0 -> (s, join_level l l') :: merge rest rest'
        | c when c < 0 -> w :: merge rest ws'
        | _ -> w' :: merge ws rest')

  let join o o' =
    match (o, o') with
    | Anywhere, _ | _, Anywhere -> Anywhere
    | Written ws, Written ws' -> Written (merge ws ws')

  let leq o o' =
    match (o, o') with
    | _, Anywhere -> true
    | Anywhere, Written _ -> false
    | Written ws, Written ws' ->
        List.for_all
          (fun (s, l) ->
            match List.assoc_opt s ws' with
            | Some l' -> LowHigh.leq l l'
            | None -> false)
          ws

  let compare_written (s, l) (s', l') =
    match String.compare s s' with 0 -> LowHigh.compare l l' | c -> c

  let compare o o' =
    match (o, o') with
    | Written ws, Written ws' -> List.compare compare_written ws ws'
    | Written _, Anywhere -> -1
    | Anywhere, Written _ -> 1
    | Anywhere, Anywhere -> 0

  let hash = function
    | Anywhere -> -1
    | Written ws ->
        Grade.hash_list
          (fun (s, l) -> Grade.combine (Hashtbl.hash s) (LowHigh.hash l))
          ws

  let show_written (s, l) = "(" ^ s ^ "," ^ LowHigh.show l ^ ")"

  (** [written lit] is the output the literal [lit] of a sink and a level
      denotes. *)
  let written = function
    | Grade.Tuple [ Grade.Name sink; level ] as lit ->
        ( sink,
          Grade.component_of_lit lit ~context:"in the level of an output, "
            LowHigh.of_lit level )
    | lit ->
        Grade.invalid_lit lit
          "outputs are pairs '(Sink, l)' of a sink and a level, not %s"
          (Grade.describe_lit lit)

  (** [of_written lit ws] is the outputs [ws], each sink listed once in the
      literal [lit]. *)
  let of_written lit ws =
    let sorted = List.sort compare_written ws in
    let rec check = function
      | (s, _) :: ((s', _) :: _ as rest) ->
          if String.equal s s' then
            Grade.invalid_lit lit "the output '%s' is listed twice" s
          else check rest
      | [ _ ] | [] -> Written sorted
    in
    check sorted

  let of_lit lit = of_written lit [ written lit ]

  let show = function
    | Anywhere -> "⊤"
    | Written ws -> String.concat "," (List.map show_written ws)
end

(* The action of a level on the outputs, raising each to at least it. *)
module Raise = struct
  type m = level
  type n = outputs

  let act l = function
    | Anywhere -> Anywhere
    | Written ws -> Written (List.map (fun (s, l') -> (s, join_level l l')) ws)
end

module FlowLevels = struct
  include GradeConstructions.SemiDirect (SecurityLevels) (Outputs) (Raise)

  let name = "flow-levels"

  let of_lit = function
    | Grade.Top -> top
    | Grade.Tuple (level :: (_ :: _ as outputs)) as lit ->
        let l =
          Grade.component_of_lit lit ~context:"in the level, "
            SecurityLevels.of_lit level
        in
        let ws =
          List.map
            (Grade.component_of_lit lit ~context:"" Outputs.written)
            outputs
        in
        (l, Outputs.of_written lit ws)
    | lit -> (
        match SecurityLevels.of_lit lit with
        | l -> (l, Outputs.bottom)
        | exception Grade.Invalid_literal (_, reason) ->
            Grade.invalid_lit lit
              "%s, or tuples '(l, (Sink, l1), ...)' of a level and the outputs \
               written"
              reason)

  let show = function
    | _, Anywhere -> "⊤"
    | l, Written [] -> LowHigh.show l
    | l, o -> "(" ^ LowHigh.show l ^ "," ^ Outputs.show o ^ ")"

  (** [fresh] is the sink standing for the sinks the constants do not name. *)
  let fresh = "_"

  (* Each ordering is the conjunction of its projections on the level and on
     each sink, (l, W) ↦ (l, W(s)), morphisms preserving the joins: a failure
     at a rigid shows at the level and one sink of it, the sinks no constant
     names being alike. *)
  let witnesses _bounds cs =
    let sinks =
      List.sort_uniq String.compare
        (fresh
        :: List.concat_map
             (function _, Written ws -> List.map fst ws | _, Anywhere -> [])
             cs)
    in
    let outputs =
      Outputs.bottom
      :: List.concat_map
           (fun s -> List.map (fun l -> Written [ (s, l) ]) LowHigh.elements)
           sinks
    in
    ( List.concat_map
        (fun l -> List.map (fun o -> (l, o)) outputs)
        LowHigh.elements,
      Grade.Complete )
end
