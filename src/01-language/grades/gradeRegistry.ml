type visibility = Everywhere | Cli_only

type implementation = {
  structure : string;
  labels : string;
  inclusion : string;
  summary : string;
}

type info = {
  title : string;
  description : string;
  visibility : visibility;
  implementation : implementation option;
}

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

let entry ?(visibility = Everywhere) ?implementation (module G : Grade.S) group
    title description =
  {
    name = G.name;
    grade = (module G : Grade.S);
    group;
    info = { title; description; visibility; implementation };
  }

(* The data structures of the regular grades and the expressions or letters
   that label them. *)
let derivatives = "derivatives"
let automata = "minimal deterministic automata"
let symbolic_automata = "minimal deterministic symbolic automata"
let letter_set_expressions = "symbolic expressions over letter sets"
let letter_expressions = "expressions over single letters"
let single_letters = "single letters"
let delay_sets = "letter sets and sets of rational delays"

(* Derivatives are taken of expressions, automata run over letters. *)
let decided_by i =
  Printf.sprintf "Decided by %s %s %s, %s." i.structure
    (if i.structure = derivatives then "of" else "over")
    i.labels i.inclusion

(* The implementations of the regular grades. *)
let symbolic =
  {
    structure = derivatives;
    labels = letter_set_expressions;
    inclusion =
      "derivatives by minterms; inclusion by depth-first search of the \
       derivatives of ρ & ~ρ′";
    summary =
      "derivatives over letter sets by minterms; inclusion by derivative search";
  }

let letter_automata =
  {
    structure = automata;
    labels = single_letters;
    inclusion =
      "inclusion by breadth-first search of the product with the complement";
    summary =
      "minimal automata over single letters; inclusion by product search";
  }

let rational_symbolic =
  {
    structure = symbolic_automata;
    labels = delay_sets;
    inclusion =
      "determinised by minterms; inclusion by breadth-first search of the \
       product with the complement";
    summary =
      "minimal symbolic automata over letter and delay sets; inclusion by \
       product search";
  }

let symbolic_by_letters =
  {
    structure = derivatives;
    labels = letter_set_expressions;
    inclusion =
      "derivatives by single letters; inclusion as for \
       regex-upper-bound-symbolic";
    summary =
      "derivatives over letter sets by single letters; inclusion by derivative \
       search";
  }

let letter_derivatives =
  {
    structure = derivatives;
    labels = letter_expressions;
    inclusion =
      "derivatives by single letters; inclusion as for \
       regex-upper-bound-symbolic";
    summary = "derivatives over single letters; inclusion by derivative search";
  }

(* The implementations of the regular grades with costs. *)
let closure_search =
  "inclusion by depth-first search of the derivatives, the closure of the \
   greater grade stepped alongside"

let closure_search_summary = "inclusion by derivative search with closures"

let cost_symbolic =
  {
    symbolic with
    inclusion = "derivatives by minterms; " ^ closure_search;
    summary =
      "derivatives over letter sets by minterms; " ^ closure_search_summary;
  }

let cost_letter_automata =
  {
    letter_automata with
    inclusion =
      "inclusion by breadth-first search of the product with the automaton of \
       the closure";
    summary =
      "minimal automata over single letters; inclusion by closure product \
       search";
  }

let cost_rational_symbolic =
  {
    rational_symbolic with
    inclusion =
      "inclusion by breadth-first search of the product with a reader of the \
       closure";
    summary =
      "minimal symbolic automata over letter and delay sets; inclusion by \
       closure-reader search";
  }

let cost_symbolic_by_letters =
  {
    symbolic_by_letters with
    inclusion = "derivatives by single letters; " ^ closure_search;
    summary =
      "derivatives over letter sets by single letters; "
      ^ closure_search_summary;
  }

let cost_letter_derivatives =
  {
    letter_derivatives with
    inclusion = "derivatives by single letters; " ^ closure_search;
    summary = "derivatives over single letters; " ^ closure_search_summary;
  }

(* The descriptions shared by the implementations of a regular grade. *)
let regular_languages =
  "Regular languages of traces over delays and operations, ordered by \
   inclusion."

let cost_lower =
  "Regular languages of traces in the coverage order, operations costing their \
   lower running-time bounds."

let cost_upper =
  "Regular languages of traces in the allowance order, operations costing \
   their upper running-time bounds."

