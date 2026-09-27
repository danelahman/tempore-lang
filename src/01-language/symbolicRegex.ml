module Letters = struct
  type names = Only of string list | Except of string list
  type t = { tick : bool; names : names }

  let equal (p : t) q = p = q
  let compare (p : t) q = Stdlib.compare p q
  let empty = { tick = false; names = Only [] }
  let any = { tick = true; names = Except [] }
  let tick = { tick = true; names = Only [] }
  let name n = { tick = false; names = Only [ n ] }

  (* Set operations on lists in increasing order. *)

  let rec merge xs ys =
    match (xs, ys) with
    | [], zs | zs, [] -> zs
    | x :: xs', y :: ys' ->
        let c = String.compare x y in
        if c < 0 then x :: merge xs' ys
        else if c > 0 then y :: merge xs ys'
        else x :: merge xs' ys'

  let rec meet xs ys =
    match (xs, ys) with
    | [], _ | _, [] -> []
    | x :: xs', y :: ys' ->
        let c = String.compare x y in
        if c < 0 then meet xs' ys
        else if c > 0 then meet xs ys'
        else x :: meet xs' ys'

  let rec minus xs ys =
    match (xs, ys) with
    | [], _ -> []
    | xs, [] -> xs
    | x :: xs', y :: ys' ->
        let c = String.compare x y in
        if c < 0 then x :: minus xs' ys
        else if c > 0 then minus xs ys'
        else minus xs' ys'

  let union_names a b =
    match (a, b) with
    | Only a, Only b -> Only (merge a b)
    | Only a, Except b | Except b, Only a -> Except (minus b a)
    | Except a, Except b -> Except (meet a b)

  let inter_names a b =
    match (a, b) with
    | Only a, Only b -> Only (meet a b)
    | Only a, Except b | Except b, Only a -> Only (minus a b)
    | Except a, Except b -> Except (merge a b)

  let union p q =
    { tick = p.tick || q.tick; names = union_names p.names q.names }

  let inter p q =
    { tick = p.tick && q.tick; names = inter_names p.names q.names }

  let compl p =
    {
      tick = not p.tick;
      names = (match p.names with Only a -> Except a | Except a -> Only a);
    }

  let is_empty p = (not p.tick) && p.names = Only []

  let hash p =
    let names, cofinite =
      match p.names with Only a -> (a, false) | Except a -> (a, true)
    in
    List.fold_left
      (fun h n -> (h * 65599) + Hashtbl.hash n)
      (Hashtbl.hash (p.tick, cofinite))
      names

  (* [least p] is the least letter of [p]: [tick], then the names listed in
     increasing order, then the names not listed. *)
  let least p =
    match p with
    | { tick = true; _ } -> (0, "")
    | { names = Only (n :: _); _ } -> (1, n)
    | _ -> (2, "")

  let order p q = Stdlib.compare (least p, p) (least q, q)
  let mentioned p = match p.names with Only a | Except a -> a

  let partition sets =
    let split block p =
      List.filter
        (fun b -> not (is_empty b))
        [ inter block p; inter block (compl p) ]
    in
    let refine blocks p = List.concat_map (fun b -> split b p) blocks in
    List.sort order (List.fold_left refine [ any ] sets)
end

type t = { id : int; view : view; nullable : bool }
(* [id] numbers the normal forms in the order of their construction. *)

and view =
  | Empty
  | Eps
  | Letters of Letters.t
  | Concat of t * t
  | Union of t list
  | Inter of t list
  | Compl of t
  | Star of t

let view r = r.view
let equal_form r s = r.id = s.id
let hash r = r.id
let by_id r s = Int.compare r.id s.id
let mem_form r rs = List.exists (equal_form r) rs

(** The table of normal forms, each view built of normal forms identified by
    their numbers. *)
module Forms = Hashtbl.Make (struct
  type t = view

  let equal v w =
    match (v, w) with
    | Empty, Empty | Eps, Eps -> true
    | Letters p, Letters q -> Letters.equal p q
    | Concat (r, s), Concat (r', s') -> equal_form r r' && equal_form s s'
    | Union rs, Union rs' | Inter rs, Inter rs' -> List.equal equal_form rs rs'
    | Compl r, Compl r' | Star r, Star r' -> equal_form r r'
    | _ -> false

  let combine tag rs = List.fold_left (fun h r -> (h * 65599) + r.id) tag rs

  let hash = function
    | Empty -> 0
    | Eps -> 1
    | Letters p -> Letters.hash p
    | Concat (r, s) -> combine 2 [ r; s ]
    | Union rs -> combine 3 rs
    | Inter rs -> combine 4 rs
    | Compl r -> combine 5 [ r ]
    | Star r -> combine 6 [ r ]
end)

let forms = Forms.create 4096

let nullable_view = function
  | Empty | Letters _ -> false
  | Eps | Star _ -> true
  | Concat (r, s) -> r.nullable && s.nullable
  | Union rs -> List.exists (fun r -> r.nullable) rs
  | Inter rs -> List.for_all (fun r -> r.nullable) rs
  | Compl r -> not r.nullable

