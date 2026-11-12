module I = DurationIntervals

module type SUMMARY = sig
  type t
  type op

  val one : t
  val mul : t -> t -> t
  val join : t -> t -> t
  val top : t
  val delays : I.t -> t
  val occurrence : string -> op -> Grade.running_time -> t
  val leq : t -> t -> bool
  val compare : t -> t -> int
  val hash : t -> int
  val compare_op : op -> op -> int
  val hash_op : op -> int
  val duration : t -> I.t option
  val vacuous : Grade.bounds -> t -> string option
  val events : t -> string list
  val counterexample : t -> t -> t option
  val closure : (t -> t) option
end

module Make (S : SUMMARY) = struct
  type t = { node : node; hash : int }

  and node =
    | Op of string * S.op
    | Delays of I.t
    | Fixed of S.t
    | Mul of t list
    | Join of t list
    | Plus of t

  let view c = c.node

  let hash_node = function
    | Op (name, op) -> Hashing.combine (Hashtbl.hash name) (S.hash_op op)
    | Delays i -> Hashing.combine 1 (I.hash i)
    | Fixed s -> Hashing.combine 2 (S.hash s)
    | Mul cs -> Hashing.combine 3 (Hashing.list (fun c -> c.hash) cs)
    | Join cs -> Hashing.combine 4 (Hashing.list (fun c -> c.hash) cs)
    | Plus c -> Hashing.combine 5 c.hash

  let make node = { node; hash = hash_node node }

  let rank = function
    | Op _ -> 0
    | Delays _ -> 1
    | Fixed _ -> 2
    | Mul _ -> 3
    | Join _ -> 4
    | Plus _ -> 5

  let rec compare c d =
    if c == d then 0
    else
      match (c.node, d.node) with
      | Op (name, op), Op (name', op') -> (
          match String.compare name name' with
          | 0 -> S.compare_op op op'
          | k -> k)
      | Delays i, Delays i' -> I.compare i i'
      | Fixed s, Fixed s' -> S.compare s s'
      | Mul cs, Mul cs' | Join cs, Join cs' -> List.compare compare cs cs'
      | Plus c, Plus c' -> compare c c'
      | n, n' -> Int.compare (rank n) (rank n')

  let hash c = c.hash
  let op name op = make (Op (name, op))
  let delays i = make (Delays i)
  let fixed s = make (Fixed s)
  let one = delays I.zero
  let top = fixed S.top
  let of_delay q = delays (I.point q)
  let of_bounds b = delays b
  let is_unit c = match c.node with Delays i -> I.is_zero i | _ -> false

  let is_fixed_top c =
    match c.node with Fixed s -> S.compare s S.top = 0 | _ -> false

  (* The factors of a product: nested products flattened, the unit dropped,
     and adjacent delays summed. *)
  let mul c d =
    let factors c = match c.node with Mul cs -> cs | _ -> [ c ] in
    let push c acc =
      match (c.node, acc) with
      | _, _ when is_unit c -> acc
      | Delays i, { node = Delays j; _ } :: rest -> delays (I.add i j) :: rest
      | _ -> c :: acc
    in
    match List.fold_right push (factors c @ factors d) [] with
    | [] -> one
    | [ c ] -> c
    | cs -> make (Mul cs)

  (* The operands of a join: nested joins flattened, sorted and
     duplicate-free, the top absorbing. *)
  let join c d =
    let operands c = match c.node with Join cs -> cs | _ -> [ c ] in
    if is_fixed_top c || is_fixed_top d then top
    else
      match List.sort_uniq compare (operands c @ operands d) with
      | [ c ] -> c
      | cs -> make (Join cs)

  module Table = Memo.Make (struct
    type nonrec t = t

    let equal c d = compare c d = 0
    let hash = hash
  end)

  (* The table of the evaluations under the latest running-time bounds. *)
  let latest : (Grade.bounds * S.t Table.t) option ref = ref None

  let table bounds =
    match !latest with
    | Some (bounds', table) when bounds' == bounds -> table
    | Some _ | None ->
        let table = Table.create 64 in
        latest := Some (bounds, table);
        table

  (* The summary of the node [n], its subterms evaluated by [go] and its
     occurrences by [occurrence]. *)
  let evaluate_node ~go ~occurrence n =
    match n with
    | Op (name, op) -> occurrence name op
    | Delays i -> S.delays i
    | Fixed s -> s
    | Mul cs -> List.fold_left (fun s c -> S.mul s (go c)) S.one cs
    | Join [] -> invalid_arg "SummaryTerms.evaluate: an empty join"
    | Join (c :: cs) -> List.fold_left (fun s c -> S.join s (go c)) (go c) cs
    | Plus c -> (
        match S.closure with
        | Some closure -> closure (go c)
        | None -> invalid_arg "SummaryTerms.evaluate: no closure declared")

  let evaluate (bounds : Grade.bounds) c =
    let table = table bounds in
    let occurrence name op = S.occurrence name op (bounds.running_time name) in
    let rec go c =
      Table.find_or_add table c (fun () -> evaluate_node ~go ~occurrence c.node)
    in
    go c

  let rec free_of_ops c =
    match c.node with
    | Op _ -> false
    | Delays _ | Fixed _ -> true
    | Mul cs | Join cs -> List.for_all free_of_ops cs
    | Plus c -> free_of_ops c

  (* The summary of a term without occurrences, under any running times. *)
  let rec value c =
    evaluate_node ~go:value
      ~occurrence:(fun name _ ->
        invalid_arg ("SummaryTerms.value: the occurrence of " ^ name))
      c.node

  (* The closure: the unit, the top and a closure are their own closures; a
     term without occurrences closes to the closure of its summary; any other
     term is kept as a closure node, evaluated to the closure of its
     summary. *)
  let plus c =
    Option.map
      (fun closure ->
        match c.node with
        | Plus _ -> c
        | _ when is_unit c || is_fixed_top c -> c
        | _ when free_of_ops c -> fixed (closure (value c))
        | _ -> make (Plus c))
      S.closure

  let leq bounds c d =
    compare c d = 0
    || is_fixed_top d
    || S.leq (evaluate bounds c) (evaluate bounds d)

  let equal bounds c d = leq bounds c d && leq bounds d c
  let is_top bounds c = is_fixed_top c || S.leq S.top (evaluate bounds c)

  let counterexample bounds c d =
    if leq bounds c d then None
    else
      Option.map fixed
        (S.counterexample (evaluate bounds c) (evaluate bounds d))

  let duration_bounds bounds c = S.duration (evaluate bounds c)
  let vacuous bounds c = S.vacuous bounds (evaluate bounds c)
  let inhabited bounds c = Grade.inhabited_of vacuous bounds c

  let events c =
    let rec go acc c =
      match c.node with
      | Op (name, _) -> name :: acc
      | Delays _ -> acc
      | Fixed s -> S.events s @ acc
      | Mul cs | Join cs -> List.fold_left go acc cs
      | Plus c -> go acc c
    in
    List.sort_uniq String.compare (go [] c)

  let is_atomic name c =
    match c.node with Op (name', _) -> String.equal name name' | _ -> false
end
