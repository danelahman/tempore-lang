let entry (module G : Grade.S) = (G.name, (module G : Grade.S))

let grade_modules =
  List.map entry
    [
      (module TimeGrades.LowerBound : Grade.S);
      (module TimeGrades.UpperBound);
      (module TimeGrades.Interval);
      (module TimedTraceGrades.LowerBound);
      (module TimedTraceGrades.UpperBound);
      (module TimedTraceGrades.Interval);
      (module RegularTraceGrade);
      (module RegularTraceGradeDerivative);
      (module LevelGrades.SecurityLevels);
      (module LevelGrades.TimeLowerBoundLevels);
      (module LevelGrades.TimeUpperBoundLevels);
    ]

let understands lit (module G : Grade.S) =
  match G.of_lit lit with
  | _ -> true
  | exception Grade.Invalid_literal _ -> false

let accepting lit =
  List.filter_map
    (fun (name, grade) -> if understands lit grade then Some name else None)
    grade_modules
