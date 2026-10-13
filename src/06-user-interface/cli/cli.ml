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
    match ArduinoBackend.ArduinoPackage.source filename with
    | Some text -> Some text
    | None -> (
        try Some (In_channel.with_open_text filename In_channel.input_all)
        with Sys_error _ -> None)

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
  packages : string list;
  host_runs : bool;
  host_simulate : int option;
  profile : bool;
  capture : int option;
  build : bool;
  upload : bool;
  port : string option;
  pio : string option;
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

(* The number of microseconds of [s], a positive decimal number of seconds,
   the argument of the option [option]. *)
let duration_of_string option s =
  let bad () =
    raise
      (Arg.Bad
         (Printf.sprintf
            "option '%s': '%s' is not a positive number of seconds of at most \
             10^6"
            option s))
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
  and packages = ref []
  and host_runs = ref false
  and host_simulate = ref None
  and profile = ref false
  and capture = ref None
  and build = ref false
  and upload = ref false
  and port = ref None
  and pio = ref None
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
        ( "--build",
          Arg.Set build,
          " Build the project written with --device with PlatformIO, passing \
           its output through and exiting with its exit code" );
        ( "--capture",
          Arg.String
            (fun s -> capture := Some (duration_of_string "--capture" s)),
          " After --upload, read the serial port of --port at the baud rate of \
           the board for the given number of seconds, printing its lines, and \
           then the last complete profile among them, if any" );
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
            (fun s ->
              host_simulate := Some (duration_of_string "--host-simulate" s)),
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
        ( "--package",
          Arg.String
            (fun name ->
              if List.mem name ArduinoBackend.ArduinoPackage.names then
                packages := name :: !packages
              else
                raise
                  (Arg.Bad
                     (Printf.sprintf "option '--package': '%s' is not one of %s"
                        name
                        (String.concat ", " ArduinoBackend.ArduinoPackage.names)))),
          " Load the declarations of the operations of the given peripheral \
           package of the Arduino backend before the files, so that the \
           program may perform them, run by their default implementations; \
           repeatable; the packages of a device written with --device are \
           those of its manifest" );
        ( "--pio",
          Arg.String (fun path -> pio := Some path),
          " Use the given executable as the PlatformIO of --build and --upload \
           (default: pio on the PATH, or else in _arduino/venv)" );
        ( "--port",
          Arg.String (fun name -> port := Some name),
          " Upload through the given serial port under --upload (default: the \
           port PlatformIO detects)" );
        ( "--profile",
          Arg.Set profile,
          " Build the project written with --device with the profile of the \
           running times of its operations and periodic tasks, logged every 5 \
           seconds in place of the trace under --host-simulate" );
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
        ( "--upload",
          Arg.Set upload,
          " Build the project written with --device with PlatformIO and upload \
           it to the board, passing its output through and exiting with its \
           exit code" );
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
  requires "--build" !build "--device" (!device <> None);
  requires "--upload" !upload "--device" (!device <> None);
  requires "--port" (!port <> None) "--upload" !upload;
  requires "--profile" !profile "--device" (!device <> None);
  requires "--capture" (!capture <> None) "--upload" !upload;
  requires "--capture" (!capture <> None) "--port" (!port <> None);
  if !pio <> None && not (!build || !upload) then begin
    Printf.eprintf "%s: option '--pio' requires '--build' or '--upload'.\n"
      Sys.argv.(0);
    exit 2
  end;
  List.iter
    (fun (option, given) ->
      if given && !host_simulate <> None then begin
        Printf.eprintf
          "%s: option '%s' cannot be used with '--host-simulate'.\n"
          Sys.argv.(0) option;
        exit 2
      end)
    [ ("--build", !build); ("--upload", !upload) ];
  if !build && !upload then begin
    Printf.eprintf "%s: option '--build' cannot be used with '--upload'.\n"
      Sys.argv.(0);
    exit 2
  end;
  List.iter
    (fun (option, given) ->
      if given && !device <> None then begin
        Printf.eprintf "%s: option '%s' cannot be used with '--device'.\n"
          Sys.argv.(0) option;
        exit 2
      end)
    [ ("--host-runs", !host_runs); ("--package", !packages <> []) ];
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
    packages = List.rev !packages;
    host_runs = !host_runs;
    host_simulate = !host_simulate;
    profile = !profile;
    capture = !capture;
    build = !build;
    upload = !upload;
    port = !port;
    pio = !pio;
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

