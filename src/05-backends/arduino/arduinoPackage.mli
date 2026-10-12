(** Peripheral packages: reusable operations of devices, with their Tempore
    declarations, their C++ implementations and their host models.

    A package is a directory [libraries/NAME/] of the backend, embedded in the
    compiler; adding a package means adding a directory. Its descriptor
    [package.json] is a JSON object with the members:

    - ["description"] (required): a string describing the package;
    - ["declarations"] (required): the Tempore file of the package, which
      declares its operations, each with the bounds of its running time and a
      default implementation that simulates that time by a delay, and may define
      types and functions; the file is loaded before the sources of a program
      that uses the package;
    - ["grades"] (required): the names of the grades under which the
      declarations are read;
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
    the program does not perform are not generated. *)

type t = {
  name : string;
  description : string;
  declarations : string;
      (** the file name of the declarations, under which their locations are
          reported: [libraries/NAME/FILE] *)
  declarations_source : string;  (** the text of the declarations *)
  grades : string list;
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
(** [source filename] is the text of the declarations of the package whose
    {!t.declarations} is [filename], if any. *)

val check_grades : grades:string -> t -> (unit, string) result
(** [check_grades ~grades package] is an error message if the declarations of
    [package] are not read under the grades named [grades]. *)
