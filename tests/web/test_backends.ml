(* Tests of the backend registry of the web interface: the timelines of the
   Opentrons backend, its verdicts at the ends of bounds, and the Opentrons
   examples, run by the interpreter with the observations of each step fed to
   the operation model of the registry, which must finish every call within
   its bounds, and compiled with and without their binding files. Silent on
   success. *)

module Rational = Grades.Rational
module Grade = Grades.Grade
module Timeline = OpentronsBackend.OpentronsTimeline

let failures = ref []
let fail fmt = Format.kasprintf (fun msg -> failures := msg :: !failures) fmt
let verbose = Array.exists (( = ) "-v") Sys.argv
let q = Rational.of_int

(* Timelines *)

let () =
  let t =
    Timeline.empty |> Timeline.perform "A"
    |> Timeline.delay (q 2)
    |> Timeline.perform "B"
    |> Timeline.delay (q 1)
    |> Timeline.resume
    |> Timeline.delay (q 1)
    |> Timeline.resume |> Timeline.resume
    |> Timeline.finish (Returned "()")
    |> Timeline.perform "C"
    |> Timeline.finish (Stopped "D")
  in
  let show (c : Timeline.call) =
    Printf.sprintf "%d %s %d %s %s" c.run c.op c.depth (Rational.show c.start)
      (Option.fold ~none:"-" ~some:Rational.show c.elapsed)
  in
  let calls = List.map show (Timeline.calls t) in
  if calls <> [ "1 A 0 0 4"; "1 B 1 2 1"; "2 C 0 4 -" ] then
    fail "timeline: %s" (String.concat "; " calls);
  (match Timeline.runs t with
  | [
   { index = 1; outcome = Returned "()"; at = a };
   { index = 2; outcome = Stopped "D"; at = b };
  ]
    when Rational.equal a (q 4) && Rational.equal b (q 4) ->
      ()
  | _ -> fail "timeline: the runs ended");
  if not (Rational.equal (Timeline.clock t) (q 4)) then fail "timeline: clock"

(* Delays outside every default implementation are entries of their own;
   delays inside one count towards the time of its call. *)
let show_entry = function
  | Timeline.Call c ->
      Printf.sprintf "%d %s %s %s" c.run c.op (Rational.show c.start)
        (Option.fold ~none:"-" ~some:Rational.show c.elapsed)
  | Timeline.Delay d ->
      Printf.sprintf "%d delay %s %s" d.run (Rational.show d.start)
        (Rational.show d.duration)

let () =
  let t =
    Timeline.empty
    |> Timeline.delay (q 2)
    |> Timeline.delay (q 3)
    |> Timeline.perform "A"
    |> Timeline.delay (q 1)
    |> Timeline.resume
    |> Timeline.delay (q 4)
    |> Timeline.finish (Returned "()")
    |> Timeline.delay (q 1)
  in
  let entries = List.map show_entry (Timeline.entries t) in
  if
    entries
    <> [
         "1 delay 0 2"; "1 delay 2 3"; "1 A 5 1"; "1 delay 6 4"; "2 delay 10 1";
       ]
  then fail "timeline delays: %s" (String.concat "; " entries);
  if List.length (Timeline.calls t) <> 1 then fail "timeline delays: calls";
  if not (Rational.equal (Timeline.clock t) (q 11)) then
    fail "timeline delays: clock"

let () =
  let check name bounds d expected =
    if Timeline.within bounds (q d) <> expected then
      fail "within %s at %d is not %b" name d expected
  in
  let closed = (Grade.Closed (q 1), Grade.Closed (q 3))
  and opened = (Grade.Open (q 1), Grade.Open (q 3))
  and unbounded = (Grade.Closed (q 2), Grade.Unbounded) in
  List.iter
    (fun (d, e) -> check "[1, 3]" closed d e)
    [ (0, false); (1, true); (2, true); (3, true); (4, false) ];
  List.iter
    (fun (d, e) -> check "(1, 3)" opened d e)
    [ (1, false); (2, true); (3, false) ];
  List.iter
    (fun (d, e) -> check "[2, ∞)" unbounded d e)
    [ (1, false); (2, true); (1000, true) ];
  let call elapsed =
    {
      Timeline.run = 1;
      op = "Op";
      depth = 0;
      start = q 0;
      elapsed = Option.map q elapsed;
    }
  in
  let verdict bounds elapsed = Timeline.verdict bounds (call elapsed) in
  if verdict (Some closed) (Some 2) <> Within then fail "verdict: within";
  if verdict (Some closed) (Some 4) <> Outside then fail "verdict: outside";
  if verdict (Some (Grade.Closed (q 0), Grade.Unbounded)) (Some 9) <> Unchecked
  then fail "verdict: [0, ∞) is monitored";
  if verdict None (Some 9) <> Unchecked then fail "verdict: no bounds";
  if verdict (Some closed) None <> Unfinished then fail "verdict: unfinished"

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
  if BackendRegistry.setting inputs [] "colour" <> "" then fail "an unknown key"

