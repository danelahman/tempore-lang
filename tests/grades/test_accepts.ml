(* Unit tests of [Grade.S.accepts]: for every grade of
   [GradeRegistry.grade_modules] and every grade literal of the source files of
   the tests, the examples and the standard library, and of a list of literals
   the parser does not produce, [accepts] agrees with reading the literal by
   [of_lit]. The literals are collected by parsing the
   files under a grade that records the literals it reads. The pairs of a grade
   over whole time steps and a literal with an interval atom of more than
   [widest] time steps are not read by [of_lit]. *)

module Grade = Grades.Grade
module GradeRegistry = Grades.GradeRegistry
module Rational = Grades.Rational
open LawChecks

(* The literals read so far, most recent first. *)
let recorded : Grade.lit list ref = ref []

(* A grade over rational delays that reads every literal as its top, recording
   it. *)
module Recorder = struct
  include Grades.RationalTimeGrades.UpperBound

  let of_lit lit =
    recorded := lit :: !recorded;
    top

  let accepts _ = true
end

module Grammar = Parser.Grammar.Make (Grades.GradeSystem.Identity (Recorder))

(* The source files [.tpe] under the directory [dir], recursively. *)
let rec sources dir =
  List.concat_map
    (fun name ->
      let path = Filename.concat dir name in
      if Sys.is_directory path then sources path
      else if Filename.check_suffix name ".tpe" then [ path ]
      else [])
    (List.sort String.compare (Array.to_list (Sys.readdir dir)))

(* The literals of the file [path] up to its first syntax error, if any. *)
let literals_of path =
  recorded := [];
  (try
     ignore
       (Parser.Lexer.read_file (Grammar.commands (Parser.Lexer.tokens ())) path)
   with _ -> ());
  !recorded

(* Literals the parser does not produce or the sources do not hold: negative
   and fractional delays, interval atoms without a whole number of time steps,
   operations among numbers of ticks, and their intersections and
   complements. *)
let unwritten =
  let open Grade in
  let q = Rational.make in
  let send = Letter "Send" in
  let no_tick = Delays (Open (q 1 1), Open (q 2 1)) in
  [
    Braces (Tick (-1));
    Braces (Seq (send, Frac (q 1 2)));
    Braces (Seq (send, Delays (Closed (q (-1) 1), Closed (q 1 1))));
    Braces (Seq (send, Delays (Unbounded, Closed (q 1 1))));
    Braces (Seq (send, no_tick));
    Braces (Union (Tick 2, no_tick));
    Braces (Star (Delays (Closed (q 1 2), Closed (q 3 4))));
    Braces (Union (Tick 1, Delays (Closed (q 1 2), Unbounded)));
    Braces (Inter (Tick 1, Tick 2));
    Braces (Inter (Star Any, Compl (Tick 3)));
    Braces (Compl (Star Any));
    Braces (Seq (Star Any, Compl (Delays (Closed (q 0 1), Unbounded))));
    Braces (Seq (Any, send));
    Tuple [ Int 1; Tuple [ Name "Send"; Braces send ] ];
    Tuple [ Int 1; Tuple [ Name "Send"; Braces (Inter (Tick 1, Tick 2)) ] ];
    Tuple [ Int 1; Tuple [ Name "Send"; Braces (Compl (Star Any)) ] ];
    Tuple [ Braces (Inter (Tick 1, Tick 2)); Tuple [ Name "Send"; Braces Any ] ];
    Interval (Closed (Braces send), Closed (Braces (Inter (send, Tick 1))));
    Interval (Closed (Braces (Seq (send, no_tick))), Unbounded);
  ]

let literals =
  List.sort_uniq compare
    (unwritten
    @ List.concat_map literals_of
        (List.concat_map sources
           [ ".."; "../../examples"; "../../src/06-loader" ]))

(* The greatest number of time steps of an interval atom read by [of_lit] in
   the grades over whole time steps, which expand it into a run of ticks. *)
let widest = 1000

let rec width = function
  | Grade.Delays (lo, hi) -> (
      match Grade.tick_interval lo hi with
      | a, Some b -> b - a
      | _, None -> 0
      | exception Grade.Invalid_literal _ -> 0)
  | Grade.Letter _ | Grade.Tick _ | Grade.Frac _ | Grade.Any -> 0
  | Grade.Seq (r, s) | Grade.Union (r, s) | Grade.Inter (r, s) ->
      max (width r) (width s)
  | Grade.Star r | Grade.Compl r -> width r

let rec lit_width = function
  | Grade.Braces r -> width r
  | Grade.Tuple ls -> List.fold_left (fun w l -> max w (lit_width l)) 0 ls
  | Grade.Interval (lo, hi) ->
      let end_width = function
        | Grade.Closed l | Grade.Open l -> lit_width l
        | Grade.Unbounded -> 0
      in
      max (end_width lo) (end_width hi)
  | Grade.Int _ | Grade.Rat _ | Grade.Name _ | Grade.Top | Grade.Inf -> 0

let whole_steps (module G : Grade.S) =
  Option.is_none (G.Delay.read (Grade.Rat (Rational.make 1 2)))

let skipped (module G : Grade.S) lit =
  whole_steps (module G) && lit_width lit > widest

(* The literal [lit] as the source writes it. *)
let rec show_lit = function
  | Grade.Int n -> string_of_int n
  | Grade.Rat q -> Rational.show q
  | Grade.Name s -> s
  | Grade.Top -> "⊤"
  | Grade.Inf -> "∞"
  | Grade.Tuple ls -> "(" ^ String.concat ", " (List.map show_lit ls) ^ ")"
  | Grade.Interval (lo, hi) ->
      let show_end ~lower = function
        | Grade.Closed l ->
            (if lower then "[" else "") ^ show_lit l ^ if lower then "" else "]"
        | Grade.Open l ->
            (if lower then "(" else "") ^ show_lit l ^ if lower then "" else ")"
        | Grade.Unbounded -> if lower then "(-∞" else "∞)"
      in
      show_end ~lower:true lo ^ ", " ^ show_end ~lower:false hi
  | Grade.Braces r -> "{" ^ Grade.show_regex r ^ "}"

let agreement =
  List.concat_map
    (fun (name, (module G : Grade.S)) ->
      List.filter_map
        (fun lit ->
          if skipped (module G) lit then None
          else
            let shown = show_lit lit in
            Some
              (match Grade.reads_lit G.of_lit lit with
              | read ->
                  expect
                    (name ^ ": accepts agrees with of_lit on " ^ shown)
                    string_of_bool ~expected:read (G.accepts lit)
              | exception e ->
                  check
                    (name ^ ": of_lit on " ^ shown)
                    false
                    ("raises " ^ Printexc.to_string e)))
        literals)
    GradeRegistry.grade_modules

let collected =
  [
    check "literals are collected from the sources"
      (List.length literals > 100)
      (string_of_int (List.length literals) ^ " literals");
  ]

(* The literals not read by [of_lit] in the grades over whole time steps. *)
let skipped_notes =
  List.filter_map
    (fun lit ->
      if lit_width lit > widest then
        Some ("not read by of_lit over whole time steps: " ^ show_lit lit)
      else None)
    literals

let () =
  let checks = collected @ agreement in
  List.iter (Printf.printf "note: %s\n") skipped_notes;
  let failures = List.filter (fun c -> not c.passed) checks in
  List.iter (fun c -> Printf.printf "FAIL %s: %s\n" c.name c.detail) failures;
  Printf.printf "%d of %d checks passed\n"
    (List.length checks - List.length failures)
    (List.length checks);
  if failures <> [] then exit 1
