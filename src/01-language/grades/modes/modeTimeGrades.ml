module I = DurationIntervals

(* [cap total i] is [i] with its upper end lowered to that of [total], where
   [i] meets [I.upto total]. *)
let cap total i =
  match I.inter i (I.upto total) with
  | Some i -> i
  | None -> invalid_arg "ModeTimeGrades.cap"

(* ------------------------------------------------------------------ *)
(* Entries: the times of the traces between two modes                  *)
(* ------------------------------------------------------------------ *)

(* The entries of the matrices: no trace, or an interval of the time spent in
    each mode and of the total time of the traces, the semiring of the interval
    vectors with the hull as its sum and the componentwise sum as its product.
    A summary names some modes; the others are bounded by [rest]. *)
module Times = struct
  type summary = { times : (string * I.t) list; rest : I.t; total : I.t }
  type t = No_trace | Traces of summary

  let zero = No_trace
  let one = Traces { times = []; rest = I.zero; total = I.zero }
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
    | Traces s, Traces s' -> Traces (pointwise I.hull s s')

  let mul e e' =
    match (e, e') with
    | No_trace, _ | _, No_trace -> No_trace
    | Traces s, Traces s' -> Traces (pointwise I.add s s')

  let leq e e' =
    match (e, e') with
    | No_trace, _ -> true
    | Traces _, No_trace -> false
    | Traces s, Traces s' ->
        I.subset s.total s'.total && I.subset s.rest s'.rest
        && List.for_all (fun p -> I.subset (time s p) (time s' p)) (keys s s')

  let equal e e' = leq e e' && leq e' e

  let compare e e' =
    match (e, e') with
    | No_trace, No_trace -> 0
    | No_trace, Traces _ -> -1
    | Traces _, No_trace -> 1
    | Traces s, Traces s' -> (
        let time (p, i) (p', i') =
          match String.compare p p' with 0 -> I.compare i i' | c -> c
        in
        match List.compare time s.times s'.times with
        | 0 -> (
            match I.compare s.rest s'.rest with
            | 0 -> I.compare s.total s'.total
            | c -> c)
        | c -> c)

  let hash = function
    | No_trace -> 0
    | Traces s ->
        List.fold_left Hashing.combine
          (Hashing.list
             (fun (p, i) -> Hashing.combine (String.hash p) (I.hash i))
             s.times)
          [ I.hash s.rest; I.hash s.total ]

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
                (fun r (p, i) -> if List.mem p modes then r else I.hull r i)
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
        Times.Traces { times = []; rest = I.unbounded; total = I.unbounded })

  let delays i =
    Matrices.make [] (fun p q ->
        if String.equal p q then
          Times.Traces { times = [ (p, i) ]; rest = I.zero; total = i }
        else Times.zero)

  let behaviour_modes behaviour =
    List.filter
      (fun p -> not (List.mem p [ stuck; unnamed; unnamed_other ]))
      (List.concat_map (fun (p, q) -> [ p; q ]) behaviour)

  (* The running time of an operation is the closed hull of its running-time
     bounds. *)
  let occurrence _name behaviour bounds =
    let running_time = I.closure bounds in
    tabulate
      (behaviour_modes behaviour)
      (List.map (fun pair -> (pair, ())) behaviour)
      (fun () p q ->
        if String.equal q stuck then Times.one
        else
          Times.Traces
            {
              times = [ (p, running_time) ];
              rest = I.zero;
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
    match totals with
    | [] -> None
    | i :: is -> Some (List.fold_left I.hull i is)

  let vacuous _ _ = None
  let events _ = []
  let counterexample _ _ = None
end

(* ------------------------------------------------------------------ *)
(* Specifications                                                      *)
(* ------------------------------------------------------------------ *)

(* The bounds of an entry of a specification: of the time in modes named, in
   each mode not named, and of the total time, each unconstrained if absent. *)
type bounds = {
  named : (string * I.t) list;
  others : I.t option;
  total : I.t option;
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
      let total = Option.value b.total ~default:I.unbounded in
      let bounded i = cap total (Option.value i ~default:I.unbounded) in
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
        let default = I.upto s.total in
        List.filter
          (fun (r, i) -> List.mem r m.modes && I.compare i default <> 0)
          s.times
  in
  let entry p q e =
    let bounds =
      match e with
      | Times.No_trace -> []
      | Times.Traces s ->
          let bound (name, i) = "(" ^ name ^ ", " ^ I.show_point i ^ ")" in
          List.map bound (bounded e)
          @ (if I.compare s.rest (I.upto s.total) = 0 then []
             else [ bound (unnamed, s.rest) ])
          @
          if I.compare s.total I.unbounded = 0 then []
          else [ I.show_point s.total ]
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
      I.point (non_negative (Option.get (number n)))
  | Grade.Interval (Grade.Closed lo, hi) -> (
      match (number lo, hi) with
      | Some lo, Grade.Unbounded ->
          (Grade.Closed (non_negative lo), Grade.Unbounded)
      | Some lo, Grade.Closed hi -> (
          match number hi with
          | Some hi when Rational.compare lo hi <= 0 ->
              (Grade.Closed (non_negative lo), Grade.Closed hi)
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

(* [realisable lit context modes (p, q) b] checks that some trace from [p] to
    [q] meets the bounds [b] of an entry of the literal [lit], the modes of the
    specification being [modes]: the time in [unnamed] has the lower end [0],
    as it bounds every mode not named, visited or not; a change of mode spends
    a positive time in its start mode; and the sum of the times in the modes
    meets the total time, the modes not named contributing [[0, 0]] if their
    time is [[0, 0]] and [\[0, ∞)] otherwise. *)
let realisable lit context modes (p, q) b =
  let positive = (Grade.Open Rational.zero, Grade.Unbounded) in
  (match b.others with
  | Some i when not (I.meets i I.zero) ->
      Grade.invalid_lit lit
        "%sthe time in `%s` has the lower end 0: it bounds every mode not \
         named, those not visited included"
        context unnamed
  | Some _ | None -> ());
  let time m = Option.value (List.assoc_opt m b.named) ~default:I.unbounded in
  let others = Option.value b.others ~default:I.unbounded in
  let start =
    if is_change (p, q) then
      let i = if String.equal p unnamed then others else time p in
      match I.inter i positive with
      | Some i -> [ i ]
      | None ->
          Grade.invalid_lit lit
            "%sa change of mode spends a positive time in its start mode `%s`"
            context p
    else []
  in
  let named =
    List.map time
      (List.filter (fun m -> not (is_change (p, q) && String.equal m p)) modes)
  in
  let rest = if I.is_zero others then I.zero else I.unbounded in
  let sum = List.fold_left I.add rest (start @ named) in
  match b.total with
  | Some t when not (I.meets sum t) ->
      Grade.invalid_lit lit
        "%sthe times in the modes sum to no time within the total time" context
  | Some _ | None -> ()

(* [bounds_of_lit lit modes (p, q) components] is the bounds of the entry from
    [p] to [q] of the literal [lit] with the components [components]: pairs
    [(M, t)] of a mode named or [unnamed] and an interval, and at most one
    interval of the total time; the modes of the specification are [modes]. *)
let bounds_of_lit lit modes (p, q) components =
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
  | Some t when is_change (p, q) && I.is_zero t ->
      Grade.invalid_lit lit "%sa change of mode takes a positive time" context
  | Some t -> (
      match
        List.find_opt
          (fun (_, i) -> not (I.meets i (I.upto t)))
          (named @ Option.fold ~none:[] ~some:(fun i -> [ (unnamed, i) ]) others)
      with
      | Some (m, _) ->
          Grade.invalid_lit lit "%sthe time in `%s` exceeds the total time"
            context m
      | None -> ())
  | None -> ());
  if String.equal p stuck && (named <> [] || others <> None || total <> None)
  then Grade.invalid_lit lit "no time is spent in the mode `%s`" stuck
  else
    let b = { named; others; total } in
    realisable lit context modes (p, q) b;
    b

(* [literal_modes lits] is the modes the entries [lits] of a specification
    name, sorted. *)
let literal_modes lits =
  let bound = function Grade.Tuple [ Grade.Name m; _ ] -> [ m ] | _ -> [] in
  List.sort_uniq String.compare
    (List.filter
       (fun p -> not (List.mem p [ stuck; unnamed; unnamed_other ]))
       (List.concat_map
          (function
            | Grade.Tuple (Grade.Name p :: Grade.Name q :: components) ->
                p :: q :: List.concat_map bound components
            | _ -> [])
          lits))

(* [spec_entry modes lit] is the entry [(From, To, bounds...)] of a
    specification of the modes [modes] the literal [lit] denotes. *)
let spec_entry modes = function
  | Grade.Tuple (Grade.Name p :: Grade.Name q :: components) as lit ->
      if String.equal p stuck && not (String.equal q stuck) then
        Grade.invalid_lit lit "no trace leaves the mode `%s`" stuck
      else
        let key = pair lit (p, q) in
        (key, bounds_of_lit lit modes key components)
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

module Terms = SummaryTerms.Make (Summary)

let of_lit = function
  | Grade.Top -> Terms.top
  | (Grade.Int _ | Grade.Rat _ | Grade.Interval _) as lit ->
      Terms.delays (interval_of_lit lit)
  | lit when is_spec_entry lit ->
      Terms.fixed (specification [ spec_entry (literal_modes [ lit ]) lit ])
  | Grade.Tuple (first :: _ as lits) as lit when is_spec_entry first ->
      Terms.fixed
        (specification
           (distinct lit
              (List.map
                 (Grade.component_of_lit lit ~context:""
                    (spec_entry (literal_modes lits)))
                 lits)))
  | (Grade.Braces _ | Grade.Tuple (Grade.Braces _ :: _)) as lit ->
      let x, b = occurrence_of_lit lit in
      Terms.op x b
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

(* Products bind tighter than joins. *)
let rec show c =
  match Terms.view c with
  | Terms.Delays i -> I.show_point i
  | Terms.Fixed m ->
      if Summary.equal m Summary.top then "⊤" else show_specification m
  | Terms.Op (x, b) -> show_occurrence x b
  | Terms.Mul cs ->
      String.concat " · "
        (List.map
           (fun c ->
             match Terms.view c with
             | Terms.Join _ -> "(" ^ show c ^ ")"
             | _ -> show c)
           cs)
  | Terms.Join cs -> String.concat " ⊔ " (List.map show cs)

let evaluate = Terms.evaluate

module ModeTimes = struct
  include Terms
  module Delay = Delay.Rational

  let name = "mode-times"
  let leq_symbol = "<="
  let unit_least = false
  let plus _ = None
  let commutative = false
  let needs_op_bounds = true
  let duration_ends = Grade.Both_ends
  let of_lit = of_lit
  let accepts = Grade.reads_lit of_lit
  let of_bounds b = delays (I.closure b)
  let show = show
  let witnesses ~degree:_ _bounds = Grade.sampled mul
end
