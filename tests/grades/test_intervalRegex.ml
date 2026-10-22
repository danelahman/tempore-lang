(* Tests of the timed regular expressions with interval letters: the syntax of
   their letters in brace literals and its errors, their normal forms on each
   side, over whole time steps and rationals, their printing, the zipping of
   intervals, and the rejection of the forms they do not read. *)

module Grade = Grades.Grade
module I = Grades.IntervalRegex
open LawChecks

(* A grade that records the literal it reads. *)
module Capture = struct
  include Grades.TimeGrades.UpperBound

  let last = ref None

  let of_lit lit =
    last := Some lit;
    top
end

module Grammar = Parser.Grammar.Make (Grades.GradeSystem.Identity (Capture))

(* [parse text] is the literal [text], or the message of its syntax error. *)
let parse text =
  let lexbuf = Lexing.from_string ("box " ^ text ^ " ()") in
  match Grammar.payload (Parser.Lexer.tokens ()) lexbuf with
  | _ -> Ok (Option.get !Capture.last)
  | exception Utils.Error.Error d -> Error d.Utils.Diagnostic.message

let regex text =
  match parse text with
  | Ok (Grade.Braces r) -> r
  | Ok _ -> failwith ("not a brace literal: " ^ text)
  | Error message -> failwith (text ^ ": " ^ message)

(* [read ~side ~whole ~finite text] is the printed normal form of the brace
   literal [text] on [side], or the reason it is rejected. *)
let read ?(whole = false) ?(finite = false) side text =
  let r = regex text in
  let lit = Grade.Braces r in
  match side with
  | `Upper -> (
      match I.Upper.of_regex ~whole ~finite lit r with
      | e -> Ok (I.Upper.show e)
      | exception Grade.Invalid_literal (_, reason) -> Error reason)
  | `Lower -> (
      match I.Lower.of_regex ~whole ~finite lit r with
      | e -> Ok (I.Lower.show e)
      | exception Grade.Invalid_literal (_, reason) -> Error reason)

let show_result = function Ok s -> "Ok " ^ s | Error s -> "Error " ^ s

let contains s sub =
  let n = String.length s and k = String.length sub in
  let rec from i = i + k <= n && (String.sub s i k = sub || from (i + 1)) in
  from 0

let reads ?whole ?finite side text expected =
  expect ("reads " ^ text) show_result ~expected:(Ok expected)
    (read ?whole ?finite side text)

let rejects ?whole ?finite side text fragment =
  match read ?whole ?finite side text with
  | Ok s -> check ("rejects " ^ text) false ("read as " ^ s)
  | Error reason ->
      check ("rejects " ^ text) (contains reason fragment)
        ("the reason '" ^ reason ^ "' does not mention '" ^ fragment ^ "'")

let syntax_error text fragment =
  match parse text with
  | Ok _ -> check ("syntax error " ^ text) false "parsed"
  | Error message ->
      check ("syntax error " ^ text) (contains message fragment) message

let parses text expected =
  expect ("parses " ^ text) Fun.id ~expected (Grade.show_regex (regex text))

(* {1 Syntax} *)

let syntax =
  [
    parses "{idle <=3}" "idle ≤3";
    parses "{idle ≤3}" "idle ≤3";
    parses "{idle <3}" "idle <3";
    parses "{idle >=2.5}" "idle ≥2.5";
    parses "{idle >2}" "idle >2";
    parses "{<=5; >=1000}" "≤5; ≥1000";
    parses "{≤∞}" "≤∞";
    parses "{<inf}" "≤∞";
    parses "{A?|B}" "A | 0 | B";
    parses "{A?;B}" "(A | 0); B";
    parses "{(A; idle <=1)?}" "A; idle ≤1 | 0";
    parses "{idle ~[2, 3]}" "idle (~[2, 3])";
    parses "{>=0 & ~Read}" "≥0 & ~Read";
    parses "{idle <=1*}" "idle ≤1*";
    syntax_error "{<0}" "`<0` holds no delay";
    syntax_error "{>=inf}" "`≥∞` holds no delay";
    syntax_error "{idle A}"
      "A strict wait `idle` applies to a length or an interval of lengths, not \
       to `A`";
  ]

(* {1 Normal forms and printing} *)

