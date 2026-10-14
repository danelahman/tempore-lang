module Rational = Grades.Rational
module Grade = Grades.Grade
module Protocol = OpentronsBackend.OpentronsProtocol
module Emit = OpentronsBackend.OpentronsEmit

type input_kind = Text | Choice of string list

type input = {
  key : string;
  label : string;
  kind : input_kind;
  default : string;
}

type settings = (string * string) list

let setting inputs settings key =
  match List.find_opt (fun (input : input) -> input.key = key) inputs with
  | None -> ""
  | Some input ->
      Option.value (List.assoc_opt key settings) ~default:input.default

type severity = Error | Warning | Note

type message = {
  severity : severity;
  text : string;
  diagnostic : Utils.Diagnostic.t option;
}

type compiled = {
  code : string option;
  language : string;
  messages : message list;
}

type operations =
  (Language.Ast.operation * Grades.Grade.running_time option) list

type function_effect = ArduinoBackend.ArduinoProject.function_effect =
  | Not_a_function
  | Effect_variable
  | Effect of { grade : string; durations : Grades.Grade.durations }

type definitions = (Language.Ast.variable * function_effect) list

type compiler = {
  compile :
    'rho 'eps.
    settings ->
    operations:operations ->
    compound:Language.Ast.operation list ->
    definitions:definitions ->
    ('rho, 'eps) Language.Ast.command list ->
    compiled;
  code_name : string;
}

type source = {
  filename : string;
  text : string;
  running_times : (string * Grades.Grade.running_time) list;
}

type event = Backend.observation =
  | Delayed of { at : string; grade : string }
  | Performed of { at : string; op : string; grade : string }
  | Resumed
  | Boxed of { at : string; resource : string; name : string; grade : string }
  | Unboxed of { at : string; resource : string; name : string }
  | Named of { resource : string; name : string }
  | Returned of { at : string; value : string }
  | Stopped of { at : string; op : string }

type status = Timeline.status = Plain | Pending

type row = Timeline.row = {
  cells : string list;
  short : string list;
  status : status;
  depth : int;
}

type report = Timeline.report = {
  title : string;
  columns : string list;
  rows : row list;
  notes : string list;
  full_notes : string list;
}

type observer = {
  observe : event -> observer;
  report : report Lazy.t;
  expanded : bool;
}

(* The timeline of a run. *)
let timeline ?title ~expanded () =
  let rec observer timeline =
    {
      observe = (fun event -> observer (Timeline.observe event timeline));
      report =
        lazy
          (let report = Timeline.report timeline in
           Option.fold ~none:report
             ~some:(fun title -> { report with title })
             title);
      expanded;
    }
  in
  observer Timeline.empty

type entry = {
  key : string;
  name : string;
  description : string;
  inputs : input list;
  compiler : compiler option;
  observer : (settings -> observer) option;
  declarations : settings -> grades:string -> (source list, string) result;
  files : (string * string) list;
}

let no_declarations _ ~grades:_ = Ok []

let interpreter =
  {
    key = "interpreter";
    name = "Interpreter";
    description =
      "The interpreter, which runs the program step by step and records a \
       timeline of each run.";
    inputs = [];
    compiler = None;
    observer = Some (fun _ -> timeline ~expanded:false ());
    declarations = no_declarations;
    files = [];
  }

(* The monitor policy of a setting, [Abort] unless it names another. *)
let monitor_policy s =
  Option.value (Utils.Monitor.of_name s) ~default:Utils.Monitor.Abort

(* The input of the monitor policy. *)
let monitor_input =
  {
    key = "monitor";
    label = "Monitor";
    kind = Choice (List.map fst Utils.Monitor.policies);
    default = "abort";
  }

(* Opentrons *)

let opentrons_inputs =
  [
    { key = "binding"; label = "Binding file"; kind = Text; default = "" };
    {
      key = "robot";
      label = "Robot";
      kind = Choice [ "flex" ];
      default = "flex";
    };
    {
      key = "time-unit";
      label = "Time unit";
      kind = Choice [ "seconds"; "minutes"; "hours" ];
      default = "seconds";
    };
    monitor_input;
  ]

let opentrons_setting = setting opentrons_inputs

(* The length in seconds of a unit of duration. *)
let time_unit settings =
  match opentrons_setting settings "time-unit" with
  | "minutes" -> Rational.of_int 60
  | "hours" -> Rational.of_int 3600
  | _ -> Rational.of_int 1

