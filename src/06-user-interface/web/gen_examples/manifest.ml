type entry = {
  group : string;
  title : string;
  grade : string;
  path : string;
  description : string;
  backend : string;
  settings : (string * string) list;
}

type summary = { label : string; short : string; summary : string }
type line = Example of entry | Summary of summary | Default of string

(* The settings field: [key=value] pairs separated by blanks. *)
let settings_of_string field =
  String.split_on_char ' ' field
  |> List.concat_map (String.split_on_char '\t')
  |> List.filter (( <> ) "")
  |> List.map (fun pair ->
      match String.index_opt pair '=' with
      | Some i when i > 0 ->
          ( String.sub pair 0 i,
            String.sub pair (i + 1) (String.length pair - i - 1) )
      | _ -> failwith (Printf.sprintf "malformed manifest setting: %s" pair))

let example group title grade path description backend settings =
  Example
    {
      group;
      title;
      grade;
      path = "examples/" ^ path;
      description;
      backend;
      settings;
    }

let line_of_string line =
  let trimmed = String.trim line in
  if trimmed = "" || trimmed.[0] = '#' then None
  else
    match List.map String.trim (String.split_on_char '|' line) with
    | [ "default"; path ] -> Some (Default ("examples/" ^ path))
    | [ "group"; label; short; summary ] ->
        Some (Summary { label; short; summary })
    | [ group; title; grade; path; description ] ->
        Some
          (example group title grade path description
             BackendRegistry.default.key [])
    | [ group; title; grade; path; description; backend ] ->
        Some (example group title grade path description backend [])
    | [ group; title; grade; path; description; backend; settings ] ->
        Some
          (example group title grade path description backend
             (settings_of_string settings))
    | _ -> failwith (Printf.sprintf "malformed manifest line: %s" line)

(* A text input is given by the path of its file, relative to examples/, and
   kept relative to the project root. *)
let checked_setting (backend : BackendRegistry.entry) path (key, value) =
  match
    List.find_opt
      (fun (input : BackendRegistry.input) -> input.key = key)
      backend.inputs
  with
  | None ->
      failwith
        (Printf.sprintf
           "the manifest sets the input '%s', unknown to %s, for %s" key
           backend.name path)
  | Some { kind = Text; _ } -> (key, "examples/" ^ value)
  | Some { kind = Choice choices; _ } ->
      if List.mem value choices then (key, value)
      else
        failwith
          (Printf.sprintf
             "the manifest sets the input '%s' to '%s', not one of its \
              choices, for %s"
             key value path)

let checked (entry : entry) =
  if not (List.mem_assoc entry.grade Grades.GradeRegistry.grade_modules) then
    failwith
      (Printf.sprintf "the manifest names the unknown grade '%s' for %s"
         entry.grade entry.path);
  match BackendRegistry.find entry.backend with
  | None ->
      failwith
        (Printf.sprintf "the manifest names the unknown backend '%s' for %s"
           entry.backend entry.path)
  | Some backend ->
      {
        entry with
        settings = List.map (checked_setting backend entry.path) entry.settings;
      }

let read manifest_path =
  let lines =
    In_channel.with_open_text manifest_path In_channel.input_lines
    |> List.filter_map line_of_string
  in
  ( List.filter_map
      (function Summary summary -> Some summary | _ -> None)
      lines,
    List.filter_map
      (function Example entry -> Some (checked entry) | _ -> None)
      lines,
    List.filter_map (function Default path -> Some path | _ -> None) lines )

let group_entries entries =
  let groups =
    List.fold_left
      (fun groups (entry : entry) ->
        match groups with
        | (label, front) :: rest when label = entry.group ->
            (label, entry :: front) :: rest
        | _ -> (entry.group, [ entry ]) :: groups)
      [] entries
  in
  List.rev_map (fun (label, front) -> (label, List.rev front)) groups

let summarised summaries groups =
  List.iter
    (fun { label; short; _ } ->
      if not (List.mem_assoc label groups) then
        failwith
          (Printf.sprintf "the manifest summarises the group '%s' of no example"
             label);
      if
        List.exists
          (fun (s : summary) -> s.short = short && s.label <> label)
          summaries
      then
        failwith
          (Printf.sprintf "the manifest gives the short form '%s' to two groups"
             short))
    summaries;
  List.map
    (fun (label, entries) ->
      match List.filter (fun (s : summary) -> s.label = label) summaries with
      | [ summary ] -> (summary, entries)
      | [] ->
          failwith
            (Printf.sprintf "the manifest gives no summary of the group '%s'"
               label)
      | _ ->
          failwith
            (Printf.sprintf
               "the manifest gives more than one summary of the group '%s'"
               label))
    groups

let defaults entries paths =
  let pairs =
    List.map
      (fun path ->
        match
          List.find_opt (fun (entry : entry) -> entry.path = path) entries
        with
        | Some entry -> (entry.backend, path)
        | None ->
            failwith
              (Printf.sprintf
                 "the manifest's default %s is not a listed example" path))
      paths
  in
  List.iter
    (fun (backend, _) ->
      if List.length (List.filter (fun (b, _) -> b = backend) pairs) > 1 then
        failwith
          (Printf.sprintf
             "the manifest gives more than one default example of the backend \
              '%s'"
             backend))
    pairs;
  if not (List.mem_assoc BackendRegistry.default.key pairs) then
    failwith
      (Printf.sprintf
         "the manifest gives no default example of the backend '%s'"
         BackendRegistry.default.key);
  pairs
