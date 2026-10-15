(* Tests of the strict delays of the rigid grades of timed operations: the
   finite-trace recursions of the rigid allowance order and of coverage with
   strict delays against an exhaustive search of the splittings of the traces
   in unit steps; the agreement of the visible rigid grades, over finite sets
   of traces, by whole steps and over rational delays, with mixed kinds of
   delays; the conservativity of the rigid lower bounds; the order of the
   kinds; specifications of sampling, washing and polling side by side with
   their budget forms; coverage of strict demands; complements; printing; and
   the rejection of strict delays outside the rigid grades. *)

module Grade = Grades.Grade
module Rational = Grades.Rational
module Trace = Grades.TimedTrace.Make (Grades.Delay.Nat)
module TimedTraceGrades = Grades.TimedTraceGrades
module Whole = Grades.RegularTimedTraceGrades
module Rat = Grades.RegularTimedTraceGradesRational
open LawChecks

(* {1 Literals} *)

module Reader (G : Grade.S) = struct
  module Grammar = Parser.Grammar.Make (Grades.GradeSystem.Identity (G))

  let parse text =
    let lexbuf = Lexing.from_string ("box " ^ text ^ " ()") in
    match Grammar.payload (Parser.Lexer.tokens ()) lexbuf with
    | { it = SugaredAst.GenBox ({ it = SugaredAst.GradeLit rho; _ }, _); _ } ->
        rho
    | _ -> invalid_arg ("not a box of a literal: " ^ text)

  (* [lit text] is the grade of [text]. *)
  let lit text =
    match parse text with
    | rho -> rho
    | exception Utils.Error.Error d ->
        failwith (G.name ^ ": " ^ text ^ ": " ^ d.Utils.Diagnostic.message)

  (* [read text] is the grade of [text], or the reason it is rejected. *)
  let read text =
    match parse text with
    | rho -> Ok rho
    | exception Grade.Invalid_literal (_, reason) -> Error reason
    | exception Utils.Error.Error d -> Error d.Utils.Diagnostic.message
end

(* The running times of the operations, each given by its ends. *)
let bounds_of table =
  {
    Grade.running_time =
      (fun o ->
        let lo, hi = List.assoc o table in
        (Grade.Closed lo, Grade.Closed hi));
    operations = List.map fst table;
  }

let q = Rational.of_int
let qf n d = Rational.make n d

(* {1 The recursions against an exhaustive search} *)

(* A trace over whole steps, its strict delays unrolled into unit steps. *)
type item = Op of string | Budget of int | Unit

(* A bound in pieces: operations and the delays between them, every gap
   holding at least one delay, a budget delay of [0] standing for none. *)
type element = Match of string | Piece of bool * int

let items trace =
  List.concat_map
    (function
      | Trace.Ev o -> [ Op o ]
      | Trace.Wait d -> [ Budget d ]
      | Trace.Strict d -> List.init d (Fun.const Unit))
    trace

let elements trace =
  let rec go acc = function
    | [] -> List.rev acc
    | Trace.Ev o :: rest -> go (Match o :: acc) rest
    | ((Trace.Wait d | Trace.Strict d) as e) :: rest ->
        go
          (Piece ((match e with Trace.Strict _ -> true | _ -> false), d)
          :: acc)
          rest
  in
  (* A gap without a budget delay next to an operation, or at either end, has
     one of length [0] there: a strict delay is flanked by budget delays. *)
  let budget = function Piece (false, _) -> true | _ -> false in
  let rec flank = function
    | (Match _ as m) :: rest -> m :: flank_after rest
    | x :: rest -> x :: flank rest
    | [] -> []
  and flank_after = function
    | x :: rest when budget x -> x :: flank rest
    | rest -> Piece (false, 0) :: flank rest
  in
  let es = flank_after (go [] trace) in
  let rev = List.rev es in
  let rec close = function
    | (Match _ as m) :: rest -> m :: close_before rest
    | x :: rest -> x :: close rest
    | [] -> []
  and close_before = function
    | x :: rest when budget x -> x :: close rest
    | rest -> Piece (false, 0) :: close rest
  in
  List.rev (close_before (close rev))

(* [search_allowance hi w s] is whether the bound [s] permits the trace [w],
   every item of [w] placed in a delay of [s] or matched, in order. *)
