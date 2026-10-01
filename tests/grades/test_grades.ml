(* Unit tests of the laws of the delays, the security-level grade, the product
   construction and its counterexamples, the witnesses of closed conditions,
   the interpretation of literals by the grades of
   [GradeRegistry.grade_modules], the laws and the declared flags of these
   grades on samples of each family of grades, the laws of the components and
   actions of the semidirect products, and the laws of the finite grades on
   all their elements. *)

module Grade = Grades.Grade
module TimeGrades = Grades.TimeGrades
module RationalTimeGrades = Grades.RationalTimeGrades
module Rational = Grades.Rational
module TimedTraceGrades = Grades.TimedTraceGrades
module TraceInclusionGrades = Grades.TraceInclusionGrades
module LevelGrades = Grades.LevelGrades
module GradeConstructions = Grades.GradeConstructions
module GradeRegistry = Grades.GradeRegistry
open LawChecks

let show_bool = string_of_bool
let show_names names = "[" ^ String.concat "; " names ^ "]"

let bounds =
  {
    Grade.cost =
      (fun _ -> Rational.(Grade.Closed (of_int 1), Grade.Closed (of_int 2)));
    operations = [];
  }

(* [contains s sub] is whether [sub] occurs in [s]. *)
let contains s sub =
  let n = String.length s and k = String.length sub in
  let rec from i = i + k <= n && (String.sub s i k = sub || from (i + 1)) in
  from 0

(* [reads name grade lit expected] checks that [grade] reads [lit] as the grade
   it shows as [expected]. *)
let reads name (module G : Grade.S) lit expected =
  match G.of_lit lit with
  | rho -> expect (G.name ^ ": " ^ name) Fun.id ~expected (G.show rho)
  | exception Grade.Invalid_literal (_, reason) ->
      check (G.name ^ ": " ^ name) false ("rejected: " ^ reason)

(* [rejects name grade lit fragment] checks that [grade] rejects [lit] for a
   reason containing [fragment]. *)
let rejects name (module G : Grade.S) lit fragment =
  match G.of_lit lit with
  | rho -> check (G.name ^ ": " ^ name) false ("read as " ^ G.show rho)
  | exception Grade.Invalid_literal (_, reason) ->
      check
        (G.name ^ ": " ^ name)
        (contains reason fragment)
        ("the reason '" ^ reason ^ "' does not mention '" ^ fragment ^ "'")

let levels =
  let open LevelGrades in
  let module L = SecurityLevels in
  let show = L.show in
  [
    check "levels: Low below High" (L.leq bounds Low High) "Low ≾ High";
    check "levels: High not below Low"
      (not (L.leq bounds High Low))
      "High ≾ Low";
    check "levels: reflexive" (L.leq bounds High High) "High ≾ High";
    expect "levels: join" show ~expected:High (L.join Low High);
    expect "levels: join of Low" show ~expected:Low (L.join Low Low);
    expect "levels: product is the join" show ~expected:High (L.mul High Low);
    expect "levels: unit" show ~expected:Low L.one;
    expect "levels: top" show ~expected:High L.top;
    expect "levels: delays touch no level" show ~expected:Low
      (L.of_delay (Rational.of_int 5));
    expect "levels: no delay is the unit" show ~expected:L.one
      (L.of_delay Rational.zero);
    expect "levels: time shadow" show ~expected:Low
      (L.of_bounds Rational.(Grade.Closed (of_int 1), Grade.Closed (of_int 2)));
    check "levels: equal" (L.equal bounds High High) "High = High";
    expect "levels: unit least" show_bool ~expected:true L.unit_least;
    expect "levels: commutative" show_bool ~expected:true L.commutative;
    expect "levels: no runtime bounds" show_bool ~expected:false
      L.needs_op_bounds;
    expect "levels: atomic" show_bool ~expected:true (L.is_atomic "Send" High);
    expect "levels: no events" show_names ~expected:[] (L.events High);
  ]

module TimeLevels = LevelGrades.TimeLowerBoundLevels
module UpperLevels = LevelGrades.TimeUpperBoundLevels

(* The levels over the whole-step delays of the trace grades. *)
module NatLevels = LevelGrades.Make (Grades.Delay.Nat)

module TraceLevels =
  GradeConstructions.Product
    (TimedTraceGrades.UpperBound)
    (NatLevels.SecurityLevels)

module RegexLevels =
  GradeConstructions.Product
    (Grades.RegularTraceGradeDerivative)
    (NatLevels.SecurityLevels)

let lit_of_pair n level = Grade.Tuple [ Grade.Int n; Grade.Name level ]

(* [span l h] is the interval literal from [l] to [h], an endpoint [⊤] below
   or [∞] above standing for an infinite one. *)
let span l h =
  Grade.Interval
    ( (match l with Grade.Top -> Grade.Unbounded | l -> Grade.Closed l),
      match h with Grade.Inf -> Grade.Unbounded | h -> Grade.Closed h )

(* Counterexamples: in the component where the order fails, with the other
   component of the lesser grade, and none from grades that offer none. *)
let counterexamples =
  let regex r level =
    RegexLevels.of_lit (Grade.Tuple [ Grade.Braces r; Grade.Name level ])
  in
  let read = Grade.Letter "Read" and write = Grade.Letter "Write" in
  let show = function Some e -> RegexLevels.show e | None -> "none" in
  let time n level = TimeLevels.of_lit (lit_of_pair n level) in
  [
    expect "counterexample: in the first component" Fun.id
      ~expected:"({Write}, Low)"
      (show
         (RegexLevels.counterexample bounds
            (regex (Grade.Union (read, write)) "Low")
            (regex read "High")));
    expect "counterexample: none from the second component" Fun.id
      ~expected:"none"
      (show
         (RegexLevels.counterexample bounds (regex read "High")
            (regex (Grade.Union (read, write)) "Low")));
    expect "counterexample: none where the order holds" Fun.id ~expected:"none"
      (show
         (RegexLevels.counterexample bounds (regex read "Low")
            (regex (Grade.Union (read, write)) "High")));
    check "counterexample: none from time and levels"
      (Option.is_none
         (TimeLevels.counterexample bounds (time 2 "High") (time 3 "Low")))
      "";
  ]

let products =
  let p n level = TimeLevels.of_lit (lit_of_pair n level) in
  let show = TimeLevels.show in
  let traces r level =
    TraceLevels.of_lit (Grade.Tuple [ Grade.Braces r; level ])
  in
  let send = Grade.Letter "Send" in
  let send_top = traces send Grade.Top in
  let send_low = traces send (Grade.Name "Low") in
  let send_then_tick =
    traces (Grade.Seq (send, Grade.Tick 1)) (Grade.Name "Low")
  in
  [
    expect "product: name" Fun.id ~expected:"time-lower-bound-levels"
      TimeLevels.name;
    expect "product: generic name" Fun.id
      ~expected:"traces-cost-upper-bound×security-levels" TraceLevels.name;
    check "product: at least as long and as low"
      (TimeLevels.leq bounds (p 3 "Low") (p 2 "High"))
      "(3, Low) ≾ (2, High)";
    check "product: too short"
      (not (TimeLevels.leq bounds (p 2 "Low") (p 3 "Low")))
      "(2, Low) ≾ (3, Low)";
    check "product: too high"
      (not (TimeLevels.leq bounds (p 3 "High") (p 3 "Low")))
      "(3, High) ≾ (3, Low)";
    expect "product: join" Fun.id ~expected:"(3, High)"
      (show (TimeLevels.join (p 3 "Low") (p 5 "High")));
    expect "product: product" Fun.id ~expected:"(8, High)"
      (show (TimeLevels.mul (p 3 "Low") (p 5 "High")));
    expect "product: unit" Fun.id ~expected:"(0, Low)" (show TimeLevels.one);
    expect "product: top" Fun.id ~expected:"(0, High)" (show TimeLevels.top);
    expect "product: ticks" Fun.id ~expected:"(4, Low)"
      (show (TimeLevels.of_delay 4));
    expect "product: time shadow" Fun.id ~expected:"(1, Low)"
      (show (TimeLevels.of_bounds (Grade.Closed 1, Grade.Closed 2)));
    check "product: equal"
      (TimeLevels.equal bounds (p 3 "Low")
         (TimeLevels.of_lit (lit_of_pair 3 "Low")))
      "(3, Low) = (3, Low)";
    expect "product: unit least iff in both" show_bool ~expected:false
      TimeLevels.unit_least;
    expect "product: unit least in both" show_bool ~expected:true
      UpperLevels.unit_least;
    expect "product: commutative in both" show_bool ~expected:true
      TimeLevels.commutative;
    expect "product: commutative iff in both" show_bool ~expected:false
      TraceLevels.commutative;
    expect "product: mixed order symbols" Fun.id ~expected:"≾"
      TimeLevels.leq_symbol;
    expect "product: shared order symbol" Fun.id ~expected:"<="
      UpperLevels.leq_symbol;
    expect "product: runtime bounds from either component" show_bool
      ~expected:true TraceLevels.needs_op_bounds;
    expect "product: no runtime bounds in neither" show_bool ~expected:false
      TimeLevels.needs_op_bounds;
    expect "product: events of either component" show_names ~expected:[ "Send" ]
      (TraceLevels.events send_top);
    expect "product: atomic in both" show_bool ~expected:true
      (TraceLevels.is_atomic "Send" send_low);
    expect "product: atomic iff in both" show_bool ~expected:false
      (TraceLevels.is_atomic "Send" send_then_tick);
    expect "product: implied bounds"
      (function
        | Some (lo, hi) -> Grade.show_interval Rational.show lo hi
        | None -> "None")
      ~expected:
        (Some Rational.(Grade.Closed (of_int 1), Grade.Closed (of_int 2)))
      (TraceLevels.implied_bounds bounds send_low);
    expect "product: level component" Fun.id ~expected:"(3, High)"
      (show (p 3 "High"));
  ]

let time_lower = (module TimeGrades.LowerBound : Grade.S)
let time_upper = (module TimeGrades.UpperBound : Grade.S)
let time_interval = (module TimeGrades.Interval : Grade.S)
let rational_lower = (module RationalTimeGrades.LowerBound : Grade.S)
let rational_upper = (module RationalTimeGrades.UpperBound : Grade.S)
let rational_interval = (module RationalTimeGrades.Interval : Grade.S)
let traces_lower = (module TimedTraceGrades.LowerBound : Grade.S)
let traces_upper = (module TimedTraceGrades.UpperBound : Grade.S)
let traces_interval = (module TimedTraceGrades.Interval : Grade.S)

let rational_traces_lower =
  (module TimedTraceGrades.Rational.LowerBound : Grade.S)

let rational_traces_upper =
  (module TimedTraceGrades.Rational.UpperBound : Grade.S)

let rational_traces_interval =
  (module TimedTraceGrades.Rational.Interval : Grade.S)

let inclusion_upper = (module TraceInclusionGrades.UpperBound : Grade.S)

let rational_inclusion_upper =
  (module TraceInclusionGrades.Rational.UpperBound : Grade.S)

let regex_upper = (module Grades.RegularTraceGradeDerivative : Grade.S)
let rational_regex_upper = (module Grades.RegularTraceGradeRational : Grade.S)

let rational_regex_costs_lower =
  (module Grades.RegularCostTraceGradesRational.Lower : Grade.S)

let rational_regex_costs_upper =
  (module Grades.RegularCostTraceGradesRational.Upper : Grade.S)

let rational_regex_costs_interval =
  (module Grades.RegularCostTraceGradesRational.Interval : Grade.S)

let security_levels = (module LevelGrades.SecurityLevels : Grade.S)

let resource_levels =
  (module Grades.ResourceLevelGrades.ResourceLevels : Grade.S)

let windowed_schedules =
  (module Grades.WindowedScheduleGrades.WindowedSchedules : Grade.S)

let flow_levels = (module LevelGrades.FlowLevels : Grade.S)
let counts_upper = (module Grades.CountGrades.UpperBound : Grade.S)

let mode_switch_costs =
  (module Grades.ModeSwitchCostGrades.ModeSwitchCosts : Grade.S)

let time_lower_levels = (module TimeLevels : Grade.S)
let time_upper_levels = (module UpperLevels : Grade.S)

