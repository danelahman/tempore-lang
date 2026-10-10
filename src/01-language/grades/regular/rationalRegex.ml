module Letters = SymbolicRegex.Letters

type t = { id : int; view : view; nullable : bool }
(* [id] numbers the normal forms in the order of their construction. *)

and view =
  | Empty
  | Eps
  | Delays of DelaySet.t
  | Names of Letters.t
  | Concat of t * t
  | Union of t list
  | Inter of t list
  | Compl of t
  | Star of t

let view r = r.view
let equal_form r s = r.id = s.id
let compare_form r s = Int.compare r.id s.id
let hash r = r.id
let nullable r = r.nullable
let mem_form r rs = List.exists (equal_form r) rs

(** The table of normal forms, each view built of normal forms identified by
    their numbers. *)
module Forms = Hashtbl.Make (struct
  type t = view

  let equal v w =
    match (v, w) with
    | Empty, Empty | Eps, Eps -> true
    | Delays s, Delays s' -> DelaySet.equal s s'
    | Names p, Names q -> Letters.equal p q
    | Concat (r, s), Concat (r', s') -> equal_form r r' && equal_form s s'
    | Union rs, Union rs' | Inter rs, Inter rs' -> List.equal equal_form rs rs'
    | Compl r, Compl r' | Star r, Star r' -> equal_form r r'
    | _ -> false

  let combine tag rs = List.fold_left (fun h r -> (h * 65599) + r.id) tag rs

  let hash = function
    | Empty -> 0
    | Eps -> 1
    | Delays s -> Grade.combine 7 (DelaySet.hash s)
    | Names p -> Letters.hash p
    | Concat (r, s) -> combine 2 [ r; s ]
    | Union rs -> combine 3 rs
    | Inter rs -> combine 4 rs
    | Compl r -> combine 5 [ r ]
    | Star r -> combine 6 [ r ]
end)

let forms = Forms.create 4096

let nullable_view = function
  | Empty | Names _ -> false
  | Eps | Star _ -> true
  | Delays s -> DelaySet.mem Rational.zero s
  | Concat (r, s) -> r.nullable && s.nullable
  | Union rs -> List.exists nullable rs
  | Inter rs -> List.for_all nullable rs
  | Compl r -> not r.nullable

(** [make view] is the normal form of [view], built on its first request: the
    expressions are hash-consed (Filliâtre and Conchon, ML Workshop 2006). *)
let make view =
  match Forms.find_opt forms view with
  | Some r -> r
  | None ->
      let r =
        { id = Forms.length forms; view; nullable = nullable_view view }
      in
      Forms.add forms view r;
      r

(** {1 Constructions} *)

let empty = make Empty
let eps = make Eps

let delays_atom s =
  if DelaySet.is_empty s then empty
  else if DelaySet.equal s DelaySet.zero then eps
  else make (Delays s)

(** The set of all names. *)
let all_names = Letters.others []

let names_atom p =
  let p = Letters.inter p all_names in
  if Letters.is_empty p then empty else make (Names p)

(** [atom r] is the set of delays of [r] if [r] is an atom: the empty language,
    the empty word or a set of delays. *)
let atom r =
  match r.view with
  | Empty -> Some DelaySet.empty
  | Eps -> Some DelaySet.zero
  | Delays s -> Some s
  | _ -> None

let names_set r = match r.view with Names p -> Some p | _ -> None

(* [_*], the repetition of every name and every positive delay, its operands
   ordered as {!union} orders them. *)
let top =
  make
    (Star
       (make
          (Union
             (List.sort compare_form
                [ make (Delays DelaySet.positive); make (Names all_names) ]))))

let is_top r = equal_form r top
let is_empty_form r = equal_form r empty

(* Adjacent atoms are summed: [⟨S⟩; ⟨T⟩ = ⟨S + T⟩], alone or leading a
   concatenation. *)
