(* A reference decision of the order of the timed grades with interval
   letters, by exhaustive search over exact words on a grid.

   An exact word is a sequence of operations, each with an exact running time,
   strict waits and budget stretches, each with an exact length. A grade
   [x] is below a grade [y] iff every exact word of [x] fits some exact word
   of [y]. A word fits another when it follows the other's skeleton: the
   operations of the greater word occur in the lesser one at the same time
   spans, in order; a strict wait of the greater word holds waiting only; a
   budget stretch holds any items whose operations belong to its set, an item
   overlapping several stretches belonging to the set of each (the window
   rule). A stretch of length [0] vanishes. Running times are positive.

   Lengths are integers of a base grid. Open ends are read with two orders of
   infinitesimals: the exact words of the lesser grade approach an open end by
   [dx] units of a finer grid, those of the greater grade by one unit, a base
   unit being [k] units, with [dx] above the number of the pieces of the
   greater word and [k] above [dx] times the number of the items of the lesser
   one. The lengths of the lesser grade are sampled: every base value of an
   interval, its open ends approached, an unbounded interval up to two base
   units above its lower end. The lengths of the greater grade are chosen
   during the search. *)

type set = All | Names of string list

let mem name = function All -> true | Names names -> List.mem name names

let subset s s' =
  match (s, s') with
  | _, All -> true
  | All, Names _ -> false
  | Names a, Names b -> List.for_all (fun n -> List.mem n b) a

type interval = { lo : int; lo_open : bool; hi : int option; hi_open : bool }

let closed lo hi = { lo; lo_open = false; hi = Some hi; hi_open = false }
let point d = closed d d

(* The one-sided intervals: [0, d] or [0, d), and [d, ∞) or (d, ∞). *)
let at_most ?(open_ = false) d =
  { lo = 0; lo_open = false; hi = Some d; hi_open = open_ }

let at_least ?(open_ = false) d =
  { lo = d; lo_open = open_; hi = None; hi_open = true }

let unbounded = at_least 0

type letter = Op of string list | Stretch of set * interval

type expr =
  | Eps
  | Empty
  | Letter of letter
  | Seq of expr list
  | Alt of expr list
  | Rep of expr * int * int

let op name = Letter (Op [ name ])
let strict iv = Letter (Stretch (Names [], iv))
let budget iv = Letter (Stretch (All, iv))

(* {1 Skeletons} *)

(* [skeletons e] is the words of letters of the star-free expression [e]. *)
let rec skeletons = function
  | Eps -> [ [] ]
  | Empty -> []
  | Letter l -> [ [ l ] ]
  | Seq es ->
      List.fold_right
        (fun e acc ->
          List.concat_map
            (fun w -> List.map (fun w' -> w @ w') acc)
            (skeletons e))
        es [ [] ]
  | Alt es -> List.sort_uniq compare (List.concat_map skeletons es)
  | Rep (e, m, n) ->
      let one = skeletons e in
      let rec power k =
        if k = 0 then [ [] ]
        else
          List.concat_map
            (fun w -> List.map (fun w' -> w @ w') (power (k - 1)))
            one
      in
      List.sort_uniq compare
        (List.concat_map power (List.init (n - m + 1) (fun i -> m + i)))

(* {1 Exact words} *)

type item = IOp of string * int | IWait of int | IBudget of set * int

let length = function IOp (_, t) -> t | IWait d | IBudget (_, d) -> d

(* [samples ~dense ~k ~dx iv] is the sampled lengths of [iv], in units, and
   if [dense] the length just above a closed lower end. *)
let samples ~dense ~k ~dx iv =
  let top = match iv.hi with Some h -> h | None -> iv.lo + 2 in
  let grid =
    List.filter
      (fun v ->
        (v > iv.lo || not iv.lo_open)
        && match iv.hi with Some h -> v < h || not iv.hi_open | None -> true)
      (List.init (top - iv.lo + 1) (fun i -> iv.lo + i))
  in
  let approached =
    (if iv.lo_open || (dense && iv.hi <> Some iv.lo) then [ (iv.lo * k) + dx ]
     else [])
    @ match iv.hi with Some h when iv.hi_open -> [ (h * k) - dx ] | _ -> []
  in
  List.sort_uniq Int.compare (List.map (fun v -> v * k) grid @ approached)

(* [words ~dense ~running_time ~k ~dx skeleton] is the sampled exact words of
   [skeleton]. *)
let words ~dense ~running_time ~k ~dx skeleton =
  let choices = function
    | Op names ->
        List.concat_map
          (fun name ->
            List.map
              (fun t -> Some (IOp (name, t)))
              (samples ~dense ~k ~dx (running_time name)))
          names
    | Stretch (set, iv) ->
        List.map
          (fun d ->
            if d = 0 then None
            else if set = Names [] then Some (IWait d)
            else Some (IBudget (set, d)))
          (samples ~dense ~k ~dx iv)
  in
  List.fold_right
    (fun l acc ->
      List.concat_map
        (fun c ->
          List.map (fun w -> match c with Some i -> i :: w | None -> w) acc)
        (choices l))
    skeleton [ [] ]

(* {1 Fitting} *)

type piece = POp of string list | PStretch of set * int * int option

(* [piece ~k l] is the letter [l] of the greater word with its lengths in
   units, its open ends approached by one unit. *)
let piece ~k = function
  | Op names -> POp names
  | Stretch (set, iv) ->
      PStretch
        ( set,
          (iv.lo * k) + Bool.to_int iv.lo_open,
          Option.map (fun h -> (h * k) - Bool.to_int iv.hi_open) iv.hi )

let admits set = function
  | IWait _ -> true
  | IBudget (s, _) -> subset s set
  | IOp (name, _) -> mem name set

(* [fits items pieces] is whether the exact word [items] fits a word of the
   skeleton [pieces], the lengths of its stretches chosen. The search state
   is the item read, what of it remains, the piece read and the length it has
   received. An item is divided among consecutive stretches only at the
   lengths that fill a stretch to an end of its interval: over one-sided
   intervals, the other divisions are dominated. *)
let fits items pieces =
  let items = Array.of_list items and pieces = Array.of_list pieces in
  let n = Array.length items and m = Array.length pieces in
  let memo = Hashtbl.create 64 in
  let rec go i r j u =
    let key = (i, r, j, u) in
    match Hashtbl.find_opt memo key with
    | Some b -> b
    | None ->
        let b = step i r j u in
        Hashtbl.add memo key b;
        b
  and next i = if i + 1 < n then (i + 1, length items.(i + 1)) else (n, 0)
  and step i r j u =
    if j = m then i = n
    else
      let fresh = i < n && r = length items.(i) in
      match pieces.(j) with
      | POp names -> (
          u = 0 && fresh
          &&
          match items.(i) with
          | IOp (name, _) when List.mem name names ->
              let i', r' = next i in
              go i' r' (j + 1) 0
          | _ -> false)
      | PStretch (set, lo, hi) ->
          let within v =
            v >= lo && match hi with Some h -> v <= h | None -> true
          in
          let close = within u && go i r (j + 1) 0 in
          close
          || i < n
             && admits set items.(i)
             &&
             let candidates =
               List.sort_uniq Int.compare
                 (r
                 :: List.filter
                      (fun d -> d > 0 && d < r)
                      ((lo - u)
                      :: (match hi with Some h -> [ h - u ] | None -> [])))
             in
             List.exists
               (fun d ->
                 (match hi with Some h -> u + d <= h | None -> true)
                 &&
                 if d = r then
                   let i', r' = next i in
                   go i' r' j (u + d)
                 else go i (r - d) j (u + d))
               candidates
  in
  let r0 = if n > 0 then length items.(0) else 0 in
  go 0 r0 0 0

(* {1 The order} *)

(* [leq ~running_time x y] is whether every exact word of [x] fits some exact
   word of [y], the operations running for the intervals [running_time]. *)
let leq ?(dense = true) ~running_time x y =
  let xs = skeletons x and ys = skeletons y in
  let longest ws = List.fold_left (fun a w -> max a (List.length w)) 0 ws in
  let dx = longest ys + 2 in
  let k = ((longest xs + 2) * dx) + 1 in
  let ys = List.map (List.map (piece ~k)) ys in
  List.for_all
    (fun skeleton ->
      List.for_all
        (fun w -> List.exists (fits w) ys)
        (words ~dense ~running_time ~k ~dx skeleton))
    xs

(* {1 Printing} *)

let show_interval iv =
  let num = string_of_int in
  match iv with
  | { lo = 0; lo_open = false; hi = Some h; hi_open } ->
      (if hi_open then "<" else "≤") ^ num h
  | { lo; lo_open; hi = None; _ } -> (if lo_open then ">" else "≥") ^ num lo
  | { lo; lo_open; hi = Some h; hi_open } ->
      (if lo_open then "(" else "[")
      ^ num lo ^ ", " ^ num h
      ^ if hi_open then ")" else "]"

let rec show = function
  | Eps -> "0"
  | Empty -> "∅"
  | Letter (Op [ name ]) -> name
  | Letter (Op names) -> "(" ^ String.concat " | " names ^ ")"
  | Letter (Stretch (Names [], iv)) -> "idle " ^ show_interval iv
  | Letter (Stretch (All, iv)) -> show_interval iv
  | Letter (Stretch (Names names, iv)) ->
      "(" ^ show_interval iv ^ " & (" ^ String.concat " | " names ^ "))"
  | Seq es -> "(" ^ String.concat "; " (List.map show es) ^ ")"
  | Alt es -> "(" ^ String.concat " | " (List.map show es) ^ ")"
  | Rep (e, m, n) ->
      show e ^ "^[" ^ string_of_int m ^ ", " ^ string_of_int n ^ "]"

(* {1 Run consistency}

   An interval [[x, y]] of a lower bound [x] and an upper bound [y] is
   consistent iff some run fits a word of each. A run is a sequence of
   operations, each with a running time within its interval, and strict
   waits; it is enumerated on a grid of [k] units per base unit, [k] above
   the number of the letters of the two words, up to a horizon: the greatest
   duration of the upper bound where it is bounded, and above the sum of the
   constants of both expressions otherwise, with at most as many operations
   as the two words have together. *)

(* [constants e] is the sum of the finite ends of the letters of [e], each
   repetition counted at its greatest count, and the number of operation
   letters on the way. *)
let rec constants ~running_time = function
  | Eps | Empty -> 0
  | Letter (Op names) ->
      List.fold_left
        (fun acc n ->
          let iv : interval = running_time n in
          max acc (match iv.hi with Some h -> h | None -> iv.lo))
        0 names
  | Letter (Stretch (_, iv)) -> (
      match iv.hi with Some h -> max h iv.lo | None -> iv.lo)
  | Seq es | Alt es ->
      List.fold_left (fun acc e -> acc + constants ~running_time e) 0 es
  | Rep (e, _, n) -> n * constants ~running_time e

let operations skeleton =
  List.length (List.filter (function Op _ -> true | _ -> false) skeleton)

let names skeletons =
  List.sort_uniq String.compare
    (List.concat_map
       (List.concat_map (function Op names -> names | Stretch _ -> []))
       skeletons)

(* [runs ~running_time ~k ~names ~operations ~horizon] is the runs of at most
   [operations] operations of [names], of duration at most [horizon] units,
   their waits merged, as a sequence. *)
let runs ~running_time ~k ~names ~operations ~horizon =
  let times name =
    let iv : interval = running_time name in
    let top = match iv.hi with Some h -> h * k | None -> horizon in
    List.filter
      (fun t ->
        t > 0
        && (t > iv.lo * k || not iv.lo_open)
        && (t < top || not (iv.hi_open && iv.hi <> None)))
      (List.init (top - (iv.lo * k) + 1) (fun i -> (iv.lo * k) + i))
  in
  let rec after_wait left ops =
    Seq.cons []
      (if ops = 0 then Seq.empty
       else
         Seq.flat_map
           (fun name ->
             Seq.flat_map
               (fun t ->
                 if t > left then Seq.empty
                 else
                   Seq.map
                     (fun rest -> IOp (name, t) :: rest)
                     (from (left - t) (ops - 1)))
               (List.to_seq (times name)))
           (List.to_seq names))
  and from left ops =
    Seq.flat_map
      (fun w ->
        Seq.map
          (fun rest -> if w = 0 then rest else IWait w :: rest)
          (after_wait (left - w) ops))
      (Seq.init (left + 1) Fun.id)
  in
  from horizon operations

(* [consistent ?dense ~running_time x y] is whether some run on the grid fits
   a word of [x] and a word of [y]: over whole steps, the grid of the base
   unit unless [dense]. *)
let consistent ?(dense = true) ~running_time x y =
  let xs = skeletons x and ys = skeletons y in
  let longest ws = List.fold_left (fun a w -> max a (List.length w)) 0 ws in
  let most ws = List.fold_left (fun a w -> max a (operations w)) 0 ws in
  let k = if dense then longest xs + longest ys + 1 else 1 in
  let bounded =
    List.for_all
      (List.for_all (function
        | Stretch (_, { hi = None; _ }) -> false
        | Stretch _ -> true
        | Op names ->
            List.for_all (fun n -> (running_time n : interval).hi <> None) names))
      ys
  in
  let horizon =
    if bounded then k * constants ~running_time y
    else k * (constants ~running_time x + constants ~running_time y + 1)
  in
  let px = List.map (List.map (piece ~k)) xs
  and py = List.map (List.map (piece ~k)) ys in
  Seq.exists
    (fun r -> List.exists (fits r) px && List.exists (fits r) py)
    (runs ~running_time ~k
       ~names:(names (xs @ ys))
       ~operations:(most xs + most ys)
       ~horizon)

(* [admits ~k x r] is whether the run [r], its lengths in units of [1/k],
   fits a word of [x]. *)
let admits ~k x r =
  List.exists (fits r) (List.map (List.map (piece ~k)) (skeletons x))
