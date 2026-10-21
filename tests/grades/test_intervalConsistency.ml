(* Tests of the run consistency of the intervals of the rigid grades of timed
   operations with interval letters: the verdicts and reasons on chosen
   literals, over whole time steps and rationals, with open ends, restricted
   budgets, repetitions and stars; random intervals against the reference
   by enumeration of runs, with the runs found checked by the reference; the
   preservation of consistency by the operations of the grades; and the
   counterexamples of the order. *)

open LawChecks
module R = IntervalLettersReference
module Grade = Grades.Grade
module Rat = Grades.Rational
module G = Grades.IntervalGrades
module C = Grades.IntervalConsistency

(* The interval grades, with their witnesses. *)
module type INTERVAL = sig
  include Grade.S

  val witness : Grade.bounds -> t -> C.item list option
end

let regex = (module G.Regex.Interval : INTERVAL)
let regex_rational = (module G.RegexRational.Interval : INTERVAL)
let traces = (module G.Traces.Interval : INTERVAL)
let traces_rational = (module G.TracesRational.Interval : INTERVAL)

module Reader (M : Grade.S) = struct
  module Grammar = Parser.Grammar.Make (Grades.GradeSystem.Identity (M))

  let parse text =
    let lexbuf = Lexing.from_string ("box " ^ text ^ " ()") in
    match Grammar.payload (Parser.Lexer.tokens ()) lexbuf with
    | { it = SugaredAst.GenBox ({ it = SugaredAst.GradeLit rho; _ }, _); _ } ->
        rho
    | _ -> failwith ("not a box of a literal: " ^ text)
    | exception Utils.Error.Error d ->
        failwith (text ^ ": " ^ d.Utils.Diagnostic.message)
end

(* [bounds table] is the running-time bounds of the operations of [table],
   each with its two ends. *)
let bounds table =
  {
    Grade.running_time = (fun o -> List.assoc o table);
    operations = List.map fst table;
  }

let closed a b = (Grade.Closed (Rat.of_int a), Grade.Closed (Rat.of_int b))

(* [verdict (module M) table text expected] checks the reason the literal
   [text] admits no run under the running times [table], [None] if it admits
   one. *)
let verdict (module M : INTERVAL) table text expected =
  let module P = Reader (M) in
  let show = function None -> "a run" | Some r -> r in
  expect
    (M.name ^ ": " ^ text)
    show ~expected
    (M.vacuous (bounds table) (P.parse text))

let common = Grade.no_common_run None
let because r = Some (Grade.no_common_run (Some r))

(* {1 Chosen literals} *)

