module IntMap = Map.Make (Int)

type event =
  | Call of { op : string; grade : string; returned : bool }
  | Delay of { grade : string }
  | Box of { resource : string; name : string; grade : string }
  | Unbox of { resource : string; name : string; grade : string }

type entry = { run : int; depth : int; start : string; event : event }
type outcome = Returned of string | Stopped of string
type finished = { index : int; at : string; outcome : outcome }

(* The entries by their position in the order of starts; [running] holds the
   positions of the calls whose default implementations have not returned,
   the innermost first. *)
type t = {
  run : int;
  entries : entry IntMap.t;
  running : int list;
  finished : finished list;  (** the latest first *)
}

let empty = { run = 1; entries = IntMap.empty; running = []; finished = [] }

(* An entry inside a default implementation starts at the start of the
   outermost call still running. *)
let add ~at event t =
  let index = IntMap.cardinal t.entries in
  let start =
    match List.rev t.running with
    | [] -> at
    | outermost :: _ -> (IntMap.find outermost t.entries).start
  in
  let entry = { run = t.run; depth = List.length t.running; start; event } in
  (index, { t with entries = IntMap.add index entry t.entries })

let record ~at event t = snd (add ~at event t)

let resume t =
  match t.running with
  | [] -> t
  | index :: running ->
      let close entry =
        match entry.event with
        | Call call -> { entry with event = Call { call with returned = true } }
        | Delay _ | Box _ | Unbox _ -> entry
      in
      {
        t with
        entries = IntMap.update index (Option.map close) t.entries;
        running;
      }

(* The boxes and unboxes of [resource] in the current run, named [name]. *)
let rename ~resource ~name t =
  let current (entry : entry) r = entry.run = t.run && r = resource in
  let rename (entry : entry) =
    match entry.event with
    | Box r when current entry r.resource ->
        { entry with event = Box { r with name } }
    | Unbox r when current entry r.resource ->
        { entry with event = Unbox { r with name } }
    | Box _ | Unbox _ | Call _ | Delay _ -> entry
  in
  { t with entries = IntMap.map rename t.entries }

let finish ~at outcome t =
  {
    t with
    run = t.run + 1;
    running = [];
    finished = { index = t.run; at; outcome } :: t.finished;
  }

let observe (observation : Backend.observation) t =
  match observation with
  | Delayed { at; grade } -> record ~at (Delay { grade }) t
  | Performed { at; op; grade } ->
      let index, t = add ~at (Call { op; grade; returned = false }) t in
      { t with running = index :: t.running }
  | Resumed -> resume t
  | Boxed { at; resource; name; grade } ->
      record ~at (Box { resource; name; grade }) t
  | Unboxed { at; resource; name; grade } ->
      record ~at (Unbox { resource; name; grade }) t
  | Named { resource; name } -> rename ~resource ~name t
  | Returned { at; value } -> finish ~at (Returned value) t
  | Stopped { at; op } -> finish ~at (Stopped op) t

let entries t = List.map snd (IntMap.bindings t.entries)
let runs t = List.rev t.finished

(* Reports *)

type status = Plain | Pending
type row = { cells : string list; status : status; depth : int }

type report = {
  title : string;
  columns : string list;
  rows : row list;
  notes : string list;
}

let report ?run t =
  let of_run index = Option.fold ~none:true ~some:(Int.equal index) run in
  let row (entry : entry) =
    let event, grade, status =
      match entry.event with
      | Call { op; grade; returned } ->
          (op, grade, if returned then Plain else Pending)
      | Delay { grade } -> ("delay", grade, Plain)
      | Box { name; grade; _ } -> ("box " ^ name, grade, Plain)
      | Unbox { name; grade; _ } -> ("unbox " ^ name, grade, Plain)
    in
    {
      cells =
        [
          string_of_int entry.run;
          (if entry.depth = 0 then entry.start else "");
          String.concat "" (List.init entry.depth (fun _ -> "· ")) ^ event;
          grade;
        ];
      status;
      depth = entry.depth;
    }
  in
  let note finished =
    match finished.outcome with
    | Returned value ->
        Printf.sprintf "Run %d returned %s at %s." finished.index value
          finished.at
    | Stopped op ->
        Printf.sprintf
          "Run %d ended at %s at a call of %s, which has neither a handler nor \
           a default implementation."
          finished.index finished.at op
  in
  {
    title = "Timeline";
    columns = [ "Run"; "Start"; "Event"; "Grade" ];
    rows =
      List.filter_map
        (fun (entry : entry) ->
          if of_run entry.run then Some (row entry) else None)
        (entries t);
    notes =
      List.filter_map
        (fun finished ->
          if of_run finished.index then Some (note finished) else None)
        (runs t);
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
