module Ast = Language.Ast
module Reach = OpentronsReach
module OperationSet = Reach.OperationSet

type robot = Flex
type monitor = Abort | Warn | Off

type options = {
  robot : robot;
  api_level : string;
  time_unit : Grades.Rational.t;
  monitor : monitor;
  name : string;
  source : string;
}

let default_api_level = function Flex -> "2.30"
let robot_type = function Flex -> "Flex"
let monitor_policy = function Abort -> "abort" | Warn -> "warn" | Off -> "off"
let reserved_prefixes = [ "tempore_"; "_tempore_" ]
let protocol_names = [ "metadata"; "requirements"; "run" ]

(* Identifiers. *)

let is_identifier_start c =
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c = '_'

let is_identifier_char c = is_identifier_start c || (c >= '0' && c <= '9')

(* The identifier at the start of [s], if any, and the rest of [s]. *)
let identifier s =
  let n = String.length s in
  let rec stop i =
    if i < n && is_identifier_char s.[i] then stop (i + 1) else i
  in
  if n > 0 && is_identifier_start s.[0] then
    let i = stop 1 in
    Some (String.sub s 0 i, String.sub s i (n - i))
  else None

let words s = List.filter (( <> ) "") (String.split_on_char ' ' s)

(* The names [targets], a comma-separated list of identifiers, binds; [None]
   if it is not one. *)
let target_names targets =
  let names =
    List.map
      (fun t ->
        match identifier (String.trim t) with
        | Some (x, "") -> Some x
        | _ -> None)
      (String.split_on_char ',' targets)
  in
  if List.for_all Option.is_some names then Some (List.filter_map Fun.id names)
  else None

(* The names an import clause [a.b as c, d] binds: the alias, or else the
   first component of the module path. *)
let import_names clause =
  List.filter_map
    (fun item ->
      match words (String.trim item) with
      | [ _; "as"; alias ] when identifier alias <> None -> Some alias
      | [ path ] -> (
          match identifier path with Some (x, _) -> Some x | None -> None)
      | _ -> None)
    (String.split_on_char ',' clause)

(* [after ~marker s] is the part of [s] after the first occurrence of
   [marker], if any. *)
let after ~marker s =
  let n = String.length s and m = String.length marker in
  let rec find i =
    if i + m > n then None
    else if String.sub s i m = marker then
      Some (String.sub s (i + m) (n - i - m))
    else find (i + 1)
  in
  find 0

(* The names the line [line] binds at the top level of a module, if it starts
   at column 0 with one of the forms the check recognises: a definition by
   [def], [async def] or [class], an import, or an assignment to names. *)
let line_names line =
  let first_identifier s =
    match identifier s with Some (x, _) -> [ x ] | None -> []
  in
  let indented = line = "" || line.[0] = ' ' || line.[0] = '\t' in
  match words line with
  | _ when indented -> []
  | ("def" | "class") :: name :: _ | "async" :: "def" :: name :: _ ->
      first_identifier name
  | "import" :: _ -> import_names (String.sub line 6 (String.length line - 6))
  | "from" :: _ -> (
      match after ~marker:" import " line with
      | Some clause ->
          let clause =
            String.map (fun c -> if c = '(' || c = ')' then ' ' else c) clause
          in
          if String.trim clause = "*" then [] else import_names clause
      | None -> [])
  | _ -> (
      let targets =
        match String.index_opt line '=' with
        | Some i when i + 1 >= String.length line || line.[i + 1] <> '=' ->
            Some (String.sub line 0 i)
        | _ -> None
      in
      match targets with
      | Some targets -> (
          let targets =
            match String.index_opt targets ':' with
            | Some j -> String.sub targets 0 j
            | None -> targets
          in
          match target_names targets with Some names -> names | None -> [])
      | None -> [])

let top_level_names source =
  List.concat
    (List.mapi
       (fun i line -> List.map (fun x -> (x, i + 1)) (line_names line))
       (String.split_on_char '\n' source))

(* The checks of the binding file. *)