let rec concat r s =
  match (r.view, s.view) with
  | Empty, _ | _, Empty -> empty
  | Eps, _ -> s
  | _, Eps -> r
  | Concat (r1, r2), _ -> concat r1 (concat r2 s)
  | Star _, Star _ when equal_form r s -> r
  | Star _, Concat (s1, _) when equal_form r s1 -> s
  | _ -> (
      match (atom r, atom s, s.view) with
      | Some a, Some b, _ -> delays_atom (DelaySet.sum a b)
      | Some a, None, Concat (s1, s2) -> (
          match atom s1 with
          | Some b -> concat (delays_atom (DelaySet.sum a b)) s2
          | None -> make (Concat (r, s)))
      | _ -> make (Concat (r, s)))

(** [flatten split rs] is the operands of the n-ary operation of the operands
    [rs], by [split]: [Some rs'] to replace an operand by [rs']. *)
let flatten split rs =
  List.concat_map (fun r -> Option.value (split r) ~default:[ r ]) rs

(** [merge part combine build rs] merges the operands [rs] that [part] maps to a
    value into the value they combine to by [combine], built by [build]. *)
let merge part combine build rs =
  let parts, others =
    List.partition_map
      (fun r -> match part r with Some p -> Left p | None -> Right r)
      rs
  in
  match parts with
  | [] -> others
  | p :: ps -> build (List.fold_left combine p ps) :: others

(** [one_name_part r] is the set of the names of the one-operation words of [r],
    when [r] is a set of names, the complement of one or the repetition of one.
*)
let one_name_part r =
  match r.view with
  | Names p -> Some p
  | Compl { view = Names p; _ } ->
      Some (Letters.inter (Letters.compl p) all_names)
  | Star { view = Names p; _ } -> Some p
  | _ -> None

(** [complementary split rs] is whether some operand of [rs] is the complement
    of another, or of the operation that [split] splits into operands, all of
    them among [rs]: the operands of a flattened union or intersection. *)
let complementary split rs =
  let among s =
    match split s with
    | Some ss -> List.for_all (fun s' -> mem_form s' rs) ss
    | None -> mem_form s rs
  in
  List.exists (fun r -> match r.view with Compl s -> among s | _ -> false) rs

(** [subsumed rs r] is whether the operand [r] of a union is contained in
    another operand [s] of [rs] by one of the laws [0 ⊆ s] for a nullable [s]
    and [r ⊆ r*]. *)
let subsumed rs r =
  let contains s =
    match s.view with
    | Star s' -> equal_form r s'
    | _ -> s.nullable && equal_form r eps && not (equal_form s eps)
  in
  List.exists contains rs

(* The atoms of a union are merged into the atom of the union of their sets,
   and the sets of names into their union. *)
let union rs =
  let split r =
    match r.view with Union rs -> Some rs | Empty -> Some [] | _ -> None
  in
  let rs = flatten split rs in
  if List.exists is_top rs then top
  else
    let rs =
      merge atom DelaySet.union delays_atom
        (merge names_set Letters.union names_atom rs)
    in
    let rs =
      List.sort_uniq compare_form
        (List.filter (fun r -> not (is_empty_form r)) rs)
    in
    let rs = List.filter (fun r -> not (subsumed rs r)) rs in
    if complementary split rs then top
    else match rs with [] -> empty | [ r ] -> r | rs -> make (Union rs)

(* The sets of delays of the expressions computed, by their numbers. *)
let delay_sets : (int, DelaySet.t) Hashtbl.t = Hashtbl.create 1024

(* The set of the delays [d] such that the word [d] is in the expression, by
   structural recursion, memoised by expression. *)
let rec delays r =
  match Hashtbl.find_opt delay_sets r.id with
  | Some n -> n
  | None ->
      let n = delays_view r in
      Hashtbl.add delay_sets r.id n;
      n