let search_allowance hi w s =
  let w = Array.of_list (items w) and s = Array.of_list (elements s) in
  let rec go i j rem =
    let advance () =
      j + 1 < Array.length s
      &&
      match s.(j + 1) with
      | Piece (_, e) -> go i (j + 1) e
      | Match a -> (
          i < Array.length w
          && w.(i) = Op a
          && j + 2 < Array.length s
          &&
          match s.(j + 2) with
          | Piece (_, e) -> go (i + 1) (j + 2) e
          | _ -> false)
    in
    let strict = match s.(j) with Piece (k, _) -> k | Match _ -> false in
    i = Array.length w
    && Array.for_all
         (function Piece _ -> true | Match _ -> false)
         (Array.sub s (j + 1) (Array.length s - j - 1))
    || advance ()
    || i < Array.length w
       &&
       match w.(i) with
       | Unit -> rem >= 1 && go (i + 1) j (rem - 1)
       | Budget d -> (not strict) && d <= rem && go (i + 1) j (rem - d)
       | Op a -> (not strict) && hi a <= rem && go (i + 1) j (rem - hi a)
  in
  match s.(0) with Piece (_, e) -> go 0 0 e | Match _ -> false

(* [search_coverage lo s w] is whether the trace [w] covers the guarantee
   [s]. *)
let search_coverage lo s w =
  let w = Array.of_list (items w) and s = Array.of_list (elements s) in
  let demand j = match s.(j) with Piece (_, e) -> e | Match _ -> 0 in
  let rec go i j have =
    let met = have >= demand j in
    let advance () =
      met
      && j + 1 < Array.length s
      &&
      match s.(j + 1) with
      | Piece _ -> go i (j + 1) 0
      | Match a ->
          i < Array.length w
          && w.(i) = Op a
          && j + 2 < Array.length s
          && go (i + 1) (j + 2) 0
    in
    let strict = match s.(j) with Piece (k, _) -> k | Match _ -> false in
    i = Array.length w
    && met
    && Array.for_all
         (function Piece (_, e) -> e = 0 | Match _ -> false)
         (Array.sub s (j + 1) (Array.length s - j - 1))
    || advance ()
    || i < Array.length w
       &&
       match w.(i) with
       | Unit -> go (i + 1) j (have + 1)
       | Budget d -> (not strict) && go (i + 1) j (have + d)
       | Op a -> (not strict) && go (i + 1) j (have + lo a)
  in
  go 0 0 0

let hi = function "A" -> 2 | _ -> 1
let lo = function "A" -> 1 | _ -> 0

let random_trace state =
  Trace.normalise
    (List.init (Random.State.int state 5) (fun _ ->
         match Random.State.int state 4 with
         | 0 -> Trace.Ev (if Random.State.bool state then "A" else "B")
         | 1 -> Trace.Wait (Random.State.int state 4)
         | _ -> Trace.Strict (1 + Random.State.int state 3)))

let show_trace t = Trace.show [ t ]

let recursions =
  let state = Random.State.make [| 12 |] in
  let pairs =
    List.init 3000 (fun _ -> (random_trace state, random_trace state))
  in
  let show (s, t) = show_trace s ^ " against " ^ show_trace t in
  [
    all "rigid allowance with strict delays agrees with the search" show
      (fun (s, t) ->
        Trace.allowance ~rigid:true hi 0 s t = search_allowance hi s t)
      pairs;
    all "coverage with strict delays agrees with the search" show
      (fun (s, t) -> Trace.coverage lo 0 s t = search_coverage lo s t)
      pairs;
  ]

(* {1 The visible grades against the recursions} *)

(* [literal ~scale ts] is the brace literal of the traces [ts], their delays
   divided by [scale]. *)
let literal ~scale ts =
  let delay d = Rational.show (Rational.make d scale) in
  let event = function
    | Trace.Ev o -> o
    | Trace.Wait d -> delay d
    | Trace.Strict d -> "!" ^ delay d
  in
  let trace = function
    | [] -> "0"
    | t -> String.concat "; " (List.map event t)
  in
  "{" ^ String.concat " | " (List.map trace ts) ^ "}"

(* [agreement ~scale grades] checks that the grades [grades] order the
   literals of random finite sets of traces alike, their delays divided by
   [scale], with the running times [hi] and [lo] divided likewise. *)
