module Rational = Grades.Rational
module Grade = Grades.Grade
module Protocol = OpentronsBackend.OpentronsProtocol
module Emit = OpentronsBackend.OpentronsEmit
module Timeline = OpentronsBackend.OpentronsTimeline

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

type status = Plain | Good | Bad | Pending
type row = { cells : string list; status : status }

type report = {
  title : string;
  columns : string list;
  rows : row list;
  notes : string list;
}

type observer = { observe : event -> observer; report : report Lazy.t }

type entry = {
  key : string;
  name : string;
  description : string;
  inputs : input list;
  compiler : compiler option;
  observer : (settings -> operations -> observer) option;
}

let tempore =
  {
    key = "tempore";
    name = "Tempore";
    description = "The interpreter, which runs the program step by step.";
    inputs = [];
    compiler = None;
    observer = None;
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

let opentrons_compile settings ~operations commands =
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
      Protocol.protocol options ~operations ~binding_name:"the binding file"
        ~binding commands
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

(* Running-time bounds as the source writes them. *)
let show_bounds ((lo, hi) : Grade.running_time) =
  let lower =
    match lo with
    | Closed q -> "[" ^ Rational.show q
    | Open q -> "(" ^ Rational.show q
    | Unbounded -> "(-∞"
  and upper =
    match hi with
    | Closed q -> Rational.show q ^ "]"
    | Open q -> Rational.show q ^ ")"
    | Unbounded -> "∞)"
  in
  lower ^ ", " ^ upper

(* The report of a timeline, its times in the unit [symbol]: a row per call,
   indented by its depth, and a note per run ended and on the clock. *)
let timeline_report ~bounds ~symbol timeline =
  let time q = Rational.show q ^ " " ^ symbol in
  let row (call : Timeline.call) =
    let declared = bounds call.op in
    let verdict = Timeline.verdict declared call in
    {
      cells =
        [
          string_of_int call.run;
          time call.start;
          String.concat "" (List.init call.depth (fun _ -> "· ")) ^ call.op;
          Option.fold ~none:"running" ~some:time call.elapsed;
          Option.fold ~none:"none" ~some:show_bounds declared;
          (match verdict with
          | Within -> "within"
          | Outside -> "outside"
          | Unchecked -> "not monitored"
          | Unfinished -> "unfinished");
        ];
      status =
        (match verdict with
        | Within -> Good
        | Outside -> Bad
        | Unchecked -> Plain
        | Unfinished -> Pending);
    }
  in
  let note (run : Timeline.finished) =
    match run.outcome with
    | Returned value ->
        Printf.sprintf "Run %d returned %s at %s." run.index value (time run.at)
    | Stopped op ->
        Printf.sprintf
          "Run %d ended at %s at a call of %s, which has neither a handler nor \
           a default implementation."
          run.index (time run.at) op
  in
  {
    title = "Timeline";
    columns = [ "Run"; "Start"; "Operation"; "Time"; "Bounds"; "Monitor" ];
    rows = List.map row (Timeline.calls timeline);
    notes =
      List.map note (Timeline.runs timeline)
      @ [ "Clock: " ^ time (Timeline.clock timeline) ^ "." ];
  }

let opentrons_observer settings operations =
  let bounds op =
    List.find_map
      (fun (op', b) ->
        if Language.Ast.OpName.string_of op' = op then Some b else None)
      operations
    |> Option.join
  and symbol = snd (time_unit settings) in
  let rec observer timeline =
    {
      observe =
        (fun event ->
          observer
            (match event with
            | Delayed q -> Timeline.delay q timeline
            | Performed op -> Timeline.perform op timeline
            | Resumed -> Timeline.resume timeline
            | Returned value -> Timeline.finish (Returned value) timeline
            | Stopped op -> Timeline.finish (Stopped op) timeline));
      report = lazy (timeline_report ~bounds ~symbol timeline);
    }
  in
  observer Timeline.empty

let opentrons =
  {
    key = "opentrons";
    name = "Opentrons";
    description =
      "Opentrons protocols in Python, with monitors of the running times of \
       operations; interpreter runs record a timeline of the operations.";
    inputs = opentrons_inputs;
    compiler =
      Some { compile = opentrons_compile; code_name = "Opentrons protocol" };
    observer = Some opentrons_observer;
  }

let entries = [ tempore; opentrons ]
let default = tempore
let find key = List.find_opt (fun (entry : entry) -> entry.key = key) entries