let literals =
  let open Grade in
  let seq r s = Seq (r, s) and union r s = Union (r, s) in
  let send = Letter "Send" in
  [
    rejects "negative integer" time_lower (Int (-1)) "must be non-negative";
    rejects "fraction, whole steps" time_upper
      (Rat (Rational.make 3 2))
      "not fractions such as '3/2'";
    rejects "fractional endpoint, whole steps" time_interval
      (Interval (Closed (Rat (Rational.make 1 3)), Unbounded))
      "endpoints are integers";
    reads "fraction, decimal" rational_upper (Rat (Rational.make 3 2)) "1.5";
    reads "fraction, quotient" rational_lower (Rat (Rational.make 1 3)) "1/3";
    reads "integer, rational" rational_upper (Int 2) "2";
    reads "infinity, rational" rational_upper Inf "∞";
    reads "open interval, rational" rational_interval
      (Interval (Closed (Rat (Rational.make 1 3)), Unbounded))
      "[1/3, ∞)";
    reads "interval, rational" rational_interval
      (Interval (Closed (Rat (Rational.make 1 8)), Closed (Int 2)))
      "[0.125, 2]";
    rejects "negative fraction" rational_upper
      (Rat (Rational.make (-1) 2))
      "must be non-negative";
    rejects "reversed interval, rational" rational_interval
      (Interval (Closed (Rat (Rational.make 3 2)), Closed (Int 1)))
      "must satisfy n <= m";
    rejects "pair, rational" rational_upper
      (Tuple [ Int 1; Int 2 ])
      "grades are plain numbers or '∞', not pairs";
    rejects "negative interval endpoint" time_interval
      (Interval (Closed (Int (-1)), Closed (Int 5)))
      "must be non-negative";
    rejects "interval unbounded below" time_interval
      (Interval (Unbounded, Closed (Int 5)))
      "must be non-negative";
    reads "pair for an open interval" time_interval
      (Tuple [ Int 1; Int 5 ])
      "[2, 4]";
    reads "half-open interval" time_interval
      (Interval (Closed (Int 1), Open (Int 5)))
      "[1, 4]";
    reads "interval open below" time_interval
      (Interval (Open (Int 1), Unbounded))
      "[2, ∞)";
    rejects "open interval of no step" time_interval
      (Tuple [ Int 1; Int 2 ])
      "the interval contains no integer";
    rejects "empty open interval" time_interval
      (Interval (Closed (Int 2), Open (Int 2)))
      "n < m at an open endpoint";
    reads "pair for an open interval, rational" rational_interval
      (Tuple [ Rat (Rational.make 1 2); Inf ])
      "(0.5, ∞)";
    reads "open interval, rational" rational_interval
      (Tuple [ Rat (Rational.make 1 2); Int 3 ])
      "(0.5, 3)";
    reads "half-open interval, rational" rational_interval
      (Interval (Open (Rat (Rational.make 1 2)), Closed (Int 3)))
      "(0.5, 3]";
    reads "interval open above, rational" rational_interval
      (Interval (Closed (Int 0), Open (Rat (Rational.make 1 3))))
      "[0, 1/3)";
    rejects "empty open interval, rational" rational_interval
      (Tuple [ Rat (Rational.make 1 2); Rat (Rational.make 1 2) ])
      "n < m at an open endpoint";
    rejects "empty half-open interval, rational" rational_interval
      (Interval (Open (Int 1), Closed (Int 1)))
      "n < m at an open endpoint";
    reads "release" resource_levels (Tuple [ Int (-1); Int 0 ]) "(-1, 0)";
    reads "unbounded peak" resource_levels (Tuple [ Int (-3); Inf ]) "(-3, ∞)";
    reads "top" resource_levels Top "(∞, ∞)";
    rejects "peak below the change" resource_levels
      (Tuple [ Int 2; Int 1 ])
      "at least the net change";
    rejects "negative peak" resource_levels
      (Tuple [ Int (-2); Int (-1) ])
      "at least 0";
    rejects "unbounded change" resource_levels
      (Tuple [ Inf; Int 3 ])
      "needs a peak";
    rejects "integer" resource_levels (Int 3) "not plain integers";
    rejects "level" resource_levels (Tuple [ Int 1; Name "Low" ]) "in the peak";
    reads "resource" resource_levels
      (Tuple [ Name "Files"; Int 1; Int 1 ])
      "(Files, 1, 1)";
    reads "resources" resource_levels
      (Tuple
         [
           Tuple [ Name "Sockets"; Int 0; Int 1 ];
           Tuple [ Name "Files"; Int 0; Int 2 ];
         ])
      "((Files, 0, 2), (Sockets, 0, 1))";
    reads "other resources" resource_levels
      (Tuple
         [
           Tuple [ Name "Files"; Int 0; Int 2 ];
           Tuple [ Name "_"; Int 0; Int 1 ];
         ])
      "((Files, 0, 2), (_, 0, 1))";
    reads "infinite net change" resource_levels (Tuple [ Inf; Inf ]) "(∞, ∞)";
    reads "explicit trough" resource_levels
      (Tuple [ Int (-1); Int 0; Int 0 ])
      "(-1, 0, 0)";
    reads "implied trough" resource_levels
      (Tuple [ Int (-1); Int (-1); Int 0 ])
      "(-1, 0)";
    reads "range" resource_levels
      (Tuple [ Interval (Closed (Int 0), Closed (Int 1)); Int 1 ])
      "([0, 1], 1)";
    reads "range with a trough" resource_levels
      (Tuple [ Int (-2); Interval (Closed (Int (-1)), Closed (Int 1)); Int 2 ])
      "(-2, [-1, 1], 2)";
    reads "range unbounded above" resource_levels
      (Tuple [ Interval (Closed (Int 0), Unbounded); Inf ])
      "([0, ∞), ∞)";
    reads "range unbounded below" resource_levels
      (Tuple [ Interval (Unbounded, Closed (Int 0)); Int 0 ])
      "((-∞, 0], 0)";
    reads "unbounded trough" resource_levels
      (Tuple [ Top; Int 0; Int 0 ])
      "(⊤, 0, 0)";
    reads "unbounded everywhere" resource_levels
      (Tuple [ Interval (Unbounded, Unbounded); Inf ])
      "(∞, ∞)";
    reads "pair for an open range" resource_levels
      (Tuple [ Tuple [ Int (-1); Int 2 ]; Int 1 ])
      "([0, 1], 1)";
    reads "half-open range" resource_levels
      (Tuple [ Interval (Unbounded, Open (Int 1)); Int 0 ])
      "((-∞, 0], 0)";
    rejects "open range of no integer" resource_levels
      (Tuple [ Tuple [ Int 0; Int 1 ]; Int 1 ])
      "in the net change, the interval contains no integer";
    rejects "fractional end of a range" resource_levels
      (Tuple
         [ Interval (Closed (Rat (Rational.make 1 2)), Closed (Int 1)); Int 1 ])
      "the ends of net changes are integers";
    rejects "trough above 0" resource_levels
      (Tuple [ Int 1; Int 1; Int 1 ])
      "the trough must be at most 0";
    rejects "trough above the net change" resource_levels
      (Tuple [ Int (-1); Int (-2); Int 0 ])
      "at most the net change";
    rejects "reversed range" resource_levels
      (Tuple [ Interval (Closed (Int 2), Closed (Int 1)); Int 2 ])
      "in the net change, interval endpoints must satisfy n <= m";
    rejects "peak below the range" resource_levels
      (Tuple [ Interval (Closed (Int 0), Closed (Int 2)); Int 1 ])
      "the peak must be at least 0 and at least the net change";
    rejects "infinite trough" resource_levels
      (Tuple [ Inf; Int 0; Int 0 ])
      "in the trough, troughs are integers or '⊤', not '∞'";
    rejects "infinite least net change" resource_levels
      (Tuple [ Interval (Closed Inf, Closed (Int 1)); Int 1 ])
      "in the net change, the ends of net changes are integers, not '∞'";
    rejects "infinite exact net change with a trough" resource_levels
      (Tuple [ Int 0; Inf; Inf ])
      "in the net change, net changes are integers or ranges";
    rejects "four components" resource_levels
      (Tuple [ Int 0; Int 0; Int 0; Int 0 ])
      "not tuples";
    reads "resource with a trough" resource_levels
      (Tuple [ Name "Files"; Int (-1); Int 0; Int 0 ])
      "(Files, -1, 0, 0)";
    reads "resource with a range" resource_levels
      (Tuple [ Name "Files"; Interval (Closed (Int 0), Closed (Int 1)); Int 1 ])
      "(Files, [0, 1], 1)";
    reads "resource with a range unbounded below" resource_levels
      (Tuple [ Name "Files"; Interval (Unbounded, Closed (Int 0)); Int 0 ])
      "(Files, (-∞, 0], 0)";
    reads "other resources with a trough" resource_levels
      (Tuple
         [
           Tuple [ Name "Files"; Int 0; Int 2 ];
           Tuple [ Name "_"; Int (-1); Int 0; Int 0 ];
         ])
      "((Files, 0, 2), (_, -1, 0, 0))";
    rejects "resource trough above 0" resource_levels
      (Tuple [ Name "Files"; Int 1; Int 1; Int 1 ])
      "in the entry of 'Files', the trough must be at most 0";
    reads "resource at the unit" resource_levels
      (Tuple [ Name "Files"; Int 0; Int 0 ])
      "(0, 0)";
    rejects "resource peak below the change" resource_levels
      (Tuple [ Name "Files"; Int 2; Int 1 ])
      "in the entry of 'Files', the peak must be at least 0";
    rejects "resource listed twice" resource_levels
      (Tuple
         [
           Tuple [ Name "Files"; Int 1; Int 1 ];
           Tuple [ Name "Files"; Int 0; Int 1 ];
         ])
      "listed twice";
    reads "duration" windowed_schedules (Int 3) "3";
    reads "interval of durations" windowed_schedules
      (Interval (Closed (Int 2), Closed (Int 5)))
      "[2, 5]";
    reads "unbounded durations" windowed_schedules
      (Interval (Closed (Int 2), Unbounded))
      "[2, ∞)";
    reads "interval of durations and times" windowed_schedules
      (Tuple
         [
           Interval (Closed (Int 0), Closed (Int 2));
           Tuple [ Name "Send"; Braces (Tick 0) ];
         ])
      "([0, 2], (Send, {0}))";
    reads "pair for an open interval of durations" windowed_schedules
      (Tuple [ Int 2; Int 5 ])
      "[3, 4]";
    reads "durations open below" windowed_schedules
      (Interval (Open (Int 2), Unbounded))
      "[3, ∞)";
    rejects "open interval of no durations" windowed_schedules
      (Tuple [ Int 2; Int 3 ])
      "the interval contains no integer";
    rejects "fractional end of durations" windowed_schedules
      (Interval (Closed (Int 0), Closed (Rat (Rational.make 1 2))))
      "interval endpoints are integers";
    reads "set of durations" windowed_schedules
      (Braces (union (Tick 1) (Tick 3)))
      "{1 | 3}";
    reads "durations and times" windowed_schedules
      (Tuple [ Int 1; Tuple [ Name "Send"; Braces (Tick 0) ] ])
      "(1, (Send, {0}))";
    reads "times of two operations" windowed_schedules
      (Tuple
         [
           Int 10;
           Tuple [ Name "Sense"; Braces (Tick 0) ];
           Tuple [ Name "Send"; Braces (union (Tick 4) (Tick 5)) ];
         ])
      "(10, (Send, {4 | 5}), (Sense, {0}))";
    reads "times of any operation" windowed_schedules
      (Tuple
         [
           Int 3;
           Tuple [ Name "_"; Braces (Tick 2) ];
           Tuple [ Name "Send"; Braces (Tick 0) ];
         ])
      "(3, (Send, {0}), (_, {2}))";
    reads "times by single ticks" windowed_schedules
      (Tuple [ Int 1; Tuple [ Name "Send"; Braces (seq Any Any) ] ])
      "(1, (Send, {2}))";
    reads "top" windowed_schedules Top "⊤";
    rejects "operation in the times" windowed_schedules
      (Tuple [ Int 1; Tuple [ Name "Send"; Braces send ] ])
      "name no operation such as 'Send'";
    rejects "unnamed times" windowed_schedules
      (Tuple [ Int 1; Braces (Tick 0) ])
      "times are given by operation";
    rejects "operation listed twice" windowed_schedules
      (Tuple
         [
           Int 1;
           Tuple [ Name "Send"; Braces (Tick 0) ];
           Tuple [ Name "Send"; Braces (Tick 1) ];
         ])
      "listed twice";
    rejects "reversed interval" windowed_schedules
      (Interval (Closed (Int 7), Closed (Int 1)))
      "must satisfy n <= m";
    rejects "negative duration" windowed_schedules (Int (-1))
      "must be non-negative";
    rejects "no durations" windowed_schedules
      (Braces (Inter (Tick 1, Tick 2)))
      "is empty";
    rejects "level" windowed_schedules (Name "Low") "not names such as 'Low'";
    reads "level" flow_levels (Name "High") "High";
    reads "outputs" flow_levels
      (Tuple
         [
           Name "High";
           Tuple [ Name "Board"; Name "Low" ];
           Tuple [ Name "Audit"; Name "High" ];
         ])
      "(High, (Audit, High), (Board, Low))";
    reads "top" flow_levels Top "⊤";
    reads "other outputs" flow_levels
      (Tuple
         [
           Name "High";
           Tuple [ Name "_"; Name "Low" ];
           Tuple [ Name "Board"; Name "High" ];
         ])
      "(High, (Board, High), (_, Low))";
    rejects "sink listed twice" flow_levels
      (Tuple
         [
           Name "High";
           Tuple [ Name "Board"; Name "Low" ];
           Tuple [ Name "Board"; Name "High" ];
         ])
      "listed twice";
    rejects "unknown level of an output" flow_levels
      (Tuple [ Name "Low"; Tuple [ Name "Board"; Name "Medium" ] ])
      "unknown level 'Medium'";
    rejects "output without a level" flow_levels
      (Tuple [ Name "Low"; Name "Board" ])
      "outputs are pairs";
    rejects "integer" flow_levels (Int 3) "tuples '(l, (Sink, l1), ...)'";
    reads "count" counts_upper (Tuple [ Name "Send"; Int 3 ]) "(Send, 3)";
    reads "counts" counts_upper
      (Tuple [ Tuple [ Name "Send"; Int 3 ]; Tuple [ Name "Auth"; Int 1 ] ])
      "((Auth, 1), (Send, 3))";
    reads "unbounded count" counts_upper
      (Tuple [ Tuple [ Name "Send"; Inf ]; Tuple [ Name "_"; Int 1 ] ])
      "((Send, ∞), (_, 1))";
    reads "every operation" counts_upper (Int 2) "2";
    reads "top" counts_upper Top "∞";
    rejects "negative count" counts_upper
      (Tuple [ Name "Send"; Int (-1) ])
      "in the entry of 'Send', grades must be non-negative";
    rejects "level" counts_upper (Name "Low") "not names such as 'Low'";
    reads "cost in every mode" mode_switch_costs (Int 3) "3";
    reads "transition" mode_switch_costs
      (Tuple [ Name "Off"; Name "On"; Int 2 ])
      "(Off, On, 2)";
    reads "transitions" mode_switch_costs
      (Tuple
         [
           Tuple [ Name "On"; Name "On"; Int 3 ];
           Tuple [ Name "Off"; Name "Off"; Inf ];
         ])
      "((Off, Off, ∞), (On, On, 3))";
    reads "stuck from a mode" mode_switch_costs
      (Tuple
         [
           Tuple [ Name "Off"; Name "Off"; Int 18 ];
           Tuple [ Name "On"; Name "Stuck"; Int 6 ];
         ])
      "((Off, Off, 18), (On, Stuck, 6))";
    reads "stuck at no cost left implicit" mode_switch_costs
      (Tuple
         [
           Tuple [ Name "Off"; Name "On"; Int 2 ];
           Tuple [ Name "On"; Name "Stuck"; Int 0 ];
         ])
      "(Off, On, 2)";
    reads "stuck besides another run" mode_switch_costs
      (Tuple
         [
           Tuple [ Name "On"; Name "On"; Int 2 ];
           Tuple [ Name "On"; Name "Stuck"; Int 0 ];
         ])
      "((On, On, 2), (On, Stuck, 0))";
    reads "stuck everywhere" mode_switch_costs
      (Tuple [ Name "Stuck"; Name "Stuck"; Int 0 ])
      "(Stuck, Stuck, 0)";
    reads "stuck in every mode named" mode_switch_costs
      (Tuple [ Name "On"; Name "Stuck"; Int 0 ])
      "(Stuck, Stuck, 0)";
    reads "the stuck row" mode_switch_costs
      (Tuple
         [
           Tuple [ Name "Off"; Name "Off"; Int 1 ];
           Tuple [ Name "Stuck"; Name "Stuck"; Int 0 ];
         ])
      "(Off, Off, 1)";
    reads "top" mode_switch_costs Top "⊤";
    rejects "change of mode at no cost" mode_switch_costs
      (Tuple [ Name "On"; Name "Off"; Int 0 ])
      "in the cost from 'On' to 'Off', a change of mode costs at least 1";
    rejects "leaving the stuck mode" mode_switch_costs
      (Tuple [ Name "Stuck"; Name "On"; Int 1 ])
      "no trace leaves the mode 'Stuck'";
    rejects "staying stuck at a cost" mode_switch_costs
      (Tuple [ Name "Stuck"; Name "Stuck"; Int 1 ])
      "which it keeps at cost 0";
    rejects "negative cost" mode_switch_costs
      (Tuple [ Name "Off"; Name "On"; Int (-1) ])
      "in the cost from 'Off' to 'On', costs must be non-negative";
    rejects "pair listed twice" mode_switch_costs
      (Tuple
         [
           Tuple [ Name "On"; Name "On"; Int 3 ];
           Tuple [ Name "On"; Name "On"; Int 4 ];
         ])
      "listed twice";
    reads "modes not named" mode_switch_costs
      (Tuple
         [
           Tuple [ Name "On"; Name "On"; Int 2 ];
           Tuple [ Name "_"; Name "_"; Int 1 ];
           Tuple [ Name "_"; Name "Stuck"; Int 0 ];
         ])
      "((On, On, 2), (_, _, 1), (_, Stuck, 0))";
    reads "to and from the modes not named" mode_switch_costs
      (Tuple
         [
           Tuple [ Name "On"; Name "_"; Int 1 ];
           Tuple [ Name "_"; Name "On"; Int 2 ];
           Tuple [ Name "_"; Name "≠"; Inf ];
         ])
      "((On, _, 1), (_, On, 2), (_, ≠, ∞))";
    rejects "change to a mode not named at no cost" mode_switch_costs
      (Tuple [ Name "On"; Name "_"; Int 0 ])
      "in the cost from 'On' to '_', a change of mode costs at least 1";
    rejects "change between modes not named at no cost" mode_switch_costs
      (Tuple [ Name "_"; Name "≠"; Int 0 ])
      "a change of mode costs at least 1";
    rejects "another mode not named after a mode named" mode_switch_costs
      (Tuple [ Name "On"; Name "≠"; Int 1 ])
      "only an entry from '_' ends in '≠'";
    rejects "pair" mode_switch_costs (Tuple [ Int 1; Int 2 ]) "not pairs";
    reads "integer" time_lower (Int 3) "3";
    reads "top" time_lower Top "0";
    rejects "infinity" time_lower Inf "not '∞'";
    rejects "pair" time_lower (Tuple [ Int 1; Int 5 ]) "not pairs";
    reads "infinity" time_upper Inf "∞";
    reads "top" time_upper Top "∞";
    rejects "name" time_upper (Name "Low") "not names such as 'Low'";
    reads "interval" time_interval
      (Interval (Closed (Int 1), Closed (Int 5)))
      "[1, 5]";
    reads "open interval" time_interval
      (Interval (Closed (Int 3), Unbounded))
      "[3, ∞)";
    reads "top" time_interval Top "[0, ∞)";
    rejects "reversed interval" time_interval
      (Interval (Closed (Int 5), Closed (Int 3)))
      "n <= m";
    rejects "infinite lower end" time_interval
      (Interval (Closed Inf, Unbounded))
      "endpoints";
    reads "pair" time_interval (Tuple [ Int 3; Inf ]) "[4, ∞)";
    rejects "pair of a name" time_interval
      (Tuple [ Name "Low"; Int 3 ])
      "not pairs";
    rejects "integer" time_interval (Int 3) "not plain integers";
    reads "top" traces_lower Top "{0}";
    reads "sequences" traces_lower
      (Braces (union (seq send (Tick 3)) (Letter "Read")))
      "{Read | Send; 3}";
    reads "top" traces_upper Top "⊤";
    reads "concatenation of a union" traces_upper
      (Braces (seq (union send (Tick 2)) (Tick 1)))
      "{Send; 1 | 3}";
    rejects "repetition" traces_upper (Braces (Star send)) "repetition '*'";
    rejects "intersection" traces_upper (Braces (Inter (send, send))) "'&'";
    rejects "complement" traces_upper (Braces (Compl send)) "'~'";
    rejects "wildcard" traces_upper (Braces (seq Any send)) "'_'";
    rejects "pair" traces_upper (Tuple [ Int 1; Int 2 ]) "not pairs";
    reads "top" traces_interval Top "[{0}, ∞)";
    reads "unbounded upper component" traces_interval (span (Braces send) Inf)
      "[{Send}, ∞)";
    reads "top upper component" traces_interval
      (Interval (Closed (Braces send), Closed Top))
      "[{Send}, ∞)";
    reads "interval of integers" traces_interval (span (Int 1) (Int 2))
      "[{1}, {2}]";
    reads "integer" traces_interval (Int 2) "[{2}, {2}]";
    rejects "reversed interval" traces_interval (span (Int 5) (Int 3)) "n <= m";
    reads "open interval of integers" traces_interval
      (Tuple [ Int 1; Int 4 ])
      "[{2}, {3}]";
    reads "interval of integers open below" traces_interval
      (Interval (Open (Int 1), Unbounded))
      "[{2}, ∞)";
    rejects "open interval of no integer" traces_interval
      (Tuple [ Int 1; Int 2 ])
      "the interval contains no integer";
    rejects "open endpoint of a set of runs" traces_interval
      (Interval (Open (Braces send), Closed (Braces send)))
      "an endpoint that is not a number is closed";
    rejects "pair" traces_interval
      (Tuple [ Braces send; Braces send ])
      "intervals are written '[L, U]' or '[L, ∞)', not as pairs '(L, U)'";
    rejects "interval unbounded below" traces_interval (span Top (Braces send))
      "intervals are bounded below, written '[L, U]' or '[L, ∞)'";
    rejects "fractional delay" traces_upper
      (Braces (seq send (Frac (Rational.make 1 2))))
      "whole numbers of time steps";
    rejects "fraction" traces_lower (Rat (Rational.make 1 2)) "not fractions";
    rejects "fraction" traces_interval (Rat (Rational.make 1 2)) "not fractions";
    rejects "name" traces_interval (Name "Send")
      "grades are intervals '[{...}, {...}]' of sets of traces";
    rejects "fractional delay" regex_upper
      (Braces (Star (Frac (Rational.make 1 2))))
      "whole numbers of time steps";
    rejects "fractional delay" windowed_schedules
      (Braces (Frac (Rational.make 1 2)))
      "whole numbers of time steps";
    rejects "fractional interval of delays" regex_upper
      (Braces
         (Seq (send, Delays (Closed Rational.zero, Open (Rational.make 1 2)))))
      "whole numbers of time steps";
    rejects "interval of no whole delay" regex_upper
      (Braces
         (Seq (send, Delays (Open Rational.zero, Open (Rational.of_int 1)))))
      "the interval '(0, 1)' contains no whole number of time steps";
    reads "interval of ticks" windowed_schedules
      (Braces (Delays (Open (Rational.of_int 1), Unbounded)))
      "[2, ∞)";
    reads "bounded interval of ticks" windowed_schedules
      (Braces (Delays (Open (Rational.of_int 1), Open (Rational.of_int 5))))
      "[2, 4]";
    rejects "interval of delays" rational_traces_upper
      (Braces (Delays (Closed Rational.zero, Closed (Rational.make 1 2))))
      "without the interval of delays '[0, 0.5]'";
    reads "interval of delays" rational_regex_upper
      (Braces
         (Seq (send, Delays (Open Rational.zero, Closed (Rational.make 1 2)))))
      "{Send; (0, 0.5]}";
    reads "open interval of delays" rational_regex_upper
      (Braces (Delays (Open (Rational.make 1 2), Open (Rational.of_int 3))))
      "{(0.5, 3)}";
    reads "fraction" rational_regex_upper (Rat (Rational.make 3 2)) "{1.5}";
    reads "top" rational_regex_upper Top "⊤";
    reads "all timed words" rational_regex_upper (Braces (Star Any)) "⊤";
    reads "complement of a delay" rational_regex_upper (Braces (Compl (Tick 1)))
      "{~1}";
    reads "repeated fraction" rational_regex_upper
      (Braces (Star (Frac (Rational.make 1 2))))
      "{(0.5)*}";
    rejects "empty language" rational_regex_upper
      (Braces (Inter (send, Delays (Closed Rational.zero, Unbounded))))
      "denotes the empty language";
    rejects "negative delay" rational_regex_upper
      (Braces (Frac (Rational.make (-1) 2)))
      "delays are non-negative";
    rejects "negative fraction" rational_regex_upper
      (Rat (Rational.make (-1) 2))
      "must be non-negative";
    reads "fractional delays" rational_traces_lower
      (Braces
         (union
            (seq send (Frac (Rational.make 1 2)))
            (seq (Frac (Rational.make 1 3)) (Tick 1))))
      "{Send; 0.5 | 4/3}";
    reads "fraction" rational_traces_upper (Rat (Rational.make 3 2)) "{1.5}";
    reads "top" rational_traces_upper Top "⊤";
    reads "adjacent delays merged" rational_traces_upper
      (Braces (seq (Frac (Rational.make 1 2)) (Frac (Rational.make 1 2))))
      "{1}";
    rejects "negative fraction" rational_traces_upper
      (Rat (Rational.make (-1) 2))
      "must be non-negative";
    rejects "repetition" rational_traces_upper (Braces (Star send))
      "repetition '*'";
    reads "interval of fractions" rational_traces_interval
      (span (Rat (Rational.make 1 2)) (Rat (Rational.make 3 2)))
      "[{0.5}, {1.5}]";
    reads "fraction" rational_traces_interval
      (Rat (Rational.make 1 4))
      "[{0.25}, {0.25}]";
    rejects "reversed interval of fractions" rational_traces_interval
      (span (Rat (Rational.make 3 2)) (Int 1))
      "n <= m";
    rejects "pair of fractions" rational_traces_interval
      (Tuple [ Rat (Rational.make 1 2); Rat (Rational.make 3 2) ])
      "an open endpoint denotes an infinite set of traces, which these grades \
       do not express";
    rejects "half-open interval of fractions" rational_traces_interval
      (Interval (Closed (Rat (Rational.make 1 2)), Open (Int 2)))
      "an open endpoint denotes an infinite set of traces";
    reads "top" inclusion_upper Top "⊤";
    reads "concatenation of a union" inclusion_upper
      (Braces (seq (union send (Tick 2)) (Tick 1)))
      "{Send; 1 | 3}";
    reads "integer" inclusion_upper (Int 2) "{2}";
    rejects "repetition" inclusion_upper (Braces (Star send)) "repetition '*'";
    rejects "pair" inclusion_upper (Tuple [ Int 1; Int 2 ]) "not pairs";
    rejects "negative integer" inclusion_upper (Int (-1)) "must be non-negative";
    rejects "fraction" inclusion_upper (Rat (Rational.make 1 2)) "not fractions";
    reads "fraction" rational_inclusion_upper (Rat (Rational.make 3 2)) "{1.5}";
    reads "adjacent delays merged" rational_inclusion_upper
      (Braces (seq (Frac (Rational.make 1 2)) (Frac (Rational.make 1 2))))
      "{1}";
    reads "Low" security_levels (Name "Low") "Low";
    reads "High" security_levels (Name "High") "High";
    reads "top" security_levels Top "High";
    rejects "unknown level" security_levels (Name "Medium")
      "unknown level 'Medium'";
    rejects "integer" security_levels (Int 0) "not plain integers";
    reads "pair" time_lower_levels (lit_of_pair 3 "High") "(3, High)";
    reads "top" time_lower_levels Top "(0, High)";
    reads "component tops" time_lower_levels (Tuple [ Top; Top ]) "(0, High)";
    reads "pair" time_upper_levels (Tuple [ Inf; Name "Low" ]) "(∞, Low)";
    reads "top" time_upper_levels Top "(∞, High)";
    rejects "first component" time_lower_levels
      (Tuple [ Name "Low"; Name "Low" ])
      "in the first component ('time-lower-bound')";
    rejects "second component" time_upper_levels (lit_of_pair 3 "Medium")
      "in the second component ('security-levels'), unknown level";
    rejects "integer" time_lower_levels (Int 3) "grades are pairs";
    rejects "triple" time_lower_levels
      (Tuple [ Int 3; Name "Low"; Int 1 ])
      "not tuples";
  ]

