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
  | Repeat of t * Count.t

let view r = r.view
let equal_form r s = r.id = s.id
let compare_form r s = Int.compare r.id s.id
let hash r = r.id
let nullable r = r.nullable

let nullable_view = function
  | Empty | Names _ -> false
  | Eps | Star _ -> true
  | Delays s -> DelaySet.mem Rational.zero s
  | Concat (r, s) -> r.nullable && s.nullable
  | Union rs -> List.exists nullable rs
  | Inter rs -> List.for_all nullable rs
  | Compl r -> not r.nullable
  | Repeat (r, c) -> r.nullable || Count.mem 0 c

(** The table of normal forms, each view built of normal forms identified by
    their numbers. *)
module Forms =
  NormalForms.HashCons
    (struct
      type t = view

      let equal v w =
        match (v, w) with
        | Empty, Empty | Eps, Eps -> true
        | Delays s, Delays s' -> DelaySet.equal s s'
        | Names p, Names q -> Letters.equal p q
        | Concat (r, s), Concat (r', s') -> equal_form r r' && equal_form s s'
        | Union rs, Union rs' | Inter rs, Inter rs' ->
            List.equal equal_form rs rs'
        | Compl r, Compl r' | Star r, Star r' -> equal_form r r'
        | Repeat (r, c), Repeat (r', c') -> equal_form r r' && Count.equal c c'
        | _ -> false

      let combine = NormalForms.combine_ids (fun r -> r.id)

      let hash = function
        | Empty -> 0
        | Eps -> 1
        | Delays s -> Hashing.combine 7 (DelaySet.hash s)
        | Names p -> Letters.hash p
        | Concat (r, s) -> combine 2 [ r; s ]
        | Union rs -> combine 3 rs
        | Inter rs -> combine 4 rs
        | Compl r -> combine 5 [ r ]
        | Star r -> combine 6 [ r ]
        | Repeat (r, c) -> Hashing.combine (combine 8 [ r ]) (Count.hash c)
    end)
    (struct
      type nonrec t = t

      let build id view = { id; view; nullable = nullable_view view }
    end)

(** [make view] is the normal form of [view]: the expressions are hash-consed
    ({!NormalForms.HashCons}). *)
let make = Forms.make

(** {1 Constructions} *)

let empty = make Empty
let eps = make Eps

include NormalForms.Boolean (struct
  type nonrec t = t

  let id r = r.id
  let nullable = nullable
  let eps = eps
  let compl_operand r = match r.view with Compl s -> Some s | _ -> None
  let star_operand r = match r.view with Star s -> Some s | _ -> None
end)

let delays_atom s =
  if DelaySet.is_empty s then empty
  else if DelaySet.equal s DelaySet.zero then eps
  else make (Delays s)

(** The set of all names. *)
let all_names = Letters.others []

(* [names_atom p] is the language of the one-operation words of the names of
   [p], [tick] left out. *)
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

(** [repetition r] is [Some (x, c)] if [r] is the repetition [x^c]. *)
let repetition r = match r.view with Repeat (x, c) -> Some (x, c) | _ -> None

(** [chain r] is [Some (h, t)] if [r] is the concatenation [h; t]. *)
let chain r = match r.view with Concat (h, t) -> Some (h, t) | _ -> None

(** [power r] is [(x, c)] if [r] is the repetition [x^c], and [(r, 1)]
    otherwise. *)
let power r = Option.value (repetition r) ~default:(r, Count.point 1)

(* The atoms of a union are merged into the atom of the union of their sets,
   the sets of names into their union, and the repetitions of a base where
   their counts overlap or touch: [x^c | x^c' = x^(c ∪ c')], also as factors of
   concatenations equal but for their counts. *)
let rec union rs =
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
        (List.filter
           (fun r -> not (is_empty_form r))
           (repetitions repetition repeat rs))
    in
    let rs =
      List.sort_uniq compare_form
        (repetitions_in_context chain repetition repeat concat rs)
    in
    let rs = unsubsumed rs in
    if complementary split rs then top
    else match rs with [] -> empty | [ r ] -> r | rs -> make (Union rs)

(* The delay [0] of an atom of a repetition is left out: [(0 | r)* = r*]; and
   [(r^c)* = r*] where [1 ∈ c]. *)
and star r =
  match r.view with
  | Empty | Eps -> eps
  | Star _ -> r
  | Repeat (s, c) when Count.mem 1 c -> star s
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

(* The laws of bounded repetition over intervals of counts: [r^0 = 0],
   [r^1 = r], [r^[0, ∞) = r*], an atom [⟨S⟩^c] is the atom of
   [⋃ {k·S : k ∈ c}] ({!DelaySet.repeat}), the empty word and language among
   them, [(s* )^c = s*] for [c ≠ {0}], [(s^c)^c' = s^(c ⊛ c')] where [c ⊛ c']
   is an interval ({!Count.nest}), and a nullable [r] has [r^c = r^n] for
   [c = [m, n]] and [r^c = r*] for [c = [m, ∞)], every word of [r^k] being one
   of [r^(k + 1)]. *)
