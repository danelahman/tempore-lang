(* Tests of the timelines of interpreter runs, of the observations of boxes and
   unboxes, and of the backend registry of the web interface: the Opentrons
   examples, run by the interpreter with the observations of each step fed to
   the observer of the registry, which must finish every call, and compiled
   with and without their binding files. Silent on success. *)

module Grade = Grades.Grade

let fail = TestSupport.Failures.fail
let verbose = Array.exists (( = ) "-v") Sys.argv

(* Timelines *)

let show_entry (e : Timeline.entry) =
  let event =
    match e.event with
    | Call { op; grade; returned } ->
        Printf.sprintf "%s %s %s" op grade (if returned then "+" else "-")
    | Delay { grade } -> "delay " ^ grade
    | Box { name; grade; _ } -> Printf.sprintf "box %s %s" name grade
    | Unbox { name; _ } -> Printf.sprintf "unbox %s" name
  in
  Printf.sprintf "%d %d %s %s" e.run e.depth e.start event

(* Calls nested in default implementations, a resource named after it is
   boxed, and two runs, the second ended by an operation without a default
   implementation. *)
let () =
  let t =
    List.fold_left
      (Fun.flip Timeline.observe)
      Timeline.empty
      [
        Backend.Performed { at = "0"; op = "A"; grade = "5" };
        Delayed { at = "0"; grade = "2" };
        Performed { at = "0"; op = "B"; grade = "2" };
        Delayed { at = "0"; grade = "1" };
        Resumed;
        Boxed
          {
            at = "0";
            resource = "resource_0";
            name = "resource_0";
            grade = "3";
          };
        Resumed;
        Unboxed { at = "5"; resource = "resource_0"; name = "resource_0" };
        Named { resource = "resource_0"; name = "x" };
        Returned { at = "5"; value = "()" };
        Performed { at = "0"; op = "C"; grade = "1" };
        Stopped { at = "1"; op = "D" };
      ]
  in
  let entries = List.map show_entry (Timeline.entries t) in
  if
    entries
    <> [
         "1 0 0 A 5 +";
         "1 1 0 delay 2";
         "1 1 0 B 2 +";
         "1 2 0 delay 1";
         "1 1 0 box x 3";
         "1 0 5 unbox x";
         "2 0 0 C 1 -";
       ]
  then fail "timeline: %s" (String.concat "; " entries);
  (match Timeline.runs t with
  | [
   { index = 1; outcome = Returned "()"; at = "5" };
   { index = 2; outcome = Stopped "D"; at = "1" };
  ] ->
      ()
  | _ -> fail "timeline: the runs ended");
  let report = Timeline.report t in
  let cells (row : Timeline.row) = String.concat " | " row.cells in
  let rows =
    List.map
      (fun (row : Timeline.row) ->
        Printf.sprintf "%s %d %s" (cells row) row.depth
          (if row.status = Pending then "pending" else "plain"))
      report.rows
  in
  if
    rows
    <> [
         "1 | 0 | A | 5 0 plain";
         "1 |  | · delay | 2 1 plain";
         "1 |  | · B | 2 1 plain";
         "1 |  | · · delay | 1 2 plain";
         "1 |  | · box x with grade 3 |  1 plain";
         "1 | 5 | unbox x |  0 plain";
         "2 | 0 | C | 1 0 pending";
       ]
  then fail "timeline report: %s" (String.concat "; " rows);
  let text = Timeline.text (Timeline.report ~run:1 t) in
  let expected =
    String.concat "\n"
      [
        "Timeline";
        "Run  Start  Event                 Grade";
        "1    0      A                     5";
        "1           · delay               2";
        "1           · B                   2";
        "1           · · delay             1";
        "1           · box x with grade 3";
        "1    5      unbox x";
        "Run 1 returned () at 5.";
        "";
      ]
  in
  if text <> expected then fail "timeline text:\n%s" text

(* Shortening: brace groups at both ends of an interval, from the front or the
   back, a regular expression with a nested group, short grades unchanged, and
   the character cut of grades without groups. *)