(** [make view] is the normal form of [view], built on its first request. *)
let make view =
  match Forms.find_opt forms view with
  | Some r -> r
  | None ->
      let r =
        { id = Forms.length forms; view; nullable = nullable_view view }
      in
      Forms.add forms view r;
      r

let nullable r = r.nullable

(** {1 Constructions} *)

let empty = make Empty
let eps = make Eps
let letters p = if Letters.is_empty p then empty else make (Letters p)
let top = make (Star (letters Letters.any))

let rec concat r s =
  match (r.view, s.view) with
  | Empty, _ | _, Empty -> empty
  | Eps, _ -> s
  | _, Eps -> r
  | Concat (r1, r2), _ -> concat r1 (concat r2 s)
  | Star _, Star _ when equal_form r s -> r
  | Star _, Concat (s1, _) when equal_form r s1 -> s
  | _ -> make (Concat (r, s))

(** [flatten split rs] is the operands of the n-ary operation of the operands
    [rs], by [split]: [Some rs'] to replace an operand by [rs']. *)
let flatten split rs =
  List.concat_map (fun r -> Option.value (split r) ~default:[ r ]) rs

let letter_set r = match r.view with Letters p -> Some p | _ -> None

(** [one_letter_part r] is the set of the letters of the one-letter words of
    [r], when [r] is a letter set, the complement of one or the repetition of
    one. *)
let one_letter_part r =
  match r.view with
  | Letters p -> Some p
  | Compl { view = Letters p; _ } -> Some (Letters.compl p)
  | Star { view = Letters p; _ } -> Some p
  | _ -> None

(** [merge_letters part combine rs] merges the operands [rs] that [part] maps to
    a letter set into the letter set they combine to by [combine]. *)
let merge_letters part combine rs =
  let sets, others =
    List.partition_map
      (fun r -> match part r with Some p -> Left p | None -> Right r)
      rs
  in
  match sets with
  | [] -> others
  | p :: ps -> letters (List.fold_left combine p ps) :: others

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

let is_top r = equal_form r top
let is_empty_form r = equal_form r empty

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

let union rs =
  let split r =
    match r.view with Union rs -> Some rs | Empty -> Some [] | _ -> None
  in
  let rs = flatten split rs in
  if List.exists is_top rs then top
  else
    let rs = List.sort_uniq by_id (merge_letters letter_set Letters.union rs) in
    let rs = List.filter (fun r -> not (subsumed rs r)) rs in
    if complementary split rs then top
    else match rs with [] -> empty | [ r ] -> r | rs -> make (Union rs)

let inter rs =
  let split r =
    match r.view with
    | Inter rs -> Some rs
    | _ when is_top r -> Some []
    | _ -> None
  in
  let rs = flatten split rs in
  (* The one-letter words of an operand are all it contributes to an
     intersection with a letter set. *)
  let rs =
    if List.exists (fun r -> Option.is_some (letter_set r)) rs then
      merge_letters one_letter_part Letters.inter rs
    else rs
  in
  if List.exists is_empty_form rs then empty
  else if mem_form eps rs then
    if List.for_all (fun r -> r.nullable) rs then eps else empty
  else
    let rs = List.sort_uniq by_id rs in
    if complementary split rs then empty
    else match rs with [] -> top | [ r ] -> r | rs -> make (Inter rs)

let compl r =
  match r.view with
  | Compl s -> s
  | Empty -> top
  | _ when is_top r -> empty
  | _ -> make (Compl r)

let rec star r =
  match r.view with
  | Empty | Eps -> eps
  | Star _ -> r
  | Union rs when mem_form eps rs ->
      star (union (List.filter (fun r -> not (equal_form r eps)) rs))
  | _ -> make (Star r)

(** {1 Traversals} *)

let children r =
  match r.view with
  | Empty | Eps | Letters _ -> []
  | Concat (r, s) -> [ r; s ]
  | Union rs | Inter rs -> rs
  | Compl r | Star r -> [ r ]

(** [letter_sets roots] is the list of the letter sets occurring in [roots],
    each once. *)
let letter_sets roots =
  let seen = Hashtbl.create 64 in
  let rec visit acc r =
    if Hashtbl.mem seen r.id then acc
    else begin
      Hashtbl.add seen r.id ();
      let acc = match r.view with Letters p -> p :: acc | _ -> acc in
      List.fold_left visit acc (children r)
    end
  in
  List.sort_uniq Letters.compare (List.fold_left visit [] roots)

let names r =
  List.sort_uniq String.compare
    (List.concat_map Letters.mentioned (letter_sets [ r ]))

(** {1 Derivatives} *)

let minterms r = Letters.partition (letter_sets [ r ])

type minterm = { set : Letters.t; key : int }
(** A block of a partition, with the number of its normal form as a key. *)

let minterm set = { set; key = (letters set).id }

(* The derivatives computed, by the key of the minterm and the number of the
   expression. *)
let derivatives : (int * int, t) Hashtbl.t = Hashtbl.create 4096

