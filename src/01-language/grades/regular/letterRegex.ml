module Letters = SymbolicRegex.Letters

type t =
  | Empty
  | Eps
  | Letters of Letters.t
  | Seq of t list
  | Union of t list
  | Inter of t list
  | Compl of t
  | Star of t

let rank = function
  | Eps -> 0
  | Letters _ -> 1
  | Seq _ -> 2
  | Star _ -> 3
  | Compl _ -> 4
  | Inter _ -> 5
  | Union _ -> 6
  | Empty -> 7

let rec compare r s =
  match (r, s) with
  | Letters p, Letters q -> Letters.order p q
  | Seq rs, Seq ss | Union rs, Union ss | Inter rs, Inter ss ->
      List.compare compare rs ss
  | Star r, Star s | Compl r, Compl s -> compare r s
  | _ -> Int.compare (rank r) (rank s)

let equal r s = compare r s = 0
let mem r rs = List.exists (equal r) rs

let rec nullable = function
  | Empty | Letters _ -> false
  | Eps | Star _ -> true
  | Seq rs | Inter rs -> List.for_all nullable rs
  | Union rs -> List.exists nullable rs
  | Compl r -> not (nullable r)

(** {1 Constructions} *)

let empty = Empty
let eps = Eps
let top = Star (Letters Letters.any)
let letters p = if Letters.is_empty p then Empty else Letters p

(** [merge_letters combine rs] merges the letter sets among the operands [rs]
    into the one they combine to by [combine]. *)
let merge_letters combine rs =
  let sets, others =
    List.partition_map (function Letters p -> Left p | r -> Right r) rs
  in
  match sets with
  | [] -> others
  | p :: ps -> letters (List.fold_left combine p ps) :: others

(** [collapse rs] rewrites [x*; x*] to [x*] in the factors [rs]. *)
let rec collapse = function
  | (Star _ as x) :: (Star _ as y) :: rest when equal x y -> collapse (x :: rest)
  | r :: rest -> r :: collapse rest
  | [] -> []

let seq rs =
  let factors = function Seq rs -> rs | Eps -> [] | r -> [ r ] in
  if mem Empty rs then Empty
  else
    match collapse (List.concat_map factors rs) with
    | [] -> Eps
    | [ r ] -> r
    | rs -> Seq rs

(** [plus r] is [Some x] if [r] is [x; x*] or [x*; x]. *)
let plus r =
  let init_last rs =
    match List.rev rs with
    | last :: rev_init -> Some (List.rev rev_init, last)
    | [] -> None
  in
  match r with
  | Seq (Star x :: rest) when equal (seq rest) x -> Some x
  | Seq rs -> (
      match init_last rs with
      | Some (init, Star x) when equal (seq init) x -> Some x
      | _ -> None)
  | _ -> None

(** [group key rs] gathers the operands [rs] by [key], each group listed in the
    order of its first operand, the operands of a group in their order. *)