let agreement ~scale name grades =
  let state = Random.State.make [| 34; scale |] in
  let bounds =
    bounds_of
      [
        ("A", (Rational.make 1 scale, Rational.make 2 scale));
        ("B", (Rational.zero, Rational.make 1 scale));
      ]
  in
  let sets =
    List.init 400 (fun _ ->
        ( literal ~scale
            (List.init
               (1 + Random.State.int state 2)
               (fun _ -> random_trace state)),
          literal ~scale
            (List.init
               (1 + Random.State.int state 2)
               (fun _ -> random_trace state)) ))
  in
  let verdicts (module G : Grade.S) =
    let module R = Reader (G) in
    List.map (fun (a, b) -> G.leq bounds (R.lit a) (R.lit b)) sets
  in
  match List.map verdicts grades with
  | [] -> []
  | reference :: others ->
      List.mapi
        (fun k found ->
          let disagreement =
            List.find_opt
              (fun ((x, y), _) -> x <> y)
              (List.combine (List.combine reference found) sets)
          in
          check
            (Printf.sprintf "%s: implementation %d agrees with the traces" name
               (k + 1))
            (Option.is_none disagreement)
            (match disagreement with
            | Some (_, (a, b)) -> a ^ " <= " ^ b
            | None -> ""))
        others

let grades_agree =
  agreement ~scale:1 "whole steps, upper bounds"
    [
      (module TimedTraceGrades.Rigid.UpperBound);
      (module Whole.Symbolic.Rigid.Upper);
      (module Rat.Rigid.Upper);
    ]
  @ agreement ~scale:1 "whole steps, lower bounds"
      [
        (module TimedTraceGrades.Rigid.LowerBound);
        (module Whole.Symbolic.Rigid.Lower);
        (module Rat.Rigid.Lower);
      ]
  @ agreement ~scale:2 "halves, upper bounds"
      [
        (module TimedTraceGrades.Rational.Rigid.UpperBound);
        (module Rat.Rigid.Upper);
      ]
  @ agreement ~scale:2 "halves, lower bounds"
      [
        (module TimedTraceGrades.Rational.Rigid.LowerBound);
        (module Rat.Rigid.Lower);
      ]

(* The rigid lower bounds agree with the lower bounds on grades without strict
   delays. *)
let conservative =
  let state = Random.State.make [| 56 |] in
  let plain () =
    Trace.normalise
      (List.init (Random.State.int state 5) (fun _ ->
           match Random.State.int state 3 with
           | 0 -> Trace.Ev (if Random.State.bool state then "A" else "B")
           | _ -> Trace.Wait (Random.State.int state 4)))
  in
  let sets =
    List.init 300 (fun _ ->
        ( literal ~scale:1
            (List.init (1 + Random.State.int state 2) (fun _ -> plain ())),
          literal ~scale:1
            (List.init (1 + Random.State.int state 2) (fun _ -> plain ())) ))
  in
  let bounds = bounds_of [ ("A", (q 1, q 2)); ("B", (q 0, q 1)) ] in
  let same name (module F : Grade.S) (module G : Grade.S) =
    let module RF = Reader (F) in
    let module RG = Reader (G) in
    all name
      (fun (a, b) -> a ^ " <= " ^ b)
      (fun (a, b) ->
        F.leq bounds (RF.lit a) (RF.lit b) = G.leq bounds (RG.lit a) (RG.lit b))
      sets
  in
  [
    same "traces: rigid lower bounds without strict delays are lower bounds"
      (module TimedTraceGrades.LowerBound)
      (module TimedTraceGrades.Rigid.LowerBound);
    same "regex: rigid lower bounds without strict delays are lower bounds"
      (module Whole.Symbolic.Lower)
      (module Whole.Symbolic.Rigid.Lower);
    same "rational: rigid lower bounds without strict delays are lower bounds"
      (module Rat.Lower)
      (module Rat.Rigid.Lower);
  ]

(* {1 Examples} *)

(* [verdicts (module G) bounds cases] checks each comparison [(a, b, expected)]
   of literals of [G] under [bounds]. *)