let chosen =
  let a13 = [ ("A", closed 1 3) ] in
  let wr = [ ("Write", closed 2 3); ("Read", closed 1 1) ] in
  let ac = [ ("A", closed 1 1); ("B", closed 1 1); ("C", closed 3 4) ] in
  let both = [ regex; regex_rational; traces; traces_rational ] in
  let all text table expected =
    List.map (fun m -> verdict m table text expected) both
  in
  List.concat
    [
      (* F7: no run waits at least 5 and at most 2. *)
      all "[{!≥5}, {!≤2}]" []
        (because "its lower end lasts at least 5 and its upper end at most 2");
      all "[{!≥2}, {!≤2}]" [] None;
      (* A run performing A for 2, although A may run for 1. *)
      all "[{(≥2 & A)}, {A}]" a13 None;
      all "[{(≥2 & A)}, {A}]"
        [ ("A", closed 1 1) ]
        (because "its lower end lasts at least 2 and its upper end at most 1");
      all "[{(≥3 & A)}, {A}]" a13 None;
      all "[{(≥4 & A)}, {A}]" a13
        (because "its lower end lasts at least 4 and its upper end at most 3");
      (* A budget of the lower end pays for the operation of the upper end,
         a strict wait does not. *)
      all "[{2}, {Write}]" wr None;
      all "[{!2}, {Write}]" wr (Some common);
      all "[{Write}, {Read; Read; Read}]" wr (Some common);
      all "[{Write; ≥0}, {≤5}]" wr None;
      all "[{Write}, {Read; ≤2}]" wr (Some common);
      (* The window rule: an operation lies in stretches whose sets all
         contain it. *)
      all "[{C}, {(≤2 & C); (≤2 & (A | C))}]" ac None;
      all "[{C}, {(≤2 & C); (≤2 & A)}]" ac (Some common);
      all "[{C}, {(≤4 & C); (≤2 & A)}]" ac None;
      all "[{(≥1 & ~C); C}, {(≤5 & ~C); C}]" ac None;
      all "[{(≥1 & C); A}, {(≤5 & ~C); A}]" ac None;
      all "[{C; A}, {(≤5 & ~C); A}]" ac (Some common);
      all "[{(≥0 & C); A}, {(≤5 & ~C); A}]" ac None;
      (* Matched operations meet the stretches of both ends. *)
      all "[{!≥1; A; ≥0}, {!≤1; A; ≤5}]" ac None;
      all "[{!≥2; A; ≥0}, {!≤1; A; ≤5}]" ac (Some common);
      all "[{A; B}, {B; A}]" ac (Some common);
      all "[{A; ≥0; B}, {≤3; B}]" ac None;
      (* Stars and repetitions. *)
      List.map
        (fun m ->
          verdict m [ ("Read", closed 1 2) ] "[{(1; Read)*}, {(2; Read)*}]" None)
        [ regex; regex_rational ];
      List.map
        (fun m ->
          verdict m ac "[{(!≥3; A); (!≥3; A)*}, {(!≤2; A)*}]" (Some common))
        [ regex; regex_rational ];
      List.map
        (fun m -> verdict m ac "[{(!≥3; A)*}, {(!≤2; A)*}]" None)
        [ regex; regex_rational ];
      List.map
        (fun m -> verdict m ac "[{(!≥3; A); (!≥3; A)*}, {(!≤2; A | ≤5)*}]" None)
        [ regex; regex_rational ];
      all "[{(!≥2; A)^3}, {(!≤2; A)^[2, 3]}]" ac None;
      all "[{(!≥3; A)^2}, {(!≤2; A)^[2, 3]}]" ac (Some common);
      all "[{(!≥1; A)^[2, 3]}, {(!≤1; A)^3}]" ac None;
      all "[{A^4}, {(A | B)^[1, 3]; ≤1}]" ac None;
      all "[{A^4}, {(A | B)^[1, 2]; ≤1}]" ac
        (because "its lower end lasts at least 4 and its upper end at most 3");
      all "[{A^4}, {(A | B)^[1, 2]; (≤2 & B)}]" ac (Some common);
      (* The examples of the robots. *)
      List.map
        (fun m ->
          verdict m
            [ ("ReadImu", closed 1 1) ]
            "[{≥100}, {(!≤10.5; ReadImu)^10}]" None)
        [ regex_rational; traces_rational ];
      List.map
        (fun m ->
          verdict m
            [ ("Move", closed 1 1) ]
            "[{(≥1000 & ~Move)}, {(≤600000 & ~Move)}]" None)
        both;
      List.map
        (fun m ->
          verdict m
            [ ("ReadImu", closed 1 1); ("ReadClock", closed 1 1) ]
            "[{(≥0; ReadImu; ReadClock)^3; ≥0}, {(≤2.5; ReadImu; ReadClock)*}]"
            None)
        [ regex_rational ];
    ]

(* Open ends and rational lengths: decided exactly over the rationals, and
   closed inward over whole steps. *)