(* Every grade reads its own top back from the literal [⊤], and prints a value
   it reads back as itself. *)
let tops =
  List.concat_map
    (fun (name, (module G : Grade.S)) ->
      [
        check
          (name ^ ": ⊤ is the top")
          (G.equal bounds (G.of_lit Grade.Top) G.top)
          (G.show (G.of_lit Grade.Top));
      ])
    GradeRegistry.grade_modules

let registry =
  [
    expect "registry: the default comes first" Fun.id
      ~expected:"time-lower-bound"
      (fst (List.hd GradeRegistry.grade_modules));
    expect "registry: grades reading a level" show_names
      ~expected:[ "security-levels"; "flow-levels" ]
      (GradeRegistry.accepting (Grade.Name "High"));
    expect "registry: grades reading a pair of a time and a level" show_names
      ~expected:[ "time-lower-bound-levels"; "time-upper-bound-levels" ]
      (GradeRegistry.accepting (lit_of_pair 3 "High"));
    expect "registry: grades reading an open interval" show_names
      ~expected:
        [
          "time-interval";
          "time-interval-rational";
          "traces-cost-interval";
          "traces-cost-interval-rational";
          "regex-cost-interval-symbolic";
          "regex-cost-interval-rational-symbolic";
          "windowed-schedules";
        ]
      (GradeRegistry.accepting (span (Grade.Int 3) Grade.Inf));
    expect "registry: grades reading an interval of brace literals" show_names
      ~expected:
        [
          "traces-cost-interval";
          "traces-cost-interval-rational";
          "regex-cost-interval-symbolic";
          "regex-cost-interval-rational-symbolic";
        ]
      (GradeRegistry.accepting
         (span (Grade.Braces (Grade.Letter "A"))
            (Grade.Braces (Grade.Letter "B"))));
    expect "registry: grades reading a pair of brace literals" show_names
      ~expected:[]
      (GradeRegistry.accepting
         (Grade.Tuple
            [ Grade.Braces (Grade.Letter "A"); Grade.Braces (Grade.Letter "B") ]));
    expect "registry: grades reading a pair of a number and '∞'" show_names
      ~expected:
        [
          "time-interval";
          "time-interval-rational";
          "traces-cost-interval";
          "regex-cost-interval-symbolic";
          "regex-cost-interval-rational-symbolic";
          "resource-levels";
          "windowed-schedules";
        ]
      (GradeRegistry.accepting (Grade.Tuple [ Grade.Int 3; Grade.Inf ]));
    expect "registry: grades reading an interval unbounded below" show_names
      ~expected:[]
      (GradeRegistry.accepting (span Grade.Top (Grade.Int 3)));
    expect "registry: grades reading a fraction" show_names
      ~expected:
        [
          "time-lower-bound-rational";
          "time-upper-bound-rational";
          "traces-upper-bound-rational";
          "traces-cost-lower-bound-rational";
          "traces-cost-upper-bound-rational";
          "traces-cost-interval-rational";
          "regex-upper-bound-rational-symbolic";
          "regex-cost-lower-bound-rational-symbolic";
          "regex-cost-upper-bound-rational-symbolic";
          "regex-cost-interval-rational-symbolic";
        ]
      (GradeRegistry.accepting (Grade.Rat (Rational.make 3 2)));
    expect "registry: grades reading a fractional delay in braces" show_names
      ~expected:
        [
          "traces-upper-bound-rational";
          "traces-cost-lower-bound-rational";
          "traces-cost-upper-bound-rational";
          "traces-cost-interval-rational";
          "regex-upper-bound-rational-symbolic";
          "regex-cost-lower-bound-rational-symbolic";
          "regex-cost-upper-bound-rational-symbolic";
          "regex-cost-interval-rational-symbolic";
        ]
      (GradeRegistry.accepting (Grade.Braces (Grade.Frac (Rational.make 1 2))));
    expect "registry: grades reading fractional runtime bounds" show_names
      ~expected:
        [
          "traces-cost-lower-bound-rational";
          "traces-cost-upper-bound-rational";
          "traces-cost-interval-rational";
          "regex-cost-lower-bound-rational-symbolic";
          "regex-cost-upper-bound-rational-symbolic";
          "regex-cost-interval-rational-symbolic";
        ]
      (GradeRegistry.accepting_bounds (Grade.Rat (Rational.make 1 2)));
    expect "registry: grades with a fractional delay" show_names
      ~expected:
        [
          "time-lower-bound-rational";
          "time-upper-bound-rational";
          "time-interval-rational";
          "traces-upper-bound-rational";
          "traces-cost-lower-bound-rational";
          "traces-cost-upper-bound-rational";
          "traces-cost-interval-rational";
          "regex-upper-bound-rational-symbolic";
          "regex-cost-lower-bound-rational-symbolic";
          "regex-cost-upper-bound-rational-symbolic";
          "regex-cost-interval-rational-symbolic";
          "security-levels";
          "flow-levels";
        ]
      (GradeRegistry.accepting_delay (Grade.Rat (Rational.make 1 2)));
    expect "registry: every grade has a whole delay" show_names
      ~expected:
        (List.concat_map
           (fun (g : GradeRegistry.group) ->
             List.filter_map
               (fun (name, (info : GradeRegistry.info)) ->
                 if info.visibility = Everywhere then Some name else None)
               g.grades)
           GradeRegistry.groups)
      (GradeRegistry.accepting_delay (Grade.Int 2));
    expect "registry: grades reading a repetition" show_names
      ~expected:
        [
          "regex-upper-bound-symbolic";
          "regex-upper-bound-rational-symbolic";
          "regex-cost-lower-bound-symbolic";
          "regex-cost-upper-bound-symbolic";
          "regex-cost-interval-symbolic";
          "regex-cost-lower-bound-rational-symbolic";
          "regex-cost-upper-bound-rational-symbolic";
          "regex-cost-interval-rational-symbolic";
        ]
      (GradeRegistry.accepting (Grade.Braces (Grade.Star (Grade.Letter "A"))));
    expect "registry: grades reading an interval of delays" show_names
      ~expected:
        [
          "regex-upper-bound-rational-symbolic";
          "regex-cost-lower-bound-rational-symbolic";
          "regex-cost-upper-bound-rational-symbolic";
          "regex-cost-interval-rational-symbolic";
        ]
      (GradeRegistry.accepting
         (Grade.Braces
            (Grade.Delays
               (Grade.Open Rational.zero, Grade.Open (Rational.of_int 1)))));
    expect "registry: grades accepted but listed nowhere" show_names
      ~expected:
        [
          "regex-upper-bound-letter-automata";
          "regex-upper-bound-symbolic-by-letters";
          "regex-upper-bound-letter-derivatives";
          "regex-cost-lower-bound-letter-automata";
          "regex-cost-upper-bound-letter-automata";
          "regex-cost-interval-letter-automata";
          "regex-cost-lower-bound-symbolic-by-letters";
          "regex-cost-upper-bound-symbolic-by-letters";
          "regex-cost-interval-symbolic-by-letters";
          "regex-cost-lower-bound-letter-derivatives";
          "regex-cost-upper-bound-letter-derivatives";
          "regex-cost-interval-letter-derivatives";
        ]
      (List.concat_map
         (fun (g : GradeRegistry.group) ->
           List.filter_map
             (fun (name, (info : GradeRegistry.info)) ->
               if info.visibility = Hidden then Some name else None)
             g.grades)
         GradeRegistry.groups);
    expect "registry: the regular grades describe their implementations"
      show_names
      ~expected:
        (List.filter
           (fun name -> String.starts_with ~prefix:"regex-" name)
           (List.map fst GradeRegistry.grade_modules))
      (List.concat_map
         (fun (g : GradeRegistry.group) ->
           List.filter_map
             (fun (name, (info : GradeRegistry.info)) ->
               Option.map (fun _ -> name) info.implementation)
             g.grades)
         GradeRegistry.groups);
    expect "registry: distinct groups have distinct short forms" show_names
      ~expected:
        (List.sort_uniq String.compare
           (List.map
              (fun (g : GradeRegistry.group) -> g.short)
              GradeRegistry.groups))
      (List.sort String.compare
         (List.map
            (fun (g : GradeRegistry.group) -> g.short)
            GradeRegistry.groups));
  ]

