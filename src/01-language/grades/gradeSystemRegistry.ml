module Mapped
    (E : Grade.S)
    (R : Grade.S with type Delay.t = E.Delay.t)
    (M : sig
      val map : Grade.bounds -> E.t -> R.t
      val lattice : GradeLattice.t option
      val unit_reflecting : bool
    end) =
struct
  module R = R
  module E = E

  let map = M.map
  let lattice = M.lattice
  let unit_reflecting = M.unit_reflecting

  let witnesses ~degree bounds _rcs ecs =
    (fst (E.witnesses ~degree bounds ecs), Grade.Partial)
end

module Durations
    (E : Grade.S)
    (R : TimeGrades.DURATIONS with type Delay.t = E.Delay.t)
    (P : sig
      val unit_reflecting : bool
    end) =
struct
  module R = R
  module E = E

  (* The running times with each open end replaced by the closed one it
     abbreviates over the delays, as the running-time bounds of a program are
     read. *)
  let closed (bounds : Grade.bounds) =
    {
      bounds with
      running_time =
        (fun op ->
          Grade.close_running_time E.Delay.adjacent (bounds.running_time op));
    }

  let map bounds e =
    match E.duration_bounds (closed bounds) e with
    | Some durations -> R.of_durations durations
    | None -> R.top

  let lattice = None
  let unit_reflecting = P.unit_reflecting

  let witnesses ~degree bounds _rcs ecs =
    (fst (E.witnesses ~degree bounds ecs), Grade.Partial)
end

(* The traces over whole time steps, and their sets with a greatest point. *)
module Traces = TimedTrace.Base (Delay.Nat)
module Runs = BankedTraceGrades.Bounded (Delay.Nat)

(* [calls pick p] is the operations of the non-empty set of traces [p], each
   with the number of its calls in a trace of [p] chosen by [pick] from those
   of all of them. *)
let calls pick p =
  let count name t =
    List.length
      (List.filter
         (function
           | Traces.Ev o -> String.equal o name | Traces.Wait _ -> false)
         t)
  in
  List.map
    (fun name ->
      match List.map (count name) p with
      | n :: ns -> (name, List.fold_left pick n ns)
      | [] -> invalid_arg "GradeSystemRegistry.calls: no traces")
    (Traces.events p)

(* The finite run sets with the at-most counts, the greatest number of calls
   in a run. *)
module MostCalls =
  Mapped (FiniteRunSetGrades.UpperBound) (CountGrades.AtMost)
    (struct
      let map _bounds = function
        | Runs.Within p -> CountGrades.AtMost.of_counts (calls max p)
        | Runs.Unbounded -> CountGrades.AtMost.top

      let lattice = None
      let unit_reflecting = false
    end)

(* The finite run sets with the at-least counts with a top, the least number
   of calls in a run. *)
module LeastRunCalls =
  Mapped (FiniteRunSetGrades.UpperBound) (CountGrades.AtLeastWithTop)
    (struct
      let map _bounds = function
        | Runs.Within p -> CountGrades.AtLeastWithTop.of_counts (calls min p)
        | Runs.Unbounded -> CountGrades.AtLeastWithTop.top

      let lattice = None
      let unit_reflecting = false
    end)

(* The lower trace bounds with the at-least counts, the least number of calls
   in a trace; the unit of both is the top. *)
module LeastCalls =
  Mapped (BankedTraceGrades.LowerBound) (CountGrades.AtLeast)
    (struct
      let map _bounds p = CountGrades.AtLeast.of_counts (calls min p)
      let lattice = None
      let unit_reflecting = true
    end)

(* The projections of the time lower bounds paired with a grade lattice. *)
module type PROJECTIONS = sig
  module First : GradeSystem.S
  module Second : GradeSystem.S
end

(* The projections over the grade lattice [L.lattice], or else [Low < High];
   the second reflects the order at the unit, [0] being the top of the time
   lower bounds. *)
module Projections (L : sig
  val lattice : GradeLattice.t option
end) =
struct
  module V = LatticeGrades.Over (struct
    let lattice = Option.value L.lattice ~default:GradeLattice.default
  end)

  module Whole = V.Make (Delay.Nat)

  module First =
    Mapped (V.TimeLowerBoundLattice) (TimeGrades.LowerBound)
      (struct
        let map _bounds (n, _) = n
        let lattice = L.lattice
        let unit_reflecting = false
      end)

  module Second =
    Mapped (V.TimeLowerBoundLattice) (Whole.Lattice)
      (struct
        let map _bounds (_, l) = l
        let lattice = L.lattice
        let unit_reflecting = true
      end)
