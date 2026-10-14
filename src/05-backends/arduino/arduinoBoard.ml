module Json = ArduinoJson

type i2c = { port : string; sda : int; scl : int; frequency : int }

type t = {
  name : string;
  title : string;
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
  serial_baud : int;
  i2c : i2c list;
  includes : string list;
  init : string list;
}

(* The texts of the embedded board profiles, each with the name of its
   board. *)
let texts =
  List.map
    (fun (file, text) -> (Filename.chop_suffix file ".json", text))
    Arduino_boards.files

let names = List.sort String.compare (List.map fst texts)

let i2c ~what v =
  let f = Json.fields ~what ~accepted:[ "port"; "sda"; "scl"; "frequency" ] v in
  {
    port = Json.required f "port" Json.string;
    sda = Json.required f "sda" Json.int;
    scl = Json.required f "scl" Json.int;
    frequency = Json.required f "frequency" Json.int;
  }

let parse name text =
  let v = Json.parse ~filename:("boards/" ^ name ^ ".json") text in
  let f =
    Json.fields ~what:"a board profile"
      ~accepted:
        [
          "title";
          "description";
          "platform";
          "board";
          "framework";
          "lib_deps";
          "build_flags";
          "cores";
          "m5unified";
          "imu_frequency";
          "capabilities";
          "serial_baud";
          "i2c";
          "includes";
          "init";
        ]
      v
  in
  let strings = Json.list Json.string in
  let m5unified = Json.required f "m5unified" Json.bool in
  let i2c = Json.required f "i2c" (Json.list i2c) in
  let imu_frequency = Json.optional f "imu_frequency" Json.int in
  if imu_frequency <> None && not m5unified then
    Utils.Error.compilation
      ~loc:(Json.location f "imu_frequency")
      "The member 'imu_frequency' of a board profile requires 'm5unified'";
  {
    name;
    title = Json.required f "title" Json.string;
    description = Json.required f "description" Json.string;
    platform = Json.required f "platform" Json.string;
    board = Json.required f "board" Json.string;
    framework = Json.required f "framework" Json.string;
    lib_deps = Json.required f "lib_deps" strings;
    build_flags = Json.required f "build_flags" strings;
    cores = Json.required f "cores" Json.int;
    m5unified;
    imu_frequency;
    capabilities =
      (if m5unified then [ "m5unified" ] else [])
      @ (if i2c <> [] then [ "i2c" ] else [])
      @ Json.required f "capabilities" strings;
    serial_baud = Json.required f "serial_baud" Json.int;
    i2c;
    includes = Json.required f "includes" strings;
    init = Json.required f "init" strings;
  }

(* The board profiles, each parsed at its first use. *)
let profiles =
  List.map (fun (name, text) -> (name, lazy (parse name text))) texts

let find name = Option.map Lazy.force (List.assoc_opt name profiles)

let platformio_ini board =
  let list key = function
    | [] -> []
    | values -> [ key ^ " =" ] @ List.map (fun value -> "    " ^ value) values
  in
  String.concat "\n"
    ([
       "; The PlatformIO project of a device programmed in Tempore, for the \
        board " ^ board.name ^ ".";
       "";
       "[env:" ^ board.name ^ "]";
       "platform = " ^ board.platform;
       "board = " ^ board.board;
       "framework = " ^ board.framework;
       "monitor_speed = " ^ string_of_int board.serial_baud;
     ]
    @ list "lib_deps" board.lib_deps
    @ list "build_flags" ("-std=gnu++17" :: board.build_flags)
    @ [ "build_unflags = -std=gnu++11"; "" ])