let cost_interval =
  "Closed intervals [L, U] of a lower and an upper regular-language bound, \
   compared componentwise."

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
      time "Intervals"
      "Intervals [n, m] and [n, ∞) of time steps, ordered by containment; (n, \
       m) is [n + 1, m - 1].";
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
      "Intervals [q, r] and [q, ∞) of time units, each finite endpoint closed \
       or open, as in (q, r] or (q, ∞), q and r non-negative rationals, \
       ordered by containment.";
    entry
      (module TraceInclusionGrades.UpperBound)
      traces "Upper bounds"
      "Sets of traces ordered by inclusion; operations declare no running-time \
       bounds.";
    entry
      (module TraceInclusionGrades.Rational.UpperBound)
      traces "Upper bounds (rational)"
      "Sets of traces with rational delays ordered by inclusion; operations \
       declare no running-time bounds.";
    entry
      (module TimedTraceGrades.LowerBound)
      traces_costs "Lower bounds"
      "Sets of traces in the coverage order, operations costing their lower \
       running-time bounds.";
    entry
      (module TimedTraceGrades.UpperBound)
      traces_costs "Upper bounds"
      "Sets of traces in the allowance order, operations costing their upper \
       running-time bounds.";
    entry
      (module TimedTraceGrades.Interval)
      traces_costs "Intervals"
      "Closed intervals [L, U] of a lower and an upper trace bound, compared \
       componentwise.";
    entry
      (module TimedTraceGrades.Rational.LowerBound)
      traces_costs "Lower bounds (rational)"
      "Sets of traces with rational delays in the coverage order, operations \
       costing their lower running-time bounds, which may be fractional.";
    entry
      (module TimedTraceGrades.Rational.UpperBound)
      traces_costs "Upper bounds (rational)"
      "Sets of traces with rational delays in the allowance order, operations \
       costing their upper running-time bounds, which may be fractional.";
    entry
      (module TimedTraceGrades.Rational.Interval)
      traces_costs "Intervals (rational)"
      "Closed intervals [L, U] of a lower and an upper trace bound with \
       rational delays, compared componentwise.";
    entry ~implementation:symbolic
      (module RegularTraceGradeDerivative)
      regex "Upper bounds (symbolic)" regular_languages;
    entry ~implementation:letter_automata
      (module RegularTraceGrade)
      regex "Upper bounds (letter automata)" regular_languages;
    entry ~implementation:rational_symbolic
      (module RegularTraceGradeRational)
      regex "Upper bounds (rational, symbolic)"
      "Regular languages of traces over rational delays and operations, \
       ordered by inclusion; exact.";
    entry ~visibility:Cli_only ~implementation:symbolic_by_letters
      (module RegularTraceGradeDerivative.Concrete)
      regex "Upper bounds (symbolic by letters)" regular_languages;
    entry ~visibility:Cli_only ~implementation:letter_derivatives
      (module RegularTraceGradePlain)
      regex "Upper bounds (letter derivatives)" regular_languages;
    entry ~implementation:cost_symbolic
      (module RegularCostTraceGrades.Symbolic.Lower)
      regex_costs "Lower bounds (symbolic)" cost_lower;
    entry ~implementation:cost_symbolic
      (module RegularCostTraceGrades.Symbolic.Upper)
      regex_costs "Upper bounds (symbolic)" cost_upper;
    entry ~implementation:cost_symbolic
      (module RegularCostTraceGrades.Symbolic.Interval)
      regex_costs "Intervals (symbolic)" cost_interval;
    entry ~implementation:cost_letter_automata
      (module RegularCostTraceGrades.Lower)
      regex_costs "Lower bounds (letter automata)" cost_lower;
    entry ~implementation:cost_letter_automata
      (module RegularCostTraceGrades.Upper)
      regex_costs "Upper bounds (letter automata)" cost_upper;
    entry ~implementation:cost_letter_automata
      (module RegularCostTraceGrades.Interval)
      regex_costs "Intervals (letter automata)" cost_interval;
    entry ~implementation:cost_rational_symbolic
      (module RegularCostTraceGradesRational.Lower)
      regex_costs "Lower bounds (rational, symbolic)"
      "Regular languages of traces over rational delays in the coverage order, \
       operations costing their lower running-time bounds, which may be \
       fractional; exact.";
    entry ~implementation:cost_rational_symbolic
      (module RegularCostTraceGradesRational.Upper)
      regex_costs "Upper bounds (rational, symbolic)"
      "Regular languages of traces over rational delays in the allowance \
       order, operations costing their upper running-time bounds, which may be \
       fractional; exact.";
    entry ~implementation:cost_rational_symbolic
      (module RegularCostTraceGradesRational.Interval)
      regex_costs "Intervals (rational, symbolic)"
      "Closed intervals [L, U] of a lower and an upper regular-language bound \
       over rational delays, compared componentwise; exact.";
    entry ~visibility:Cli_only ~implementation:cost_symbolic_by_letters
      (module RegularCostTraceGrades.Concrete.Lower)
      regex_costs "Lower bounds (symbolic by letters)" cost_lower;
    entry ~visibility:Cli_only ~implementation:cost_symbolic_by_letters
      (module RegularCostTraceGrades.Concrete.Upper)
      regex_costs "Upper bounds (symbolic by letters)" cost_upper;
    entry ~visibility:Cli_only ~implementation:cost_symbolic_by_letters
      (module RegularCostTraceGrades.Concrete.Interval)
      regex_costs "Intervals (symbolic by letters)" cost_interval;
    entry ~visibility:Cli_only ~implementation:cost_letter_derivatives
      (module RegularCostTraceGrades.Plain.Lower)
      regex_costs "Lower bounds (letter derivatives)" cost_lower;
    entry ~visibility:Cli_only ~implementation:cost_letter_derivatives
      (module RegularCostTraceGrades.Plain.Upper)
      regex_costs "Upper bounds (letter derivatives)" cost_upper;
    entry ~visibility:Cli_only ~implementation:cost_letter_derivatives
      (module RegularCostTraceGrades.Plain.Interval)
      regex_costs "Intervals (letter derivatives)" cost_interval;
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
      (module ResourceLevelGrades.ResourceLevels)
      semidirect "Resource levels"
      "Triples (t, d, h) of the trough, the net change and the peak of a \
       resource held, such as open files; later levels are shifted by the \
       earlier change.";
    entry
      (module WindowedScheduleGrades.WindowedSchedules)
      semidirect "Windowed schedules"
      "Pairs (T, E) of the possible durations and the times at which each \
       operation happens; later times are shifted by the earlier durations.";
    entry
      (module ModeSwitchCostGrades.ModeSwitchCosts)
      semidirect "Mode-switch costs"
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
