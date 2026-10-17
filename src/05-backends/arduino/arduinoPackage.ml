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
  packages : string list;
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

(* The names of the packages of [files], in alphabetical order. *)
let names_of files =
  List.sort String.compare
    (List.filter_map
       (fun (path, _) ->
         match String.split_on_char '/' path with
         | [ name; file ] when file = descriptor -> Some name
         | _ -> None)
       files)

let names = names_of files

let parse ~files name =
  let directory = "libraries/" ^ name ^ "/" in
  let text =
    match List.assoc_opt (name ^ "/" ^ descriptor) files with
    | Some text -> text
    | None ->
        Error.compilation "The package `%s` has no descriptor `%s`" name
          descriptor
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
          "packages";
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
        Error.compilation ~loc:v.at "The package `%s` has no file `%s` for %s"
          name file what
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
          "The member `grades` of a package descriptor is missing; it names \
           the grades under which the declarations are read"
    | Json.Object members, None ->
        if members = [] then
          Error.compilation ~loc:member.at
            "The member `declarations` of a package descriptor names no grades";
        List.map
          (fun ((grades : string Location.located), filename) ->
            (grades.it, tpe ~what filename))
          (Json.assoc Json.string
             ~what:"the member `declarations` of a package descriptor" member)
    | Json.Object _, Some _ ->
        Error.compilation ~loc:(Json.location f "grades")
          "A package descriptor whose declarations map grades to files has no \
           member `grades`"
    | _ ->
        Error.compilation ~loc:member.at
          "The member `declarations` of a package descriptor must be a string \
           or an object, but it is %s"
          (Json.kind member)
  in
  let bindings = list "bindings" in
  let others = List.filter (( <> ) name) (names_of files) in
  let packages =
    List.map
      (fun (package : string Location.located) ->
        if not (List.mem package.it others) then
          Error.compilation ~loc:package.at
            "The package `%s` needs the package `%s`, which is not another \
             package; accepted: %s"
            name package.it
            (Utils.Diagnostic.code_list others);
        package.it)
      (Option.value ~default:[]
         (Json.optional f "packages"
            (Json.list (fun ~what (v : Json.t) ->
                 { Location.it = Json.string ~what v; at = v.at }))))
  in
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
        Error.compilation ~loc:v.at "%s is %s, not an array `[lo, hi]`"
          (String.capitalize_ascii what)
          (Json.kind v)
  in
  let operations ~what v =
    List.map
      (fun ((op : string Location.located), bounds) ->
        if not (List.mem op.it bindings) then
          Error.compilation ~loc:op.at
            "The bounds of a board name the operation `%s`, which the package \
             `%s` does not bind; it binds: %s"
            op.it name
            (Utils.Diagnostic.code_list bindings);
        (op.it, bounds))
      (Json.assoc interval ~what v)
  in
  let boards ~what v =
    List.map
      (fun ((board : string Location.located), operations) ->
        if Board.find board.it = None then
          Error.compilation ~loc:board.at
            "Unknown board `%s` in the bounds of the package `%s`; accepted: %s"
            board.it name
            (Utils.Diagnostic.code_list Board.names);
        (board.it, operations))
      (Json.assoc operations ~what v)
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
    packages;
    sources = List.map (file ~what:"its sources") (list "sources");
    host_models = List.map (file ~what:"its host models") (list "host_models");
    bindings;
    init = Json.optional f "init" Json.string;
    safe_state = Json.optional f "safe_state" Json.string;
    bounds;
  }

(* The packages, each parsed at its first use. *)
let packages = List.map (fun name -> (name, lazy (parse ~files name))) names
let find name = Option.map Lazy.force (List.assoc_opt name packages)

let resolve (name : string Location.located) =
  match find name.it with
  | Some package -> package
  | None ->
      Error.compilation ~loc:name.at "Unknown package `%s`; accepted: %s"
        name.it
        (Utils.Diagnostic.code_list names)

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

let missing_package ~before package =
  List.find_opt
    (fun name -> not (List.exists (fun p -> p.name = name) before))
    package.packages

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
           "The package `%s` declares its operations under the grades %s, not \
            `%s`"
           package.name
           (Utils.Diagnostic.code_list (List.map fst package.declarations))
           grades)