let opentrons_compile settings ~operations ~compound ~definitions:_ commands =
  let binding = opentrons_setting settings "binding" in
  if String.trim binding = "" then
    {
      code = Some (Emit.plain_program ~operations commands);
      language = "python";
      messages =
        [
          {
            severity = Note;
            diagnostic = None;
            text =
              "Without a binding file, the program is compiled to a Python \
               program that runs on a virtual clock, its operations performed \
               by their default implementations.";
          };
        ];
    }
  else
    let robot = Protocol.Flex
    and monitor = monitor_policy (opentrons_setting settings "monitor") in
    let options =
      {
        Protocol.robot;
        api_level = Protocol.default_api_level robot;
        time_unit = time_unit settings;
        monitor;
        name = "Tempore program";
        source = "the web interface";
      }
    in
    match
      Protocol.protocol options ~operations ~compound
        ~binding_name:"the binding file" ~binding commands
    with
    | Ok (code, warnings) ->
        {
          code = Some code;
          language = "python";
          messages =
            List.map
              (fun text -> { severity = Warning; text; diagnostic = None })
              warnings;
        }
    | Stdlib.Error errors ->
        {
          code = None;
          language = "python";
          messages =
            List.map
              (fun text -> { severity = Error; text; diagnostic = None })
              errors;
        }

(* The timeline titled with the unit of duration. *)
let opentrons_observer settings =
  let unit =
    match opentrons_setting settings "time-unit" with
    | "minutes" -> "1 min"
    | "hours" -> "1 h"
    | _ -> "1 s"
  in
  timeline
    ~title:(Printf.sprintf "Timeline (one time unit = %s)" unit)
    ~expanded:true ()

let opentrons =
  {
    key = "opentrons";
    name = "Opentrons";
    description =
      "Opentrons protocols in Python, with monitors of the running times of \
       operations; interpreter runs record a timeline.";
    inputs = opentrons_inputs;
    compiler =
      Some { compile = opentrons_compile; code_name = "Opentrons protocol" };
    observer = Some opentrons_observer;
    declarations = no_declarations;
    files = [];
  }

(* Arduino *)

module Device = ArduinoBackend.ArduinoDevice
module Package = ArduinoBackend.ArduinoPackage
module Project = ArduinoBackend.ArduinoProject

let arduino_inputs =
  [
    { key = "manifest"; label = "Device manifest"; kind = Text; default = "" };
    { key = "bindings"; label = "Binding file"; kind = Text; default = "" };
    monitor_input;
  ]

let arduino_setting = setting arduino_inputs

(* The file name under which the manifest is parsed and its diagnostics
   located. *)
let manifest_filename = "device.json"

(* The manifest of [settings], unless its input is blank. *)
let manifest settings =
  let text = arduino_setting settings "manifest" in
  if String.trim text = "" then None
  else Some (Device.parse ~filename:manifest_filename text)

(* The board of the manifest of [settings] and its packages known to the
   registry, each once, in the order of their first mention; no board and no
   packages if the manifest is blank or malformed, whose compilation reports
   it. *)
let arduino_packages settings =
  match manifest settings with
  | None | (exception Utils.Error.Error _) -> (None, [])
  | Some device ->
      ( Some device.board.it,
        List.fold_left
          (fun acc (name : Device.name) ->
            match Package.find name.it with
            | Some p
              when not
                     (List.exists (fun (q : Package.t) -> q.name = p.name) acc)
              ->
                acc @ [ p ]
            | _ -> acc)
          [] device.packages )

let arduino_declarations settings ~grades =
  let board, packages = arduino_packages settings in
  List.fold_left
    (fun acc (p : Package.t) ->
      Result.bind acc (fun sources ->
          Result.map
            (fun files ->
              sources
              @ List.map
                  (fun (f : Package.file) ->
                    {
                      filename = f.filename;
                      text = f.text;
                      running_times = f.running_times;
                    })
                  files)
            (Package.files_for ~grades ?board p)))
    (Ok []) packages

(* The files of a project shown, in order, the others being the runtime
   header, the scaffold, the sources of the packages, the binding file and the
   host simulation. *)
