module IntMap = Map.Make (Int)

type event =
  | Call of { op : string; grade : string; returned : bool }
  | Delay of { grade : string }
  | Box of { resource : string; name : string; grade : string }
  | Unbox of { resource : string; name : string }

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
  | Unboxed { at; resource; name } -> record ~at (Unbox { resource; name }) t
  | Named { resource; name } -> rename ~resource ~name t
  | Returned { at; value } -> finish ~at (Returned value) t
  | Stopped { at; op } -> finish ~at (Stopped op) t

let entries t = List.map snd (IntMap.bindings t.entries)
let runs t = List.rev t.finished

(* Shortening *)

type keep = Beginning | End

let limit = 40

(* The number of characters of the UTF-8 string [s]: its bytes other than
   continuation bytes. *)
let length s =
  String.fold_left
    (fun n c -> if Char.code c land 0xC0 = 0x80 then n else n + 1)
    0 s

let is_opening c = c = '(' || c = '[' || c = '{'
let is_closing c = c = ')' || c = ']' || c = '}'

(* The parts of [s] between the occurrences of [sep] outside every pair of
   brackets, parentheses or braces. *)
let split ~sep s =
  let n = String.length s and m = String.length sep in
  let rec go depth from i parts =
    if i >= n then List.rev (String.sub s from (n - from) :: parts)
    else if depth = 0 && i + m <= n && String.sub s i m = sep then
      go depth (i + m) (i + m) (String.sub s from (i - from) :: parts)
    else
      let c = s.[i] in
      let depth =
        if is_opening c then depth + 1
        else if is_closing c then depth - 1
        else depth
      in
      go depth from (i + 1) parts
  in
  go 0 0 0 []

(* Whether [s] is enclosed by the bracket at its start, which [first] admits,
   and the one at its end, which [last] admits, the first closed only at the
   end. *)
let enclosed ~first ~last s =
  let n = String.length s in
  let rec closes_at_end depth i =
    if i >= n - 1 then true
    else
      let c = s.[i] in
      let depth =
        if is_opening c then depth + 1
        else if is_closing c then depth - 1
        else depth
      in
      depth > 0 && closes_at_end depth (i + 1)
  in
  n >= 2 && first s.[0] && last s.[n - 1] && closes_at_end 0 0

let inner s = String.sub s 1 (String.length s - 2)

(* The ends of an interval [s], with its brackets, or [s] alone. *)
let components s =
  let interval =
    enclosed
      ~first:(fun c -> c = '[' || c = '(')
      ~last:(fun c -> c = ']' || c = ')')
      s
  in
  match if interval then split ~sep:", " (inner s) else [] with
  | _ :: _ :: _ as ends ->
      (String.make 1 s.[0], ends, String.make 1 s.[String.length s - 1])
  | [] | [ _ ] -> ("", [ s ], "")

(* The items of the brace group [c], if it is one. *)
let items c =
  if enclosed ~first:(Char.equal '{') ~last:(Char.equal '}') c then
    Some (split ~sep:"; " (inner c))
  else None

let rec take k = function x :: xs when k > 0 -> x :: take (k - 1) xs | _ -> []
let drop k l = List.filteri (fun i _ -> i >= k) l

(* The UTF-8 string [s] cut to its first or last [k] characters. *)
let cut keep k s =
  let n = String.length s in
  let starts =
    List.filter
      (fun i -> Char.code s.[i] land 0xC0 <> 0x80)
      (List.init n Fun.id)
  in
  let count = List.length starts in
  match keep with
  | Beginning -> (
      match drop k starts with [] -> s | i :: _ -> String.sub s 0 i)
  | End -> (
      match drop (count - k) starts with
      | i :: _ when count > k -> String.sub s i (n - i)
      | _ -> s)

let ellipsis = "…"

let shorten keep s =
  let opening, ends, closing = components s in
  if List.for_all (fun c -> length c <= limit) ends then s
  else
    let groups = List.map (fun c -> (c, items c)) ends in
    let most =
      List.fold_left
        (fun most (_, items) ->
          max most (Option.fold ~none:0 ~some:List.length items))
        0 groups
    in
    (* The end [c] with its first or last [k] items if it is a brace group,
       the others elided. *)
    let group k (c, items) =
      match items with
      | Some items when List.length items > k ->
          let kept =
            match keep with
            | Beginning -> take k items @ [ ellipsis ]
            | End -> ellipsis :: drop (List.length items - k) items
          in
          "{" ^ String.concat "; " kept ^ "}"
      | Some _ | None -> c
    in
    let fits k = List.for_all (fun g -> length (group k g) <= limit) groups in
    let rec fit k = if k <= 1 || fits k then k else fit (k - 1) in
    if most = 0 then
      match keep with
      | Beginning -> cut Beginning (limit - 1) s ^ ellipsis
      | End -> ellipsis ^ cut End (limit - 1) s
    else
      let k = fit (max 1 (most - 1)) in
      opening ^ String.concat ", " (List.map (group k) groups) ^ closing

(* Reports *)

type status = Plain | Pending

type row = {
  cells : string list;
  short : string list;
  status : status;
  depth : int;
}

type report = {
  title : string;
  columns : string list;
  rows : row list;
  notes : string list;
}

let report ?run t =
  let of_run index = Option.fold ~none:true ~some:(Int.equal index) run in
  let row (entry : entry) =
    (* The event, its grade, and the event and grade shortened. *)
    let event, grade, short_event, status =
      match entry.event with
      | Call { op; grade; returned } ->
          (op, grade, op, if returned then Plain else Pending)
      | Delay { grade } -> ("delay", grade, "delay", Plain)
      | Box { name; grade; _ } ->
          let box = "box " ^ name ^ " with grade " in
          (box ^ grade, "", box ^ shorten Beginning grade, Plain)
      | Unbox { name; _ } ->
          let unbox = "unbox " ^ name in
          (unbox, "", unbox, Plain)
    in
    let mark = String.concat "" (List.init entry.depth (fun _ -> "· ")) in
    let start = if entry.depth = 0 then entry.start else "" in
    let run = string_of_int entry.run in
    {
      cells = [ run; start; mark ^ event; grade ];
      short =
        [ run; shorten End start; mark ^ short_event; shorten Beginning grade ];
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

let text ?(full = false) report =
  let lines =
    report.columns
    :: List.map (fun row -> if full then row.cells else row.short) report.rows
  in
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