(* The installation directory [name] of an optional tool, in the directory of
   the executable or else in the current directory, with the path of the
   tool's executable [path] relative to it, if it holds that executable. *)
let find_installation name path =
  let executable_dir =
    let dir = Filename.dirname Sys.executable_name in
    if Filename.is_relative dir then Filename.concat (Sys.getcwd ()) dir
    else dir
  in
  List.find_map
    (fun dir ->
      let installation = Filename.concat dir name in
      let executable = List.fold_left Filename.concat installation path in
      if Sys.file_exists executable && not (Sys.is_directory executable) then
        Some (installation, executable)
      else None)
    [ executable_dir; Sys.getcwd () ]

(* Runs an optional tool with [arguments], its output passed through, and is
   its exit code. The tool is [explicit], or else [name] on the PATH, or
   else the executable [path] of the installation [installation]
   ({!find_installation}), run with the environment variable [variable] set to
   the subdirectory [subdirectory] of the installation unless the environment
   sets it. If there is none, the error [missing explicit] or [absent] is
   reported and the program exits with code 1. *)
let run_tool ?explicit ~name ~installation:(installation, path)
    ~variable:(variable, subdirectory) ~missing ~absent arguments =
  let command =
    match explicit with
    | Some path when Sys.file_exists path ->
        Some (Filename.quote_command path arguments)
    | Some _ -> None
    | None -> (
        match find_on_path name with
        | Some path -> Some (Filename.quote_command path arguments)
        | None ->
            Option.map
              (fun (dir, path) ->
                match Sys.getenv_opt variable with
                | Some _ -> Filename.quote_command path arguments
                | None ->
                    Filename.quote_command "env"
                      ((variable ^ "=" ^ Filename.concat dir subdirectory)
                      :: path :: arguments))
              (find_installation installation path))
  in
  match command with
  | None ->
      prerr_endline
        (match explicit with Some path -> missing path | None -> absent);
      exit 1
  | Some command ->
      flush_all ();
      Sys.command command

(* Runs the Opentrons simulator on the protocol [filename], its output passed
   through, and exits with its exit code. The simulator is [simulator], or
   else [opentrons_simulate] on the PATH, or else that of the virtual
   environment [_opentrons] of [make opentrons-deps], run with
   OT_API_CONFIG_DIR set to its directory [config] unless the environment sets
   it. *)
let simulate ?simulator filename =
  exit
  @@ run_tool ?explicit:simulator ~name:"opentrons_simulate"
       ~installation:("_opentrons", [ "bin"; "opentrons_simulate" ])
       ~variable:("OT_API_CONFIG_DIR", "config")
       ~missing:
         (Printf.sprintf "Error: the Opentrons simulator '%s' was not found")
       ~absent:
         "Error: the Opentrons simulator opentrons_simulate was not found on \
          the PATH or in _opentrons; 'make opentrons-deps' installs it with \
          Python 3.10 or later"
       [ filename ]

(* Runs PlatformIO on the project in [directory], building it, or under
   [upload] building and uploading it, through the serial port [port] if
   given, its output passed through, and is its exit code.
   PlatformIO is [pio], or else [pio] on the PATH, or else that of the
   installation [_arduino] of [make arduino-deps], run with
   PLATFORMIO_CORE_DIR set to its directory [platformio] unless the
   environment sets it. *)
let platformio ?pio ~upload ?port directory =
  run_tool ?explicit:pio ~name:"pio"
    ~installation:("_arduino", [ "venv"; "bin"; "pio" ])
    ~variable:("PLATFORMIO_CORE_DIR", "platformio")
    ~missing:(Printf.sprintf "Error: PlatformIO '%s' was not found")
    ~absent:
      "Error: PlatformIO pio was not found on the PATH or in _arduino/venv; \
       'make arduino-deps' installs it with Python 3.10 or later"
    ([ "run"; "-d"; directory ]
    @ (if upload then [ "-t"; "upload" ] else [])
    @ match port with Some port -> [ "--upload-port"; port ] | None -> [])

(* The beginning and the end of a profile in the log of a device. *)
let profile_start = "] Profile since start-up"
and profile_end = "] End of the profile"

(* Whether [line] contains [part]. *)
let contains line part =
  let n = String.length part and m = String.length line in
  let rec from i = i + n <= m && (String.sub line i n = part || from (i + 1)) in
  from 0

(* Opens the serial port [port] for reading, retrying until the time
   [deadline] of [Unix.gettimeofday] while it is missing, as while a board
   restarts. A terminal is opened without waiting for a carrier and set to
   raw input at [baud] bauds, its modem control lines left as opening it sets
   them and kept when it is closed; a port that is not a terminal is read as
   it is. *)
let rec open_port ~deadline ~baud port =
  match
    Unix.openfile port [ Unix.O_RDONLY; Unix.O_NOCTTY; Unix.O_NONBLOCK ] 0
  with
  | fd ->
      (match Unix.tcgetattr fd with
      | attributes ->
          Unix.tcsetattr fd Unix.TCSANOW
            {
              attributes with
              c_ibaud = baud;
              c_obaud = baud;
              c_csize = 8;
              c_cstopb = 1;
              c_parenb = false;
              c_cread = true;
              c_clocal = true;
              c_hupcl = false;
              c_icanon = false;
              c_echo = false;
              c_isig = false;
              c_icrnl = false;
              c_inlcr = false;
              c_igncr = false;
              c_ixon = false;
              c_ixoff = false;
              c_istrip = false;
              c_opost = false;
              c_vmin = 0;
              c_vtime = 0;
            }
      | exception Unix.Unix_error (Unix.ENOTTY, _, _) -> ());
      Unix.clear_nonblock fd;
      fd
  | exception Unix.Unix_error (Unix.ENOENT, _, _)
    when Unix.gettimeofday () < deadline ->
      Unix.sleepf 0.1;
      open_port ~deadline ~baud port

(* Reads the serial port [port] at [baud] bauds for [duration] microseconds,
   or until its end or an error of reading, which is reported, printing its
   lines without their carriage returns, and then, if [profile], the last
   complete profile among them, or else a note that there is none; or reports
   the error of opening the port and exits with code 1. *)
let capture ~port ~baud ~duration ~profile =
  let deadline = Unix.gettimeofday () +. (float_of_int duration /. 1e6) in
  match open_port ~deadline ~baud port with
  | exception Unix.Unix_error (error, _, _) ->
      Printf.eprintf "Error: the serial port %s: %s\n" port
        (Unix.error_message error);
      exit 1
  | fd ->
      let buffer = Bytes.create 4096 and line = Buffer.create 160 in
      (* The lines of the profile being read, in reverse order, if any, and
         those of the last complete one, in order. *)
      let current = ref None and last = ref [] in
      let end_line () =
        let text = Buffer.contents line in
        Buffer.clear line;
        print_endline text;
        if contains text profile_start then current := Some [ text ]
        else
          Option.iter
            (fun lines ->
              if contains text profile_end then begin
                last := List.rev (text :: lines);
                current := None
              end
              else if String.starts_with ~prefix:"  " text then
                current := Some (text :: lines))
            !current
      in
      let rec read () =
        let remaining = deadline -. Unix.gettimeofday () in
        if remaining > 0. then
          match Unix.select [ fd ] [] [] remaining with
          | [], _, _ -> ()
          | _ -> (
              match Unix.read fd buffer 0 (Bytes.length buffer) with
              | exception Unix.Unix_error (Unix.EINTR, _, _) -> read ()
              | exception Unix.Unix_error (error, _, _) ->
                  Printf.eprintf "Error: the serial port %s: %s\n" port
                    (Unix.error_message error)
              | 0 -> ()
              | n ->
                  Bytes.iter
                    (function
                      | '\n' -> end_line ()
                      | '\r' -> ()
                      | c -> Buffer.add_char line c)
                    (Bytes.sub buffer 0 n);
                  flush stdout;
                  read ())
          | exception Unix.Unix_error (Unix.EINTR, _, _) -> read ()
      in
      read ();
      if Buffer.length line > 0 then end_line ();
      Unix.close fd;
      if profile then begin
        match !last with
        | [] -> print_endline "No complete profile was read."
        | lines ->
            print_endline "The last profile read:";
            List.iter print_endline lines
      end

(* The path under [name] in [directory]: [name] in [directory] if it has no
   directory component, else [name]. *)
let in_default_directory directory name =
  if Filename.basename name = name then Filename.concat directory name else name

(* The directory, relative to the current directory, of the files written by
   --emit-opentrons under a name without a directory component. *)
let default_emit_directory = Filename.concat "_opentrons" "protocols"

(* The path of the file written by --emit-opentrons under [name]. *)
let emit_path = in_default_directory default_emit_directory

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

(* The directory written by --emit-arduino under [name]. *)
let arduino_directory =
  in_default_directory (Filename.concat "_arduino" "projects")

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
let host_simulate ~directory ~duration ~profile files =
  if find_on_path "c++" = None then begin
    prerr_endline "Error: the C++ compiler c++ was not found on the PATH";
    exit 1
  end;
  let executable =
    Filename.concat (Filename.concat directory "host") "simulation"
  in
  let command =
    ArduinoBackend.ArduinoProject.host_build_command ~profile ~directory
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
   the [commands] of the program, those of the library being the commands
   located in the standard library or in the files [declarations] of the
   packages; under --device, the PlatformIO project of the device of the
   manifest [device], whose task functions are found among the [definitions]
   of the program's sources, each with the effect of its type, and whose
   operations are monitored against the bounds of the declared
   [operations]. *)