let verdicts (module G : Grade.S) bounds cases =
  let module R = Reader (G) in
  List.concat_map
    (fun (a, b, expected) ->
      let x = R.lit a and y = R.lit b in
      let found = G.leq bounds x y in
      check
        (Printf.sprintf "%s: %s <= %s is %b" G.name a b expected)
        (found = expected)
        (Printf.sprintf "found %b" found)
      ::
      (if expected then []
       else
         match G.counterexample bounds x y with
         | None -> []
         | Some c ->
             [
               check
                 (Printf.sprintf "%s: the counterexample %s to %s <= %s" G.name
                    (G.show c) a b)
                 (G.leq bounds c x && not (G.leq bounds c y))
                 "";
             ]))
    cases

let on_all grades bounds cases =
  List.concat_map (fun g -> verdicts g bounds cases) grades

(* The kinds: a strict delay is below a budget delay of the same length, not
   conversely, as an upper and as a lower bound. *)
let kinds =
  let bounds = bounds_of [ ("A", (q 1, q 1)) ] in
  on_all
    [
      (module Rat.Rigid.Upper);
      (module Rat.Rigid.Lower);
      (module Whole.Symbolic.Rigid.Upper);
      (module Whole.Symbolic.Rigid.Lower);
      (module TimedTraceGrades.Rigid.UpperBound);
      (module TimedTraceGrades.Rigid.LowerBound);
    ]
    bounds
    [
      ("{!5}", "{5}", true);
      ("{5}", "{!5}", false);
      ("{A; !2; 3}", "{A; 5}", true);
      ("{A; 5}", "{A; !2; 3}", false);
    ]

(* The specifications of design note §12.4: each program trace is permitted by
   the budget form of the bound and not by its strict form. *)
let specifications =
  let on_regex table program budget strict =
    on_all
      [ (module Rat.Rigid.Upper); (module Rat.Rigid.Interval) ]
      (bounds_of table)
      [ (program, budget, true); (program, strict, false) ]
  in
  let exact name t = (name, (t, t)) in
  on_regex
    [ exact "AddBeads" (q 1); exact "ChangeTip" (q 1); exact "MagnetOn" (q 1) ]
    "{AddBeads; !7; ChangeTip; MagnetOn}" "{AddBeads; [5, 10]; MagnetOn}"
    "{AddBeads; ![5, 10]; MagnetOn}"
  @ on_regex
      [ exact "Wash" (q 1); exact "ChangeTip" (q 1) ]
      "{Wash; !2; ChangeTip; ChangeTip}"
      "{(Wash; ChangeTip)*; Wash; [2, 3]; ChangeTip}"
      "{(Wash; ChangeTip)*; Wash; ![2, 3]; ChangeTip}"
  @ on_regex
      [
        exact "AddBeads" (q 1);
        exact "Mix" (q 1);
        exact "Move" (qf 1 2);
        exact "MagnetOn" (q 1);
      ]
      "{AddBeads; !2; Move; Mix; !5/2; MagnetOn}"
      "{AddBeads; ([2, 3]; Mix)*; [2, 3]; MagnetOn}"
      "{AddBeads; (![2, 3]; Mix)*; ![2, 3]; MagnetOn}"
  @ on_regex
      [
        exact "AddEthanol" (q 1);
        exact "ChangeTip" (qf 1 4);
        exact "RemoveEthanol" (q 1);
      ]
      "{AddEthanol; !1; ChangeTip; RemoveEthanol}"
      "{AddEthanol; [1/2, 3/2]; RemoveEthanol}"
      "{AddEthanol; ![1/2, 3/2]; RemoveEthanol}"
  @ on_regex
      [ exact "MagnetOn" (q 1); exact "Mix" (q 1) ]
      "{!3; MagnetOn; !3; Mix}" "{[2, 5]; MagnetOn; [2, 5]}"
      "{[2, 5]; MagnetOn; ![2, 5]}"
  @ on_regex
      [ exact "Attitude" (qf 1 10); ("Motor", (qf 1 10, qf 45 100)) ]
      "{Attitude; !10; Motor; Attitude; !10}" "{(Attitude; [9.5, 10.5])*}"
      "{(Attitude; ![9.5, 10.5])*}"
  @ on_regex
      [ ("SetMotors", (qf 1 10, qf 1 2)); exact "ReadEncoders" (qf 1 10) ]
      "{SetMotors; !20; SetMotors; ReadEncoders}"
      "{SetMotors; ([19, 21]; ReadEncoders)*}"
      "{SetMotors; (![19, 21]; ReadEncoders)*}"
  @ on_regex
      [ exact "ReadTouch" (qf 1 10); ("ConfigureImu", (qf 1 10, qf 4 10)) ]
      "{ReadTouch; !50; ConfigureImu; ReadTouch; !50}"
      "{(ReadTouch; [49, 51])*}" "{(ReadTouch; ![49, 51])*}"
  @ on_regex
      [
        exact "Beep" (qf 1 10);
        ("ReadClock", (q 0, qf 5 100));
        ("ReadImu", (qf 2 10, qf 15 10));
      ]
      "{Beep; ReadClock; !1; ReadClock; ReadImu; ReadClock}"
      "{Beep; ReadClock; ([0, 2.5]; ReadImu; ReadClock)*}"
      "{Beep; ReadClock; (![0, 2.5]; ReadImu; ReadClock)*}"
  @ on_regex
      [ ("ReadImu", (qf 2 10, qf 15 10)); ("Tone", (qf 1 10, qf 1 10)) ]
      "{!10; Tone; ReadImu}" "{([9.5, 10.5]; ReadImu)*}"
      "{(![9.5, 10.5]; ReadImu)*}"

