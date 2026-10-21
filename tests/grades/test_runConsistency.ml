(* Tests of the run consistency of the intervals of the trace grades of timed
   operations, whether some run meets both ends: the joint walk of finite
   traces against a search of the runs covering a guarantee and permitted by a
   bound, over whole time steps and rational delays; the examples of the
   formalisation; the agreement of the decisions of the regular families with
   the joint walk on star-free literals, over whole time steps and rational
   delays, and of the decisions on gap graphs with that by closures over ticks
   on random literals, those over rational delays on literals of whole delays
   without complements or the catch-all letter, whose languages are the same; open ends, pumping, matched operations, durations apart,
   and the counterexamples of intervals whose component counterexample admits
   no run. *)

module Grade = Grades.Grade
module Rational = Grades.Rational
module Delay = Grades.Delay
module TimedTraceGrades = Grades.TimedTraceGrades
module Timed = Grades.RegularTimedTraceGrades
module TimedRational = Grades.RegularTimedTraceGradesRational
open LawChecks

(* [Reader (G)] reads the literals of [G] by the parser, in the grade position
   of a box. *)
module Reader (G : Grade.S) = struct
  module Grammar = Parser.Grammar.Make (Grades.GradeSystem.Identity (G))

  let lit text =
    let lexbuf = Lexing.from_string ("box " ^ text ^ " ()") in
    match Grammar.payload (Parser.Lexer.tokens ()) lexbuf with
    | { it = SugaredAst.GenBox ({ it = SugaredAst.GradeLit rho; _ }, _); _ } ->
        rho
    | _ -> invalid_arg ("not a box of a literal: " ^ text)
end

(* {1 Running times} *)

let names = [ "A"; "B"; "C" ]

(* [bounds_of table] is the running-time bounds of the operations of [table],
   each with the ends of its bounds. *)
let bounds_of table =
  {
    Grade.running_time = (fun o -> List.assoc o table);
    operations = List.map fst table;
  }

let closed (lo, hi) =
  (Grade.Closed (Rational.of_int lo), Grade.Closed (Rational.of_int hi))

let show_end = function
  | Grade.Closed q -> "[" ^ Rational.show q
  | Grade.Open q -> "(" ^ Rational.show q
  | Grade.Unbounded -> "∞"

let show_table table =
  String.concat ", "
    (List.map
       (fun (o, (lo, hi)) ->
         Printf.sprintf "%s:%s, %s" o (show_end lo)
           (match hi with
           | Grade.Closed q -> Rational.show q ^ "]"
           | Grade.Open q -> Rational.show q ^ ")"
           | Grade.Unbounded -> "∞)"))
       table)

(* Random tables of whole running times: lower ends in [0 … 2], upper ends up
   to two more. *)
let whole_tables =
  let state = Random.State.make [| 31 |] in
  List.init 6 (fun _ ->
      List.map
        (fun o ->
          let lo = Random.State.int state 3 in
          (o, closed (lo, lo + Random.State.int state 3)))
        names)

let half n = Rational.make n 2

(* Random tables of rational running times in halves, some ends open. *)
let rational_tables =
  let state = Random.State.make [| 37 |] in
  List.init 6 (fun _ ->
      List.map
        (fun o ->
          let lo = Random.State.int state 3 in
          let hi = lo + Random.State.int state 2 in
          let end_ q =
            if lo < hi && Random.State.bool state then Grade.Open (half q)
            else Grade.Closed (half q)
          in
          (o, (end_ lo, end_ hi)))
        names)

(* {1 Finite traces against a search of runs} *)

(* The joint walk of finite traces over the delays [D], against a search of
   the runs of at most three operations, their delays from [grid]; the traces
   compared have at most two events, the delays of [delays], so that a run
   meeting both, if any, is one of these: by the soundness of the walk, its
   delays are a budget, at most the one delay of the bound, a delay of the
   guarantee less a slack, or a sum of the two, and its operations those of
   the guarantee and, where the guarantee has a delay, the one of the bound. *)