end

type entry = {
  effects : string;
  resources : string;
  system : (module GradeSystem.S);
  over_lattice : (GradeLattice.t -> (module GradeSystem.S)) option;
  morphism : string;
}

let entry ?over_lattice (module GS : GradeSystem.S) morphism =
  {
    effects = GS.E.name;
    resources = GS.R.name;
    system = (module GS : GradeSystem.S);
    over_lattice;
    morphism;
  }

module Reflecting = struct
  let unit_reflecting = true
end

module Not_reflecting = struct
  let unit_reflecting = false
end

(* [projection select] is the entry of the projection [select] of the
   products of the time lower bounds and a grade lattice, over the grade
   lattice a program declares, or else [Low < High]. *)
let projection select morphism =
  let over lattice =
    let module P = Projections (struct
      let lattice = lattice
    end) in
    select (module P : PROJECTIONS)
  in
  entry ~over_lattice:(fun lattice -> over (Some lattice)) (over None) morphism

let lower_end = "the lower end of an effect grade, [d, a] becoming [d, ∞)"
let upper_end = "the upper end of an effect grade, [d, a] becoming [0, a]"

let duration_hull =
  "the least and the greatest duration of the runs of an effect grade, by the \
   running times of its operations"

let duration_infimum =
  "the least duration of the runs of an effect grade, by the running times of \
   its operations"

let duration_supremum =
  "the greatest duration of the runs of an effect grade, by the running times \
   of its operations"

let fastest_trace =
  "the least total running time of the traces of an effect grade"

let slowest_trace =
  "the greatest total running time of the traces of an effect grade"

let trace_hull =
  "the least and the greatest total running time of the traces of an effect \
   grade"

let most_calls =
  "for each operation, the greatest number of its calls in a run of an effect \
   grade"

let least_run_calls =
  "for each operation, the least number of its calls in a run of an effect \
   grade, the top kept"

let least_calls =
  "for each operation, the least number of its calls in a trace of an effect \
   grade"

let systems =
  [
    entry
      (module Durations (TimeGrades.Interval) (TimeGrades.LowerBound)
                (Not_reflecting))
      lower_end;
    entry
      (module Durations
                (RationalTimeGrades.Interval)
                (RationalTimeGrades.LowerBound)
                (Not_reflecting))
      lower_end;
    entry
      (module Durations (TimeGrades.Interval) (TimeGrades.UpperBound)
                (Reflecting))
      upper_end;
    entry
      (module Durations
                (RationalTimeGrades.Interval)
                (RationalTimeGrades.UpperBound)
                (Reflecting))
      upper_end;
    entry
      (module Durations (TimedRegexGrades.Interval) (TimeGrades.Interval)
                (Not_reflecting))
      duration_hull;
    entry
      (module Durations
                (TimedRegexGrades.Rational.Interval)
                (RationalTimeGrades.Interval)
                (Not_reflecting))
      duration_hull;
    entry
      (module Durations (TimedRegexGrades.Finite.Interval) (TimeGrades.Interval)
                (Not_reflecting))
      duration_hull;
    entry
      (module Durations
                (TimedRegexGrades.Finite.Rational.Interval)
                (RationalTimeGrades.Interval)
                (Not_reflecting))
      duration_hull;
    entry
      (module Durations (TimedRegexGrades.LowerBound) (TimeGrades.LowerBound)
                (Not_reflecting))
      duration_infimum;
    entry
      (module Durations
                (TimedRegexGrades.Rational.LowerBound)
                (RationalTimeGrades.LowerBound)
                (Not_reflecting))
      duration_infimum;
    entry
      (module Durations (TimedRegexGrades.UpperBound) (TimeGrades.UpperBound)
                (Reflecting))
      duration_supremum;
    entry
      (module Durations
                (TimedRegexGrades.Rational.UpperBound)
                (RationalTimeGrades.UpperBound)
                (Reflecting))
      duration_supremum;
    entry
      (module Durations
                (TimedRegexGrades.Finite.LowerBound)
                (TimeGrades.LowerBound)
                (Not_reflecting))
      duration_infimum;
    entry
      (module Durations
                (TimedRegexGrades.Finite.Rational.LowerBound)
                (RationalTimeGrades.LowerBound)
                (Not_reflecting))
      duration_infimum;
    entry
      (module Durations
                (TimedRegexGrades.Finite.UpperBound)
                (TimeGrades.UpperBound)
                (Reflecting))
      duration_supremum;
    entry
      (module Durations
                (TimedRegexGrades.Finite.Rational.UpperBound)
                (RationalTimeGrades.UpperBound)
                (Reflecting))
      duration_supremum;
    entry
      (module Durations (BankedTraceGrades.LowerBound) (TimeGrades.LowerBound)
                (Reflecting))
      fastest_trace;
    entry
      (module Durations
                (BankedTraceGrades.Rational.LowerBound)
                (RationalTimeGrades.LowerBound)
                (Reflecting))
      fastest_trace;
    entry
      (module Durations (BankedTraceGrades.UpperBound) (TimeGrades.UpperBound)
                (Reflecting))
      slowest_trace;
    entry
      (module Durations
                (BankedTraceGrades.Rational.UpperBound)
                (RationalTimeGrades.UpperBound)
                (Reflecting))
      slowest_trace;
    entry
      (module Durations (BankedTraceGrades.Interval) (TimeGrades.Interval)
                (Reflecting))
      trace_hull;
    entry
      (module Durations
                (BankedTraceGrades.Rational.Interval)
                (RationalTimeGrades.Interval)
                (Reflecting))
      trace_hull;
    entry (module MostCalls) most_calls;
    entry (module LeastRunCalls) least_run_calls;
    entry (module LeastCalls) least_calls;
    projection
      (fun (module P : PROJECTIONS) -> (module P.First : GradeSystem.S))
      "the time component of an effect grade";
    projection
      (fun (module P : PROJECTIONS) -> (module P.Second : GradeSystem.S))
      "the lattice component of an effect grade";
  ]