let () =
  let check keep grade expected =
    let shortened = Timeline.shorten keep grade in
    if shortened <> expected then
      fail "shorten %s: %s, not %s" grade shortened expected
  in
  let start = "{AddBeads; 5; Engage; 3; RemoveSupernatant}" in
  check End
    ("[" ^ start ^ ", " ^ start ^ "]")
    "[{…; 5; Engage; 3; RemoveSupernatant}, {…; 5; Engage; 3; \
     RemoveSupernatant}]";
  check Beginning
    ("[" ^ start ^ ", " ^ start ^ "]")
    "[{AddBeads; 5; Engage; 3; …}, {AddBeads; 5; Engage; 3; …}]";
  let washed =
    "{Ethanol; ChangeTip; Ethanol; 2; (0 | 1); ChangeTip; Ethanol; (0 | 1)}"
  in
  check Beginning washed "{Ethanol; ChangeTip; Ethanol; 2; …}";
  check End washed "{…; ChangeTip; Ethanol; (0 | 1)}";
  check Beginning "{(Aaaa; Bbbb; Cccc; Dddd; Eeee; Ffff); Gggg; Hhhh}"
    "{(Aaaa; Bbbb; Cccc; Dddd; Eeee; Ffff); …}";
  check End "[{AddBeads; 5}, {AddBeads; 5}]" "[{AddBeads; 5}, {AddBeads; 5}]";
  check End "[7, 7]" "[7, 7]";
  check Beginning "[{RemoveSupernatantAndDiscardTheLiquidPhase}, {0}]"
    "[{RemoveSupernatantAndDiscardTheLiquidPhase}, {0}]";
  let long =
    String.concat "" (List.init 50 (fun i -> string_of_int (i mod 10)))
  in
  check End long ("…" ^ String.sub long 11 39);
  check Beginning long (String.sub long 0 39 ^ "…");
  (* the grade shortened as a whole *)
  let total keep n grade expected =
    let shortened = Timeline.shorten_total keep n grade in
    if shortened <> expected then
      fail "shorten_total %d %s: differs from the expectation" n grade
  in
  let both = "[" ^ washed ^ ", " ^ washed ^ "]" in
  total Beginning 28 both (Some "[{Ethanol; …}, {Ethanol; …}]");
  total End 28 both (Some "[{…; (0 | 1)}, {…; (0 | 1)}]");
  total Beginning 60 both
    (Some "[{Ethanol; ChangeTip; …}, {Ethanol; ChangeTip; …}]");
  total Beginning 200 both (Some both);
  total Beginning 20 both None;
  total Beginning 20 long (Some (String.sub long 0 19 ^ "…"));
  total Beginning 1 long None;
  (* the event cell of a box row fits the limit, or loses its grade *)
  let box name =
    let t =
      Timeline.observe
        (Boxed { at = "0"; resource = "r"; name; grade = both })
        Timeline.empty
    in
    match (Timeline.report t).rows with
    | [ { short = [ _; _; event; _ ]; _ } ] -> event
    | _ ->
        fail "box row";
        ""
  in
  if box "washed" <> "box washed with grade [{Ethanol; …}, {Ethanol; …}]" then
    fail "box event: %s" (box "washed");
  if
    box "aVeryLongNameOfABoundResource"
    <> "box aVeryLongNameOfABoundResource with grade …"
  then fail "box event: %s" (box "aVeryLongNameOfABoundResource")

(* The registry *)

let () =
  if BackendRegistry.default.key <> "interpreter" then fail "default backend";
  if BackendRegistry.find "opentrons" = None then fail "no Opentrons backend";
  let inputs = BackendRegistry.opentrons.inputs in
  if BackendRegistry.setting inputs [] "robot" <> "flex" then
    fail "the robot's default";
  if
    BackendRegistry.setting inputs [ ("time-unit", "hours") ] "time-unit"
    <> "hours"
  then fail "the time unit set";
  if BackendRegistry.setting inputs [] "colour" <> "" then fail "an unknown key";
  (* the title of the Opentrons timeline states the time unit *)
  let title (entry : BackendRegistry.entry) settings =
    match entry.observer with
    | Some make -> (Lazy.force (make settings).report).title
    | None -> ""
  in
  List.iter
    (fun (unit, expected) ->
      let t = title BackendRegistry.opentrons [ ("time-unit", unit) ] in
      if t <> expected then fail "Opentrons title: %s, not %s" t expected)
    [
      ("seconds", "Timeline (one time unit = 1 s)");
      ("minutes", "Timeline (one time unit = 1 min)");
      ("hours", "Timeline (one time unit = 1 h)");
    ];
  if title BackendRegistry.default [] <> "Timeline" then
    fail "the interpreter's title";
  (* the interpreter's timeline folded, that of Opentrons unfolded, both in
     grades whatever the time unit *)
  let report (entry : BackendRegistry.entry) settings =
    match entry.observer with
    | None ->
        fail "%s: no observer" entry.key;
        None
    | Some make ->
        let observer = make settings in
        let observer = observer.observe (Delayed { at = "0"; grade = "2" }) in
        let observer = observer.observe (Returned { at = "2"; value = "()" }) in
        Some (observer.expanded, Lazy.force observer.report)
  in
  let delay_row : BackendRegistry.row list -> bool = function
    | [ { cells = [ "1"; "0"; "delay"; "2" ]; depth = 0; status = Plain; _ } ]
      ->
        true
    | _ -> false
  in
  (match report BackendRegistry.interpreter [] with
  | Some (false, { rows; notes = [ "Run 1 returned () at 2." ]; _ })
    when delay_row rows ->
      ()
  | Some _ -> fail "the interpreter's timeline"
  | None -> ());
  match report BackendRegistry.opentrons [ ("time-unit", "minutes") ] with
  | Some (true, { rows; notes = [ "Run 1 returned () at 2." ]; _ })
    when delay_row rows ->
      ()
  | Some _ -> fail "the Opentrons timeline"
  | None -> ()

