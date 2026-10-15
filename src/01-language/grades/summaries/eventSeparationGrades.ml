open Grade
module I = DurationIntervals
module Indexed = GradeConstructions.Indexed

(* The hull of two optional intervals, an absent one being empty. *)
let hull_opt f a b =
  match (a, b) with
  | Some a, Some b -> Some (f a b)
  | Some x, None | None, Some x -> Some x
  | None, None -> None

(* The sum of two optional cases, absent if either is. *)
let both f a b = match (a, b) with Some a, Some b -> Some (f a b) | _ -> None

(* Inclusion of optional intervals, an absent one being empty. *)
let subset_opt subset a b =
  match (a, b) with
  | None, _ -> true
  | Some _, None -> false
  | Some a, Some b -> subset a b

let compare_opt = Option.compare
let hash_opt hash = function None -> 0 | Some x -> Hashing.combine 1 (hash x)

(* Intervals of natural numbers, [most] being [None] where unbounded. *)
module Count = struct
  type t = { least : int; most : int option }

  let point n = { least = n; most = Some n }
  let unbounded = { least = 0; most = None }

  let add c c' =
    { least = c.least + c'.least; most = both ( + ) c.most c'.most }

  let hull c c' =
    { least = min c.least c'.least; most = both max c.most c'.most }

  let subset c c' =
    c'.least <= c.least
    &&
    match (c.most, c'.most) with
    | _, None -> true
    | None, Some _ -> false
    | Some m, Some m' -> m <= m'

  let compare c c' =
    match Int.compare c.least c'.least with
    | 0 -> compare_opt Int.compare c.most c'.most
    | c -> c

  let hash c = Hashing.combine c.least (hash_opt Fun.id c.most)

  let show c =
    match c.most with
    | Some m when m = c.least -> string_of_int m
    | Some m -> Printf.sprintf "[%d, %d]" c.least m
    | None -> Printf.sprintf "[%d, ∞)" c.least
end

module Summary = struct
  type count = Count.t = { least : int; most : int option }
  type active = { count : count; lead : I.t; gaps : I.t option; tail : I.t }
  type entry = { silent : I.t option; active : active option }
  type t = { entries : entry Indexed.t; total : I.t }
  type op = unit

  let hull_active a a' =
    {
      count = Count.hull a.count a'.count;
      lead = I.hull a.lead a'.lead;
      gaps = hull_opt I.hull a.gaps a'.gaps;
      tail = I.hull a.tail a'.tail;
    }

  let compare_active a a' =
    match Count.compare a.count a'.count with
    | 0 -> (
        match I.compare a.lead a'.lead with
        | 0 -> (
            match compare_opt I.compare a.gaps a'.gaps with
            | 0 -> I.compare a.tail a'.tail
            | c -> c)
        | c -> c)
    | c -> c

  let compare_entry e e' =
    match compare_opt I.compare e.silent e'.silent with
    | 0 -> compare_opt compare_active e.active e'.active
    | c -> c

  let hash_active a =
    Hashing.combine
      (Hashing.combine
         (Hashing.combine (Count.hash a.count) (I.hash a.lead))
         (hash_opt I.hash a.gaps))
      (I.hash a.tail)

  let hash_entry e =
    Hashing.combine (hash_opt I.hash e.silent) (hash_opt hash_active e.active)

  (* The longest-gap monoid, lifted to the cases of an entry: a stretch without
     the name added to a lead or a tail, and the tail of the first part with
     the lead of the second part forming a gap, the counts added. *)
  let mul_entry e e' =
    let cases =
      [
        both (fun s a -> { a with lead = I.add s a.lead }) e.silent e'.active;
        both (fun a s -> { a with tail = I.add a.tail s }) e.active e'.silent;
        both
          (fun a a' ->
            {
              count = Count.add a.count a'.count;
              lead = a.lead;
              gaps =
                hull_opt I.hull
                  (hull_opt I.hull a.gaps a'.gaps)
                  (Some (I.add a.tail a'.lead));
              tail = a'.tail;
            })
          e.active e'.active;
      ]
    in
    {
      silent = both I.add e.silent e'.silent;
      active = List.fold_left (hull_opt hull_active) None cases;
    }

  let join_entry e e' =
    {
      silent = hull_opt I.hull e.silent e'.silent;
      active = hull_opt hull_active e.active e'.active;
    }

  let leq_active a a' =
    Count.subset a.count a'.count
    && I.subset a.lead a'.lead
    && subset_opt I.subset a.gaps a'.gaps
    && I.subset a.tail a'.tail

  let leq_entry e e' =
    subset_opt I.subset e.silent e'.silent
    && subset_opt leq_active e.active e'.active

  let silent_entry i = { silent = Some i; active = None }

  let top_entry =
    {
      silent = Some I.unbounded;
      active =
        Some
          {
            count = { least = 1; most = None };
            lead = I.unbounded;
            gaps = Some I.unbounded;
            tail = I.unbounded;
          };
    }

  let delays i = { entries = Indexed.everywhere (silent_entry i); total = i }
  let one = delays I.zero
  let top = { entries = Indexed.everywhere top_entry; total = I.unbounded }

  let occurrence name () running_time =
    {
      entries =
        Indexed.of_list ~compare:compare_entry
          ~others:(silent_entry running_time)
          [
            ( name,
              {
                silent = None;
                active =
                  Some
                    {
                      count = Count.point 1;
                      lead = I.zero;
                      gaps = None;
                      tail = running_time;
                    };
              } );
          ];
      total = running_time;
    }

  let mul s s' =
    {
      entries = Indexed.map2 compare_entry mul_entry s.entries s'.entries;
      total = I.add s.total s'.total;
    }

  let join s s' =
    {
      entries = Indexed.map2 compare_entry join_entry s.entries s'.entries;
      total = I.hull s.total s'.total;
    }

  let leq s s' =
    I.subset s.total s'.total && Indexed.for_all2 leq_entry s.entries s'.entries

  let compare s s' =
    match I.compare s.total s'.total with
    | 0 -> Indexed.compare_with compare_entry s.entries s'.entries
    | c -> c

  let hash s =
    Hashing.combine (I.hash s.total) (Indexed.hash_with hash_entry s.entries)

  let compare_op () () = 0
  let hash_op () = 0
  let duration s = Some s.total

  (* The durations of the computations of an active case with [k] occurrences
     lie in [lead + (k - 1) gaps + tail]: their hull over the count. *)
  let active_durations a =
    let gaps =
      match a.gaps with
      | None -> I.zero
      | Some gaps -> (
          let fewest = I.scale (a.count.least - 1) gaps in
          match a.count.most with
          | None -> I.from fewest
          | Some most -> I.hull fewest (I.scale (most - 1) gaps))
    in
    I.add (I.add a.lead a.tail) gaps

  (* Some silent duration, or the durations of an active case, within the
     total. *)
  let entry_inhabited total e =
    Option.fold ~none:false ~some:(I.meets total) e.silent
    || Option.fold ~none:false
         ~some:(fun a -> I.meets total (active_durations a))
         e.active

  let inhabited s = Indexed.for_all (entry_inhabited s.total) s.entries
  let events s = List.map fst (Indexed.named s.entries)

  (* The entry [e] at the name [s] of the summary [c], the others kept. *)
  let with_entry c s e =
    let entries =
      if String.equal s Indexed.fresh then
        Indexed.of_list ~compare:compare_entry ~others:e
          (Indexed.named c.entries)
      else
        Indexed.of_list ~compare:compare_entry
          ~others:(Indexed.others c.entries)
          ((s, e) :: List.remove_assoc s (Indexed.named c.entries))
    in
    { c with entries }

  (* The lesser summary with, at the first name where the order fails, the
     case that fails alone, or the summary itself. *)
  let counterexample c d =
    let failing s =
      let e = Indexed.at c.entries s and e' = Indexed.at d.entries s in
      if leq_entry e e' then None
      else if not (subset_opt I.subset e.silent e'.silent) then
        if Option.is_some e.active then
          Some (with_entry c s { e with active = None })
        else None
      else if Option.is_some e.silent then
        Some (with_entry c s { e with silent = None })
      else None
    in
    Some
      (Option.value ~default:c
         (List.find_map failing (Indexed.names [ c.entries; d.entries ])))
end

module Terms = SummaryTerms.Make (Summary)
include Terms
module Delay = Delay.Rational

let name = "event-separation"
let leq_symbol = "<="
let unit_least = false
let commutative = false
let needs_op_bounds = true
let of_delay = Terms.of_delay
let witnesses ~degree:_ _bounds = sampled mul

(* ------------------------------------------------------------------ *)
(* Literals                                                            *)
(* ------------------------------------------------------------------ *)

(* [of_braces lit r] is the term of the expression [r] of the brace literal
   [lit]: operation names, delays and intervals of delays, sequenced and
   joined. *)
let of_braces lit r =
  check_delays lit r;
  let rec go = function
    | Letter name -> Terms.op name ()
    | Tick n -> Terms.of_delay (Rational.of_int n)
    | Frac q -> Terms.of_delay q
    | Delays (lo, hi) -> (
        match emptiness lo hi with
        | Some reason -> invalid_lit lit "%s" reason
        | None -> Terms.delays (lo, hi))
    | Seq (r, s) -> mul (go r) (go s)
    | Union (r, s) -> join (go r) (go s)
    | Strict _ as r -> component_of_lit lit ~context:"" strict_unsupported r
    | Any | Star _ | Inter _ | Compl _ ->
        invalid_lit lit
          "the brace literals of event separation are sequences `;` and unions \
           `|` of operation names and delays, without `*`, `&`, `~` and `_`"
  in
  go r

(* The entry of a specification of the count [count] of occurrences, the
   silent computations included where it contains [0], and of the lead, the
   gaps and the tail of the active ones; there are no gaps where the count of
   the active ones is [1]. *)
let make_entry (count : Count.t) ~lead ~gaps ~tail =
  let open Summary in
  {
    silent = (if count.least = 0 then I.inter lead tail else None);
    active =
      (if count.most = Some 0 then None
       else
         let count = { count with least = max 1 count.least } in
         Some
           {
             count;
             lead;
             gaps = (if count.most = Some 1 then None else Some gaps);
             tail;
           });
  }

(* A count: a natural number, or an interval [[n, m]] or [\[n, ∞)] of them,
   its open ends closed over the integers. *)
let count_of_lit lit =
  let natural = function Closed (Int n) when n >= 0 -> Some n | _ -> None in
  let reject () =
    invalid_lit lit
      "counts are natural numbers `n` or intervals `[n, m]` and `[n, ∞)`, not \
       %s"
      (describe_lit lit)
  in
  match lit with
  | Int n when n >= 0 -> Count.point n
  | Int n -> invalid_lit lit "counts are non-negative, not %d" n
  | Interval (lo, hi) -> (
      match integer_ends lit lo hi with
      | lo, Unbounded -> (
          match natural lo with
          | Some n -> { Count.least = n; most = None }
          | None -> reject ())
      | lo, hi -> (
          match (natural lo, natural hi) with
          | Some n, Some m -> { Count.least = n; most = Some m }
          | _ -> reject ()))
  | _ -> reject ()

(* The name of an entry literal, [(X, ...)] or [(n, X, ...)]. *)
let entry_name = function
  | Tuple (Name x :: _ :: _) -> Some x
  | Tuple ((Int _ | Rat _ | Interval _) :: Name x :: _) -> Some x
  | _ -> None

let is_entry lit = Option.is_some (entry_name lit)

(* The name and the entry of an entry literal: [(X, [s, t])], gaps in
   [[s, t]] and stretches without [X] at most [t], or
   [(X, lead, gaps, tail)], any number of [X]s; or [(n, X, [s, t])],
   [(n, X, lead, tail)], the gaps unconstrained, and
   [(n, X, lead, gaps, tail)], [n] of them. *)
let entry_of_lit lit =
  (match entry_name lit with
  | Some x when String.equal x Indexed.fresh ->
      invalid_lit (Tuple [ Name x ])
        "the entries of a specification name operations, the others being \
         unconstrained"
  | Some _ | None -> ());
  let interval x context =
    component_of_lit lit
      ~context:(Printf.sprintf "in the entry of `%s`, %s" x context)
      I.of_lit
  in
  let short x count gaps =
    let gaps = interval x "in the gaps, " gaps in
    make_entry count ~lead:(I.upto gaps) ~gaps ~tail:(I.upto gaps)
  in
  let full x count lead gaps tail =
    make_entry count
      ~lead:(interval x "in the lead, " lead)
      ~gaps:
        (Option.fold ~none:I.unbounded ~some:(interval x "in the gaps, ") gaps)
      ~tail:(interval x "in the tail, " tail)
  in
  match lit with
  | Tuple [ Name x; gaps ] -> (x, short x Count.unbounded gaps)
  | Tuple [ Name x; lead; gaps; tail ] ->
      (x, full x Count.unbounded lead (Some gaps) tail)
  | Tuple (Name _ :: _) ->
      invalid_lit lit
        "an entry `(X, ...)` lists one interval, the gaps, or three, the lead, \
         the gaps and the tail"
  | Tuple (count :: Name x :: rest) -> (
      let count =
        component_of_lit lit
          ~context:(Printf.sprintf "in the entry of `%s`, in the count, " x)
          count_of_lit count
      in
      let entry =
        match rest with
        | [ gaps ] -> short x count gaps
        | [ lead; tail ] -> full x count lead None tail
        | [ lead; gaps; tail ] -> full x count lead (Some gaps) tail
        | [] | _ :: _ :: _ :: _ :: _ ->
            invalid_lit lit
              "an entry `(n, X, ...)` lists one interval, the gaps, two, the \
               lead and the tail, or three, the lead, the gaps and the tail"
      in
      match entry with
      | { silent = None; active = None } ->
          invalid_lit lit
            "the entry of `%s` admits no computation: a count of 0, and a lead \
             and a tail that do not meet"
            x
      | entry -> (x, entry))
  | lit ->
      invalid_lit lit "entries are tuples `(X, ...)`, not %s" (describe_lit lit)

(* [of_specification lit components] is the specification of the tuple
   [lit] of the entries and at most one interval of the total duration
   [components]. *)
let of_specification lit components =
  let entries, totals = List.partition is_entry components in
  let entries =
    Grade.distinct_entries lit ~compare:String.compare
      ~twice:(Printf.sprintf "the name `%s` is listed twice")
      (List.map (component_of_lit lit ~context:"" entry_of_lit) entries)
  in
  let total =
    match totals with
    | [] -> I.unbounded
    | [ total ] ->
        component_of_lit lit ~context:"in the total duration, " I.of_lit total
    | _ :: _ :: _ ->
        invalid_lit lit
          "a specification lists entries `(X, ...)` and at most one interval, \
           the total duration"
  in
  Terms.fixed
    {
      Summary.entries =
        Indexed.of_list ~compare:Summary.compare_entry ~others:Summary.top_entry
          entries;
      total;
    }

let of_lit lit =
  match open_pair lit with
  | Top -> top
  | Braces r -> of_braces lit r
  | (Int _ | Rat _ | Interval _) as lit -> Terms.delays (I.of_lit lit)
  | lit when is_entry lit -> of_specification lit [ lit ]
  | Tuple components when List.exists is_entry components ->
      of_specification lit components
  | Name name ->
      invalid_lit lit
        "the occurrence of an operation is written `{%s}`, and its separation \
         `(%s, [s, t])`"
        name name
  | lit ->
      invalid_lit lit
        "grades are brace literals `{...}` of operation names and delays, \
         numbers, intervals and specifications `(X, [s, t])`, not %s"
        (describe_lit lit)

let accepts = reads_lit of_lit

(* ------------------------------------------------------------------ *)
(* Printing                                                            *)
(* ------------------------------------------------------------------ *)

(* The entry [e] of the name [name] as the first literal of an entry that
   denotes it, if one does: the forms without a count, then those with one,
   each with fewer components first. *)
let entry_literal (name, (e : Summary.entry)) =
  let parts =
    match (e.active, e.silent) with
    | Some a, silent ->
        Some
          ( {
              a.count with
              least = (if Option.is_some silent then 0 else a.count.least);
            },
            a.lead,
            Option.value a.gaps ~default:I.unbounded,
            a.tail )
    | None, Some s -> Some (Count.point 0, s, I.unbounded, s)
    | None, None -> None
  in
  Option.bind parts (fun (count, lead, gaps, tail) ->
      let n = Count.show count and stretch = I.upto gaps in
      let show = List.map I.show in
      let form count lead gaps tail components =
        ( make_entry count ~lead ~gaps ~tail,
          "(" ^ String.concat ", " components ^ ")" )
      in
      List.find_map
        (fun (e', text) ->
          if Summary.compare_entry e e' = 0 then Some text else None)
        [
          form Count.unbounded stretch gaps stretch (name :: show [ gaps ]);
          form Count.unbounded lead gaps tail (name :: show [ lead; gaps; tail ]);
          form count stretch gaps stretch (n :: name :: show [ gaps ]);
          form count lead I.unbounded tail (n :: name :: show [ lead; tail ]);
          form count lead gaps tail (n :: name :: show [ lead; gaps; tail ]);
        ])

(* The cases of the entry [e] of the name [name] in the notation of
   summaries, an absent case omitted, no gaps written [∅], and the count of an
   active case written first where it is not [\[1, ∞)] or implied by the
   absence of gaps. *)
let show_entry (name, (e : Summary.entry)) =
  let count (a : Summary.active) =
    if
      Option.is_none a.gaps
      || Count.compare a.count { least = 1; most = None } = 0
    then []
    else [ Count.show a.count ]
  in
  name ^ ": "
  ^ String.concat ", "
      (Option.to_list (Option.map (fun i -> "silent " ^ I.show i) e.silent)
      @ Option.to_list
          (Option.map
             (fun (a : Summary.active) ->
               "active ("
               ^ String.concat ", "
                   (count a
                   @ [
                       I.show a.lead;
                       Option.fold ~none:"∅" ~some:I.show a.gaps;
                       I.show a.tail;
                     ])
               ^ ")")
             e.active))

(* A summary as the literal of a specification where it is one, and otherwise
   in the notation of summaries. *)
let show_summary (s : Summary.t) =
  let others = Indexed.others s.entries in
  let entries = Indexed.named s.entries in
  let literals = List.filter_map entry_literal entries in
  let total =
    if I.compare s.total I.unbounded = 0 then [] else [ I.show s.total ]
  in
  if Summary.compare s Summary.top = 0 then "⊤"
  else if
    Summary.compare_entry others Summary.top_entry = 0
    && List.length literals = List.length entries
    && literals <> []
  then
    match literals @ total with
    | [ entry ] -> entry
    | components -> "(" ^ String.concat ", " components ^ ")"
  else
    "⟨"
    ^ String.concat "; "
        (List.map show_entry (entries @ [ (Indexed.fresh, others) ])
        @ List.map (fun total -> "total " ^ total) total)
    ^ "⟩"

(* The expression of a brace literal of the term [c], if it has one. *)
let rec regex c =
  let fold f = function
    | [] -> None
    | c :: cs ->
        List.fold_left
          (fun r c -> Option.bind r (fun r -> Option.map (f r) (regex c)))
          (regex c) cs
  in
  match view c with
  | Op (name, ()) -> Some (Letter name)
  | Delays (Closed q, Closed q') when Rational.equal q q' ->
      Some (rational_tick q)
  | Delays (lo, hi) -> Some (Delays (lo, hi))
  | Fixed _ -> None
  | Mul cs -> fold (fun r s -> Seq (r, s)) cs
  | Join cs -> fold (fun r s -> Union (r, s)) cs

(* The factors [cs] of a product, the adjacent ones of brace literals
   sequenced into one. *)
let groups cs =
  List.rev
    (List.fold_left
       (fun acc c ->
         match (acc, regex c) with
         | Either.Left r :: rest, Some s -> Either.Left (Seq (r, s)) :: rest
         | _, Some s -> Either.Left s :: acc
         | _, None -> Either.Right c :: acc)
       [] cs)

let braces r = "{" ^ show_regex r ^ "}"

let rec show c =
  match (view c, regex c) with
  | Delays i, _ -> I.show_point i
  | Fixed s, _ -> show_summary s
  | (Op _ | Mul _ | Join _), Some r -> braces r
  | Mul cs, None ->
      String.concat " · "
        (List.map
           (function
             | Either.Left r -> braces r
             | Either.Right c -> (
                 match view c with Join _ -> "(" ^ show c ^ ")" | _ -> show c))
           (groups cs))
  | Join cs, None -> String.concat " ⊔ " (List.map show cs)
  | Op _, None -> invalid_arg "EventSeparationGrades.show"