module Search (D : Delay.MONUS) = struct
  module T = Grades.TimedTrace.Make (D)

  (* [runs grid n] is the traces of at most [n] operations of [names], with
     delays of [grid] before, between and after them. *)
  let runs grid n =
    let rec go n =
      let tails =
        if n = 0 then []
        else
          List.concat_map
            (fun o -> List.map (fun t -> T.Ev o :: t) (go (n - 1)))
            names
      in
      List.concat_map
        (fun d -> List.map (fun t -> T.Wait d :: t) ([] :: tails))
        grid
    in
    T.of_list (go n)

  (* [traces delays] is the traces of at most two events, operations of
     [names] and delays of [delays]. *)
  let traces delays =
    let events =
      List.map (fun o -> T.Ev o) names @ List.map (fun d -> T.Wait d) delays
    in
    T.of_list
      (([] :: List.map (fun e -> [ e ]) events)
      @ List.concat_map (fun e -> List.map (fun e' -> [ e; e' ]) events) events
      )

  let search lo hi runs p q =
    List.exists
      (fun x -> T.coverage lo D.zero p x && T.allowance hi D.zero x q)
      runs

  (* [agrees ~name ~running_time ~grid ~delays tables] checks the walk
     against the search on random pairs of traces under each of [tables]. *)
  let agrees ~name ~running_time ~grid ~delays tables =
    let state = Random.State.make [| 41 |] in
    let traces = Array.of_list (traces delays) and runs = runs grid 3 in
    let pick () = traces.(Random.State.int state (Array.length traces)) in
    List.map
      (fun table ->
        let lo o = running_time (fst (List.assoc o table))
        and hi o = running_time (snd (List.assoc o table)) in
        all
          (name ^ ": the joint walk agrees with a search of runs")
          (fun (p, q) ->
            T.show [ p ] ^ ", " ^ T.show [ q ] ^ " at " ^ show_table table)
          (fun (p, q) -> T.consistent lo hi p q = search lo hi runs p q)
          (List.init 150 (fun _ -> (pick (), pick ()))))
      tables
end

module NatSearch = Search (Delay.Nat)
module RationalSearch = Search (Delay.Rational)

let value = function
  | Grade.Closed q | Grade.Open q -> q
  | Grade.Unbounded -> invalid_arg "value"

let finite_traces =
  NatSearch.agrees ~name:"whole time steps"
    ~running_time:(fun b -> Option.get (Rational.to_int (value b)))
    ~grid:[ 0; 1; 2; 3; 4 ] ~delays:[ 1; 2 ] whole_tables
  @ RationalSearch.agrees ~name:"rational delays" ~running_time:value
      ~grid:(List.init 5 half)
      ~delays:[ half 1; half 2 ]
      rational_tables

(* {1 Examples} *)

module TracesReader = Reader (TimedTraceGrades.Interval)
module RationalTracesReader = Reader (TimedTraceGrades.Rational.Interval)

(* [verdicts (module G) cases] checks, for each literal of [cases] with the
   running-time bounds of its table, whether [G] admits a run of it as
   [expected]. *)
let verdicts (module G : Grade.S) cases =
  let module R = Reader (G) in
  List.map
    (fun (text, table, expected) ->
      let rho = R.lit text in
      check
        (G.name ^ ": " ^ text ^ " at " ^ show_table table)
        (G.inhabited (bounds_of table) rho = expected)
        (if expected then "admits no run" else "admits a run"))
    cases

let write ends = [ ("Write", closed ends); ("Read", closed (1, 1)) ]

(* The examples of the formalisation: a delay of 2 guaranteed and a write
   permitted, consistent iff a write takes at least 2; and a write guaranteed
   with only reads permitted. *)
