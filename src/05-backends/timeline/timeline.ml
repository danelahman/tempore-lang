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

type box = {
  run : int;
  start : Rational.t;
  depth : int;
  name : string;
  grade : string;
}

type unbox = {
  run : int;
  start : Rational.t;
  depth : int;
  name : string;
  box_grade : string;
  accumulated : string;
  within : bool;
}

type entry = Call of call | Delay of wait | Box of box | Unbox of unbox
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

let box ~name ~grade t =
  let depth = List.length t.running in
  {
    t with
    entries = add (Box { run = t.run; start = t.clock; depth; name; grade }) t;
  }

let unbox ~name ~box_grade ~accumulated ~within t =
  let depth = List.length t.running in
  let unbox =
    {
      run = t.run;
      start = t.clock;
      depth;
      name;
      box_grade;
      accumulated;
      within;
    }
  in
  { t with entries = add (Unbox unbox) t }

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
  | Unboxed { name; box_grade; accumulated; within } ->
      unbox ~name ~box_grade ~accumulated ~within t
  | Returned value -> finish (Returned value) t
  | Stopped op -> finish (Stopped op) t

let entries t = List.map snd (IntMap.bindings t.entries)

let calls t =
  List.filter_map
    (function Call call -> Some call | Delay _ | Box _ | Unbox _ -> None)
    (entries t)

let runs t = List.rev t.finished

(* Reports *)

type verdict = Within | Outside | Unchecked | Unfinished
type status = Plain | Good | Bad | Pending
type row = { cells : string list; status : status }

type report = {
  title : string;
  columns : string list;
  rows : row list;
  notes : string list;
}

let report ?verdict ?time_unit t =
  let time q =
    Rational.show q ^ Option.fold ~none:"" ~some:(fun s -> " " ^ s) time_unit
  in
  let indent depth text =
    String.concat "" (List.init depth (fun _ -> "· ")) ^ text
  in
  let row = function
    | Call call ->
        let check, status =
          match Option.map (fun verdict -> verdict call) verdict with
          | Some Within -> ("within", Good)
          | Some Outside -> ("outside", Bad)
          | Some Unchecked -> ("not monitored", Plain)
          | Some Unfinished -> ("unfinished", Pending)
          | None -> ("", if call.elapsed = None then Pending else Plain)
        in
        {
          cells =
            [
              string_of_int call.run;
              time call.start;
              indent call.depth call.op;
              Option.fold ~none:"running" ~some:time call.elapsed;
              "";
              check;
            ];
          status;
        }
    | Delay wait ->
        {
          cells =
            [
              string_of_int wait.run;
              time wait.start;
              "delay";
              time wait.duration;
              "—";
              "—";
            ];
          status = Plain;
        }
    | Box box ->
        {
          cells =
            [
              string_of_int box.run;
              time box.start;
              indent box.depth ("box " ^ box.name);
              "";
              box.grade;
              "";
            ];
          status = Plain;
        }
    | Unbox unbox ->
        let check = if unbox.within then "within" else "outside" in
        {
          cells =
            [
              string_of_int unbox.run;
              time unbox.start;
              indent unbox.depth ("unbox " ^ unbox.name);
              "";
              unbox.accumulated ^ " " ^ check ^ " " ^ unbox.box_grade;
              check;
            ];
          status = (if unbox.within then Good else Bad);
        }
  in
  let note run =
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
    columns = [ "Run"; "Start"; "Event"; "Time"; "Grade"; "Check" ];
    rows = List.map row (entries t);
    notes = List.map note (runs t) @ [ "Clock: " ^ time (clock t) ^ "." ];
  }