let normal_forms =
  [
    reads `Upper "{1; idle 1; 1}" "≤1; idle ≤1; ≤1";
    reads `Upper "{1; 1}" "≤2";
    reads `Upper "{idle 1; idle 2.5}" "idle ≤3.5";
    reads `Lower "{1; idle 1; 1}" "≥1; idle ≥1; ≥1";
    reads `Lower "{idle 1; idle 2}" "idle ≥3";
    reads `Upper "{1; (A | 0); 1}" "≤1; A?; ≤1";
    reads `Upper "{(idle 400)^500}" "idle ≤200000";
    reads `Lower "{(idle 400)^500}" "idle ≥200000";
    reads `Lower "{(idle 400)^[0, 500]}" "(idle ≥400)?";
    reads `Upper "{(ReceiveMessage; ReportStatus; idle 400)^[1, 500]}"
      "(ReceiveMessage; ReportStatus; idle ≤400)^[1, 500]";
    reads `Lower "{(ReceiveMessage; ReportStatus; idle 400)^[1, 500]}"
      "(ReceiveMessage; ReportStatus; idle ≥400)^[1, 500]";
    reads `Upper "{(idle 2)*}" "idle ≥0";
    reads `Lower "{(idle 2)*}" "(idle ≥2)?";
    reads `Lower "{(>=0)*}" "≥0";
    reads `Lower "{(idle >=0)*}" "idle ≥0";
    reads `Upper "{[2, 5]}" "≤5";
    reads `Lower "{[2, 5]}" "≥2";
    reads `Lower "{(2, 5]}" ">2";
    reads ~whole:true `Lower "{(2, 5]}" "≥3";
    reads `Upper "{<3}" "<3";
    reads ~whole:true `Upper "{<3}" "≤2";
    reads ~whole:true `Upper "{<1}" "0";
    reads ~whole:true `Upper "{idle <1}" "0";
    reads `Upper "{1 | 3}" "≤3";
    reads `Lower "{1 | 3}" "≥1";
    reads `Lower "{0 | 3}" "≥3?";
    reads `Upper "{0 | 3}" "≤3";
    reads `Upper "{0 | idle 3}" "idle ≤3";
    reads `Upper "{0}" "0";
    reads `Lower "{>=0}" "≥0";
    reads `Upper "{>=0}" "≥0";
    reads `Lower "{<=inf}" "≥0";
    reads `Upper "{[0, 5] & [2, 7]}" "≤5";
    reads `Lower "{[0, 5] & [2, 7]}" "≥2";
    reads `Upper "{A | B; C | B}" "A | B | B; C";
    reads `Upper "{(A | B); C}" "(A | B); C";
    reads `Upper "{_}" "_";
    reads `Upper "{_*}" "_*";
    reads `Upper "{~Read}" "_ & ~Read";
    reads `Upper "{_ & ~(Read | Log)}" "_ & ~(Log | Read)";
    reads `Upper "{A & B}" "_ & ~_";
    reads `Upper "{A; A; A}" "A^3";
    reads `Upper "{A?}" "A?";
    reads `Upper "{(A; B)?}" "(A; B)?";
    reads `Upper "{(idle 1)?}" "idle ≤1";
    reads `Upper "{idle 1; A; idle 1}" "idle ≤1; A; idle ≤1";
  ]

(* {1 Rejections} *)

