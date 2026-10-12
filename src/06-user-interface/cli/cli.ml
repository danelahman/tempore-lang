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
  emit_opentrons : string option;
  emit_arduino : string option;
  device : string option;
  host_runs : bool;
  host_simulate : int option;
  bind : string option;
  robot : OpentronsBackend.OpentronsProtocol.robot option;
  api_level : string option;
  time_unit : Grades.Rational.t option;
  timeline : bool;
  timeline_full : bool;
  monitor : OpentronsBackend.OpentronsProtocol.monitor option;
  simulate : bool;
  simulator : string option;
}

(* The length in seconds of the time unit [s]: [seconds], [minutes], [hours]
   or a positive decimal number of seconds. *)
let time_unit_of_string s =
  match s with
  | "seconds" -> Grades.Rational.of_int 1
  | "minutes" -> Grades.Rational.of_int 60
  | "hours" -> Grades.Rational.of_int 3600
  | _ -> (
      match Grades.Rational.of_decimal s with
      | q when Grades.Rational.sign q > 0 -> q
      | _ | (exception Invalid_argument _) ->
          raise
            (Arg.Bad
               (Printf.sprintf
                  "option '--time-unit': '%s' is neither seconds, minutes, \
                   hours nor a positive number of seconds"
                  s)))

(* The number of microseconds of [s], a positive decimal number of seconds. *)
let simulated_duration_of_string s =
  let bad () =
    raise
      (Arg.Bad
         (Printf.sprintf
            "option '--host-simulate': '%s' is not a positive number of \
             seconds of at most 10^6"
            s))
  in
  match Grades.Rational.of_decimal s with
  | q
    when Grades.Rational.sign q > 0
         && Grades.Rational.compare q (Grades.Rational.of_int 1_000_000) <= 0 ->
      let us = Grades.Rational.mul q (Grades.Rational.of_int 1_000_000) in
      Z.to_int (Z.fdiv (Grades.Rational.num us) (Grades.Rational.den us))
  | _ | (exception Invalid_argument _) -> bad ()

let accepted_resource_names = List.map fst Grades.GradeRegistry.grade_modules

(* The accepted grades, one per line and grouped as the web selector groups
   them, each with its title in a column after the longest name and, for a
   regular grade, its representation and inclusion test on an indented line
   below; indented to align under the "--grades" entry of [Arg]'s aligned
   option list. *)
