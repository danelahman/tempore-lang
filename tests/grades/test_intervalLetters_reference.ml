(* Tests of the reference decision of the order of the timed grades with
   interval letters on exact words: the two counterexamples to monotonicity of
   the earlier rigid orders, the verdicts on the transcribed rows of the
   prototype's tests of strict delays, upper and lower, open ends and the
   point rule. *)

open LawChecks
module R = IntervalLettersReference

let running_time = function
  | "H" -> R.point 2
  | "S" -> R.point 1
  | "C" -> R.closed 3 4
  | "L" | "O" | "K" | "R" | "A" -> R.point 1
  | "B" -> { R.lo = 0; lo_open = true; hi = Some 2; hi_open = false }
  | "P" -> { R.lo = 0; lo_open = true; hi = Some 1; hi_open = false }
  | name -> invalid_arg ("running_time: " ^ name)

(* [word ~side text] is the expression of the word [text] of operation names,
   delays [d] and strict delays [!d], each delay read as its hull on [side]. *)
let word ~upper text =
  let hull d = if upper then R.at_most d else R.at_least d in
  R.Seq
    (List.map
       (fun token ->
         if token.[0] = '!' then
           R.strict
             (hull
                (int_of_string (String.sub token 1 (String.length token - 1))))
         else
           match int_of_string_opt token with
           | Some d -> R.budget (hull d)
           | None -> R.op token)
       (String.split_on_char ' ' text))

(* [flanked text] is the lower word [text] with a stretch [≥0] before every
   letter other than a budget and at the end, merged into adjacent budgets. *)
let flanked text =
  let flank = R.budget R.unbounded in
  let letters =
    match word ~upper:false text with R.Seq ls -> ls | l -> [ l ]
  in
  let is_budget = function
    | R.Letter (R.Stretch (R.All, _)) -> true
    | _ -> false
  in
  let rec go previous_budget = function
    | [] -> if previous_budget then [] else [ flank ]
    | l :: rest when is_budget l -> l :: go true rest
    | l :: rest ->
        (if previous_budget then [] else [ flank ]) @ (l :: go false rest)
  in
  R.Seq (go false letters)

let leq x y = R.leq ~running_time x y

(* {1 The core} *)

module Grade = Grades.Grade
module Rat = Grades.Rational
module G = Grades.IntervalGrades

(* [to_regex ~grid e] is the brace-literal contents of [e], its lengths in
   units of [1/grid]. *)
let rec to_regex ~grid e =
  let q n = Rat.make n grid in
  let interval (iv : R.interval) =
    match iv with
    | { lo = 0; lo_open = false; hi = Some h; hi_open } ->
        Grade.Below (if hi_open then Grade.Open (q h) else Grade.Closed (q h))
    | { lo; lo_open; hi = None; _ } ->
        Grade.Above (if lo_open then Grade.Open (q lo) else Grade.Closed (q lo))
    | { lo; lo_open; hi = Some h; hi_open } ->
        Grade.Delays
          ( (if lo_open then Grade.Open (q lo) else Grade.Closed (q lo)),
            if hi_open then Grade.Open (q h) else Grade.Closed (q h) )
  in
  let fold f = function
    | [] -> Grade.Tick 0
    | x :: xs -> List.fold_left (fun acc x -> f acc x) x xs
  in
  match e with
  | R.Eps -> Grade.Tick 0
  | R.Empty -> Grade.Inter (Grade.Letter "A", Grade.Letter "B")
  | R.Letter (R.Op names) ->
      fold
        (fun a b -> Grade.Union (a, b))
        (List.map (fun n -> Grade.Letter n) names)
  | R.Letter (R.Stretch (R.Names [], iv)) -> Grade.Strict (interval iv)
  | R.Letter (R.Stretch (_, iv)) -> interval iv
  | R.Seq es ->
      fold (fun a b -> Grade.Seq (a, b)) (List.map (to_regex ~grid) es)
  | R.Alt es ->
      fold (fun a b -> Grade.Union (a, b)) (List.map (to_regex ~grid) es)
  | R.Rep (e, m, n) ->
      Grade.Repeat (to_regex ~grid e, Grades.Count.make m (Some n))

let operations = [ "A"; "B"; "C"; "H"; "K"; "L"; "O"; "P"; "R"; "S" ]

(* The running times of the reference, in units of [1/grid]. *)
let bounds_of ?(operations = operations) ~grid running_time =
  {
    Grade.running_time =
      (fun n ->
        let iv : R.interval = running_time n in
        let q v = Rat.make v grid in
        ( (if iv.lo_open then Grade.Open (q iv.lo) else Grade.Closed (q iv.lo)),
          match iv.hi with
          | Some h ->
              if iv.hi_open then Grade.Open (q h) else Grade.Closed (q h)
          | None -> invalid_arg "an unbounded running time" ));
    operations;
  }

