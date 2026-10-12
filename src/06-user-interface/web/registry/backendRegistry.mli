(** The backends of the web interface.

    A backend is an entry of {!entries}: its name, the inputs it needs besides
    the program, the code it compiles a program to, if any, and the model of the
    operations of interpreter runs, if any, which observes each run and reports
    on it. The web interface lists the backends in a selector, shows their
    inputs, compiled code and reports, and lists in its gallery the examples of
    the selected backend; adding a backend is adding an entry. *)

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
(** An input of a backend: its key, by which settings and the example manifest
    name it, its label and its value unless set. *)

type settings = (string * string) list
(** Values of inputs, by key. *)

val setting : input list -> settings -> string -> string
(** [setting inputs settings key] is the value [settings] give the input [key]
    of [inputs], or else its default; [""] for a key not among [inputs]. *)

(** {1 Compiled code} *)

type severity = Error | Warning | Note

type message = { severity : severity; text : string }
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

type compiler = {
  compile :
    'rho 'eps.
    settings ->
    operations:operations ->
    ('rho, 'eps) Language.Ast.command list ->
    compiled;
  code_name : string;
      (** the name of the compiled code, by which the web interface labels the
          view of it *)
}
(** [compile settings ~operations commands] compiles the desugared [commands],
    accepted by the typechecker, of a program, the standard library's included,
    whose declared operations are [operations]. *)

(** {1 Operation models} *)

(** What an operation model observes of an interpreter run. *)
type event = Backend.observation =
  | Delayed of Grades.Rational.t
  | Performed of string
  | Resumed
  | Returned of string
  | Stopped of string

(** How a row of a report is marked. *)
type status = Plain | Good | Bad | Pending

type row = { cells : string list; status : status }

type report = {
  title : string;
  columns : string list;  (** the headings of the columns of the rows *)
  rows : row list;
  notes : string list;  (** lines shown after the rows *)
}
(** What an operation model reports on the events observed. *)

type observer = { observe : event -> observer; report : report Lazy.t }
(** An operation model, having observed the events of a run so far. *)

(** {1 Backends} *)

type entry = {
  key : string;  (** by which the example manifest names the backend *)
  name : string;  (** shown in the selector *)
  description : string;  (** one sentence *)
  inputs : input list;
  compiler : compiler option;
  observer : (settings -> operations -> observer) option;
      (** the operation model of a run of a program declaring the operations
          given, before any event *)
}

val interpreter : entry
(** The interpreter alone: no inputs, no compiled code, no operation model. *)

val opentrons : entry
(** Opentrons protocols ({!OpentronsBackend.OpentronsProtocol}). The inputs are
    the binding file, the robot, the time unit and the monitor policy. Without a
    binding file the program compiles to a plain Python program
    ({!OpentronsBackend.OpentronsEmit.plain_program}). The operation model is
    the timeline of the run ({!OpentronsBackend.OpentronsTimeline}), with the
    verdicts of the monitors of the running-time bounds. *)

val entries : entry list
(** The backends, in the order of the selector, {!interpreter} first. *)

val default : entry
(** The backend selected as the page opens, {!interpreter}. *)

val find : string -> entry option
(** [find key] is the backend of [key], if any. *)
