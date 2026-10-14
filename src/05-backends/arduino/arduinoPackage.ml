module Json = ArduinoJson
module Error = Utils.Error
module Location = Utils.Location
module Board = ArduinoBoard

type file = {
  filename : string;
  text : string;
  running_times : (string * Grades.Grade.running_time) list;
}

type t = {
  name : string;
  description : string;
  definitions : file option;
  declarations : (string * file) list;
  requires : string list;
  sources : (string * string) list;
  host_models : (string * string) list;
  bindings : string list;
  init : string option;
  safe_state : string option;
  bounds : (string * (string * Grades.Grade.running_time) list) list;
}

(* The embedded files, each with its path below libraries/. *)
let files = Arduino_libraries.files
let descriptor = "package.json"

let names =
  List.sort String.compare
    (List.filter_map
       (fun (path, _) ->
         match String.split_on_char '/' path with
         | [ name; file ] when file = descriptor -> Some name
         | _ -> None)
       files)

let parse ~files name =
  let directory = "libraries/" ^ name ^ "/" in
  let text =
    match List.assoc_opt (name ^ "/" ^ descriptor) files with
    | Some text -> text
    | None ->
        Error.compilation "The package %s has no descriptor %s" name descriptor
  in
  let v = Json.parse ~filename:(directory ^ descriptor) text in
  let f =
    Json.fields ~what:"a package descriptor"
      ~accepted:
        [
          "description";
          "definitions";
          "declarations";
          "grades";
          "requires";
          "sources";
          "host_models";
          "bindings";
          "init";
          "safe_state";
          "bounds";
        ]
      v
  in
  let strings = Json.list Json.string in
  let list name = Option.value ~default:[] (Json.optional f name strings) in
  let file ~what file =
    match List.assoc_opt (name ^ "/" ^ file) files with
    | Some text -> (file, text)
    | None ->
        Error.compilation ~loc:v.at "The package %s has no file %s for %s" name
          file what
  in
  let tpe ~what filename =
    {
      filename = directory ^ filename;
      text = snd (file ~what filename);
      running_times = [];
    }
  in
  let declarations =
    let what = "its declarations" in
    let member = Json.required f "declarations" (fun ~what:_ v -> v) in
    match (member.value, Json.optional f "grades" strings) with
    | Json.String filename, Some grades ->
        let declarations = tpe ~what filename in
        List.map (fun grades -> (grades, declarations)) grades
    | Json.String _, None ->
        Error.compilation ~loc:v.at
          "The member 'grades' of a package descriptor is missing; it names \
           the grades under which the declarations are read"
    | Json.Object members, None ->
        if members = [] then
          Error.compilation ~loc:member.at
            "The member 'declarations' of a package descriptor names no grades";
        (* The grades, none twice. *)
        let g =
          Json.fields ~what:"the member 'declarations' of a package descriptor"
            ~accepted:
              (List.map
                 (fun ((key : string Location.located), _) -> key.it)
                 members)
            member
        in
        List.map
          (fun ((key : string Location.located), _) ->
            (key.it, tpe ~what (Json.required g key.it Json.string)))
          members
    | Json.Object _, Some _ ->
        Error.compilation ~loc:(Json.location f "grades")
          "A package descriptor whose declarations map grades to files has no \
           member 'grades'"
    | _ ->
        Error.compilation ~loc:member.at
          "The member 'declarations' of a package descriptor must be a string \
           or an object, but it is %s"
          (Json.kind member)
  in
  let bindings = list "bindings" in
  (* The running-time bounds of each board, a closed interval [[lo, hi]] by
     operation, each operation one of the bindings. *)
  let interval ~what (v : Json.t) =
    match v.value with
    | Json.Array [ lo; hi ] ->
        let lo = Json.rational ~what lo and hi = Json.rational ~what hi in
        if Grades.Rational.compare lo hi > 0 then
          Error.compilation ~loc:v.at
            "%s is an empty interval: its lower bound exceeds its upper bound"
            (String.capitalize_ascii what);
        (Grades.Grade.Closed lo, Grades.Grade.Closed hi)
    | _ ->
        Error.compilation ~loc:v.at "%s is %s, not an array [lo, hi]"
          (String.capitalize_ascii what)
          (Json.kind v)
  in
  (* The members of the object [v], each with its name, decoded by
     [decode]. *)
  let members decode ~what (v : Json.t) =
    match v.value with
    | Json.Object members ->
        let names =
          List.map (fun ((key : string Location.located), _) -> key.it) members
        in
        let g = Json.fields ~what ~accepted:names v in
        List.map
          (fun ((key : string Location.located), _) ->
            (key, Json.required g key.it decode))
          members
    | _ ->
        Error.compilation ~loc:v.at "%s is %s, not an object"
          (String.capitalize_ascii what)
          (Json.kind v)
  in
  let operations ~what v =
    List.map
      (fun ((op : string Location.located), bounds) ->
        if not (List.mem op.it bindings) then
          Error.compilation ~loc:op.at
            "The bounds of a board name the operation %s, which the package %s \
             does not bind; it binds: %s"
            op.it name
            (match bindings with [] -> "none" | ops -> String.concat ", " ops);
        (op.it, bounds))
      (members interval ~what v)
  in
  let boards ~what v =
    List.map
      (fun ((board : string Location.located), operations) ->
        if Board.find board.it = None then
          Error.compilation ~loc:board.at
            "Unknown board '%s' in the bounds of the package %s; accepted: %s"
            board.it name
            (String.concat ", " Board.names);
        (board.it, operations))
      (members operations ~what v)
  in
  let bounds = Option.value ~default:[] (Json.optional f "bounds" boards) in
  {
    name;
    description = Json.required f "description" Json.string;
    definitions =
      Option.map
        (tpe ~what:"its definitions")
        (Json.optional f "definitions" Json.string);
    declarations;
    requires = list "requires";
    sources = List.map (file ~what:"its sources") (list "sources");
    host_models = List.map (file ~what:"its host models") (list "host_models");
    bindings;
    init = Json.optional f "init" Json.string;
    safe_state = Json.optional f "safe_state" Json.string;
    bounds;
  }

let find name =
  if List.mem_assoc (name ^ "/" ^ descriptor) files then
    Some (parse ~files name)
  else None

let resolve (name : string Location.located) =
  match find name.it with
  | Some package -> package
  | None ->
      Error.compilation ~loc:name.at "Unknown package '%s'; accepted: %s"
        name.it (String.concat ", " names)

let package_files package =
  Option.to_list package.definitions @ List.map snd package.declarations

let source filename =
  List.find_map
    (fun name ->
      Option.bind (find name) (fun p ->
          List.find_map
            (fun file ->
              if file.filename = filename then Some file.text else None)
            (package_files p)))
    names

let shared_binding p q =
  List.find_opt (fun op -> List.mem op q.bindings) p.bindings

let running_times ?board package =
  Option.value ~default:[]
    (Option.bind board (fun board -> List.assoc_opt board package.bounds))

let files_for ~grades ?board package =
  match List.assoc_opt grades package.declarations with
  | Some declarations ->
      Ok
        (Option.to_list package.definitions
        @ [ { declarations with running_times = running_times ?board package } ]
        )
  | None ->
      Error
        (Printf.sprintf
           "The package %s declares its operations under the grades %s, not %s"
           package.name
           (String.concat ", " (List.map fst package.declarations))
           grades)