let formalisation =
  let cases =
    [
      ("[{2}, {Write}]", write (2, 3), true);
      ("[{2}, {Write}]", write (1, 3), false);
      ("[{Write}, {Read; Read; Read}]", write (2, 3), false);
      ("[{Write}, {Read; Write}]", write (2, 3), true);
    ]
  in
  verdicts (module TimedTraceGrades.Interval) cases
  @ verdicts (module TimedTraceGrades.Rational.Interval) cases
  @ List.concat_map
      (fun g -> verdicts g cases)
      [
        (module Timed.Interval : Grade.S);
        (module Timed.Symbolic.Interval);
        (module Timed.Concrete.Interval);
        (module Timed.Plain.Interval);
        (module TimedRational.Interval);
        (module TimedRational.Automata.Interval);
      ]

let a_b = [ ("A", closed (1, 3)); ("B", closed (2, 2)); ("C", closed (0, 0)) ]

let rational_a_b =
  [
    ("A", (Grade.Closed (half 1), Grade.Open (half 3)));
    ("B", closed (1, 1));
    ("C", closed (0, 0));
  ]

(* Pumping: a star of the bound banks any delay; matched operations reset the
   slack and the budget; open ends of sets of delays. *)
let regular_examples =
  let whole =
    [
      ("[{5; A}, {(1)*; A}]", a_b, true);
      ("[{A; 5}, {A; (1)*}]", a_b, true);
      ("[{A; 5}, {A; 1; 1; 1}]", a_b, false);
      ("[{A; 2}, {A; 1; 1; 1}]", a_b, true);
      ("[{5; A}, {(1 | B)*; A}]", a_b, true);
      ("[{5; A}, {B*; A}]", a_b, true);
      ("[{5; A}, {C*; A}]", a_b, false);
      ("[{5; A}, {(2; B)*; A}]", a_b, true);
      ("[{1; A}, {(B; A)*}]", a_b, true);
      ("[{2; A}, {B; A}]", a_b, true);
      ("[{3; A}, {B; A}]", a_b, false);
    ]
  in
  let rational =
    [
      ("[{(2, 3)}, {[0, 2]}]", rational_a_b, false);
      ("[{[2, 3)}, {[0, 2]}]", rational_a_b, true);
      ("[{(2, 3)}, {[0, 2)}]", rational_a_b, false);
      ("[{[2, 3)}, {[0, 2)}]", rational_a_b, false);
      ("[{(1/2, 1); B}, {[0, 1/2]; B}]", rational_a_b, false);
      ("[{[1/2, 1); B}, {[0, 1/2]; B}]", rational_a_b, true);
      ("[{(1/2, 1); B}, {[0, 1/2]; A; B}]", rational_a_b, true);
      ("[{5; A}, {(1/2)*; A}]", rational_a_b, true);
      ("[{2; A}, {B; A}]", rational_a_b, false);
      ("[{1; A}, {B; A}]", rational_a_b, true);
    ]
  in
  List.concat_map
    (fun g -> verdicts g whole)
    [
      (module Timed.Interval : Grade.S);
      (module Timed.Symbolic.Interval);
      (module Timed.Concrete.Interval);
      (module Timed.Plain.Interval);
      (module TimedRational.Interval);
      (module TimedRational.Automata.Interval);
    ]
  @ List.concat_map
      (fun g -> verdicts g rational)
      [
        (module TimedRational.Interval : Grade.S);
        (module TimedRational.Automata.Interval);
      ]

(* [reason (module G) table text] is the reason [G] gives for the literal
   [text] under the running-time bounds of [table]. *)
let reason (module G : Grade.S) table text =
  let module R = Reader (G) in
  expect
    (G.name ^ ": the reason for " ^ text)
    (Option.value ~default:"none")
    ~expected:
      (Some
         "admits no run: no run meets both its lower and its upper end: its \
          lower end lasts at least 4 and its upper end at most 3")
    (G.vacuous (bounds_of table) (R.lit text))