(* Open sets of strict delays: a strict delay of a word may be divided among
   consecutive strict delays of a bound, each approached, not attained. *)
let open_sets =
  let bounds = bounds_of [ ("A", (q 1, q 1)) ] in
  verdicts
    (module Rat.Rigid.Upper)
    bounds
    [
      ("{!1}", "{![0, 1)}", false);
      ("{!0.5}", "{![0, 1)}", true);
      ("{![0, 1)}", "{!1}", true);
      ("{![0, 1)}", "{!0.99}", false);
      ("{!2}", "{![0, 1); ![0, 1]}", false);
      ("{!1.9}", "{![0, 1); ![0, 1]}", true);
      ("{!2}", "{![0, 1]; ![0, 1]}", true);
      ("{!2; A}", "{![0, 1); 1; A}", false);
      ("{!1.5; A}", "{![0, 1); [0, 1); A}", true);
      ("{(!1; A)*}", "{(![0, 2]; A)*}", true);
      ("{(!3; A)*}", "{(![0, 2]; A)*}", false);
      ("{(1; A)*}", "{(![0, 2]; A)*}", false);
    ]
  @ verdicts
      (module Rat.Rigid.Lower)
      bounds
      [
        ("{![0, 1)}", "{!1}", false);
        ("{!1}", "{!(0, 1); !(0, 1)}", true);
        ("{!1}", "{!(1/2, 1); !(1/2, 1)}", false);
        ("{!2}", "{!(1, 2); 1}", false);
        ("{!2}", "{!(1, 2); (0, 1)}", true);
        ("{A; !2; A}", "{A; !(1, 2); 1; A}", false);
        ("{A; !2; A}", "{A; !(1, 2); (0, 1); A}", true);
        ("{A; !1; A}", "{A; !(1, 2); A}", false);
      ]

(* Coverage: a strict demand is covered by waiting, not by operations counting
   at their lower running-time bounds; a budget demand by both. *)
let coverage =
  let bounds =
    bounds_of [ ("A", (q 1, q 1)); ("B", (q 1, q 1)); ("C", (q 3, q 4)) ]
  in
  let lower =
    [
      ("{A; C; C; B}", "{A; !5; B}", false);
      ("{A; !5; B}", "{A; !5; B}", true);
      ("{A; !6; B}", "{A; !5; B}", true);
      ("{A; !2; C; !3; B}", "{A; !5; B}", false);
      ("{A; 5; B}", "{A; !5; B}", false);
      ("{A; C; C; B}", "{A; 5; B}", true);
      ("{A; C; !2; B}", "{A; 1; !2; B}", true);
      ("{A; !3; B}", "{A; 1; !2; B}", true);
    ]
  in
  on_all
    [
      (module Rat.Rigid.Lower);
      (module Whole.Symbolic.Rigid.Lower);
      (module TimedTraceGrades.Rigid.LowerBound);
      (module TimedTraceGrades.Rational.Rigid.LowerBound);
    ]
    bounds lower
  @ on_all
      [ (module Rat.Lower); (module TimedTraceGrades.LowerBound) ]
      bounds
      [ ("{A; C; C; B}", "{A; 5; B}", true) ]

