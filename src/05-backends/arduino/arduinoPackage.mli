(** Peripheral packages: reusable operations of devices, with their Tempore
    declarations, their C++ implementations and their host models.

    A package is a directory [libraries/NAME/] of the backend, embedded in the
    compiler; adding a package means adding a directory. Its descriptor
    [package.json] is a JSON object with the members:

    - ["description"] (required): a string describing the package;
    - ["definitions"]: a Tempore file of types and of functions that perform no
      operation, read under every grade system and loaded before the
      declarations;
    - ["declarations"] (required): the Tempore files of the package, each
      declaring its operations under a grade system, with grades and default
      implementations, and possibly defining types and functions; an object
      mapping the name of each grade system under which the package is read (as
      [--grades] accepts it) to its file, several names possibly sharing one
      file, or the name of a single file, read under the grade systems listed by
      ["grades"];
    - ["grades"]: with a single file of declarations, the names of the grade
      systems under which it is read;
    - ["requires"]: the capabilities of the board the package needs
      ({!ArduinoBoard.t.capabilities}, default none);
    - ["sources"]: C++ files of the package, copied to [src/] of a project;
    - ["host_models"]: C++ files of the package compiled only by the host
      simulation, copied to [host/];
    - ["bindings"]: the operations whose binding functions the sources define;
    - ["init"]: the name of a C++ function [void f()] of the sources called by
      [setup()] after the initialisation of the board and before the tasks are
      created;
    - ["safe_state"]: the name of a C++ function [void f()] of the sources
      called when the device enters its safe state, before the safe-state hook
      of the application.

    The sources include [tempore_bindings.h], which declares, for each operation
    [Op] the program performs, the binding function [binding_Op], the types
    [tempore_argument_Op] and [tempore_result_Op] of its argument and result,
    and the macro [TEMPORE_PERFORMS_Op]; the definition of a binding function is
    enclosed in [#ifdef TEMPORE_PERFORMS_Op], since the types of an operation
    the program does not perform are not generated.

    Under a grade system that bounds durations, the declarations give each
    operation the bounds of its running time, as an interval grade [[lo, hi]] or
    by [within [lo, hi]], and a default implementation that simulates that time
    by a delay; the monitors of a device check these bounds. Under the other
    grade systems an operation has no running-time bounds, and its calls are not
    checked by a monitor.

    A program under the grade system [g] is preceded by the definitions and the
    declarations under [g] of each of its packages ({!files_for}). *)

type file = {
  filename : string;
      (** the name under which its locations are reported: [libraries/NAME/FILE]
      *)
  text : string;
}
(** A Tempore file of a package. *)

type t = {
  name : string;
  description : string;
  definitions : file option;
  declarations : (string * file) list;
      (** the declarations under each grade system, by its name, in the order of
          the descriptor *)
  requires : string list;
  sources : (string * string) list;
      (** the C++ files for the device, each with its text *)
  host_models : (string * string) list;
      (** the C++ files for the host simulation, each with its text *)
  bindings : string list;  (** the names of the operations it binds *)
  init : string option;
  safe_state : string option;
}
(** A package. *)

val names : string list
(** The names of the packages, in alphabetical order. *)

val find : string -> t option
(** [find name] is the package named [name], if any.

    @raise Utils.Error.Error if the embedded package is malformed. *)

val resolve : string Utils.Location.located -> t
(** [resolve name] is the package named [name].

    @raise Utils.Error.Error at [name] if there is none. *)

val source : string -> string option
(** [source filename] is the text of the file of a package, definitions or
    declarations, whose {!file.filename} is [filename], if any. *)

val files_for : grades:string -> t -> (file list, string) result
(** [files_for ~grades package] is the files of [package] that precede a program
    under the grade system named [grades]: its definitions, if any, and its
    declarations under [grades]; an error message if it has none under [grades].
*)
