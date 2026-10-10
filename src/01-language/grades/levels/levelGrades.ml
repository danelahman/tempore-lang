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

(** [join_level l l'] is the join of the levels [l] and [l']. *)
let join_level = LowHigh.join

module Indexed = GradeConstructions.Indexed

(* The level at which a sink is written, if it is: [None], then [Some Low],
   then [Some High]. *)
module WrittenAt = struct
  type t = level option

  let name = "written"
  let bottom = None
  let top = Some High

  let join w w' =
    match (w, w') with
    | None, w | w, None -> w
    | Some l, Some l' -> Some (join_level l l')

  let leq w w' =
    match (w, w') with
    | None, _ -> true
    | Some _, None -> false
    | Some l, Some l' -> LowHigh.leq l l'

  let compare = Option.compare LowHigh.compare
  let hash = function None -> -1 | Some l -> LowHigh.hash l
  let of_lit lit = Some (LowHigh.of_lit lit)
  let show = function None -> "⊥" | Some l -> LowHigh.show l
end

module Outputs = Indexed.OfSemilattice (WrittenAt)

(* The action of a level on the outputs, raising each written sink to at
   least it. *)
module Raise =
  Indexed.Action
    (WrittenAt)
    (struct
      type m = level
      type n = level option

      let act l = Option.map (join_level l)
    end)

(** [written lit] is the output the literal [lit] of a sink and a level denotes.
*)
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
  let sorted = List.sort (fun (s, _) (s', _) -> String.compare s s') ws in
  let rec check = function
    | (s, _) :: ((s', _) :: _ as rest) ->
        if String.equal s s' then
          Grade.invalid_lit lit "the output '%s' is listed twice" s
        else check rest
    | [ _ ] | [] ->
        let defaults, named =
          List.partition (fun (s, _) -> String.equal s Indexed.fresh) sorted
        in
        Indexed.of_list ~compare:WrittenAt.compare
          ~others:(match defaults with (_, l) :: _ -> Some l | [] -> None)
          (List.map (fun (s, l) -> (s, Some l)) named)
  in
  check sorted

module Make (D : Delay.S) = struct
  module SecurityLevels = GradeConstructions.OfLattice (D) (LowHigh)

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
            List.map (Grade.component_of_lit lit ~context:"" written) outputs
          in
          (l, of_written lit ws)
      | lit -> (
          match SecurityLevels.of_lit lit with
          | l -> (l, Outputs.bottom)
          | exception Grade.Invalid_literal (_, reason) ->
              Grade.invalid_lit lit
                "%s, or tuples '(l, (Sink, l1), ...)' of a level and the \
                 outputs written"
                reason)

    let show ((l, o) as c) =
      if compare c top = 0 then "⊤"
      else if Outputs.compare o Outputs.bottom = 0 then LowHigh.show l
      else
        "(" ^ LowHigh.show l ^ ", "
        ^ Indexed.show_entries ~is_default:Option.is_none WrittenAt.show o
        ^ ")"

    (* Each ordering is the conjunction of its projections on the level and on
       each sink, (l, W) ↦ (l, W(s)), morphisms preserving the joins: a failure
       at a rigid shows at the level and one sink of it, the sinks no constant
       names being alike. *)
    let witnesses ~degree:_ _bounds cs =
      let outputs =
        Outputs.bottom
        :: List.concat_map
             (fun s ->
               List.map
                 (fun l ->
                   Indexed.of_list ~compare:WrittenAt.compare ~others:None
                     [ (s, Some l) ])
                 LowHigh.elements)
             (Indexed.names (List.map snd cs))
      in
      ( List.concat_map
          (fun l -> List.map (fun o -> (l, o)) outputs)
          LowHigh.elements,
        Grade.Complete )
  end
end

include Make (Delay.Rational)

module SteppedLevels = GradeConstructions.OfLattice (Delay.Nat) (LowHigh)
(** The security levels over the whole-step delays of the time grades. *)

module TimeLowerBoundLevels = struct
  include GradeConstructions.Product (TimeGrades.LowerBound) (SteppedLevels)

  let name = "time-lower-bound-levels"
end

module TimeUpperBoundLevels = struct
  include GradeConstructions.Product (TimeGrades.UpperBound) (SteppedLevels)

  let name = "time-upper-bound-levels"
end