(* Complements: a bound whose delays are strict admits no operation it does
   not name. *)
let complements =
  let bounds = bounds_of [ ("A", (q 1, q 1)); ("B", (q 1, q 1)) ] in
  let regex : (module Grade.S) list =
    [ (module Rat.Rigid.Upper); (module Whole.Symbolic.Rigid.Upper) ]
  in
  on_all regex bounds
    [
      ("{B; !3; A}", "{(!_ & ~A)*}", false);
      ("{B; !3; B; !100}", "{(!_ & ~A)*}", true);
      ("{B; 3}", "{(!_ & ~A)*}", false);
      ("{B; !3; A}", "{!_* & ~(_*; A; _*)}", false);
      ("{B; !3; B}", "{!_* & ~(_*; A; _*)}", true);
      ("{B; !3; A}", "{(_ & ~A)*}", true);
      ("{!1}", "{~!1}", true);
      ("{5}", "{~!5}", true);
      ("{!10; A; B}", "{(!_ & ~A)*; [0, 5]; B}", true);
      ("{A; !10; B}", "{(!_ & ~A)*; [0, 5]; B}", false);
      ("{!_*}", "{!_* & ~(_*; A; _*)}", false);
      ("{!5}", "{![0, 5] & ~(!2; !3)}", true);
      ("{!5}", "{![0, 5] & ~!5}", false);
      ("{!2; !3}", "{![0, 5] & ~!5}", false);
      ("{!2; !3}", "{!5}", true);
      ("{!5}", "{!2; !3}", true);
    ]
  @ List.map
      (fun (module G : Grade.S) ->
        let module R = Reader (G) in
        check
          (G.name ^ ": the budget complement of an operation is the top")
          (G.is_top bounds (R.lit "{(_ & ~A)*}")
          && G.is_top bounds (R.lit "{~!1}"))
          "")
      regex
  @ List.map
      (fun (module G : Grade.S) ->
        let module R = Reader (G) in
        check
          (G.name ^ ": a complement holding the empty trace is the top")
          (G.is_top bounds (R.lit "{~A}"))
          "")
      [
        (module Rat.Rigid.Lower : Grade.S); (module Whole.Symbolic.Rigid.Lower);
      ]

(* Printing: the grade of a delay is strict, adjacent strict delays stay
   apart, a literal with strict delays prints as written, an inferred grade
   prints as its normal form, and a printed grade reads back as an equal
   one. *)