let rejections =
  [
    rejects `Upper "{~(A; B)}"
      "the complement `~` applies to operation sets and intervals only";
    rejects `Upper "{(A; B) & C}"
      "the intersection `&` applies to operation sets, intervals and a budget \
       with an operation set only";
    rejects `Upper "{A; >=0 & ~B; C}"
      "a restricted budget in a sequence is written in parentheses";
    reads `Upper "{(>=0 & ~B)}" "≥0 & ~B";
    reads `Lower "{>=0 & ~ReceiveMessage}" "≥0 & ~ReceiveMessage";
    reads `Upper "{A; (≤5 & (Scan | Turn)); B}" "A; (≤5 & (Scan | Turn)); B";
    reads `Upper "{A; ((Scan | Turn) & <=5); B}" "A; (≤5 & (Scan | Turn)); B";
    reads `Upper "{(≤1 & A); (≤2 & A)}" "≤3 & A";
    reads `Upper "{(≤1 & A); ≤1}" "(≤1 & A); ≤1";
    reads `Upper "{(≤1 & A) | (≤3 & A)}" "≤3 & A";
    reads `Lower "{(≥1 & A) | (≥3 & A)}" "≥1 & A";
    reads `Upper "{(≤1 & ~(A | B))*}" "≥0 & ~(A | B)";
    rejects `Upper "{(idle ≤1 & A)}" "the intersection `&` applies";
    reads `Upper "{(≤1 & (A & B))}" "idle ≤1";
    reads ~finite:true `Upper "{A; (≤3 & ~B)}" "A; (≤3 & ~B)";
    rejects `Upper "{idle _}" "`idle _` is no letter of these grades";
    rejects `Upper "{idle ~[2, 3]}"
      "the complement of an interval is not one-sided";
    rejects `Upper "{~[2, 3]}" "the complement of an interval is not one-sided";
    rejects `Lower "{<=3}"
      "lower bounds have letters bounded below only, such as `≥3` or `idle \
       ≥3`, not `≤3`";
    rejects `Lower "{idle <3}" "not `idle <3`";
    rejects `Upper "{>=3}"
      "upper bounds have letters bounded above only, such as `≤3` or `idle \
       ≤3`, not `≥3`";
    rejects ~whole:true `Upper "{1/2}" "";
    rejects ~finite:true `Upper "{A*}" "repetition `*`";
    rejects ~finite:true `Upper "{A^[1, ∞)}" "the unbounded repetition";
    rejects ~finite:true `Upper "{_}" "the operation set `_`";
    rejects ~finite:true `Upper "{~A}" "the operation set `~A`";
    reads ~finite:true `Upper "{(A | B); ≤3; A^[1, 2]}" "(A | B); ≤3; A^[1, 2]";
  ]

(* {1 Zipped intervals} *)

let zip_of text =
  let r = regex text in
  let lit = Grade.Braces r in
  I.zip
    (I.Lower.of_regex ~whole:false ~finite:false lit r)
    (I.Upper.of_regex ~whole:false ~finite:false lit r)

let zip_pair lo hi =
  let lo = regex lo and hi = regex hi in
  I.zip
    (I.Lower.of_regex ~whole:false ~finite:false (Grade.Braces lo) lo)
    (I.Upper.of_regex ~whole:false ~finite:false (Grade.Braces hi) hi)

let show_option = function Some s -> s | None -> "none"

let zips text expected =
  expect ("zips " ^ text) show_option ~expected:(Some expected) (zip_of text)

let zipping =
  [
    expect "zips a restricted interval" show_option
      ~expected:(Some "[1000, 600000] & ~Move")
      (zip_pair "{≥1000 & ~Move}" "{≤600000 & ~Move}");
    expect "does not zip different sets" show_option ~expected:None
      (zip_pair "{≥1000 & ~Move}" "{≤600000 & ~ReceiveMessage}");
    zips "{AddEthanol; idle [0.5, 1.5]}" "AddEthanol; idle [0.5, 1.5]";
    zips "{idle 400}" "idle 400";
    zips "{[1000, 600000]}" "[1000, 600000]";
    zips "{(2, 3)}" "(2, 3)";
    zips "{[2, ∞)}" "[2, ∞)";
    zips "{≥0}" "≥0";
    zips "{(ReceiveMessage; ReportStatus; idle 400)^[1, 500]}"
      "(ReceiveMessage; ReportStatus; idle 400)^[1, 500]";
    zips "{(A | B); 2 | C; 3}" "(A | B); 2 | C; 3";
    zips "{[0, 1]}" "[0, 1]";
    zips "{A?; 3}" "A?; 3";
    expect "zips a lower bound with the top" show_option
      ~expected:(Some "[1000, ∞)")
      (zip_pair "{≥1000}" "{≥0}");
    expect "does not zip an empty interval" show_option ~expected:None
      (zip_pair "{A; ≥2}" "{A; ≤1}");
    expect "does not zip different skeletons" show_option ~expected:None
      (zip_pair "{A; ≥2}" "{A; ≤3; B}");
  ]

let () =
  let checks = syntax @ normal_forms @ rejections @ zipping in
  let failures = List.filter (fun c -> not c.passed) checks in
  List.iter (fun c -> Printf.printf "FAIL %s: %s\n" c.name c.detail) failures;
  Printf.printf "%d of %d checks passed\n"
    (List.length checks - List.length failures)
    (List.length checks);
  if failures <> [] then exit 1
