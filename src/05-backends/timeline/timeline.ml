module Rational = Grades.Rational
module IntMap = Map.Make (Int)

type call = {
  run : int;
  op : string;
  depth : int;
  start : Rational.t;
  elapsed : Rational.t option;
}

type wait = { run : int; start : Rational.t; duration : Rational.t }

type resource = {
  run : int;
  start : Rational.t;
  depth : int;
  name : string;
  grade : string;
}

type entry =
  | Call of call
  | Delay of wait
  | Box of resource
  | Unbox of resource

type outcome = Returned of string | Stopped of string
type finished = { index : int; at : Rational.t; outcome : outcome }

(* The entries by their position in the order of starts; [running] holds the
   positions of the calls whose default implementations have not returned,
   the innermost first. *)
type t = {
  clock : Rational.t;
  run : int;
  entries : entry IntMap.t;
  running : int list;
  finished : finished list;  (** the latest first *)
}

let empty =
  {
    clock = Rational.zero;
    run = 1;
    entries = IntMap.empty;
    running = [];
    finished = [];
  }

let clock t = t.clock
let add entry t = IntMap.add (IntMap.cardinal t.entries) entry t.entries

let delay q t =
  let entries =
    match t.running with
    | [] -> add (Delay { run = t.run; start = t.clock; duration = q }) t
    | _ :: _ -> t.entries
  in
  { t with clock = Rational.add t.clock q; entries }

let perform op t =
  let index = IntMap.cardinal t.entries in
  let call =
    {
      run = t.run;
      op;
      depth = List.length t.running;
      start = t.clock;
      elapsed = None;
    }
  in
  {
    t with
    entries = IntMap.add index (Call call) t.entries;
    running = index :: t.running;
  }

let resume t =
  match t.running with
  | [] -> t
  | index :: running ->
      let close = function
        | Call call ->
            Call { call with elapsed = Some (Rational.sub t.clock call.start) }
        | (Delay _ | Box _ | Unbox _) as entry -> entry
      in
      {
        t with
        entries = IntMap.update index (Option.map close) t.entries;
        running;
      }

let resource ~name ~grade t =
  { run = t.run; start = t.clock; depth = List.length t.running; name; grade }

let box ~name ~grade t =
  { t with entries = add (Box (resource ~name ~grade t)) t }

let unbox ~name ~grade t =
  { t with entries = add (Unbox (resource ~name ~grade t)) t }

let finish outcome t =
  {
    t with
    run = t.run + 1;
    running = [];
    finished = { index = t.run; at = t.clock; outcome } :: t.finished;
  }

let observe (observation : Backend.observation) t =
  match observation with
  | Delayed q -> delay q t
  | Performed op -> perform op t
  | Resumed -> resume t
  | Boxed { name; grade } -> box ~name ~grade t
  | Unboxed { name; grade } -> unbox ~name ~grade t
  | Returned value -> finish (Returned value) t
  | Stopped op -> finish (Stopped op) t

let entries t = List.map snd (IntMap.bindings t.entries)

let calls t =
  List.filter_map
    (function Call call -> Some call | Delay _ | Box _ | Unbox _ -> None)
    (entries t)

let runs t = List.rev t.finished

(* Reports *)

type status = Plain | Pending
type row = { cells : string list; status : status }

type report = {
  title : string;
  columns : string list;
  rows : row list;
  notes : string list;
}

let run_of = function
  | Call { run; _ } | Delay { run; _ } | Box { run; _ } | Unbox { run; _ } ->
      run

let report ?run ?time_unit t =
  let time q =
    Rational.show q ^ Option.fold ~none:"" ~some:(fun s -> " " ^ s) time_unit
  in
  let indent depth text =
    String.concat "" (List.init depth (fun _ -> "· ")) ^ text
  in
  let of_run index = Option.fold ~none:true ~some:(Int.equal index) run in
  let resource_row event (resource : resource) =
    {
      cells =
        [
          string_of_int resource.run;
          time resource.start;
          indent resource.depth (event ^ " " ^ resource.name);
          "";
          resource.grade;
        ];
      status = Plain;
    }
  in
  let row = function
    | Call call ->
        {
          cells =
            [
              string_of_int call.run;
              time call.start;
              indent call.depth call.op;
              Option.fold ~none:"running" ~some:time call.elapsed;
              "";
            ];
          status = (if call.elapsed = None then Pending else Plain);
        }
    | Delay wait ->
        {
          cells =
            [
              string_of_int wait.run;
              time wait.start;
              "delay";
              time wait.duration;
              "";
            ];
          status = Plain;
        }
    | Box resource -> resource_row "box" resource
    | Unbox resource -> resource_row "unbox" resource
  in
  let note finished =
    match finished.outcome with
    | Returned value ->
        Printf.sprintf "Run %d returned %s at %s." finished.index value
          (time finished.at)
    | Stopped op ->
        Printf.sprintf
          "Run %d ended at %s at a call of %s, which has neither a handler nor \
           a default implementation."
          finished.index (time finished.at) op
  in
  {
    title = "Timeline";
    columns = [ "Run"; "Start"; "Event"; "Time"; "Grade" ];
    rows =
      List.filter_map
        (fun entry -> if of_run (run_of entry) then Some (row entry) else None)
        (entries t);
    notes =
      (List.filter_map
         (fun finished ->
           if of_run finished.index then Some (note finished) else None)
         (runs t)
      @ if run = None then [ "Clock: " ^ time (clock t) ^ "." ] else []);
  }

(* The number of characters of the UTF-8 string [s]: its bytes other than
   continuation bytes. *)
let length s =
  String.fold_left
    (fun n c -> if Char.code c land 0xC0 = 0x80 then n else n + 1)
    0 s

let text report =
  let lines = report.columns :: List.map (fun row -> row.cells) report.rows in
  let widths =
    List.fold_left
      (fun widths cells -> List.map2 max widths (List.map length cells))
      (List.map (fun _ -> 0) report.columns)
      lines
  in
  let line cells =
    let padded =
      List.map2
        (fun width cell -> cell ^ String.make (width - length cell) ' ')
        widths cells
    in
    let s = String.concat "  " padded in
    let rec trim n = if n > 0 && s.[n - 1] = ' ' then trim (n - 1) else n in
    String.sub s 0 (trim (String.length s))
  in
  String.concat "\n" ((report.title :: List.map line lines) @ report.notes)
  ^ "\n"