let find ?lattice ~effects ~resources () =
  List.find_map
    (fun e ->
      if String.equal e.effects effects && String.equal e.resources resources
      then
        match (lattice, e.over_lattice) with
        | Some lattice, Some over -> Some (over lattice)
        | _ -> Some e.system
      else None)
    systems

let effects_of resources =
  List.filter_map
    (fun e ->
      if String.equal e.resources resources then Some e.effects else None)
    systems

let resources_of effects =
  List.filter_map
    (fun e -> if String.equal e.effects effects then Some e.resources else None)
    systems

let morphism ~effects ~resources =
  List.find_map
    (fun e ->
      if String.equal e.effects effects && String.equal e.resources resources
      then Some e.morphism
      else None)
    systems

(* The names [names] quoted and listed, the last two joined by "and". *)
let listed names =
  match List.rev_map (fun name -> "`" ^ name ^ "`") names with
  | [] -> ""
  | [ name ] -> name
  | last :: rest -> String.concat ", " (List.rev rest) ^ " and " ^ last

let select ?lattice ~effects ~resources (module G : Grade.S) =
  match resources with
  | Some resources when not (String.equal resources effects) -> (
      match find ?lattice ~effects ~resources () with
      | Some system -> Ok system
      | None ->
          Error
            (Printf.sprintf
               "The grade algebra `%s` has no grade system with the resource \
                grade algebra `%s`; %s"
               effects resources
               (match resources_of effects with
               | [] ->
                   Printf.sprintf
                     "its only resource grade algebra is `%s` itself" effects
               | others ->
                   "its resource grade algebras are "
                   ^ listed (effects :: others))))
  | Some _ | None ->
      Ok
        (module GradeSystem.Declaring
                  (struct
                    let lattice = lattice
                  end)
                  (G) : GradeSystem.S)

let by_resources =
  let add groups e =
    let rec go = function
      | [] -> [ (e.resources, [ ([ e.effects ], e.morphism) ]) ]
      | (r, clauses) :: rest when String.equal r e.resources ->
          let rec merge = function
            | [] -> [ ([ e.effects ], e.morphism) ]
            | (es, m) :: more when String.equal m e.morphism ->
                (es @ [ e.effects ], m) :: more
            | c :: more -> c :: merge more
          in
          (r, merge clauses) :: rest
      | g :: rest -> g :: go rest
    in
    go groups
  in
  List.fold_left add [] systems
