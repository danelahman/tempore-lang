(* Test of the links of the names of a program to their definitions, in the
   program and in the standard library: local variables, parameters, top-level
   definitions, constructors, types in annotations, a performed operation and
   functions and operators of the standard library. Silent on success. *)

module Location = Utils.Location
module References = Desugarer.References
module G = (val snd (List.hd Grades.GradeRegistry.grade_modules))
module GS = Grades.GradeSystem.Identity (G)
module Grammar = Parser.Grammar.Make (GS)

let program =
  {|type shape = Circle of nat | Square of nat

operation Observe : shape ~> unit # 1

let area (s : shape) =
  match s with
  | Circle r -> r * r
  | Square a -> a * a

let total xs = fold_left (fun acc x -> acc + area x) 0 xs

run
  let c = Circle 2 in
  perform Observe c;
  total [c; Square (length [1; 2])]
|}

let parse ~filename source =
  let lexbuf = Lexing.from_string source in
  lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = filename };
  Grammar.commands (Parser.Lexer.tokens ()) lexbuf

(* The links of the program's names, loaded after the standard library. *)
let links =
  let env, _ =
    List.fold_left_map References.command References.empty
      (parse ~filename:Loader.stdlib_filename Loader.stdlib_source)
  in
  List.concat
    (snd
       (List.fold_left_map References.command env (parse ~filename:"" program)))

let text (loc : Location.t) =
  let source = if loc.filename = "" then program else Loader.stdlib_source in
  String.sub source loc.start.offset (loc.stop.offset - loc.start.offset)

let place (loc : Location.t) =
  if loc.filename = "" then
    Printf.sprintf "%d:%d" loc.start.line loc.start.column
  else loc.filename

let sort = function
  | References.Value -> "value"
  | Constructor -> "constructor"
  | Type -> "type"
  | Operation -> "operation"

let show ({ use; definition; sort = s } : References.link) =
  Printf.sprintf "%s %s -> %s %s (%s)" (text use) (place use) (text definition)
    (place definition) (sort s)

let expected =
  [
    "shape 3:21 -> shape 1:6 (type)";
    "shape 5:15 -> shape 1:6 (type)";
    "s 6:9 -> s 5:11 (value)";
    "Circle 7:5 -> Circle 1:14 (constructor)";
    "r 7:17 -> r 7:12 (value)";
    "* 7:19 -> ( * ) stdlib.tpe (value)";
    "r 7:21 -> r 7:12 (value)";
    "Square 8:5 -> Square 1:30 (constructor)";
    "a 8:17 -> a 8:12 (value)";
    "* 8:19 -> ( * ) stdlib.tpe (value)";
    "a 8:21 -> a 8:12 (value)";
    "fold_left 10:16 -> fold_left stdlib.tpe (value)";
    "acc 10:40 -> acc 10:31 (value)";
    "+ 10:44 -> ( + ) stdlib.tpe (value)";
    "area 10:46 -> area 5:5 (value)";
    "x 10:51 -> x 10:35 (value)";
    "xs 10:56 -> xs 10:11 (value)";
    "Circle 13:11 -> Circle 1:14 (constructor)";
    "Observe 14:11 -> Observe 3:11 (operation)";
    "c 14:19 -> c 13:7 (value)";
    "total 15:3 -> total 10:5 (value)";
    "c 15:10 -> c 13:7 (value)";
    "Square 15:13 -> Square 1:30 (constructor)";
    "length 15:21 -> length stdlib.tpe (value)";
  ]

let () =
  let actual = List.map show links in
  if actual <> expected then begin
    List.iter print_endline actual;
    prerr_endline "test_references: the links differ from the expected ones";
    exit 1
  end