let open_ends =
  let a = [ ("A", closed 1 1); ("B", closed 1 1) ] in
  let a_open =
    [ ("A", (Grade.Closed (Rat.of_int 1), Grade.Open (Rat.of_int 2))) ]
  in
  [
    verdict regex_rational [] "[{!>2}, {!≤2}]"
      (because "its lower end lasts more than 2 and its upper end at most 2");
    verdict regex_rational [] "[{!≥2}, {!<2}]"
      (because "its lower end lasts at least 2 and its upper end less than 2");
    verdict regex_rational a "[{!>1; A; ≥0}, {!<2; A; ≤5}]" None;
    verdict regex a "[{!>1; A; ≥0}, {!<2; A; ≤5}]" (Some common);
    verdict regex_rational a "[{!>1; A}, {!<2; A}]" None;
    verdict traces_rational a "[{!>1; A}, {!<2; A}]" None;
    verdict regex a "[{!>1; A}, {!<2; A}]"
      (because "its lower end lasts at least 3 and its upper end at most 2");
    verdict regex_rational a "[{!≥1/2; A; !>1/2}, {!≤1/2; A; !<1}]" None;
    verdict regex_rational a "[{!≥1/2; A; !≥1}, {!≤1/2; A; !<1; ≤1}]" None;
    verdict regex_rational a "[{!≥1/2; A; !≥1; B}, {!≤1/2; A; !<1; B}]"
      (because
         "its lower end lasts at least 3.5 and its upper end less than 3.5");
    verdict regex_rational a "[{!≥1/2; A; !≥1; B}, {!≤1/2; A; !<1; ≤2}]" None;
    verdict regex_rational a "[{!≥1/2; A; !≥1; B}, {!≤1/2; A; !<1; (≤2 & A)}]"
      (Some common);
    verdict regex_rational a_open "[{(≥2 & A)}, {A}]"
      (because "its lower end lasts at least 2 and its upper end less than 2");
    verdict regex_rational a_open "[{(>1 & A)}, {A}]" None;
    verdict regex a_open "[{(>1 & A)}, {A}]"
      (because "its lower end lasts at least 2 and its upper end at most 1");
  ]

(* {1 Random intervals against the reference} *)

let letter_set () =
  R.Names
    (List.nth [ [ "A" ]; [ "C" ]; [ "A"; "B" ]; [ "B"; "C" ] ] (Random.int 4))

(* [random_side ~whole ~upper ~size] is a random star-free expression of one
   side, of about [size] letters. *)
let random_side ~whole ~upper ~size =
  let letter () =
    let d = Random.int 3 in
    let opened = (not whole) && Random.int 3 = 0 in
    let iv =
      if upper then R.at_most ~open_:opened (max d 1)
      else R.at_least ~open_:opened d
    in
    match Random.int 7 with
    | 0 -> R.op "A"
    | 1 -> R.op "B"
    | 2 -> R.op "C"
    | 3 -> R.strict iv
    | 4 -> R.budget iv
    | _ -> R.Letter (R.Stretch (letter_set (), iv))
  in
  let rec expr size =
    if size <= 1 then letter ()
    else
      match Random.int 4 with
      | 0 -> R.Alt [ expr (size - 1); expr (size - 1) ]
      | 1 -> R.Rep (letter (), Random.int 2, 2)
      | _ -> R.Seq [ letter (); expr (size - 1) ]
  in
  expr size

let random_running_time ~whole = function
  | "A" -> R.point 1
  | "B" ->
      if whole then R.closed 1 2
      else { R.lo = 0; lo_open = true; hi = Some 2; hi_open = false }
  | "C" ->
      if whole then R.closed 2 2
      else { R.lo = 1; lo_open = true; hi = Some 2; hi_open = true }
  | n -> invalid_arg n

(* [to_regex e] is the brace-literal contents of the reference expression
   [e], its lengths in base units. *)
let rec to_regex e =
  let q = Rat.of_int in
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
  let fold = function
    | [] -> Grade.Tick 0
    | x :: xs -> List.fold_left (fun a b -> Grade.Union (a, b)) x xs
  in
  let seq = function
    | [] -> Grade.Tick 0
    | x :: xs -> List.fold_left (fun a b -> Grade.Seq (a, b)) x xs
  in
  match e with
  | R.Eps -> Grade.Tick 0
  | R.Empty -> Grade.Inter (Grade.Letter "A", Grade.Letter "B")
  | R.Letter (R.Op names) -> fold (List.map (fun n -> Grade.Letter n) names)
  | R.Letter (R.Stretch (R.Names [], iv)) -> Grade.Strict (interval iv)
  | R.Letter (R.Stretch (R.All, iv)) -> interval iv
  | R.Letter (R.Stretch (R.Names names, iv)) ->
      Grade.Inter (interval iv, fold (List.map (fun n -> Grade.Letter n) names))
  | R.Seq es -> seq (List.map to_regex es)
  | R.Alt es -> fold (List.map to_regex es)
  | R.Rep (e, m, n) -> Grade.Repeat (to_regex e, Grades.Count.make m (Some n))

