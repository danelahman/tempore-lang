type visibility = Everywhere | Cli_only
type info = { title : string; description : string; visibility : visibility }
type group = { label : string; short : string; grades : (string * info) list }

(* One registered grade: its module, named by [Grade.S.name], grouped and
   described for the web selector and the CLI's [--help]. The single list
   [entries] is the source of truth that [grade_modules], [groups] and
   [accepting] are all read off. *)
type entry = {
  name : string;
  grade : (module Grade.S);
  group : string * string;
  info : info;
}

(* The groups of the grades, each its label and the label's short form. *)
let time = ("Time", "Time")
let traces = ("Traces", "Traces")
let traces_costs = ("Traces with costs", "Traces (costs)")
let regex = ("Regular expressions", "Regex")
let regex_costs = ("Regular expressions with costs", "Regex (costs)")
let security = ("Security levels", "Security")
let semidirect = ("Semidirect products", "Semidirect")
let counts = ("Operation counts", "Counts")

let entry ?(visibility = Everywhere) (module G : Grade.S) group title
    description =
  {
    name = G.name;
    grade = (module G : Grade.S);
    group;
    info = { title; description; visibility };
  }

let entries =
  [
    entry
      (module TimeGrades.LowerBound)
      time "Lower bounds" "At least n time steps; the unit 0 is greatest.";
    entry
      (module TimeGrades.UpperBound)
      time "Upper bounds" "At most n time steps; the unit 0 is least.";
    entry
      (module TimeGrades.Interval)
      time "Intervals" "Between n and m time steps, ordered by containment.";
    entry
      (module RationalTimeGrades.LowerBound)
      time "Lower bounds (rational)"
      "At least q time units, q a non-negative rational; the unit 0 is \
       greatest.";
    entry
      (module RationalTimeGrades.UpperBound)
      time "Upper bounds (rational)"
      "At most q time units, q a non-negative rational or ∞; the unit 0 is \
       least.";
    entry
      (module RationalTimeGrades.Interval)
      time "Intervals (rational)"
      "Between q and r time units, rationals, ordered by containment.";
    entry
      (module TraceInclusionGrades.UpperBound)
      traces "Upper bounds"
      "Sets of traces ordered by inclusion; operations declare no runtime \
       bounds.";
    entry
      (module TraceInclusionGrades.Rational.UpperBound)
      traces "Upper bounds (rational)"
      "Sets of traces with rational delays ordered by inclusion; operations \
       declare no runtime bounds.";
    entry
      (module TimedTraceGrades.LowerBound)
      traces_costs "Lower bounds"
      "Sets of traces in the coverage order, operations costing their lower \
       runtime bounds.";
    entry
      (module TimedTraceGrades.UpperBound)
      traces_costs "Upper bounds"
      "Sets of traces in the allowance order, operations costing their upper \
       runtime bounds.";
    entry
      (module TimedTraceGrades.Interval)
      traces_costs "Intervals"
      "Pairs of a lower and an upper trace bound, compared componentwise.";
    entry
      (module TimedTraceGrades.Rational.LowerBound)
      traces_costs "Lower bounds (rational)"
      "Sets of traces with rational delays in the coverage order, operations \
       costing their lower runtime bounds, which may be fractional.";
    entry
      (module TimedTraceGrades.Rational.UpperBound)
      traces_costs "Upper bounds (rational)"
      "Sets of traces with rational delays in the allowance order, operations \
       costing their upper runtime bounds, which may be fractional.";
    entry
      (module TimedTraceGrades.Rational.Interval)
      traces_costs "Intervals (rational)"
      "Pairs of a lower and an upper trace bound with rational delays, \
       compared componentwise.";
    entry
      (module RegularTraceGrade)
      regex "Upper bounds"
      "Regular languages of runs over delays and operations, bounding the runs \
       permitted by inclusion; decided by automata.";
    entry
      (module RegularTraceGradeDerivative)
      regex "Upper bounds (symbolic derivatives)"
      "The same grade as the automata version, decided by symbolic derivatives \
       instead of automata.";
    entry ~visibility:Cli_only
      (module RegularTraceGradeDerivative.Concrete)
      regex "Upper bounds (plain derivatives)"
      "The same grade as the automata version, decided by derivatives by \
       single letters instead of minterms.";
    entry ~visibility:Cli_only
      (module RegularTraceGradePlain)
      regex "Upper bounds (fully plain derivatives)"
      "The same grade as the automata version, over single letters instead of \
       letter sets, decided by derivatives by letters.";
    entry
      (module RegularCostTraceGrades.Lower)
      regex_costs "Lower bounds"
      "Regular languages of runs in the coverage order, operations costing \
       their lower runtime bounds, decided by automata.";
    entry
      (module RegularCostTraceGrades.Upper)
      regex_costs "Upper bounds"
      "Regular languages of runs in the allowance order, operations costing \
       their upper runtime bounds, decided by automata.";
    entry
      (module RegularCostTraceGrades.Interval)
      regex_costs "Intervals"
      "Pairs of a lower and an upper regular-language bound, compared \
       componentwise, decided by automata.";
    entry
      (module RegularCostTraceGrades.Symbolic.Lower)
      regex_costs "Lower bounds (symbolic derivatives)"
      "The lower-bound cost grade, decided by symbolic derivatives instead of \
       automata.";
    entry
      (module RegularCostTraceGrades.Symbolic.Upper)
      regex_costs "Upper bounds (symbolic derivatives)"
      "The upper-bound cost grade, decided by symbolic derivatives instead of \
       automata.";
    entry
      (module RegularCostTraceGrades.Symbolic.Interval)
      regex_costs "Intervals (symbolic derivatives)"
      "The interval cost grade, decided by symbolic derivatives instead of \
       automata.";
    entry ~visibility:Cli_only
      (module RegularCostTraceGrades.Concrete.Lower)
      regex_costs "Lower bounds (plain derivatives)"
      "The lower-bound cost grade, decided by derivatives by letters instead \
       of minterms.";
    entry ~visibility:Cli_only
      (module RegularCostTraceGrades.Concrete.Upper)
      regex_costs "Upper bounds (plain derivatives)"
      "The upper-bound cost grade, decided by derivatives by letters instead \
       of minterms.";
    entry ~visibility:Cli_only
      (module RegularCostTraceGrades.Concrete.Interval)
      regex_costs "Intervals (plain derivatives)"
      "The interval cost grade, decided by derivatives by letters instead of \
       minterms.";
    entry ~visibility:Cli_only
      (module RegularCostTraceGrades.Plain.Lower)
      regex_costs "Lower bounds (fully plain derivatives)"
      "The lower-bound cost grade over single letters instead of letter sets, \
       decided by derivatives by letters.";
    entry ~visibility:Cli_only
      (module RegularCostTraceGrades.Plain.Upper)
      regex_costs "Upper bounds (fully plain derivatives)"
      "The upper-bound cost grade over single letters instead of letter sets, \
       decided by derivatives by letters.";
    entry ~visibility:Cli_only
      (module RegularCostTraceGrades.Plain.Interval)
      regex_costs "Intervals (fully plain derivatives)"
      "The interval cost grade over single letters instead of letter sets, \
       decided by derivatives by letters.";
    entry
      (module LevelGrades.SecurityLevels)
      security "Levels"
      "The two-point security lattice Low < High; a box is out of reach once a \
       higher level has been touched.";
    entry
      (module LevelGrades.TimeLowerBoundLevels)
      security "Embargoes"
      "A time lower bound paired with a security level: at least n time steps, \
       touching nothing above the level.";
    entry
      (module LevelGrades.TimeUpperBoundLevels)
      security "Expiring capabilities"
      "A time upper bound paired with a security level: at most n time steps, \
       touching nothing above the level.";
    entry
      (module LevelGrades.FlowLevels)
      security "Flow-sensitive outputs"
      "A security level paired with the level at which each output is written; \
       later outputs are raised to the level touched before them.";
    entry
      (module PeakGrades.PeakUsage)
      semidirect "Peak usage"
      "Triples (t, d, h) of the trough, the net change and the peak of a \
       resource held, such as open files; later levels are shifted by the \
       earlier change.";
    entry
      (module WindowGrades.TimeWindows)
      semidirect "Time windows"
      "Pairs (T, E) of the possible durations and the times at which windowed \
       operations happen; later times are shifted by the earlier durations.";
    entry
      (module ModeGrades.ModeCosts)
      semidirect "Mode costs"
      "Max-plus matrices of the costs between named modes, such as (Off, On, \
       2); an operation gets stuck from the modes its grade does not start \
       from, and a change of mode costs at least 1.";
    entry
      (module CountGrades.UpperBound)
      counts "Upper bounds"
      "At most n calls of each operation, by name, such as ((Auth, 1), (Send, \
       3)); delays count nothing.";
  ]

let grade_modules = List.map (fun e -> (e.name, e.grade)) entries

let understands lit (module G : Grade.S) =
  match G.of_lit lit with
  | _ -> true
  | exception Grade.Invalid_literal _ -> false

let accepting lit =
  List.filter_map
    (fun e ->
      if e.info.visibility = Everywhere && understands lit e.grade then
        Some e.name
      else None)
    entries

let accepting_delay lit =
  List.filter_map
    (fun e ->
      let (module G : Grade.S) = e.grade in
      match G.Delay.read lit with
      | Some _ when e.info.visibility = Everywhere -> Some e.name
      | Some _ | None -> None)
    entries

let accepting_bounds lit =
  List.filter_map
    (fun e ->
      let (module G : Grade.S) = e.grade in
      match G.Delay.read lit with
      | Some _ when e.info.visibility = Everywhere && G.needs_op_bounds ->
          Some e.name
      | Some _ | None -> None)
    entries

(* [entries] grouped by [group], preserving both the order groups first occur
   in and the order of the grades within each, as {!grade_modules} lists
   them. *)
let groups =
  let groups =
    List.fold_left
      (fun groups (e : entry) ->
        match groups with
        | (group, front) :: rest when group = e.group ->
            (group, (e.name, e.info) :: front) :: rest
        | _ -> (e.group, [ (e.name, e.info) ]) :: groups)
      [] entries
  in
  List.rev_map
    (fun ((label, short), front) -> { label; short; grades = List.rev front })
    groups