let accepted_grades_help =
  let listed = Grades.GradeRegistry.listed in
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
  and resource_type = ref Grades.GradeRegistry.default_name
  and emit_opentrons = ref None
  and emit_arduino = ref None
  and device = ref None
  and host_runs = ref false
  and host_simulate = ref None
  and bind = ref None
  and robot = ref None
  and api_level = ref None
  and time_unit = ref None
  and timeline = ref false
  and timeline_full = ref false
  and monitor = ref None
  and simulate = ref false
  and simulator = ref None in
  let choice option values reference value =
    match List.assoc_opt value values with
    | Some v -> reference := Some v
    | None ->
        raise
          (Arg.Bad
             (Printf.sprintf "option '%s': '%s' is not one of %s" option value
                (String.concat ", " (List.map fst values))))
  in
  let usage = "Run Tempore as '" ^ Sys.argv.(0) ^ " [filename.tpe] ...'"
  and anonymous filename = filenames := filename :: !filenames
  (* The options, in alphabetical order. [--help] is listed rather than left
     to [Arg] to add, which would put it last; it refers back to the list to
     print it, hence the reference. *)
  and options = ref [] in
  options :=
    Arg.align
      [
        ( "--api-level",
          Arg.String (fun level -> api_level := Some level),
          " Set the apiLevel of the protocol written with --bind (default: \
           2.30)" );
        ( "--bind",
          Arg.String (fun filename -> bind := Some filename),
          " With --emit-opentrons, write an Opentrons protocol whose \
           operations are performed by the functions of the given Python \
           binding file" );
        ( "--debug",
          Arg.Set debug,
          " Print the inferred type schemes of the top-level definitions \
           before running" );
        ( "--device",
          Arg.String (fun filename -> device := Some filename),
          " With --emit-arduino, write a PlatformIO project of the device \
           described by the given manifest" );
        ( "--emit-arduino",
          Arg.String (fun directory -> emit_arduino := Some directory),
          " Typecheck the files and write them, compiled to C++, to the given \
           directory, without running them; a name without a directory \
           component names a directory in _arduino/projects" );
        ( "--emit-opentrons",
          Arg.String (fun filename -> emit_opentrons := Some filename),
          " Typecheck the files and write them, compiled to Python, to the \
           given file, without running them; a file name without a directory \
           names a file in _opentrons/protocols" );
        ( "--grades",
          Arg.Set_string resource_type,
          Printf.sprintf " Selects the grades (default: %s); accepted:%s"
            Grades.GradeRegistry.default_name accepted_grades_help );
        ( "--help",
          Arg.Unit
            (fun () -> raise (Arg.Help (Arg.usage_string !options usage))),
          " Display this list of options" );
        ( "--host-runs",
          Arg.Set host_runs,
          " With --emit-arduino, also compile the run commands, and write a \
           main program for the host that executes them and prints their \
           results as the interpreter does" );
        ( "--host-simulate",
          Arg.String
            (fun s -> host_simulate := Some (simulated_duration_of_string s)),
          " With --device, build the project for the host with c++ and run its \
           tasks for the given number of seconds of simulated time, printing \
           the log of the device with the events of its tasks" );
        ( "--monitor",
          Arg.String
            (choice "--monitor"
               OpentronsBackend.OpentronsProtocol.
                 [ ("abort", Abort); ("warn", Warn); ("off", Off) ]
               monitor),
          " Set what a protocol written with --bind or a device written with \
           --device does when an operation's running time is outside its \
           bounds, or a step of a periodic task takes its period or longer: \
           abort, warn or off (default: abort)" );
        ( "--no-stdlib",
          Arg.Clear use_stdlib,
          " Do not load the standard library" );
        ( "--robot",
          Arg.String
            (choice "--robot"
               OpentronsBackend.OpentronsProtocol.[ ("flex", Flex) ]
               robot),
          " Set the robot of the protocol written with --bind: flex (default: \
           flex)" );
        ( "--simulate",
          Arg.Set simulate,
          " Run the Opentrons simulator on the protocol written with --bind, \
           passing its run log through and exiting with its exit code" );
        ( "--simulator",
          Arg.String (fun path -> simulator := Some path),
          " Use the given executable as the Opentrons simulator of --simulate \
           (default: opentrons_simulate on the PATH, or else in _opentrons)" );
        ( "--time-unit",
          Arg.String (fun s -> time_unit := Some (time_unit_of_string s)),
          " Set the length of a unit of duration of the protocol written with \
           --bind: seconds, minutes, hours or a positive number of seconds \
           (default: seconds)" );
        ( "--timeline",
          Arg.Set timeline,
          " Print the timeline of each run after its result: its delays and \
           calls of operations performed by their default implementations, \
           with the events of these indented below them, each with its grade, \
           and the resources boxed, with their grades, and unboxed, each row \
           with the grade accumulated before it; long grades are shortened" );
        ( "--timeline-full",
          Arg.Set timeline_full,
          " Print the timelines of --timeline with their grades in full; \
           implies --timeline" );
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
  let requires option given needed present =
    if given && not present then begin
      Printf.eprintf "%s: option '%s' requires '%s'.\n" Sys.argv.(0) option
        needed;
      exit 2
    end
  in
  requires "--bind" (!bind <> None) "--emit-opentrons" (!emit_opentrons <> None);
  requires "--host-runs" !host_runs "--emit-arduino" (!emit_arduino <> None);
  requires "--device" (!device <> None) "--emit-arduino" (!emit_arduino <> None);
  requires "--host-simulate" (!host_simulate <> None) "--device"
    (!device <> None);
  if !host_runs && !device <> None then begin
    Printf.eprintf "%s: option '--host-runs' cannot be used with '--device'.\n"
      Sys.argv.(0);
    exit 2
  end;
  List.iter
    (fun (emit, emitting) ->
      List.iter
        (fun (option, given) ->
          if given && emitting then begin
            Printf.eprintf "%s: option '%s' cannot be used with '%s'.\n"
              Sys.argv.(0) option emit;
            exit 2
          end)
        [
          ("--timeline", !timeline);
          ("--timeline-full", !timeline_full);
          ("--emit-arduino", emit <> "--emit-arduino" && !emit_arduino <> None);
        ])
    [
      ("--emit-opentrons", !emit_opentrons <> None);
      ("--emit-arduino", !emit_arduino <> None);
    ];
  List.iter
    (fun (option, given) -> requires option given "--bind" (!bind <> None))
    [
      ("--api-level", !api_level <> None);
      ("--robot", !robot <> None);
      ("--simulate", !simulate);
      ("--simulator", !simulator <> None);
      ("--time-unit", !time_unit <> None);
    ];
  if !monitor <> None && !bind = None && !device = None then begin
    Printf.eprintf "%s: option '--monitor' requires '--bind' or '--device'.\n"
      Sys.argv.(0);
    exit 2
  end;
  {
    filenames = List.rev !filenames;
    use_stdlib = !use_stdlib;
    debug = !debug;
    typecheck_only = !typecheck_only;
    resource_type = !resource_type;
    emit_opentrons = !emit_opentrons;
    emit_arduino = !emit_arduino;
    device = !device;
    host_runs = !host_runs;
    host_simulate = !host_simulate;
    bind = !bind;
    robot = !robot;
    api_level = !api_level;
    time_unit = !time_unit;
    timeline = !timeline || !timeline_full;
    timeline_full = !timeline_full;
    monitor = !monitor;
    simulate = !simulate;
    simulator = !simulator;
  }

(* The path of the executable [name] in a directory of the PATH, if any. *)
let find_on_path name =
  let separator = if Sys.win32 then ';' else ':' in
  match Sys.getenv_opt "PATH" with
  | None -> None
  | Some path ->
      List.find_map
        (fun dir ->
          let candidate =
            Filename.concat (if dir = "" then "." else dir) name
          in
          if Sys.file_exists candidate && not (Sys.is_directory candidate) then
            Some candidate
          else None)
        (String.split_on_char separator path)

(* The virtual environment of the Opentrons simulator installed by
   [make opentrons-deps], in the directory of the executable or else in the
   current directory, if it holds the simulator. *)
let find_opentrons_venv () =
  let executable_dir =
    let dir = Filename.dirname Sys.executable_name in
    if Filename.is_relative dir then Filename.concat (Sys.getcwd ()) dir
    else dir
  in
  List.find_map
    (fun dir ->
      let venv = Filename.concat dir "_opentrons" in
      let simulator =
        Filename.concat (Filename.concat venv "bin") "opentrons_simulate"
      in
      if Sys.file_exists simulator && not (Sys.is_directory simulator) then
        Some (venv, simulator)
      else None)
    [ executable_dir; Sys.getcwd () ]

(* Runs the Opentrons simulator on the protocol [filename], its output passed
   through, and exits with its exit code. The simulator is [simulator], or
   else [opentrons_simulate] on the PATH, or else that of the virtual
   environment [_opentrons], run with OT_API_CONFIG_DIR set to its directory
   [config] unless the environment sets it. *)
let simulate ?simulator filename =
  let command =
    match simulator with
    | Some path when Sys.file_exists path ->
        Some (Filename.quote_command path [ filename ])
    | Some _ -> None
    | None -> (
        match find_on_path "opentrons_simulate" with
        | Some path -> Some (Filename.quote_command path [ filename ])
        | None ->
            Option.map
              (fun (venv, path) ->
                match Sys.getenv_opt "OT_API_CONFIG_DIR" with
                | Some _ -> Filename.quote_command path [ filename ]
                | None ->
                    Filename.quote_command "env"
                      [
                        "OT_API_CONFIG_DIR=" ^ Filename.concat venv "config";
                        path;
                        filename;
                      ])
              (find_opentrons_venv ()))
  in
  match command with
  | None ->
      prerr_endline
        (match simulator with
        | Some path ->
            Printf.sprintf "Error: the Opentrons simulator '%s' was not found"
              path
        | None ->
            "Error: the Opentrons simulator opentrons_simulate was not found \
             on the PATH or in _opentrons; 'make opentrons-deps' installs it \
             with Python 3.10 or later");
      exit 1
  | Some command ->
      flush_all ();
      exit (Sys.command command)

(* The directory, relative to the current directory, of the files written by
   --emit-opentrons under a name without a directory component. *)
let default_emit_directory = Filename.concat "_opentrons" "protocols"

(* The path of the file written by --emit-opentrons under [name]: [name] in
   [default_emit_directory] if it has no directory component, else [name]. *)
let emit_path name =
  if Filename.basename name = name then
    Filename.concat default_emit_directory name
  else name

(* Creates the directory [dir] and its missing ancestors. *)
let rec make_directory dir =
  if not (Sys.file_exists dir) then begin
    make_directory (Filename.dirname dir);
    Sys.mkdir dir 0o755
  end

(* Writes [contents] to the file [filename], creating [default_emit_directory]
   if [filename] lies in it, and prints the path written; or reports the error
   and exits with code 1. *)
let write_file filename contents =
  try
    if Filename.dirname filename = default_emit_directory then
      make_directory default_emit_directory;
    Out_channel.with_open_text filename (fun oc ->
        Out_channel.output_string oc contents);
    print_endline ("Wrote " ^ filename)
  with Sys_error message ->
    prerr_endline ("Error: " ^ message);
    exit 1

(* The directory written by --emit-arduino under [name]: [name] in
   [_arduino/projects] if it has no directory component, else [name]. *)
let arduino_directory name =
  if Filename.basename name = name then
    Filename.concat (Filename.concat "_arduino" "projects") name
  else name

(* The text of the file [filename], or else the error reported and exit with
   code 1. *)
let read_file filename =
  try In_channel.with_open_text filename In_channel.input_all
  with Sys_error message ->
    prerr_endline ("Error: " ^ message);
    exit 1

(* Builds the project [files] written to [directory] for the host with c++ and
   runs its simulation for [duration] microseconds, its output passed through,
   and exits with its exit code. *)
let host_simulate ~directory ~duration files =
  if find_on_path "c++" = None then begin
    prerr_endline "Error: the C++ compiler c++ was not found on the PATH";
    exit 1
  end;
  let executable =
    Filename.concat (Filename.concat directory "host") "simulation"
  in
  let command =
    ArduinoBackend.ArduinoProject.host_build_command ~directory
      ~output:executable files
  in
  flush_all ();
  if
    Sys.command (Filename.quote_command (List.hd command) (List.tl command))
    <> 0
  then begin
    prerr_endline "Error: the host build of the project failed";
    exit 1
  end;
  let executable =
    if Filename.is_implicit executable then
      Filename.concat Filename.current_dir_name executable
    else executable
  in
  exit
    (Sys.command (Filename.quote_command executable [ string_of_int duration ]))

(* Writes to the directory [directory], created if missing, the C++ files of
   the [commands] of the program, those of the standard library being the
   commands located in it; under --device, the PlatformIO project of the
   device, whose task functions are found among the [definitions] of the
   program's sources, each with the effect of its type, and whose operations
   are monitored against the bounds of the declared [operations]. *)
let emit_arduino config ~directory ~definitions ~operations commands =
  let library, sources =
    List.partition
      (fun (cmd : _ Ast.command) -> cmd.at.filename = stdlib_filename)
      commands
  in
  let program =
    ArduinoBackend.ArduinoFragment.check ~runs:config.host_runs ~library sources
  in
  let source =
    match List.rev config.filenames with
    | last :: _ -> Filename.basename last
    | [] -> "the standard library"
  in
  let files =
    match config.device with
    | None ->
        (ArduinoBackend.ArduinoEmit.compile ~host_runs:config.host_runs ~source
           program)
          .files
    | Some manifest ->
        let module Project = ArduinoBackend.ArduinoProject in
        let device =
          ArduinoBackend.ArduinoDevice.parse ~filename:manifest
            (read_file manifest)
        in
        let bindings =
          Option.map
            (fun (name : string Utils.Location.located) ->
              let path =
                if Filename.is_relative name.it then
                  Filename.concat (Filename.dirname manifest) name.it
                else name.it
              in
              (path, read_file path))
            device.bindings
        in
        let monitor =
          match config.monitor with
          | None | Some OpentronsBackend.OpentronsProtocol.Abort ->
              Project.Abort
          | Some Warn -> Project.Warn
          | Some Off -> Project.Off
        in
        Project.files
          { device; monitor; source; definitions; operations; bindings }
          program
  in
  (try
     List.iter
       (fun (name, _) ->
         make_directory (Filename.dirname (Filename.concat directory name)))
       files
   with Sys_error message ->
     prerr_endline ("Error: " ^ message);
     exit 1);
  List.iter
    (fun (name, contents) ->
      write_file (Filename.concat directory name) contents)
    files;
  Option.iter
    (fun duration -> host_simulate ~directory ~duration files)
    config.host_simulate

(* Writes to [filename] the Opentrons protocol of the [commands] of the
   program, with the binding file [binding_name], or reports the errors that
   refuse it. The protocol is named after the last source file. *)
let emit_protocol config ~filename ~binding_name ~operations ~compound commands
    =
  let module P = OpentronsBackend.OpentronsProtocol in
  let binding =
    try In_channel.with_open_text binding_name In_channel.input_all
    with Sys_error message ->
      prerr_endline ("Error: " ^ message);
      exit 1
  in
  let robot = Option.value config.robot ~default:P.Flex in
  let source =
    match List.rev config.filenames with
    | last :: _ -> Filename.basename last
    | [] -> "the standard library"
  in
  let options =
    {
      P.robot;
      api_level =
        Option.value config.api_level ~default:(P.default_api_level robot);
      time_unit =
        Option.value config.time_unit ~default:(Grades.Rational.of_int 1);
      monitor = Option.value config.monitor ~default:P.Abort;
      name = Filename.remove_extension source;
      source;
    }
  in
  match
    P.protocol options ~operations ~compound ~binding_name ~binding commands
  with
  | Ok (protocol, warnings) ->
      List.iter (fun w -> prerr_endline ("Warning: " ^ w)) warnings;
      write_file filename protocol;
      if config.simulate then simulate ?simulator:config.simulator filename
  | Error errors ->
      List.iter (fun e -> prerr_endline ("Error: " ^ e)) errors;
      exit 1

let run_with (module G : Grades.Grade.S) config =
  let module Backend = CliInterpreter.Make (Grades.GradeSystem.Identity (G)) in
  let module Loader = Loader.Loader (Backend) in
  (* The timeline of the run [run_num], as a table. *)
  let print_timeline timeline run_num =
    print_string
      (Timeline.text ~full:config.timeline_full
         (Timeline.report ~run:run_num timeline));
    print_newline ()
  in
  (* Runs the program from [state], each step chosen at random among those
     available, and prints each run as it ends, followed by its timeline under
     [--timeline]. The timeline observes a step before the state it leaves is
     printed, so that it holds the end of the run printed. *)
  let rec run (state : Backend.run_state) run_num timeline =
    let step =
      match Backend.steps state with
      | [] -> None
      | steps -> Some (List.nth steps (Random.int (List.length steps)))
    in
    let timeline =
      Option.fold ~none:timeline
        ~some:(fun (step : Backend.step) ->
          List.fold_left
            (Fun.flip Timeline.observe)
            timeline
            (Backend.observe state step))
        step
    in
    let printed = Backend.view_run_state state ~run_num in
    if printed && config.timeline then print_timeline timeline run_num;
    let next_run_num = if printed then run_num + 1 else run_num in
    Option.iter
      (fun (step : Backend.step) ->
        run (step.next_state ()) next_run_num timeline)
      step
  in
  try
    Random.self_init ();
    (* Every source is parsed before any is loaded, so that the grades of the
       program are read over the operations all of them declare. *)
    let files = List.map Loader.parse_file config.filenames in
    let program = Loader.load_program ~use_stdlib:config.use_stdlib files in
    let diagnostics = program.diagnostics in
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
    let run_state = Backend.run program.loaded.backend in
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
        print_definitions program.library;
        print_newline ()
      end;
      print_endline "=== Top-level definitions ===";
      print_definitions
        ~skip:(List.length (definitions program.library))
        program.loaded;
      print_newline ()
    end;
    (* loading the files has typechecked every command, the [run]s included *)
    match (Option.map emit_path config.emit_opentrons, config.bind) with
    | _ when config.emit_arduino <> None ->
        let effect_of scheme =
          match Loader.TC.function_effect program.loaded.typechecker scheme with
          | Typechecker.Not_a_function ->
              ArduinoBackend.ArduinoProject.Not_a_function
          | Typechecker.Effect_variable -> Effect_variable
          | Typechecker.Effect { grade; durations } ->
              Effect { grade; durations }
        in
        emit_arduino config
          ~directory:(arduino_directory (Option.get config.emit_arduino))
          ~definitions:
            (List.map
               (fun (d : Loader.definition) -> (d.variable, effect_of d.scheme))
               program.definitions)
          ~operations:program.operations program.commands
    | Some filename, None ->
        write_file filename
          (OpentronsBackend.OpentronsEmit.plain_program
             ~operations:program.operations program.commands)
    | Some filename, Some binding_name ->
        emit_protocol config ~filename ~binding_name
          ~operations:program.operations ~compound:program.compound_operations
          program.commands
    | None, _ ->
        if not config.typecheck_only then run run_state 1 Timeline.empty
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
