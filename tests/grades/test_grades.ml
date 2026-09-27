(* Unit tests of the security-level grade, the product construction and its
   counterexamples, and the interpretation of literals by the grades of
   [GradeRegistry.grade_modules]. *)

module Grade = Grades.Grade
module TimeGrades = Grades.TimeGrades
module TimedTraceGrades = Grades.TimedTraceGrades
module LevelGrades = Grades.LevelGrades
module GradeConstructions = Grades.GradeConstructions
module GradeRegistry = Grades.GradeRegistry

type check = { name : string; passed : bool; detail : string }

let check name passed detail = { name; passed; detail }

let expect name show ~expected actual =
  check name (expected = actual)
    ("expected " ^ show expected ^ ", got " ^ show actual)

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
let time_lower_levels = (module TimeLevels : Grade.S)
let time_upper_levels = (module UpperLevels : Grade.S)

let literals =
  let open Grade in
  let seq r s = Seq (r, s) and union r s = Union (r, s) in
  let send = Letter "Send" in
  [
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
      ~expected:[ "security-levels" ]
      (GradeRegistry.accepting (Grade.Name "High"));
    expect "registry: grades reading a pair of a time and a level" show_names
      ~expected:[ "time-lower-bound-levels"; "time-upper-bound-levels" ]
      (GradeRegistry.accepting (lit_of_pair 3 "High"));
    expect "registry: grades reading an open interval" show_names
      ~expected:[ "time-interval" ]
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
  ]

let () =
  let checks =
    levels @ products @ counterexamples @ literals @ tops @ registry
  in
  let failures = List.filter (fun c -> not c.passed) checks in
  List.iter (fun c -> Printf.printf "FAIL %s: %s\n" c.name c.detail) failures;
  Printf.printf "%d of %d checks passed\n"
    (List.length checks - List.length failures)
    (List.length checks);
  if failures <> [] then exit 1
