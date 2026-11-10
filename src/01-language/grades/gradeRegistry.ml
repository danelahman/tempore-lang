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
   described for the web selector and the CLI's [--help], and, if it is built
   on a grade lattice, built over any grade lattice. The single list
   [entries] is the source of truth that [grade_modules], [groups] and
   [accepting] are all read off. *)
type entry = {
  name : string;
  grade : (module Grade.S);
  over_lattice : (GradeLattice.t -> (module Grade.S)) option;
  group : string * string;
  info : info;
}

(* The groups of the grades, each its label and the label's short form. *)
let time = ("Time", "Time")
let finite_run_sets = ("Finite run sets", "Run sets")
let banked_traces = ("Trace grades with banked delays", "Traces (banked)")
let regular_trace_languages = ("Regular trace languages", "Regular languages")
let banked_regex = ("Regex grades with banked delays", "Regex (banked)")
let timed_regex_finite = ("Finite timed regex grades", "Timed regex (finite)")
let timed_regex = ("Timed regex grades", "Timed regex")
let lattices = ("Grade lattices", "Lattices")
let semidirect = ("Semidirect products", "Semidirect")
let energy = ("Time with an energy budget", "Energy")
let counts = ("Counts", "Counts")
let inter_arrival = ("Inter-arrival grades", "Inter-arrival")

let entry ?(visibility = Everywhere) ?implementation ?over_lattice
    (module G : Grade.S) group title description =
  {
    name = G.name;
    grade = (module G : Grade.S);
    over_lattice;
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

(* How inclusion is decided for the regex grades with banked delays, full
   and short. *)
let banked_symbolic_inclusion =
  "emptiness of the product of the automaton of the gap derivatives of the \
   lesser grade with a reader of the closure of that of the greater grade, by \
   breadth-first search"

let banked_symbolic_inclusion_short =
  "gap derivatives with a closure reader, breadth-first"

let banked_letter_inclusion =
  "emptiness relative to the closure of the greater grade, by depth-first \
   search of the derivatives by single letters with the closure stepped \
   alongside, an automaton built on the fly"

let banked_letter_inclusion_short =
  "derivatives by single letters with closures, depth-first"

let banked_product_inclusion =
  "emptiness of the product with the automaton of the closure of the greater \
   grade, by breadth-first search"

let banked_product_inclusion_short = "product with the closure, breadth-first"

let banked_rational_inclusion =
  "emptiness of the product with a reader of the closure of the greater grade, \
   by breadth-first search"

let banked_rational_inclusion_short =
  "product with a closure reader, breadth-first"

(* The implementations of the regex grades with banked delays. *)
let banked_symbolic =
  {
    symbolic with
    inclusion = banked_symbolic_inclusion;
    inclusion_short = banked_symbolic_inclusion_short;
  }

let banked_letter_automata =
  {
    letter_automata with
    inclusion = banked_product_inclusion;
    inclusion_short = banked_product_inclusion_short;
  }

let banked_rational_symbolic =
  {
    rational_symbolic with
    inclusion = banked_symbolic_inclusion;
    inclusion_short = banked_symbolic_inclusion_short;
  }

let banked_rational_automata =
  {
    rational_automata with
    inclusion = banked_rational_inclusion;
    inclusion_short = banked_rational_inclusion_short;
  }

let banked_symbolic_by_letters =
  {
    symbolic_by_letters with
    inclusion = banked_letter_inclusion;
    inclusion_short = banked_letter_inclusion_short;
  }

let banked_letter_derivatives =
  {
    letter_derivatives with
    inclusion = banked_letter_inclusion;
    inclusion_short = banked_letter_inclusion_short;
  }

(* The descriptions shared by the implementations of a regular grade. *)
let regular_languages =
  "Regular languages of traces over delays and operations, ordered by \
   inclusion."

let banked_lower =
  "Regular languages of traces in the coverage order, operations counting at \
   their lower running-time bounds."

let banked_upper =
  "Regular languages of traces in the allowance order, operations counting at \
   their upper running-time bounds."

let banked_interval =
  "Closed intervals [L, U] of a lower and an upper regular-language bound, \
   compared componentwise."

let rational_languages =
  "Regular languages of traces over rational delays and operations, ordered by \
   inclusion; exact."

let banked_lower_rational =
  "Regular languages of traces over rational delays in the coverage order, \
   operations counting at their lower running-time bounds, which may be \
   fractional; exact."

let banked_upper_rational =
  "Regular languages of traces over rational delays in the allowance order, \
   operations counting at their upper running-time bounds, which may be \
   fractional; exact."

let banked_interval_rational =
  "Closed intervals [L, U] of a lower and an upper regular-language bound over \
   rational delays, compared componentwise; exact."

let time_span_words =
  "words of operations, idle waits and time spans, a word below a bound when \
   it follows the skeleton of one of its words: its operations matched in \
   order, and the other items fitting in its time spans, an idle wait holding \
   waiting only"

let timed_regex_lower =
  "Regular languages of " ^ time_span_words
  ^ "; lengths bounded below, ≥d and idle ≥d, operations counting at their \
     lower running-time bounds."

let timed_regex_upper =
  "Regular languages of " ^ time_span_words
  ^ "; lengths bounded above, ≤d and idle ≤d, operations counting at their \
     upper running-time bounds."

let timed_regex_interval =
  "Intervals [L, U] of a lower and an upper bound of regular languages of \
   words with idle waits and time spans, compared componentwise."

let timed_regex_lower_rational =
  "Regular languages of " ^ time_span_words
  ^ "; rational lengths bounded below, ≥d, >d, idle ≥d and idle >d, operations \
     counting at their lower running-time bounds; exact."

let timed_regex_upper_rational =
  "Regular languages of " ^ time_span_words
  ^ "; rational lengths bounded above, ≤d, <d, idle ≤d and idle <d, operations \
     counting at their upper running-time bounds; exact."

let timed_regex_interval_rational =
  "Intervals [L, U] of a lower and an upper bound of regular languages of \
   words with idle waits and time spans of rational lengths, compared \
   componentwise; exact."

let timed_regex_finite_lower =
  "Finite sets of " ^ time_span_words
  ^ "; lengths bounded below, ≥d and idle ≥d, operations counting at their \
     lower running-time bounds."

let timed_regex_finite_upper =
  "Finite sets of " ^ time_span_words
  ^ "; lengths bounded above, ≤d and idle ≤d, operations counting at their \
     upper running-time bounds."

let timed_regex_finite_interval =
  "Intervals [L, U] of a lower and an upper bound of finite sets of words with \
   idle waits and time spans, compared componentwise."

let timed_regex_finite_lower_rational =
  "Finite sets of " ^ time_span_words
  ^ "; rational lengths bounded below, operations counting at their lower \
     running-time bounds, which may be fractional."

let timed_regex_finite_upper_rational =
  "Finite sets of " ^ time_span_words
  ^ "; rational lengths bounded above, operations counting at their upper \
     running-time bounds, which may be fractional."

let timed_regex_finite_interval_rational =
  "Intervals [L, U] of a lower and an upper bound of finite sets of words with \
   idle waits and time spans of rational lengths, compared componentwise."

(* The implementation of the timed regex grades. *)
let time_spans =
  {
    representation =
      "timed regular expressions over operation sets, one-sided time spans and \
       idle waits in normal form";
    representation_short =
      "expressions over time spans, idle waits and operation sets";
    inclusion =
      "breadth-first search of the automaton of the partial derivatives of the \
       lesser grade against a reader of the time spans of the greater one, at \
       extremal lengths";
    inclusion_short =
      "partial derivatives with a time span reader, breadth-first";
  }

let entries =
  [
    entry
      (module TimeGrades.LowerBound)
      time "Lower bounds"
      "At least n time steps, also written [n, ∞); (n, ∞) is n + 1; the unit 0 \
       is greatest.";
    entry
      (module TimeGrades.UpperBound)
      time "Upper bounds"
      "At most n time steps, also written [0, n]; [0, n) is n - 1; the unit 0 \
       is least.";
    entry
      (module TimeGrades.Interval)
      time "Intervals"
      "Intervals [n, m] and [n, ∞) of time steps, ordered by containment; (n, \
       m) is [n + 1, m - 1].";
    entry
      (module RationalTimeGrades.LowerBound)
      time "Lower bounds (rational)"
      "At least q time units, also written [q, ∞), or more than q, written (q, \
       ∞), q a non-negative rational; the unit 0 is greatest.";
    entry
      (module RationalTimeGrades.UpperBound)
      time "Upper bounds (rational)"
      "At most q time units, also written [0, q], or less than q, written [0, \
       q), q a non-negative rational or ∞; the unit 0 is least.";
    entry
      (module RationalTimeGrades.Interval)
      time "Intervals (rational)"
      "Intervals [q, r] and [q, ∞) of time units, each finite endpoint closed \
       or open, as in (q, r] or (q, ∞), q and r non-negative rationals, \
       ordered by containment.";
    entry
      (module FiniteRunSetGrades.UpperBound)
      finite_run_sets "Upper bounds"
      "Sets of traces ordered by inclusion; operations declare no running-time \
       bounds.";
    entry
      (module FiniteRunSetGrades.Rational.UpperBound)
      finite_run_sets "Upper bounds (rational)"
      "Sets of traces with rational delays ordered by inclusion; operations \
       declare no running-time bounds.";
    entry
      (module BankedTraceGrades.LowerBound)
      banked_traces "Lower bounds"
      "Sets of traces in the coverage order, operations counting at their \
       lower running-time bounds.";
    entry
      (module BankedTraceGrades.UpperBound)
      banked_traces "Upper bounds"
      "Sets of traces in the allowance order, operations counting at their \
       upper running-time bounds.";
    entry
      (module BankedTraceGrades.Interval)
      banked_traces "Intervals"
      "Closed intervals [L, U] of a lower and an upper trace bound, compared \
       componentwise.";
    entry
      (module BankedTraceGrades.Rational.LowerBound)
      banked_traces "Lower bounds (rational)"
      "Sets of traces with rational delays in the coverage order, operations \
       counting at their lower running-time bounds, which may be fractional.";
    entry
      (module BankedTraceGrades.Rational.UpperBound)
      banked_traces "Upper bounds (rational)"
      "Sets of traces with rational delays in the allowance order, operations \
       counting at their upper running-time bounds, which may be fractional.";
    entry
      (module BankedTraceGrades.Rational.Interval)
      banked_traces "Intervals (rational)"
      "Closed intervals [L, U] of a lower and an upper trace bound with \
       rational delays, compared componentwise.";
    entry ~implementation:symbolic
      (module RegularTraceLanguagesDerivative)
      regular_trace_languages "Upper bounds (symbolic)" regular_languages;
    entry ~visibility:Hidden ~implementation:letter_automata
      (module RegularTraceLanguages)
      regular_trace_languages "Upper bounds (letter automata)" regular_languages;
    entry ~implementation:rational_symbolic
      (module RegularTraceLanguagesRational)
      regular_trace_languages "Upper bounds (rational, symbolic)"
      rational_languages;
    entry ~visibility:Hidden ~implementation:rational_automata
      (module RegularTraceLanguagesRational.Automata)
      regular_trace_languages "Upper bounds (rational, automata)"
      rational_languages;
    entry ~visibility:Hidden ~implementation:symbolic_by_letters
      (module RegularTraceLanguagesDerivative.Concrete)
      regular_trace_languages "Upper bounds (symbolic by letters)"
      regular_languages;
    entry ~visibility:Hidden ~implementation:letter_derivatives
      (module RegularTraceLanguagesPlain)
      regular_trace_languages "Upper bounds (letter derivatives)"
      regular_languages;
    entry ~implementation:banked_symbolic
      (module BankedRegexGrades.Symbolic.LowerBound)
      banked_regex "Lower bounds (symbolic)" banked_lower;
    entry ~implementation:banked_symbolic
      (module BankedRegexGrades.Symbolic.UpperBound)
      banked_regex "Upper bounds (symbolic)" banked_upper;
    entry ~implementation:banked_symbolic
      (module BankedRegexGrades.Symbolic.Interval)
      banked_regex "Intervals (symbolic)" banked_interval;
    entry ~visibility:Hidden ~implementation:banked_letter_automata
      (module BankedRegexGrades.LowerBound)
      banked_regex "Lower bounds (letter automata)" banked_lower;
    entry ~visibility:Hidden ~implementation:banked_letter_automata
      (module BankedRegexGrades.UpperBound)
      banked_regex "Upper bounds (letter automata)" banked_upper;
    entry ~visibility:Hidden ~implementation:banked_letter_automata
      (module BankedRegexGrades.Interval)
      banked_regex "Intervals (letter automata)" banked_interval;
    entry ~implementation:banked_rational_symbolic
      (module BankedRegexGradesRational.LowerBound)
      banked_regex "Lower bounds (rational, symbolic)" banked_lower_rational;
    entry ~implementation:banked_rational_symbolic
      (module BankedRegexGradesRational.UpperBound)
      banked_regex "Upper bounds (rational, symbolic)" banked_upper_rational;
    entry ~implementation:banked_rational_symbolic
      (module BankedRegexGradesRational.Interval)
      banked_regex "Intervals (rational, symbolic)" banked_interval_rational;
    entry ~visibility:Hidden ~implementation:banked_rational_automata
      (module BankedRegexGradesRational.Automata.LowerBound)
      banked_regex "Lower bounds (rational, automata)" banked_lower_rational;
    entry ~visibility:Hidden ~implementation:banked_rational_automata
      (module BankedRegexGradesRational.Automata.UpperBound)
      banked_regex "Upper bounds (rational, automata)" banked_upper_rational;
    entry ~visibility:Hidden ~implementation:banked_rational_automata
      (module BankedRegexGradesRational.Automata.Interval)
      banked_regex "Intervals (rational, automata)" banked_interval_rational;
    entry ~visibility:Hidden ~implementation:banked_symbolic_by_letters
      (module BankedRegexGrades.Concrete.LowerBound)
      banked_regex "Lower bounds (symbolic by letters)" banked_lower;
    entry ~visibility:Hidden ~implementation:banked_symbolic_by_letters
      (module BankedRegexGrades.Concrete.UpperBound)
      banked_regex "Upper bounds (symbolic by letters)" banked_upper;
    entry ~visibility:Hidden ~implementation:banked_symbolic_by_letters
      (module BankedRegexGrades.Concrete.Interval)
      banked_regex "Intervals (symbolic by letters)" banked_interval;
    entry ~visibility:Hidden ~implementation:banked_letter_derivatives
      (module BankedRegexGrades.Plain.LowerBound)
      banked_regex "Lower bounds (letter derivatives)" banked_lower;
    entry ~visibility:Hidden ~implementation:banked_letter_derivatives
      (module BankedRegexGrades.Plain.UpperBound)
      banked_regex "Upper bounds (letter derivatives)" banked_upper;
    entry ~visibility:Hidden ~implementation:banked_letter_derivatives
      (module BankedRegexGrades.Plain.Interval)
      banked_regex "Intervals (letter derivatives)" banked_interval;
    entry ~implementation:time_spans
      (module TimedRegexGrades.LowerBound)
      timed_regex "Lower bounds" timed_regex_lower;
    entry ~implementation:time_spans
      (module TimedRegexGrades.UpperBound)
      timed_regex "Upper bounds" timed_regex_upper;
    entry ~implementation:time_spans
      (module TimedRegexGrades.Interval)
      timed_regex "Intervals" timed_regex_interval;
    entry ~implementation:time_spans
      (module TimedRegexGrades.Rational.LowerBound)
      timed_regex "Lower bounds (rational)" timed_regex_lower_rational;
    entry ~implementation:time_spans
      (module TimedRegexGrades.Rational.UpperBound)
      timed_regex "Upper bounds (rational)" timed_regex_upper_rational;
    entry ~implementation:time_spans
      (module TimedRegexGrades.Rational.Interval)
      timed_regex "Intervals (rational)" timed_regex_interval_rational;
    entry ~implementation:time_spans
      (module TimedRegexGrades.Finite.LowerBound)
      timed_regex_finite "Lower bounds" timed_regex_finite_lower;
    entry ~implementation:time_spans
      (module TimedRegexGrades.Finite.UpperBound)
      timed_regex_finite "Upper bounds" timed_regex_finite_upper;
    entry ~implementation:time_spans
      (module TimedRegexGrades.Finite.Interval)
      timed_regex_finite "Intervals" timed_regex_finite_interval;
    entry ~implementation:time_spans
      (module TimedRegexGrades.Finite.Rational.LowerBound)
      timed_regex_finite "Lower bounds (rational)"
      timed_regex_finite_lower_rational;
    entry ~implementation:time_spans
      (module TimedRegexGrades.Finite.Rational.UpperBound)
      timed_regex_finite "Upper bounds (rational)"
      timed_regex_finite_upper_rational;
    entry ~implementation:time_spans
      (module TimedRegexGrades.Finite.Rational.Interval)
      timed_regex_finite "Intervals (rational)"
      timed_regex_finite_interval_rational;
    entry
      ~over_lattice:(fun lattice ->
        let module V = LatticeGrades.Over (struct
          let lattice = lattice
        end) in
        (module V.Lattice : Grade.S))
      (module LatticeGrades.Lattice)
      lattices "Grade lattice"
      "A finite lattice of grades, Low < High unless the program declares its \
       own; a computation's grade is the highest element reached, and a box is \
       out of reach once a higher element has been reached.";
    entry
      ~over_lattice:(fun lattice ->
        let module V = LatticeGrades.Over (struct
          let lattice = lattice
        end) in
        (module V.TimeLowerBoundLattice : Grade.S))
      (module LatticeGrades.TimeLowerBoundLattice)
      lattices "Lower bounds × lattice (embargoes)"
      "A time lower bound paired with an element of the grade lattice: at \
       least n time steps, touching nothing above the element.";
    entry
      ~over_lattice:(fun lattice ->
        let module V = LatticeGrades.Over (struct
          let lattice = lattice
        end) in
        (module V.TimeUpperBoundLattice : Grade.S))
      (module LatticeGrades.TimeUpperBoundLattice)
      lattices "Upper bounds × lattice (expiring capabilities)"
      "A time upper bound paired with an element of the grade lattice: at most \
       n time steps, touching nothing above the element.";
    entry
      ~over_lattice:(fun lattice ->
        let module V = LatticeGrades.Over (struct
          let lattice = lattice
        end) in
        (module V.TimeIntervalLattice : Grade.S))
      (module LatticeGrades.TimeIntervalLattice)
      lattices "Intervals × lattice"
      "A rational time interval paired with an element of the grade lattice: a \
       time within the interval, touching nothing above the element.";
    entry
      ~over_lattice:(fun lattice ->
        let module V = LatticeGrades.Over (struct
          let lattice = lattice
        end) in
        (module V.FlowSensitiveLevels : Grade.S))
      (module LatticeGrades.FlowSensitiveLevels)
      lattices "Flow-sensitive levels"
      "An element of the grade lattice paired with the element at which each \
       output is written; later outputs are raised to the element reached \
       before them.";
    entry
      (module EnergyGrades.TimeUpperBoundEnergy)
      energy "Upper bounds × energy"
      "A time upper bound paired with an energy budget: at most n time steps, \
       drawing at most e units of energy, such as (5, 12); delays draw none.";
    entry
      (module WatermarkGrades.Watermarks)
      semidirect "Watermark grades"
      "Triples (t, d, h) of the trough, the net change and the peak of a \
       system resource held, such as open files; later levels are shifted by \
       the earlier change.";
    entry
      (module CallTimeSetGrades.CallTimeSets)
      semidirect "Call-time sets"
      "Pairs (T, E) of the possible durations and the times at which each \
       operation is called; later times are shifted by the earlier durations.";
    entry
      (module ModeSwitchCostGrades.ModeSwitchCosts)
      semidirect "Mode-switch costs"
      "Max-plus matrices of the costs between named modes, such as (Off, On, \
       2); an operation gets stuck from the modes its grade does not start \
       from, and a change of mode costs at least 1.";
    entry
      (module ModeTimeGrades.ModeTimes)
      semidirect "Mode times"
      "The time spent in each mode of a device or a material, over traces that \
       change modes, such as (Cold, Cold, (Out, [0, 30])); an operation runs \
       in the mode it starts from, and its change of mode takes effect at its \
       end.";
    entry
      (module CountGrades.AtMost)
      counts "At-most counts"
      "At most n calls of each operation, by name, such as ((Auth, 1), (Send, \
       3)); delays count nothing.";
    entry
      (module CountGrades.AtLeast)
      counts "At-least counts"
      "At least n calls of each operation, by name, such as ((Approve, 2), \
       (Test, 1)); delays count nothing, and the unit 0 is greatest.";
    entry
      (module InterArrivalGrades)
      inter_arrival "Inter-arrival grades"
      "How often an operation recurs: the time between consecutive \
       occurrences, at most and at least, such as (Beat, [0, 20]); operations \
       take their running times, occurring at their start.";
  ]

let grade_modules = List.map (fun e -> (e.name, e.grade)) entries
let default_name = fst (List.hd grade_modules)

(* The grades shown [Everywhere], each the name and the module of an entry:
   with a grade lattice [lattice], those built on a grade lattice, over it. *)
let offered lattice =
  List.filter_map
    (fun e ->
      match (lattice, e.over_lattice) with
      | _ when e.info.visibility <> Everywhere -> None
      | None, _ -> Some (e.name, e.grade)
      | Some lattice, Some over -> Some (e.name, over lattice)
      | Some _, None -> None)
    entries

let accepting ?lattice lit =
  List.filter_map
    (fun (name, (module G : Grade.S)) ->
      if G.accepts lit then Some name else None)
    (offered lattice)

let accepting_delay ?lattice lit =
  List.filter_map
    (fun (name, (module G : Grade.S)) ->
      Option.map (fun _ -> name) (G.Delay.read lit))
    (offered lattice)

let accepting_bounds ?lattice lit =
  List.filter_map
    (fun (name, (module G : Grade.S)) ->
      match G.Delay.read lit with
      | Some _ when G.needs_op_bounds -> Some name
      | Some _ | None -> None)
    (offered lattice)

let find name = List.find_opt (fun e -> String.equal e.name name) entries

let over_lattice name lattice =
  Option.bind (find name) (fun e ->
      Option.map (fun over -> over lattice) e.over_lattice)

let uses_lattice name =
  match find name with Some { over_lattice = Some _; _ } -> true | _ -> false

let without_lattice name =
  Printf.sprintf
    "The `%s` grade algebra is not built on a grade lattice, so none can be \
     declared"
    name

(* [entries] grouped by [group], preserving both the order groups first occur
   in and the order of the grades within each, as {!grade_modules} lists
   them. *)
let groups =
  let same (label, short) (label', short') =
    String.equal label label' && String.equal short short'
  in
  let labels =
    List.fold_left
      (fun seen (e : entry) ->
        if List.exists (same e.group) seen then seen else e.group :: seen)
      [] entries
  in
  List.rev_map
    (fun ((label, short) as group) ->
      {
        label;
        short;
        grades =
          List.filter_map
            (fun (e : entry) ->
              if same e.group group then Some (e.name, e.info) else None)
            entries;
      })
    labels

let info name = Option.map (fun e -> e.info) (find name)

let listed group =
  List.filter (fun (_, info) -> info.visibility = Everywhere) group.grades
