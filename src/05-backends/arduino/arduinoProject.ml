module Ast = Language.Ast
module Error = Utils.Error
module Rational = Grades.Rational
module Grade = Grades.Grade
module F = ArduinoFragment
module Device = ArduinoDevice
module Board = ArduinoBoard
module Names = ArduinoNames
module Package = ArduinoPackage
module Cpp = ArduinoCpp
module StringSet = Set.Make (String)
module Diagnostic = Utils.Diagnostic

type function_effect =
  | Not_a_function
  | Effect_variable
  | Effect of { grade : string; durations : Grade.durations }

type input = {
  device : Device.t;
  monitor : Utils.Monitor.t;
  source : string;
  definitions : (Ast.variable * function_effect) list;
  operations :
    (Ast.operation * (Rational.t Grade.bound * Rational.t Grade.bound) option)
    list;
  file_text : Device.name -> string;
  profile : bool;
}

(* Types, printed as in the source, the type variables named ['a], ['b], ...
   in the order of the list [metas]. *)

let rec show_ty metas = function
  | F.Nat -> "nat"
  | F.Int -> "int"
  | F.Float -> "float"
  | F.Bool -> "bool"
  | F.String -> "string"
  | F.Tuple [] -> "unit"
  | F.Tuple tys -> String.concat " * " (List.map (show_atom metas) tys)
  | F.Data n -> Ast.TyName.string_of n
  | F.Arrow ((F.Arrow _ as a), b) ->
      "(" ^ show_ty metas a ^ ") -> " ^ show_ty metas b
  | F.Arrow (a, b) -> show_ty metas a ^ " -> " ^ show_ty metas b
  | F.Meta i ->
      let rec index k = function
        | [] -> 0
        | j :: rest -> if i = j then k else index (k + 1) rest
      in
      let k = index 0 metas in
      if k < 26 then Printf.sprintf "'%c" (Char.chr (Char.code 'a' + k))
      else Printf.sprintf "'t%d" k

and show_atom metas = function
  | (F.Tuple (_ :: _) | F.Arrow _) as ty -> "(" ^ show_ty metas ty ^ ")"
  | ty -> show_ty metas ty

let unit_ty = F.Tuple []

(* The type of [d], as a clause of a message. *)
let show_signature (d : F.definition) =
  match F.function_type d with
  | Some (parameters, result) ->
      let tys = parameters @ [ result ] in
      Printf.sprintf "it has the type %s"
        (Diagnostic.code
           (String.concat " -> "
              (List.map (show_atom (F.type_variables tys)) tys)))
  | None -> "it is not a function"

(* Task functions. *)

(* The type a task function must have: [Exactly (p, q)] is [p -> q], and
   [State_step] is [s -> s] for a type [s] without type variables. *)
type expected = Exactly of F.ty * F.ty | State_step

let show_expected = function
  | Exactly (p, q) -> Diagnostic.code (show_atom [] p ^ " -> " ^ show_atom [] q)
  | State_step -> "`s -> s` for a type `s` without type variables"

(* A task function: its definition, its effect and its C++ function. *)
type resolved = {
  definition : F.definition;
  function_effect : function_effect;
  cxx : string;
}

