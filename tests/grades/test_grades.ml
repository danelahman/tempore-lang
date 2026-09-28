(* Unit tests of the security-level grade, the product construction and its
   counterexamples, the witnesses of closed conditions, the interpretation of
   literals by the grades of [GradeRegistry.grade_modules], and the laws of
   these grades on samples. *)

module Grade = Grades.Grade
module TimeGrades = Grades.TimeGrades
module TimedTraceGrades = Grades.TimedTraceGrades
module LevelGrades = Grades.LevelGrades
module GradeConstructions = Grades.GradeConstructions
module GradeRegistry = Grades.GradeRegistry
open LawChecks

let show_bool = string_of_bool
let show_names names = "[" ^ String.concat "; " names ^ "]"
let bounds = { Grade.cost = (fun _ -> (1, 2)); operations = [] }

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
    expect "levels: ticks touch no level" show ~expected:Low (L.of_nat 5);
    expect "levels: no ticks is the unit" show ~expected:L.one (L.of_nat 0);
    expect "levels: time shadow" show ~expected:Low (L.of_bounds (1, 2));
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

module TraceLevels =
  GradeConstructions.Product
    (TimedTraceGrades.UpperBound)
    (LevelGrades.SecurityLevels)

module RegexLevels =
  GradeConstructions.Product
    (Grades.RegularTraceGradeDerivative)
    (LevelGrades.SecurityLevels)

let lit_of_pair n level = Grade.Tuple [ Grade.Int n; Grade.Name level ]

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
      ~expected:"({Write},Low)"
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
      ~expected:"traces-upper-bound×security-levels" TraceLevels.name;
    check "product: at least as long and as low"
      (TimeLevels.leq bounds (p 3 "Low") (p 2 "High"))
      "(3,Low) ≾ (2,High)";
    check "product: too short"
      (not (TimeLevels.leq bounds (p 2 "Low") (p 3 "Low")))
      "(2,Low) ≾ (3,Low)";
    check "product: too high"
      (not (TimeLevels.leq bounds (p 3 "High") (p 3 "Low")))
      "(3,High) ≾ (3,Low)";
    expect "product: join" Fun.id ~expected:"(3,High)"
      (show (TimeLevels.join (p 3 "Low") (p 5 "High")));
    expect "product: product" Fun.id ~expected:"(8,High)"
      (show (TimeLevels.mul (p 3 "Low") (p 5 "High")));
    expect "product: unit" Fun.id ~expected:"(0,Low)" (show TimeLevels.one);
    expect "product: top" Fun.id ~expected:"(0,High)" (show TimeLevels.top);
    expect "product: ticks" Fun.id ~expected:"(4,Low)"
      (show (TimeLevels.of_nat 4));
    expect "product: time shadow" Fun.id ~expected:"(1,Low)"
      (show (TimeLevels.of_bounds (1, 2)));
    check "product: equal"
      (TimeLevels.equal bounds (p 3 "Low")
         (TimeLevels.of_lit (lit_of_pair 3 "Low")))
      "(3,Low) = (3,Low)";
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
        | Some (lo, hi) -> Printf.sprintf "(%d, %d)" lo hi | None -> "None")
      ~expected:(Some (1, 2))
      (TraceLevels.implied_bounds bounds send_low);
    expect "product: level component" Fun.id ~expected:"(3,High)"
      (show (p 3 "High"));
  ]

let time_lower = (module TimeGrades.LowerBound : Grade.S)
let time_upper = (module TimeGrades.UpperBound : Grade.S)
let time_interval = (module TimeGrades.Interval : Grade.S)
let traces_lower = (module TimedTraceGrades.LowerBound : Grade.S)
let traces_upper = (module TimedTraceGrades.UpperBound : Grade.S)
let traces_interval = (module TimedTraceGrades.Interval : Grade.S)
let security_levels = (module LevelGrades.SecurityLevels : Grade.S)
let peak_usage = (module Grades.PeakGrades.PeakUsage : Grade.S)
let time_windows = (module Grades.WindowGrades.TimeWindows : Grade.S)
let flow_levels = (module LevelGrades.FlowLevels : Grade.S)
let time_lower_levels = (module TimeLevels : Grade.S)
let time_upper_levels = (module UpperLevels : Grade.S)

