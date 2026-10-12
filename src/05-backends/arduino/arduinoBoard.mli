(** Board profiles: the data that adapts the generated projects to a board.

    A profile is a JSON object in the file [boards/NAME.json] of the backend,
    embedded in the compiler; adding a board means adding a profile. Its members
    are:

    - ["description"]: a string describing the board;
    - ["platform"], ["board"], ["framework"]: the PlatformIO platform, board
      identifier and framework of the [platformio.ini] of the project;
    - ["lib_deps"], ["build_flags"]: arrays of strings, the library dependencies
      and build flags of [platformio.ini];
    - ["cores"]: the number of processor cores, to which the cores of tasks are
      pinned;
    - ["m5unified"]: whether the board is initialised by M5Unified;
    - ["serial_baud"]: the baud rate of the serial port of the log;
    - ["i2c"]: an array of I2C buses, each an object of the ["port"] (the
      [TwoWire] object, e.g. ["Wire"]), the pins ["sda"] and ["scl"] and the
      ["frequency"] in hertz;
    - ["includes"]: an array of further headers of the initialisation;
    - ["init"]: an array of further C++ statements of the initialisation,
      executed after those the other members imply. *)

type i2c = { port : string; sda : int; scl : int; frequency : int }
(** An I2C bus. *)

type t = {
  name : string;
  description : string;
  platform : string;
  board : string;
  framework : string;
  lib_deps : string list;
  build_flags : string list;
  cores : int;
  m5unified : bool;
  serial_baud : int;
  i2c : i2c list;
  includes : string list;
  init : string list;
}
(** A board profile. *)

val names : string list
(** The names of the board profiles, in alphabetical order. *)

val find : string -> t option
(** [find name] is the board profile named [name], if any.

    @raise Utils.Error.Error if the embedded profile is malformed. *)

val platformio_ini : t -> string
(** [platformio_ini board] is the [platformio.ini] of a project for [board],
    with the single environment named after the board. *)