let rec derive m r =
  let key = (m.key, r.id) in
  match Hashtbl.find_opt derivatives key with
  | Some d -> d
  | None ->
      let d = derive_view m r in
      Hashtbl.add derivatives key d;
      d

and derive_view m r =
  match r.view with
  | Empty | Eps -> empty
  | Letters p -> if Letters.is_empty (Letters.inter m.set p) then empty else eps
  | Concat (r1, r2) ->
      let d = concat (derive m r1) r2 in
      if r1.nullable then union [ d; derive m r2 ] else d
  | Union rs -> union (List.map (derive m) rs)
  | Inter rs -> inter (List.map (derive m) rs)
  | Compl r -> compl (derive m r)
  | Star r' -> concat (derive m r') r

let derivative set r = derive (minterm set) r

(** {1 Decisions} *)

(* The emptiness of the expressions explored, by their numbers. *)
let emptiness : (int, bool) Hashtbl.t = Hashtbl.create 4096
let known_empty r = Hashtbl.find_opt emptiness r.id = Some true

(** [search r] is a shortest word of [r], found by breadth-first exploration of
    its derivatives, and [None] if there is none; the derivatives known to be
    empty are not explored, and if no word is found every expression explored is
    recorded as empty. [r] is not nullable. *)
let search r =
  let ms = List.map minterm (minterms r) in
  let seen = Hashtbl.create 64 in
  let fresh d = not (Hashtbl.mem seen d.id || known_empty d) in
  let queue = Queue.create () in
  let rec expand s rev_word = function
    | [] -> None
    | m :: ms ->
        let d = derive m s in
        if not (fresh d) then expand s rev_word ms
        else begin
          Hashtbl.add seen d.id ();
          let rev_word' = m.set :: rev_word in
          if d.nullable then Some (List.rev rev_word')
          else begin
            Queue.push (d, rev_word') queue;
            expand s rev_word ms
          end
        end
  in
  let rec go () =
    match Queue.take_opt queue with
    | None -> None
    | Some (s, rev_word) -> (
        match expand s rev_word ms with Some w -> Some w | None -> go ())
  in
  Hashtbl.add seen r.id ();
  Queue.push (r, []) queue;
  let found = go () in
  if Option.is_none found then
    Hashtbl.iter (fun id () -> Hashtbl.replace emptiness id true) seen
  else Hashtbl.replace emptiness r.id false;
  found

let shortest r =
  if r.nullable then Some [] else if known_empty r then None else search r

(** [inhabited r] is whether some derivative of [r] is nullable, found by
    depth-first exploration of its derivatives; the derivatives known to be
    empty are not explored, and if none is nullable every expression explored is
    recorded as empty. *)
let inhabited r =
  let ms = List.map minterm (minterms r) in
  let seen = Hashtbl.create 64 in
  let fresh d = not (Hashtbl.mem seen d.id || known_empty d) in
  let rec go = function
    | [] -> false
    | d :: _ when d.nullable -> true
    | d :: stack ->
        let next = List.filter fresh (List.map (fun m -> derive m d) ms) in
        List.iter (fun d -> Hashtbl.replace seen d.id ()) next;
        go (next @ stack)
  in
  Hashtbl.add seen r.id ();
  let found = go [ r ] in
  if found then Hashtbl.replace emptiness r.id false
  else Hashtbl.iter (fun id () -> Hashtbl.replace emptiness id true) seen;
  found

let is_empty r =
  match Hashtbl.find_opt emptiness r.id with
  | Some e -> e
  | None -> not (inhabited r)

let subset r s = equal_form r s || is_top s || is_empty (inter [ r; compl s ])

(* The pairs of expressions compared, by their numbers, the lesser first. *)
let equalities : (int * int, bool) Hashtbl.t = Hashtbl.create 1024

(** [bisimilar r s] explores the pairs of derivatives of [r] and [s] by the same
    words, merging the classes of the two expressions of each pair, until two
    expressions of a pair differ in nullability or no pair is left. *)
let bisimilar r s =
  let ms = List.map minterm (Letters.partition (letter_sets [ r; s ])) in
  let parent = Hashtbl.create 64 in
  let rec find x =
    match Hashtbl.find_opt parent x with
    | Some p ->
        let root = find p in
        Hashtbl.replace parent x root;
        root
    | None -> x
  in
  let queue = Queue.create () in
  Queue.push (r, s) queue;
  let rec go () =
    match Queue.take_opt queue with
    | None -> true
    | Some (r, s) ->
        let x = find r.id and y = find s.id in
        if x = y then go ()
        else if r.nullable <> s.nullable then false
        else begin
          Hashtbl.replace parent x y;
          List.iter (fun m -> Queue.push (derive m r, derive m s) queue) ms;
          go ()
        end
  in
  go ()

let equal r s =
  equal_form r s
  || r.nullable = s.nullable
     &&
     let key = if r.id < s.id then (r.id, s.id) else (s.id, r.id) in
     match Hashtbl.find_opt equalities key with
     | Some e -> e
     | None ->
         let e = bisimilar r s in
         Hashtbl.add equalities key e;
         e
