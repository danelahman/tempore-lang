(* Generates the source of the module [Examples_tpe], which lists the
   examples the web interface's gallery offers. Reads the manifest
   [examples/index] and the source of each example it names, and prints an
   OCaml module of the groups and examples it describes, in the manifest's
   order, and the example loaded when the page is opened; invoked by a dune
   rule, see src/06-user-interface/web/dune. It fails on a grade the registry
   does not list, on a group without exactly one summary or a summary without a
   group, on two groups of one short form, and unless exactly one default line
   names a listed example. *)

(* One example: its group, title, the grading monoid the web interface
   switches to when it is loaded, its path relative to the project root, and
   its one-line description. *)
type entry = {
  group : string;
  title : string;
  grade : string;
  path : string;
  description : string;
}

(* A group's summary line: its label, the label's short form and the
   one-line summary. *)
type summary = { label : string; short : string; summary : string }

(* A line of the manifest: an example, the summary line of a group, or the
   path of the default example. *)
type line = Example of entry | Summary of summary | Default of string

(* A manifest line split into its fields, trimmed of surrounding space: five
   fields "group | title | grade | path | description" for an example, four
   fields "group | label | short | summary" for a group's summary; [None] for
   two fields "default | path" for the default example; [None] for a line that
   is none of these (blank, or a comment starting with '#'). *)
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
          (Example
             { group; title; grade; path = "examples/" ^ path; description })
    | _ -> failwith (Printf.sprintf "malformed manifest line: %s" line)

(* [entry], if its grade is one of those Grades.GradeRegistry lists. *)
let checked (entry : entry) =
  if List.mem_assoc entry.grade Grades.GradeRegistry.grade_modules then entry
  else
    failwith
      (Printf.sprintf "the manifest names the unknown grade '%s' for %s"
         entry.grade entry.path)

(* The summaries, the examples and the default paths of the manifest, each in
   the manifest's order. *)
let read_manifest manifest_path =
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

(* [entries] grouped by [group], preserving the manifest's order of both the
   groups and the examples within them; entries of one group are expected to
   be listed together, as consecutive lines. *)
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

(* Each group of [groups] paired with its summary line; fails unless every
   group has exactly one summary, every summary names a group and no two
   summaries give one short form. *)
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

(* A delimiter [tag] for a quoted string literal [{tag|...|tag}] that does not
   occur as the closing sequence "|tag}" inside [content]; tried in increasing
   length until one is safe, so that an example may itself contain [{|...|}]. *)
let quoting_tag content =
  let closes_with tag =
    let closing = "|" ^ tag ^ "}" in
    let content_len = String.length content
    and closing_len = String.length closing in
    let rec at i =
      i + closing_len <= content_len
      && (String.sub content i closing_len = closing || at (i + 1))
    in
    at 0
  in
  let rec search n =
    let tag = if n = 0 then "" else Printf.sprintf "q%d" n in
    if closes_with tag then search (n + 1) else tag
  in
  search 0

(* [content] as an OCaml quoted string literal, delimited so that its text
   cannot close the literal early. *)
let quoted content =
  let tag = quoting_tag content in
  "{" ^ tag ^ "|" ^ content ^ "|" ^ tag ^ "}"

(* The one default path, which names a listed example; fails otherwise. *)
let default_path entries = function
  | [ path ] ->
      if List.exists (fun (entry : entry) -> entry.path = path) entries then
        path
      else
        failwith
          (Printf.sprintf "the manifest's default %s is not a listed example"
             path)
  | _ -> failwith "the manifest does not give exactly one default example"

let read_source root path =
  In_channel.with_open_text (Filename.concat root path) In_channel.input_all

let print_example buf root (entry : entry) =
  let source = read_source root entry.path in
  Buffer.add_string buf
    (Printf.sprintf
       "        {\n\
       \          title = %s;\n\
       \          grade = %s;\n\
       \          source = %s;\n\
       \          description = %s;\n\
       \          path = %s;\n\
       \        };\n"
       (quoted entry.title) (quoted entry.grade) (quoted source)
       (quoted entry.description) (quoted entry.path))

let print_group buf root ({ label; short; summary }, entries) =
  Buffer.add_string buf
    (Printf.sprintf "    { label = %s; short = %s; summary = %s; examples = [\n"
       (quoted label) (quoted short) (quoted summary));
  List.iter (print_example buf root) entries;
  Buffer.add_string buf "    ] };\n"

let preamble =
  "(* Generated from examples/index by gen_examples; see \
   src/06-user-interface/web/dune. [examples] lists the groups of the web \
   interface's gallery, in order, each with its examples; [default] is the \
   path of the example loaded when the page is opened, one of theirs. *)\n\n\
   type example = {\n\
  \  title : string;  (** shown on its card, without the group's prefix *)\n\
  \  grade : string;  (** the grading monoid the web interface switches to *)\n\
  \  source : string;\n\
  \  description : string;  (** shown on its card *)\n\
  \  path : string;  (** relative to the project root, for links from the \
   documentation *)\n\
   }\n\n\
   type group = {\n\
  \  label : string;\n\
  \  short : string;  (** the label's short form, distinct for distinct groups \
   *)\n\
  \  summary : string;  (** one line, shown beside the label *)\n\
  \  examples : example list;\n\
   }\n\n"

let () =
  match Sys.argv with
  | [| _; manifest_path; root |] ->
      let summaries, entries, defaults = read_manifest manifest_path in
      let groups = summarised summaries (group_entries entries) in
      let default = default_path entries defaults in
      let buf = Buffer.create 4096 in
      Buffer.add_string buf preamble;
      Buffer.add_string buf "let examples : group list =\n  [\n";
      List.iter (print_group buf root) groups;
      Buffer.add_string buf "  ]\n";
      Buffer.add_string buf
        (Printf.sprintf "\nlet default : string = %s\n" (quoted default));
      print_string (Buffer.contents buf)
  | _ ->
      prerr_endline "usage: gen_examples <manifest path> <project root>";
      exit 2
