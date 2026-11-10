module Durations
    (E : Grade.S)
    (R : TimeGrades.DURATIONS with type Delay.t = E.Delay.t)
    (P : sig
      val unit_reflecting : bool
    end) =
struct
  module R = R
  module E = E

  let map bounds e =
    match E.duration_bounds bounds e with
    | Some durations -> R.of_durations durations
    | None -> R.top

  let lattice = None
  let unit_reflecting = P.unit_reflecting

  let witnesses ~degree bounds _rcs ecs =
    (fst (E.witnesses ~degree bounds ecs), Grade.Partial)
end

type entry = {
  effects : string;
  resources : string;
  system : (module GradeSystem.S);
  morphism : string;
}

let entry (module GS : GradeSystem.S) morphism =
  {
    effects = GS.E.name;
    resources = GS.R.name;
    system = (module GS : GradeSystem.S);
    morphism;
  }

module Reflecting = struct
  let unit_reflecting = true
end

module Not_reflecting = struct
  let unit_reflecting = false
end

let lower_end = "∣[d, a]∣ = [d, ∞), the lower end kept with its openness"
let upper_end = "∣[d, a]∣ = [0, a], the upper end kept with its openness"

let duration_hull =
  "∣g∣ = the least interval containing the durations of the runs of g, \
   operations taking their running times"

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
  ]

let find ~effects ~resources =
  List.find_map
    (fun e ->
      if String.equal e.effects effects && String.equal e.resources resources
      then Some e.system
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
