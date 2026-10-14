module Ast = Language.Ast
module Location = Utils.Location
module Error = Utils.Error
module Rational = Grades.Rational
module Grade = Grades.Grade
module F = ArduinoFragment
module Device = ArduinoDevice
module Board = ArduinoBoard
module Names = ArduinoNames
module Package = ArduinoPackage

type monitor = Abort | Warn | Off

type function_effect =
  | Not_a_function
  | Effect_variable
  | Effect of { grade : string; durations : Grade.durations }

type input = {
  device : Device.t;
  monitor : monitor;
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
  | F.Meta i ->
      let rec index k = function
        | [] -> 0
        | j :: rest -> if i = j then k else index (k + 1) rest
      in
      let k = index 0 metas in
      if k < 26 then Printf.sprintf "'%c" (Char.chr (Char.code 'a' + k))
      else Printf.sprintf "'t%d" k

and show_atom metas = function
  | F.Tuple (_ :: _) as ty -> "(" ^ show_ty metas ty ^ ")"
  | ty -> show_ty metas ty

(* The type variables of [tys], in order of first occurrence. *)
let metas tys =
  let rec collect acc = function
    | F.Meta i -> if List.mem i acc then acc else i :: acc
    | F.Tuple tys -> List.fold_left collect acc tys
    | F.Nat | F.Int | F.Float | F.Bool | F.String | F.Data _ -> acc
  in
  List.rev (List.fold_left collect [] tys)

let unit_ty = F.Tuple []

(* The parameter and result types of a function definition. *)
let signature (d : F.definition) =
  match d.definition_body with
  | F.Function_body { parameters; body; _ } ->
      Some
        ( List.map (fun (p : F.pattern) -> p.pattern_ty) parameters,
          body.F.result )
  | F.Constant_body _ | F.Handler_body _ -> None

let show_signature (d : F.definition) =
  match signature d with
  | Some (parameters, result) ->
      let tys = parameters @ [ result ] in
      String.concat " -> " (List.map (show_atom (metas tys)) tys)
  | None -> "not that of a function"

(* Task functions. *)

type resolved = {
  definition : F.definition;
  function_effect : function_effect;
  cxx : string;  (** the name of the C++ function *)
}

(* The definition of the program's sources named [name], the last of them, with
   its effect and C++ name. *)
let resolve input (program : F.program) entries (name : Device.name) =
  let candidates =
    List.filter
      (fun (x, _) -> Ast.Variable.string_of x = name.it)
      input.definitions
  in
  let unknown () =
    let functions =
      List.fold_left
        (fun functions (x, function_effect) ->
          let name = Ast.Variable.string_of x in
          match function_effect with
          | Not_a_function -> functions
          | Effect_variable | Effect _ ->
              if List.mem name functions then functions else name :: functions)
        [] input.definitions
      |> List.rev
    in
    Error.compilation ~loc:name.at
      "Unknown function '%s'; the top-level functions of the program are: %s"
      name.it
      (match functions with [] -> "none" | _ -> String.concat ", " functions)
  in
  match List.rev candidates with
  | [] -> unknown ()
  | (x, function_effect) :: _ -> (
      match
        List.find_opt
          (fun (d : F.definition) ->
            d.in_sources && Ast.Variable.equal d.variable x)
          program.definitions
      with
      | None -> unknown ()
      | Some definition ->
          let cxx =
            List.find_map
              (fun (y, cxx) ->
                if Ast.Variable.equal x y then Some cxx else None)
              entries
          in
          { definition; function_effect; cxx = Option.value cxx ~default:"" })

(* Checks that [r], named by [name], has the type [parameter -> result], [role]
   naming it in the message. *)
let check_type ~role (name : Device.name) r ~expected =
  let ok =
    r.definition.quantified = []
    &&
    match (signature r.definition, expected) with
    | Some ([ p ], q), (p', Some q') ->
        F.compare_ty p p' = 0 && F.compare_ty q q' = 0
    | Some ([ p ], q), (_, None) -> F.compare_ty p q = 0
    | _ -> false
  in
  if not ok then
    Error.compilation ~loc:name.at
      "The function '%s' of %s must have the type %s, but it has the type %s"
      name.it role
      (match expected with
      | p, Some q -> show_atom [] p ^ " -> " ^ show_atom [] q
      | _, None -> "s -> s for a type s without type variables")
      (show_signature r.definition)

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
        "The effect of the function '%s' of a periodic task has a variable; \
         annotate the function with an effect whose durations are below its \
         period %s"
        name.it (Rational.show period)
  | Effect { durations = Grade.Untimed; _ } -> ()
  | Effect { grade; durations = Grade.Undetermined } ->
      Error.compilation ~loc:name.at
        "The effect `%s` of the function '%s' of a periodic task does not \
         bound its durations, so it is not below the period %s"
        grade name.it (Rational.show period)
  | Effect { grade; durations = Grade.Duration_interval (_, hi) } ->
      if not (below_period hi period) then
        Error.compilation ~loc:name.at
          "The effect `%s` of the function '%s' of a periodic task is not \
           below its period: its durations are not all below %s"
          grade name.it (Rational.show period)

(* Whether a lower end of an interval of durations is positive. *)
let takes_time = function
  | Grade.Closed q | Grade.Open q -> Rational.sign q > 0
  | Grade.Unbounded -> false

let check_repeat (name : Device.name) r =
  let fail grade =
    Error.compilation ~loc:name.at
      "The effect `%s` of the function '%s' of a repeated free task does not \
       bound its durations below by a positive time, so that the task may \
       never yield"
      grade name.it
  in
  match r.function_effect with
  | Not_a_function -> ()
  | Effect_variable ->
      Error.compilation ~loc:name.at
        "The effect of the function '%s' of a repeated free task has a \
         variable; annotate the function with an effect whose durations are \
         bounded below by a positive time"
        name.it
  | Effect { durations = Grade.Untimed; _ } -> ()
  | Effect { grade; durations = Grade.Undetermined } -> fail grade
  | Effect { grade; durations = Grade.Duration_interval (lo, _) } ->
      if not (takes_time lo) then fail grade

(* Bindings. *)

let is_identifier_char = function
  | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' -> true
  | _ -> false

(* Whether [text] contains the identifier [id] as a whole word. *)
let mentions text id =
  let n = String.length id and m = String.length text in
  let rec from i =
    if i + n > m then false
    else if
      String.sub text i n = id
      && (i = 0 || not (is_identifier_char text.[i - 1]))
      && (i + n = m || not (is_identifier_char text.[i + n]))
    then true
    else from (i + 1)
  in
  from 0

(* Rendering. *)

let lines ls = String.concat "\n" ls ^ "\n"

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
  Printf.sprintf "// %s of the program %s, generated by Tempore." what source

let bindings_header input (compiled : ArduinoEmit.compiled) =
  lines
    ([
       generated input.source
         "The declarations of the binding functions and the safe-state hook";
       "";
       "#ifndef TEMPORE_BINDINGS_H";
       "#define TEMPORE_BINDINGS_H";
       "";
       "#include \"tempore_program.h\"";
       "#include \"tempore_scaffold.h\"";
     ]
    @ (match compiled.operation_types with
      | [] -> []
      | ops ->
          ""
          :: "// The operations performed: the types of their arguments and \
              results, and their binding functions."
          :: List.concat_map
               (fun (op, (argument, result)) ->
                 let name = Ast.OpName.string_of op in
                 [
                   "";
                   "#define " ^ Names.performs name;
                   Printf.sprintf "typedef %s %s;" argument
                     (Names.argument_type name);
                   Printf.sprintf "typedef %s %s;" result
                     (Names.result_type name);
                   Printf.sprintf "%s %s(%s);" result (Names.binding name)
                     argument;
                 ])
               ops)
    @ (match input.device.safe_state with
      | None -> []
      | Some hook -> [ ""; "// The safe state."; "void " ^ hook.it ^ "();" ])
    @ [ ""; "#endif" ])

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
            Printf.sprintf "static const tempore_bounds %s = %s;" bounds_name
              (bounds_initialiser ~unit_us b);
          ]
      | None -> [])
    @ [
        Printf.sprintf "static tempore_operation_monitor %s(%s, %s);"
          (Names.monitor name)
          (Names.string_literal name)
          (match bounds with Some _ -> "&" ^ bounds_name | None -> "nullptr");
        "";
        Printf.sprintf "%s %s(%s a) {" result (Names.operation name) argument;
        "  tempore_check_halt();";
        "  const int64_t start = tempore_clock_us();";
        Printf.sprintf "  const auto r = %s(a);" (Names.binding name);
        Printf.sprintf
          "  tempore_monitor_operation(&%s, tempore_clock_us() - start);"
          (Names.monitor name);
        "  return r;";
        "}";
      ]
  in
  lines
    ([
       generated input.source
         "The operations, monitored calls of the binding functions,";
       "";
       "#include \"tempore_bindings.h\"";
     ]
    @ List.concat_map (fun op -> "" :: operation op) compiled.operation_types
    @ [
        ""; "tempore_operation_monitor *const tempore_operation_monitors[] = {";
      ]
    @ List.map
        (fun (op, _) ->
          Printf.sprintf "    &%s," (Names.monitor (Ast.OpName.string_of op)))
        compiled.operation_types
    @ [ "    nullptr};" ])