(* ------------------------------------------------------------------ *)
(* Witnesses                                                           *)
(* ------------------------------------------------------------------ *)

(* Conditions [lhs ≾ rhs] in one rigid [j] over a grade [G], evaluated at
   the witnesses of their constants and, by brute force, at the grades of
   [D.values]; [D.constant] draws a random constant. *)
module Conditions
    (G : Grade.S)
    (D : sig
      val constant : Random.State.t -> G.t
      val values : G.t list
    end) =
struct
  type exp = Rigid | Const of G.t | Mul of exp * exp | Join of exp * exp

  let rec eval j = function
    | Rigid -> j
    | Const c -> c
    | Mul (e, e') -> G.mul (eval j e) (eval j e')
    | Join (e, e') -> G.join (eval j e) (eval j e')

  let rec constants = function
    | Rigid -> []
    | Const c -> [ c ]
    | Mul (e, e') | Join (e, e') -> constants e @ constants e'

  let rec occurrences = function
    | Rigid -> 1
    | Const _ -> 0
    | Mul (e, e') | Join (e, e') -> occurrences e + occurrences e'

  let rec show = function
    | Rigid -> "j"
    | Const c -> G.show c
    | Mul (e, e') -> "(" ^ show e ^ " · " ^ show e' ^ ")"
    | Join (e, e') -> "(" ^ show e ^ " ⊔ " ^ show e' ^ ")"

  let rec random st depth =
    if depth = 0 || Random.State.int st 3 = 0 then
      if Random.State.bool st then Rigid else Const (D.constant st)
    else
      let e = random st (depth - 1) and e' = random st (depth - 1) in
      if Random.State.bool st then Mul (e, e') else Join (e, e')

  let holds (lhs, rhs) j = G.leq bounds (eval j lhs) (eval j rhs)

  let witnesses (lhs, rhs) =
    let degree = Int.max (occurrences lhs) (occurrences rhs) in
    fst (G.witnesses ~degree bounds (constants lhs @ constants rhs))

  (* Whether [cond] holds at every witness. *)
  let at_witnesses cond = List.for_all (holds cond) (witnesses cond)

  (* A condition of [count] random ones of depth at most 3 that holds at
     every witness and fails at a grade of [D.values]. *)
  let incomplete ~count =
    let st = Random.State.make [| 42 |] in
    List.find_opt
      (fun cond ->
        at_witnesses cond && not (List.for_all (holds cond) D.values))
      (List.init count (fun _ -> (random st 3, random st 3)))

  let complete ~count =
    let name = G.name ^ ": witnesses complete on random conditions" in
    match incomplete ~count with
    | None -> check name true ""
    | Some (lhs, rhs) -> check name false (show lhs ^ " ≾ " ^ show rhs)
end

let nat n = Grade.Int n
let up_to n = List.init (n + 1) Fun.id

module Lower_conditions =
  Conditions
    (TimeGrades.LowerBound)
    (struct
      let constant st =
        TimeGrades.LowerBound.of_lit (nat (Random.State.int st 5))

      let values = List.map TimeGrades.LowerBound.of_delay (up_to 60)
    end)

module Upper_conditions =
  Conditions
    (TimeGrades.UpperBound)
    (struct
      let constant st =
        TimeGrades.UpperBound.of_lit
          (if Random.State.int st 8 = 0 then Grade.Inf
           else nat (Random.State.int st 5))

      let values =
        TimeGrades.UpperBound.top
        :: List.map TimeGrades.UpperBound.of_delay (up_to 60)
    end)

(* The intervals [[n, m]] with [n ≤ m ≤ bound], and those from [n] on. *)
let intervals bound =
  List.concat_map
    (fun n ->
      span (nat n) Grade.Inf
      :: List.map
           (fun m -> span (nat n) (nat m))
           (List.init (bound - n + 1) (( + ) n)))
    (up_to bound)

module Interval_conditions =
  Conditions
    (TimeGrades.Interval)
    (struct
      let constant st =
        let n = Random.State.int st 4 in
        TimeGrades.Interval.of_lit
          (span (nat n)
             (if Random.State.int st 6 = 0 then Grade.Inf
              else nat (n + Random.State.int st 3)))

      let values = List.map TimeGrades.Interval.of_lit (intervals 40)
    end)

module Levels_conditions =
  Conditions
    (TimeLevels)
    (struct
      let level st = if Random.State.bool st then "Low" else "High"

      let constant st =
        TimeLevels.of_lit (lit_of_pair (Random.State.int st 5) (level st))

      let values =
        List.concat_map
          (fun n ->
            [
              TimeLevels.of_lit (lit_of_pair n "Low");
              TimeLevels.of_lit (lit_of_pair n "High");
            ])
          (up_to 60)
    end)

module Flow = LevelGrades.FlowLevels

(* The flow-sensitive grades over the sinks [sinks], each written at a level or
   not at all, and the top. *)
let flow_grades sinks =
  let outputs =
    List.fold_left
      (fun outputs sink ->
        List.concat_map
          (fun ws ->
            ws
            :: List.map
                 (fun level -> ws @ [ (sink, level) ])
                 [ LevelGrades.Low; High ])
          outputs)
      [ [] ] sinks
  in
  Flow.top
  :: List.concat_map
       (fun level ->
         List.map
           (fun ws ->
             ( level,
               GradeConstructions.Indexed.of_list
                 ~compare:LevelGrades.WrittenAt.compare ~others:None
                 (List.map (fun (s, l) -> (s, Some l)) ws) ))
           outputs)
       [ LevelGrades.Low; High ]

module Flow_conditions =
  Conditions
    (Flow)
    (struct
      let named = Array.of_list (flow_grades [ "Audit"; "Board" ])
      let constant st = named.(Random.State.int st (Array.length named))
      let values = flow_grades [ "Audit"; "Board"; "Other" ]
    end)

(* The rationals [x/d] in [[0, 30]] with [d ≤ 48], in increasing order. *)
let rational_values =
  List.sort_uniq Rational.compare
    (List.concat_map
       (fun d -> List.init ((30 * d) + 1) (fun x -> Rational.make x d))
       (List.init 48 (( + ) 1)))

(* A random rational with a denominator of at most 4, below 8. *)
let random_rational st =
  Rational.make (Random.State.int st 8) (1 + Random.State.int st 4)

let rational_lit st = Grade.rational_lit (random_rational st)

module Rational_lower_conditions =
  Conditions
    (RationalTimeGrades.LowerBound)
    (struct
      let constant st = RationalTimeGrades.LowerBound.of_lit (rational_lit st)

      let values =
        List.map RationalTimeGrades.LowerBound.of_delay rational_values
    end)

module Rational_upper_conditions =
  Conditions
    (RationalTimeGrades.UpperBound)
    (struct
      let constant st =
        RationalTimeGrades.UpperBound.of_lit
          (if Random.State.int st 8 = 0 then Grade.Inf else rational_lit st)

      let values =
        RationalTimeGrades.UpperBound.top
        :: List.map RationalTimeGrades.UpperBound.of_delay rational_values
    end)

(* The rational interval from [q] to [r], [r] possibly [∞], closed at its
   finite endpoints, or open at those where [lo_open] and [hi_open] hold. *)
let interval_of ?(lo_open = false) ?(hi_open = false) q r =
  let lo = Grade.rational_lit q in
  RationalTimeGrades.Interval.of_lit
    (Grade.Interval
       ( (if lo_open then Grade.Open lo else Grade.Closed lo),
         match r with
         | Grade.Inf -> Grade.Unbounded
         | r -> if hi_open then Grade.Open r else Grade.Closed r ))

module Rational_interval_conditions =
  Conditions
    (RationalTimeGrades.Interval)
    (struct
      let constant st =
        let q = random_rational st in
        let width = Random.State.int st 3 in
        let lo_open = width > 0 && Random.State.bool st
        and hi_open = width > 0 && Random.State.bool st in
        interval_of ~lo_open ~hi_open q
          (if Random.State.int st 6 = 0 then Grade.Inf
           else Grade.rational_lit (Rational.add q (Rational.make width 2)))

      (* The endpoints of an ordering are compared separately: the intervals
         [[q, ∞)], [(q, ∞)], [[0, r]] and [[0, r)], and the intervals
         between the rationals with denominators up to 6 in [[0, 6]], closed
         or open at either endpoint. *)
      let values =
        let coarse =
          List.filter
            (fun q -> Rational.compare q (Rational.of_int 6) <= 0)
            (List.filter
               (fun q -> 6 mod Rational.denominator q = 0)
               rational_values)
        in
        let flags =
          [ (false, false); (true, false); (false, true); (true, true) ]
        in
        List.concat_map
          (fun q ->
            [ interval_of q Grade.Inf; interval_of ~lo_open:true q Grade.Inf ])
          rational_values
        @ List.concat_map
            (fun r ->
              interval_of Rational.zero (Grade.rational_lit r)
              ::
              (if Rational.sign r > 0 then
                 [
                   interval_of ~hi_open:true Rational.zero
                     (Grade.rational_lit r);
                 ]
               else []))
            rational_values
        @ List.concat_map
            (fun q ->
              List.concat_map
                (fun r ->
                  match Rational.compare q r with
                  | 0 -> [ interval_of q (Grade.rational_lit r) ]
                  | c when c < 0 ->
                      List.map
                        (fun (lo_open, hi_open) ->
                          interval_of ~lo_open ~hi_open q (Grade.rational_lit r))
                        flags
                  | _ -> [])
                coarse)
            coarse
    end)

(* [1·j ≾ 1 ⊔ jᵏ], which fails exactly for [j] in [(0, 1/(k-1))]. *)
let power_condition k =
  let open Rational_upper_conditions in
  let one =
    Const (RationalTimeGrades.UpperBound.of_delay (Rational.of_int 1))
  in
  let rec power k = if k = 1 then Rigid else Mul (Rigid, power (k - 1)) in
  (Mul (one, Rigid), Join (one, power k))

let witnesses =
  let module L = TimeGrades.LowerBound in
  let lower n = L.of_lit (nat n) in
  let five_ge_one_j =
    ( Lower_conditions.Const (lower 5),
      Lower_conditions.Mul (Const (lower 1), Rigid) )
  in
  let completeness (module G : Grade.S) =
    match snd (G.witnesses ~degree:1 bounds []) with
    | Grade.Complete -> "complete"
    | Grade.Partial -> "partial"
  in
  [
    check "time-lower-bound: 5 >= 1 · j fails at a witness"
      (not (Lower_conditions.at_witnesses five_ge_one_j))
      "5 >= 1 · j";
    check "time-lower-bound: 5 >= 1 · j fails at j = 5"
      (List.exists
         (fun j ->
           L.equal bounds j (lower 5)
           && not (Lower_conditions.holds five_ge_one_j j))
         (Lower_conditions.witnesses five_ge_one_j))
      "5 >= 1 + 5";
    check "time-lower-bound: 1 · j >= j holds at every witness"
      (Lower_conditions.at_witnesses (Mul (Const (lower 1), Rigid), Rigid))
      "1 · j >= j";
    check "time-lower-bound: 5 >= 5 ⊔ j holds at every witness"
      (Lower_conditions.at_witnesses
         (Const (lower 5), Join (Const (lower 5), Rigid)))
      "5 >= min(5, j)";
    Lower_conditions.complete ~count:2000;
    Upper_conditions.complete ~count:2000;
    Interval_conditions.complete ~count:1000;
    Levels_conditions.complete ~count:1000;
    Flow_conditions.complete ~count:3000;
    Rational_lower_conditions.complete ~count:1000;
    Rational_upper_conditions.complete ~count:1000;
    Rational_interval_conditions.complete ~count:500;
    all "time-upper-bound-rational: 1·j ≾ 1 ⊔ jᵏ refuted at a witness"
      string_of_int
      (fun k ->
        not (Rational_upper_conditions.at_witnesses (power_condition k)))
      (List.init 9 (( + ) 2));
    check
      "time-upper-bound-rational: 1·j ≾ 1 ⊔ j³ holds at the witnesses of \
       degree 1"
      (let lhs, rhs = power_condition 3 in
       List.for_all
         (Rational_upper_conditions.holds (lhs, rhs))
         (fst
            (RationalTimeGrades.UpperBound.witnesses ~degree:1 bounds
               Rational_upper_conditions.(constants lhs @ constants rhs))))
      "1·j <= 1 ⊔ j·j·j";
    check "flow-levels: a failure at an unnamed sink shows at a witness"
      (not
         (Flow_conditions.at_witnesses
            (Flow_conditions.Rigid, Const (Flow.of_lit (Grade.Name "High")))))
      "j <= High";
    expect "witnesses: time grades complete" Fun.id ~expected:"complete"
      (completeness time_interval);
    expect "witnesses: rational time grades complete" Fun.id
      ~expected:"complete"
      (completeness rational_interval);
    expect "witnesses: levels complete" Fun.id ~expected:"complete"
      (completeness (module LevelGrades.SecurityLevels));
    expect "witnesses: product of complete grades complete" Fun.id
      ~expected:"complete"
      (completeness (module UpperLevels));
    expect "witnesses: traces partial" Fun.id ~expected:"partial"
      (completeness traces_upper);
    expect "witnesses: rational traces partial" Fun.id ~expected:"partial"
      (completeness rational_traces_interval);
    expect "witnesses: traces by inclusion partial" Fun.id ~expected:"partial"
      (completeness inclusion_upper);
    expect "witnesses: product with a partial grade partial" Fun.id
      ~expected:"partial"
      (completeness (module TraceLevels));
    expect "witnesses: resource levels partial" Fun.id ~expected:"partial"
      (completeness resource_levels);
    expect "witnesses: windowed schedules partial" Fun.id ~expected:"partial"
      (completeness windowed_schedules);
    expect "witnesses: flow-levels complete" Fun.id ~expected:"complete"
      (completeness (module Flow));
    expect "witnesses: counts complete" Fun.id ~expected:"complete"
      (completeness counts_upper);
    expect "witnesses: mode-switch costs partial" Fun.id ~expected:"partial"
      (completeness mode_switch_costs);
    check "counts: delays count nothing"
      Grades.CountGrades.UpperBound.(equal bounds (of_delay 5) one)
      "";
  ]

(* ------------------------------------------------------------------ *)
(* Laws of the registered grades                                       *)
(* ------------------------------------------------------------------ *)

(* A cost model over the operations [A], [B] and [C]. *)
let costs =
  let table = [ ("A", (1, 3)); ("B", (2, 2)); ("C", (0, 5)) ] in
  {
    Grade.cost =
      (fun o ->
        let lo, hi = List.assoc o table in
        (Grade.Closed (Rational.of_int lo), Grade.Closed (Rational.of_int hi)));
    operations = List.map fst table;
  }

(* The families of the registered grades, by the literals they read. *)
type family =
  | Time
  | Inclusion_traces
  | Rational_inclusion_traces
  | Traces
  | Rational_traces
  | Regex
  | Rational_regex
  | Rational_regex_costs
  | Levels
  | Timed_levels
  | Flow
  | Resources
  | Schedules
  | Modes
  | Counts

(* [family name] is the family of the registered grade [name], if known. *)
let family name =
  let prefix p = String.starts_with ~prefix:p name in
  match name with
  | "security-levels" -> Some Levels
  | "time-lower-bound-levels" | "time-upper-bound-levels" -> Some Timed_levels
  | "flow-levels" -> Some Flow
  | "resource-levels" -> Some Resources
  | "windowed-schedules" -> Some Schedules
  | "mode-switch-costs" -> Some Modes
  | "counts-upper-bound" -> Some Counts
  | "traces-upper-bound" -> Some Inclusion_traces
  | "traces-upper-bound-rational" -> Some Rational_inclusion_traces
  | "regex-upper-bound-rational-symbolic" -> Some Rational_regex
  | _
    when prefix "regex-cost-"
         && String.ends_with ~suffix:"-rational-symbolic" name ->
      Some Rational_regex_costs
  | _ when prefix "regex-" -> Some Regex
  | _ when prefix "traces-" && String.ends_with ~suffix:"-rational" name ->
      Some Rational_traces
  | _ when prefix "traces-" -> Some Traces
  | _ when prefix "time-" -> Some Time
  | _ -> None

let rat n d = Grade.rational_lit (Rational.make n d)
let pair l l' = Grade.Tuple [ l; l' ]
let closed l l' = Grade.Interval (Grade.Closed l, Grade.Closed l')
let entry name components = Grade.Tuple (Grade.Name name :: components)
let pick st xs = List.nth xs (Random.State.int st (List.length xs))
let letter_a = Grade.Letter "A"
let letter_b = Grade.Letter "B"
let letter_c = Grade.Letter "C"