let literals =
  let open Grade in
  let seq r s = Seq (r, s) and union r s = Union (r, s) in
  let send = Letter "Send" in
  [
    rejects "negative integer" time_lower (Int (-1)) "must be non-negative";
    rejects "negative interval endpoint" time_interval
      (Tuple [ Int (-1); Int 5 ])
      "must be non-negative";
    reads "release" peak_usage (Tuple [ Int (-1); Int 0 ]) "(-1,0)";
    reads "unbounded peak" peak_usage (Tuple [ Int (-3); Inf ]) "(-3,∞)";
    reads "top" peak_usage Top "(∞,∞)";
    rejects "peak below the change" peak_usage
      (Tuple [ Int 2; Int 1 ])
      "at least the net change";
    rejects "negative peak" peak_usage
      (Tuple [ Int (-2); Int (-1) ])
      "at least 0";
    rejects "unbounded change" peak_usage (Tuple [ Inf; Int 3 ]) "needs a peak";
    rejects "integer" peak_usage (Int 3) "not plain integers";
    rejects "level" peak_usage (Tuple [ Int 1; Name "Low" ]) "in the peak";
    reads "duration" time_windows (Int 3) "3";
    reads "interval of durations" time_windows (Tuple [ Int 2; Int 5 ]) "(2,5)";
    reads "unbounded durations" time_windows (Tuple [ Int 2; Inf ]) "(2,∞)";
    reads "set of durations" time_windows
      (Braces (union (Tick 1) (Tick 3)))
      "{1 | 3}";
    reads "durations and times" time_windows
      (Tuple [ Int 1; Braces (Tick 0) ])
      "(1,{0})";
    reads "times by single ticks" time_windows
      (Tuple [ Int 1; Braces (seq Any Any) ])
      "(1,{2})";
    reads "top" time_windows Top "⊤";
    rejects "operation" time_windows
      (Tuple [ Int 1; Braces send ])
      "name no operation such as 'Send'";
    rejects "reversed interval" time_windows
      (Tuple [ Int 7; Int 1 ])
      "must satisfy n <= m";
    rejects "negative duration" time_windows (Int (-1)) "must be non-negative";
    rejects "no durations" time_windows
      (Braces (Inter (Tick 1, Tick 2)))
      "is empty";
    rejects "level" time_windows (Name "Low") "not names such as 'Low'";
    reads "level" flow_levels (Name "High") "High";
    reads "outputs" flow_levels
      (Tuple
         [
           Name "High";
           Tuple [ Name "Board"; Name "Low" ];
           Tuple [ Name "Audit"; Name "High" ];
         ])
      "(High,(Audit,High),(Board,Low))";
    reads "top" flow_levels Top "⊤";
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
    reads "integer" time_lower (Int 3) "3";
    reads "top" time_lower Top "0";
    rejects "infinity" time_lower Inf "not '∞'";
    rejects "pair" time_lower (Tuple [ Int 1; Int 5 ]) "not pairs";
    reads "infinity" time_upper Inf "∞";
    reads "top" time_upper Top "∞";
    rejects "name" time_upper (Name "Low") "not names such as 'Low'";
    reads "interval" time_interval (Tuple [ Int 1; Int 5 ]) "(1,5)";
    reads "open interval" time_interval (Tuple [ Int 3; Inf ]) "(3,∞)";
    reads "top" time_interval Top "(0,∞)";
    rejects "reversed interval" time_interval (Tuple [ Int 5; Int 3 ]) "n <= m";
    rejects "infinite lower end" time_interval (Tuple [ Inf; Inf ]) "endpoints";
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
    reads "top" traces_interval Top "({0},⊤)";
    reads "unbounded upper component" traces_interval
      (Tuple [ Braces send; Top ])
      "({Send},⊤)";
    reads "pair of integers" traces_interval
      (Tuple [ Int 1; Int 2 ])
      "({1},{2})";
    reads "integer" traces_interval (Int 2) "({2},{2})";
    rejects "reversed pair" traces_interval (Tuple [ Int 5; Int 3 ]) "n <= m";
    reads "Low" security_levels (Name "Low") "Low";
    reads "High" security_levels (Name "High") "High";
    reads "top" security_levels Top "High";
    rejects "unknown level" security_levels (Name "Medium")
      "unknown level 'Medium'";
    rejects "integer" security_levels (Int 0) "not plain integers";
    reads "pair" time_lower_levels (lit_of_pair 3 "High") "(3,High)";
    reads "top" time_lower_levels Top "(0,High)";
    reads "component tops" time_lower_levels (Tuple [ Top; Top ]) "(0,High)";
    reads "pair" time_upper_levels (Tuple [ Inf; Name "Low" ]) "(∞,Low)";
    reads "top" time_upper_levels Top "(∞,High)";
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
      ~expected:[ "time-interval"; "peak-usage"; "time-windows" ]
      (GradeRegistry.accepting (Grade.Tuple [ Grade.Int 3; Grade.Inf ]));
    expect "registry: grades reading a repetition" show_names
      ~expected:
        [
          "traces-regex";
          "traces-regex-symbolic";
          "traces-regex-lower";
          "traces-regex-upper";
          "traces-regex-interval";
          "traces-regex-lower-symbolic";
          "traces-regex-upper-symbolic";
          "traces-regex-interval-symbolic";
        ]
      (GradeRegistry.accepting (Grade.Braces (Grade.Star (Grade.Letter "A"))));
    expect "registry: grades offered by the CLI only" show_names
      ~expected:
        [
          "traces-regex-derivatives";
          "traces-regex-plain";
          "traces-regex-lower-derivatives";
          "traces-regex-upper-derivatives";
          "traces-regex-interval-derivatives";
          "traces-regex-lower-plain";
          "traces-regex-upper-plain";
          "traces-regex-interval-plain";
        ]
      (List.concat_map
         (fun (g : GradeRegistry.group) ->
           List.filter_map
             (fun (name, (info : GradeRegistry.info)) ->
               if info.visibility = Cli_only then Some name else None)
             g.grades)
         GradeRegistry.groups);
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
    fst (G.witnesses bounds (constants lhs @ constants rhs))

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

      let values = List.map TimeGrades.LowerBound.of_nat (up_to 60)
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
        :: List.map TimeGrades.UpperBound.of_nat (up_to 60)
    end)