(* [lower_side e] is whether [e] has a letter bounded below only, and
   [upper_side e] one bounded above. *)
let rec letters_of = function
  | R.Letter l -> [ l ]
  | R.Seq es | R.Alt es -> List.concat_map letters_of es
  | R.Rep (e, _, _) -> letters_of e
  | R.Eps | R.Empty -> []

let has_lower e =
  List.exists
    (function R.Stretch (_, { hi = None; _ }) -> true | _ -> false)
    (letters_of e)

(* The rejections whose counterexample is not one. *)
let bad_counterexamples = ref []

(* [core ~whole ~grid ~upper running_time x y] is the verdict of the core
   grade of the side on [x <= y]. *)
let core ?operations ~whole ~grid ~upper running_time x y =
  let bounds = bounds_of ?operations ~grid running_time in
  let lit e = Grade.Braces (to_regex ~grid e) in
  let decide (module M : Grade.S) =
    let x = M.of_lit (lit x) and y = M.of_lit (lit y) in
    let verdict = M.leq bounds x y in
    (if not verdict then
       match M.counterexample bounds x y with
       | Some e when M.leq bounds e x && not (M.leq bounds e y) -> ()
       | e ->
           bad_counterexamples :=
             (M.show x ^ " <= " ^ M.show y ^ ": "
             ^ match e with Some e -> M.show e | None -> "none")
             :: !bad_counterexamples);
    verdict
  in
  match (whole, upper) with
  | true, true -> decide (module G.Regex.Upper)
  | true, false -> decide (module G.Regex.Lower)
  | false, true -> decide (module G.RegexRational.Upper)
  | false, false -> decide (module G.RegexRational.Lower)

let verdict name x y expected =
  let label = name ^ ": " ^ R.show x ^ " <= " ^ R.show y in
  let sides =
    if has_lower x || has_lower y then [ false ] else [ true; false ]
  in
  let sides =
    if
      List.exists
        (function R.Stretch (_, { hi = Some _; _ }) -> true | _ -> false)
        (letters_of x @ letters_of y)
    then List.filter Fun.id sides
    else sides
  in
  expect label string_of_bool ~expected (leq x y)
  :: List.map
       (fun upper ->
         expect
           (label ^ " (core, " ^ (if upper then "upper" else "lower") ^ ")")
           string_of_bool ~expected
           (core ~whole:false ~grid:1 ~upper running_time x y))
       sides

let up = word ~upper:true
let low = word ~upper:false

let f4 =
  [
    verdict "upper premise" (up "1") (up "1") true;
    verdict "upper premise" (up "1") (up "!1 1") true;
    verdict "upper product" (up "1 1") (up "1 !1 1") true;
    verdict "lower premise" (low "1 !1") (low "1 !1") true;
    verdict "lower premise fails" (low "1 !1") (low "!1") false;
    verdict "lower product" (low "1 !1 1 !1") (low "1 !2") false;
  ]