(* [cover family] is the literals of the cases [family] distinguishes: for the
   time grades, integers, fractions, [∞] and intervals such as '[0, ∞)'; for
   the trace grades without costs, sets of runs of which some include others;
   for the trace and regular grades, the operations of [costs], delays, unions,
   sequences and, for the regular grades, repetitions, the catch-all letter,
   intersections and complements; the two levels; pairs of times and levels;
   levels with outputs at named sinks and at the others; releases,
   acquisitions, ranges of net changes, explicit and unbounded troughs and the
   resources not named; durations with the times of named and other
   operations; partial operations, changes of mode, runs stuck at a cost,
   round trips and the modes not named; and counts of several operations, of
   the others, [0] and [∞]. *)
let cover =
  let open Grade in
  let level l = Name l in
  function
  | Time ->
      [
        Int 1;
        Int 3;
        rat 1 2;
        rat 5 3;
        Inf;
        span (Int 0) Inf;
        span (Int 0) (Int 0);
        span (Int 1) (Int 3);
        span (Int 2) Inf;
        span (rat 1 2) (rat 5 3);
        span (rat 1 3) Inf;
        span (Int 1) (rat 5 2);
        Interval (Open (rat 1 2), Closed (rat 5 3));
        Interval (Closed (Int 1), Open (Int 3));
        Interval (Open (Int 0), Open (rat 1 2));
        Interval (Open (rat 1 3), Unbounded);
        Tuple [ rat 1 3; Int 2 ];
        Tuple [ Int 1; Inf ];
      ]
  | Traces ->
      [
        Braces letter_a;
        Braces (Seq (letter_b, Tick 1));
        Braces (Union (letter_a, Tick 2));
        Braces (Union (Tick 1, Tick 3));
        Braces (Seq (letter_a, letter_b));
        Braces (Union (Seq (letter_c, letter_a), letter_b));
        closed (Braces letter_a) (Braces (Union (letter_a, Tick 3)));
        closed (Int 1) (Int 3);
        span (Braces (Tick 0)) Inf;
        Int 2;
      ]
  | Inclusion_traces ->
      [
        Braces letter_a;
        Braces (Union (letter_a, letter_b));
        Braces (Union (letter_a, Seq (letter_b, Tick 1)));
        Braces (Union (Seq (letter_a, letter_b), letter_a));
        Braces (Seq (Tick 1, Seq (Tick 2, letter_c)));
        Braces (Union (Tick 1, Tick 3));
        Braces (Seq (Union (letter_a, Tick 1), letter_b));
        Braces (Tick 0);
        Int 3;
      ]
  | Rational_inclusion_traces ->
      let frac n d = Frac (Rational.make n d) in
      [
        Braces letter_a;
        Braces (Union (letter_a, Seq (letter_b, frac 1 2)));
        Braces (Seq (letter_b, frac 1 2));
        Braces (Union (frac 1 3, Tick 1));
        Braces (Seq (frac 1 2, frac 1 2));
        Braces (Seq (letter_a, Seq (frac 1 4, letter_b)));
        Braces (Union (Seq (letter_a, Seq (frac 1 4, letter_b)), letter_c));
        rat 5 4;
      ]
  | Rational_traces ->
      let frac n d = Frac (Rational.make n d) in
      [
        Braces letter_a;
        Braces (Seq (letter_b, frac 1 2));
        Braces (Union (letter_a, frac 5 2));
        Braces (Union (frac 1 3, Tick 1));
        Braces (Seq (letter_a, Seq (frac 1 4, letter_b)));
        Braces (Union (Seq (letter_c, letter_a), frac 3 4));
        closed (Braces letter_a) (Braces (Union (letter_a, frac 7 2)));
        closed (rat 1 2) (rat 3 2);
        span (Braces (Tick 0)) Inf;
        rat 5 4;
      ]
  | Regex ->
      [
        Braces letter_a;
        Braces (Seq (letter_b, Tick 1));
        Braces (Union (letter_a, Tick 2));
        Braces (Star (Seq (letter_a, Tick 1)));
        Braces Any;
        Braces (Seq (letter_a, Seq (Any, letter_b)));
        Braces (Inter (Any, Compl letter_a));
        Braces (Seq (Star (Union (letter_a, letter_b)), letter_c));
        Braces (Star (Tick 1));
        Braces (Union (letter_c, Tick 0));
        closed (Braces letter_a) (Braces (Union (letter_a, Tick 3)));
        closed (Braces (Tick 1)) (Braces (Star Any));
        Braces
          (Seq
             (letter_a, Delays (Open Rational.zero, Closed (Rational.of_int 2))));
        Braces (Seq (Delays (Closed (Rational.of_int 1), Unbounded), letter_b));
        Tuple [ Int 1; Int 4 ];
        Interval (Open (Int 0), Closed (Braces letter_a));
      ]
  | (Rational_regex | Rational_regex_costs) as family ->
      let frac n d = Frac (Rational.make n d) in

      [
        Braces letter_a;
        Braces (Seq (letter_b, frac 1 2));
        Braces
          (Union
             (letter_a, Delays (Closed Rational.zero, Open (Rational.of_int 1))));
        Braces
          (Seq
             ( letter_b,
               Delays (Open (Rational.make 1 2), Closed (Rational.of_int 2)) ));
        Braces (Star (Seq (letter_a, frac 1 2)));
        Braces Any;
        Braces (Seq (letter_a, Seq (Any, letter_b)));
        Braces (Inter (Any, Compl letter_a));
        Braces (Compl (Tick 1));
        Braces (Delays (Open Rational.zero, Open (Rational.of_int 1)));
        Braces (Star (frac 1 2));
        Braces
          (Star
             (Delays (Closed (Rational.of_int 1), Closed (Rational.of_int 2))));
        Braces (Seq (Star (Union (letter_a, letter_b)), letter_c));
        Braces (Union (letter_c, Tick 0));
        Braces
          (Seq
             ( Delays (Closed (Rational.make 3 2), Unbounded),
               Seq (letter_a, Star Any) ));
        rat 3 2;
      ]
      @
      if family = Rational_regex_costs then
        [
          closed (Braces letter_a)
            (Braces
               (Union
                  ( letter_a,
                    Delays (Closed Rational.zero, Open (Rational.make 5 2)) )));
          Tuple [ rat 4 5; Int 3 ];
          Interval (Open (rat 1 2), Closed (rat 3 2));
          closed (rat 1 2) (rat 3 2);
          span (Braces (Tick 0)) Inf;
        ]
      else []
  | Levels -> [ level "Low"; level "High" ]
  | Timed_levels ->
      [
        pair (Int 3) (level "High");
        pair (Int 1) (level "Low");
        pair Inf (level "Low");
        pair (Int 2) Top;
        pair Top (level "Low");
      ]
  | Flow ->
      [
        level "High";
        Tuple [ level "Low"; entry "Board" [ level "Low" ] ];
        Tuple
          [
            level "Low";
            entry "Board" [ level "High" ];
            entry "_" [ level "Low" ];
          ];
        Tuple
          [
            level "High";
            entry "Audit" [ level "High" ];
            entry "Board" [ level "Low" ];
          ];
        Tuple [ level "Low"; entry "_" [ level "High" ] ];
      ]
  | Resources ->
      [
        pair (Int (-1)) (Int 0);
        pair (Int 1) (Int 1);
        pair (span (Int 0) (Int 1)) (Int 1);
        Tuple [ Int (-1); Int 0; Int 0 ];
        Tuple [ Top; Int 0; Int 0 ];
        pair (span Top (Int 0)) (Int 0);
        pair (Int (-3)) Inf;
        entry "Files" [ Int (-1); Int 0 ];
        entry "Files" [ Int 1; Int 1 ];
        entry "Sockets" [ span (Int 0) (Int 2); Int 3 ];
        entry "Files" [ Int (-2); span (Int (-1)) (Int 1); Int 2 ];
        Tuple
          [
            entry "Files" [ Int 0; Int 2 ];
            entry "_" [ span (Int (-1)) Inf; Inf ];
          ];
      ]
  | Schedules ->
      [
        Int 1;
        span (Int 2) (Int 5);
        span (Int 2) Inf;
        Braces (Union (Tick 1, Tick 3));
        pair (Int 1) (entry "A" [ Braces (Tick 0) ]);
        Tuple
          [
            Int 3; entry "A" [ Braces (Tick 0) ]; entry "_" [ Braces (Tick 2) ];
          ];
        Tuple
          [
            span (Int 0) (Int 2);
            entry "A" [ Braces (Union (Tick 0, Tick 1)) ];
            entry "B" [ Braces (Star (Tick 2)) ];
          ];
        pair (Int 0) (entry "B" [ Braces (Tick 0) ]);
      ]
  | Modes ->
      let mode p q c = entry p [ Name q; c ] in
      [
        mode "On" "On" (Int 4);
        mode "Off" "On" (Int 2);
        mode "On" "Off" (Int 1);
        Tuple [ mode "Off" "Off" (Int 18); mode "On" "Stuck" (Int 6) ];
        Tuple [ mode "On" "Off" (Int 1); mode "Off" "On" (Int 1) ];
        Int 1;
        Tuple [ mode "On" "On" (Int 2); mode "On" "Stuck" (Int 0) ];
        mode "Stuck" "Stuck" (Int 0);
        Tuple
          [
            mode "On" "On" (Int 2);
            mode "_" "_" (Int 1);
            mode "_" "Stuck" (Int 0);
          ];
        Tuple [ mode "On" "_" (Int 1); mode "_" "On" (Int 2); mode "_" "≠" Inf ];
      ]
  | Counts ->
      [
        entry "A" [ Int 3 ];
        Tuple [ entry "A" [ Int 1 ]; entry "B" [ Int 3 ] ];
        Tuple [ entry "B" [ Inf ]; entry "_" [ Int 1 ] ];
        Int 2;
        entry "C" [ Int 0 ];
        Tuple [ entry "A" [ Int 1 ]; entry "B" [ Inf ]; entry "C" [ Int 0 ] ];
      ]

