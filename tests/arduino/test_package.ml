(* The running-time bounds of the peripheral packages of the Arduino backend
   by board: their selection, their replacement of the bounds the
   declarations give under each kind of grade system, and the errors of a
   descriptor or a source that they do not fit. Each case prints its outcome,
   compared with test_package.expected. *)

module Package = ArduinoBackend.ArduinoPackage
module Error = Utils.Error

let show_bounds (lo, hi) = Grades.Grade.show_interval Grades.Rational.show lo hi

let show_running_times = function
  | [] -> "none"
  | running_times ->
      String.concat ", "
        (List.map
           (fun (op, bounds) -> op ^ " " ^ show_bounds bounds)
           running_times)

(* The outcome of [f], or the message of the error it raises. *)
let outcome f =
  match f () with
  | text -> text
  | exception Error.Error d -> "Error: " ^ d.Utils.Diagnostic.message

let closed lo hi =
  ( Grades.Grade.Closed (Grades.Rational.of_decimal lo),
    Grades.Grade.Closed (Grades.Rational.of_decimal hi) )

(* The bounds of the package m5-imu on each board, and on none. *)
let selection () =
  let package = Option.get (Package.find "m5-imu") in
  List.iter
    (fun board ->
      Printf.printf "m5-imu on %s: %s\n"
        (Option.value ~default:"no board" board)
        (show_running_times (Package.running_times ?board package)))
    [ None; Some "m5stack-gray"; Some "m5stack-cores3"; Some "m5stack-fire" ];
  List.iter
    (fun (grades, board) ->
      match Package.files_for ~grades ~board package with
      | Ok files ->
          List.iter
            (fun (f : Package.file) ->
              Printf.printf "%s under %s on %s: %s\n" f.filename grades board
                (show_running_times f.running_times))
            files
      | Error message -> print_endline message)
    [
      ("time-interval-rational", "m5stack-gray");
      ("counts-upper-bound", "m5stack-cores3");
    ]

(* The descriptor of a package p with the member 'bounds' [bounds]. *)
let descriptor bounds =
  [
    ( "p/package.json",
      Printf.sprintf
        {|{ "description": "A package", "declarations": "p.tpe",
  "grades": ["time-interval-rational"], "bindings": ["A"],
  "bounds": %s }|}
        bounds );
    ("p/p.tpe", "operation A : unit ~> unit ! [0, 1]\n");
  ]

let descriptors () =
  List.iter
    (fun bounds ->
      print_endline
        (outcome (fun () ->
             let p = Package.parse ~files:(descriptor bounds) "p" in
             show_running_times (Package.running_times ~board:"esp32-devkit" p))))
    [
      {|{ "esp32-devkit": { "A": [0.5, 0.75] } }|};
      {|{ "esp32-board": { "A": [0.5, 0.75] } }|};
      {|{ "esp32-devkit": { "B": [0.5, 0.75] } }|};
      {|{ "esp32-devkit": { "A": [0.75, 0.5] } }|};
      {|{ "esp32-devkit": { "A": 0.5 } }|};
      {|{ "esp32-devkit": { "A": [0.5, 0.75], "A": [0.5, 1] } }|};
      {|[]|};
    ]

(* The declarations [source] under the grades [grades], with the bounds
   [running_times] replaced, each operation with its grade and its bounds
   [within], if any. *)
let replaced grades running_times source =
  let (module G : Grades.Grade.S) =
    List.assoc grades Grades.GradeRegistry.grade_modules
  in
  let module GS = Grades.GradeSystem.Identity (G) in
  let module Grammar = Parser.Grammar.Make (GS) in
  outcome (fun () ->
      let lexbuf = Lexing.from_string source in
      let commands = Grammar.commands (Parser.Lexer.tokens ()) lexbuf in
      Loader.with_running_times
        (module GS.E)
        ~filename:"source.tpe" running_times commands
      |> List.filter_map (fun (cmd : _ SugaredAst.command) ->
          match cmd.it with
          | SugaredAst.OpSig
              (name, _, _, (eps : _ Utils.Location.located), within) ->
              Some
                (Printf.sprintf "%s ! %s%s" name.it
                   (match eps.it with
                   | SugaredAst.GradeLit g -> GS.E.show g
                   | SugaredAst.GradeParam p -> p)
                   (match within with
                   | Some bounds -> " within " ^ show_bounds bounds
                   | None -> ""))
          | _ -> None)
      |> String.concat "; ")

let replacements () =
  let a = [ ("A", closed "0.5" "0.75") ] in
  List.iter
    (fun (grades, running_times, source) ->
      Printf.printf "%s: %s\n" grades (replaced grades running_times source))
    [
      ( "time-interval-rational",
        a,
        "operation A : unit ~> unit ! [0, 1]\n\
         operation B : unit ~> unit ! [0, 1]\n" );
      ("time-lower-bound-rational", a, "operation A : unit ~> unit ! 0\n");
      ( "regex-timed-interval-rational-symbolic",
        a,
        "operation A : unit ~> unit ! {A} within (0, 1]\n" );
      ("counts-upper-bound", a, "operation A : unit ~> unit ! (A, 1)\n");
      ( "time-interval-rational",
        [ ("C", closed "0.5" "0.75") ],
        "operation A : unit ~> unit ! [0, 1]\n" );
      ("time-interval", a, "operation A : unit ~> unit ! [0, 1]\n");
    ]

(* The operations bound by both of two packages. *)
let shared () =
  let package name bindings =
    Package.parse
      ~files:
        [
          ( name ^ "/package.json",
            Printf.sprintf
              {|{ "description": "A package", "declarations": "%s.tpe",
  "grades": ["time-interval-rational"], "bindings": [%s] }|}
              name
              (String.concat ", " (List.map (Printf.sprintf "%S") bindings)) );
          ( name ^ "/" ^ name ^ ".tpe",
            String.concat ""
              (List.map
                 (Printf.sprintf "operation %s : unit ~> unit ! [0, 1]\n")
                 bindings) );
        ]
      name
  in
  let p = package "p" [ "A"; "B" ] in
  List.iter
    (fun q ->
      Printf.printf "p and %s share: %s\n" q.Package.name
        (Option.value ~default:"none" (Package.shared_binding p q)))
    [ package "q" [ "C"; "B" ]; package "r" [ "C" ] ]

let () =
  selection ();
  descriptors ();
  replacements ();
  shared ()