(* The rows of the upper bounds, a program below a bound, with the verdicts of
   the design's upper instance. *)
let upper_rows =
  List.map
    (fun (name, p, b, expected) -> verdict name (up p) (up b) expected)
    [
      ("traces budget stir", "H !2 S C", "H 3 C", true);
      ("traces strict stir", "H !2 S C", "H !3 C", false);
      ("logged", "H L !2 C", "H 3 C", true);
      ("uncooled", "H !3", "H 3 C", false);
      ("kind", "!5", "5", true);
      ("kind", "5", "!5", false);
      ("strict and budget", "A !2 3", "A 5", true);
      ("strict and budget", "A 5", "A !2 3", false);
      ("too long a wait", "!3 A", "!1 1 A", false);
      ("wait into a budget", "!2 A", "!1 1 A", true);
      ("budget into a wait", "1 A", "!2 A", false);
      ("binding strict", "K !7 S R", "K !10 R", false);
      ("binding budget", "K !7 S R", "K 10 R", true);
      ("unused strict", "1", "!1 1", true);
      ("product", "1 1", "1 !1 1", true);
      ("operation across a strict delay", "B", "1 !1 1", true);
      ("wait across budgets", "!2", "1 1", true);
    ]

(* The rows of the lower bounds, a run below a guarantee given flanks, with
   the verdicts of the prototype's coverage order. *)
let lower_rows =
  List.map
    (fun (name, r, g, expected) -> verdict name (low r) (flanked g) expected)
    [
      ("stirred wait", "A C C B", "A !5 B", false);
      ("wait", "A !5 B", "A !5 B", true);
      ("longer wait", "A !6 B", "A !5 B", true);
      ("undisturbed", "A !2 C !3 B", "A !5 B", false);
      ("budget for a wait", "A 5 B", "A !5 B", false);
      ("operations for a budget", "A C C B", "A 5 B", true);
      ("operation for a budget", "A C !2 B", "A 1 !2 B", true);
      ("wait for a budget", "A !3 B", "A 1 !2 B", true);
      ("flank", "A !5 C B", "A !5 B", true);
      ("kind", "!5", "5", true);
      ("kind", "5", "!5", false);
      ("strict and budget", "A !2 3", "A 5", true);
      ("strict and budget", "A 5", "A !2 3", false);
      ("settled", "O !5 L", "O !5 L", true);
      ("stirred", "O C C L", "O !5 L", false);
      ("leading flank", "A !1", "!1", true);
    ]

(* Without flanks, a lower bound fixes its skeleton. *)
let unflanked =
  [
    verdict "no trailing flank" (low "A !5 C B") (low "A !5 B") false;
    verdict "no leading flank" (low "A !1") (low "!1") false;
    verdict "the unit is not the top" (low "A") R.Eps false;
    verdict "the top" (low "A !2 B 3") (R.budget R.unbounded) true;
  ]

let strict_open iv = R.strict iv
let budget_open iv = R.budget iv
let lt d = R.at_most ~open_:true d
let gt d = R.at_least ~open_:true d

(* Open ends: the lesser word approaches its ends more slowly than the greater
   one. *)
let open_ends =
  [
    verdict "open sum"
      (strict_open (lt 2))
      (R.Seq [ budget_open (lt 1); budget_open (lt 1) ])
      true;
    verdict "closed into open"
      (strict_open (R.at_most 2))
      (R.Seq [ budget_open (lt 1); budget_open (lt 1) ])
      false;
    verdict "closed into open and closed"
      (strict_open (R.at_most 2))
      (R.Seq [ budget_open (lt 1); budget_open (R.at_most 1) ])
      false;
    verdict "closed into closed"
      (strict_open (R.at_most 2))
      (R.Seq [ budget_open (R.at_most 1); budget_open (R.at_most 1) ])
      true;
    verdict "lower closed into open"
      (strict_open (R.at_least 2))
      (R.Seq [ strict_open (gt 1); strict_open (R.at_least 1) ])
      false;
    verdict "lower open into open"
      (strict_open (gt 2))
      (R.Seq [ strict_open (gt 1); strict_open (R.at_least 1) ])
      true;
    verdict "open running time" (R.op "P") (budget_open (lt 1)) false;
    verdict "open running time below its end" (R.op "P")
      (budget_open (R.at_most 1))
      true;
  ]

(* Running times are positive, open at 0 if need be: an operation occupies a
   positive stretch of a budget, never one of a strict wait, and a stretch of
   length 0 vanishes. *)
let positive =
  [
    verdict "in a budget" (R.op "P") (R.budget (R.at_most 1)) true;
    verdict "in the top" (R.op "P") (R.budget R.unbounded) true;
    verdict "not in a wait" (R.op "P") (R.strict (R.at_most 1)) false;
    verdict "not in no stretch" (R.op "P") R.Eps false;
    verdict "at the end of a budget"
      (R.Seq [ R.strict (R.point 1); R.op "P" ])
      (R.Seq [ R.strict (R.point 1); R.budget (R.at_most 1) ])
      true;
    verdict "between waits"
      (R.Seq [ R.strict (R.point 1); R.op "P"; R.strict (R.point 1) ])
      (R.strict (R.at_most 3))
      false;
    verdict "a budget of length 0 vanishes" (R.budget R.unbounded)
      (R.Alt [ R.Eps; R.budget (R.at_least 1) ])
      false;
    verdict "matched" (R.op "B") (R.op "B") true;
  ]

(* {1 Random cross-check}

   Small random star-free expressions on one side, the core against the
   reference, with a fixed seed: over whole steps with closed ends, and over
   halves with open ends. *)

let random_running_time ~whole = function
  | "A" -> if whole then R.point 1 else R.point 2
  | "B" ->
      if whole then R.closed 1 2
      else { R.lo = 0; lo_open = true; hi = Some 3; hi_open = false }
  | "C" ->
      if whole then R.closed 1 2
      else { R.lo = 1; lo_open = true; hi = Some 3; hi_open = false }
  | n -> invalid_arg n

let random_expr ~whole ~upper =
  let letter () =
    let d = Random.int 3 in
    let opened = (not whole) && Random.int 3 = 0 in
    let iv =
      if upper then R.at_most ~open_:opened (d + 1)
      else R.at_least ~open_:opened d
    in
    match Random.int 6 with
    | 0 -> R.op "A"
    | 1 -> R.op "B"
    | 2 -> R.op "C"
    | 3 -> R.strict iv
    | 4 -> R.budget iv
    | _ -> R.Letter (R.Op [ "A"; "B" ])
  in
  let rec expr depth =
    if depth = 0 then letter ()
    else
      match Random.int 5 with
      | 0 | 1 ->
          R.Seq (List.init (2 + Random.int 2) (fun _ -> expr (depth - 1)))
      | 2 -> R.Alt (List.init 2 (fun _ -> expr (depth - 1)))
      | 3 -> R.Rep (expr (depth - 1), Random.int 2, 2)
      | _ -> letter ()
  in
  expr (1 + Random.int 2)

(* [perturb ~whole ~upper x] is [x] with its stretches changed at random:
   another end, another kind, split in two, or flanked. *)
let rec perturb ~whole ~upper x =
  let iv () =
    let d = Random.int 3 in
    let opened = (not whole) && Random.int 3 = 0 in
    if upper then R.at_most ~open_:opened (d + 1)
    else R.at_least ~open_:opened d
  in
  match x with
  | R.Letter (R.Stretch (set, _)) -> (
      match Random.int 5 with
      | 0 -> R.Letter (R.Stretch (set, iv ()))
      | 1 -> R.budget (iv ())
      | 2 -> R.Seq [ R.Letter (R.Stretch (set, iv ())); R.budget (iv ()) ]
      | 3 -> R.Seq [ R.strict (iv ()); R.Letter (R.Stretch (set, iv ())) ]
      | _ -> x)
  | R.Letter (R.Op _) when Random.int 4 = 0 ->
      if upper then R.Seq [ x; R.budget (iv ()) ]
      else R.Seq [ R.budget R.unbounded; x; R.budget R.unbounded ]
  | R.Seq es -> R.Seq (List.map (perturb ~whole ~upper) es)
  | R.Alt es -> R.Alt (List.map (perturb ~whole ~upper) es)
  | R.Rep (e, m, n) -> R.Rep (perturb ~whole ~upper e, m, n)
  | x -> x

let cross_check ~whole ~upper n =
  let grid = if whole then 1 else 2 in
  let running_time = random_running_time ~whole in
  let failures = ref [] and agreed = ref 0 and accepted = ref 0 in
  for _ = 1 to n do
    let x = random_expr ~whole ~upper and y = random_expr ~whole ~upper in
    let y =
      match Random.int 4 with
      | 0 -> R.Seq [ x; y ]
      | 1 | 2 -> perturb ~whole ~upper x
      | _ -> y
    in
    let reference = R.leq ~dense:(not whole) ~running_time x y
    and core =
      core ~operations:[ "A"; "B"; "C" ] ~whole ~grid ~upper running_time x y
    in

    if reference = core then begin
      incr agreed;
      if reference then incr accepted
    end
    else failures := (x, y, reference) :: !failures
  done;
  let name =
    Printf.sprintf "cross-check %s %s (%d accepted)"
      (if whole then "whole" else "rational")
      (if upper then "upper" else "lower")
      !accepted
  in
  match !failures with
  | [] -> check name true ""
  | (x, y, reference) :: _ ->
      check name false
        (Printf.sprintf "%d disagreements, e.g. %s <= %s: reference %b"
           (List.length !failures) (R.show x) (R.show y) reference)

let cross_checks =
  Random.init 2026;
  [
    cross_check ~whole:true ~upper:true 10000;
    cross_check ~whole:true ~upper:false 10000;
    cross_check ~whole:false ~upper:true 10000;
    cross_check ~whole:false ~upper:false 10000;
  ]

let () =
  let checks =
    List.concat (f4 @ upper_rows @ lower_rows @ unflanked @ open_ends @ positive)
    @ cross_checks
    @ [
        check "counterexamples"
          (!bad_counterexamples = [])
          (String.concat "\n"
             (List.filteri (fun i _ -> i < 5) !bad_counterexamples));
      ]
  in

  let failures = List.filter (fun c -> not c.passed) checks in
  List.iter (fun c -> Printf.printf "FAIL %s: %s\n" c.name c.detail) failures;
  Printf.printf "%d of %d checks passed\n"
    (List.length checks - List.length failures)
    (List.length checks);
  if failures <> [] then exit 1
