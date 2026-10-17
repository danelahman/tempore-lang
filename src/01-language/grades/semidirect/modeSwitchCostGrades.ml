type cost = No_trace | Cost of int | Unbounded

(** [add c c'] is the cost of [c] followed by [c']; [No_trace] is absorbing, and
    then [Unbounded]. *)
let add c c' =
  match (c, c') with
  | No_trace, _ | _, No_trace -> No_trace
  | Unbounded, _ | _, Unbounded -> Unbounded
  | Cost n, Cost n' -> Cost (Delay.checked_add ~quantity:"cost" n n')

let rank = function No_trace -> 0 | Cost _ -> 1 | Unbounded -> 2

let compare_cost c c' =
  match (c, c') with
  | Cost n, Cost n' -> Int.compare n n'
  | _ -> Int.compare (rank c) (rank c')

let leq_cost c c' = compare_cost c c' <= 0
let max_cost c c' = if leq_cost c c' then c' else c

(* [compare_tagged c c'] orders the costs by constructor, in the order
   [No_trace], [Unbounded], [Cost], then by value. *)
let compare_tagged c c' =
  let tag = function No_trace -> 0 | Unbounded -> 1 | Cost _ -> 2 in
  match (c, c') with
  | Cost n, Cost n' -> Int.compare n n'
  | _ -> Int.compare (tag c) (tag c')

let show_cost = function
  | No_trace -> "⊥"
  | Cost n -> string_of_int n
  | Unbounded -> "∞"

(** The max-plus semiring of the costs, naming no modes. *)
module Costs = struct
  type t = cost

  let zero = No_trace
  let one = Cost 0
  let is_zero c = c = No_trace
  let mul = add
  let add = max_cost
  let leq = leq_cost
  let equal c c' = compare_cost c c' = 0
  let compare = compare_tagged

  let hash = function
    | No_trace -> 0
    | Unbounded -> 1
    | Cost n -> Hashing.combine 2 n

  let rename _ c = c
  let project _ c = c
end

module Matrices = ModeMatrices.Make (Costs)
include Matrices

let stuck = ModeMatrices.stuck

let everywhere c =
  {
    modes = [];
    within = [];
    leaving = [];
    entering = [];
    staying = c;
    moving = No_trace;
    to_stuck = [];
    other_to_stuck = No_trace;
  }

let one = everywhere (Cost 0)

let top =
  { (everywhere Unbounded) with moving = Unbounded; other_to_stuck = Unbounded }

(** [cost_of_lit lit] is the cost the literal [lit] denotes. *)
let cost_of_lit = function
  | Grade.Int n when n < 0 ->
      Grade.invalid_lit (Grade.Int n) "costs must be non-negative"
  | Grade.Int n -> Cost n
  | Grade.Inf -> Unbounded
  | lit ->
      Grade.invalid_lit lit "costs are plain integers or `∞`, not %s"
        (Grade.describe_lit lit)

(* The names of the literals standing for a mode not named, and for a mode
   not named other than the one an entry of [unnamed] starts from. *)
let unnamed = "_"
let unnamed_other = "≠"

(** [entry lit] is the entry [(From, To, cost)] the literal [lit] denotes, of
    modes named, [stuck], [unnamed] or, as its target after [unnamed],
    [unnamed_other]: no trace leaves [stuck], and a change between two ordinary
    modes costs at least [1]. *)
let entry = function
  | Grade.Tuple [ Grade.Name p; Grade.Name q; c ] as lit ->
      let c =
        Grade.component_of_lit lit
          ~context:(Printf.sprintf "in the cost from `%s` to `%s`, " p q)
          cost_of_lit c
      in
      let change =
        match (p, q) with
        | _, q when String.equal q stuck -> false
        | p, q -> not (String.equal p q)
      in
      if
        String.equal p unnamed_other
        || (String.equal q unnamed_other && not (String.equal p unnamed))
      then
        Grade.invalid_lit lit "only an entry from `%s` ends in `%s`" unnamed
          unnamed_other
      else if String.equal p stuck && not (String.equal q stuck && c = Cost 0)
      then
        Grade.invalid_lit lit
          "no trace leaves the mode `%s`, which it keeps at cost 0" stuck
      else if change && c = Cost 0 then
        Grade.invalid_lit lit
          "in the cost from `%s` to `%s`, a change of mode costs at least 1" p q
      else ((p, q), c)
  | lit ->
      Grade.invalid_lit lit
        "entries are triples `(From, To, n)` of two modes and a cost, not %s"
        (Grade.describe_lit lit)

(** [of_entries lit entries] is the grade whose traces are those of [entries],
    each pair of modes listed once in the literal [lit]; a trace from a mode
    that [entries] do not start from, the modes not named starting from
    [unnamed], is stuck at cost [0]. *)
let of_entries lit entries =
  ignore
    (Grade.distinct_entries lit ~compare:Stdlib.compare
       ~twice:(fun (p, q) ->
         Printf.sprintf "the modes `%s` to `%s` are listed twice" p q)
       entries);
  let modes =
    List.filter
      (fun p -> not (List.mem p [ stuck; unnamed; unnamed_other ]))
      (List.concat_map (fun ((p, q), _) -> [ p; q ]) entries)
  in
  let starts p = List.exists (fun ((p', _), _) -> String.equal p p') entries in
  let name p = if List.mem p modes then p else unnamed in
  make modes (fun p q ->
      let key =
        match (List.mem p modes, List.mem q modes) with
        | false, false when String.equal q stuck -> (unnamed, stuck)
        | false, false when String.equal p q -> (unnamed, unnamed)
        | false, false -> (unnamed, unnamed_other)
        | _ -> (name p, if String.equal q stuck then stuck else name q)
      in
      match List.assoc_opt key entries with
      | Some c -> c
      | None ->
          if String.equal q stuck && not (starts (fst key)) then Cost 0
          else No_trace)

let is_entry = function
  | Grade.Tuple [ Grade.Name _; Grade.Name _; _ ] -> true
  | _ -> false

let of_lit = function
  | Grade.Top -> top
  | (Grade.Int _ | Grade.Inf) as lit -> everywhere (cost_of_lit lit)
  | lit when is_entry lit -> of_entries lit [ entry lit ]
  | Grade.Tuple (first :: _ as lits) as lit when is_entry first ->
      of_entries lit
        (List.map (Grade.component_of_lit lit ~context:"" entry) lits)
  | lit ->
      Grade.invalid_lit lit
        "grades are costs `n`, entries `(From, To, n)` of two modes and a \
         cost, or tuples of entries, not %s"
        (Grade.describe_lit lit)

(* The entry into [stuck] of a mode from which it is the only trace, at cost
   [0], is left implicit where another entry names the mode, and the grade
   stuck at cost [0] from every mode is printed [(Stuck, Stuck, 0)]. *)
let show m =
  if equal m top then "⊤"
  else
    let entry p q c = "(" ^ p ^ ", " ^ q ^ ", " ^ show_cost c ^ ")" in
    let starts p =
      List.exists (fun ((p', _), _) -> String.equal p p') m.within
      || List.mem_assoc p m.leaving
    in
    let named_elsewhere p =
      List.exists (fun ((_, q), _) -> String.equal p q) m.within
      || List.mem_assoc p m.entering
    in
    let others_start =
      m.entering <> [] || m.staying <> No_trace || m.moving <> No_trace
    in
    let explicit start c = start || c <> Cost 0 in
    let named =
      List.sort
        (fun (k, _) (k', _) -> Stdlib.compare k k')
        (m.within
        @ List.filter_map
            (fun (p, c) ->
              if explicit (starts p || not (named_elsewhere p)) c then
                Some ((p, stuck), c)
              else None)
            m.to_stuck)
    in
    let entries =
      List.map (fun ((p, q), c) -> entry p q c) named
      @ List.map (fun (p, c) -> entry p unnamed c) m.leaving
      @ List.map (fun (q, c) -> entry unnamed q c) m.entering
      @ (if m.staying = No_trace then []
         else [ entry unnamed unnamed m.staying ])
      @ (if m.moving = No_trace then []
         else [ entry unnamed unnamed_other m.moving ])
      @
      if
        m.other_to_stuck = No_trace
        || not (explicit others_start m.other_to_stuck)
      then []
      else [ entry unnamed stuck m.other_to_stuck ]
    in
    match (m.modes, m.moving, m.other_to_stuck, entries) with
    | [], No_trace, No_trace, _ -> show_cost m.staying
    | _, _, _, [] -> entry stuck stuck (Cost 0)
    | _, _, _, [ e ] -> e
    | _ -> "(" ^ String.concat ", " entries ^ ")"

let is_top m = equal top m

module Make (D : Delay.S) = struct
  type nonrec t = t

  module Delay = D

  let name = "mode-switch-costs"
  let one = one
  let mul = mul
  let leq _bounds = leq
  let leq_symbol = "<="
  let top = top
  let join = join
  let of_delay _ = one
  let equal _bounds = equal
  let is_top _bounds = is_top
  let compare = compare
  let hash = hash
  let counterexample _bounds _ _ = None
  let unit_least = false
  let plus _ = None
  let commutative = false
  let needs_op_bounds = false
  let duration_bounds _bounds _ = None
  let inhabited _bounds _ = true
  let events _ = []
  let of_lit = of_lit
  let accepts = Grade.reads_lit of_lit
  let of_bounds _ = one
  let is_atomic _name _ = true
  let show = show
  let witnesses ~degree:_ _bounds = Grade.sampled mul
end

module ModeSwitchCosts = Make (Delay.Nat)
