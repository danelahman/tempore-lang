(* Tests of the declarations shown above the program: the names of their
   packages, the places of definitions in them, and the links of the names of
   an example of the Arduino backend to the declarations of the packages of
   its manifest. *)

let fail = TestSupport.Failures.fail
let root = Filename.concat (Sys.getcwd ()) "../../.."

let read path =
  In_channel.with_open_bin (Filename.concat root path) In_channel.input_all

let check name ok = if not ok then fail "%s" name

(* The location of the bytes [start, stop) of [text] under [filename]. *)
let location filename text start stop =
  let pos offset =
    let line =
      String.fold_left
        (fun n c -> if c = '\n' then n + 1 else n)
        1 (String.sub text 0 offset)
    in
    { Utils.Location.line; column = 1; offset }
  in
  { Utils.Location.filename; start = pos start; stop = pos stop }

(* Titles and package names. *)
let () =
  check "package of a library file"
    (WebDeclarations.package "libraries/m5-imu/m5_imu.tpe" = "m5-imu");
  check "package of another file"
    (WebDeclarations.package "decls.tpe" = "decls.tpe");
  check "title"
    (WebDeclarations.title
       [
         { filename = "libraries/m5-imu/m5_imu_filter.tpe"; text = "" };
         { filename = "libraries/m5-imu/m5_imu.tpe"; text = "" };
         { filename = "libraries/bala2-base/bala2_base.tpe"; text = "" };
       ]
    = "Package declarations: m5-imu, bala2-base")

(* Places: the line of a value, the lines of an operation continuing its
   command, and none outside the sources. *)
let () =
  let filename = "libraries/p/p.tpe" in
  let text =
    "(* p *)\n\
     let full = 1\n\n\
     operation Show : nat * string ~> unit\n\
    \    # {Show} within (0, 33]\n\
     default Show _ = delay 3\n"
  in
  let sources = [ { WebDeclarations.filename; text } ] in
  let at name =
    let rec find i =
      if String.sub text i (String.length name) = name then i else find (i + 1)
    in
    let start = find 0 in
    location filename text start (start + String.length name)
  in
  (match WebDeclarations.place sources Value (at "full") with
  | Some { line = 2; text = "let full = 1"; span; _ } ->
      check "span of a value"
        (span = ((at "full").start.offset, (at "full").stop.offset))
  | _ -> fail "place of a value");
  (match WebDeclarations.place sources Operation (at "Show") with
  | Some { line = 4; text; filename = f; _ } ->
      check "lines of an operation"
        (text = "operation Show : nat * string ~> unit\n# {Show} within (0, 33]"
        && f = filename)
  | _ -> fail "place of an operation");
  check "place outside the sources"
    (WebDeclarations.place sources Value
       { (at "full") with filename = "other.tpe" }
    = None)

(* The links of a BALA2 example under [grade] to the declarations of its
   packages: each one placed at its name, among them the operation ShowTextAt
   of m5-display with its grade, on one line or two, and the function
   bala2_drive of bala2-base. *)
let bala2 ~grade ~manifest ~program:path =
  let settings = [ ("manifest", read manifest) ] in
  match
    ( List.assoc_opt grade Grades.GradeRegistry.grade_modules,
      BackendRegistry.arduino.declarations settings ~grades:grade )
  with
  | None, _ -> fail "unknown grade %s" grade
  | _, Error message -> fail "declarations: %s" message
  | Some (module G : Grades.Grade.S), Ok declared ->
      let module B = WebInterpreter.Make (Grades.GradeSystem.Identity (G)) in
      let module L = Loader.Loader (B) in
      let program =
        L.load_program ~use_stdlib:true
          (List.map
             (fun (d : BackendRegistry.source) ->
               L.parse_source ~filename:d.filename
                 ~running_times:d.running_times d.text)
             declared
          @ [ L.parse_source (read path) ])
      in
      check (path ^ " is accepted") (program.diagnostics = []);
      let sources =
        List.map
          (fun (d : BackendRegistry.source) ->
            { WebDeclarations.filename = d.filename; text = d.text })
          declared
      in
      let placed =
        List.filter_map
          (fun ({ use; definition; sort } : Desugarer.References.link) ->
            if
              use.filename = ""
              && String.starts_with ~prefix:"libraries/" definition.filename
            then
              match WebDeclarations.place sources sort definition with
              | None ->
                  fail "a link to %s, line %d, unplaced" definition.filename
                    definition.start.line;
                  None
              | Some place ->
                  let source =
                    List.find
                      (fun (s : WebDeclarations.source) ->
                        s.filename = place.filename)
                      sources
                  in
                  let start, stop = place.span in
                  Some (String.sub source.text start (stop - start), place)
            else None)
          program.links
      in
      List.iter
        (fun (name, (place : WebDeclarations.place)) ->
          check
            (Printf.sprintf "the line of %s names it" name)
            (List.exists
               (fun word -> word = name)
               (String.split_on_char ' '
                  (String.map
                     (fun c -> if c = '(' || c = ':' then ' ' else c)
                     place.text))))
        placed;
      (match List.assoc_opt "ShowTextAt" placed with
      | Some place ->
          check "ShowTextAt in m5-display"
            (WebDeclarations.package place.filename = "m5-display"
            && String.starts_with ~prefix:"operation ShowTextAt" place.text
            && String.contains place.text '#')
      | None -> fail "no link to ShowTextAt");
      (match List.assoc_opt "bala2_drive" placed with
      | Some place ->
          check "bala2_drive in bala2-base"
            (WebDeclarations.package place.filename = "bala2-base"
            && String.starts_with ~prefix:"let bala2_drive" place.text)
      | None -> fail "no link to bala2_drive");
      check "a definition of the packages among those of the program"
        (List.exists
           (fun (d : L.definition) ->
             d.at.filename <> ""
             && Language.Ast.Variable.string_of d.variable = "bala2_drive")
           program.definitions)

let () =
  bala2 ~grade:"time-interval-rational"
    ~manifest:"examples/arduino/bala2/balance.device.json"
    ~program:"examples/arduino/bala2/balance.tpe";
  bala2 ~grade:"regex-timed-interval-rational-symbolic"
    ~manifest:"examples/arduino/bala2-regex/balance_regex.device.json"
    ~program:"examples/arduino/bala2-regex/balance_regex.tpe"

let () =
  TestSupport.Failures.finish ~success:"web declarations: all tests passed" ()
