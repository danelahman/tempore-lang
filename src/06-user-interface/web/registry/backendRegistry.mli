(** The backends of the web interface.

    A backend is an entry of {!entries}: its name, the inputs it needs besides
    the program, the code it compiles a program to, if any, and the observer of
    interpreter runs, if any, which observes each run and reports on it. The web
    interface lists the backends in a selector, shows their inputs, compiled
    code and reports, and lists in its gallery the examples of the selected
    backend; adding a backend is adding an entry. *)

(** {1 Inputs} *)

(** What an input holds. *)
type input_kind =
  | Text  (** text of several lines, such as the source of a file *)
  | Choice of string list  (** one of the strings listed *)

type input = {
  key : string;
  label : string;
  kind : input_kind;
  default : string;
}
(** An input of a backend: its key, by which settings and the example index name
    it, its label and its value unless set. *)

type settings = (string * string) list
(** Values of inputs, by key. *)

val setting : input list -> settings -> string -> string
(** [setting inputs settings key] is the value [settings] give the input [key]
    of [inputs], or else its default; [""] for a key not among [inputs]. *)

(** {1 Compiled code} *)

type severity = Error | Warning | Note

type message = {
  severity : severity;
  text : string;
  diagnostic : Utils.Diagnostic.t option;
      (** the diagnostic of an error or a warning, located in the program, its
          declarations or the inputs, when the compiler reports one *)
}
(** A message of a compilation. *)

type compiled = {
  code : string option;  (** the code, unless the compilation is refused *)
  language : string;  (** the language of the code, such as ["python"] *)
  messages : message list;
}
(** The outcome of a compilation. *)

type operations =
  (Language.Ast.operation * Grades.Grade.running_time option) list
(** The operations a program declares, each with the bounds of its running time
    if it has any, the upper end possibly infinite. *)

(** The effect of the type of a top-level definition. *)
type function_effect = ArduinoBackend.ArduinoProject.function_effect =
  | Not_a_function
  | Effect_variable  (** an effect with a variable *)
  | Effect of {
      grade : string;  (** the grade, printed *)
      durations : Grades.Grade.durations;  (** the durations of the grade *)
    }

type definitions = (Language.Ast.variable * function_effect) list
(** The top-level definitions of a program, the standard library's excepted, in
    order, each with the effect of its type. *)

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
      (** the name of the compiled code, by which the web interface labels the
          view of it *)
}
(** [compile settings ~operations ~compound ~definitions commands] compiles the
    desugared [commands], accepted by the typechecker, of a program, the
    standard library's and the declarations' ({!entry.declarations}) included,
    whose declared operations are [operations], those of them that are compound
    being [compound], and whose top-level definitions are [definitions]. The
    commands of the editor are those located in the file named [""]. *)

(** {1 Observers} *)

(** What an observer observes of an interpreter run. *)
type event = Backend.observation =
  | Delayed of { at : string; grade : string }
  | Performed of { at : string; op : string; grade : string }
  | Resumed
  | Boxed of { at : string; resource : string; name : string; grade : string }
  | Unboxed of { at : string; resource : string; name : string }
  | Named of { resource : string; name : string }
  | Returned of { at : string; value : string }
  | Stopped of { at : string; op : string }

(** How a row of a report is marked. *)
type status = Timeline.status = Plain | Pending

type row = Timeline.row = {
  cells : string list;
  short : string list;  (** the cells shortened for display *)
  status : status;
  depth : int;  (** positive for the rows shown de-emphasised *)
}

type report = Timeline.report = {
  title : string;
  columns : string list;  (** the headings of the columns of the rows *)
  rows : row list;
  notes : string list;  (** lines shown after the rows *)
  full_notes : string list;  (** the notes with their grades in full *)
}
(** What an observer reports on the events observed. *)

type observer = {
  observe : event -> observer;
  report : report Lazy.t;
  expanded : bool;  (** whether the report is shown unfolded at first *)
}
(** An observer, having observed the events of a run so far. *)

(** {1 Backends} *)

type source = {
  filename : string;
  text : string;
  running_times : (string * Grades.Grade.running_time) list;
      (** the running-time bounds, by operation, that replace those the source
          declares ({!Loader.with_running_times}) *)
}
(** A source loaded before the program, under its file name. *)

type entry = {
  key : string;  (** by which the example index names the backend *)
  name : string;  (** shown in the selector *)
  description : string;  (** one sentence *)
  inputs : input list;
  compiler : compiler option;
  observer : (settings -> observer) option;
      (** the observer of a run, before any event *)
  declarations : settings -> grades:string -> (source list, string) result;
      (** the sources loaded before the program under the grades named [grades],
          in order, or else why they cannot be loaded under them *)
  files : (string * string) list;
      (** the file names under which the compiler locates the diagnostics of the
          text of its inputs, each with the key of the input *)
}

val interpreter : entry
(** The interpreter alone: no inputs and no compiled code. The observer is the
    timeline of the run ({!Timeline}), folded at first. *)

val arduino : entry
(** PlatformIO projects of the Arduino backend
    ({!ArduinoBackend.ArduinoProject}). The inputs are the device manifest
    ({!ArduinoBackend.ArduinoDevice}), the binding file it names and the monitor
    policy. The declarations are those of the peripheral packages of the
    manifest ({!ArduinoBackend.ArduinoPackage}), each once, with the
    running-time bounds of the board of the manifest; none for a blank or
    malformed manifest. The compiled code is the configuration, [main.cpp], the
    program and the operation wrappers of the project, one file after another,
    each after a comment line naming it; a blank manifest compiles the program
    alone ({!ArduinoBackend.ArduinoEmit}). Under a manifest, the warnings of the
    check ({!ArduinoBackend.ArduinoFragment.program}) are messages of severity
    [Warning] with their diagnostics. The observer is the timeline of the run
    ({!Timeline}), unfolded at first. *)

val opentrons : entry
(** Opentrons protocols ({!OpentronsBackend.OpentronsProtocol}). The inputs are
    the binding file, the robot, the time unit and the monitor policy. Without a
    binding file the program compiles to a plain Python program
    ({!OpentronsBackend.OpentronsEmit.plain_program}). The observer is the
    timeline of the run ({!Timeline}), unfolded at first; its cells are grades,
    so the time unit does not apply to them. *)

val entries : entry list
(** The backends, in the order of the selector, {!interpreter} first. *)

val default : entry
(** The backend selected as the page opens, {!interpreter}. *)

val find : string -> entry option
(** [find key] is the backend of [key], if any. *)

val input_of_file : string -> input option
(** [input_of_file filename] is the input of a backend of {!entries} whose text
    the compiler locates under [filename] ({!entry.files}), if any. *)
