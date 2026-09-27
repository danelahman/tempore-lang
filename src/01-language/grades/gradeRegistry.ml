type info = { title : string; description : string }
type group = { label : string; grades : (string * info) list }

(* One registered grade: its module, named by [Grade.S.name], grouped and
   described for the web selector and the CLI's [--help]. The single list
   [entries] is the source of truth that [grade_modules], [groups] and
   [accepting] are all read off. *)
type entry = {
  name : string;
  grade : (module Grade.S);
  group : string;
  info : info;
}

let entry (module G : Grade.S) group title description =
  {
    name = G.name;
    grade = (module G : Grade.S);
    group;
    info = { title; description };
  }

let entries =
  [
    entry
      (module TimeGrades.LowerBound)
      "Time" "Lower bounds" "At least n time steps; the unit 0 is greatest.";
    entry
      (module TimeGrades.UpperBound)
      "Time" "Upper bounds" "At most n time steps; the unit 0 is least.";
    entry
      (module TimeGrades.Interval)
      "Time" "Intervals" "Between n and m time steps, ordered by containment.";
    entry
      (module TimedTraceGrades.LowerBound)
      "Timed traces" "Lower bounds"
      "Sets of timed traces in the coverage order, operations costing their \
       lower runtime bounds.";
    entry
      (module TimedTraceGrades.UpperBound)
      "Timed traces" "Upper bounds"
      "Sets of timed traces in the allowance order, operations costing their \
       upper runtime bounds.";
    entry
      (module TimedTraceGrades.Interval)
      "Timed traces" "Intervals"
      "Pairs of a lower and an upper timed-trace bound, compared componentwise.";
    entry
      (module RegularTraceGrade)
      "Regular traces" "Regular languages"
      "Regular languages of runs over delays and operations, decided by \
       automata.";
    entry
      (module RegularTraceGradeDerivative)
      "Regular traces" "Regular languages (symbolic derivatives)"
      "The same grade as regular languages, decided by symbolic derivatives \
       instead of automata.";
    entry
      (module RegularCostTraceGrades.Lower)
      "Regular traces with costs" "Lower bounds"
      "Regular languages of runs in the coverage order, operations costing \
       their lower runtime bounds, decided by automata.";
    entry
      (module RegularCostTraceGrades.Upper)
      "Regular traces with costs" "Upper bounds"
      "Regular languages of runs in the allowance order, operations costing \
       their upper runtime bounds, decided by automata.";
    entry
      (module RegularCostTraceGrades.Interval)
      "Regular traces with costs" "Intervals"
      "Pairs of a lower and an upper regular-language bound, compared \
       componentwise, decided by automata.";
    entry
      (module RegularCostTraceGrades.Symbolic.Lower)
      "Regular traces with costs" "Lower bounds (symbolic derivatives)"
      "The lower-bound cost grade, decided by symbolic derivatives instead of \
       automata.";
    entry
      (module RegularCostTraceGrades.Symbolic.Upper)
      "Regular traces with costs" "Upper bounds (symbolic derivatives)"
      "The upper-bound cost grade, decided by symbolic derivatives instead of \
       automata.";
    entry
      (module RegularCostTraceGrades.Symbolic.Interval)
      "Regular traces with costs" "Intervals (symbolic derivatives)"
      "The interval cost grade, decided by symbolic derivatives instead of \
       automata.";
    entry
      (module LevelGrades.SecurityLevels)
      "Security levels" "Levels"
      "The two-point security lattice Low < High; a box is out of reach once a \
       higher level has been touched.";
    entry
      (module LevelGrades.TimeLowerBoundLevels)
      "Security levels" "Embargoes"
      "A time lower bound paired with a security level: at least n time steps, \
       touching nothing above the level.";
    entry
      (module LevelGrades.TimeUpperBoundLevels)
      "Security levels" "Expiring capabilities"
      "A time upper bound paired with a security level: at most n time steps, \
       touching nothing above the level.";
  ]

let grade_modules = List.map (fun e -> (e.name, e.grade)) entries

let understands lit (module G : Grade.S) =
  match G.of_lit lit with
  | _ -> true
  | exception Grade.Invalid_literal _ -> false

let accepting lit =
  List.filter_map
    (fun e -> if understands lit e.grade then Some e.name else None)
    entries

(* [entries] grouped by [group], preserving both the order groups first occur
   in and the order of the grades within each, as {!grade_modules} lists
   them. *)
let groups =
  let groups =
    List.fold_left
      (fun groups (e : entry) ->
        match groups with
        | (label, front) :: rest when label = e.group ->
            (label, (e.name, e.info) :: front) :: rest
        | _ -> (e.group, [ (e.name, e.info) ]) :: groups)
      [] entries
  in
  List.rev_map (fun (label, front) -> { label; grades = List.rev front }) groups