type task_code = {
  task : Device.task;
  step : resolved;
  initial : resolved option;
}

(* Whether the board has a screen driven through M5Unified, on which the
   events of the monitor are shown. *)
let has_screen (board : Board.t) =
  board.m5unified && List.mem "display" board.capabilities

let m5_directory = "m5/"

let main_source input board packages tasks =
  let device = input.device in
  let hooks f = List.filter_map (fun (p : Package.t) -> f p) packages in
  let inits = hooks (fun p -> p.init)
  and safe_states = hooks (fun p -> p.safe_state) in
  let task_monitor i = Printf.sprintf "tempore_task%d_monitor" i in
  let task_function i { task; step; initial } =
    let name = Names.string_literal task.function_name.it in
    let header = Printf.sprintf "static void tempore_task%d(void *) {" i in
    match task.kind with
    | Device.Periodic { period_ms; period_us; _ } ->
        [
          Printf.sprintf "// The periodic task %s, of period %d us%s."
            task.function_name.it period_us
            (match step.function_effect with
            | Effect { durations = Grade.Untimed; _ } ->
                "; its grades bound no durations, so its steps are checked \
                 against the period by the monitor only"
            | _ -> "");
          Printf.sprintf "static tempore_task_monitor %s(%s, %d);"
            (task_monitor i) name period_us;
          "";
          header;
          "  tempore_check_halt();";
          (match initial with
          | Some r -> Printf.sprintf "  auto state = %s(tempore_unit{});" r.cxx
          | None -> "  tempore_unit state{};");
          "  TickType_t release = xTaskGetTickCount();";
          "  for (;;) {";
          "    tempore_check_halt();";
          Printf.sprintf "    tempore_trace(\"Release %%s\", %s);" name;
          "    const int64_t start = tempore_clock_us();";
          Printf.sprintf "    state = %s(state);" step.cxx;
          Printf.sprintf
            "    tempore_monitor_period(&%s, start, tempore_clock_us());"
            (task_monitor i);
          Printf.sprintf "    vTaskDelayUntil(&release, pdMS_TO_TICKS(%d));"
            period_ms;
          "  }";
          "}";
        ]
    | Device.Free { repeat = false } ->
        [
          Printf.sprintf "// The free task %s." task.function_name.it;
          header;
          "  tempore_check_halt();";
          Printf.sprintf "  tempore_trace(\"Start %%s\", %s);" name;
          Printf.sprintf "  %s(tempore_unit{});" step.cxx;
          Printf.sprintf "  tempore_trace(\"End %%s\", %s);" name;
          "  vTaskDelete(nullptr);";
          "}";
        ]
    | Device.Free { repeat = true } ->
        [
          Printf.sprintf "// The repeated free task %s." task.function_name.it;
          header;
          "  for (;;) {";
          "    tempore_check_halt();";
          Printf.sprintf "    tempore_trace(\"Start %%s\", %s);" name;
          Printf.sprintf "    %s(tempore_unit{});" step.cxx;
          Printf.sprintf "    tempore_trace(\"End %%s\", %s);" name;
          "  }";
          "}";
        ]
  in
  let unit_us = device.unit_us in
  let policy =
    match input.monitor with Abort -> "abort" | Warn -> "warn" | Off -> "off"
  in
  lines
    ([
       Printf.sprintf
         "// The device of the program %s on the board %s, generated by \
          Tempore."
         input.source board.Board.name;
       "";
       "#include <Arduino.h>";
       "#include <freertos/FreeRTOS.h>";
       "#include <freertos/task.h>";
     ]
    @ (if board.m5unified then [ "#include <M5Unified.h>" ] else [])
    @ (if board.i2c <> [] then [ "#include <Wire.h>" ] else [])
    @ List.map (fun h -> "#include <" ^ h ^ ">") board.includes
    @ [
        "";
        "#include \"tempore_bindings.h\"";
        "#include \"tempore_scaffold.h\"";
        "";
        "// The configuration.";
        Printf.sprintf
          "const tempore_monitor_policy tempore_monitor = \
           tempore_monitor_policy::%s;"
          policy;
        Printf.sprintf "const uint64_t tempore_unit_numerator_us = %sULL;"
          (Z.to_string (Rational.num unit_us));
        Printf.sprintf "const uint64_t tempore_unit_denominator_us = %sULL;"
          (Z.to_string (Rational.den unit_us));
      ]
    @ (match inits @ safe_states with
      | [] -> []
      | hooks ->
          "" :: "// The hooks of the packages."
          :: List.map (fun f -> "void " ^ f ^ "();") hooks)
    @ (if has_screen board then
         [
           "";
           "// The display of the events of the monitor on the screen.";
           "extern const tempore_monitor_display tempore_m5_monitor_display;";
         ]
       else [])
    @ [
        "";
        (match
           safe_states
           @ Option.to_list
               (Option.map (fun (h : Device.name) -> h.it) device.safe_state)
         with
        | [] -> "void tempore_safe_state() {}"
        | hooks ->
            Printf.sprintf "void tempore_safe_state() { %s }"
              (String.concat " " (List.map (fun f -> f ^ "();") hooks)));
      ]
    @ List.concat (List.mapi (fun i t -> "" :: task_function i t) tasks)
    @ [ ""; "tempore_task_monitor *const tempore_task_monitors[] = {" ]
    @ List.concat
        (List.mapi
           (fun i { task; _ } ->
             match task.kind with
             | Device.Periodic _ ->
                 [ Printf.sprintf "    &%s," (task_monitor i) ]
             | Device.Free _ -> [])
           tasks)
    @ [
        "    nullptr};";
        "";
        "void setup() {";
        Printf.sprintf "  tempore_log_begin(%d);" board.serial_baud;
      ]
    @ (if board.m5unified then
         [ "  auto m5_config = M5.config();"; "  M5.begin(m5_config);" ]
         @ List.map
             (Printf.sprintf "  M5.Imu.setClock(%d);")
             (Option.to_list board.imu_frequency)
       else [])
    @ List.concat_map
        (fun (bus : Board.i2c) ->
          [
            Printf.sprintf "  %s.begin(%d, %d, %d);" bus.port bus.sda bus.scl
              bus.frequency;
            Printf.sprintf "  %s.setClock(%d);" bus.port bus.frequency;
          ])
        board.i2c
    @ List.map (fun s -> "  " ^ s) board.init
    @ List.map (fun f -> "  " ^ f ^ "();") inits
    @ (if has_screen board then
         [ "  tempore_monitor_display_begin(&tempore_m5_monitor_display);" ]
       else [])
    @ List.mapi
        (fun i { task; _ } ->
          Printf.sprintf
            "  xTaskCreatePinnedToCore(tempore_task%d, %s, %d, nullptr, %d, \
             nullptr, %d);"
            i
            (Names.string_literal task.function_name.it)
            task.stack task.priority task.core)
        tasks
    @ [
        "  tempore_profile_begin();";
        "}";
        "";
        "void loop() { vTaskDelete(nullptr); }";
      ])