(* The intervals [(n, m)] with [n ≤ m ≤ bound] or [m = ∞]. *)
let intervals bound =
  List.concat_map
    (fun n ->
      Grade.Tuple [ nat n; Grade.Inf ]
      :: List.map
           (fun m -> Grade.Tuple [ nat n; nat m ])
           (List.init (bound - n + 1) (( + ) n)))
    (up_to bound)

module Interval_conditions =
  Conditions
    (TimeGrades.Interval)
    (struct
      let constant st =
        let n = Random.State.int st 4 in
        TimeGrades.Interval.of_lit
          (Grade.Tuple
             [
               nat n;
               (if Random.State.int st 6 = 0 then Grade.Inf
                else nat (n + Random.State.int st 3));
             ])

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

let witnesses =
  let module L = TimeGrades.LowerBound in
  let lower n = L.of_lit (nat n) in
  let five_ge_one_j =
    ( Lower_conditions.Const (lower 5),
      Lower_conditions.Mul (Const (lower 1), Rigid) )
  in
  let completeness (module G : Grade.S) =
    match snd (G.witnesses bounds []) with
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
    check "flow-levels: a failure at an unnamed sink shows at a witness"
      (not
         (Flow_conditions.at_witnesses
            (Flow_conditions.Rigid, Const (Flow.of_lit (Grade.Name "High")))))
      "j <= High";
    expect "witnesses: time grades complete" Fun.id ~expected:"complete"
      (completeness time_interval);
    expect "witnesses: levels complete" Fun.id ~expected:"complete"
      (completeness (module LevelGrades.SecurityLevels));
    expect "witnesses: product of complete grades complete" Fun.id
      ~expected:"complete"
      (completeness (module UpperLevels));
    expect "witnesses: timed traces partial" Fun.id ~expected:"partial"
      (completeness traces_upper);
    expect "witnesses: product with a partial grade partial" Fun.id
      ~expected:"partial"
      (completeness (module TraceLevels));
    expect "witnesses: peak usage partial" Fun.id ~expected:"partial"
      (completeness peak_usage);
    expect "witnesses: time windows partial" Fun.id ~expected:"partial"
      (completeness time_windows);
    expect "witnesses: flow-levels complete" Fun.id ~expected:"complete"
      (completeness (module Flow));
  ]

(* ------------------------------------------------------------------ *)
(* Laws of the registered grades                                       *)
(* ------------------------------------------------------------------ *)

(* A cost model over the operations [A], [B] and [C]. *)
let costs =
  let table = [ ("A", (1, 3)); ("B", (2, 2)); ("C", (0, 5)) ] in
  {
    Grade.cost = (fun o -> List.assoc o table);
    operations = List.map fst table;
  }

(* A random literal of any form, over the operations [A] and [B] and the
   levels. *)
let random_lit st =
  let int () = Random.State.int st 9 - 2 in
  let level () = Grade.Name (if Random.State.bool st then "Low" else "High") in
  let rec regex depth =
    match Random.State.int st (if depth = 0 then 3 else 6) with
    | 0 -> Grade.Letter (if Random.State.bool st then "A" else "B")
    | 1 -> Grade.Tick (Random.State.int st 3)
    | 2 -> Grade.Any
    | 3 -> Grade.Seq (regex (depth - 1), regex (depth - 1))
    | 4 -> Grade.Union (regex (depth - 1), regex (depth - 1))
    | _ -> Grade.Star (regex (depth - 1))
  in
  match Random.State.int st 7 with
  | 0 -> Grade.Int (int ())
  | 1 -> level ()
  | 2 -> Grade.Tuple [ Grade.Int (int ()); Grade.Int (int ()) ]
  | 3 -> Grade.Tuple [ Grade.Int (int ()); Grade.Inf ]
  | 4 -> Grade.Tuple [ Grade.Int (int ()); level () ]
  | 5 -> Grade.Braces (regex 2)
  | _ -> Grade.Tuple [ Grade.Braces (regex 2); Grade.Braces (regex 2) ]