let emit_arduino config ~directory ~device ~declarations ~definitions
    ~operations commands =
  let library, sources =
    List.partition
      (fun (cmd : _ Ast.command) ->
        cmd.at.filename = stdlib_filename
        || List.mem cmd.at.filename declarations)
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
    match device with
    | None ->
        (ArduinoBackend.ArduinoEmit.compile ~host_runs:config.host_runs ~source
           program)
          .files
    | Some (manifest, (device : ArduinoBackend.ArduinoDevice.t)) ->
        let module Project = ArduinoBackend.ArduinoProject in
        let read (name : string Utils.Location.located) =
          let path =
            if Filename.is_relative name.it then
              Filename.concat (Filename.dirname manifest) name.it
            else name.it
          in
          (path, read_file path)
        in
        let bindings = Option.map read device.bindings in
        let host_models = List.map read device.host_models in
        let monitor =
          match config.monitor with
          | None | Some OpentronsBackend.OpentronsProtocol.Abort ->
              Project.Abort
          | Some Warn -> Project.Warn
          | Some Off -> Project.Off
        in
        Project.files
          {
            device;
            monitor;
            source;
            definitions;
            operations;
            bindings;
            host_models;
            profile = config.profile;
          }
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
    (fun duration ->
      host_simulate ~directory ~duration ~profile:config.profile files)
    config.host_simulate;
  if config.build || config.upload then begin
    let code =
      platformio ?pio:config.pio ~upload:config.upload ?port:config.port
        directory
    in
    match (config.capture, config.port, device) with
    | Some duration, Some port, Some (_, device) when code = 0 ->
        (* The board is known: the project was written for it. *)
        let board =
          Option.get (ArduinoBackend.ArduinoBoard.find device.board.it)
        in
        let baud = board.serial_baud in
        capture ~port ~baud ~duration ~profile:config.profile;
        exit 0
    | _ -> exit code
  end

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
    (* The manifest of --device, and the peripheral packages whose
       declarations precede the files: those of the manifest, or else those
       of --package. *)
    let device =
      Option.map
        (fun manifest ->
          ( manifest,
            ArduinoBackend.ArduinoDevice.parse ~filename:manifest
              (read_file manifest) ))
        config.device
    in
    let module Package = ArduinoBackend.ArduinoPackage in
    let checked ~refuse (package : Package.t) =
      match Package.files_for ~grades:config.resource_type package with
      | Ok files -> (package, files)
      | Error message -> refuse message
    in
    let packages =
      match device with
      | Some (_, device) ->
          List.map
            (fun (name : string Utils.Location.located) ->
              checked (Package.resolve name) ~refuse:(fun message ->
                  Error.compilation ~loc:name.at "%s" message))
            device.packages
      | None ->
          List.map
            (fun name ->
              checked
                (Option.get (Package.find name))
                ~refuse:(fun message ->
                  prerr_endline ("Error: " ^ message);
                  exit 1))
            config.packages
    in
    (* The files of each package once, in the order of its first mention. *)
    let package_files =
      List.rev
        (List.fold_left
           (fun acc ((p : Package.t), files) ->
             if List.exists (fun ((q : Package.t), _) -> q.name = p.name) acc
             then acc
             else (p, files) :: acc)
           [] packages)
      |> List.concat_map snd
    in
    let declarations =
      List.map (fun (f : Package.file) -> f.filename) package_files
    in
    (* Every source is parsed before any is loaded, so that the grades of the
       program are read over the operations all of them declare. *)
    let files =
      List.map
        (fun (f : Package.file) ->
          Loader.parse_source ~filename:f.filename f.text)
        package_files
      @ List.map Loader.parse_file config.filenames
    in
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
          ~device ~declarations
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