(* The Opentrons examples *)

let root = Filename.concat (Sys.getcwd ()) "../.."

let read path =
  In_channel.with_open_text (Filename.concat root path) In_channel.input_all

let text_of_row (row : BackendRegistry.row) = String.concat " | " row.cells

let run_example (entry : ExampleIndex.entry) =
  match List.assoc_opt entry.grade Grades.GradeRegistry.grade_modules with
  | None -> fail "%s: unknown grade" entry.path
  | Some (module G : Grade.S) -> (
      let module B = WebInterpreter.Make (Grades.GradeSystem.Identity (G)) in
      let module L = Loader.Loader (B) in
      let settings =
        List.map
          (fun (k, v) -> if k = "binding" then (k, read v) else (k, v))
          entry.settings
      in
      let program =
        L.load_program ~use_stdlib:true [ L.parse_source (read entry.path) ]
      in
      if program.diagnostics <> [] then fail "%s: rejected" entry.path
      else
        let operations = program.operations in
        (* the interpreter's first step at each state, observed *)
        let rec go observer (rs : B.run_state) =
          match B.steps rs with
          | [] -> observer
          | step :: _ ->
              go
                (List.fold_left
                   (fun (o : BackendRegistry.observer) -> o.observe)
                   observer (B.observe rs step))
                (step.next_state ())
        in
        match BackendRegistry.opentrons.observer with
        | None -> fail "the Opentrons backend has no observer"
        | Some make -> (
            let observer = go (make settings) (B.run program.loaded.backend) in
            let report = Lazy.force observer.report in
            if verbose then begin
              print_endline entry.path;
              List.iter (fun row -> print_endline (text_of_row row)) report.rows;
              List.iter print_endline report.notes
            end;
            if report.rows = [] then fail "%s: no operation recorded" entry.path;
            if report.columns <> [ "Run"; "Start"; "Event"; "Grade" ] then
              fail "%s: columns" entry.path;
            (* every call finished, a grade exactly for the rows other than
               boxes and unboxes, and a start for exactly the rows at the top
               level *)
            let rec resource event =
              if String.starts_with ~prefix:"· " event then
                resource (String.sub event 3 (String.length event - 3))
              else
                String.starts_with ~prefix:"box " event
                || String.starts_with ~prefix:"unbox " event
            in
            List.iter
              (fun (row : BackendRegistry.row) ->
                match (row.status, row.cells) with
                | Plain, [ _; start; event; grade ]
                  when grade = "" = resource event
                       && start = "" = (row.depth > 0) ->
                    ()
                | _ -> fail "%s: %s" entry.path (text_of_row row))
              report.rows;
            if
              not
                (List.exists
                   (fun note ->
                     String.starts_with ~prefix:"Run 1 returned" note)
                   report.notes)
            then fail "%s: %s" entry.path (String.concat " " report.notes);
            match BackendRegistry.opentrons.compiler with
            | None -> fail "the Opentrons backend has no compiler"
            | Some compiler ->
                let check name (output : BackendRegistry.compiled) =
                  if
                    output.code = None
                    || List.exists
                         (fun (m : BackendRegistry.message) ->
                           m.severity = BackendRegistry.Error)
                         output.messages
                  then fail "%s: not compiled %s" entry.path name
                in
                check "with its binding"
                  (compiler.compile settings ~operations
                     ~compound:program.compound_operations ~definitions:[]
                     program.commands);
                check "without a binding"
                  (compiler.compile [] ~operations
                     ~compound:program.compound_operations ~definitions:[]
                     program.commands)))

(* Programs run by an interpreter *)

(* The observations of the steps of the runs of [source] under the grade
   [grade], by the first step at each state, of the command-line interpreter
   if [cli], else of the web interpreter. *)
let observations ?(cli = false) grade source =
  match List.assoc_opt grade Grades.GradeRegistry.grade_modules with
  | None ->
      fail "%s: unknown grade" grade;
      []
  | Some (module G : Grade.S) ->
      let module GS = Grades.GradeSystem.Identity (G) in
      let observe (type rs st) ~steps ~observe ~next ~start =
        let rec go acc (rs : rs) =
          match (steps rs : st list) with
          | [] -> List.rev acc
          | step :: _ -> go (List.rev_append (observe rs step) acc) (next step)
        in
        go [] start
      in
      if cli then
        let module B = CliInterpreter.Make (GS) in
        let module L = Loader.Loader (B) in
        let program =
          L.load_program ~use_stdlib:true [ L.parse_source source ]
        in
        if program.diagnostics <> [] then (
          fail "%s: rejected" grade;
          [])
        else
          observe ~steps:B.steps ~observe:B.observe
            ~next:(fun (step : B.step) -> step.next_state ())
            ~start:(B.run program.loaded.backend)
      else
        let module B = WebInterpreter.Make (GS) in
        let module L = Loader.Loader (B) in
        let program =
          L.load_program ~use_stdlib:true [ L.parse_source source ]
        in
        if program.diagnostics <> [] then (
          fail "%s: rejected" grade;
          [])
        else
          observe ~steps:B.steps ~observe:B.observe
            ~next:(fun (step : B.step) -> step.next_state ())
            ~start:(B.run program.loaded.backend)

let timeline observations =
  List.fold_left (Fun.flip Timeline.observe) Timeline.empty observations

let check_entries name t expected =
  let entries = List.map show_entry (Timeline.entries t) in
  if verbose then List.iter print_endline entries;
  if entries <> expected then fail "%s: %s" name (String.concat "; " entries)

(* A default implementation that performs an operation, and a run that ends
   at an operation with neither a handler nor a default implementation. The
   delays of a default implementation and the declared grades of the calls it
   performs make up its grade; only calls at the top level add to the
   accumulated grade. *)
let nested =
  {|operation Inner : unit ~> unit # [1, 2]
default Inner () = delay 1

operation Outer : unit ~> unit # [2, 4]
default Outer () = delay 1; perform Inner (); delay 1

operation Missing : unit ~> unit # [0, 1]

run perform Outer (); delay 5; perform Outer ()
run perform Outer (); perform Missing ()
|}

let () =
  let t = timeline (observations "time-interval" nested) in
  check_entries "nested" t
    [
      "1 0 [0, 0] Outer [2, 4] +";
      "1 1 [0, 0] delay [1, 1]";
      "1 1 [0, 0] Inner [1, 2] +";
      "1 2 [0, 0] delay [1, 1]";
      "1 1 [0, 0] delay [1, 1]";
      "1 0 [2, 4] delay [5, 5]";
      "1 0 [7, 9] Outer [2, 4] +";
      "1 1 [7, 9] delay [1, 1]";
      "1 1 [7, 9] Inner [1, 2] +";
      "1 2 [7, 9] delay [1, 1]";
      "1 1 [7, 9] delay [1, 1]";
      "2 0 [0, 0] Outer [2, 4] +";
      "2 1 [0, 0] delay [1, 1]";
      "2 1 [0, 0] Inner [1, 2] +";
      "2 2 [0, 0] delay [1, 1]";
      "2 1 [0, 0] delay [1, 1]";
    ];
  match Timeline.runs t with
  | [
   { outcome = Returned "()"; at = "[9, 13]"; _ };
   { outcome = Stopped "Missing"; at = "[2, 4]"; _ };
  ] ->
      ()
  | _ -> fail "nested: the runs ended"

(* The chain of default implementations of tests/default_chain.tpe, through
   the observer of the interpreter's entry of the registry. *)
let () =
  match BackendRegistry.interpreter.observer with
  | None -> fail "the interpreter has no observer"
  | Some make ->
      let observer =
        List.fold_left
          (fun (o : BackendRegistry.observer) -> o.observe)
          (make [])
          (observations "time-lower-bound" (read "tests/default_chain.tpe"))
      in
      let report = Lazy.force observer.report in
      let rows =
        List.map
          (fun (row : BackendRegistry.row) ->
            Printf.sprintf "%s %d" (text_of_row row) row.depth)
          report.rows
      in
      if
        rows
        <> [
             "1 | 0 | Ask | 3 0";
             "1 |  | · delay | 1 1";
             "1 |  | · Load | 2 1";
             "1 |  | · · Store | 1 2";
             "1 |  | · · · delay | 1 3";
             "1 |  | · · Store | 1 2";
             "1 |  | · · · delay | 1 3";
             "2 | 0 | delay | 1 0";
           ]
      then fail "default chain: %s" (String.concat "; " rows);
      if report.notes <> [ "Run 1 returned 2 at 3."; "Run 2 returned () at 1." ]
      then fail "default chain: %s" (String.concat " " report.notes)

(* Boxes and unboxes *)

(* The boxes and unboxes the command-line interpreter observes in the runs of
   [source] under the grade [grade], with their final names. *)
let check_boxes name grade source expected =
  let shown =
    List.filter_map
      (fun (e : Timeline.entry) ->
        match e.event with
        | Box { name; grade; _ } -> Some (Printf.sprintf "box %s %s" name grade)
        | Unbox { name; _ } -> Some (Printf.sprintf "unbox %s" name)
        | Call _ | Delay _ -> None)
      (Timeline.entries (timeline (observations ~cli:true grade source)))
  in
  if verbose then List.iter print_endline shown;
  if shown <> expected then fail "%s: %s" name (String.concat "; " shown)

(* Nested boxes, a box inside the continuation of a call performed by its
   default implementation, an immediate unbox, a box named by the [let]
   binding it, a handled operation, whose continuation is not shown, and a box
   passed to that continuation, named by the [let] binding the result of the
   call. *)
let nested_boxes ~op ~outer ~inner ~unit ~handled =
  Printf.sprintf
    {|operation Op : unit ~> unit # %s
default Op () = delay 2

operation Get : unit ~> [%s]unit # %s

run
  box %s () as p in
  delay 1;
  box %s () as q in
  perform Op ();
  unbox q as _ in
  let b = box %s () in
  unbox b as _ in
  unbox p as _ in
  ()

run
  handle (perform Op (); delay 1)
  with handler
  | x -> x
  | Op () k -> delay %s; continue k with ()

run
  handle (let got = perform Get () in unbox got as _ in ())
  with handler
  | x -> x
  | Get () k -> delay %s; continue k with (box %s ())
|}
    op unit op outer inner unit handled handled unit

let () =
  check_boxes "time-interval" "time-interval"
    (nested_boxes ~op:"[2, 3]" ~outer:"[3, 5]" ~inner:"[2, 3]" ~unit:"[0, 0]"
       ~handled:"2")
    [
      "box p [3, 5]";
      "box q [2, 3]";
      "unbox q";
      "box b [0, 0]";
      "unbox b";
      "unbox p";
      "box got [0, 0]";
      "unbox got";
    ];
  let t =
    timeline
      (observations ~cli:true "time-interval"
         (nested_boxes ~op:"[2, 3]" ~outer:"[3, 5]" ~inner:"[2, 3]"
            ~unit:"[0, 0]" ~handled:"2"))
  in
  let text = Timeline.text (Timeline.report ~run:1 t) in
  let expected =
    String.concat "\n"
      [
        "Timeline";
        "Run  Start   Event                    Grade";
        "1    [0, 0]  box p with grade [3, 5]";
        "1    [0, 0]  delay                    [1, 1]";
        "1    [1, 1]  box q with grade [2, 3]";
        "1    [1, 1]  Op                       [2, 3]";
        "1            · delay                  [2, 2]";
        "1    [3, 4]  unbox q";
        "1    [3, 4]  box b with grade [0, 0]";
        "1    [3, 4]  unbox b";
        "1    [3, 4]  unbox p";
        "Run 1 returned () at [3, 4].";
        "";
      ]
  in
  if text <> expected then fail "time-interval text:\n%s" text;
  let text = Timeline.text (Timeline.report ~run:2 t) in
  let expected =
    String.concat "\n"
      [
        "Timeline";
        "Run  Start   Event  Grade";
        "2    [0, 0]  delay  [2, 2]";
        "2    [2, 2]  delay  [1, 1]";
        "Run 2 returned () at [3, 3].";
        "";
      ]
  in
  if text <> expected then fail "time-interval handled text:\n%s" text

let () =
  check_boxes "time-lower-bound" "time-lower-bound"
    (nested_boxes ~op:"2" ~outer:"3" ~inner:"2" ~unit:"0" ~handled:"2")
    [
      "box p 3";
      "box q 2";
      "unbox q";
      "box b 0";
      "unbox b";
      "unbox p";
      "box got 0";
      "unbox got";
    ]

(* Under the security levels the delays are unit grades. *)
let () =
  check_boxes "security-levels" "security-levels"
    {|operation Read : unit ~> nat # Low
default Read () = delay 1; 7

run
  box High () as h in
  box Low () as l in
  let n = perform Read () in
  delay 2;
  unbox l as _ in
  unbox h as _ in
  n
|}
    [ "box h High"; "box l Low"; "unbox l"; "unbox h" ]

(* The conversions between natural numbers and floats, with natural numbers
   beyond 32 bits, and the square root and the arctangent of two floats. *)
let () =
  let returned =
    List.filter_map
      (function Backend.Returned { value; _ } -> Some value | _ -> None)
      (observations "time-interval"
         {|let rec power (n : nat) = match n with 0 -> 1 | m + 1 -> 10 * power m

run nat_of_float (float_of_nat 9007199254740993)
run (nat_of_float 4294967296.0, nat_of_float 1e20)
run (float_of_nat (power 308), float_of_nat (power 309))
run (nat_of_float (~-. 2.5), nat_of_float (0.0 /. 0.0))
run (sqrt 2.25, sqrt (~-. 1.0), atan2 (1.0, ~-. 1.0))
|})
  in
  let expected =
    [
      "9007199254740992";
      "(4294967296, 100000000000000000000)";
      "(1e+308, infinity)";
      "(0, 0)";
      "(1.5, nan, 2.35619449019)";
    ]
  in
  if returned <> expected then
    fail "conversions: %s" (String.concat "; " returned)

(* Integers beyond 32 bits, division and modulo truncated toward zero, and
   the conversions of integers. *)
let () =
  let returned =
    List.filter_map
      (function Backend.Returned { value; _ } -> Some value | _ -> None)
      (observations "time-interval"
         {|run (4294967296i *! -4294967296i, -7i /! 2i, -7i mod! 2i, ~-!(-3i))
run (int_of_nat 4294967296, nat_of_int (-4294967296i), nat_of_int 5i)
run (int_of_float (~-. 1e20), int_of_float (~-. 2.75), float_of_int (-3i))
|})
  in
  let expected =
    [
      "(-18446744073709551616i, -3i, -1i, 3i)";
      "(4294967296i, 0, 5)";
      "(-100000000000000000000i, -2i, -3.)";
    ]
  in
  if returned <> expected then fail "integers: %s" (String.concat "; " returned)

(* The Arduino backend *)

let arduino_compiler =
  match BackendRegistry.arduino.compiler with
  | Some compiler -> compiler
  | None -> failwith "the Arduino backend has no compiler"

let has_error (output : BackendRegistry.compiled) =
  List.exists
    (fun (m : BackendRegistry.message) -> m.severity = BackendRegistry.Error)
    output.messages

let error_text (output : BackendRegistry.compiled) =
  String.concat "\n"
    (List.map (fun (m : BackendRegistry.message) -> m.text) output.messages)

let contains ~sub s =
  let n = String.length s and m = String.length sub in
  let rec go i = i + m <= n && (String.sub s i m = sub || go (i + 1)) in
  go 0

(* The program [source], after the declarations of the Arduino backend under
   [settings] and [grade], loaded by the web interpreter, run with the
   observer of the backend by the first step at each state, which must record
   an operation if [observed], and compiled with each of [variants], a list
   of settings and a check of the output; [name] names it in failures. *)
let arduino_program ~name ~grade ~settings ?(observed = false) variants source =
  match List.assoc_opt grade Grades.GradeRegistry.grade_modules with
  | None -> fail "%s: unknown grade" name
  | Some (module G : Grade.S) -> (
      let module B = WebInterpreter.Make (Grades.GradeSystem.Identity (G)) in
      let module L = Loader.Loader (B) in
      match BackendRegistry.arduino.declarations settings ~grades:grade with
      | Error message -> fail "%s: %s" name message
      | Ok declarations ->
          let program =
            L.load_program ~use_stdlib:true
              (List.map
                 (fun (d : BackendRegistry.source) ->
                   L.parse_source ~filename:d.filename d.text)
                 declarations
              @ [ L.parse_source source ])
          in
          if program.diagnostics <> [] then fail "%s: rejected" name
          else
            let definitions =
              List.map
                (fun (d : L.definition) ->
                  ( d.variable,
                    match
                      L.TC.function_effect program.loaded.typechecker d.scheme
                    with
                    | Typechecker.Not_a_function ->
                        BackendRegistry.Not_a_function
                    | Typechecker.Effect_variable -> Effect_variable
                    | Typechecker.Effect { grade; durations } ->
                        Effect { grade; durations } ))
                program.definitions
            in
            let compile settings =
              arduino_compiler.compile settings ~operations:program.operations
                ~compound:program.compound_operations ~definitions
                program.commands
            in
            (match BackendRegistry.arduino.observer with
            | None -> fail "the Arduino backend has no observer"
            | Some make ->
                let rec go observer (rs : B.run_state) =
                  match B.steps rs with
                  | [] -> observer
                  | step :: _ ->
                      go
                        (List.fold_left
                           (fun (o : BackendRegistry.observer) -> o.observe)
                           observer (B.observe rs step))
                        (step.next_state ())
                in
                let report =
                  Lazy.force
                    (go (make settings) (B.run program.loaded.backend)).report
                in
                if observed && report.rows = [] then
                  fail "%s: no operation recorded" name);
            List.iter
              (fun (variant, check) ->
                let output = compile variant in
                if verbose then begin
                  print_endline (Option.value output.code ~default:"");
                  print_endline (error_text output)
                end;
                if not (check output) then
                  fail "%s: variant %s" name
                    (String.concat " " (List.map (fun (k, _) -> k) variant)))
              variants)

(* The Arduino examples, with their manifests and binding files: compiled to
   the files of the project shown, each warning located in the program, those
   of bala2-regex about its handler [simulated_robot], which no task uses;
   without the binding file, refused at the
   manifest; without a manifest, compiled to the program alone, or, if the
   program defines a handler that is not tail-resumptive, which only the
   definitions of the tasks of the manifest may leave out, refused at it. *)
let arduino_example (entry : ExampleIndex.entry) =
  let settings = List.map (fun (k, v) -> (k, read v)) entry.settings in
  let source = read entry.path in
  let has_files names (output : BackendRegistry.compiled) =
    match output.code with
    | Some code ->
        List.for_all (fun name -> contains ~sub:("// File " ^ name) code) names
        && output.language = "cpp"
        && not (has_error output)
    | None -> false
  in
  let warnings (output : BackendRegistry.compiled) =
    List.filter
      (fun (m : BackendRegistry.message) ->
        m.severity = BackendRegistry.Warning)
      output.messages
  in
  let warned (output : BackendRegistry.compiled) =
    List.for_all
      (fun (m : BackendRegistry.message) ->
        match m.diagnostic with
        | Some { kind = Warning; primary = Some loc; message; _ } ->
            loc.filename = ""
            && ((not (contains ~sub:"bala2-regex" entry.path))
               || contains ~sub:"`simulated_robot`" message)
        | _ -> false)
      (warnings output)
    && (warnings output <> [] || not (contains ~sub:"bala2-regex" entry.path))
  in
  arduino_program ~name:entry.path ~grade:entry.grade ~settings ~observed:true
    [
      ( settings,
        fun output ->
          has_files
            [
              "platformio.ini";
              "src/main.cpp";
              "src/tempore_program.h";
              "src/tempore_program.cpp";
              "src/tempore_bindings.h";
              "src/tempore_operations.cpp";
            ]
            output
          && warned output );
      ( List.remove_assoc "bindings" settings,
        fun output ->
          output.code = None && contains ~sub:"device.json" (error_text output)
      );
      ( List.remove_assoc "manifest" settings,
        fun output ->
          match output.code with
          | None ->
              contains ~sub:"handler\n" source
              && contains ~sub:"cannot be compiled to direct calls"
                   (error_text output)
          | Some code ->
              has_files [ "tempore_program.h"; "tempore_program.cpp" ] output
              && not (contains ~sub:"// File src/main.cpp" code) );
    ]
    source

(* Errors of the Arduino backend: a malformed manifest, located in the file of
   the manifest input, a task function the program lacks, a construct outside
   the fragment, located in the program, an unknown package, which loads no
   declarations, a package listed twice, which loads them once, and packages
   under grades they are not declared under. *)
let () =
  let manifest text = [ ("manifest", text) ] in
  let refused ~sub (output : BackendRegistry.compiled) =
    output.code = None && has_error output && contains ~sub (error_text output)
  in
  (* every error carries a diagnostic located in the file [file] *)
  let located ~file (output : BackendRegistry.compiled) =
    List.for_all
      (fun (m : BackendRegistry.message) ->
        m.severity <> BackendRegistry.Error
        ||
        match m.diagnostic with
        | Some { primary = Some loc; _ } -> loc.filename = file
        | _ -> false)
      output.messages
  in
  (match
     ( BackendRegistry.input_of_file "device.json",
       BackendRegistry.input_of_file "" )
   with
  | Some { key = "manifest"; _ }, None -> ()
  | _ -> fail "the inputs of the files of diagnostics");
  arduino_program ~name:"a program of nats" ~grade:"time-interval-rational"
    ~settings:[]
    [
      ([], fun output -> output.code <> None && not (has_error output));
      ( manifest "{ \"board\": ",
        fun output ->
          refused ~sub:"device.json" output
          && located ~file:"device.json" output );
      ( manifest
          {|{ "board": "esp32-devkit", "tasks": [ { "function": "missing", "kind": "free" } ] }|},
        refused ~sub:"missing" );
    ]
    "let double (n : nat) = n + n\nrun double 2";
  arduino_program ~name:"a local function" ~grade:"time-interval-rational"
    ~settings:[]
    [
      ( [],
        fun output ->
          refused ~sub:"Compilation error" output && located ~file:"" output );
    ]
    "let twice (n : nat) = let f (m : nat) = m + m in f n\nrun twice 2";
  (* A handler that is not tail-resumptive: a warning located in the program
     when no task uses it, the project compiled; an error when one does. *)
  let free task =
    manifest
      (Printf.sprintf
         {|{ "board": "esp32-devkit", "tasks": [ { "function": "%s", "kind": "free" } ] }|}
         task)
  in
  let warned (output : BackendRegistry.compiled) =
    output.code <> None
    && (not (has_error output))
    &&
    match
      List.filter
        (fun (m : BackendRegistry.message) ->
          m.severity = BackendRegistry.Warning)
        output.messages
    with
    | [
     {
       diagnostic = Some { kind = Warning; primary = Some loc; message; _ };
       text;
       _;
     };
    ] ->
        loc.filename = "" && loc.start.line = 6
        && contains ~sub:"The handler `counted` is not tail-resumptive" message
        && contains ~sub:"Warning: The handler `counted`" text
    | _ -> false
  in
  arduino_program ~name:"a handler not tail-resumptive"
    ~grade:"time-interval-rational" ~settings:[]
    [
      (free "pause", warned);
      ( free "counting",
        fun output ->
          refused ~sub:"resumed outside tail position" output
          && located ~file:"" output );
    ]
    "operation Pause : unit ~> unit # [1, 1]\n\
     let counted =\n\
    \  handler\n\
    \  | r -> (r, 0)\n\
    \  | Pause () k ->\n\
    \      let r, n = continue k with delay 1 in\n\
    \      (r, n + 1)\n\
     let pause () = delay 1\n\
     let counting () = handle perform Pause () with counted\n";
  let gray packages =
    manifest
      (Printf.sprintf
         {|{ "board": "m5stack-gray", "tasks": [ { "function": "f", "kind": "free" } ], "packages": %s }|}
         packages)
  in
  (match
     BackendRegistry.arduino.declarations
       (gray {|["m5-imu", "nowhere", "m5-imu"]|})
       ~grades:"time-interval-rational"
   with
  | Ok [ definitions; declarations ]
    when contains ~sub:"m5_imu_filter.tpe" definitions.filename
         && contains ~sub:"m5_imu.tpe" declarations.filename ->
      ()
  | Ok sources ->
      fail "the declarations of the packages: %s"
        (String.concat ", "
           (List.map (fun (d : BackendRegistry.source) -> d.filename) sources))
  | Error message -> fail "the declarations of the packages: %s" message);
  (match
     BackendRegistry.arduino.declarations (gray {|["m5-imu"]|})
       ~grades:"time-interval"
   with
  | Error _ -> ()
  | Ok _ -> fail "m5-imu loaded under time-interval");
  (match
     BackendRegistry.arduino.declarations (gray {|["m5-imu"]|})
       ~grades:"counts-upper-bound"
   with
  | Ok [ _; declarations ]
    when contains ~sub:"m5_imu_counts.tpe" declarations.filename ->
      ()
  | _ -> fail "the declarations of m5-imu under counts-upper-bound");
  match
    BackendRegistry.arduino.declarations
      (manifest "not a manifest")
      ~grades:"time-interval-rational"
  with
  | Ok [] -> ()
  | _ -> fail "the declarations of a malformed manifest"

let () =
  let _, entries, _ =
    ExampleIndex.read (Filename.concat root "examples/index")
  in
  List.iter run_example
    (List.filter
       (fun (e : ExampleIndex.entry) -> e.backend = "opentrons")
       entries);
  let arduino =
    List.filter (fun (e : ExampleIndex.entry) -> e.backend = "arduino") entries
  in
  if List.length arduino < 2 then fail "the Arduino examples are missing";
  List.iter arduino_example arduino;
  TestSupport.Failures.finish ()