let shown_files =
  [
    "platformio.ini";
    "src/main.cpp";
    "src/tempore_program.h";
    "src/tempore_program.cpp";
    "src/tempore_bindings.h";
    "src/tempore_operations.cpp";
  ]

(* The files [names] of [files] that are present, each after a comment line
   naming it. *)
let concatenated names files =
  String.concat "\n"
    (List.filter_map
       (fun name ->
         Option.map
           (fun contents -> Printf.sprintf "// File %s\n\n%s" name contents)
           (List.assoc_opt name files))
       names)

(* The text of the diagnostic [d], with the lines of the manifest
   [manifest_text] and of the declarations of the packages it points at. *)
let diagnostic_text ~manifest_text d =
  let source filename =
    if filename = manifest_filename then Some manifest_text
    else Package.source filename
  in
  String.trim (Format.asprintf "%t" (Utils.Diagnostic.print ~source d))

let arduino_compile settings ~operations ~compound:_ ~definitions commands =
  let manifest_text = arduino_setting settings "manifest" in
  let library, sources =
    List.partition
      (fun (cmd : _ Language.Ast.command) -> cmd.at.filename <> "")
      commands
  in
  let source = "of the web interface" in
  try
    let device = manifest settings in
    let program =
      ArduinoBackend.ArduinoFragment.check
        ?roots:(Option.map Device.functions device)
        ~runs:false ~library sources
    in
    match device with
    | None ->
        let compiled =
          ArduinoBackend.ArduinoEmit.compile ~host_runs:false ~source program
        in
        {
          code =
            Some
              (concatenated
                 [ "tempore_program.h"; "tempore_program.cpp" ]
                 compiled.files);
          language = "cpp";
          messages =
            [
              {
                severity = Note;
                diagnostic = None;
                text =
                  "Without a device manifest, the program is compiled to C++ \
                   functions alone, its operations calls of functions \
                   implemented outside the program.";
              };
            ];
        }
    | Some device ->
        let file_text (name : Device.name) =
          match device.bindings with
          | Some bindings when bindings.it = name.it ->
              arduino_setting settings "bindings"
          | _ -> ""
        and monitor = monitor_policy (arduino_setting settings "monitor") in
        let files =
          Project.files
            {
              device;
              monitor;
              source;
              definitions;
              operations;
              file_text;
              profile = false;
            }
            program
        in
        let packages =
          List.map
            (fun (p : Package.t) -> p.name)
            (snd (arduino_packages settings))
        in
        let warnings =
          List.map
            (fun d ->
              {
                severity = Warning;
                text = diagnostic_text ~manifest_text d;
                diagnostic = Some d;
              })
            program.warnings
        in
        {
          code = Some (concatenated shown_files files);
          language = "cpp";
          messages =
            warnings
            @ [
                {
                  severity = Note;
                  diagnostic = None;
                  text =
                    Printf.sprintf
                      "The PlatformIO project of the device for the board \
                       %s%s. Not shown: the runtime header, the scaffold, the \
                       sources of the packages, the binding file and the host \
                       simulation."
                      device.board.it
                      (match packages with
                      | [] -> ""
                      | names ->
                          ", with the packages " ^ String.concat ", " names);
                };
              ];
        }
  with Utils.Error.Error d ->
    {
      code = None;
      language = "cpp";
      messages =
        [
          {
            severity = Error;
            text = diagnostic_text ~manifest_text d;
            diagnostic = Some d;
          };
        ];
    }

let arduino =
  {
    key = "arduino";
    name = "Arduino";
    description =
      "C++ for Arduino boards: a PlatformIO project of the tasks of a device \
       manifest, with the declarations of its peripheral packages and monitors \
       of the running times of operations; interpreter runs record a timeline.";
    inputs = arduino_inputs;
    compiler = Some { compile = arduino_compile; code_name = "C++ project" };
    observer = Some (fun _ -> timeline ~expanded:true ());
    declarations = arduino_declarations;
    files = [ (manifest_filename, "manifest") ];
  }

let entries = [ interpreter; arduino; opentrons ]
let default = interpreter
let find key = List.find_opt (fun (entry : entry) -> entry.key = key) entries

let input_of_file filename =
  List.find_map
    (fun (entry : entry) ->
      Option.bind (List.assoc_opt filename entry.files) (fun key ->
          List.find_opt (fun (input : input) -> input.key = key) entry.inputs))
    entries
