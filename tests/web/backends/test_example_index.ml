(* Tests of the reading of the example index: the forms of its example
   lines, with and without a backend and settings, the checks of grades,
   backends and settings, and the example index of the repository. Silent on
   success. *)

let fail = TestSupport.Failures.fail
let raises f = match f () with _ -> false | exception Failure _ -> true

let example line =
  match ExampleIndex.line_of_string line with
  | Some (ExampleIndex.Example entry) -> Some entry
  | _ -> None

let () =
  (* five fields: the default backend, no settings *)
  (match example "G | T | time-interval | dir/a.tpe | A description." with
  | Some e ->
      if
        e.backend <> "interpreter" || e.settings <> []
        || e.path <> "examples/dir/a.tpe"
      then fail "five fields: backend %s, path %s" e.backend e.path
  | None -> fail "five fields: not an example");
  (* six fields: a backend, no settings *)
  (match example "G | T | time-interval | a.tpe | D. | opentrons" with
  | Some e ->
      if e.backend <> "opentrons" || e.settings <> [] then
        fail "six fields: backend %s" e.backend
  | None -> fail "six fields: not an example");
  (* seven fields: settings separated by blanks *)
  (match
     example
       "G | T | time-interval | a.tpe | D. | opentrons | binding=b.py  \
        time-unit=minutes"
   with
  | Some e ->
      if e.settings <> [ ("binding", "b.py"); ("time-unit", "minutes") ] then
        fail "seven fields: settings %s"
          (String.concat ";" (List.map (fun (k, v) -> k ^ "=" ^ v) e.settings));
      let e = ExampleIndex.checked e in
      if List.assoc_opt "binding" e.settings <> Some "examples/b.py" then
        fail "checked: the binding is not relative to the project root"
  | None -> fail "seven fields: not an example");
  (* blank lines and comments *)
  if ExampleIndex.line_of_string "   " <> None then fail "a blank line is read";
  if ExampleIndex.line_of_string "# G | T | g | p | d" <> None then
    fail "a comment is read";
  (* malformed lines and settings *)
  List.iter
    (fun line ->
      if not (raises (fun () -> ExampleIndex.line_of_string line)) then
        fail "accepted the malformed line %S" line)
    [
      "G | T | g";
      "G | T | g | p | d | b | s | extra";
      "G | T | time-interval | a.tpe | D. | opentrons | binding";
      "G | T | time-interval | a.tpe | D. | opentrons | =b.py";
    ];
  (* unknown grades, backends, inputs and choices *)
  List.iter
    (fun line ->
      match example line with
      | Some e ->
          if not (raises (fun () -> ExampleIndex.checked e)) then
            fail "checked accepted %S" line
      | None -> fail "not an example: %S" line)
    [
      "G | T | no-such-grade | a.tpe | D.";
      "G | T | time-interval | a.tpe | D. | no-such-backend";
      "G | T | time-interval | a.tpe | D. | opentrons | colour=red";
      "G | T | time-interval | a.tpe | D. | opentrons | robot=ot3";
      "G | T | time-interval | a.tpe | D. | interpreter | binding=b.py";
    ];
  (* the example index of the repository *)
  let root = Filename.concat (Sys.getcwd ()) "../../.." in
  let summaries, entries, defaults =
    ExampleIndex.read (Filename.concat root "examples/index")
  in
  let groups =
    ExampleIndex.summarised summaries (ExampleIndex.group_entries entries)
  in
  (match ExampleIndex.defaults entries defaults with
  | [
   ("interpreter", "examples/introduction/sensor_reading.tpe");
   ("arduino", "examples/arduino/bala2/balance.tpe");
   ("opentrons", "examples/opentrons/elisa.tpe");
  ] ->
      ()
  | _ -> fail "the defaults of the example index are not those expected");
  if
    not
      (raises (fun () ->
           ExampleIndex.defaults entries
             [ "examples/opentrons/elisa.tpe"; "examples/opentrons/beads.tpe" ]))
  then fail "defaults accepted two of one backend";
  if
    not
      (raises (fun () ->
           ExampleIndex.defaults entries [ "examples/opentrons/elisa.tpe" ]))
  then fail "defaults accepted none of the default backend";
  let opentrons =
    List.filter
      (fun (e : ExampleIndex.entry) -> e.backend = "opentrons")
      entries
  in
  if List.length opentrons <> 8 then
    fail "the example index lists %d Opentrons examples, not 8"
      (List.length opentrons);
  List.iter
    (fun (e : ExampleIndex.entry) ->
      match List.assoc_opt "binding" e.settings with
      | Some path ->
          if not (Sys.file_exists (Filename.concat root path)) then
            fail "the binding file %s of %s does not exist" path e.path
      | None -> fail "the Opentrons example %s has no binding file" e.path)
    opentrons;
  if
    not
      (List.for_all
         (fun ((_ : ExampleIndex.summary), es) ->
           List.for_all
             (fun (e : ExampleIndex.entry) ->
               e.backend = (List.hd es : ExampleIndex.entry).backend)
             es)
         groups)
  then fail "a group of the example index mixes backends";
  TestSupport.Failures.finish ()