and delays_view r =
  let fold op rs =
    match List.map delays rs with
    | n :: ns -> List.fold_left op n ns
    | [] -> DelaySet.empty
  in
  match r.view with
  | Empty | Names _ -> DelaySet.empty
  | Eps -> DelaySet.zero
  | Delays s -> s
  | Concat (r1, r2) -> DelaySet.sum (delays r1) (delays r2)
  | Union rs -> fold DelaySet.union rs
  | Inter rs -> (
      (* [N(r & ~s) = N(r) ∖ N(s)]. *)
      let complemented, others =
        List.partition_map
          (fun r -> match r.view with Compl s -> Left s | _ -> Right r)
          rs
      in
      match others with
      | [] -> DelaySet.compl (fold DelaySet.union complemented)
      | others ->
          List.fold_left
            (fun n s -> DelaySet.diff n (delays s))
            (fold DelaySet.inter others)
            complemented)
  | Compl r -> DelaySet.compl (delays r)
  | Star r -> DelaySet.star (delays r)

(** [symbols r] is [(S, p)] if the words of [r] are the delays of [S] and the
    one-operation words of the names of [p]: if [r] is an atom, a set of names
    or a union of these. *)
let symbols r =
  let part r =
    match (atom r, names_set r) with
    | Some s, _ -> Some (s, Letters.empty)
    | None, Some p -> Some (DelaySet.empty, p)
    | None, None -> None
  in
  match r.view with
  | Union rs ->
      List.fold_left
        (fun acc r ->
          Option.bind acc (fun (s, p) ->
              Option.map
                (fun (s', p') -> (DelaySet.union s s', Letters.union p p'))
                (part r)))
        (Some (DelaySet.empty, Letters.empty))
        rs
  | _ -> part r

(** [one_symbol_part r] is the delays and the names of the words of [r] of one
    delay or one operation, when [r] is as in {!symbols}, the complement of such
    an expression or the repetition of a set of names. *)
let one_symbol_part r =
  match r.view with
  | Compl s ->
      Option.map
        (fun (s, p) ->
          (DelaySet.compl s, Letters.inter (Letters.compl p) all_names))
        (symbols s)
  | Star { view = Names p; _ } -> Some (DelaySet.zero, p)
  | _ -> symbols r

(** [common_symbols rs] is the delays and the names common to the one-symbol
    parts ({!one_symbol_part}) of all of [rs], when each of them has one and one
    of them is as in {!symbols}. *)
let common_symbols rs =
  if List.exists (fun r -> Option.is_some (symbols r)) rs then
    List.fold_left
      (fun acc r ->
        Option.bind acc (fun (s, p) ->
            Option.map
              (fun (s', p') -> (DelaySet.inter s s', Letters.inter p p'))
              (one_symbol_part r)))
      (Some (DelaySet.all, all_names))
      rs
  else None

(* An intersection with an atom is the atom of the delays of all operands; an
   intersection of expressions of single symbols, their complements and
   repetitions of sets of names, one of them of single symbols, is the
   expression of the single symbols common to all; and in an intersection with
   a set of names, the sets of names, their complements and their repetitions
   are merged into the intersection of their one-operation words. *)
let inter rs =
  let split r =
    match r.view with
    | Inter rs -> Some rs
    | _ when is_top r -> Some []
    | _ -> None
  in
  let rs = flatten split rs in
  if List.exists (fun r -> Option.is_some (atom r)) rs then
    delays_atom
      (List.fold_left (fun n r -> DelaySet.inter n (delays r)) DelaySet.all rs)
  else
    match common_symbols rs with
    | Some (s, p) -> union [ delays_atom s; names_atom p ]
    | None -> (
        let rs =
          if List.exists (fun r -> Option.is_some (names_set r)) rs then
            merge one_name_part Letters.inter names_atom rs
          else rs
        in
        if List.exists is_empty_form rs then empty
        else
          let rs = List.sort_uniq compare_form rs in
          if complementary split rs then empty
          else match rs with [] -> top | [ r ] -> r | rs -> make (Inter rs))

