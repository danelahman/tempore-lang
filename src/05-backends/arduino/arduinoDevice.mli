(** Device manifests: the declarative description of an application of the
    Arduino backend.

    A manifest is a JSON object with the members:

    - ["board"] (required): the name of a board profile ({!ArduinoBoard});
    - ["time_unit"]: the length of one time unit of the program, ["ms"]
      (default), ["us"] or ["s"], or a positive number of microseconds, at most
      10^9, whose numerator and denominator in lowest terms are below 2^30;
    - ["tasks"] (required): a non-empty array of tasks;
    - ["packages"]: an array of names of peripheral packages ({!ArduinoPackage},
      default none);
    - ["bindings"]: the C++ file of the bindings of the operations of the
      program, relative to the directory of the manifest;
    - ["safe_state"]: the name of the C++ function [void f()] of the binding
      file that puts the device in its safe state;
    - ["host_models"]: an array of C++ files, relative to the directory of the
      manifest, compiled only by the host simulation: the models of the devices
      and of the physical world of the application (default none);
    - ["battery"]: whether the scaffold draws the battery indicator, the charge
      of the battery in percent, in the top right corner of the screen (default
      [false]); it requires a board with M5Unified and the capabilities
      ["display"] and ["battery"] ({!ArduinoBoard}), and is drawn whether or not
      the program uses the display ({!ArduinoProject}).

    A task is an object with the members:

    - ["function"] (required): the name of a top-level function of the program;
    - ["kind"] (required): ["periodic"] or ["free"];
    - ["period"]: for a periodic task, and only for one, its period in time
      units, a whole number of milliseconds (the tick of FreeRTOS);
    - ["initial"]: for a periodic task, the name of a top-level function of type
      [unit -> s] whose result is the initial state of the task; required unless
      [s] is [unit];
    - ["repeat"]: for a free task, and only for one, whether its function is
      called again each time it returns (default [false]);
    - ["core"]: the core the task is pinned to (default 1);
    - ["priority"]: its FreeRTOS priority, from 1 to 24 (default 1);
    - ["stack"]: its stack size in bytes, at least 1024 (default 4096).

    A periodic task calls its function, of type [s -> s], once per period,
    passing the state from one call to the next; a free task calls its function,
    of type [unit -> unit], once, or, if it is repeated, again each time it
    returns, as Arduino's [loop()].

    For example:
    {v
    {
      "board": "esp32-devkit",
      "time_unit": "ms",
      "tasks": [
        { "function": "step", "kind": "periodic", "period": 10,
          "initial": "start", "core": 1, "priority": 2 },
        { "function": "blinker", "kind": "free", "core": 0 }
      ],
      "bindings": "bindings.cpp",
      "safe_state": "safe_state"
    }
    v} *)

type name = string Utils.Location.located
(** A name, with the location of its string in the manifest. *)

type kind =
  | Periodic of {
      period_us : int;  (** the period in microseconds *)
      period_ms : int;  (** the period in milliseconds *)
      period : Grades.Rational.t;  (** the period in time units *)
      initial : name option;
    }
  | Free of { repeat : bool }  (** whether the function is called again *)

type task = {
  function_name : name;
  kind : kind;
  core : int;
  core_at : Utils.Location.t;
  priority : int;
  stack : int;
}
(** A task. *)

type t = {
  filename : string;
  at : Utils.Location.t;  (** the location of the manifest *)
  board : name;
  unit_us : Grades.Rational.t;
      (** the length of one time unit in microseconds *)
  tasks : task list;
  packages : name list;
  bindings : name option;
  safe_state : name option;
  host_models : name list;
  battery : bool;  (** whether the battery indicator is drawn *)
  battery_at : Utils.Location.t;
      (** the location of the member ["battery"], or else of the manifest *)
}
(** A manifest. *)

val functions : t -> string list
(** [functions device] is the names of the task functions and the initial
    functions of the manifest [device], in order. *)

val parse : filename:string -> string -> t
(** [parse ~filename text] is the manifest [text] of the file [filename].

    @raise Utils.Error.Error
      at the first value that is not part of a well-formed manifest. *)
