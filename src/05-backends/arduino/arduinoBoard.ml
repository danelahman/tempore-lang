module Json = ArduinoJson

type i2c = { port : string; sda : int; scl : int; frequency : int }

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

let names = List.sort String.compare (List.map fst Arduino_boards.profiles)

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
          "description";
          "platform";
          "board";
          "framework";
          "lib_deps";
          "build_flags";
          "cores";
          "m5unified";
          "serial_baud";
          "i2c";
          "includes";
          "init";
        ]
      v
  in
  let strings = Json.list Json.string in
  {
    name;
    description = Json.required f "description" Json.string;
    platform = Json.required f "platform" Json.string;
    board = Json.required f "board" Json.string;
    framework = Json.required f "framework" Json.string;
    lib_deps = Json.required f "lib_deps" strings;
    build_flags = Json.required f "build_flags" strings;
    cores = Json.required f "cores" Json.int;
    m5unified = Json.required f "m5unified" Json.bool;
    serial_baud = Json.required f "serial_baud" Json.int;
    i2c = Json.required f "i2c" (Json.list i2c);
    includes = Json.required f "includes" strings;
    init = Json.required f "init" strings;
  }

let find name =
  Option.map (parse name) (List.assoc_opt name Arduino_boards.profiles)

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