(* [interval_atom k q] is the interval atom of the delays below, up to,
   above or from [q], for [k] = 0, 1, 2 or 3; no delay is below [0], and the
   empty language is written [~_*]. *)
let interval_atom k q =
  let zero = Grade.Closed Rational.zero in
  if k = 0 && Rational.sign q = 0 then Grade.Compl (Grade.Star Grade.Any)
  else
    let lo, hi =
      match k with
      | 0 -> (zero, Grade.Open q)
      | 1 -> (zero, Grade.Closed q)
      | 2 -> (Grade.Open q, Grade.Unbounded)
      | _ -> (Grade.Closed q, Grade.Unbounded)
    in
    Grade.Delays (lo, hi)

(* [random family st] is a random literal of the forms of [cover family], over
   the operations [A], [B] and [C] of [costs]. *)
let random family st =
  let open Grade in
  let int n = Random.State.int st n in
  let tick () = Tick (int 4) in
  let letter () = pick st [ letter_a; letter_b; letter_c ] in
  let rec regex ~star depth =
    match int (if depth = 0 then 2 else if star then 7 else 4) with
    | 0 -> letter ()
    | 1 -> tick ()
    | 2 -> Seq (regex ~star (depth - 1), regex ~star (depth - 1))
    | 3 -> Union (regex ~star (depth - 1), regex ~star (depth - 1))
    | 4 -> Star (regex ~star (depth - 1))
    | 5 -> Any
    | _ -> Inter (Any, Compl (regex ~star (depth - 1)))
  in
  let braces ~star = Braces (regex ~star 2) in
  let rec timed depth =
    match int (if depth = 0 then 4 else 9) with
    | 0 -> letter ()
    | 1 -> rational_tick (Rational.make (int 7) (1 + int 4))
    | 2 ->
        interval_atom
          (pick st [ 0; 1; 2; 3 ])
          (Rational.make (int 7) (1 + int 4))
    | 3 -> Any
    | 4 -> Seq (timed (depth - 1), timed (depth - 1))
    | 5 -> Union (timed (depth - 1), timed (depth - 1))
    | 6 -> Star (timed (depth - 1))
    | 7 -> Inter (timed (depth - 1), timed (depth - 1))
    | _ -> Compl (timed (depth - 1))
  in
  let rec fractional depth =
    match int (if depth = 0 then 2 else 4) with
    | 0 -> letter ()
    | 1 -> rational_tick (Rational.make (int 7) (1 + int 4))
    | 2 -> Seq (fractional (depth - 1), fractional (depth - 1))
    | _ -> Union (fractional (depth - 1), fractional (depth - 1))
  in
  let level () = Name (pick st [ "Low"; "High" ]) in
  let entries names component =
    match List.filter (fun _ -> Random.State.bool st) names with
    | [] -> component ()
    | [ name ] -> entry name [ component () ]
    | names -> Tuple (List.map (fun name -> entry name [ component () ]) names)
  in
  match family with
  | Time -> (
      let number () =
        match int 3 with
        | 0 -> Int (int 6)
        | 1 -> rat (int 9) (2 + int 3)
        | _ -> Inf
      in
      let open_end = function
        | Closed a when Random.State.bool st -> Open a
        | b -> b
      in
      if Random.State.bool st then number ()
      else
        match span (number ()) (number ()) with
        | Interval (lo, hi) -> Interval (open_end lo, open_end hi)
        | lit -> lit)
  | Inclusion_traces -> braces ~star:false
  | Traces ->
      if Random.State.bool st then braces ~star:false
      else closed (braces ~star:false) (braces ~star:false)
  | Rational_inclusion_traces -> Braces (fractional 2)
  | Rational_traces ->
      if Random.State.bool st then Braces (fractional 2)
      else closed (Braces (fractional 2)) (Braces (fractional 2))
  | Regex ->
      if int 4 > 0 then braces ~star:true
      else closed (braces ~star:true) (braces ~star:true)
  | Rational_regex -> Braces (timed 2)
  | Rational_regex_costs ->
      if int 4 > 0 then Braces (timed 2)
      else closed (Braces (timed 2)) (Braces (timed 2))
  | Levels -> level ()
  | Timed_levels -> pair (pick st [ Int (int 5); Inf; Top ]) (level ())
  | Flow -> (
      match
        List.filter_map
          (fun sink ->
            if Random.State.bool st then Some (entry sink [ level () ])
            else None)
          [ "Audit"; "Board"; "_" ]
      with
      | [] -> level ()
      | outputs -> Tuple (level () :: outputs))
  | Resources -> (
      let lower () = pick st [ Top; Int (int 3 - 2) ] in
      let change () =
        if Random.State.bool st then Int (int 5 - 2)
        else span (lower ()) (pick st [ Int (int 3); Inf ])
      in
      let peak () = pick st [ Int (int 4); Inf ] in
      let usage () =
        if Random.State.bool st then [ change (); peak () ]
        else [ lower (); change (); peak () ]
      in
      if int 3 = 0 then Tuple (usage ())
      else
        match List.filter (fun _ -> Random.State.bool st) [ "Files"; "_" ] with
        | [] -> entry "Sockets" (usage ())
        | names ->
            Tuple
              (List.map
                 (fun name -> entry name (usage ()))
                 ("Sockets" :: names)))
  | Schedules -> (
      let durations () =
        match int 3 with
        | 0 -> Int (int 4)
        | 1 ->
            let n = int 3 in
            span (Int n) (if Random.State.bool st then Inf else Int (n + int 3))
        | _ -> Braces (Union (tick (), tick ()))
      in
      let times () =
        Braces
          (match int 3 with
          | 0 -> tick ()
          | 1 -> Union (tick (), tick ())
          | _ -> Seq (tick (), Star (tick ())))
      in
      match
        List.filter_map
          (fun name ->
            if Random.State.bool st then Some (entry name [ times () ])
            else None)
          [ "A"; "B"; "_" ]
      with
      | [] -> durations ()
      | entries -> Tuple (durations () :: entries))
  | Modes ->
      let mode () =
        entry
          (pick st [ "Off"; "On"; "_" ])
          [
            Name (pick st [ "Off"; "On"; "_"; "Stuck"; "≠" ]);
            pick st [ Int (int 4); Inf ];
          ]
      in
      if int 4 = 0 then Int (int 3)
      else if Random.State.bool st then mode ()
      else Tuple [ mode (); mode () ]
  | Counts ->
      entries [ "A"; "B"; "C"; "_" ] (fun () -> pick st [ Int (int 4); Inf ])

(* [distinct compare xs] is [xs] without the elements equal under [compare]
   to an earlier one. *)
let distinct compare =
  List.fold_left
    (fun cs c ->
      if List.exists (fun c' -> compare c c' = 0) cs then cs else cs @ [ c ])
    []

