type level = int

module type S = sig
  val lattice : LevelLattice.t

  module WrittenAt : GradeConstructions.SEMILATTICE with type t = level option

  module Outputs :
    GradeConstructions.SEMILATTICE
      with type t = level option GradeConstructions.Indexed.t

  module Raise :
    GradeConstructions.ACTION with type m = level and type n = Outputs.t

  module Make (D : Delay.S) : sig
    module SecurityLevels : Grade.S with type t = level and type Delay.t = D.t

    module FlowLevels :
      Grade.S with type t = level * Outputs.t and type Delay.t = D.t
  end

  module SecurityLevels :
    Grade.S with type t = level and type Delay.t = Delay.Rational.t

  module TimeLowerBoundLevels :
    Grade.S
      with type t = TimeGrades.LowerBound.t * level
       and type Delay.t = Delay.Nat.t

  module TimeUpperBoundLevels :
    Grade.S
      with type t = TimeGrades.UpperBound.t * level
       and type Delay.t = Delay.Nat.t

  module FlowLevels :
    Grade.S with type t = level * Outputs.t and type Delay.t = Delay.Rational.t
end

module Over (L : sig
  val lattice : LevelLattice.t
end) =
struct
  let lattice = L.lattice

  (* The levels of the lattice, by their numbers. *)
  module Levels = struct
    type t = level

    let name = "security-levels"
    let bottom = LevelLattice.bottom lattice
    let top = LevelLattice.top lattice
    let join = LevelLattice.join lattice
    let leq = LevelLattice.leq lattice
    let compare = Int.compare
    let hash = Fun.id
    let elements = LevelLattice.elements lattice

    let of_lit = function
      | Grade.Name name as lit -> (
          match LevelLattice.index lattice name with
          | Some l -> l
          | None ->
              Grade.invalid_lit lit "unknown level `%s`; %s" name
                (LevelLattice.levels_are lattice))
      | lit ->
          Grade.invalid_lit lit "grades are %s, not %s"
            (LevelLattice.the_levels lattice)
            (Grade.describe_lit lit)

    let show = LevelLattice.label lattice
  end

  (* [join_level l l'] is the join of the levels [l] and [l']. *)
  let join_level = Levels.join

  module Indexed = GradeConstructions.Indexed

  (* The level at which a sink is written, if it is: [None] below every
     [Some l]. *)
  module WrittenAt = struct
    type t = level option

    let name = "written"
    let bottom = None
    let top = Some Levels.top

    let join w w' =
      match (w, w') with
      | None, w | w, None -> w
      | Some l, Some l' -> Some (join_level l l')

    let leq w w' =
      match (w, w') with
      | None, _ -> true
      | Some _, None -> false
      | Some l, Some l' -> Levels.leq l l'

    let compare = Option.compare Levels.compare
    let hash = function None -> -1 | Some l -> Levels.hash l
    let of_lit lit = Some (Levels.of_lit lit)
    let show = function None -> "⊥" | Some l -> Levels.show l
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

  (** [written lit] is the output the literal [lit] of a sink and a level
      denotes. *)
  let written = function
    | Grade.Tuple [ Grade.Name sink; level ] as lit ->
        ( sink,
          Grade.component_of_lit lit ~context:"in the level of an output, "
            Levels.of_lit level )
    | lit ->
        Grade.invalid_lit lit
          "outputs are pairs `(Sink, l)` of a sink and a level, not %s"
          (Grade.describe_lit lit)

  (** [of_written lit ws] is the outputs [ws], each sink listed once in the
      literal [lit]. *)
  let of_written lit ws =
    let defaults, named =
      List.partition
        (fun (s, _) -> String.equal s Indexed.fresh)
        (Grade.distinct_entries lit ~compare:String.compare
           ~twice:(Printf.sprintf "the output `%s` is listed twice")
           ws)
    in
    Indexed.of_list ~compare:WrittenAt.compare
      ~others:(match defaults with (_, l) :: _ -> Some l | [] -> None)
      (List.map (fun (s, l) -> (s, Some l)) named)

  module Make (D : Delay.S) = struct
    module SecurityLevels = GradeConstructions.OfLattice (D) (Levels)

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
            match Grade.read_lit SecurityLevels.of_lit lit with
            | Ok l -> (l, Outputs.bottom)
            | Error (_, reason) ->
                Grade.invalid_lit lit
                  "%s, or tuples `(l, (Sink, l1), ...)` of a level and the \
                   outputs written"
                  reason)

      let accepts = Grade.reads_lit of_lit

      let show ((l, o) as c) =
        if compare c top = 0 then "⊤"
        else if Outputs.compare o Outputs.bottom = 0 then Levels.show l
        else
          "(" ^ Levels.show l ^ ", "
          ^ Indexed.show_entries ~is_default:Option.is_none WrittenAt.show o
          ^ ")"

      (* Each ordering is the conjunction of its projections on the level and
         on each sink, (l, W) ↦ (l, W(s)), morphisms preserving the joins: a
         failure at a rigid shows at the level and one sink of it, the sinks no
         constant names being alike. *)
      let witnesses ~degree:_ _bounds cs =
        let outputs =
          Outputs.bottom
          :: List.concat_map
               (fun s ->
                 List.map
                   (fun l ->
                     Indexed.of_list ~compare:WrittenAt.compare ~others:None
                       [ (s, Some l) ])
                   Levels.elements)
               (Indexed.names (List.map snd cs))
        in
        ( List.concat_map
            (fun l -> List.map (fun o -> (l, o)) outputs)
            Levels.elements,
          Grade.Complete )
    end
  end

  include Make (Delay.Rational)

  (* The security levels over the whole-step delays of the time grades. *)
  module SteppedLevels = GradeConstructions.OfLattice (Delay.Nat) (Levels)

  module TimeLowerBoundLevels = struct
    include GradeConstructions.Product (TimeGrades.LowerBound) (SteppedLevels)

    let name = "time-lower-bound-levels"
  end

  module TimeUpperBoundLevels = struct
    include GradeConstructions.Product (TimeGrades.UpperBound) (SteppedLevels)

    let name = "time-upper-bound-levels"
  end
end

include Over (struct
  let lattice = LevelLattice.default
end)
