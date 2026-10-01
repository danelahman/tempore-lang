module Error = Utils.Error
module Diagnostic = Utils.Diagnostic
module Ast = Language.Ast

(* [Loader] is shadowed inside [run_with] by the backend's instance of the
   functor, so the name is bound here while the library module is in scope. *)
let stdlib_filename = Loader.stdlib_filename

(* What [Diagnostic.print] quotes the source from. The standard library is
   loaded from a string and has no file to read; a location with no file name
   at all comes from a source only the caller knows, so it is left unquoted. *)
let source filename =
  if filename = stdlib_filename then Some Loader.stdlib_source
  else if filename = "" then None
  else
    try Some (In_channel.with_open_text filename In_channel.input_all)
    with Sys_error _ -> None

(* The definitions with their schemes, from the [skip]-th on. *)
let print_definitions ~print_scheme ?(skip = 0) definitions =
  List.iteri
    (fun i (x, scheme) ->
      if i >= skip then
        Format.printf "@[<v 2>%t :@,%t@]@." (Ast.Variable.print x)
          (print_scheme scheme))
    definitions

type config = {
  filenames : string list;
  use_stdlib : bool;
  debug : bool;
  typecheck_only : bool;
  resource_type : string;
}

let accepted_resource_names = List.map fst Grades.GradeRegistry.grade_modules
let default_resource_name = List.hd accepted_resource_names

(* The accepted grades, one per line and grouped as the web selector groups
   them, each with its title in a column after the longest name and, for a
   regular grade, its representation and inclusion test on an indented line
   below; indented to align under the "--grades" entry of [Arg]'s aligned
   option list. *)
let accepted_grades_help =
  let listed (g : Grades.GradeRegistry.group) =
    List.filter
      (fun (_, (info : Grades.GradeRegistry.info)) ->
        info.visibility = Grades.GradeRegistry.Everywhere)
      g.grades
  in
  let width =
    List.fold_left max 0
      (List.concat_map
         (fun g -> List.map (fun (name, _) -> String.length name) (listed g))
         Grades.GradeRegistry.groups)
  in
  let line (name, (info : Grades.GradeRegistry.info)) =
    Printf.sprintf "\n        %-*s %s%s" width name info.title
      (match info.implementation with
      | Some i ->
          Printf.sprintf "\n            %s; inclusion by %s"
            i.representation_short i.inclusion_short
      | None -> "")
  in
  let group (g : Grades.GradeRegistry.group) =
    match listed g with
    | [] -> ""
    | grades ->
        Printf.sprintf "\n      %s:%s" g.label
          (String.concat "" (List.map line grades))
  in
  String.concat "" (List.map group Grades.GradeRegistry.groups)
  ^ "\n\
    \      Further implementations of the regular grades, kept for \
     benchmarking, are accepted by --grades with the suffixes \
     -letter-automata, -symbolic-by-letters and -letter-derivatives in place \
     of -symbolic, and -rational-automata in place of -rational-symbolic."

let parse_args_to_config () =
  let filenames = ref []
  and use_stdlib = ref true
  and debug = ref false
  and typecheck_only = ref false
  and resource_type = ref default_resource_name in
  let usage = "Run Tempore as '" ^ Sys.argv.(0) ^ " [filename.tpe] ...'"
  and anonymous filename = filenames := filename :: !filenames
  (* The options, in alphabetical order. [--help] is listed rather than left
     to [Arg] to add, which would put it last; it refers back to the list to
     print it, hence the reference. *)
  and options = ref [] in
  options :=
    Arg.align
      [
        ( "--debug",
          Arg.Set debug,
          " Show final internal state and top level typing results after \
           execution" );
        ( "--grades",
          Arg.Set_string resource_type,
          Printf.sprintf " Selects the grades (default: %s); accepted:%s"
            default_resource_name accepted_grades_help );
        ( "--help",
          Arg.Unit
            (fun () -> raise (Arg.Help (Arg.usage_string !options usage))),
          " Display this list of options" );
        ( "--no-stdlib",
          Arg.Clear use_stdlib,
          " Do not load the standard library" );
        ( "--typecheck-only",
          Arg.Set typecheck_only,
          " Typecheck the files without running them" );
        (* [Arg] would otherwise add a single-dash "-help" alongside "--help";
           listing it here with an empty doc string keeps it out of the help
           text and makes it fail like any other unknown option. *)
        ( "-help",
          Arg.Unit (fun () -> raise (Arg.Bad "unknown option '-help'")),
          "" );
      ];
  Arg.parse !options anonymous usage;
  {
    filenames = List.rev !filenames;
    use_stdlib = !use_stdlib;
    debug = !debug;
    typecheck_only = !typecheck_only;
    resource_type = !resource_type;
  }