let group key rs =
  let add groups r =
    let k = key r in
    if List.exists (fun (k', _) -> equal k k') groups then
      List.map
        (fun (k', members) ->
          if equal k k' then (k', r :: members) else (k', members))
        groups
    else (k, [ r ]) :: groups
  in
  List.rev_map
    (fun (k, members) -> (k, List.rev members))
    (List.fold_left add [] rs)

let is_tick = function Letters p -> Letters.equal p Letters.tick | _ -> false

(** [first_part rs] splits the factors [rs] after their first part: a maximal
    run of ticks, printed as one integer, or else their first factor. *)
let first_part = function
  | r :: _ as rs when is_tick r ->
      let run = List.take_while is_tick rs in
      (seq run, List.drop (List.length run) rs)
  | r :: rest -> (r, rest)
  | [] -> (Eps, [])

(** [split_first r] is [r] as [x; y], [x] the first part of [r] and [y] the
    rest, [y] being [ε] if [r] is no concatenation, and [split_last r] is [r] as
    [y; x], [x] its last part. *)
let split_first = function
  | Seq rs ->
      let x, rest = first_part rs in
      (x, seq rest)
  | r -> (r, Eps)

let split_last = function
  | Seq rs ->
      let x, rev_rest = first_part (List.rev rs) in
      (x, seq (List.rev rev_rest))
  | r -> (r, Eps)

let rec union rs =
  let operands = function Union rs -> rs | Empty -> [] | r -> [ r ] in
  let rs = List.concat_map operands rs in
  let rs = List.sort_uniq compare (merge_letters Letters.union rs) in
  let rs =
    List.filter
      (fun r ->
        not (List.exists (function Star x -> equal x r | _ -> false) rs))
      rs
  in
  match absorb_eps rs with
  | Some rs -> union rs
  | None -> (
      match factor rs with
      | Some rs -> union rs
      | None -> ( match rs with [] -> Empty | [ r ] -> r | rs -> Union rs))

(** [absorb_eps rs] is [Some rs'] if the operands [rs] of a union include a
    nullable one, so that the union contains the empty word, and either [ε] and
    another nullable operand, or an operand [x; x*] or [x*; x]: [ε] is dropped
    in the first case, and each [x; x*] and [x*; x] becomes [x*]. *)
and absorb_eps rs =
  let others = List.filter (fun r -> not (equal r Eps)) rs in
  let starred r = Option.map star (plus r) in
  let redundant_eps = mem Eps rs && List.exists nullable others in
  let pluses = List.exists (fun r -> Option.is_some (starred r)) rs in
  if List.exists nullable rs && (redundant_eps || pluses) then
    Some
      (List.map
         (fun r -> Option.value (starred r) ~default:r)
         (if redundant_eps then others else rs))
  else None

(** [factor rs] is [Some rs'] if two operands of [rs] have a common first
    factor, or else a common last factor, [rs'] being the operands with the
    common factors factored out. *)
and factor rs =
  let factored split join =
    let groups = group (fun r -> fst (split r)) rs in
    if List.length groups = List.length rs then None
    else
      Some
        (List.map
           (fun (x, members) ->
             match members with
             | [ r ] -> r
             | members ->
                 join x (union (List.map (fun r -> snd (split r)) members)))
           groups)
  in
  match factored split_first (fun x y -> seq [ x; y ]) with
  | Some rs -> Some rs
  | None -> factored split_last (fun x y -> seq [ y; x ])

and star r =
  let unstar = function Star x -> x | x -> Option.value (plus x) ~default:x in
  match r with
  | Empty | Eps -> Eps
  | Star _ -> r
  | Union rs ->
      let rs' = List.map unstar (List.filter (fun r -> not (equal r Eps)) rs) in
      if List.equal equal rs rs' then Star r else star (union rs')
  | Seq rs when List.for_all nullable rs -> star (union rs)
  | r -> ( match plus r with Some x -> Star x | None -> Star r)

let inter rs =
  let operands = function
    | Inter rs -> rs
    | r when equal r top -> []
    | r -> [ r ]
  in
  let rs = List.concat_map operands rs in
  let rs =
    if List.exists (function Letters _ -> true | _ -> false) rs then
      merge_letters Letters.inter rs
    else rs
  in
  if mem Empty rs then Empty
  else
    match List.sort_uniq compare rs with
    | [] -> top
    | [ r ] -> r
    | rs -> Inter rs

let compl = function
  | Compl r -> r
  | Empty -> top
  | r when equal r top -> Empty
  | r -> Compl r

let rec of_symbolic r =
  match SymbolicRegex.view r with
  | SymbolicRegex.Empty -> empty
  | Eps -> eps
  | Letters p -> letters p
  | Concat (r, s) -> seq [ of_symbolic r; of_symbolic s ]
  | Union rs -> union (List.map of_symbolic rs)
  | Inter rs -> inter (List.map of_symbolic rs)
  | Compl r -> compl (of_symbolic r)
  | Star r -> star (of_symbolic r)

(** {1 Printing} *)

type factor = Ticks of int | Factor of t

(** [group_ticks rs] joins the runs of ticks of the factors [rs] into their
    number. *)
let group_ticks rs =
  let add r acc =
    match acc with
    | Ticks n :: acc when is_tick r -> Ticks (n + 1) :: acc
    | acc when is_tick r -> Ticks 1 :: acc
    | acc -> Factor r :: acc
  in
  List.fold_right add rs []

(** [letters_size p] is the size of the printed form of the letter set [p]. *)
let letters_size (p : Letters.t) =
  let tick = Bool.to_int p.tick and no_tick = Bool.to_int (not p.tick) in
  match p.names with
  | Only names -> (2 * (List.length names + tick)) - 1
  | Except [] when p.tick -> 1
  | Except names -> (2 * (List.length names + no_tick)) + 2

let rec size = function
  | Empty -> 3
  | Eps -> 1
  | Letters p -> letters_size p
  | Seq rs ->
      let part = function Ticks _ -> 1 | Factor r -> size r in
      let parts = group_ticks rs in
      List.fold_left (fun n p -> n + part p) (List.length parts - 1) parts
  | Union rs | Inter rs ->
      List.fold_left (fun n r -> n + size r) (List.length rs - 1) rs
  | Compl r | Star r -> 1 + size r

let smallest = function
  | [] -> invalid_arg "LetterRegex.smallest: no expression"
  | r :: rs ->
      List.fold_left (fun best r -> if size r < size best then r else best) r rs

type printed = { text : string; level : int }
(* The level of the outermost operator of [text]: [0] union, [1]
   intersection, [2] concatenation, [3] complement, [4] repetition and [5] an
   atom. *)

let atom text = { text; level = 5 }

(** [at level p] is [p] grouped if its operator binds more loosely than [level]:
    in braces if it ends with a repetition, and in parentheses otherwise. *)
let at level p =
  if p.level >= level then p.text
  else if String.ends_with ~suffix:"*" p.text then "{" ^ p.text ^ "}"
  else "(" ^ p.text ^ ")"

let alternatives = function
  | [ item ] -> atom item
  | items -> { text = String.concat " | " items; level = 0 }

let print_letters (p : Letters.t) =
  let ticks tick = if tick then [ "1" ] else [] in
  match p.names with
  | Only names -> alternatives (ticks p.tick @ names)
  | Except [] when p.tick -> atom "_"
  | Except names ->
      let excluded = alternatives (ticks (not p.tick) @ names) in
      { text = "_ & ~" ^ at 3 excluded; level = 1 }

let rec print = function
  | Empty -> { text = "~_*"; level = 3 }
  | Eps -> atom "0"
  | Letters p -> print_letters p
  | Seq rs -> print_seq rs
  | Union rs -> nary " | " 0 rs
  | Inter rs -> nary " & " 1 rs
  | Compl r -> { text = "~" ^ at 3 (print r); level = 3 }
  | Star r -> { text = at 4 (print r) ^ "*"; level = 4 }

and nary separator level rs =
  {
    text = String.concat separator (List.map (fun r -> at level (print r)) rs);
    level;
  }

and print_seq rs =
  let part = function
    | Ticks n -> string_of_int n
    | Factor r -> at 3 (print r)
  in
  match group_ticks rs with
  | [ Ticks n ] -> atom (string_of_int n)
  | parts -> { text = String.concat "; " (List.map part parts); level = 2 }

let to_string r = (print r).text