(* [samples (module G)] is [G]'s unit, top and grades of one and two time
   steps, the first six distinct grades read from random literals, and
   products and joins of pairs of these. *)
let samples (type a) (module G : Grade.S with type t = a) : a list =
  let st = Random.State.make [| 11 |] in
  let read lit =
    match G.of_lit lit with
    | c when G.inhabited costs c -> Some c
    | _ | (exception Grade.Invalid_literal _) -> None
  in
  let distinct =
    List.fold_left
      (fun cs c ->
        if List.exists (fun c' -> G.compare c c' = 0) cs then cs else cs @ [ c ])
      []
  in
  let read_back =
    List.filteri
      (fun i _ -> i < 6)
      (distinct (List.filter_map read (List.init 400 (fun _ -> random_lit st))))
  in
  let base = [ G.one; G.top; G.of_nat 1; G.of_nat 2 ] @ read_back in
  let nth i = List.nth base (i mod List.length base) in
  base
  @ List.init 3 (fun i -> G.mul (nth (i + 4)) (nth (i + 5)))
  @ List.init 3 (fun i -> G.join (nth (i + 4)) (nth (i + 6)))

let registered_laws =
  List.concat_map
    (fun (_, (module G : Grade.S)) ->
      let samples = samples (module G) in
      let context = "A:(1,3), B:(2,2), C:(0,5)" in
      order_laws (module G) ~context costs samples
      @ algebra_laws (module G) ~context costs samples
      @ counterexample_laws (module G) ~offered:false ~context costs samples
      @ of_nat_laws (module G) costs ())
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
    ~others:(TimeGrades.UpperBound.of_nat 0)
    [ (s, v) ]

let bound n = TimeGrades.UpperBound.of_nat n
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
    reads "entry" by_name (entry "A" (Int 3)) "(A,3)";
    reads "entries" by_name
      (Tuple [ entry "B" Inf; entry "A" (Int 3) ])
      "((A,3),(B,∞))";
    reads "everywhere" by_name (Int 4) "4";
    reads "unit entries dropped" by_name
      (Tuple [ entry "A" (Int 0); entry "B" (Int 2) ])
      "(B,2)";
    reads "top" by_name Top "∞";
    reads "entry of a tuple" intervals
      (Tuple [ Name "A"; Int 1; Int 2 ])
      "(A,1,2)";
    reads "entry of a nested tuple" intervals
      (entry "A" (Tuple [ Int 1; Int 2 ]))
      "(A,1,2)";
    rejects "name listed twice" by_name
      (Tuple [ entry "A" (Int 1); entry "A" (Int 2) ])
      "listed twice";
    rejects "component" by_name (entry "A" (Name "Low")) "in the entry of 'A'";
    expect "default printed as an entry" Fun.id ~expected:"((A,1),(_,3))"
      (ByName.show
         (Indexed.of_list ~compare:TimeGrades.UpperBound.compare
            ~others:(bound 3)
            [ ("A", bound 1) ]));
    ByName_conditions.complete ~count:1000;
    expect "witnesses: complete over a complete grade" Fun.id
      ~expected:"complete"
      (match snd (ByName.witnesses bounds []) with
      | Grade.Complete -> "complete"
      | Grade.Partial -> "partial");
    expect "witnesses: partial over a partial grade" Fun.id ~expected:"partial"
      (match snd (RegexByName.witnesses bounds []) with
      | Grade.Complete -> "complete"
      | Grade.Partial -> "partial");
  ]
  @ order_laws (module ByName) ~context bounds upper_samples
  @ algebra_laws (module ByName) ~context bounds upper_samples
  @ of_nat_laws (module ByName) bounds ~monotone:true ()
  @ order_laws (module RegexByName) ~context bounds regex_samples
  @ algebra_laws (module RegexByName) ~context bounds regex_samples
  @ laws (module RegexByName) ~context bounds regex_samples

let () =
  let checks =
    levels @ products @ counterexamples @ witnesses @ literals @ tops @ registry
    @ registered_laws @ indexed
  in
  let failures = List.filter (fun c -> not c.passed) checks in
  List.iter (fun c -> Printf.printf "FAIL %s: %s\n" c.name c.detail) failures;
  Printf.printf "%d of %d checks passed\n"
    (List.length checks - List.length failures)
    (List.length checks);
  if failures <> [] then exit 1
