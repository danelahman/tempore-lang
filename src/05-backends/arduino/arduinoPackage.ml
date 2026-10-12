module Json = ArduinoJson
module Error = Utils.Error
module Location = Utils.Location

type t = {
  name : string;
  description : string;
  declarations : string;
  declarations_source : string;
  grades : string list;
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
  let declarations = Json.required f "declarations" Json.string in
  {
    name;
    description = Json.required f "description" Json.string;
    declarations = directory ^ declarations;
    declarations_source = snd (file ~what:"its declarations" declarations);
    grades = Json.required f "grades" strings;
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

let source filename =
  List.find_map
    (fun name ->
      match find name with
      | Some p when p.declarations = filename -> Some p.declarations_source
      | _ -> None)
    names

let check_grades ~grades package =
  if List.mem grades package.grades then Ok ()
  else
    Error
      (Printf.sprintf
         "The package %s declares its operations under the grades %s, not %s"
         package.name
         (String.concat ", " package.grades)
         grades)