let binding_errors ~compiled ~binding_name binding =
  let defined = top_level_names binding in
  let compiled_names = List.map fst (top_level_names compiled) in
  let error = Printf.sprintf in
  let check (x, line) =
    if
      List.exists (fun prefix -> String.starts_with ~prefix x) reserved_prefixes
    then
      Some
        (error
           "%s, line %d: the name `%s` begins with `tempore_` or `_tempore_`, \
            which are reserved for the runtime and the compiled program"
           binding_name line x)
    else if List.mem x protocol_names then
      Some
        (error "%s, line %d: the name `%s` is defined by the protocol"
           binding_name line x)
    else if List.mem x compiled_names then
      Some
        (error "%s, line %d: the name `%s` is defined by the compiled program"
           binding_name line x)
    else None
  in
  List.filter_map check defined
  @
  if List.mem_assoc "setup" defined then []
  else [ error "%s: no function `setup` is defined" binding_name ]

(* The checks of the operations of the runs. *)

(* The errors and the warnings about the operations of the runs of
   [commands], in the order of the runs and of the operations' names. *)
let operation_diagnostics ~bound commands =
  let unbound i (run : Reach.run_operations) op =
    if bound op || OperationSet.mem op run.defaults then None
    else
      let handled = OperationSet.mem op run.handled in
      let message =
        Printf.sprintf
          "operation `%s`, which run %d may perform, has neither a binding \
           function nor a default implementation%s"
          op (i + 1)
          (if handled then
             "; a handler in the run's code has a case for it, so the run \
              fails only if it performs it outside every such handler"
           else "")
      in
      Some (if handled then Either.Right message else Either.Left message)
  in
  Reach.run_operations ~bound commands
  |> List.mapi (fun i (run : Reach.run_operations) ->
      List.filter_map (unbound i run) (OperationSet.elements run.performed))
  |> List.concat |> List.partition_map Fun.id

(* The protocol. *)

let python_string = OpentronsEmit.python_string
let dictionary = OpentronsEmit.dictionary

let protocol options ~operations ~binding_name ~binding commands =
  let compiled = OpentronsEmit.compile ~operations commands in
  let defined = List.map fst (top_level_names binding) in
  let declared = List.map (fun (op, _) -> Ast.OpName.string_of op) operations in
  let bound op = List.mem op declared && List.mem op defined in
  let errors, warnings =
    operation_diagnostics ~bound (Reach.reachable commands)
  in
  match binding_errors ~compiled ~binding_name binding @ errors with
  | _ :: _ as errors -> Error errors
  | [] ->
      let bindings =
        List.filter_map
          (fun op -> if bound op then Some (op, op) else None)
          (List.sort_uniq String.compare declared)
      in
      let metadata =
        dictionary
          [
            ("protocolName", python_string options.name);
            ( "description",
              python_string ("Compiled by Tempore from " ^ options.source) );
          ]
      and requirements =
        dictionary
          [
            ("robotType", python_string (robot_type options.robot));
            ("apiLevel", python_string options.api_level);
          ]
      in
      let source =
        String.concat "\n"
          [
            "# An Opentrons protocol compiled by Tempore from " ^ options.source
            ^ ".";
            "";
            "metadata = " ^ metadata;
            "requirements = " ^ requirements;
            "";
            OpentronsEmit.runtime;
            "# The binding file " ^ binding_name ^ ".";
            "";
            binding;
            "# The compiled program.";
            "";
            compiled;
            "";
            "def run(protocol):";
            "    tempore_run_protocol(";
            "        protocol,";
            "        tempore_RUNS,";
            "        setup,";
            "        " ^ dictionary bindings ^ ",";
            "        time_unit="
            ^ OpentronsEmit.fraction options.time_unit
            ^ ",";
            "        monitor="
            ^ python_string (monitor_policy options.monitor)
            ^ ",";
            "    )";
            "";
            "";
            "if __name__ == \"__main__\":";
            "    tempore_run_plain(tempore_RUNS)";
            "";
          ]
      in
      Ok (source, warnings)