let compl r =
  match r.view with
  | Compl s -> s
  | Empty -> top
  | _ when is_top r -> empty
  | _ -> make (Compl r)

(** [all_symbols r] is whether [r] is an atom, a set of names, or a union of
    these, that holds every name and every positive delay: the one-symbol words
    [Σ], whose repetition is [Σ*]. *)
let all_symbols r =
  let operands = match r.view with Union rs -> rs | _ -> [ r ] in
  let delay_part =
    List.fold_left
      (fun n r ->
        DelaySet.union n (Option.value (atom r) ~default:DelaySet.empty))
      DelaySet.empty operands
  and name_part =
    List.fold_left
      (fun p r ->
        Letters.union p (Option.value (names_set r) ~default:Letters.empty))
      Letters.empty operands
  in
  List.for_all
    (fun r -> Option.is_some (atom r) || Option.is_some (names_set r))
    operands
  && DelaySet.subset DelaySet.positive delay_part
  && Letters.equal name_part all_names

(** [holds_zero r] is whether [r] is an atom holding the delay [0]. *)
let holds_zero r =
  match atom r with Some s -> DelaySet.mem Rational.zero s | None -> false

(* The delay [0] of an atom of a repetition is left out: [(0 | r)* = r*]. *)
let rec star r =
  match r.view with
  | Empty | Eps -> eps
  | Star _ -> r
  | Delays s -> delays_atom (DelaySet.star s)
  | Union rs when List.exists holds_zero rs ->
      star
        (union
           (List.map
              (fun r ->
                match atom r with
                | Some s -> delays_atom (DelaySet.diff s DelaySet.zero)
                | None -> r)
              rs))
  | _ when all_symbols r -> top
  | _ -> make (Star r)

let rec of_regex : GradeLiteral.regex -> t = function
  | Letter name -> names_atom (Letters.name name)
  | Tick n -> delays_atom (DelaySet.point (Rational.of_int n))
  | Frac q -> delays_atom (DelaySet.point q)
  | Delays (lo, hi) -> delays_atom (DelaySet.between lo hi)
  | Any -> union [ delays_atom DelaySet.positive; names_atom all_names ]
  | Seq (r, s) -> concat (of_regex r) (of_regex s)
  | Union (r, s) -> union [ of_regex r; of_regex s ]
  | Inter (r, s) -> inter [ of_regex r; of_regex s ]
  | Compl r -> compl (of_regex r)
  | Star r -> star (of_regex r)

(** {1 Traversals} *)

let children r =
  match r.view with
  | Empty | Eps | Delays _ | Names _ -> []
  | Concat (r, s) -> [ r; s ]
  | Union rs | Inter rs -> rs
  | Compl r | Star r -> [ r ]

(** [name_sets roots] is the list of the sets of names occurring in [roots],
    each once. *)
let name_sets roots =
  let seen = Hashtbl.create 64 in
  let rec visit acc r =
    if Hashtbl.mem seen r.id then acc
    else begin
      Hashtbl.add seen r.id ();
      let acc = match r.view with Names p -> p :: acc | _ -> acc in
      List.fold_left visit acc (children r)
    end
  in
  List.sort_uniq Letters.compare (List.fold_left visit [] roots)

let names r =
  List.sort_uniq String.compare
    (List.concat_map
       (fun (p : Letters.t) -> match p.names with Only a | Except a -> a)
       (name_sets [ r ]))

let blocks roots =
  List.filter_map
    (fun b ->
      let b = Letters.inter b all_names in
      if Letters.is_empty b then None else Some b)
    (Letters.partition (name_sets roots))
  |> List.sort Letters.order

(** {1 Gap derivatives} *)

type gaps = t GapMap.t

include GapMap.Make (struct
  type nonrec t = t

  let universe = DelaySet.all
  let empty = empty
  let top = top
  let union = union
  let inter = inter
  let compl = compl
  let compare_form = compare_form
end)

