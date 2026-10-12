module Rational = Grades.Rational
module Grade = Grades.Grade
module IntMap = Map.Make (Int)

type call = {
  run : int;
  op : string;
  depth : int;
  start : Rational.t;
  elapsed : Rational.t option;
}

type wait = { run : int; start : Rational.t; duration : Rational.t }
type entry = Call of call | Delay of wait
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

let delay q t =
  let entries =
    match t.running with
    | [] ->
        IntMap.add
          (IntMap.cardinal t.entries)
          (Delay { run = t.run; start = t.clock; duration = q })
          t.entries
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
        | Delay _ as entry -> entry
      in
      {
        t with
        entries = IntMap.update index (Option.map close) t.entries;
        running;
      }

let finish outcome t =
  {
    t with
    run = t.run + 1;
    running = [];
    finished = { index = t.run; at = t.clock; outcome } :: t.finished;
  }

let entries t = List.map snd (IntMap.bindings t.entries)

let calls t =
  List.filter_map
    (function Call call -> Some call | Delay _ -> None)
    (entries t)

let runs t = List.rev t.finished

let within (lo, hi) d =
  let above =
    match (lo : Rational.t Grade.bound) with
    | Closed q -> Rational.compare q d <= 0
    | Open q -> Rational.compare q d < 0
    | Unbounded -> true
  and below =
    match (hi : Rational.t Grade.bound) with
    | Closed q -> Rational.compare d q <= 0
    | Open q -> Rational.compare d q < 0
    | Unbounded -> true
  in
  above && below

type verdict = Within | Outside | Unchecked | Unfinished

(* The bounds [\[0, ∞)] hold of every duration, and are not monitored. *)
let monitored = function
  | Some ((lo, hi) : Grade.running_time) -> (
      match (lo, hi) with
      | Closed q, Unbounded when Rational.sign q = 0 -> None
      | _ -> Some (lo, hi))
  | None -> None

let verdict bounds call =
  match (monitored bounds, call.elapsed) with
  | _, None -> Unfinished
  | None, Some _ -> Unchecked
  | Some bounds, Some d -> if within bounds d then Within else Outside
