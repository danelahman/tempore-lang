type element = int

module type S = sig
  val lattice : GradeLattice.t

  module WrittenAt : GradeConstructions.SEMILATTICE with type t = element option

  module Outputs :
    GradeConstructions.SEMILATTICE
      with type t = element option GradeConstructions.Indexed.t

  module Raise :
    GradeConstructions.ACTION with type m = element and type n = Outputs.t

  module Make (D : Delay.S) : sig
    module Lattice : Grade.S with type t = element and type Delay.t = D.t

    module FlowLattice :
      Grade.S with type t = element * Outputs.t and type Delay.t = D.t
  end

  module Lattice :
    Grade.S with type t = element and type Delay.t = Delay.Rational.t

  module TimeLowerBoundLattice :
    Grade.S
      with type t = TimeGrades.LowerBound.t * element
       and type Delay.t = Delay.Nat.t

  module TimeUpperBoundLattice :
    Grade.S
      with type t = TimeGrades.UpperBound.t * element
       and type Delay.t = Delay.Nat.t

  module TimeIntervalLattice :
    Grade.S
      with type t = RationalTimeGrades.Interval.t * element
       and type Delay.t = Delay.Rational.t

  module FlowLattice :
    Grade.S
      with type t = element * Outputs.t
       and type Delay.t = Delay.Rational.t
end

module Over (L : sig
  val lattice : GradeLattice.t
end) =
struct
  let lattice = L.lattice

  (* The elements of the lattice, by their numbers. *)
  module Elements = struct
    type t = element

    let name = "lattice"
    let bottom = GradeLattice.bottom lattice
    let top = GradeLattice.top lattice
    let join = GradeLattice.join lattice
    let leq = GradeLattice.leq lattice
    let compare = Int.compare
    let hash = Fun.id
    let elements = GradeLattice.elements lattice

    let of_lit = function
      | Grade.Name name as lit -> (
          match GradeLattice.index lattice name with
          | Some l -> l
          | None ->
              Grade.invalid_lit lit
                "unknown element `%s` of the grade lattice; %s" name
                (GradeLattice.its_elements lattice))
      | lit ->
          Grade.invalid_lit lit "grades are %s of the grade lattice, not %s"
            (GradeLattice.the_elements lattice)
            (Grade.describe_lit lit)

    let show = GradeLattice.label lattice
  end

  (* [join_element l l'] is the join of the elements [l] and [l']. *)
  let join_element = Elements.join

  module Indexed = GradeConstructions.Indexed

  (* The element at which a sink is written, if it is: [None] below every
     [Some l]. *)
  module WrittenAt = struct
    type t = element option

    let name = "written"
    let bottom = None
    let top = Some Elements.top

    let join w w' =
      match (w, w') with
      | None, w | w, None -> w
      | Some l, Some l' -> Some (join_element l l')

    let leq w w' =
      match (w, w') with
      | None, _ -> true
      | Some _, None -> false
      | Some l, Some l' -> Elements.leq l l'

    let compare = Option.compare Elements.compare
    let hash = function None -> -1 | Some l -> Elements.hash l
    let of_lit lit = Some (Elements.of_lit lit)
    let show = function None -> "⊥" | Some l -> Elements.show l
  end

  module Outputs = Indexed.OfSemilattice (WrittenAt)

  (* The action of an element on the outputs, raising each written sink to at
     least it. *)
  module Raise =
    Indexed.Action
      (WrittenAt)
      (struct
        type m = element
        type n = element option

        let act l = Option.map (join_element l)
      end)

  (** [written lit] is the output the literal [lit] of a sink and an element
      denotes. *)
  let written = function
    | Grade.Tuple [ Grade.Name sink; element ] as lit ->
        ( sink,
          Grade.component_of_lit lit ~context:"in the element of an output, "
            Elements.of_lit element )
    | lit ->
        Grade.invalid_lit lit
          "outputs are pairs `(Sink, l)` of a sink and an element, not %s"
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
    module Lattice = GradeConstructions.OfLattice (D) (Elements)

    module FlowLattice = struct
      include GradeConstructions.SemiDirect (Lattice) (Outputs) (Raise)

      let name = "flow-lattice"

      let of_lit = function
        | Grade.Top -> top
        | Grade.Tuple (element :: (_ :: _ as outputs)) as lit ->
            let l =
              Grade.component_of_lit lit ~context:"in the element, "
                Lattice.of_lit element
            in
            let ws =
              List.map (Grade.component_of_lit lit ~context:"" written) outputs
            in
            (l, of_written lit ws)
        | lit -> (
            match Grade.read_lit Lattice.of_lit lit with
            | Ok l -> (l, Outputs.bottom)
            | Error (_, reason) ->
                Grade.invalid_lit lit
                  "%s, or tuples `(l, (Sink, l1), ...)` of an element and the \
                   outputs written"
                  reason)

      let accepts = Grade.reads_lit of_lit

      let show ((l, o) as c) =
        if compare c top = 0 then "⊤"
        else if Outputs.compare o Outputs.bottom = 0 then Elements.show l
        else
          "(" ^ Elements.show l ^ ", "
          ^ Indexed.show_entries ~is_default:Option.is_none WrittenAt.show o
          ^ ")"

      (* Each ordering is the conjunction of its projections on the element and
         on each sink, (l, W) ↦ (l, W(s)), morphisms preserving the joins: a
         failure at a rigid shows at the element and one sink of it, the sinks no
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
                   Elements.elements)
               (Indexed.names (List.map snd cs))
        in
        ( List.concat_map
            (fun l -> List.map (fun o -> (l, o)) outputs)
            Elements.elements,
          Grade.Complete )
    end
  end

  include Make (Delay.Rational)

  (* The grade lattice over the whole-step delays of the time grades. *)
  module SteppedLattice = GradeConstructions.OfLattice (Delay.Nat) (Elements)

  module TimeLowerBoundLattice = struct
    include GradeConstructions.Product (TimeGrades.LowerBound) (SteppedLattice)

    let name = "time-lower-bound-lattice"
  end

  module TimeUpperBoundLattice = struct
    include GradeConstructions.Product (TimeGrades.UpperBound) (SteppedLattice)

    let name = "time-upper-bound-lattice"
  end

  module TimeIntervalLattice = struct
    include GradeConstructions.Product (RationalTimeGrades.Interval) (Lattice)

    let name = "time-interval-lattice"
  end
end

include Over (struct
  let lattice = GradeLattice.default
end)
