module IntMap = Map.Make (Int)
module StringMap = Map.Make (String)

type event =
  | Call of { op : string; grade : string; returned : bool }
  | Delay of { grade : string }
  | Box of { resource : string; name : string; grade : string }
  | Unbox of { resource : string; name : string }

type entry = { run : int; depth : int; start : string; event : event }
type outcome = Returned of string | Stopped of string
type finished = { index : int; at : string; outcome : outcome }

(* The entries by their position in the order of starts, [count] of them;
   [running] holds the positions of the calls whose default implementations
   have not returned, the innermost first, [depth] of them, the outermost
   starting at [outer_start]; [boxes] holds the positions of the boxes and
   unboxes of the current run, by resource. *)
type t = {
  run : int;
  count : int;
  entries : entry IntMap.t;
  running : int list;
  depth : int;
  outer_start : string;
  boxes : int list StringMap.t;
  finished : finished list;  (** the latest first *)
}

let empty =
  {
    run = 1;
    count = 0;
    entries = IntMap.empty;
    running = [];
    depth = 0;
    outer_start = "";
    boxes = StringMap.empty;
    finished = [];
  }

(* An entry inside a default implementation starts at the start of the
   outermost call still running. *)
let add ~at event t =
  let start = if t.depth = 0 then at else t.outer_start in
  let entry = { run = t.run; depth = t.depth; start; event } in
  ( t.count,
    { t with count = t.count + 1; entries = IntMap.add t.count entry t.entries }
  )

let record ~at event t = snd (add ~at event t)

(* The box or unbox [event] of [resource], recorded among the boxes of the
   current run. *)
let record_box ~at ~resource event t =
  let index, t = add ~at event t in
  {
    t with
    boxes =
      StringMap.update resource
        (fun indices -> Some (index :: Option.value indices ~default:[]))
        t.boxes;
  }

let call ~at event t =
  let index, t = add ~at event t in
  {
    t with
    running = index :: t.running;
    depth = t.depth + 1;
    outer_start = (if t.depth = 0 then at else t.outer_start);
  }

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
        depth = t.depth - 1;
      }

(* The boxes and unboxes of [resource] in the current run, named [name]. *)
let rename ~resource ~name t =
  let rename (entry : entry) =
    match entry.event with
    | Box r -> { entry with event = Box { r with name } }
    | Unbox r -> { entry with event = Unbox { r with name } }
    | Call _ | Delay _ -> entry
  in
  {
    t with
    entries =
      List.fold_left
        (fun entries index -> IntMap.update index (Option.map rename) entries)
        t.entries
        (Option.value (StringMap.find_opt resource t.boxes) ~default:[]);
  }

let finish ~at outcome t =
  {
    t with
    run = t.run + 1;
    running = [];
    depth = 0;
    boxes = StringMap.empty;
    finished = { index = t.run; at; outcome } :: t.finished;
  }

let observe (observation : Backend.observation) t =
  match observation with
  | Delayed { at; grade } -> record ~at (Delay { grade }) t
  | Performed { at; op; grade } ->
      call ~at (Call { op; grade; returned = false }) t
  | Resumed -> resume t
  | Boxed { at; resource; name; grade } ->
      record_box ~at ~resource (Box { resource; name; grade }) t
  | Unboxed { at; resource; name } ->
      record_box ~at ~resource (Unbox { resource; name }) t
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

(* The end [c] with its first or last [k] items if it is a brace group of
   more, the others elided. *)
let group keep k (c, items) =
  match items with
  | Some items when List.length items > k ->
      let kept =
        match keep with
        | Beginning -> take k items @ [ ellipsis ]
        | End -> ellipsis :: drop (List.length items - k) items
      in
      "{" ^ String.concat "; " kept ^ "}"
  | Some _ | None -> c

(* The interval [s] read as ends and groups of items: [ends] are its ends,
   [most] the largest number of items in a group, and [ends_at k] and
   [interval_at k] the ends and the interval with every group reduced to [k]
   items. *)
type reduced = {
  ends : string list;
  most : int;
  ends_at : int -> string list;
  interval_at : int -> string;
}

let reduced keep s =
  let opening, ends, closing = components s in
  let groups = List.map (fun c -> (c, items c)) ends in
  let most =
    List.fold_left
      (fun most (_, items) ->
        max most (Option.fold ~none:0 ~some:List.length items))
      0 groups
  in
  let ends_at k = List.map (group keep k) groups in
  let at k = opening ^ String.concat ", " (ends_at k) ^ closing in
  { ends; most; ends_at; interval_at = at }

(* The first or last [n - 1] characters of [s] with the ellipsis. *)
let cut_ellipsis keep n s =
  match keep with
  | Beginning -> cut Beginning (n - 1) s ^ ellipsis
  | End -> ellipsis ^ cut End (n - 1) s

let shorten keep s =
  let { ends; most; ends_at; interval_at = at } = reduced keep s in
  if List.for_all (fun c -> length c <= limit) ends then s
  else if most = 0 then cut_ellipsis keep limit s
  else
    let fits k = List.for_all (fun c -> length c <= limit) (ends_at k) in
    let rec fit k = if k <= 1 || fits k then k else fit (k - 1) in
    at (fit (max 1 (most - 1)))

let shorten_total keep n s =
  if length s <= n then Some s
  else
    let { most; interval_at = at; _ } = reduced keep s in
    if most = 0 then if n >= 2 then Some (cut_ellipsis keep n s) else None
    else
      let rec fit k =
        if k < 1 then None
        else
          let candidate = at k in
          if length candidate <= n then Some candidate else fit (k - 1)
      in
      fit (max 1 (most - 1))

let event_limit = 50

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
  full_notes : string list;
}

let report ?run t =
  let of_run index = Option.fold ~none:true ~some:(Int.equal index) run in
  let row (entry : entry) =
    let mark = String.concat "" (List.init entry.depth (fun _ -> "· ")) in
    (* The event, its grade, and the event and grade shortened. *)
    let event, grade, short_event, status =
      match entry.event with
      | Call { op; grade; returned } ->
          (op, grade, op, if returned then Plain else Pending)
      | Delay { grade } -> ("delay", grade, "delay", Plain)
      | Box { name; grade; _ } ->
          let box = "box " ^ name ^ " with grade " in
          let room = event_limit - length mark - length box in
          let shortened =
            match shorten_total Beginning room grade with
            | Some g -> g
            | None -> ellipsis
          in
          (box ^ grade, "", box ^ shortened, Plain)
      | Unbox { name; _ } ->
          let unbox = "unbox " ^ name in
          (unbox, "", unbox, Plain)
    in
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
  let note shorten_at finished =
    let at = shorten_at finished.at in
    match finished.outcome with
    | Returned value ->
        Printf.sprintf "Run %d returned %s at %s." finished.index value at
    | Stopped op ->
        Printf.sprintf
          "Run %d ended at %s at a call of %s, which has neither a handler nor \
           a default implementation."
          finished.index at op
  in
  let notes shorten_at =
    List.filter_map
      (fun finished ->
        if of_run finished.index then Some (note shorten_at finished) else None)
      (runs t)
  in
  {
    title = "Timeline";
    columns = [ "Run"; "Start"; "Event"; "Grade" ];
    rows =
      List.filter_map
        (fun (entry : entry) ->
          if of_run entry.run then Some (row entry) else None)
        (entries t);
    notes = notes (shorten End);
    full_notes = notes Fun.id;
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
  String.concat "\n"
    ((report.title :: List.map line lines)
    @ if full then report.full_notes else report.notes)
  ^ "\n"