type block = { set : Letters.t; key : int }
(** A block of names, with the number of its normal form as a key. *)

let block set = { set; key = (names_atom set).id }

(** Tables by pairs of numbers. *)
module Pairs = Hashtbl.Make (struct
  type t = int * int

  let equal (i, j) (i', j') = Int.equal i i' && Int.equal j j'
  let hash (i, j) = Grade.combine i j
end)

(* The gap derivatives computed, by the key of the block and the number of the
   expression. *)
let gap_derivatives : gaps Pairs.t = Pairs.create 1024

(* The derivative by the words [d a], [a] a name of the block, symbolic in the
   delay [d]: a symbolic derivative over the Boolean algebra of the finite
   unions of products of sets of delays and blocks of names (D'Antoni and
   Veanes, POPL 2014), with the derivatives of concatenation and repetition of
   Brzozowski (JACM 1964), the delays before the name read by [delays].
   Memoised by block and expression. *)
let rec gap m r =
  let key = (m.key, r.id) in
  match Pairs.find_opt gap_derivatives key with
  | Some f -> f
  | None ->
      let f = gap_view m r in
      Pairs.add gap_derivatives key f;
      f

and gap_view m r =
  match r.view with
  | Empty | Eps | Delays _ -> []
  | Names p ->
      if Letters.is_empty (Letters.inter m.set p) then []
      else [ (DelaySet.zero, eps) ]
  | Concat (r1, r2) ->
      join
        (normalise (List.map (fun (n, e) -> (n, concat e r2)) (gap m r1)))
        (shift (delays r1) (gap m r2))
  | Union rs -> List.fold_left (fun f r -> join f (gap m r)) [] rs
  | Inter rs -> List.fold_left (fun f r -> meet f (gap m r)) full rs
  | Compl r -> complement (gap m r)
  | Star r' ->
      shift
        (DelaySet.star (delays r'))
        (List.map (fun (n, e) -> (n, concat e r)) (gap m r'))

let gap_derivative set r = gap (block (Letters.inter set all_names)) r

(** {1 Decisions} *)

include GapDecisions.Make (struct
  type nonrec t = t
  type nonrec block = block

  let id r = r.id
  let empty = empty
  let is_top = is_top
  let inter = inter
  let compl = compl
  let nullable = nullable
  let delays = delays
  let gap = gap
  let blocks roots = List.map block (blocks roots)
end)

(* An atom is contained in an expression iff none of its delays is a delay of
   the complement, its words being delays. *)
let subset r s =
  equal_form r s
  ||
  match atom r with
  | Some n -> not (DelaySet.intersects n (delays (compl s)))
  | None -> subset r s

let mem word r =
  let rec go r pending = function
    | [] -> DelaySet.mem pending (delays r)
    | DelayAutomaton.Delay d :: word -> go r (Rational.add pending d) word
    | DelayAutomaton.Operation c :: word -> (
        match
          List.find_opt
            (fun (n, _) -> DelaySet.mem pending n)
            (gap_derivative c r)
        with
        | Some (_, e) -> go e Rational.zero word
        | None -> false)
  in
  go r Rational.zero word

module Graph = GapGraph.Make (struct
  type nonrec t = t

  let id r = r.id
  let delays = delays
  let gap_derivative name = gap_derivative (Letters.name name)
end)

let graph = Graph.graph

let counterexample r s =
  if subset r s then None
  else
    Option.map
      (fun (steps, finals) ->
        let choose n =
          match DelaySet.choose n with
          | Some d -> d
          | None ->
              invalid_arg
                "RationalRegex.counterexample: an empty set of delays on a word"
        in
        List.concat_map
          (fun (n, m) ->
            [ DelayAutomaton.Delay (choose n); DelayAutomaton.Operation m.set ])
          steps
        @ [ DelayAutomaton.Delay (choose finals) ])
      (fewest_operations (inter [ r; compl s ]))