let reasons =
  reason (module TimedTraceGrades.Interval) a_b "[{4}, {B; 1}]"
  :: reason (module TimedTraceGrades.Rational.Interval) a_b "[{4}, {B; 1}]"
  :: List.map
       (fun g -> reason g a_b "[{4; A*}, {B; 1}]")
       [
         (module Timed.Interval : Grade.S);
         (module Timed.Symbolic.Interval);
         (module TimedRational.Interval);
         (module TimedRational.Automata.Interval);
       ]
  @ [
      expect "no reason where the durations meet"
        (Option.value ~default:"none")
        ~expected:
          (Some "admits no run: no run meets both its lower and its upper end")
        (Timed.Symbolic.Interval.vacuous (bounds_of a_b)
           (let module R = Reader (Timed.Symbolic.Interval) in
           R.lit "[{A; 5}, {A; 1; 1; 1}]"));
    ]

(* {1 Counterexamples} *)

(* The counterexample to [x ≾ y] by automata is a trace of the upper end of
   [x] outside the closure of that of [y] with the fewest letters, [{A}],
   which with the lower end [{11}] admits no run, so [x] itself is given; by
   gap graphs, the trace with the fewest symbols, [{1; A; 7}], admits a run
   with it. *)
let counterexamples =
  let table =
    [ ("A", closed (5, 5000)); ("B", closed (0, 3)); ("C", closed (2, 7)) ]
  in
  let bounds = bounds_of table in
  let x = "[{11}, {_^2; 7 | A*; B*}]" and y = "[{_^2; 7 | A*; B*}, {11}]" in
  let module Automata = Reader (Timed.Interval) in
  let module Gaps = Reader (Timed.Symbolic.Interval) in
  let by_automata =
    Timed.Interval.counterexample bounds (Automata.lit x) (Automata.lit y)
  and by_gaps =
    Timed.Symbolic.Interval.counterexample bounds (Gaps.lit x) (Gaps.lit y)
  in
  let show = Option.value ~default:"none" in
  [
    expect "automata: the counterexample is the lesser interval" show
      ~expected:(Some (Timed.Interval.show (Automata.lit x)))
      (Option.map Timed.Interval.show by_automata);
    expect "gap graphs: the counterexample is a trace of the upper end" show
      ~expected:(Some "[{11}, {1; A; 7}]")
      (Option.map Timed.Symbolic.Interval.show by_gaps);
    check "the counterexamples admit a run"
      (Option.fold ~none:false
         ~some:(Timed.Interval.inhabited bounds)
         by_automata
      && Option.fold ~none:false
           ~some:(Timed.Symbolic.Interval.inhabited bounds)
           by_gaps)
      "";
  ]

(* {1 Agreement} *)

(* The forms of random regular expressions: sequences and unions; these with
   intersections and repetitions; and these with complements and the catch-all
   letter. *)
type forms = Finite | Positive | Regular

(* Random regular expressions of depth [depth] over [A], [B] and the delays
   [delays], of the [forms]. *)
let random_regex ~forms ~delays ~depth state =
  let atom () =
    match Random.State.int state (if forms = Regular then 5 else 4) with
    | 0 -> Grade.Letter "A"
    | 1 -> Grade.Letter "B"
    | 2 | 3 -> List.nth delays (Random.State.int state (List.length delays))
    | _ -> Grade.Any
  in
  let operators =
    match forms with Finite -> 6 | Positive -> 8 | Regular -> 9
  in
  let rec go depth =
    if depth = 0 then atom ()
    else
      match Random.State.int state operators with
      | 0 | 1 -> atom ()
      | 2 | 3 -> Grade.Seq (go (depth - 1), go (depth - 1))
      | 4 | 5 -> Grade.Union (go (depth - 1), go (depth - 1))
      | 6 -> Grade.Inter (go (depth - 1), go (depth - 1))
      | 7 -> Grade.Star (go (depth - 1))
      | _ -> Grade.Compl (go (depth - 1))
  in
  go depth

