module Json = ArduinoJson
module Error = Utils.Error
module Location = Utils.Location

type file = { filename : string; text : string }

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

let parse name text =
  let directory = "libraries/" ^ name ^ "/" in
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
    { filename = directory ^ filename; text = snd (file ~what filename) }
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
    bindings = list "bindings";
    init = Json.optional f "init" Json.string;
    safe_state = Json.optional f "safe_state" Json.string;
  }

let find name =
  Option.map (parse name) (List.assoc_opt (name ^ "/" ^ descriptor) files)

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

let files_for ~grades package =
  match List.assoc_opt grades package.declarations with
  | Some declarations ->
      Ok (Option.to_list package.definitions @ [ declarations ])
  | None ->
      Error
        (Printf.sprintf
           "The package %s declares its operations under the grades %s, not %s"
           package.name
           (String.concat ", " (List.map fst package.declarations))
           grades)
