type cost = No_run | Cost of int | Unbounded

(** [add c c'] is the cost of [c] followed by [c']; [No_run] is absorbing, and
    then [Unbounded]. *)
let add c c' =
  match (c, c') with
  | No_run, _ | _, No_run -> No_run
  | Unbounded, _ | _, Unbounded -> Unbounded
  | Cost n, Cost n' -> Cost (n + n')

let rank = function No_run -> 0 | Cost _ -> 1 | Unbounded -> 2

let compare_cost c c' =
  match (c, c') with
  | Cost n, Cost n' -> Int.compare n n'
  | _ -> Int.compare (rank c) (rank c')

let leq_cost c c' = compare_cost c c' <= 0
let max_cost c c' = if leq_cost c c' then c' else c
let maximum = List.fold_left max_cost No_run

let show_cost = function
  | No_run -> "⊥"
  | Cost n -> string_of_int n
  | Unbounded -> "∞"

(** The absorbing mode, in which a run is stuck. *)
let stuck = "Stuck"

(* The costs between the modes named, from a mode named to the others, from
   the others to a mode named, keeping a mode not named, between two modes not
   named, and into [stuck] from a mode named and from the others; [No_run]
   entries are omitted. *)
type t = {
  modes : string list;
  within : ((string * string) * cost) list;
  leaving : (string * cost) list;
  entering : (string * cost) list;
  staying : cost;
  moving : cost;
  to_stuck : (string * cost) list;
  other_to_stuck : cost;
}

(* The names standing for modes that no grade at hand names; the modes of the
   literals are capitalised, so that these differ from them. *)
let other = "_x"
let another = "_y"
let yet_another = "_z"

(** [cost m p q] is the cost of the runs from the mode [p] to the mode [q]. *)
let cost m p q =
  let named p = List.mem p m.modes in
  let find key entries =
    Option.value (List.assoc_opt key entries) ~default:No_run
  in
  if String.equal p stuck then if String.equal q stuck then Cost 0 else No_run
  else if String.equal q stuck then
    if named p then find p m.to_stuck else m.other_to_stuck
  else
    match (named p, named q) with
    | true, true -> find (p, q) m.within
    | true, false -> find p m.leaving
    | false, true -> find q m.entering
    | false, false -> if String.equal p q then m.staying else m.moving

(* A mode whose costs are those of the modes not named is dropped. *)
let trim m =
  let alike q =
    List.for_all
      (fun p ->
        String.equal p q
        || compare_cost (cost m p q) (cost m p other) = 0
           && compare_cost (cost m q p) (cost m other p) = 0)
      m.modes
    && compare_cost (cost m q q) m.staying = 0
    && compare_cost (cost m q other) m.moving = 0
    && compare_cost (cost m other q) m.moving = 0
    && compare_cost (cost m q stuck) m.other_to_stuck = 0
  in
  let modes = List.filter (fun q -> not (alike q)) m.modes in
  let keep (p, q) = List.mem p modes && List.mem q modes in
  {
    m with
    modes;
    within = List.filter (fun (key, _) -> keep key) m.within;
    leaving = List.filter (fun (p, _) -> List.mem p modes) m.leaving;
    entering = List.filter (fun (q, _) -> List.mem q modes) m.entering;
    to_stuck = List.filter (fun (p, _) -> List.mem p modes) m.to_stuck;
  }

(** [make modes f] is the grade over the ordinary modes [modes] whose cost from
    [p] to [q] is [f p q], [f] treating alike the modes not among [modes]. *)
let make modes f =
  let modes = List.sort_uniq String.compare modes in
  let costs pairs =
    List.filter_map
      (fun (key, c) -> if c = No_run then None else Some (key, c))
      pairs
  in
  trim
    {
      modes;
      within =
        costs
          (List.concat_map
             (fun p -> List.map (fun q -> ((p, q), f p q)) modes)
             modes);
      leaving = costs (List.map (fun p -> (p, f p other)) modes);
      entering = costs (List.map (fun q -> (q, f other q)) modes);
      staying = f other other;
      moving = f other another;
      to_stuck = costs (List.map (fun p -> (p, f p stuck)) modes);
      other_to_stuck = f other stuck;
    }

(* The modes of [m] and [m'], and pairs of modes covering every case of
   theirs: pairs of those modes or of one mode not named, one pair of two
   distinct modes not named, and each of these modes paired with [stuck]. *)
let modes_of m m' = List.sort_uniq String.compare (m.modes @ m'.modes)

let cases modes =
  let with_other = modes @ [ other ] in
  (other, another)
  :: List.concat_map
       (fun p -> (p, stuck) :: List.map (fun q -> (p, q)) with_other)
       with_other

let everywhere c =
  {
    modes = [];
    within = [];
    leaving = [];
    entering = [];
    staying = c;
    moving = No_run;
    to_stuck = [];
    other_to_stuck = No_run;
  }

let one = everywhere (Cost 0)

let top =
  { (everywhere Unbounded) with moving = Unbounded; other_to_stuck = Unbounded }

(* The max-plus matrix product. A run from [p] to [r] passes through a mode
   named, [p], [r], [stuck] or another mode, the modes not named all alike. *)
let mul m m' =
  let modes = modes_of m m' in
  make modes (fun p r ->
      let fresh =
        List.find
          (fun q -> not (String.equal q p || String.equal q r))
          [ other; another; yet_another ]
      in
      maximum
        (List.map
           (fun q -> add (cost m p q) (cost m' q r))
           (fresh :: p :: r :: stuck :: modes)))

let join m m' =
  make (modes_of m m') (fun p q -> max_cost (cost m p q) (cost m' p q))

let leq m m' =
  List.for_all
    (fun (p, q) -> leq_cost (cost m p q) (cost m' p q))
    (cases (modes_of m m'))

let equal m m' = leq m m' && leq m' m

(* The representations are canonical, trimmed of the modes alike to those not
   named, so that they are equal iff the grades are. *)
let fields m =
  ( m.modes,
    m.within,
    m.leaving,
    m.entering,
    m.staying,
    m.moving,
    m.to_stuck,
    m.other_to_stuck )

let compare m m' = Stdlib.compare (fields m) (fields m')
let hash m = Hashtbl.hash (fields m)

(** [cost_of_lit lit] is the cost the literal [lit] denotes. *)
let cost_of_lit = function
  | Grade.Int n when n < 0 ->
      Grade.invalid_lit (Grade.Int n) "costs must be non-negative"
  | Grade.Int n -> Cost n
  | Grade.Inf -> Unbounded
  | lit ->
      Grade.invalid_lit lit "costs are plain integers or '∞', not %s"
        (Grade.describe_lit lit)

(* The names of the literals standing for a mode not named, and for a mode
   not named other than the one an entry of [unnamed] starts from. *)
let unnamed = "_"
let unnamed_other = "≠"

(** [entry lit] is the entry [(From, To, cost)] the literal [lit] denotes, of
    modes named, [stuck], [unnamed] or, as its target after [unnamed],
    [unnamed_other]: no run leaves [stuck], and a change between two ordinary
    modes costs at least [1]. *)
let entry = function
  | Grade.Tuple [ Grade.Name p; Grade.Name q; c ] as lit ->
      let c =
        Grade.component_of_lit lit
          ~context:(Printf.sprintf "in the cost from '%s' to '%s', " p q)
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
        Grade.invalid_lit lit "only an entry from '%s' ends in '%s'" unnamed
          unnamed_other
      else if String.equal p stuck && not (String.equal q stuck && c = Cost 0)
      then
        Grade.invalid_lit lit
          "no run leaves the mode '%s', which it keeps at cost 0" stuck
      else if change && c = Cost 0 then
        Grade.invalid_lit lit
          "in the cost from '%s' to '%s', a change of mode costs at least 1" p q
      else ((p, q), c)
  | lit ->
      Grade.invalid_lit lit
        "entries are triples '(From, To, n)' of two modes and a cost, not %s"
        (Grade.describe_lit lit)

(** [of_entries lit entries] is the grade whose runs are those of [entries],
    each pair of modes listed once in the literal [lit]; a run from a mode that
    [entries] do not start from, the modes not named starting from [unnamed], is
    stuck at cost [0]. *)
let of_entries lit entries =
  let sorted = List.sort (fun (k, _) (k', _) -> Stdlib.compare k k') entries in
  let rec check = function
    | ((p, q), _) :: ((key', _) :: _ as rest) ->
        if (p, q) = key' then
          Grade.invalid_lit lit "the modes '%s' to '%s' are listed twice" p q
        else check rest
    | [ _ ] | [] -> ()
  in
  check sorted;
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
          else No_run)

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
        "grades are costs 'n', entries '(From, To, n)' of two modes and a \
         cost, or tuples of entries, not %s"
        (Grade.describe_lit lit)

(* The entry into [stuck] of a mode from which it is the only run, at cost
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
      m.entering <> [] || m.staying <> No_run || m.moving <> No_run
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
      @ (if m.staying = No_run then [] else [ entry unnamed unnamed m.staying ])
      @ (if m.moving = No_run then []
         else [ entry unnamed unnamed_other m.moving ])
      @
      if
        m.other_to_stuck = No_run
        || not (explicit others_start m.other_to_stuck)
      then []
      else [ entry unnamed stuck m.other_to_stuck ]
    in
    match (m.modes, m.moving, m.other_to_stuck, entries) with
    | [], No_run, No_run, _ -> show_cost m.staying
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
  let commutative = false
  let needs_op_bounds = false
  let implied_bounds _bounds _ = None
  let inhabited _bounds _ = true
  let events _ = []
  let of_lit = of_lit
  let of_bounds _ = one
  let is_atomic _name _ = true
  let show = show
  let witnesses ~degree:_ _bounds = Grade.sampled mul
end

module ModeSwitchCosts = Make (Delay.Nat)