(* The top-level functions of the program's sources, each once, in order. *)
let function_names input =
  List.fold_left
    (fun (seen, names) (x, function_effect) ->
      let name = Ast.Variable.string_of x in
      match function_effect with
      | Not_a_function -> (seen, names)
      | Effect_variable | Effect _ ->
          if StringSet.mem name seen then (seen, names)
          else (StringSet.add name seen, name :: names))
    (StringSet.empty, []) input.definitions
  |> snd |> List.rev

(* The definition of the program's sources named [name], the last of them,
   with its effect and the name of its C++ function among [entries], the
   compiled entry points; it must have the type [expected], [role] naming it
   in the message. The entry points are the functions of the program's
   sources whose types have no type variables. *)
let resolve input (program : F.program) entries ~role ~expected
    (name : Device.name) =
  let unknown () =
    Error.compilation ~loc:name.at
      "Unknown function `%s`; the top-level functions of the program are: %s"
      name.it
      (Diagnostic.code_list (function_names input))
  in
  let named =
    List.filter
      (fun (x, _) -> Ast.Variable.string_of x = name.it)
      input.definitions
  in
  match List.rev named with
  | [] -> unknown ()
  | (x, function_effect) :: _ -> (
      match
        List.find_opt
          (fun (d : F.definition) ->
            d.in_sources && Ast.Variable.equal d.variable x)
          program.definitions
      with
      | None -> unknown ()
      | Some definition -> (
          let fits =
            match (F.function_type definition, expected) with
            | Some ([ p ], q), Exactly (p', q') ->
                F.compare_ty p p' = 0 && F.compare_ty q q' = 0
            | Some ([ p ], q), State_step -> F.compare_ty p q = 0
            | _ -> false
          in
          let entry =
            List.find_map
              (fun (y, cxx) ->
                if Ast.Variable.equal x y then Some cxx else None)
              entries
          in
          match entry with
          | Some cxx when fits -> { definition; function_effect; cxx }
          | _ ->
              Error.compilation ~loc:name.at
                "The function `%s` of %s must have the type %s, but %s" name.it
                role (show_expected expected)
                (show_signature definition)))

(* Whether the upper end [hi] of an interval of durations is below [period]:
   the effect is then below [[0, period)]. *)
let below_period hi period =
  match hi with
  | Grade.Closed q -> Rational.compare q period < 0
  | Grade.Open q -> Rational.compare q period <= 0
  | Grade.Unbounded -> false

let check_period (name : Device.name) r period =
  match r.function_effect with
  | Not_a_function -> ()
  | Effect_variable ->
      Error.compilation ~loc:name.at
        "The effect of the function `%s` of a periodic task has a variable; \
         annotate the function with an effect whose durations are below its \
         period %s"
        name.it (Rational.show period)
  | Effect { durations = Grade.Untimed; _ } -> ()
  | Effect { grade; durations = Grade.Undetermined } ->
      Error.compilation ~loc:name.at
        "The effect `%s` of the function `%s` of a periodic task does not \
         bound its durations, so it is not below the period %s"
        grade name.it (Rational.show period)
  | Effect { grade; durations = Grade.Duration_interval (_, hi) } ->
      if not (below_period hi period) then
        Error.compilation ~loc:name.at
          "The effect `%s` of the function `%s` of a periodic task is not \
           below its period: its durations are not all below %s"
          grade name.it (Rational.show period)

(* Whether a lower end of an interval of durations is positive. *)
let takes_time = function
  | Grade.Closed q | Grade.Open q -> Rational.sign q > 0
  | Grade.Unbounded -> false

let check_repeat (name : Device.name) r =
  let fail grade =
    Error.compilation ~loc:name.at
      "The effect `%s` of the function `%s` of a repeated free task does not \
       bound its durations below by a positive time, so that the task may \
       never yield"
      grade name.it
  in
  match r.function_effect with
  | Not_a_function -> ()
  | Effect_variable ->
      Error.compilation ~loc:name.at
        "The effect of the function `%s` of a repeated free task has a \
         variable; annotate the function with an effect whose durations are \
         bounded below by a positive time"
        name.it
  | Effect { durations = Grade.Untimed; _ } -> ()
  | Effect { grade; durations = Grade.Undetermined } -> fail grade
  | Effect { grade; durations = Grade.Duration_interval (lo, _) } ->
      if not (takes_time lo) then fail grade

type task_code = {
  task : Device.task;
  step : resolved;
  initial : resolved option;
}

(* The functions of [task], checked against its kind. *)
let task_code input program entries (task : Device.task) =
  let name = task.function_name in
  let resolve = resolve input program entries in
  match task.kind with
  | Device.Free { repeat } ->
      let step =
        resolve ~role:"a free task" ~expected:(Exactly (unit_ty, unit_ty)) name
      in
      if repeat then check_repeat name step;
      { task; step; initial = None }
  | Device.Periodic { period; initial; _ } ->
      let step = resolve ~role:"a periodic task" ~expected:State_step name in
      let state =
        match F.function_type step.definition with
        | Some (_, state) -> state
        | None -> unit_ty
      in
      check_period name step period;
      let initial =
        match initial with
        | Some initial_name ->
            Some
              (resolve ~role:"the initial state of a periodic task"
                 ~expected:(Exactly (unit_ty, state))
                 initial_name)
        | None ->
            if F.compare_ty state unit_ty <> 0 then
              Error.compilation ~loc:name.at
                "The periodic task of the function `%s` has the state type \
                 `%s`, so it needs the member `initial`"
                name.it (show_ty [] state);
            None
      in
      { task; step; initial }

(* Bindings. *)

(* Whether [text] contains the identifier [id] as a whole word. *)
let mentions text id =
  let n = String.length id and m = String.length text in
  let rec from i =
    if i + n > m then false
    else if
      String.sub text i n = id
      && (i = 0 || not (Cpp.is_identifier_char text.[i - 1]))
      && (i + n = m || not (Cpp.is_identifier_char text.[i + n]))
    then true
    else from (i + 1)
  in
  from 0

(* Rendering. *)

(* The end [b] of the bounds of an operation, times [unit_us], in whole
   microseconds, rounded outwards: the value, whether it is open, and whether
   it is finite. Values beyond 2^62 microseconds are taken as infinite. *)
let end_us ~lower ~unit_us b =
  let limit = Z.shift_left Z.one 62 in
  match b with
  | Grade.Unbounded -> ("0", false, false)
  | Grade.Closed q | Grade.Open q ->
      let x = Rational.mul q unit_us in
      let exact = Rational.is_integer x in
      let n =
        if lower then Z.fdiv (Rational.num x) (Rational.den x)
        else Z.cdiv (Rational.num x) (Rational.den x)
      in
      let opened = exact && match b with Grade.Open _ -> true | _ -> false in
      if Z.gt n limit then
        if lower then (Z.to_string limit, false, true) else ("0", false, false)
      else (Z.to_string n, opened, true)

let bounds_initialiser ~unit_us (lo, hi) =
  let lo_value, lo_open, _ = end_us ~lower:true ~unit_us lo in
  let hi_value, hi_open, hi_finite = end_us ~lower:false ~unit_us hi in
  Printf.sprintf "{%s, %b, %s, %b, %b}" lo_value lo_open hi_value hi_open
    hi_finite

let generated source what =
  Cpp.comment
    (Printf.sprintf "%s of the program %s, generated by Tempore." what source)

(* The initialisation functions and the safe-state functions of [packages],
   in order. *)
let package_hooks packages =
  let hooks f = List.filter_map (fun (p : Package.t) -> f p) packages in
  (hooks (fun p -> p.init), hooks (fun p -> p.safe_state))

let bindings_header input packages (compiled : ArduinoEmit.compiled) =
  let inits, safe_states = package_hooks packages in
  Cpp.render
    ([
       generated input.source
         "The declarations of the binding functions and of the hooks";
       Cpp.blank;
       Cpp.Line "#ifndef TEMPORE_BINDINGS_H";
       Cpp.define "TEMPORE_BINDINGS_H";
       Cpp.blank;
       Cpp.local_include "tempore_program.h";
       Cpp.local_include "tempore_scaffold.h";
     ]
    @ (match compiled.operation_types with
      | [] -> []
      | ops ->
          Cpp.blank
          :: Cpp.comment
               "The operations performed: the types of their arguments and \
                results, and their binding functions."
          :: List.concat_map
               (fun (op, (argument, result)) ->
                 let name = Ast.OpName.string_of op in
                 [
                   Cpp.blank;
                   Cpp.define (Names.performs name);
                   Cpp.typedef argument (Names.argument_type name);
                   Cpp.typedef result (Names.result_type name);
                   Cpp.prototype result (Names.binding name) [ argument ];
                 ])
               ops)
    @ (match input.device.safe_state with
      | None -> []
      | Some hook ->
          [
            Cpp.blank;
            Cpp.comment "The safe state.";
            Cpp.prototype "void" hook.it [];
          ])
    @ (match inits @ safe_states with
      | [] -> []
      | hooks ->
          Cpp.blank
          :: Cpp.comment
               "The initialisation and safe-state functions of the packages."
          :: List.map (fun f -> Cpp.prototype "void" f []) hooks)
    @ [ Cpp.blank; Cpp.Line "#endif" ])

let operations_source input (compiled : ArduinoEmit.compiled) =
  let unit_us = input.device.unit_us in
  let operation (op, (argument, result)) =
    let name = Ast.OpName.string_of op in
    let bounds =
      List.find_map
        (fun (op', bounds) ->
          if Ast.OpName.string_of op' = name then Some bounds else None)
        input.operations
      |> Option.join
    in
    let bounds_name = Names.bounds name in
    (match bounds with
      | Some b ->
          [
            Cpp.constant ~static:true "tempore_bounds" bounds_name
              (bounds_initialiser ~unit_us b);
          ]
      | None -> [])
    @ [
        Cpp.statement
          ("static tempore_operation_monitor "
          ^ Cpp.call (Names.monitor name)
              [
                Cpp.string_literal name;
                (match bounds with
                | Some _ -> "&" ^ bounds_name
                | None -> "nullptr");
              ]);
        Cpp.blank;
        Cpp.definition result (Names.operation name)
          [ (argument, Some "a") ]
          [
            Cpp.statement (Cpp.call "tempore_check_halt" []);
            Cpp.constant "int64_t" "start" (Cpp.call "tempore_clock_us" []);
            Cpp.constant "auto" "r" (Cpp.call (Names.binding name) [ "a" ]);
            Cpp.statement
              (Cpp.call "tempore_monitor_operation"
                 [ "&" ^ Names.monitor name; "tempore_clock_us() - start" ]);
            Cpp.return "r";
          ];
      ]
  in
  Cpp.render
    ([
       generated input.source
         "The operations, monitored calls of the binding functions,";
       Cpp.blank;
       Cpp.local_include "tempore_bindings.h";
     ]
    @ List.concat_map
        (fun op -> Cpp.blank :: operation op)
        compiled.operation_types
    @ Cpp.blank
      :: Cpp.null_terminated
           "tempore_operation_monitor *const tempore_operation_monitors[]"
           (List.map
              (fun (op, _) -> "&" ^ Names.monitor (Ast.OpName.string_of op))
              compiled.operation_types))

(* Whether the board has a screen driven through M5Unified, on which the
   events of the monitor are shown. *)
let has_screen (board : Board.t) =
  board.m5unified && List.mem "display" board.capabilities

let m5_directory = "m5/"
let battery_directory = "battery/"
let task_monitor i = Printf.sprintf "tempore_task%d_monitor" i
let task_name i = Printf.sprintf "tempore_task%d" i
let check_halt = Cpp.statement (Cpp.call "tempore_check_halt" [])

let trace event name =
  Cpp.statement
    (Cpp.call "tempore_trace" [ Cpp.string_literal (event ^ " %s"); name ])

(* The C++ task of the [i]-th task of the manifest, with its monitor if it is
   periodic. *)
let task_function i { task; step; initial } =
  let name = Cpp.string_literal task.function_name.it in
  let definition =
    Cpp.definition ~static:true "void" (task_name i) [ ("void *", None) ]
  in
  let call_step = Cpp.statement (Cpp.call step.cxx [ "tempore_unit{}" ]) in
  match task.kind with
  | Device.Periodic { period_ms; period_us; _ } ->
      [
        Cpp.comment
          (Printf.sprintf "The periodic task %s, of period %d us%s."
             task.function_name.it period_us
             (match step.function_effect with
             | Effect { durations = Grade.Untimed; _ } ->
                 "; its grades bound no durations, so its steps are checked \
                  against the period by the monitor only"
             | _ -> ""));
        Cpp.statement
          ("static tempore_task_monitor "
          ^ Cpp.call (task_monitor i) [ name; string_of_int period_us ]);
        Cpp.blank;
        definition
          [
            check_halt;
            (match initial with
            | Some r ->
                Cpp.variable "auto" "state"
                  ~init:(Cpp.call r.cxx [ "tempore_unit{}" ])
            | None -> Cpp.variable "tempore_unit" "state");
            Cpp.variable "TickType_t" "release"
              ~init:(Cpp.call "xTaskGetTickCount" []);
            Cpp.block "for (;;)"
              [
                check_halt;
                trace "Release" name;
                Cpp.constant "int64_t" "start" (Cpp.call "tempore_clock_us" []);
                Cpp.assign "state" (Cpp.call step.cxx [ "state" ]);
                Cpp.statement
                  (Cpp.call "tempore_monitor_period"
                     [ "&" ^ task_monitor i; "start"; "tempore_clock_us()" ]);
                Cpp.statement
                  (Cpp.call "tempore_wait_release"
                     [
                       "&release";
                       Cpp.call "pdMS_TO_TICKS" [ string_of_int period_ms ];
                     ]);
              ];
          ];
      ]
  | Device.Free { repeat = false } ->
      [
        Cpp.comment ("The free task " ^ task.function_name.it ^ ".");
        definition
          [
            check_halt;
            trace "Start" name;
            call_step;
            trace "End" name;
            Cpp.statement (Cpp.call "vTaskDelete" [ "nullptr" ]);
          ];
      ]
  | Device.Free { repeat = true } ->
      [
        Cpp.comment ("The repeated free task " ^ task.function_name.it ^ ".");
        definition
          [
            Cpp.block "for (;;)"
              [
                check_halt;
                trace "Start" name;
                call_step;
                trace "End" name;
                Cpp.statement (Cpp.call "vTaskDelay" [ "1" ]);
              ];
          ];
      ]

(* The body of [setup()]: the log, the board, its I2C buses and its own
   initialisation, the initialisation functions [inits] of the packages, the
   display of the monitor, the battery indicator, the tasks and the profile. *)
let setup_body (board : Board.t) (device : Device.t) inits tasks =
  let m5unified =
    if board.m5unified then
      [
        Cpp.variable "auto" "m5_config" ~init:"M5.config()";
        Cpp.statement "M5.begin(m5_config)";
      ]
      @ List.map
          (fun f ->
            Cpp.statement (Cpp.call "M5.Imu.setClock" [ string_of_int f ]))
          (Option.to_list board.imu_frequency)
    else []
  in
  let bus (bus : Board.i2c) =
    [
      Cpp.statement
        (Cpp.call (bus.port ^ ".begin")
           (List.map string_of_int [ bus.sda; bus.scl; bus.frequency ]));
      Cpp.statement
        (Cpp.call (bus.port ^ ".setClock") [ string_of_int bus.frequency ]);
    ]
  in
  let create i { task; _ } =
    Cpp.statement
      (Cpp.call "xTaskCreatePinnedToCore"
         [
           task_name i;
           Cpp.string_literal task.function_name.it;
           string_of_int task.stack;
           "nullptr";
           string_of_int task.priority;
           "nullptr";
           string_of_int task.core;
         ])
  in
  Cpp.statement
    (Cpp.call "tempore_log_begin" [ string_of_int board.serial_baud ])
  :: m5unified
  @ List.concat_map bus board.i2c
  @ List.map (fun s -> Cpp.Line s) board.init
  @ List.map (fun f -> Cpp.statement (Cpp.call f [])) inits
  @ (if has_screen board then
       [
         Cpp.statement
           (Cpp.call "tempore_monitor_display_begin"
              [ "&tempore_m5_monitor_display" ]);
       ]
     else [])
  @ (if device.battery then
       [ Cpp.statement (Cpp.call "tempore_battery_begin" []) ]
     else [])
  @ List.mapi create tasks
  @ [ Cpp.statement (Cpp.call "tempore_profile_begin" []) ]

(* The safe state: the calls of [hooks], in order. *)
let safe_state_definition hooks =
  Cpp.Line
    (Cpp.declarator "void" "tempore_safe_state" []
    ^
    match hooks with
    | [] -> " {}"
    | hooks ->
        " { "
        ^ String.concat " " (List.map (fun f -> Cpp.call f [] ^ ";") hooks)
        ^ " }")

(* The configuration of the scaffold: the monitor policy and the time unit. *)
let configuration input =
  let unit_us = input.device.unit_us in

  [
    Cpp.comment "The configuration.";
    Cpp.constant "tempore_monitor_policy" "tempore_monitor"
      ("tempore_monitor_policy::" ^ Utils.Monitor.name input.monitor);
    Cpp.constant "uint64_t" "tempore_unit_numerator_us"
      (Z.to_string (Rational.num unit_us) ^ "ULL");
    Cpp.constant "uint64_t" "tempore_unit_denominator_us"
      (Z.to_string (Rational.den unit_us) ^ "ULL");
  ]

let main_source input (board : Board.t) packages tasks =
  let inits, safe_states = package_hooks packages in
  Cpp.render
    ([
       Cpp.comment
         (Printf.sprintf
            "The device of the program %s on the board %s, generated by \
             Tempore."
            input.source board.name);
       Cpp.blank;
       Cpp.system_include "Arduino.h";
       Cpp.system_include "freertos/FreeRTOS.h";
       Cpp.system_include "freertos/task.h";
     ]
    @ (if board.m5unified then [ Cpp.system_include "M5Unified.h" ] else [])
    @ (if board.i2c <> [] then [ Cpp.system_include "Wire.h" ] else [])
    @ List.map Cpp.system_include board.includes
    @ [
        Cpp.blank;
        Cpp.local_include "tempore_bindings.h";
        Cpp.local_include "tempore_scaffold.h";
        Cpp.blank;
      ]
    @ configuration input
    @ (if has_screen board then
         [
           Cpp.blank;
           Cpp.comment "The display of the events of the monitor on the screen.";
           Cpp.Line
             "extern const tempore_monitor_display tempore_m5_monitor_display;";
         ]
       else [])
    @ [
        Cpp.blank;
        safe_state_definition
          (safe_states
          @ Option.to_list
              (Option.map
                 (fun (h : Device.name) -> h.it)
                 input.device.safe_state));
      ]
    @ List.concat (List.mapi (fun i t -> Cpp.blank :: task_function i t) tasks)
    @ Cpp.blank
      :: Cpp.null_terminated
           "tempore_task_monitor *const tempore_task_monitors[]"
           (List.concat
              (List.mapi
                 (fun i { task; _ } ->
                   match task.kind with
                   | Device.Periodic _ -> [ "&" ^ task_monitor i ]
                   | Device.Free _ -> [])
                 tasks))
    @ [
        Cpp.blank;
        Cpp.definition "void" "setup" []
          (setup_body board input.device inits tasks);
        Cpp.blank;
        Cpp.Line "void loop() { vTaskDelete(nullptr); }";
      ])

(* The project. *)

let host_directory = "host/"

let board_of (device : Device.t) =
  match Board.find device.board.it with
  | Some board -> board
  | None ->
      Error.compilation ~loc:device.board.at "Unknown board `%s`; accepted: %s"
        device.board.it
        (Diagnostic.code_list Board.names)

(* The packages of the manifest, in order, each checked against the packages
   before it and the capabilities of [board]. *)
let packages_of (board : Board.t) (device : Device.t) =
  let add packages (name : Device.name) =
    let package = Package.resolve name in
    if List.exists (fun (p : Package.t) -> p.name = name.it) packages then
      Error.compilation ~loc:name.at "The package `%s` is listed twice" name.it;
    List.iter
      (fun (p : Package.t) ->
        Option.iter
          (fun op ->
            Error.compilation ~loc:name.at
              "The package `%s` binds the operation `%s`, which the package \
               `%s` binds"
              package.name op p.name)
          (Package.shared_binding package p))
      packages;
    Option.iter
      (fun needed ->
        Error.compilation ~loc:name.at
          "The package `%s` needs the package `%s`, listed before it"
          package.name needed)
      (Package.missing_package ~before:packages package);
    List.iter
      (fun capability ->
        if not (List.mem capability board.capabilities) then
          Error.compilation ~loc:name.at
            "The package `%s` requires the capability `%s`, which the board \
             `%s` lacks; its capabilities are: %s"
            package.name capability board.name
            (Diagnostic.code_list board.capabilities))
      package.requires;
    package :: packages
  in
  List.rev (List.fold_left add [] device.packages)

(* Checks that [board] has the capabilities of the battery indicator, if the
   manifest requests it. *)
let check_battery (board : Board.t) (device : Device.t) =
  if device.battery then
    List.iter
      (fun capability ->
        if not (List.mem capability board.capabilities) then
          Error.compilation ~loc:device.battery_at
            "The member `battery` of the manifest requires the capability \
             `%s`, which the board `%s` lacks; its capabilities are: %s"
            capability board.name
            (Diagnostic.code_list board.capabilities))
      [ "m5unified"; "display"; "battery" ]

let check_cores (board : Board.t) (device : Device.t) =
  List.iter
    (fun (task : Device.task) ->
      if task.core >= board.cores then
        Error.compilation ~loc:task.core_at
          "The core of a task must be below %d, the number of cores of the \
           board `%s`"
          board.cores board.name)
    device.tasks

(* The base name of the file [name] of the manifest, [what], checked to be a
   C++ source whose name is not among [taken] nor that of a generated file. *)
let check_file ~what ~taken (name : Device.name) =
  let base = Filename.basename name.it in
  if
    String.starts_with ~prefix:"tempore" base
    || base = "main.cpp"
    || not (Filename.check_suffix base ".cpp")
  then
    Error.compilation ~loc:name.at
      "%s must be a `.cpp` file whose name is neither `main.cpp` nor starts \
       with `tempore`"
      what;
  if List.mem base taken then
    Error.compilation ~loc:name.at
      "%s `%s` has the name of another file of the project; rename it" what base;
  base

(* The paths of the files [f] of [packages]. *)
let package_files f packages =
  List.concat_map (fun (p : Package.t) -> List.map fst (f p)) packages

(* The binding file of the manifest, if any: its name, base name and text. *)
let binding_file input packages =
  Option.map
    (fun name ->
      ( name,
        check_file ~what:"The binding file"
          ~taken:(package_files (fun p -> p.Package.sources) packages)
          name,
        input.file_text name ))
    input.device.bindings

(* The host models of the manifest, each with its base name and text. *)
let host_models input packages =
  let host_names = package_files (fun p -> p.Package.host_models) packages in
  List.fold_left
    (fun acc (name : Device.name) ->
      let base =
        check_file ~what:"A host model"
          ~taken:(host_names @ List.map fst acc)
          name
      in
      (base, input.file_text name) :: acc)
    [] input.device.host_models
  |> List.rev

(* Checks that the binding file defines the binding function of each
   operation performed that no package binds, and the safe-state hook, and
   none of the binding functions of the packages. *)
let check_bindings input packages (compiled : ArduinoEmit.compiled) binding_file
    =
  let device = input.device in
  let provider name =
    List.find_opt (fun (p : Package.t) -> List.mem name p.bindings) packages
  in
  let required =
    List.filter_map
      (fun (op, _) ->
        let name = Ast.OpName.string_of op in
        match provider name with
        | Some _ -> None
        | None ->
            Some
              ( Names.binding name,
                Printf.sprintf "the operation %s" (Diagnostic.code name) ))
      compiled.operation_types
    @
    match device.safe_state with
    | Some hook -> [ (hook.it, "the safe state") ]
    | None -> []
  in
  Option.iter
    (fun ((name : Device.name), base, text) ->
      List.iter
        (fun (op, _) ->
          let op = Ast.OpName.string_of op in
          match provider op with
          | Some p when mentions text (Names.binding op) ->
              Error.compilation ~loc:name.at
                "The binding file `%s` defines the function `%s` of the \
                 operation `%s`, which the package `%s` defines"
                base (Names.binding op) op p.name
          | _ -> ())
        compiled.operation_types)
    binding_file;
  List.iter
    (fun (id, what) ->
      match binding_file with
      | Some (name, base, text) ->
          if not (mentions text id) then
            Error.compilation ~loc:name.at
              "The binding file `%s` does not define the function `%s` of %s"
              base id what
      | None ->
          Error.compilation ~loc:device.at
            "The function `%s` of %s needs a binding file, the member \
             `bindings` of the manifest"
            id what)
    required

let platformio_ini input (board : Board.t) =
  let flags =
    List.map
      (Printf.sprintf "-DTEMPORE_IMU_FREQUENCY=%d")
      (Option.to_list board.imu_frequency)
    @ if input.profile then [ "-DTEMPORE_PROFILE" ] else []
  in
  Board.platformio_ini { board with build_flags = board.build_flags @ flags }

(* The files of the scaffold for [board] and [device], each with its path in
   the project: its sources in src/, those of m5/ on a board with a screen and
   those of battery/ under the member [battery] of the manifest, then the
   files of the host simulation in host/. *)
let scaffold_files board (device : Device.t) =
  let host, sources =
    List.partition
      (fun (path, _) -> String.starts_with ~prefix:host_directory path)
      Arduino_scaffold.files
  in
  let included path =
    if String.starts_with ~prefix:m5_directory path then Some (has_screen board)
    else if String.starts_with ~prefix:battery_directory path then
      Some device.battery
    else None
  in
  List.filter_map
    (fun (path, text) ->
      match included path with
      | Some true -> Some ("src/" ^ Filename.basename path, text)
      | Some false -> None
      | None -> Some ("src/" ^ path, text))
    sources
  @ host

let files input (program : F.program) =
  let board = board_of input.device in
  let packages = packages_of board input.device in
  check_cores board input.device;
  check_battery board input.device;
  let compiled = ArduinoEmit.compile ~source:input.source program in
  let tasks =
    List.map (task_code input program compiled.entries) input.device.tasks
  in
  let binding_file = binding_file input packages in
  let host_models = host_models input packages in
  check_bindings input packages compiled binding_file;
  let src files = List.map (fun (path, text) -> ("src/" ^ path, text)) files in
  let host files =
    List.map (fun (path, text) -> (host_directory ^ path, text)) files
  in
  src compiled.files
  @ [
      ("platformio.ini", platformio_ini input board);
      ("src/main.cpp", main_source input board packages tasks);
      ("src/tempore_bindings.h", bindings_header input packages compiled);
      ("src/tempore_operations.cpp", operations_source input compiled);
    ]
  @ scaffold_files board input.device
  @ List.concat_map
      (fun (p : Package.t) -> src p.sources @ host p.host_models)
      packages
  @ (match binding_file with
    | Some (_, base, text) -> [ ("src/" ^ base, text) ]
    | None -> [])
  @ host host_models

let host_sources files =
  List.filter_map
    (fun (path, _) ->
      if
        Filename.check_suffix path ".cpp"
        && (String.starts_with ~prefix:"src/" path
           || Filename.dirname path ^ "/" = host_directory)
      then Some path
      else None)
    files

let host_build_command ?(profile = false) ~directory ~output files =
  let path p = Filename.concat directory p in
  [
    "c++";
    "-std=c++17";
    "-ffp-contract=off";
    "-DTEMPORE_HOST";
    (if profile then "-DTEMPORE_PROFILE" else "-DTEMPORE_TRACE");
    "-pthread";
    "-I";
    path "host";
    "-I";
    path "src";
  ]
  @ List.map path (host_sources files)
  @ [ "-o"; output ]
