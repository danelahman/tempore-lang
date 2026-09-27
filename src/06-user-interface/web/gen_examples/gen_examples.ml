(* Generates the source of the module [Examples_tpe], which lists the
   examples the web interface's selector offers. Reads the manifest
   [examples/index] and the source of each example it names, and prints an
   OCaml module of the groups and examples it describes, in the manifest's
   order; invoked by a dune rule, see src/06-user-interface/web/dune. *)

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

(* A manifest line "group | title | grade | path | description" split into its
   five fields, trimmed of surrounding space; [None] for a line that is not an
   entry (blank, or a comment starting with '#'). *)
let entry_of_line line =
  let trimmed = String.trim line in
  if trimmed = "" || trimmed.[0] = '#' then None
  else
    match String.split_on_char '|' line with
    | [ group; title; grade; path; description ] ->
        Some
          {
            group = String.trim group;
            title = String.trim title;
            grade = String.trim grade;
            path = "examples/" ^ String.trim path;
            description = String.trim description;
          }
    | _ -> failwith (Printf.sprintf "malformed manifest line: %s" line)

let read_entries manifest_path =
  In_channel.with_open_text manifest_path In_channel.input_lines
  |> List.filter_map entry_of_line

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

let print_group buf root (label, entries) =
  Buffer.add_string buf
    (Printf.sprintf "    { label = %s; examples = [\n" (quoted label));
  List.iter (print_example buf root) entries;
  Buffer.add_string buf "    ] };\n"

let preamble =
  "(* Generated from examples/index by gen_examples; see \
   src/06-user-interface/web/dune. [examples] lists the groups of the web \
   interface's selector, in order, each with its examples. *)\n\n\
   type example = {\n\
  \  title : string;  (** shown in the selector, without the group's prefix *)\n\
  \  grade : string;  (** the grading monoid the web interface switches to *)\n\
  \  source : string;\n\
  \  description : string;  (** shown as the option's tooltip *)\n\
  \  path : string;  (** relative to the project root, for links from the \
   documentation *)\n\
   }\n\n\
   type group = { label : string; examples : example list }\n\n"

let () =
  match Sys.argv with
  | [| _; manifest_path; root |] ->
      let groups = group_entries (read_entries manifest_path) in
      let buf = Buffer.create 4096 in
      Buffer.add_string buf preamble;
      Buffer.add_string buf "let examples : group list =\n  [\n";
      List.iter (print_group buf root) groups;
      Buffer.add_string buf "  ]\n";
      print_string (Buffer.contents buf)
  | _ ->
      prerr_endline "usage: gen_examples <manifest path> <project root>";
      exit 2