(* The Opentrons examples *)

let root = Filename.concat (Sys.getcwd ()) "../.."

let read path =
  In_channel.with_open_text (Filename.concat root path) In_channel.input_all

let run_example (entry : Manifest.entry) =
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
              let observer =
                Option.fold ~none:observer
                  ~some:observer.BackendRegistry.observe
                  (B.observe rs step.label)
              in
              go observer (step.next_state ())
        in
        match BackendRegistry.opentrons.observer with
        | None -> fail "the Opentrons backend has no operation model"
        | Some make -> (
            let observer =
              go (make settings operations) (B.run program.loaded.backend)
            in
            let report = Lazy.force observer.report in
            if verbose then begin
              print_endline entry.path;
              List.iter
                (fun (row : BackendRegistry.row) ->
                  print_endline (String.concat " | " row.cells))
                report.rows;
              List.iter print_endline report.notes
            end;
            if report.rows = [] then fail "%s: no operation recorded" entry.path;
            (* a call within its bounds, or a delay, unmonitored *)
            List.iter
              (fun (row : BackendRegistry.row) ->
                match (row.status, row.cells) with
                | Good, _ | Plain, [ _; _; "delay"; _; "—"; "—" ] -> ()
                | _ -> fail "%s: %s" entry.path (String.concat " " row.cells))
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
                     ~compound:program.compound_operations program.commands);
                check "without a binding"
                  (compiler.compile [] ~operations
                     ~compound:program.compound_operations program.commands)))

(* A default implementation that performs an operation, and a run that ends
   at an operation with neither a handler nor a default implementation: the
   observations of the interpreter's steps, fed to a timeline. *)
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
  let module B =
    WebInterpreter.Make (Grades.GradeSystem.Identity (Grades.TimeGrades.Interval)) in
  let module L = Loader.Loader (B) in
  let program = L.load_program ~use_stdlib:true [ L.parse_source nested ] in
  if program.diagnostics <> [] then fail "nested: rejected"
  else
    let rec go timeline (rs : B.run_state) =
      match B.steps rs with
      | [] -> timeline
      | step :: _ ->
          let timeline =
            match B.observe rs step.label with
            | Some (Delayed d) -> Timeline.delay d timeline
            | Some (Performed op) -> Timeline.perform op timeline
            | Some Resumed -> Timeline.resume timeline
            | Some (Returned v) -> Timeline.finish (Returned v) timeline
            | Some (Stopped op) -> Timeline.finish (Stopped op) timeline
            | None -> timeline
          in
          go timeline (step.next_state ())
    in
    let t = go Timeline.empty (B.run program.loaded.backend) in
    let show (c : Timeline.call) =
      Printf.sprintf "%d %s %d %s %s" c.run c.op c.depth (Rational.show c.start)
        (Option.fold ~none:"-" ~some:Rational.show c.elapsed)
    in
    let calls = List.map show (Timeline.calls t) in
    let expected =
      [
        "1 Outer 0 0 3";
        "1 Inner 1 1 1";
        "1 Outer 0 8 3";
        "1 Inner 1 9 1";
        "2 Outer 0 11 3";
        "2 Inner 1 12 1";
      ]
    in
    if calls <> expected then fail "nested: %s" (String.concat "; " calls);
    let entries = List.map show_entry (Timeline.entries t) in
    let expected =
      [
        "1 Outer 0 3";
        "1 Inner 1 1";
        "1 delay 3 5";
        "1 Outer 8 3";
        "1 Inner 9 1";
        "2 Outer 11 3";
        "2 Inner 12 1";
      ]
    in
    if entries <> expected then
      fail "nested entries: %s" (String.concat "; " entries);
    match Timeline.runs t with
    | [ { outcome = Returned "()"; _ }; { outcome = Stopped "Missing"; _ } ] ->
        ()
    | _ -> fail "nested: the runs ended"

let () =
  let _, entries, _ = Manifest.read (Filename.concat root "examples/index") in
  List.iter run_example
    (List.filter (fun (e : Manifest.entry) -> e.backend = "opentrons") entries);
  match !failures with
  | [] -> ()
  | failures ->
      List.iter prerr_endline (List.rev failures);
      exit 1