(* [samples (module G) family] is [G]'s unit, top and grades of one and two
   time steps, the grades of [cover family], the first six further distinct
   grades read from random literals of [family], and products and joins of
   pairs of these, the grades being inhabited under [costs]. *)
let samples (type a) (module G : Grade.S with type t = a) family : a list =
  let st = Random.State.make [| 11 |] in
  let read lit =
    match G.of_lit lit with
    | c when G.inhabited costs c -> Some c
    | _ | (exception Grade.Invalid_literal _) -> None
  in
  let delay n =
    Option.to_list (Option.map G.of_delay (G.Delay.read (Grade.Int n)))
  in
  let covered =
    distinct G.compare
      ([ G.one; G.top ] @ delay 1
      @ List.filter_map read (cover family)
      @ delay 2)
  in
  let base =
    first
      (List.length covered + 6)
      (distinct G.compare
         (covered
         @ List.filter_map read (List.init 400 (fun _ -> random family st))))
  in
  let nth i = List.nth base (i mod List.length base) in
  base
  @ List.init 3 (fun i -> G.mul (nth (i + 4)) (nth (i + 5)))
  @ List.init 3 (fun i -> G.join (nth (i + 4)) (nth (i + 6)))

let registered_laws =
  let context = "A:(1, 3), B:(2, 2), C:(0, 5)" in
  all "registry: every grade has a family of samples" Fun.id
    (fun name -> Option.is_some (family name))
    (List.map fst GradeRegistry.grade_modules)
  :: List.concat_map
       (fun (name, (module G : Grade.S)) ->
         match family name with
         | None -> []
         | Some family ->
             let samples = samples (module G) family in
             order_laws ~thirds:12 (module G) ~context costs samples
             @ algebra_laws ~width:10 (module G) ~context costs samples
             @ declared_laws (module G) ~context costs samples
             @ counterexample_laws
                 (module G)
                 ~offered:false ~context costs samples
             @ of_delay_laws (module G) costs ()
             @ of_bounds_laws (module G) costs)
       GradeRegistry.grade_modules

(* A cost model of fractional runtime bounds over the operations [A], [B] and
   [C]. *)
let fractional_costs =
  let table =
    [
      ("A", ((1, 2), (3, 2))); ("B", ((2, 3), (2, 3))); ("C", ((0, 1), (5, 2)));
    ]
  in
  {
    Grade.cost =
      (fun o ->
        let (n, d), (n', d') = List.assoc o table in
        (Grade.Closed (Rational.make n d), Grade.Closed (Rational.make n' d')));
    operations = List.map fst table;
  }

(* The laws of the trace grades over rational delays under
   [fractional_costs]. *)
let fractional_laws =
  let context = "A:(1/2, 3/2), B:(2/3, 2/3), C:(0, 5/2)" in
  List.concat_map
    (fun (module G : Grade.S) ->
      let samples = samples (module G) Rational_traces in
      order_laws ~thirds:12 (module G) ~context fractional_costs samples
      @ algebra_laws ~width:10 (module G) ~context fractional_costs samples
      @ declared_laws (module G) ~context fractional_costs samples
      @ of_delay_laws (module G) fractional_costs ()
      @ of_bounds_laws (module G) fractional_costs)
    [ rational_traces_lower; rational_traces_upper; rational_traces_interval ]

(* The trace grades without costs: inclusion of the normal forms, ignoring the
   runtime bounds of [costs], a counterexample to every failure, and the laws
   under [fractional_costs]. *)
let inclusion_laws =
  let module U = TraceInclusionGrades.UpperBound in
  let read r = U.of_lit (Grade.Braces r) in
  let a = Grade.Letter "A" and b = Grade.Letter "B" in
  let show = function Some e -> U.show e | None -> "none" in
  [
    check "traces by inclusion: a subset below"
      (U.leq costs (read a) (read (Grade.Union (a, b))))
      "{A} <= {A | B}";
    check "traces by inclusion: a superset not below"
      (not (U.leq costs (read (Grade.Union (a, b))) (read a)))
      "{A | B} <= {A}";
    check "traces by inclusion: delays paying for no operation"
      (not (U.leq costs (read a) (read (Grade.Tick 3))))
      "{A} <= {3}";
    check "traces by inclusion: delays merged"
      (U.equal costs
         (read (Grade.Seq (Grade.Tick 1, Grade.Tick 1)))
         (read (Grade.Tick 2)))
      "{1; 1} = {2}";
    check "traces by inclusion: top absorbing"
      (U.is_top costs (U.mul (read a) U.top))
      "{A} · ⊤ = ⊤";
    expect "traces by inclusion: counterexample" Fun.id ~expected:"{B}"
      (show (U.counterexample costs (read (Grade.Union (a, b))) (read a)));
    expect "traces by inclusion: no counterexample where the order holds" Fun.id
      ~expected:"none"
      (show (U.counterexample costs (read a) (read (Grade.Union (a, b)))));
  ]
  @ List.concat_map
      (fun ((module G : Grade.S), family) ->
        let samples = samples (module G) family in
        let context = "A:(1, 3), B:(2, 2), C:(0, 5)" in
        counterexample_laws (module G) ~offered:true ~context costs samples
        @ order_laws ~thirds:12
            (module G)
            ~context:"fractional bounds" fractional_costs samples
        @ algebra_laws ~width:10
            (module G)
            ~context:"fractional bounds" fractional_costs samples)
      [
        (inclusion_upper, Inclusion_traces);
        (rational_inclusion_upper, Rational_inclusion_traces);
        (rational_regex_upper, Rational_regex);
        (rational_regex_costs_lower, Rational_regex_costs);
        (rational_regex_costs_upper, Rational_regex_costs);
        (rational_regex_costs_interval, Rational_regex_costs);
      ]

(* The declared flags of the registered grades that are false with no
   refutation on the samples. *)
let registered_notes =
  List.concat_map
    (fun (name, (module G : Grade.S)) ->
      match family name with
      | None -> []
      | Some family -> flag_notes (module G) costs (samples (module G) family))
    GradeRegistry.grade_modules

(* ------------------------------------------------------------------ *)
(* Grades indexed by names                                             *)
(* ------------------------------------------------------------------ *)

module Indexed = GradeConstructions.Indexed
module ByName = Indexed.OfGrade (TimeGrades.UpperBound)
module IntervalsByName = Indexed.OfGrade (TimeGrades.Interval)
module RegexByName = Indexed.OfGrade (Grades.RegularTraceGradeDerivative)

(* The maps giving the name [s] the upper bound [v], the others [0]. *)
let single s v =
  Indexed.of_list ~compare:TimeGrades.UpperBound.compare
    ~others:(TimeGrades.UpperBound.of_delay 0)
    [ (s, v) ]

let bound n = TimeGrades.UpperBound.of_delay n
let bounds_up_to n = TimeGrades.UpperBound.top :: List.map bound (up_to n)

module ByName_conditions =
  Conditions
    (ByName)
    (struct
      let constant st =
        let v () =
          if Random.State.int st 8 = 0 then TimeGrades.UpperBound.top
          else bound (Random.State.int st 4)
        in
        match Random.State.int st 3 with
        | 0 -> Indexed.everywhere (v ())
        | 1 -> single (if Random.State.bool st then "A" else "B") (v ())
        | _ ->
            Indexed.of_list ~compare:TimeGrades.UpperBound.compare
              ~others:(v ())
              [ ("A", v ()); ("B", v ()) ]

      let values =
        List.map Indexed.everywhere (bounds_up_to 30)
        @ List.concat_map
            (fun s -> List.map (single s) (bounds_up_to 30))
            [ "A"; "B"; "Other" ]
        @ List.concat_map
            (fun a ->
              List.map
                (fun b ->
                  Indexed.of_list ~compare:TimeGrades.UpperBound.compare
                    ~others:(bound 0)
                    [ ("A", a); ("B", b) ])
                (bounds_up_to 5))
            (bounds_up_to 5)
    end)

(* [indexed_samples of_lit] is the grades read from a few literals of entries
   of the names [A] and [B], and the products and joins of pairs of them. *)
let indexed_samples (type a) (module G : Grade.S with type t = a) lits : a list
    =
  let base = G.one :: G.top :: List.map G.of_lit lits in
  base
  @ List.concat_map
      (fun x -> List.concat_map (fun y -> [ G.mul x y; G.join x y ]) base)
      (List.filteri (fun i _ -> i < 4) base)

let indexed =
  let open Grade in
  let entry name component = Tuple [ Name name; component ] in
  let by_name = (module ByName : Grade.S) in
  let intervals = (module IntervalsByName : Grade.S) in
  let upper_samples =
    indexed_samples
      (module ByName)
      [
        entry "A" (Int 3);
        Tuple [ entry "A" (Int 1); entry "B" Inf ];
        Int 2;
        Tuple [ entry "B" (Int 4); entry "C" (Int 0) ];
      ]
  in
  let regex_samples =
    indexed_samples
      (module RegexByName)
      [
        entry "A" (Braces (Seq (Letter "Send", Tick 1)));
        Tuple [ entry "A" (Int 1); entry "B" (Braces (Star (Tick 2))) ];
        Braces (Union (Tick 1, Letter "Recv"));
      ]
  in
  let context = "no cost model" in
  [
    reads "entry" by_name (entry "A" (Int 3)) "(A, 3)";
    reads "entries" by_name
      (Tuple [ entry "B" Inf; entry "A" (Int 3) ])
      "((A, 3), (B, ∞))";
    reads "everywhere" by_name (Int 4) "4";
    reads "unit entries dropped" by_name
      (Tuple [ entry "A" (Int 0); entry "B" (Int 2) ])
      "(B, 2)";
    reads "top" by_name Top "∞";
    reads "entry of an interval" intervals
      (entry "A" (span (Int 1) (Int 2)))
      "(A, [1, 2])";
    reads "entry of an unbounded interval" intervals
      (entry "A" (span (Int 1) Inf))
      "(A, [1, ∞))";
    reads "entry of a pair" intervals
      (Tuple [ Name "A"; Int 1; Int 4 ])
      "(A, [2, 3])";
    rejects "entry of an empty pair" intervals
      (Tuple [ Name "A"; Int 1; Int 2 ])
      "in the entry of 'A', the interval contains no integer";
    rejects "name listed twice" by_name
      (Tuple [ entry "A" (Int 1); entry "A" (Int 2) ])
      "listed twice";
    rejects "component" by_name (entry "A" (Name "Low")) "in the entry of 'A'";
    expect "default printed as an entry" Fun.id ~expected:"((A, 1), (_, 3))"
      (ByName.show
         (Indexed.of_list ~compare:TimeGrades.UpperBound.compare
            ~others:(bound 3)
            [ ("A", bound 1) ]));
    ByName_conditions.complete ~count:1000;
    expect "witnesses: complete over a complete grade" Fun.id
      ~expected:"complete"
      (match snd (ByName.witnesses ~degree:1 bounds []) with
      | Grade.Complete -> "complete"
      | Grade.Partial -> "partial");
    expect "witnesses: partial over a partial grade" Fun.id ~expected:"partial"
      (match snd (RegexByName.witnesses ~degree:1 bounds []) with
      | Grade.Complete -> "complete"
      | Grade.Partial -> "partial");
  ]
  @ order_laws (module ByName) ~context bounds upper_samples
  @ algebra_laws (module ByName) ~context bounds upper_samples
  @ of_delay_laws (module ByName) bounds ~monotone:true ()
  @ order_laws (module RegexByName) ~context bounds regex_samples
  @ algebra_laws (module RegexByName) ~context bounds regex_samples
  @ laws (module RegexByName) ~context bounds regex_samples

(* [Reader (G)] reads the literals of [G] by the parser, in the grade position
   of a box. *)
module Reader (G : Grade.S) = struct
  module Grammar = Parser.Grammar.Make (Grades.GradeSystem.Identity (G))

  let parse text =
    let lexbuf = Lexing.from_string ("box " ^ text ^ " ()") in
    match Grammar.payload (Parser.Lexer.tokens ()) lexbuf with
    | { it = SugaredAst.GenBox ({ it = SugaredAst.GradeLit rho; _ }, _); _ } ->
        Ok rho
    | _ -> Error "not a box of a literal"
    | exception Grammar.Error -> Error "parser error"
    | exception Utils.Error.Error d -> Error d.Utils.Diagnostic.message
end

(* The laws of the mode-switch costs on grades over the modes [Off], [On] and [Idle],
   the modes not named and [Stuck]: changes of mode, operations performed only
   in some modes, runs stuck at a cost, entries of the modes not named, the
   unit and the top, and the products and joins of the partial operations and
   changes of mode. Besides, the product of two partial operations; the
   totality of the products, a grade [x] having a run from every mode iff
   [(Stuck, Stuck, 0) ≾ x · (Stuck, Stuck, 0)]; and the reading back of the
   printed grades. *)