let run_with (module G : Grades.Grade.S) config =
  let module Backend = CliInterpreter.Make (Grades.GradeSystem.Identity (G)) in
  let module Loader = Loader.Loader (Backend) in
  let rec run (state : Backend.run_state) run_num =
    let printed = Backend.view_run_state state ~run_num in
    let next_run_num = if printed then run_num + 1 else run_num in
    match Backend.steps state with
    | [] -> ()
    | steps ->
        let i = Random.int (List.length steps) in
        let step = List.nth steps i in
        let state' = step.next_state () in
        run state' next_run_num
  in
  try
    Random.self_init ();
    (* Every source is parsed before any is loaded, so that the grades of the
       program are read over the operations all of them declare. *)
    let stdlib =
      if config.use_stdlib then
        Loader.parse_source ~filename:stdlib_filename Loader.stdlib_source
      else []
    in
    let files = List.map Loader.parse_file config.filenames in
    let stdlib_state =
      Loader.load_commands
        (Loader.declare (stdlib :: files) Loader.initial_state)
        stdlib
    in
    (* Every file is loaded even when an earlier one had errors, so that all
       of them are reported at once; a fatal failure still stops everything. *)
    let state', diagnostics =
      List.fold_left
        (fun (state, diagnostics) file ->
          let state', diagnostics' = Loader.load_commands_all state file in
          (state', diagnostics @ diagnostics'))
        (stdlib_state, []) files
    in
    (* A blank line between diagnostics, so that a reader can tell where one
       ends. A rejected program is not run, whatever [--typecheck-only] says. *)
    if diagnostics <> [] then begin
      List.iteri
        (fun i d ->
          if i > 0 then Format.pp_print_newline Format.err_formatter ();
          Diagnostic.print ~source d Format.err_formatter)
        diagnostics;
      exit 1
    end;
    let run_state = Backend.run state'.backend in
    if config.debug then begin
      let definitions (state : Loader.state) =
        Loader.TC.definitions state.typechecker
      in
      let print_definitions ?skip (state : Loader.state) =
        print_definitions
          ~print_scheme:(Loader.TC.print_scheme state.typechecker)
          ?skip (definitions state)
      in
      if config.use_stdlib then begin
        print_endline "=== Standard library ===";
        print_definitions stdlib_state;
        print_newline ()
      end;
      print_endline "=== Top-level definitions ===";
      print_definitions ~skip:(List.length (definitions stdlib_state)) state';
      print_newline ()
    end;
    (* loading the files has typechecked every command, the [run]s included *)
    if not config.typecheck_only then run run_state 1
  with
  | Error.Error d ->
      Diagnostic.print ~source d Format.err_formatter;
      exit 1
  | Stack_overflow ->
      prerr_endline
        "Fatal error: the available stack was exhausted, e.g. by a grade too \
         large to decide under this grading monoid";
      exit 2

let main () =
  let config = parse_args_to_config () in
  match
    List.assoc_opt config.resource_type Grades.GradeRegistry.grade_modules
  with
  | Some grade -> run_with grade config
  | None ->
      Printf.eprintf "Unknown grades '%s'. Accepted: %s\n" config.resource_type
        (String.concat ", "
           (List.map (fun s -> "'" ^ s ^ "'") accepted_resource_names));
      exit 1

let _ = main ()
