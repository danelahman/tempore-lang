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
    - ["imu_frequency"], optional, under ["m5unified"]: the frequency in hertz
      of the I2C transactions with the inertial measurement unit, set by
      [M5.Imu.setClock] after [M5.begin] and by the build flag
      [TEMPORE_IMU_FREQUENCY] for the package m5-imu; without it, the default of
      M5Unified, 400 kHz;
    - ["capabilities"]: an array of names of further capabilities of the board
      that peripheral packages may require ({!ArduinoPackage}): ["imu"], an
      inertial measurement unit read through M5Unified, and ["display"], a
      display driven through M5Unified;
    - ["serial_baud"]: the baud rate of the serial port of the log;
    - ["i2c"]: an array of I2C buses, each an object of the ["port"] (the
      [TwoWire] object, e.g. ["Wire"]), the pins ["sda"] and ["scl"] and the
      ["frequency"] in hertz, started by [begin] after the initialisation of
      M5Unified and clocked at the frequency by [setClock], since M5Unified may
      start a bus that shares its port at the default frequency of 100 kHz, on
      which [begin] does not change the frequency;
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
  imu_frequency : int option;
  capabilities : string list;
      (** the capabilities of the board: ["m5unified"] if it is initialised by
          M5Unified, ["i2c"] if it has an I2C bus, and those of the member
          ["capabilities"] *)
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
