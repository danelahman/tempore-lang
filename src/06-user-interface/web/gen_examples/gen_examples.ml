(* Generates the source of the module [Examples_tpe], which lists the
   examples the web interface's gallery offers. Reads the manifest
   [examples/index] ({!Manifest}), the source of each example it names and the
   files of the text inputs its examples set, and prints an OCaml module of the
   groups and examples it describes, in the manifest's order, and the example
   loaded when the page is opened; invoked by a dune rule, see
   src/06-user-interface/web/dune. It fails on a grade or a backend the
   registries do not list, on a setting of an input its backend does not have
   or of a choice the input does not offer, on a group without exactly one
   summary or a summary without a group, on two groups of one short form, and
   unless exactly one default line names a listed example. *)

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

(* The value of a setting: the content of the file of a text input, which a
   setting names relative to the project root, or the choice of another. *)
let setting_value root backend (key, value) =
  match
    Option.bind (BackendRegistry.find backend)
      (fun (b : BackendRegistry.entry) ->
        List.find_opt
          (fun (input : BackendRegistry.input) -> input.key = key)
          b.inputs)
  with
  | Some { kind = Text; _ } -> (key, read_source root value)
  | _ -> (key, value)

let print_example buf root (entry : Manifest.entry) =
  let source = read_source root entry.path in
  let settings =
    String.concat "; "
      (List.map
         (fun (key, value) ->
           Printf.sprintf "(%s, %s)" (quoted key) (quoted value))
         (List.map (setting_value root entry.backend) entry.settings))
  in
  Buffer.add_string buf
    (Printf.sprintf
       "        {\n\
       \          title = %s;\n\
       \          grade = %s;\n\
       \          source = %s;\n\
       \          description = %s;\n\
       \          path = %s;\n\
       \          backend = %s;\n\
       \          settings = [ %s ];\n\
       \        };\n"
       (quoted entry.title) (quoted entry.grade) (quoted source)
       (quoted entry.description) (quoted entry.path) (quoted entry.backend)
       settings)

let print_group buf root
    (({ label; short; summary } : Manifest.summary), entries) =
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
  \  backend : string;  (** the key of its backend in BackendRegistry *)\n\
  \  settings : (string * string) list;  (** the values of inputs of its \
   backend, by key *)\n\
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
      let summaries, entries, defaults = Manifest.read manifest_path in
      let groups =
        Manifest.summarised summaries (Manifest.group_entries entries)
      in
      let default = Manifest.default_path entries defaults in
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
