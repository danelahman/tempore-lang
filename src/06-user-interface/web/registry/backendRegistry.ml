module Rational = Grades.Rational
module Grade = Grades.Grade
module Protocol = OpentronsBackend.OpentronsProtocol
module Emit = OpentronsBackend.OpentronsEmit

type input_kind = Text | Choice of string list

type input = {
  key : string;
  label : string;
  kind : input_kind;
  default : string;
}

type settings = (string * string) list

let setting inputs settings key =
  match List.find_opt (fun (input : input) -> input.key = key) inputs with
  | None -> ""
  | Some input ->
      Option.value (List.assoc_opt key settings) ~default:input.default

type severity = Error | Warning | Note
type message = { severity : severity; text : string }

type compiled = {
  code : string option;
  language : string;
  messages : message list;
}

type operations =
  (Language.Ast.operation * Grades.Grade.running_time option) list

type compiler = {
  compile :
    'rho 'eps.
    settings ->
    operations:operations ->
    compound:Language.Ast.operation list ->
    ('rho, 'eps) Language.Ast.command list ->
    compiled;
  code_name : string;
}

type event = Backend.observation =
  | Delayed of Rational.t
  | Performed of string
  | Resumed
  | Returned of string
  | Stopped of string
  | Boxed of { name : string; grade : string }
  | Unboxed of { name : string; grade : string }

type status = Timeline.status = Plain | Pending
type row = Timeline.row = { cells : string list; status : status }

type report = Timeline.report = {
  title : string;
  columns : string list;
  rows : row list;
  notes : string list;
}

type observer = {
  observe : event -> observer;
  report : report Lazy.t;
  expanded : bool;
}

(* The timeline of a run, with times followed by the symbol [time_unit]. *)
let timeline ~expanded ?time_unit () =
  let rec observer timeline =
    {
      observe = (fun event -> observer (Timeline.observe event timeline));
      report = lazy (Timeline.report ?time_unit timeline);
      expanded;
    }
  in
  observer Timeline.empty

type entry = {
  key : string;
  name : string;
  description : string;
  inputs : input list;
  compiler : compiler option;
  observer : (settings -> observer) option;
}

let interpreter =
  {
    key = "interpreter";
    name = "Interpreter";
    description =
      "The interpreter, which runs the program step by step and records a \
       timeline of each run.";
    inputs = [];
    compiler = None;
    observer = Some (fun _ -> timeline ~expanded:false ());
  }

(* Opentrons *)

let opentrons_inputs =
  [
    { key = "binding"; label = "Binding file"; kind = Text; default = "" };
    {
      key = "robot";
      label = "Robot";
      kind = Choice [ "flex" ];
      default = "flex";
    };
    {
      key = "time-unit";
      label = "Time unit";
      kind = Choice [ "seconds"; "minutes"; "hours" ];
      default = "seconds";
    };
    {
      key = "monitor";
      label = "Monitor";
      kind = Choice [ "abort"; "warn"; "off" ];
      default = "abort";
    };
  ]

let opentrons_setting = setting opentrons_inputs

(* The length in seconds of a unit of duration, and its symbol. *)
let time_unit settings =
  match opentrons_setting settings "time-unit" with
  | "minutes" -> (Rational.of_int 60, "min")
  | "hours" -> (Rational.of_int 3600, "h")
  | _ -> (Rational.of_int 1, "s")

let opentrons_compile settings ~operations ~compound commands =
  let binding = opentrons_setting settings "binding" in
  if String.trim binding = "" then
    {
      code = Some (Emit.plain_program ~operations commands);
      language = "python";
      messages =
        [
          {
            severity = Note;
            text =
              "Without a binding file, the program is compiled to a Python \
               program that runs on a virtual clock, its operations performed \
               by their default implementations.";
          };
        ];
    }
  else
    let robot = Protocol.Flex
    and monitor =
      match opentrons_setting settings "monitor" with
      | "warn" -> Protocol.Warn
      | "off" -> Protocol.Off
      | _ -> Protocol.Abort
    in
    let options =
      {
        Protocol.robot;
        api_level = Protocol.default_api_level robot;
        time_unit = fst (time_unit settings);
        monitor;
        name = "Tempore program";
        source = "the web interface";
      }
    in
    match
      Protocol.protocol options ~operations ~compound
        ~binding_name:"the binding file" ~binding commands
    with
    | Ok (code, warnings) ->
        {
          code = Some code;
          language = "python";
          messages =
            List.map (fun text -> { severity = Warning; text }) warnings;
        }
    | Stdlib.Error errors ->
        {
          code = None;
          language = "python";
          messages = List.map (fun text -> { severity = Error; text }) errors;
        }

let opentrons_observer settings =
  timeline ~expanded:true ~time_unit:(snd (time_unit settings)) ()

let opentrons =
  {
    key = "opentrons";
    name = "Opentrons";
    description =
      "Opentrons protocols in Python, with monitors of the running times of \
       operations; interpreter runs record a timeline in units of time.";
    inputs = opentrons_inputs;
    compiler =
      Some { compile = opentrons_compile; code_name = "Opentrons protocol" };
    observer = Some opentrons_observer;
  }

let entries = [ interpreter; opentrons ]
let default = interpreter
let find key = List.find_opt (fun (entry : entry) -> entry.key = key) entries