let bounds_of running_time =
  bounds
    (List.map
       (fun n ->
         let iv : R.interval = running_time n in
         let q = Rat.of_int in
         ( n,
           ( (if iv.lo_open then Grade.Open (q iv.lo) else Grade.Closed (q iv.lo)),
             match iv.hi with
             | Some h ->
                 if iv.hi_open then Grade.Open (q h) else Grade.Closed (q h)
             | None -> Grade.Unbounded ) ))
       [ "A"; "B"; "C" ])

let interval_lit x y =
  Grade.Interval
    ( Grade.Closed (Grade.Braces (to_regex x)),
      Grade.Closed (Grade.Braces (to_regex y)) )

(* [denominator items] is the least common multiple of the denominators of
   the lengths of [items]. *)
let denominator items =
  let rec gcd a b = if b = 0 then a else gcd b (a mod b) in
  List.fold_left
    (fun k i ->
      let d =
        Rat.denominator (match i with C.Op (_, t) -> t | C.Wait t -> t)
      in
      k * d / gcd k d)
    1 items

(* [in_units k q] is [q] in units of [1/k]. *)
let in_units k q = Option.get (Rat.to_int (Rat.mul q (Rat.of_int k)))

(* [fits ~running_time x y run] is whether the run [run] has its operations
   within their running times and fits a word of [x] and a word of [y], by
   the reference on a grid finer than that of [run] by more than the number
   of the items and letters. *)
let fits ~running_time x y run =
  let longest e =
    List.fold_left (fun a w -> max a (List.length w)) 0 (R.skeletons e)
  in
  let k = denominator run * (List.length run + longest x + longest y + 1) in
  let items =
    List.map
      (function
        | C.Op (n, t) -> R.IOp (n, in_units k t)
        | C.Wait t -> R.IWait (in_units k t))
      run
  in
  let within = function
    | R.IOp (n, t) -> (
        let iv : R.interval = running_time n in
        t > 0
        && (t > iv.lo * k || ((not iv.lo_open) && t = iv.lo * k))
        &&
        match iv.hi with
        | Some h -> t < h * k || ((not iv.hi_open) && t = h * k)
        | None -> true)
    | _ -> true
  in
  List.for_all within items && R.admits ~k x items && R.admits ~k y items

let show_run run =
  String.concat "; "
    (List.map
       (function
         | C.Op (n, t) -> n ^ "@" ^ Rat.show t | C.Wait t -> "!" ^ Rat.show t)
       run)

(* [cross_check ~whole ~size ~traces n] compares the verdicts on [n] random
   intervals with the reference, checks the runs found against it, and the
   preservation of consistency on the consistent ones; [traces] for the
   finite families. *)
let cross_check ~whole ~size ~traces n =
  let (module M : INTERVAL) =
    match (whole, traces) with
    | true, false -> regex
    | false, false -> regex_rational
    | true, true -> (module G.Traces.Interval : INTERVAL)
    | false, true -> traces_rational
  in
  let running_time = random_running_time ~whole in
  let bounds = bounds_of running_time in
  let failures = ref [] and consistent = ref 0 and decided = ref [] in
  for _ = 1 to n do
    let x = random_side ~whole ~upper:false ~size
    and y = random_side ~whole ~upper:true ~size in
    match M.of_lit (interval_lit x y) with
    | exception Grade.Invalid_literal _ -> ()
    | rho ->
        let verdict = M.inhabited bounds rho
        and reference = R.consistent ~dense:(not whole) ~running_time x y in
        let run = if verdict then M.witness bounds rho else None in
        let label = R.show x ^ ", " ^ R.show y in
        if verdict <> reference then
          failures :=
            Printf.sprintf "[%s]: reference %b" label reference :: !failures
        else if verdict then begin
          incr consistent;
          decided := rho :: !decided;
          match run with
          | Some run when fits ~running_time x y run -> ()
          | Some run ->
              failures :=
                Printf.sprintf "[%s]: run %s fits not" label (show_run run)
                :: !failures
          | None -> failures := Printf.sprintf "[%s]: no run" label :: !failures
        end
  done;
  let name =
    Printf.sprintf "%s: random intervals of size %d (%d consistent of %d)"
      M.name size !consistent n
  in
  (match !failures with
  | [] -> check name true ""
  | f :: _ ->
      check name false
        (Printf.sprintf "%d failures, e.g. %s" (List.length !failures) f))
  :: consistency_laws
       (module M)
       ~context:"A:[1, 1], B:[1, 2] or (0, 2], C:[2, 2] or (1, 2)" bounds
       !decided

