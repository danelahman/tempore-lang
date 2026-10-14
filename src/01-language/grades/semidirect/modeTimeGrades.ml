(* ------------------------------------------------------------------ *)
(* Intervals of times                                                  *)
(* ------------------------------------------------------------------ *)

type interval = { lo : Rational.t; hi : Rational.t option }

let point d = { lo = d; hi = Some d }
let nothing = point Rational.zero
let anything = { lo = Rational.zero; hi = None }

let sum i i' =
  {
    lo = Rational.add i.lo i'.lo;
    hi =
      (match (i.hi, i'.hi) with
      | Some h, Some h' -> Some (Rational.add h h')
      | _ -> None);
  }

let hull i i' =
  {
    lo = (if Rational.compare i.lo i'.lo <= 0 then i.lo else i'.lo);
    hi =
      (match (i.hi, i'.hi) with
      | Some h, Some h' -> Some (if Rational.compare h h' >= 0 then h else h')
      | _ -> None);
  }

(* [below h h'] is whether the upper end [h] is at most [h'], [None] being
   infinite. *)
let below h h' =
  match (h, h') with
  | _, None -> true
  | None, Some _ -> false
  | Some h, Some h' -> Rational.compare h h' <= 0

let included i i' = Rational.compare i'.lo i.lo <= 0 && below i.hi i'.hi

let compare_interval i i' =
  match Rational.compare i.lo i'.lo with
  | 0 -> (
      match (i.hi, i'.hi) with
      | Some h, Some h' -> Rational.compare h h'
      | None, None -> 0
      | None, Some _ -> 1
      | Some _, None -> -1)
  | c -> c

let equal_interval i i' = compare_interval i i' = 0

let hash_interval i =
  Hashing.combine (Rational.hash i.lo)
    (match i.hi with Some h -> Rational.hash h | None -> -1)

(* [cap h i] is [i] with its upper end at most [h]. *)
let cap h i = if below i.hi h then i else { i with hi = h }

let show_interval i =
  match i.hi with
  | Some h when Rational.equal h i.lo -> Rational.show h
  | Some h -> "[" ^ Rational.show i.lo ^ ", " ^ Rational.show h ^ "]"
  | None -> "[" ^ Rational.show i.lo ^ ", ∞)"

(* ------------------------------------------------------------------ *)
(* Entries: the times of the traces between two modes                  *)
(* ------------------------------------------------------------------ *)

(* The entries of the matrices: no trace, or an interval of the time spent in
    each mode and of the total time of the traces, the semiring of the interval
    vectors with the hull as its sum and the componentwise sum as its product.
    A summary names some modes; the others are bounded by [rest]. *)
module Times = struct
  type summary = {
    times : (string * interval) list;
    rest : interval;
    total : interval;
  }

  type t = No_trace | Traces of summary

  let zero = No_trace
  let one = Traces { times = []; rest = nothing; total = nothing }
  let is_zero = function No_trace -> true | Traces _ -> false
  let time s p = Option.value (List.assoc_opt p s.times) ~default:s.rest

  let keys s s' =
    List.sort_uniq String.compare (List.map fst s.times @ List.map fst s'.times)

  let pointwise f s s' =
    {
      times = List.map (fun p -> (p, f (time s p) (time s' p))) (keys s s');
      rest = f s.rest s'.rest;
      total = f s.total s'.total;
    }

  let add e e' =
    match (e, e') with
    | No_trace, e | e, No_trace -> e
    | Traces s, Traces s' -> Traces (pointwise hull s s')

  let mul e e' =
    match (e, e') with
    | No_trace, _ | _, No_trace -> No_trace
    | Traces s, Traces s' -> Traces (pointwise sum s s')

  let leq e e' =
    match (e, e') with
    | No_trace, _ -> true
    | Traces _, No_trace -> false
    | Traces s, Traces s' ->
        included s.total s'.total && included s.rest s'.rest
        && List.for_all (fun p -> included (time s p) (time s' p)) (keys s s')

  let equal e e' = leq e e' && leq e' e

  let compare e e' =
    match (e, e') with
    | No_trace, No_trace -> 0
    | No_trace, Traces _ -> -1
    | Traces _, No_trace -> 1
    | Traces s, Traces s' -> (
        let time (p, i) (p', i') =
          match String.compare p p' with 0 -> compare_interval i i' | c -> c
        in
        match List.compare time s.times s'.times with
        | 0 -> (
            match compare_interval s.rest s'.rest with
            | 0 -> compare_interval s.total s'.total
            | c -> c)
        | c -> c)

  let hash = function
    | No_trace -> 0
    | Traces s ->
        List.fold_left Hashing.combine
          (Hashing.list
             (fun (p, i) -> Hashing.combine (String.hash p) (hash_interval i))
             s.times)
          [ hash_interval s.rest; hash_interval s.total ]

  let rename f = function
    | No_trace -> No_trace
    | Traces s ->
        Traces
          {
            s with
            times =
              List.sort
                (fun (p, _) (q, _) -> String.compare p q)
                (List.map (fun (p, i) -> (f p, i)) s.times);
          }

  (* A mode named besides [modes] is one of the modes not named, each bounded
     by the hull of its time and [rest]. *)
  let project modes = function
    | No_trace -> No_trace
    | Traces s ->
        let modes = List.sort_uniq String.compare modes in
        Traces
          {
            s with
            times = List.map (fun p -> (p, time s p)) modes;
            rest =
              List.fold_left
                (fun r (p, i) -> if List.mem p modes then r else hull r i)
                s.rest s.times;
          }
end

(* ------------------------------------------------------------------ *)
(* Summaries: matrices of the times between the modes                  *)
(* ------------------------------------------------------------------ *)

module Matrices = ModeMatrices.Make (Times)

let stuck = ModeMatrices.stuck

(* The names of the literals standing for a mode not named, and for a mode not
   named other than the one an entry of [unnamed] starts from. *)
let unnamed = "_"
let unnamed_other = "≠"

(* [key modes p q] is the pair of the literal names of the entries over the
   modes named [modes] that gives the traces from [p] to [q]. *)
let key modes p q =
  let name p = if List.mem p modes then p else unnamed in
  match (List.mem p modes, List.mem q modes) with
  | false, false when String.equal q stuck -> (unnamed, stuck)
  | false, false when String.equal p q -> (unnamed, unnamed)
  | false, false -> (unnamed, unnamed_other)
  | _ -> (name p, if String.equal q stuck then stuck else name q)

(* [tabulate modes entries summary] is the matrix over the modes named [modes]
   of the entries [entries], keyed by pairs of literal names, the entry of [a]
   from [p] to [q] being [summary a p q]; a mode from which no entry starts is
   stuck at no time. *)
let tabulate modes entries summary =
  let starts p = List.exists (fun ((p', _), _) -> String.equal p p') entries in
  Matrices.make modes (fun p q ->
      let ((from, _) as k) = key modes p q in
      match List.assoc_opt k entries with
      | Some a -> summary a p q
      | None ->
          if String.equal q stuck && not (starts from) then Times.one
          else Times.zero)

(* [own modes p q] is the modes among [p] and [q] not named by [modes] nor
   [stuck], the representatives that the entries from [p] to [q] name. *)
let own modes p q =
  List.filter
    (fun r -> not (String.equal r stuck || List.mem r modes))
    (List.sort_uniq String.compare [ p; q ])

(* The algebra of the summaries of the terms: the matrices, with the delays,
   the occurrences of operations and the durations. *)
module Summary = struct
  type t = Matrices.t

  (* The behaviour of an operation: the pairs of literal names of the modes it
     takes, sorted. *)
  type op = (string * string) list

  let compare_op = Stdlib.compare

  let hash_op =
    Hashing.list (fun (p, q) -> Hashing.combine (String.hash p) (String.hash q))

  let one =
    Matrices.make [] (fun p q ->
        if String.equal p q then Times.one else Times.zero)

  let mul = Matrices.mul
  let join = Matrices.join
  let leq = Matrices.leq
  let equal = Matrices.equal
  let compare = Matrices.compare
  let hash = Matrices.hash

  let top =
    Matrices.make [] (fun _ _ ->
        Times.Traces { times = []; rest = anything; total = anything })

  let delays i =
    Matrices.make [] (fun p q ->
        if String.equal p q then
          Times.Traces { times = [ (p, i) ]; rest = nothing; total = i }
        else Times.zero)

  let behaviour_modes behaviour =
    List.filter
      (fun p -> not (List.mem p [ stuck; unnamed; unnamed_other ]))
      (List.concat_map (fun (p, q) -> [ p; q ]) behaviour)

  (* The running time of an operation is the closed hull of its running-time
     bounds. *)
  let occurrence _name behaviour bounds =
    let lo, hi = Grade.hull bounds in
    let running_time = { lo; hi = Some hi } in
    tabulate
      (behaviour_modes behaviour)
      (List.map (fun pair -> (pair, ())) behaviour)
      (fun () p q ->
        if String.equal q stuck then Times.one
        else
          Times.Traces
            {
              times = [ (p, running_time) ];
              rest = nothing;
              total = running_time;
            })

  let times m p q =
    match Matrices.entry m p q with
    | Times.No_trace -> None
    | Times.Traces s -> Some (Times.time s, s.total)

  let duration (m : t) =
    let totals =
      List.filter_map
        (function
          | Times.Traces s -> Some s.Times.total | Times.No_trace -> None)
        (List.map snd m.within @ List.map snd m.leaving
       @ List.map snd m.entering @ [ m.staying; m.moving ])
    in
    match totals with [] -> None | i :: is -> Some (List.fold_left hull i is)

  let inhabited _ = true
  let events _ = []
  let counterexample _ _ = None
end

(* ------------------------------------------------------------------ *)
(* Specifications                                                      *)
(* ------------------------------------------------------------------ *)

(* The bounds of an entry of a specification: of the time in modes named, in
   each mode not named, and of the total time, each unconstrained if absent. *)
type bounds = {
  named : (string * interval) list;
  others : interval option;
  total : interval option;
}

(* [specification entries] is the matrix of the entries [entries] of a
   specification, keyed by pairs of literal names: each mode not listed in the
   bounds of an entry is unconstrained, and no time in a mode exceeds the total
   time. *)
let specification entries =
  let modes =
    List.filter
      (fun p -> not (List.mem p [ stuck; unnamed; unnamed_other ]))
      (List.concat_map
         (fun ((p, q), b) -> p :: q :: List.map fst b.named)
         entries)
  in
  let modes = List.sort_uniq String.compare modes in
  tabulate modes entries (fun b p q ->
      let total = Option.value b.total ~default:anything in
      let bounded i = cap total.hi (Option.value i ~default:anything) in
      let rest = bounded b.others in
      Times.Traces
        {
          times =
            List.map (fun m -> (m, bounded (List.assoc_opt m b.named))) modes
            @ List.map (fun r -> (r, rest)) (own modes p q);
          rest;
          total;
        })

(* [show_specification m] prints the matrix [m] of a specification. The entry
   into [stuck] at no time of a mode from which it is the only trace is left
   implicit where another entry names the mode, and the matrix stuck at no time
   from every mode is printed [(Stuck, Stuck)]. *)
let show_specification (m : Matrices.t) =
  (* The bounds of the modes named that differ from the total time. *)
  let bounded = function
    | Times.No_trace -> []
    | Times.Traces s ->
        let default = cap s.total.hi anything in
        List.filter
          (fun (r, i) -> List.mem r m.modes && not (equal_interval i default))
          s.times
  in
  let entry p q e =
    let bounds =
      match e with
      | Times.No_trace -> []
      | Times.Traces s ->
          let bound (name, i) = "(" ^ name ^ ", " ^ show_interval i ^ ")" in
          List.map bound (bounded e)
          @ (if equal_interval s.rest (cap s.total.hi anything) then []
             else [ bound (unnamed, s.rest) ])
          @
          if equal_interval s.total anything then []
          else [ show_interval s.total ]
    in
    "(" ^ String.concat ", " (p :: q :: bounds) ^ ")"
  in
  let all_entries =
    List.map snd m.within @ List.map snd m.leaving @ List.map snd m.entering
    @ List.map snd m.to_stuck
    @ [ m.staying; m.moving; m.other_to_stuck ]
  in
  let starts p =
    List.exists (fun ((p', _), _) -> String.equal p p') m.within
    || List.mem_assoc p m.leaving
  in
  let named_elsewhere p =
    List.exists (fun ((_, q), _) -> String.equal p q) m.within
    || List.mem_assoc p m.entering
    || List.exists (fun e -> List.mem_assoc p (bounded e)) all_entries
  in
  let others_start =
    m.entering <> []
    || (not (Times.is_zero m.staying))
    || not (Times.is_zero m.moving)
  in
  let explicit start e = start || not (Times.equal e Times.one) in
  let named =
    List.sort
      (fun (k, _) (k', _) -> Stdlib.compare k k')
      (m.within
      @ List.filter_map
          (fun (p, e) ->
            if explicit (starts p || not (named_elsewhere p)) e then
              Some ((p, stuck), e)
            else None)
          m.to_stuck)
  in
  let entries =
    List.map (fun ((p, q), e) -> entry p q e) named
    @ List.map (fun (p, e) -> entry p unnamed e) m.leaving
    @ List.map (fun (q, e) -> entry unnamed q e) m.entering
    @ (if Times.is_zero m.staying then []
       else [ entry unnamed unnamed m.staying ])
    @ (if Times.is_zero m.moving then []
       else [ entry unnamed unnamed_other m.moving ])
    @
    if
      Times.is_zero m.other_to_stuck
      || not (explicit others_start m.other_to_stuck)
    then []
    else [ entry unnamed stuck m.other_to_stuck ]
  in
  match entries with
  | [] -> "(" ^ stuck ^ ", " ^ stuck ^ ")"
  | [ e ] -> e
  | _ -> "(" ^ String.concat ", " entries ^ ")"

(* ------------------------------------------------------------------ *)
(* Literals                                                            *)
(* ------------------------------------------------------------------ *)

let number = function
  | Grade.Int n -> Some (Rational.of_int n)
  | Grade.Rat q -> Some q
  | _ -> None

(* [interval_of_lit lit] is the interval of times the literal [lit] denotes: a
    number [d], the interval [[d, d]], or a closed interval [[lo, hi]] or
    [[lo, ∞)] of non-negative numbers. *)
let interval_of_lit lit =
  let non_negative q =
    if Rational.sign q < 0 then
      Grade.invalid_lit lit "times must be non-negative"
    else q
  in
  match lit with
  | (Grade.Int _ | Grade.Rat _) as n ->
      point (non_negative (Option.get (number n)))
  | Grade.Interval (Grade.Closed lo, hi) -> (
      match (number lo, hi) with
      | Some lo, Grade.Unbounded -> { lo = non_negative lo; hi = None }
      | Some lo, Grade.Closed hi -> (
          match number hi with
          | Some hi when Rational.compare lo hi <= 0 ->
              { lo = non_negative lo; hi = Some hi }
          | Some _ -> Grade.invalid_lit lit "intervals `[lo, hi]` need lo <= hi"
          | None ->
              Grade.invalid_lit lit "the endpoints of intervals are numbers")
      | None, _ ->
          Grade.invalid_lit lit "the endpoints of intervals are numbers"
      | Some _, Grade.Open _ ->
          Grade.invalid_lit lit
            "intervals of times are closed, `[lo, hi]` or `[lo, ∞)`")
  | Grade.Interval _ ->
      Grade.invalid_lit lit
        "intervals of times are closed, `[lo, hi]` or `[lo, ∞)`"
  | lit ->
      Grade.invalid_lit lit
        "times are numbers or intervals `[lo, hi]` or `[lo, ∞)`, not %s"
        (Grade.describe_lit lit)

(* [pair lit (p, q)] is the pair of literal names [(p, q)] of an entry from [p]
    to [q], of modes named, [stuck], [unnamed] or, as its target after
    [unnamed], [unnamed_other], checked in the literal [lit]. *)
let pair lit (p, q) =
  if
    String.equal p unnamed_other
    || (String.equal q unnamed_other && not (String.equal p unnamed))
  then
    Grade.invalid_lit lit "only an entry from `%s` ends in `%s`" unnamed
      unnamed_other
  else (p, q)

let is_change (p, q) = not (String.equal q stuck || String.equal p q)

(* [distinct lit entries] is [entries], each pair of modes listed once in the
    literal [lit]. *)
let distinct lit entries =
  Grade.distinct_entries lit ~compare:Stdlib.compare
    ~twice:(fun (p, q) ->
      Printf.sprintf "the modes `%s` to `%s` are listed twice" p q)
    entries

(* [behaviour lit pairs] is the behaviour of an operation, the pairs of modes
    [pairs] it takes, checked in the literal [lit]: no pair leaves [stuck] but
    [(Stuck, Stuck)]. *)
let behaviour lit pairs =
  List.map fst
    (distinct lit
       (List.map
          (fun (p, q) ->
            if String.equal p stuck && not (String.equal q stuck) then
              Grade.invalid_lit lit "no trace leaves the mode `%s`" stuck
            else (pair lit (p, q), ()))
          pairs))

(* [bounds_of_lit lit (p, q) components] is the bounds of the entry from [p] to
    [q] of the literal [lit] with the components [components]: pairs [(M, t)]
    of a mode named or [unnamed] and an interval, and at most one interval of
    the total time. *)
let bounds_of_lit lit (p, q) components =
  let context = Printf.sprintf "in the entry from `%s` to `%s`, " p q in
  let read = Grade.component_of_lit lit ~context interval_of_lit in
  let named, totals =
    List.partition_map
      (function
        | Grade.Tuple [ Grade.Name m; t ] ->
            if String.equal m stuck then
              Grade.invalid_lit lit "%sno time is spent in the mode `%s`"
                context stuck
            else if String.equal m unnamed_other then
              Grade.invalid_lit lit "%sthe time in `%s` is not bounded" context
                unnamed_other
            else Left (m, read t)
        | (Grade.Int _ | Grade.Rat _ | Grade.Interval _) as t -> Right (read t)
        | c ->
            Grade.invalid_lit lit
              "%sthe bounds are pairs `(M, [lo, hi])` of a mode and an \
               interval, or an interval of the total time, not %s"
              context (Grade.describe_lit c))
      components
  in
  let named =
    Grade.distinct_entries lit ~compare:String.compare
      ~twice:(fun m ->
        Printf.sprintf "%sthe time in `%s` is bounded twice" context m)
      named
  in
  let total =
    match totals with
    | [] -> None
    | [ t ] -> Some t
    | _ -> Grade.invalid_lit lit "%sthe total time is bounded twice" context
  in
  let others = List.assoc_opt unnamed named in
  let named = List.filter (fun (m, _) -> not (String.equal m unnamed)) named in
  (match total with
  | Some { hi = Some h; _ } when is_change (p, q) && Rational.sign h = 0 ->
      Grade.invalid_lit lit "%sa change of mode takes a positive time" context
  | Some t -> (
      match
        List.find_opt
          (fun (_, i) -> not (below (Some i.lo) t.hi))
          (named @ Option.fold ~none:[] ~some:(fun i -> [ (unnamed, i) ]) others)
      with
      | Some (m, _) ->
          Grade.invalid_lit lit "%sthe time in `%s` exceeds the total time"
            context m
      | None -> ())
  | None -> ());
  if String.equal p stuck && (named <> [] || others <> None || total <> None)
  then Grade.invalid_lit lit "no time is spent in the mode `%s`" stuck
  else { named; others; total }

(* [spec_entry lit] is the entry [(From, To, bounds...)] of a specification the
    literal [lit] denotes. *)
let spec_entry = function
  | Grade.Tuple (Grade.Name p :: Grade.Name q :: components) as lit ->
      if String.equal p stuck && not (String.equal q stuck) then
        Grade.invalid_lit lit "no trace leaves the mode `%s`" stuck
      else
        let key = pair lit (p, q) in
        (key, bounds_of_lit lit key components)
  | lit ->
      Grade.invalid_lit lit
        "entries of specifications are tuples `(From, To, ...)` of two modes \
         and bounds, not %s"
        (Grade.describe_lit lit)

let is_spec_entry = function
  | Grade.Tuple (Grade.Name _ :: Grade.Name _ :: _) -> true
  | _ -> false

(* [occurrence_of_lit lit] is the name and the behaviour of the operation the
    literal [lit] denotes: [{X}] in every mode, [({X}, From, To)] from [From] to
    [To], or [({X}, (From, To), ...)] taking each pair. *)
let occurrence_of_lit lit =
  let pair_of = function
    | Grade.Tuple [ Grade.Name p; Grade.Name q ] -> Some (p, q)
    | _ -> None
  in
  let modes_of x = function
    | [ Grade.Name p; Grade.Name q ] -> (x, behaviour lit [ (p, q) ])
    | components -> (
        let pairs = List.filter_map pair_of components in
        match pairs with
        | _ :: _ when List.length pairs = List.length components ->
            (x, behaviour lit pairs)
        | _ ->
            Grade.invalid_lit lit
              "the modes of an operation are written `From, To` or as pairs \
               `(From, To), ...`")
  in
  match lit with
  | Grade.Braces (Grade.Letter x) -> (x, [ (unnamed, unnamed) ])
  | Grade.Tuple (Grade.Braces (Grade.Letter x) :: components) ->
      modes_of x components
  | Grade.Braces r | Grade.Tuple (Grade.Braces r :: _) ->
      Grade.invalid_lit lit
        "an operation is written `{X}` of a single operation `X`, not `{%s}`"
        (Grade.show_regex r)
  | lit ->
      Grade.invalid_lit lit
        "operations are written `{X}`, `({X}, From, To)` or `({X}, (From, To), \
         ...)`, not %s"
        (Grade.describe_lit lit)

(* ------------------------------------------------------------------ *)
(* Terms evaluated under the running times                             *)
(* ------------------------------------------------------------------ *)

type term =
  | Delay of interval
  | Specification of Summary.t
  | Occurrence of string * (string * string) list
  | Mul of term * term
  | Join of term * term

let rec compare_term t t' =
  let rank = function
    | Delay _ -> 0
    | Specification _ -> 1
    | Occurrence _ -> 2
    | Mul _ -> 3
    | Join _ -> 4
  in
  match (t, t') with
  | Delay i, Delay i' -> compare_interval i i'
  | Specification m, Specification m' -> Summary.compare m m'
  | Occurrence (x, b), Occurrence (x', b') -> (
      match String.compare x x' with 0 -> Summary.compare_op b b' | c -> c)
  | Mul (a, b), Mul (a', b') | Join (a, b), Join (a', b') -> (
      match compare_term a a' with 0 -> compare_term b b' | c -> c)
  | _ -> Int.compare (rank t) (rank t')

let rec hash_term = function
  | Delay i -> Hashing.combine 0 (hash_interval i)
  | Specification m -> Hashing.combine 1 (Summary.hash m)
  | Occurrence (x, b) ->
      Hashing.combine 2 (Hashing.combine (String.hash x) (Summary.hash_op b))
  | Mul (a, b) ->
      Hashing.combine 3 (Hashing.combine (hash_term a) (hash_term b))
  | Join (a, b) ->
      Hashing.combine 4 (Hashing.combine (hash_term a) (hash_term b))

let rec events = function
  | Delay _ | Specification _ -> []
  | Occurrence (x, _) -> [ x ]
  | Mul (a, b) | Join (a, b) ->
      List.sort_uniq String.compare (events a @ events b)

let rec evaluate_with running_time = function
  | Delay i -> Summary.delays i
  | Specification m -> m
  | Occurrence (x, b) -> Summary.occurrence x b (running_time x)
  | Mul (a, b) ->
      Summary.mul (evaluate_with running_time a) (evaluate_with running_time b)
  | Join (a, b) ->
      Summary.join (evaluate_with running_time a) (evaluate_with running_time b)

(* The evaluations, by the term and the running times of its operations. *)
module Evaluations = Memo.Make (struct
  type t = term * (string * interval) list

  let equal (t, r) (t', r') =
    compare_term t t' = 0
    && List.equal
         (fun (x, i) (x', i') -> String.equal x x' && equal_interval i i')
         r r'

  let hash (t, r) =
    Hashing.combine (hash_term t)
      (Hashing.list
         (fun (x, i) -> Hashing.combine (String.hash x) (hash_interval i))
         r)
end)

let evaluations = Evaluations.create 64

(* The evaluations are recorded by the closed hulls of the running-time bounds
   of the operations, which the summaries read. *)
let evaluate (bounds : Grade.bounds) t =
  let running_times =
    List.map
      (fun x ->
        let lo, hi = Grade.hull (bounds.running_time x) in
        (x, { lo; hi = Some hi }))
      (events t)
  in
  Evaluations.find_or_add evaluations (t, running_times) (fun () ->
      evaluate_with
        (fun x ->
          let i = List.assoc x running_times in
          (Grade.Closed i.lo, Grade.Closed (Option.get i.hi)))
        t)

let one = Delay nothing
let top = Specification Summary.top

let mul t t' =
  match (t, t') with
  | Delay i, Delay i' -> Delay (sum i i')
  | (Delay i, t | t, Delay i) when equal_interval i nothing -> t
  | _ -> Mul (t, t')

let join t t' = if compare_term t t' = 0 then t else Join (t, t')

let of_lit = function
  | Grade.Top -> top
  | (Grade.Int _ | Grade.Rat _ | Grade.Interval _) as lit ->
      Delay (interval_of_lit lit)
  | lit when is_spec_entry lit ->
      Specification (specification [ spec_entry lit ])
  | Grade.Tuple (first :: _ as lits) as lit when is_spec_entry first ->
      Specification
        (specification
           (distinct lit
              (List.map
                 (Grade.component_of_lit lit ~context:"" spec_entry)
                 lits)))
  | (Grade.Braces _ | Grade.Tuple (Grade.Braces _ :: _)) as lit ->
      let x, b = occurrence_of_lit lit in
      Occurrence (x, b)
  | lit ->
      Grade.invalid_lit lit
        "grades are operations `({X}, From, To)`, delays `d` or `[lo, hi]`, \
         specifications `(From, To, (M, [lo, hi]), ..., [lo, hi])` of two \
         modes and bounds of the time in modes and of the total time, or \
         tuples of specifications, not %s"
        (Grade.describe_lit lit)

let show_occurrence x = function
  | [ (p, q) ] when String.equal p unnamed && String.equal q unnamed ->
      "{" ^ x ^ "}"
  | [ (p, q) ] -> "({" ^ x ^ "}, " ^ p ^ ", " ^ q ^ ")"
  | b ->
      "({" ^ x ^ "}, "
      ^ String.concat ", " (List.map (fun (p, q) -> "(" ^ p ^ ", " ^ q ^ ")") b)
      ^ ")"

(* Products bind tighter than joins, and both associate. *)
let rec show_at level = function
  | Delay i -> show_interval i
  | Specification m ->
      if Summary.equal m Summary.top then "⊤" else show_specification m
  | Occurrence (x, b) -> show_occurrence x b
  | Mul (a, b) ->
      let s = show_at 1 a ^ " · " ^ show_at 1 b in
      if level > 1 then "(" ^ s ^ ")" else s
  | Join (a, b) ->
      let s = show_at 0 a ^ " ⊔ " ^ show_at 0 b in
      if level > 0 then "(" ^ s ^ ")" else s

let show = show_at 0

module ModeTimes = struct
  type t = term

  module Delay = Delay.Rational

  let name = "mode-times"
  let one = one
  let mul = mul
  let leq bounds t t' = Summary.leq (evaluate bounds t) (evaluate bounds t')
  let leq_symbol = "<="
  let top = top
  let join = join
  let of_delay d = Delay (point d)
  let equal bounds t t' = Summary.equal (evaluate bounds t) (evaluate bounds t')
  let is_top bounds t = Summary.leq Summary.top (evaluate bounds t)
  let compare = compare_term
  let hash = hash_term
  let counterexample _bounds _ _ = None
  let unit_least = false
  let commutative = false
  let needs_op_bounds = true

  let duration_bounds bounds t =
    Option.map
      (fun i ->
        ( Grade.Closed i.lo,
          match i.hi with Some h -> Grade.Closed h | None -> Grade.Unbounded ))
      (Summary.duration (evaluate bounds t))

  let inhabited _bounds _ = true
  let events = events
  let of_lit = of_lit
  let accepts = Grade.reads_lit of_lit

  let of_bounds b =
    let lo, hi = Grade.hull b in
    Delay { lo; hi = Some hi }

  let is_atomic name = function
    | Occurrence (x, _) -> String.equal x name
    | _ -> false

  let show = show
  let witnesses ~degree:_ _bounds = Grade.sampled mul
end