let interval (r, r') =
  Grade.Interval (Grade.Closed (Grade.Braces r), Grade.Closed (Grade.Braces r'))

(* [decision (module G) bounds lit] is whether [G] admits a run of the
   interval [lit], [None] if it does not read it or one of its ends has no
   trace. *)
let decision (module G : Grade.S) bounds lit =
  match G.of_lit lit with
  | rho -> (
      match G.vacuous bounds rho with
      | None -> Some true
      | Some r when String.equal r Grade.no_trace -> None
      | Some _ -> Some false)
  | exception Grade.Invalid_literal _ -> None

(* [agreement name reference others tables pairs] checks that the grades
   [others] decide the intervals of [pairs] as [reference] does, where it
   reads them, under each of [tables]. *)
let agreement name reference others tables pairs =
  List.map
    (fun table ->
      let bounds = bounds_of table in
      all name
        (fun (r, r') ->
          "[{" ^ Grade.show_regex r ^ "}, {" ^ Grade.show_regex r' ^ "}] at "
          ^ show_table table)
        (fun p ->
          let lit = interval p in
          match decision reference bounds lit with
          | None -> true
          | expected ->
              List.for_all (fun g -> decision g bounds lit = expected) others)
        pairs)
    tables

let random_pairs ~forms ~delays ~depth seed count =
  let state = Random.State.make [| seed |] in
  List.init count (fun _ ->
      ( random_regex ~forms ~delays ~depth state,
        random_regex ~forms ~delays ~depth state ))

let whole_delays = [ Grade.Tick 0; Grade.Tick 1; Grade.Tick 2; Grade.Tick 3 ]

let rational_delays =
  [ Grade.Tick 0; Grade.Frac (half 1); Grade.Tick 1; Grade.Frac (half 3) ]

let tick_families : (module Grade.S) list =
  [
    (module Timed.Interval);
    (module Timed.Concrete.Interval);
    (module Timed.Plain.Interval);
  ]

let agreements =
  agreement "star-free, whole time steps: the regular families as finite traces"
    (module TimedTraceGrades.Interval)
    ((module Timed.Symbolic.Interval : Grade.S) :: tick_families)
    whole_tables
    (random_pairs ~forms:Finite ~delays:whole_delays ~depth:3 43 120)
  @ agreement
      "star-free, rational delays: the regular families as finite traces"
      (module TimedTraceGrades.Rational.Interval)
      [
        (module TimedRational.Interval : Grade.S);
        (module TimedRational.Automata.Interval);
      ]
      rational_tables
      (random_pairs ~forms:Finite ~delays:rational_delays ~depth:3 47 120)
  @ agreement "whole time steps: gap graphs as closures over ticks"
      (module Timed.Interval)
      [
        (module Timed.Symbolic.Interval : Grade.S);
        (module Timed.Concrete.Interval);
        (module Timed.Plain.Interval);
      ]
      whole_tables
      (random_pairs ~forms:Regular ~delays:whole_delays ~depth:3 53 160)
  @ agreement "rational delays: gap graphs as automata"
      (module TimedRational.Interval)
      [ (module TimedRational.Automata.Interval : Grade.S) ]
      rational_tables
      (random_pairs ~forms:Regular ~delays:rational_delays ~depth:3 59 160)
  @ agreement
      "whole time steps without complements: rational gap graphs as closures \
       over ticks"
      (module Timed.Interval)
      [
        (module TimedRational.Interval : Grade.S);
        (module TimedRational.Automata.Interval);
      ]
      whole_tables
      (random_pairs ~forms:Positive ~delays:whole_delays ~depth:3 61 160)

let () =
  let checks =
    finite_traces @ formalisation @ regular_examples @ reasons @ counterexamples
    @ agreements
  in
  let failures = List.filter (fun c -> not c.passed) checks in
  List.iter (fun c -> Printf.printf "FAIL %s: %s\n" c.name c.detail) failures;
  Printf.printf "%d of %d checks passed\n"
    (List.length checks - List.length failures)
    (List.length checks);
  if failures <> [] then exit 1
