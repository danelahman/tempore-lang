type visibility = Everywhere | Hidden

type implementation = {
  representation : string;
  representation_short : string;
  inclusion : string;
  inclusion_short : string;
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
let traces_timed = ("Traces of timed operations", "Traces (timed ops)")
let regex = ("Regular expressions", "Regex")

let regex_timed =
  ("Regular expressions of timed operations", "Regex (timed ops)")

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

let implementation_text i =
  Printf.sprintf "Represented as %s. Inclusion: %s." i.representation
    i.inclusion

(* The representations of the regular grades, full and short. *)
let symbolic_representation =
  "symbolic expressions over letter sets in normal form, no automaton"

let symbolic_representation_short = "symbolic expressions over letter sets"

let letter_derivatives_representation =
  "expressions over single letters in normal form, no automaton"

let letter_derivatives_representation_short = "expressions over single letters"

let letter_automata_representation =
  "minimal deterministic automata over single letters, built with the grade"

let letter_automata_representation_short =
  "minimal automata over single letters"

let rational_symbolic_representation =
  "symbolic expressions over letter sets and sets of rational delays in normal \
   form, no automaton"

let rational_symbolic_representation_short =
  "symbolic expressions over letter and delay sets"

let rational_automata_representation =
  "minimal deterministic symbolic automata over letter sets and sets of \
   rational delays, built with the grade"

let rational_automata_representation_short =
  "minimal symbolic automata over letter and delay sets"

(* How inclusion is decided for the regular grades without running times, full
   and short. *)
let symbolic_inclusion =
  "emptiness of ρ & ~ρ′, by depth-first search of its gap derivatives, each by \
   a set of delays and a minterm of operations, an automaton built on the fly"

let symbolic_inclusion_short = "gap derivatives by minterms, depth-first"

let letter_inclusion =
  "emptiness of ρ & ~ρ′, by depth-first search of its derivatives by single \
   letters, an automaton built on the fly"

let letter_inclusion_short = "derivatives by single letters, depth-first"

let product_inclusion =
  "emptiness of the product with the complement, by breadth-first search"

let product_inclusion_short = "product with the complement, breadth-first"

(* The implementations of the regular grades. *)
let symbolic =
  {
    representation = symbolic_representation;
    representation_short = symbolic_representation_short;
    inclusion = symbolic_inclusion;
    inclusion_short = symbolic_inclusion_short;
  }

let letter_automata =
  {
    representation = letter_automata_representation;
    representation_short = letter_automata_representation_short;
    inclusion = product_inclusion;
    inclusion_short = product_inclusion_short;
  }

let rational_symbolic =
  {
    representation = rational_symbolic_representation;
    representation_short = rational_symbolic_representation_short;
    inclusion = symbolic_inclusion;
    inclusion_short = symbolic_inclusion_short;
  }

let rational_automata =
  {
    representation = rational_automata_representation;
    representation_short = rational_automata_representation_short;
    inclusion = product_inclusion;
    inclusion_short = product_inclusion_short;
  }

let symbolic_by_letters =
  {
    representation = symbolic_representation;
    representation_short = symbolic_representation_short;
    inclusion = letter_inclusion;
    inclusion_short = letter_inclusion_short;
  }

let letter_derivatives =
  {
    representation = letter_derivatives_representation;
    representation_short = letter_derivatives_representation_short;
    inclusion = letter_inclusion;
    inclusion_short = letter_inclusion_short;
  }

(* How inclusion is decided for the regular grades of timed operations, full
   and short. *)
let timed_symbolic_inclusion =
  "emptiness of the product of the automaton of the gap derivatives of the \
   lesser grade with a reader of the closure of that of the greater grade, by \
   breadth-first search"

let timed_symbolic_inclusion_short =
  "gap derivatives with a closure reader, breadth-first"

let timed_letter_inclusion =
  "emptiness relative to the closure of the greater grade, by depth-first \
   search of the derivatives by single letters with the closure stepped \
   alongside, an automaton built on the fly"

let timed_letter_inclusion_short =
  "derivatives by single letters with closures, depth-first"

let timed_product_inclusion =
  "emptiness of the product with the automaton of the closure of the greater \
   grade, by breadth-first search"

let timed_product_inclusion_short = "product with the closure, breadth-first"

let timed_rational_inclusion =
  "emptiness of the product with a reader of the closure of the greater grade, \
   by breadth-first search"

let timed_rational_inclusion_short =
  "product with a closure reader, breadth-first"

(* The implementations of the regular grades of timed operations. *)
let timed_symbolic =
  {
    symbolic with
    inclusion = timed_symbolic_inclusion;
    inclusion_short = timed_symbolic_inclusion_short;
  }

let timed_letter_automata =
  {
    letter_automata with
    inclusion = timed_product_inclusion;
    inclusion_short = timed_product_inclusion_short;
  }

let timed_rational_symbolic =
  {
    rational_symbolic with
    inclusion = timed_symbolic_inclusion;
    inclusion_short = timed_symbolic_inclusion_short;
  }

let timed_rational_automata =
  {
    rational_automata with
    inclusion = timed_rational_inclusion;
    inclusion_short = timed_rational_inclusion_short;
  }

let timed_symbolic_by_letters =
  {
    symbolic_by_letters with
    inclusion = timed_letter_inclusion;
    inclusion_short = timed_letter_inclusion_short;
  }

let timed_letter_derivatives =
  {
    letter_derivatives with
    inclusion = timed_letter_inclusion;
    inclusion_short = timed_letter_inclusion_short;
  }

(* The descriptions shared by the implementations of a regular grade. *)
let regular_languages =
  "Regular languages of traces over delays and operations, ordered by \
   inclusion."

let timed_lower =
  "Regular languages of traces in the coverage order, operations counting at \
   their lower running-time bounds."

let timed_upper =
  "Regular languages of traces in the allowance order, operations counting at \
   their upper running-time bounds."

let timed_interval =
  "Closed intervals [L, U] of a lower and an upper regular-language bound, \
   compared componentwise."

let rational_languages =
  "Regular languages of traces over rational delays and operations, ordered by \
   inclusion; exact."

let timed_lower_rational =
  "Regular languages of traces over rational delays in the coverage order, \
   operations counting at their lower running-time bounds, which may be \
   fractional; exact."

let timed_upper_rational =
  "Regular languages of traces over rational delays in the allowance order, \
   operations counting at their upper running-time bounds, which may be \
   fractional; exact."

let timed_interval_rational =
  "Closed intervals [L, U] of a lower and an upper regular-language bound over \
   rational delays, compared componentwise; exact."

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
      traces_timed "Lower bounds"
      "Sets of traces in the coverage order, operations counting at their \
       lower running-time bounds.";
    entry
      (module TimedTraceGrades.UpperBound)
      traces_timed "Upper bounds"
      "Sets of traces in the allowance order, operations counting at their \
       upper running-time bounds.";
    entry
      (module TimedTraceGrades.Interval)
      traces_timed "Intervals"
      "Closed intervals [L, U] of a lower and an upper trace bound, compared \
       componentwise.";
    entry
      (module TimedTraceGrades.Rational.LowerBound)
      traces_timed "Lower bounds (rational)"
      "Sets of traces with rational delays in the coverage order, operations \
       counting at their lower running-time bounds, which may be fractional.";
    entry
      (module TimedTraceGrades.Rational.UpperBound)
      traces_timed "Upper bounds (rational)"
      "Sets of traces with rational delays in the allowance order, operations \
       counting at their upper running-time bounds, which may be fractional.";
    entry
      (module TimedTraceGrades.Rational.Interval)
      traces_timed "Intervals (rational)"
      "Closed intervals [L, U] of a lower and an upper trace bound with \
       rational delays, compared componentwise.";
    entry ~implementation:symbolic
      (module RegularTraceGradeDerivative)
      regex "Upper bounds (symbolic)" regular_languages;
    entry ~visibility:Hidden ~implementation:letter_automata
      (module RegularTraceGrade)
      regex "Upper bounds (letter automata)" regular_languages;
    entry ~implementation:rational_symbolic
      (module RegularTraceGradeRational)
      regex "Upper bounds (rational, symbolic)" rational_languages;
    entry ~visibility:Hidden ~implementation:rational_automata
      (module RegularTraceGradeRational.Automata)
      regex "Upper bounds (rational, automata)" rational_languages;
    entry ~visibility:Hidden ~implementation:symbolic_by_letters
      (module RegularTraceGradeDerivative.Concrete)
      regex "Upper bounds (symbolic by letters)" regular_languages;
    entry ~visibility:Hidden ~implementation:letter_derivatives
      (module RegularTraceGradePlain)
      regex "Upper bounds (letter derivatives)" regular_languages;
    entry ~implementation:timed_symbolic
      (module RegularTimedTraceGrades.Symbolic.Lower)
      regex_timed "Lower bounds (symbolic)" timed_lower;
    entry ~implementation:timed_symbolic
      (module RegularTimedTraceGrades.Symbolic.Upper)
      regex_timed "Upper bounds (symbolic)" timed_upper;
    entry ~implementation:timed_symbolic
      (module RegularTimedTraceGrades.Symbolic.Interval)
      regex_timed "Intervals (symbolic)" timed_interval;
    entry ~visibility:Hidden ~implementation:timed_letter_automata
      (module RegularTimedTraceGrades.Lower)
      regex_timed "Lower bounds (letter automata)" timed_lower;
    entry ~visibility:Hidden ~implementation:timed_letter_automata
      (module RegularTimedTraceGrades.Upper)
      regex_timed "Upper bounds (letter automata)" timed_upper;
    entry ~visibility:Hidden ~implementation:timed_letter_automata
      (module RegularTimedTraceGrades.Interval)
      regex_timed "Intervals (letter automata)" timed_interval;
    entry ~implementation:timed_rational_symbolic
      (module RegularTimedTraceGradesRational.Lower)
      regex_timed "Lower bounds (rational, symbolic)" timed_lower_rational;
    entry ~implementation:timed_rational_symbolic
      (module RegularTimedTraceGradesRational.Upper)
      regex_timed "Upper bounds (rational, symbolic)" timed_upper_rational;
    entry ~implementation:timed_rational_symbolic
      (module RegularTimedTraceGradesRational.Interval)
      regex_timed "Intervals (rational, symbolic)" timed_interval_rational;
    entry ~visibility:Hidden ~implementation:timed_rational_automata
      (module RegularTimedTraceGradesRational.Automata.Lower)
      regex_timed "Lower bounds (rational, automata)" timed_lower_rational;
    entry ~visibility:Hidden ~implementation:timed_rational_automata
      (module RegularTimedTraceGradesRational.Automata.Upper)
      regex_timed "Upper bounds (rational, automata)" timed_upper_rational;
    entry ~visibility:Hidden ~implementation:timed_rational_automata
      (module RegularTimedTraceGradesRational.Automata.Interval)
      regex_timed "Intervals (rational, automata)" timed_interval_rational;
    entry ~visibility:Hidden ~implementation:timed_symbolic_by_letters
      (module RegularTimedTraceGrades.Concrete.Lower)
      regex_timed "Lower bounds (symbolic by letters)" timed_lower;
    entry ~visibility:Hidden ~implementation:timed_symbolic_by_letters
      (module RegularTimedTraceGrades.Concrete.Upper)
      regex_timed "Upper bounds (symbolic by letters)" timed_upper;
    entry ~visibility:Hidden ~implementation:timed_symbolic_by_letters
      (module RegularTimedTraceGrades.Concrete.Interval)
      regex_timed "Intervals (symbolic by letters)" timed_interval;
    entry ~visibility:Hidden ~implementation:timed_letter_derivatives
      (module RegularTimedTraceGrades.Plain.Lower)
      regex_timed "Lower bounds (letter derivatives)" timed_lower;
    entry ~visibility:Hidden ~implementation:timed_letter_derivatives
      (module RegularTimedTraceGrades.Plain.Upper)
      regex_timed "Upper bounds (letter derivatives)" timed_upper;
    entry ~visibility:Hidden ~implementation:timed_letter_derivatives
      (module RegularTimedTraceGrades.Plain.Interval)
      regex_timed "Intervals (letter derivatives)" timed_interval;
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