let printing =
  let bounds = bounds_of [ ("A", (q 1, q 1)) ] in
  let prints (module G : Grade.S) text expected =
    let module R = Reader (G) in
    let rho = R.lit text in
    let shown = G.show rho in
    [
      expect (G.name ^ ": " ^ text ^ " prints") Fun.id ~expected shown;
      check
        (G.name ^ ": " ^ shown ^ " reads back")
        (G.equal bounds rho (R.lit shown))
        "";
    ]
  in
  let delays (module G : Grade.S) text d e =
    let rho = G.mul (G.of_delay d) (G.of_delay e) in
    expect (G.name ^ ": two delays print") Fun.id ~expected:text (G.show rho)
  in
  let inferred (module G : Grade.S) text d =
    let module R = Reader (G) in
    let a = R.lit "{A}" in
    let rho = G.mul a (G.mul (G.of_delay d) a) in
    expect
      (G.name ^ ": an inferred grade prints")
      Fun.id ~expected:text (G.show rho)
  in
  prints (module Rat.Rigid.Upper) "{A; !2; 1; B}" "{A; !2; 1; B}"
  @ prints (module Rat.Rigid.Upper) "{(!_ & ~A)*}" "{(!_ & ~A)*}"
  @ prints (module Rat.Rigid.Upper) "{!2; !3}" "{!2; !3}"
  @ prints
      (module Rat.Rigid.Upper)
      "{![0, 5] & ~(!2; !3)}" "{![0, 5] & ~(!2; !3)}"
  @ prints (module Whole.Symbolic.Rigid.Upper) "{!2; !3}" "{!2; !3}"
  @ prints (module Whole.Symbolic.Rigid.Upper) "{A; !2; 1; B}" "{A; !2; 1; B}"
  @ prints (module Whole.Symbolic.Rigid.Upper) "{!3 | !5}" "{!3 | !5}"
  @ prints (module Whole.Symbolic.Rigid.Upper) "{(!_ & ~A)*}" "{(!_ & ~A)*}"
  @ prints
      (module Whole.Symbolic.Rigid.Upper)
      "{A; ![5, 10]; B}" "{A; ![5, 10]; B}"
  @ prints
      (module Whole.Symbolic.Rigid.Upper)
      "{!_* & ~(_*; A; (_ & ~B)*; A; _*)}" "{!_* & ~(_*; A; (_ & ~B)*; A; _*)}"
  @ prints
      (module Whole.Symbolic.Rigid.Lower)
      "{A; ![5, 10]; B}" "{A; ![5, 10]; B}"
  @ prints
      (module Whole.Symbolic.Rigid.Interval)
      "[{A; !2; B}, {(A; B)*; A; ![2, 3]; B}]"
      "[{A; !2; B}, {(A; B)*; A; ![2, 3]; B}]"
  @ prints (module Whole.Symbolic.Rigid.Upper) "{_*}" "⊤"
  @ prints (module TimedTraceGrades.Rigid.UpperBound) "{A; !2; 1}" "{A; !2; 1}"
  @ [
      delays (module Rat.Rigid.Upper) "{!0.5; !2}" (qf 1 2) (q 2);
      delays (module Whole.Symbolic.Rigid.Upper) "{!2; !3}" 2 3;
      inferred (module Whole.Symbolic.Rigid.Upper) "{A; !6; A}" 6;
      inferred (module Rat.Rigid.Upper) "{A; !6; A}" (q 6);
      delays (module TimedTraceGrades.Rigid.UpperBound) "{!5}" 2 3;
      delays (module Rat.Upper) "{2.5}" (qf 1 2) (q 2);
    ]

(* Strict delays are read by the visible rigid grades only. *)
let rejections =
  let rejected (module G : Grade.S) text =
    let module R = Reader (G) in
    check
      (G.name ^ ": " ^ text ^ " is rejected")
      (Result.is_error (R.read text))
      ""
  in
  let rejects_with (module G : Grade.S) text fragment =
    let module R = Reader (G) in
    match R.read text with
    | Ok _ -> check (G.name ^ ": " ^ text ^ " is rejected") false ""
    | Error reason ->
        let contains s sub =
          let n = String.length sub in
          let rec at i =
            i + n <= String.length s && (String.sub s i n = sub || at (i + 1))
          in
          at 0
        in
        check
          (G.name ^ ": " ^ text ^ " is rejected naming the rigid grades")
          (contains reason fragment) reason
  in
  List.concat_map
    (fun g ->
      [ rejects_with g "{A; !3}" "regex-timed-rigid-"; rejected g "{!_}" ])
    [
      (module Rat.Upper : Grade.S);
      (module Rat.Lower);
      (module Rat.Interval);
      (module Whole.Symbolic.Upper);
      (module Grades.RegularTraceGradeRational);
      (module Grades.RegularTraceGradeDerivative);
      (module Rat.Automata.Rigid.Upper);
      (module Whole.Rigid.Upper);
      (module Whole.Concrete.Rigid.Upper);
      (module Whole.Plain.Rigid.Upper);
      (module TimedTraceGrades.UpperBound);
    ]
  @ List.concat_map
      (fun g -> [ rejected g "{!A}"; rejected g "{!(A; 2)}" ])
      [
        (module Rat.Rigid.Upper : Grade.S); (module Whole.Symbolic.Rigid.Upper);
      ]
  @ [ rejected (module TimedTraceGrades.Rigid.UpperBound) "{![1, 2]}" ]

let () =
  let checks =
    recursions @ grades_agree @ conservative @ kinds @ specifications
    @ open_sets @ coverage @ complements @ printing @ rejections
  in
  let failures = List.filter (fun c -> not c.passed) checks in
  List.iter (fun c -> Printf.printf "FAIL %s: %s\n" c.name c.detail) failures;
  Printf.printf "%d of %d checks passed\n"
    (List.length checks - List.length failures)
    (List.length checks);
  if failures <> [] then exit 1