let mode_laws =
  let module M = Grades.ModeSwitchCostGrades.ModeSwitchCosts in
  let open Grade in
  let entry p q c = Tuple [ Name p; Name q; c ] in
  let send = entry "On" "On" (Int 4)
  and radio_on = entry "Off" "On" (Int 2)
  and radio_off = entry "On" "Off" (Int 1)
  and stuck_after =
    Tuple [ entry "Off" "Off" (Int 18); entry "On" "Stuck" (Int 6) ]
  and round_trip =
    Tuple [ entry "On" "Off" (Int 1); entry "Off" "On" (Int 1) ]
  in
  let partial =
    List.map M.of_lit [ send; radio_on; radio_off; stuck_after; round_trip ]
  in
  let lits =
    [
      send;
      radio_on;
      radio_off;
      stuck_after;
      round_trip;
      Tuple [ entry "Off" "Off" (Int 1); entry "On" "On" (Int 3) ];
      Int 1;
      Tuple [ entry "Idle" "On" Inf; entry "On" "Idle" (Int 1) ];
      Tuple [ entry "On" "On" (Int 2); entry "On" "Stuck" (Int 0) ];
      entry "Stuck" "Stuck" (Int 0);
      Tuple
        [
          entry "On" "On" (Int 2);
          entry "_" "_" (Int 1);
          entry "_" "Stuck" (Int 0);
        ];
      Tuple
        [ entry "On" "_" (Int 1); entry "_" "On" (Int 2); entry "_" "≠" Inf ];
    ]
  in
  let samples =
    distinct M.compare
      ((M.one :: M.top :: List.map M.of_lit lits)
      @ List.concat_map
          (fun x ->
            List.concat_map (fun y -> [ M.mul x y; M.join x y ]) partial)
          (M.top :: M.of_lit (Int 1) :: partial))
  in
  let stuck = M.of_lit (entry "Stuck" "Stuck" (Int 0)) in
  let total x = M.leq bounds stuck (M.mul x stuck) in
  let send = M.of_lit send and radio_on = M.of_lit radio_on in
  let reads_back x =
    let module R = Reader (M) in
    match R.parse (M.show x) with
    | Ok x' -> M.compare x x' = 0
    | Error _ -> false
  in
  let context = "mode-switch costs" in
  [
    expect "mode-switch-costs: a partial operation, then another" Fun.id
      ~expected:"(On, Stuck, 4)"
      (M.show (M.mul send radio_on));
    expect "mode-switch-costs: a partial operation, then another, not the unit"
      show_bool ~expected:false
      (M.leq bounds (M.mul send radio_on) M.one);
    all "mode-switch-costs: products total"
      (fun (x, y) -> M.show x ^ ", " ^ M.show y)
      (fun (x, y) -> total (M.mul x y))
      (pairs samples);
    all "mode-switch-costs: printed grades read back" M.show reads_back
      (samples @ List.concat_map (fun x -> List.map (M.mul x) samples) samples);
  ]
  @ order_laws (module M) ~context bounds samples
  @ algebra_laws (module M) ~context bounds samples
  @ of_delay_laws (module M) bounds ()

(* The laws of the resource levels on grades acquiring and releasing the resources
   [Files] and [Sockets], with ranges of net changes, explicit and unbounded
   troughs and an entry of the resources not named, the unit and the top; and
   the products and joins of a release and an acquisition with these. Besides,
   the order of a release and an acquisition, and the reading back of the
   printed grades. *)
let resource_laws =
  let module P = Grades.ResourceLevelGrades.ResourceLevels in
  let module R = Reader (P) in
  let open Grade in
  let release = entry "Files" [ Int (-1); Int 0 ]
  and acquisition = entry "Files" [ Int 1; Int 1 ] in
  let lits =
    [
      release;
      acquisition;
      entry "Sockets" [ span (Int 0) (Int 2); Int 3 ];
      entry "Files" [ Int (-1); Int 0; Int 0 ];
      entry "Files" [ Int (-2); span (Int (-1)) (Int 1); Int 2 ];
      entry "Sockets" [ Int 1; Int 2 ];
      entry "Files" [ Top; Int 0; Int 0 ];
      Tuple
        [ entry "Files" [ Int (-1); Int 0 ]; entry "Sockets" [ Int 1; Int 1 ] ];
      Tuple
        [
          entry "Files" [ Int 0; Int 2 ]; entry "_" [ span (Int (-1)) Inf; Inf ];
        ];
    ]
  in
  let close = P.of_lit release and open_ = P.of_lit acquisition in
  let base = P.one :: P.top :: List.map P.of_lit lits in
  let samples =
    distinct P.compare
      (base
      @ List.concat_map
          (fun x ->
            [
              P.mul x close;
              P.mul close x;
              P.mul x open_;
              P.mul open_ x;
              P.join x close;
              P.join x open_;
            ])
          base)
  in
  let reads_back x =
    match R.parse (P.show x) with
    | Ok x' -> P.compare x x' = 0
    | Error _ -> false
  in
  let context = "resource levels" in
  [
    expect "resource-levels: not commutative" show_bool ~expected:false
      P.commutative;
    expect "resource-levels: unit not least" show_bool ~expected:false
      P.unit_least;
    expect "resource-levels: a release, then an acquisition" Fun.id
      ~expected:"(Files, -1, 0, 0)"
      (P.show (P.mul close open_));
    expect "resource-levels: an acquisition, then a release" Fun.id
      ~expected:"(Files, 0, 1)"
      (P.show (P.mul open_ close));
    all "resource-levels: printed grades read back" P.show reads_back samples;
  ]
  @ order_laws (module P) ~context costs samples
  @ algebra_laws (module P) ~context costs samples

(* The printed grades of the interval grades with costs, on their samples,
   read back as equal grades: a lower bound of all runs prints as '⊤' and reads
   back as the top '{0}' of the lower order, equal to it. *)
let interval_read_back =
  List.concat_map
    (fun (name, (module G : Grade.S)) ->
      match family name with
      | Some family when contains name "cost-interval" ->
          let module R = Reader (G) in
          let reads_back x =
            match R.parse (G.show x) with
            | Ok x' -> G.equal costs x x'
            | Error _ -> false
          in
          [
            all
              (name ^ ": printed grades read back")
              G.show reads_back
              (samples (module G) family);
          ]
      | _ -> [])
    GradeRegistry.grade_modules

(* ------------------------------------------------------------------ *)
(* Constructions                                                       *)
(* ------------------------------------------------------------------ *)

module Resources = Grades.ResourceLevelGrades

(* The bounds [-∞], [-2], ..., [2] and [∞]. *)
let peak_bounds =
  (Resources.Minus_inf :: List.init 5 (fun d -> Resources.Fin (d - 2)))
  @ [ Resources.Plus_inf ]

(* [half_laws (module H) changes] checks, on all the pairs of the net changes
   [changes] and the extremes [peak_bounds], the laws of the half [H] of the
   resource levels but the zero-product law, which it lacks; the laws of its
   semilattice of extremes; and the laws A1-A5 of its action. *)
let half_laws
    (module H : Grade.S with type t = Resources.bound * Resources.bound) changes
    =
  let elements =
    List.concat_map (fun d -> List.map (fun e -> (d, e)) peak_bounds) changes
  in
  let width = List.length elements in
  let context = "all pairs of bounds from -2 to 2" in
  order_laws ~width ~zero_product:false (module H) ~context bounds elements
  @ algebra_laws ~width (module H) ~context bounds elements
  @ declared_laws (module H) ~context bounds elements
  @ semilattice_laws ~width:(List.length peak_bounds)
      (acted (module H) bounds)
      peak_bounds
  @ action_laws (action_of_semidirect (module H) bounds) changes peak_bounds

(* The grades of one resource with bounds from [-1] to [1]: the troughs [t],
   ranges [[d1, d2]] of net changes and peaks [h] with [t ≤ min(0, d1)],
   [d1 ≤ d2] and [h ≥ max(0, d2)]. *)
let one_resource_grades =
  let open Resources in
  let leq b b' =
    match (b, b') with
    | Minus_inf, _ | _, Plus_inf -> true
    | _, Minus_inf | Plus_inf, _ -> false
    | Fin d, Fin d' -> d <= d'
  in
  let range xs = List.map (fun d -> Fin d) xs in
  List.concat_map
    (fun t ->
      List.concat_map
        (fun d1 ->
          List.concat_map
            (fun d2 ->
              List.filter_map
                (fun h ->
                  if leq t d1 && leq d1 d2 && leq d2 h then
                    Some ((d1, t), (d2, h))
                  else None)
                (range [ 0; 1 ] @ [ Plus_inf ]))
            (range [ -1; 0; 1 ] @ [ Plus_inf ]))
        (Minus_inf :: range [ -1; 0; 1 ]))
    (Minus_inf :: range [ -1; 0 ])

module Schedules = Grades.WindowedScheduleGrades

(* Durations: single numbers, intervals, finite and infinite sets, and all
   numbers. *)
let schedule_durations =
  let open Grade in
  List.map Schedules.Durations.of_lit
    [
      Int 0;
      Int 1;
      Int 2;
      span (Int 1) (Int 3);
      span (Int 2) Inf;
      Braces (Union (Tick 1, Tick 3));
      Braces (Star (Tick 2));
      Top;
    ]

(* Times: none, single times, finite and infinite sets, and all times. *)
let schedule_times =
  let open Grade in
  Schedules.Times.bottom :: Schedules.Times.top
  :: List.map Schedules.Times.of_lit
       [
         Braces (Tick 0);
         Braces (Union (Tick 1, Tick 3));
         Braces (Seq (Tick 2, Star (Tick 1)));
         Braces (Star (Tick 2));
       ]

(* The times of the operations [A] and [B] and of the others, and the top. *)
let schedule_times_by_name =
  let times = Array.of_list schedule_times in
  Schedules.TimesByName.top
  :: List.concat_map
       (fun others ->
         List.concat_map
           (fun a ->
             List.map
               (fun b ->
                 Indexed.of_list ~compare:Schedules.Times.compare ~others
                   [ ("A", times.(a)); ("B", times.(b)) ])
               [ 0; 5 ])
           [ 0; 2; 3; 4 ])
       [ times.(0); times.(2) ]

let schedule_laws =
  let module D = Schedules.Durations in
  let context = "durations" in
  let shift =
    action_of_components
      (module D)
      (module Schedules.TimesByName)
      Schedules.ShiftByName.act bounds
  in
  let schedules =
    List.concat_map
      (fun d ->
        List.map
          (fun e -> (d, e))
          (List.filteri (fun i _ -> i < 5) schedule_times_by_name))
      (List.filteri (fun i _ -> i < 4) schedule_durations)
  in
  semilattice_laws
    ~width:(List.length schedule_times)
    (module Schedules.Times)
    schedule_times
  @ semilattice_laws
      ~width:(List.length schedule_times_by_name)
      (module Schedules.TimesByName)
      schedule_times_by_name
  @ order_laws
      ~width:(List.length schedule_durations)
      (module D)
      ~context bounds schedule_durations
  @ algebra_laws
      ~width:(List.length schedule_durations)
      (module D)
      ~context bounds schedule_durations
  @ declared_laws (module D) ~context bounds schedule_durations
  @ action_laws shift schedule_durations schedule_times_by_name
  @ semidirect_laws (module Schedules.WindowedSchedules) shift bounds schedules

let resource_construction_laws =
  let changes = List.init 5 (fun d -> Resources.Fin (d - 2)) in
  let context = "troughs, ranges and peaks from -1 to 1" in
  half_laws (module Resources.Upper) (changes @ [ Resources.Plus_inf ])
  @ half_laws (module Resources.Lower) (Resources.Minus_inf :: changes)
  @ order_laws
      ~width:(List.length one_resource_grades)
      (module Resources.OneResource)
      ~context bounds one_resource_grades
  @ algebra_laws
      ~width:(List.length one_resource_grades)
      (module Resources.OneResource)
      ~context bounds one_resource_grades
  @ declared_laws
      (module Resources.OneResource)
      ~context bounds one_resource_grades

(* ------------------------------------------------------------------ *)
(* Finite grades, on all their elements                                *)
(* ------------------------------------------------------------------ *)

module Levels = LevelGrades.SecurityLevels

let written_levels = [ None; Some LevelGrades.Low; Some LevelGrades.High ]

(* The outputs to the sinks [Audit] and [Board] and the other sinks, each
   unwritten or written at a level: every element over these sinks. *)
let all_outputs =
  List.concat_map
    (fun others ->
      List.concat_map
        (fun audit ->
          List.map
            (fun board ->
              Indexed.of_list ~compare:LevelGrades.WrittenAt.compare ~others
                [ ("Audit", audit); ("Board", board) ])
            written_levels)
        written_levels)
    written_levels

let all_flow_levels =
  List.concat_map
    (fun level -> List.map (fun outputs -> (level, outputs)) all_outputs)
    [ LevelGrades.Low; High ]

let finite_laws =
  let levels = [ LevelGrades.Low; High ] in
  let raise =
    action_of_components
      (module Levels)
      (module LevelGrades.Outputs)
      LevelGrades.Raise.act bounds
  in
  let context = "all elements" in
  let flow_context = "all elements over the sinks Audit, Board and _" in
  let width = List.length all_flow_levels in
  order_laws ~width:2 (module Levels) ~context bounds levels
  @ algebra_laws ~width:2 (module Levels) ~context bounds levels
  @ declared_laws (module Levels) ~context bounds levels
  @ semilattice_laws ~width:3 (module LevelGrades.WrittenAt) written_levels
  @ semilattice_laws ~width:(List.length all_outputs)
      (module LevelGrades.Outputs)
      all_outputs
  @ order_laws ~width (module Flow) ~context:flow_context bounds all_flow_levels
  @ algebra_laws ~width
      (module Flow)
      ~context:flow_context bounds all_flow_levels
  @ declared_laws (module Flow) ~context:flow_context bounds all_flow_levels
  @ action_laws raise levels all_outputs
  @ semidirect_laws (module Flow) raise bounds all_flow_levels

(* The laws of the instances of the delays. *)
let delay_laws =
  stepped_delay_laws ~name:"natural delays" (module Grades.Delay.Nat)
  @ measured_delay_laws ~name:"rational delays" (module Grades.Delay.Rational)

let () =
  let checks =
    delay_laws @ levels @ products @ counterexamples @ witnesses @ literals
    @ tops @ registry @ registered_laws @ fractional_laws @ inclusion_laws
    @ indexed @ mode_laws @ resource_laws @ interval_read_back @ schedule_laws
    @ resource_construction_laws @ finite_laws
  in
  let failures = List.filter (fun c -> not c.passed) checks in
  List.iter (Printf.printf "note: %s\n") registered_notes;
  List.iter (fun c -> Printf.printf "FAIL %s: %s\n" c.name c.detail) failures;
  Printf.printf "%d of %d checks passed\n"
    (List.length checks - List.length failures)
    (List.length checks);
  if failures <> [] then exit 1