(* {1 Stars} *)

(* [starred ~whole n] checks on [n] random intervals that replacing a bounded
   repetition [r^[m, 2]] of each end by [r*] only adds runs. *)
let starred ~whole n =
  let (module M : INTERVAL) = if whole then regex else regex_rational in
  let bounds = bounds_of (random_running_time ~whole) in
  let rec star = function
    | Grade.Repeat (r, _) -> Grade.Star (star r)
    | Grade.Seq (r, s) -> Grade.Seq (star r, star s)
    | Grade.Union (r, s) -> Grade.Union (star r, star s)
    | Grade.Inter (r, s) -> Grade.Inter (star r, star s)
    | r -> r
  in
  let failures = ref [] in
  for _ = 1 to n do
    let x = to_regex (random_side ~whole ~upper:false ~size:3)
    and y = to_regex (random_side ~whole ~upper:true ~size:3) in
    let lit x y =
      Grade.Interval
        (Grade.Closed (Grade.Braces x), Grade.Closed (Grade.Braces y))
    in
    match (M.of_lit (lit x y), M.of_lit (lit (star x) (star y))) with
    | exception Grade.Invalid_literal _ -> ()
    | rho, rho' ->
        if M.inhabited bounds rho && not (M.inhabited bounds rho') then
          failures := (M.show rho ^ " and " ^ M.show rho') :: !failures
  done;
  all (M.name ^ ": a star adds runs") Fun.id (fun _ -> false) !failures

(* {1 Counterexamples} *)

(* The counterexample of an order failing on the lower end is the word of the
   lesser lower end with the lesser upper end, if a run meets both, and the
   lesser grade itself otherwise. *)
let counterexamples =
  let (module M : INTERVAL) = regex in
  let module P = Reader (M) in
  let b = bounds [ ("A", closed 1 2) ] in
  let show = function None -> "none" | Some e -> M.show e in
  let fallback = P.parse "[{A | !≥5}, {A}]" in
  [
    expect
      (M.name
     ^ ": a counterexample admitting no run falls back to the lesser grade")
      Fun.id ~expected:(M.show fallback)
      (show (M.counterexample b fallback (P.parse "[{A}, {A}]")));
    check
      (M.name ^ ": the lesser grade is consistent")
      (M.inhabited b fallback) "";
    expect
      (M.name ^ ": a counterexample admitting a run")
      Fun.id ~expected:"[{!≥5}, {≤5}]"
      (show
         (M.counterexample b
            (P.parse "[{A | !≥5}, {≤5}]")
            (P.parse "[{A}, {≤5}]")));
  ]

let () =
  Random.init 2026;
  let whole = cross_check ~whole:true ~size:4 ~traces:false 400 in
  let whole_traces = cross_check ~whole:true ~size:3 ~traces:true 500 in
  let rational = cross_check ~whole:false ~size:2 ~traces:false 100 in
  let rational_traces = cross_check ~whole:false ~size:2 ~traces:true 100 in
  let cross = [ whole; whole_traces; rational; rational_traces ] in
  let checks =
    chosen @ open_ends @ List.concat cross
    @ [ starred ~whole:true 300; starred ~whole:false 300 ]
    @ counterexamples
  in
  let failures = List.filter (fun c -> not c.passed) checks in
  List.iter (fun c -> Printf.printf "FAIL %s: %s\n" c.name c.detail) failures;
  Printf.printf "%d of %d checks passed\n"
    (List.length checks - List.length failures)
    (List.length checks);
  if failures <> [] then exit 1