and repeat r (c : Count.t) =
  if Count.is_point 0 c then eps
  else if Count.is_point 1 c then r
  else
    match (atom r, r.view, c.most) with
    | Some s, _, _ -> delays_atom (DelaySet.repeat s c)
    | None, Star _, _ -> r
    | None, _, None when r.nullable || c.least = 0 -> star r
    | None, _, Some n when r.nullable && c.least < n -> repeat r (Count.point n)
    | None, Repeat (s, c0), _ -> (
        match Count.nest c0 c with
        | Some d -> repeat s d
        | None -> make (Repeat (r, c)))
    | None, _, _ -> make (Repeat (r, c))

(* Adjacent atoms are summed: [⟨S⟩; ⟨T⟩ = ⟨S + T⟩], alone or leading a
   concatenation; and a repetition followed by one of the same base, alone or
   leading a concatenation, is joined with it: [x^c; x^c' = x^(c + c')], a
   factor [x] counting as [x^1]. *)
and concat r s =
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
      | Some a, None, Concat (s1, s2) when Option.is_some (atom s1) ->
          concat (delays_atom (DelaySet.sum a (Option.get (atom s1)))) s2
      | _ -> (
          let x, c = power r in
          let head, rest =
            match s.view with Concat (s1, s2) -> (s1, Some s2) | _ -> (s, None)
          in
          let y, c' = power head in
          if not (equal_form x y) then make (Concat (r, s))
          else
            let joined = repeat x (Count.add c c') in
            match rest with None -> joined | Some rest -> concat joined rest))

(** [node r] is the top operation of [r], its atoms being its sets of delays and
    of names. *)
let node r : t NormalForms.node =
  match r.view with
  | Delays _ | Names _ -> Atom r
  | Empty -> Empty
  | Eps -> Eps
  | Concat (r, s) -> Concat (r, s)
  | Union rs -> Union rs
  | Inter rs -> Inter rs
  | Compl r -> Compl r
  | Star r -> Star r
  | Repeat (r, c) -> Repeat (r, c)

(* The set of the delays [d] such that the word [d] is in the expression, the
   complement taken in [ℚ≥0]. *)
include NormalForms.Delays (struct
  type nonrec t = t

  let id r = r.id
  let node = node
  let atom_delays r = match r.view with Delays s -> s | _ -> DelaySet.empty
  let complement = DelaySet.compl
end)

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
  | Repeat (r, c) -> repeat (of_regex r) c
  | Strict _ as r -> GradeLiteral.strict_unsupported r

(** The strict delays of the rigid grades. *)
module Strict = StrictDelays.Make (struct
  type nonrec t = t

  let eps = eps
  let name n = names_atom (Letters.name n)
  let operations = names_atom (Letters.others StrictDelays.markers)
  let delay = delays_atom DelaySet.positive
  let positive = delay
  let of_delays = of_regex
  let nullable = nullable
  let concat = concat
  let union = union
  let inter = inter
  let compl = compl
  let star = star
  let repeat = repeat
end)

let of_strict_regex = Strict.of_regex
let strict_top = Strict.words

(** {1 Traversals} *)

let children r =
  match r.view with
  | Empty | Eps | Delays _ | Names _ -> []
  | Concat (r, s) -> [ r; s ]
  | Union rs | Inter rs -> rs
  | Compl r | Star r | Repeat (r, _) -> [ r ]

(** [name_sets roots] is the list of the sets of names occurring in [roots],
    each once. *)
let name_sets roots =
  List.sort_uniq Letters.compare
    (collect children
       (fun r -> match r.view with Names p -> [ p ] | _ -> [])
       roots)

let names =
  let table = Memo.Ints.create 1024 in
  fun r ->
    Memo.Ints.find_or_add table r.id (fun () ->
        List.sort_uniq String.compare
          (List.concat_map
             (fun (p : Letters.t) ->
               match p.names with Only a | Except a -> a)
             (name_sets [ r ])))

let blocks roots =
  List.filter_map
    (fun b ->
      let b = Letters.inter b all_names in
      if Letters.is_empty b then None else Some b)
    (Letters.partition (name_sets roots))
  |> List.sort Letters.order

(** {1 Gap derivatives} *)

type gaps = t GapMap.t

type block = { set : Letters.t; key : int }
(** A block of names, with the number of its normal form as a key. *)

let block set = { set; key = (names_atom set).id }

(* The derivative by the words [d a], [a] a name of the block, symbolic in the
   delay [d] ({!NormalForms.Gaps}). *)
include NormalForms.Gaps (struct
  type nonrec t = t
  type nonrec block = block

  let id r = r.id
  let node = node
  let universe = DelaySet.all
  let empty = empty
  let top = top
  let union = union
  let inter = inter
  let compl = compl
  let compare_form = compare_form
  let key m = m.key

  let meets m r =
    match r.view with
    | Names p -> not (Letters.is_empty (Letters.inter m.set p))
    | _ -> false

  let eps = eps
  let concat = concat
  let repeat = repeat
  let delays = delays
end)

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
