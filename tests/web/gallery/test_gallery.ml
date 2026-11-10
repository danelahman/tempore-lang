(* Tests of the examples of the web interface's gallery under the grade
   systems their rows of the example index name: the grade algebras of each
   row those of the header of its example; each example loaded as the web
   interface loads it, after the declarations of its backend under its
   inputs, under the grade system of its grades and resource grades
   (Grades.GradeSystemRegistry.select), and accepted; an example of a grade
   system other than an identity one also run to its end, and checked under
   the identity grade system of its effect grade algebra, with the verdict
   [identity_verdicts] gives. Silent on success. *)

let fail = TestSupport.Failures.fail
let root = Filename.concat (Sys.getcwd ()) "../../.."

let read path =
  In_channel.with_open_text (Filename.concat root path) In_channel.input_all

(* The inputs of [entry], the text of a text input read from its file. *)
let settings (entry : ExampleIndex.entry) =
  let backend = Option.get (BackendRegistry.find entry.backend) in
  List.map
    (fun (key, value) ->
      match
        List.find_opt
          (fun (input : BackendRegistry.input) -> input.key = key)
          backend.inputs
      with
      | Some { kind = Text; _ } -> (key, read value)
      | _ -> (key, value))
    entry.settings

(* Whether each example of a grade system other than an identity one is
   accepted under the identity grade system of its effect grade algebra: the
   box grades of the bread proofing and of the session key are not literals of
   the effect grade algebra, while those of the access token and of the latte
   are, and their unboxes are within them there too. *)
let identity_verdicts =
  [
    ("examples/grade_systems/proofing.tpe", false);
    ("examples/grade_systems/token.tpe", true);
    ("examples/grade_systems/latte.tpe", true);
    ("examples/grade_systems/session_key.tpe", false);
  ]

(* The number of steps a run of an example is allowed before it counts as
   not terminating. *)
let step_limit = 100_000

(* [entry] loaded under its grades and the resource grades [resources]: the
   diagnostics reported, and whether a run, taking the first step at each
   state, ends within [step_limit] steps, if [run]. *)
let load ?(run = false) (entry : ExampleIndex.entry) resources =
  let backend = Option.get (BackendRegistry.find entry.backend) in
  match backend.declarations (settings entry) ~grades:entry.grade with
  | Error message -> Error message
  | Ok declared -> (
      let source = read entry.path in
      let grades, lattice =
        Loader.grades_of_sources ~grades:entry.grade
          (List.map
             (fun (d : BackendRegistry.source) -> (d.filename, d.text))
             declared
          @ [ ("", source) ])
      in
      match
        Grades.GradeSystemRegistry.select ?lattice ~effects:entry.grade
          ~resources grades
      with
      | Error message -> Error message
      | Ok (module GS) ->
          let module B = WebInterpreter.Make (GS) in
          let module L = Loader.Loader (B) in
          let program =
            L.load_program ~use_stdlib:true
              (List.map
                 (fun (d : BackendRegistry.source) ->
                   L.parse_source ~filename:d.filename
                     ~running_times:d.running_times d.text)
                 declared
              @ [ L.parse_source source ])
          in
          let rec ends n rs =
            n < step_limit
            &&
            match B.steps rs with
            | [] -> B.is_done rs
            | step :: _ -> ends (n + 1) (step.next_state ())
          in
          Ok
            ( program.diagnostics,
              (not run)
              || program.diagnostics = []
                 && ends 0 (B.run program.loaded.backend) ))

let () =
  let _, entries, _ =
    ExampleIndex.read (Filename.concat root "examples/index")
  in
  List.iter
    (fun (entry : ExampleIndex.entry) ->
      let path = Filename.concat root entry.path in
      if TestSupport.Header.grades path <> entry.grade then
        fail "%s: the grades %s of its row are not those of its header"
          entry.path entry.grade;
      if TestSupport.Header.resource_grades path <> entry.resources then
        fail "%s: the resource grades of its row are not those of its header"
          entry.path;
      let run = Option.is_some entry.resources in
      (match load ~run entry entry.resources with
      | Ok ([], true) -> ()
      | Ok ([], false) -> fail "%s: its run does not end" entry.path
      | Ok (_ :: _, _) -> fail "%s: rejected under its grade system" entry.path
      | Error message -> fail "%s: %s" entry.path message
      | exception exn -> fail "%s: %s" entry.path (Printexc.to_string exn));
      if run then
        let accepted =
          match load entry None with
          | Ok (diagnostics, _) -> Ok (diagnostics = [])
          | Error message -> Error message
          | exception Utils.Error.Error _ -> Ok false
        in
        match (accepted, List.assoc_opt entry.path identity_verdicts) with
        | Ok verdict, Some expected when verdict = expected -> ()
        | Ok verdict, Some _ ->
            fail "%s: %s under the identity grade system" entry.path
              (if verdict then "accepted" else "rejected")
        | Ok _, None ->
            fail "%s: no verdict under the identity grade system is expected"
              entry.path
        | Error message, _ -> fail "%s: %s" entry.path message)
    entries;
  let systems =
    List.filter
      (fun (e : ExampleIndex.entry) -> Option.is_some e.resources)
      entries
  in
  if List.length systems <> 4 then
    fail "the gallery lists %d examples of grade systems, not 4"
      (List.length systems);
  TestSupport.Failures.finish ()
