module Json = ArduinoJson
module Location = Utils.Location
module Error = Utils.Error
module Rational = Grades.Rational

type name = string Location.located

type kind =
  | Periodic of {
      period_us : int;
      period_ms : int;
      period : Rational.t;
      initial : name option;
    }
  | Free of { repeat : bool }

type task = {
  function_name : name;
  kind : kind;
  core : int;
  core_at : Location.t;
  priority : int;
  stack : int;
}

type t = {
  filename : string;
  at : Location.t;
  board : name;
  unit_us : Rational.t;
  tasks : task list;
  packages : name list;
  bindings : name option;
  safe_state : name option;
  host_models : name list;
}

let located decode ~what (v : Json.t) =
  { Location.it = decode ~what v; at = v.at }

(* The bound of the numerator and the denominator of the time unit, 2^30, under
   which the conversion of a delay to microseconds in 64-bit unsigned
   arithmetic does not overflow. *)
let unit_term_bound = Z.shift_left Z.one 30

let time_unit ~what (v : Json.t) =
  match v.value with
  | Json.String "ms" -> Rational.of_int 1000
  | Json.String "us" -> Rational.of_int 1
  | Json.String "s" -> Rational.of_int 1_000_000
  | Json.Number _ -> (
      match Json.rational ~what v with
      | q
        when Rational.sign q > 0
             && Rational.compare q (Rational.of_int 1_000_000_000) <= 0
             && Z.lt (Rational.num q) unit_term_bound
             && Z.lt (Rational.den q) unit_term_bound ->
          q
      | _ ->
          Error.compilation ~loc:v.at
            "The time unit must be a positive number of microseconds, at most \
             10^9, whose numerator and denominator in lowest terms are below \
             2^30")
  | _ ->
      Error.compilation ~loc:v.at
        "The time unit must be ms, us, s or a positive number of microseconds"

(* A C++ identifier that is not reserved for the compiler. *)
let identifier ~what (v : Json.t) =
  let s = Json.string ~what v in
  let ok =
    s <> ""
    && (match s.[0] with 'a' .. 'z' | 'A' .. 'Z' | '_' -> true | _ -> false)
    && String.for_all
         (function
           | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' -> true | _ -> false)
         s
    && not (String.starts_with ~prefix:"tempore" s)
  in
  if ok then s
  else
    Error.compilation ~loc:v.at
      "%s must be a C++ identifier that does not start with tempore"
      (String.capitalize_ascii what)

let in_range ~what ~lo ~hi fields name default =
  match Json.optional fields name Json.int with
  | None -> default
  | Some n when n >= lo && n <= hi -> n
  | Some _ ->
      Error.compilation
        ~loc:(Json.location fields name)
        "%s must be from %d to %d"
        (String.capitalize_ascii what)
        lo hi

let task ~unit_us ~what v =
  let f =
    Json.fields ~what
      ~accepted:
        [
          "function";
          "kind";
          "period";
          "initial";
          "repeat";
          "core";
          "priority";
          "stack";
        ]
      v
  in
  let function_name = Json.required f "function" (located Json.string) in
  let kind_name = Json.required f "kind" (located Json.string) in
  let period = Json.optional f "period" Json.rational in
  let initial = Json.optional f "initial" (located Json.string) in
  let repeat = Json.optional f "repeat" Json.bool in
  let kind =
    match (kind_name.it, period) with
    | "periodic", None ->
        Error.compilation ~loc:v.at "A periodic task needs the member 'period'"
    | "periodic", Some _ when repeat <> None ->
        Error.compilation ~loc:(Json.location f "repeat")
          "A periodic task is repeated by its period; the member 'repeat' is \
           for free tasks"
    | "periodic", Some period ->
        let us = Rational.mul period unit_us in
        let ms = Rational.div us (Rational.of_int 1000) in
        let period_ms =
          match Rational.to_int ms with
          | Some ms when Rational.sign period > 0 && ms <= 0x7FFF_FFFF / 1000 ->
              ms
          | _ ->
              Error.compilation ~loc:(Json.location f "period")
                "The period of a periodic task must be a positive whole number \
                 of milliseconds, the tick of FreeRTOS, but it is %s \
                 microseconds"
                (Rational.show us)
        in
        Periodic { period_us = period_ms * 1000; period_ms; period; initial }
    | "free", Some _ ->
        Error.compilation ~loc:(Json.location f "period")
          "A free task has no period"
    | "free", None -> (
        match initial with
        | Some name ->
            Error.compilation ~loc:name.at "A free task has no initial state"
        | None -> Free { repeat = Option.value repeat ~default:false })
    | other, _ ->
        Error.compilation ~loc:kind_name.at
          "Unknown kind of task '%s'; accepted: periodic, free" other
  in
  {
    function_name;
    kind;
    core = in_range ~what:("the core of " ^ what) ~lo:0 ~hi:15 f "core" 1;
    core_at = Json.location f "core";
    priority =
      in_range ~what:("the priority of " ^ what) ~lo:1 ~hi:24 f "priority" 1;
    stack =
      in_range
        ~what:("the stack size of " ^ what)
        ~lo:1024 ~hi:(1 lsl 20) f "stack" 4096;
  }

let functions device =
  List.concat_map
    (fun task ->
      task.function_name.it
      ::
      (match task.kind with
      | Periodic { initial = Some initial; _ } -> [ initial.it ]
      | Periodic { initial = None; _ } | Free _ -> []))
    device.tasks

let parse ~filename text =
  let v = Json.parse ~filename text in
  let f =
    Json.fields ~what:"the manifest"
      ~accepted:
        [
          "board";
          "time_unit";
          "tasks";
          "packages";
          "bindings";
          "safe_state";
          "host_models";
        ]
      v
  in
  let board = Json.required f "board" (located Json.string) in
  let unit_us =
    Option.value
      (Json.optional f "time_unit" time_unit)
      ~default:(Rational.of_int 1000)
  in
  let tasks =
    List.mapi
      (fun i v -> task ~unit_us ~what:(Printf.sprintf "task %d" (i + 1)) v)
      (Json.required f "tasks" (Json.list (fun ~what:_ v -> v)))
  in
  if List.is_empty tasks then
    Error.compilation ~loc:(Json.location f "tasks")
      "The manifest declares no task";
  {
    filename;
    at = v.at;
    board;
    unit_us;
    tasks;
    packages =
      Option.value ~default:[]
        (Json.optional f "packages" (Json.list (located Json.string)));
    bindings = Json.optional f "bindings" (located Json.string);
    safe_state = Json.optional f "safe_state" (located identifier);
    host_models =
      Option.value ~default:[]
        (Json.optional f "host_models" (Json.list (located Json.string)));
  }