(* The project. *)

let host_directory = "host/"

let files input (program : F.program) =
  let device = input.device in
  let board =
    match Board.find device.board.it with
    | Some board -> board
    | None ->
        Error.compilation ~loc:device.board.at
          "Unknown board '%s'; accepted: %s" device.board.it
          (String.concat ", " Board.names)
  in
  let packages =
    List.fold_left
      (fun packages (name : Device.name) ->
        let package = Package.resolve name in
        if List.exists (fun (p : Package.t) -> p.name = name.it) packages then
          Error.compilation ~loc:name.at "The package '%s' is listed twice"
            name.it;
        List.iter
          (fun (p : Package.t) ->
            Option.iter
              (fun op ->
                Error.compilation ~loc:name.at
                  "The package %s binds the operation %s, which the package %s \
                   binds"
                  package.name op p.name)
              (Package.shared_binding package p))
          packages;
        List.iter
          (fun capability ->
            if not (List.mem capability board.capabilities) then
              Error.compilation ~loc:name.at
                "The package %s requires the capability %s, which the board %s \
                 lacks; its capabilities are: %s"
                package.name capability board.name
                (match board.capabilities with
                | [] -> "none"
                | cs -> String.concat ", " cs))
          package.requires;
        package :: packages)
      [] device.packages
    |> List.rev
  in
  List.iter
    (fun (task : Device.task) ->
      if task.core >= board.cores then
        Error.compilation ~loc:task.core_at
          "The core of a task must be below %d, the number of cores of the \
           board %s"
          board.cores board.name)
    device.tasks;
  let compiled = ArduinoEmit.compile ~source:input.source program in
  let resolve = resolve input program compiled.entries in
  let tasks =
    List.map
      (fun (task : Device.task) ->
        let name = task.function_name in
        let step = resolve name in
        match task.kind with
        | Device.Free { repeat } ->
            check_type ~role:"a free task" name step
              ~expected:(unit_ty, Some unit_ty);
            if repeat then check_repeat name step;
            { task; step; initial = None }
        | Device.Periodic { period; initial; _ } ->
            check_type ~role:"a periodic task" name step
              ~expected:(unit_ty, None);
            let state =
              match signature step.definition with
              | Some (_, state) -> state
              | None -> unit_ty
            in
            check_period name step period;
            let initial =
              match initial with
              | Some initial_name ->
                  let r = resolve initial_name in
                  check_type ~role:"the initial state of a periodic task"
                    initial_name r ~expected:(unit_ty, Some state);
                  Some r
              | None ->
                  if F.compare_ty state unit_ty <> 0 then
                    Error.compilation ~loc:name.at
                      "The periodic task of the function '%s' has the state \
                       type %s, so it needs the member 'initial'"
                      name.it (show_ty [] state);
                  None
            in
            { task; step; initial })
      device.tasks
  in
  let package_files f =
    List.concat_map (fun (p : Package.t) -> List.map fst (f p)) packages
  in
  let source_names = package_files (fun p -> p.sources)
  and host_names = package_files (fun p -> p.host_models) in
  let check_file ~what ~taken (name : Device.name) =
    let base = Filename.basename name.it in
    if
      String.starts_with ~prefix:"tempore" base
      || base = "main.cpp"
      || not (Filename.check_suffix base ".cpp")
    then
      Error.compilation ~loc:name.at
        "%s must be a .cpp file whose name is neither main.cpp nor starts with \
         tempore"
        what;
    if List.mem base taken then
      Error.compilation ~loc:name.at
        "%s %s has the name of another file of the project; rename it" what base;
    base
  in
  let binding_file =
    Option.map
      (fun name ->
        ( name,
          check_file ~what:"The binding file" ~taken:source_names name,
          input.file_text name ))
      device.bindings
  in
  let host_models =
    List.fold_left
      (fun acc (name : Device.name) ->
        let base =
          check_file ~what:"A host model"
            ~taken:(host_names @ List.map fst acc)
            name
        in
        (base, input.file_text name) :: acc)
      [] device.host_models
    |> List.rev
  in
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
            Some (Names.binding name, Printf.sprintf "the operation %s" name))
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
                "The binding file %s defines the function %s of the operation \
                 %s, which the package %s defines"
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
              "The binding file %s does not define the function %s of %s" base
              id what
      | None ->
          Error.compilation ~loc:device.at
            "The function %s of %s needs a binding file, the member 'bindings' \
             of the manifest"
            id what)
    required;
  List.map (fun (path, text) -> ("src/" ^ path, text)) compiled.files
  @ [
      ( "platformio.ini",
        let flags =
          List.map
            (Printf.sprintf "-DTEMPORE_IMU_FREQUENCY=%d")
            (Option.to_list board.imu_frequency)
          @ if input.profile then [ "-DTEMPORE_PROFILE" ] else []
        in
        Board.platformio_ini
          { board with build_flags = board.build_flags @ flags } );
      ("src/main.cpp", main_source input board packages tasks);
      ("src/tempore_bindings.h", bindings_header input compiled);
      ("src/tempore_operations.cpp", operations_source input compiled);
    ]
  @ List.filter_map
      (fun (path, text) ->
        if String.starts_with ~prefix:host_directory path then Some (path, text)
        else if String.starts_with ~prefix:m5_directory path then
          if has_screen board then Some ("src/" ^ Filename.basename path, text)
          else None
        else Some ("src/" ^ path, text))
      Arduino_scaffold.files
  @ List.concat_map
      (fun (p : Package.t) ->
        List.map (fun (file, text) -> ("src/" ^ file, text)) p.sources
        @ List.map
            (fun (file, text) -> (host_directory ^ file, text))
            p.host_models)
      packages
  @ (match binding_file with
    | Some (_, base, text) -> [ ("src/" ^ base, text) ]
    | None -> [])
  @ List.map (fun (base, text) -> (host_directory ^ base, text)) host_models

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
