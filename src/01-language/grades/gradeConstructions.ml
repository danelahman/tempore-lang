module type LATTICE = sig
  type t

  val name : string
  val bottom : t
  val top : t
  val join : t -> t -> t
  val leq : t -> t -> bool
  val compare : t -> t -> int
  val hash : t -> int
  val elements : t list
  val of_lit : Grade.lit -> t
  val show : t -> string
end

(* A bounded join-semilattice as a grading monoid, its join the product. *)
module OfLattice (L : LATTICE) = struct
  type t = L.t

  let name = L.name
  let one = L.bottom
  let mul = L.join
  let leq _bounds = L.leq
  let leq_symbol = "<="
  let top = L.top
  let join = L.join

  let of_nat n =
    let (_ : int) = Grade.check_nat L.name n in
    L.bottom

  let equal _bounds l l' = L.leq l l' && L.leq l' l
  let is_top _bounds = L.leq L.top
  let compare = L.compare
  let hash = L.hash
  let counterexample _bounds _ _ = None
  let unit_least = true
  let commutative = true
  let needs_op_bounds = false
  let implied_bounds _bounds _ = None
  let inhabited _bounds _ = true
  let events _ = []
  let of_lit = function Grade.Top -> L.top | lit -> L.of_lit lit
  let of_bounds _ = L.bottom
  let is_atomic _name _ = true
  let show = L.show
  let witnesses _bounds _ = (L.elements, Grade.Complete)
end

(** [intersect b b'] is the intersection of the runtime bounds [b] and [b'],
    either possibly absent. *)
let intersect b b' =
  match (b, b') with
  | Some (lo, hi), Some (lo', hi') -> Some (Int.max lo lo', Int.min hi hi')
  | Some b, None | None, Some b -> Some b
  | None, None -> None

(* The product of two grading monoids, ordered componentwise. *)
module Product (G1 : Grade.S) (G2 : Grade.S) = struct
  type t = G1.t * G2.t

  let name = G1.name ^ "×" ^ G2.name
  let one = (G1.one, G2.one)
  let mul (a, b) (a', b') = (G1.mul a a', G2.mul b b')
  let leq bounds (a, b) (a', b') = G1.leq bounds a a' && G2.leq bounds b b'
  let leq_symbol = if G1.leq_symbol = G2.leq_symbol then G1.leq_symbol else "≾"
  let top = (G1.top, G2.top)
  let join (a, b) (a', b') = (G1.join a a', G2.join b b')
  let of_nat n = (G1.of_nat n, G2.of_nat n)

  let equal bounds (a, b) (a', b') =
    G1.equal bounds a a' && G2.equal bounds b b'

  let is_top bounds (a, b) = G1.is_top bounds a && G2.is_top bounds b

  let compare (a, b) (a', b') =
    match G1.compare a a' with 0 -> G2.compare b b' | c -> c

  let hash (a, b) = Grade.combine (G1.hash a) (G2.hash b)

  let counterexample bounds (a, b) (a', b') =
    match G1.counterexample bounds a a' with
    | Some e -> Some (e, b)
    | None -> Option.map (fun e -> (a, e)) (G2.counterexample bounds b b')

  let unit_least = G1.unit_least && G2.unit_least
  let commutative = G1.commutative && G2.commutative
  let needs_op_bounds = G1.needs_op_bounds || G2.needs_op_bounds

  let implied_bounds bounds (a, b) =
    intersect (G1.implied_bounds bounds a) (G2.implied_bounds bounds b)

  let inhabited bounds (a, b) = G1.inhabited bounds a && G2.inhabited bounds b
  let events (a, b) = List.sort_uniq String.compare (G1.events a @ G2.events b)

  let of_lit = function
    | Grade.Top -> top
    | Grade.Tuple [ l1; l2 ] as lit ->
        let component ordinal name =
          Printf.sprintf "in the %s component ('%s'), " ordinal name
        in
        let a =
          Grade.component_of_lit lit
            ~context:(component "first" G1.name)
            G1.of_lit l1
        in
        let b =
          Grade.component_of_lit lit
            ~context:(component "second" G2.name)
            G2.of_lit l2
        in
        (a, b)
    | lit ->
        Grade.invalid_lit lit
          "grades are pairs '(g1, g2)' of a '%s' and a '%s' grade, not %s"
          G1.name G2.name (Grade.describe_lit lit)

  let of_bounds b = (G1.of_bounds b, G2.of_bounds b)
  let is_atomic name (a, b) = G1.is_atomic name a && G2.is_atomic name b
  let show (a, b) = "(" ^ G1.show a ^ "," ^ G2.show b ^ ")"

  (* An ordering fails iff it fails in one component, at a witness of that
     component when its list is complete, paired with any grade. *)
  let witnesses bounds cs =
    let ws1, complete1 = G1.witnesses bounds (List.map fst cs) in
    let ws2, complete2 = G2.witnesses bounds (List.map snd cs) in
    let completeness =
      match (complete1, complete2) with
      | Grade.Complete, Grade.Complete -> Grade.Complete
      | Grade.Partial, _ | _, Grade.Partial -> Grade.Partial
    in
    (List.concat_map (fun a -> List.map (fun b -> (a, b)) ws2) ws1, completeness)
end

module type SEMILATTICE = sig
  type t

  val name : string
  val bottom : t
  val top : t
  val join : t -> t -> t
  val leq : t -> t -> bool
  val compare : t -> t -> int
  val hash : t -> int
  val of_lit : Grade.lit -> t
  val show : t -> string
end

module type ACTION = sig
  type m
  type n

  val act : m -> n -> n
end

(* The semidirect product of a grading monoid and a semilattice, ordered
   componentwise. *)
module SemiDirect
    (M : Grade.S)
    (N : SEMILATTICE)
    (Act : ACTION with type m = M.t and type n = N.t) =
struct
  type t = M.t * N.t

  let name = M.name ^ "⋉" ^ N.name
  let one = (M.one, N.bottom)
  let mul (m, n) (m', n') = (M.mul m m', N.join n (Act.act m n'))
  let leq bounds (m, n) (m', n') = M.leq bounds m m' && N.leq n n'
  let leq_symbol = if M.leq_symbol = "<=" then "<=" else "≾"
  let top = (M.top, N.top)
  let join (m, n) (m', n') = (M.join m m', N.join n n')
  let of_nat k = (M.of_nat k, N.bottom)

  let equal bounds (m, n) (m', n') =
    M.equal bounds m m' && N.leq n n' && N.leq n' n

  let is_top bounds (m, n) = M.is_top bounds m && N.leq N.top n

  let compare (m, n) (m', n') =
    match M.compare m m' with 0 -> N.compare n n' | c -> c

  let hash (m, n) = Grade.combine (M.hash m) (N.hash n)

  let counterexample bounds (m, n) (m', _) =
    Option.map (fun e -> (e, n)) (M.counterexample bounds m m')

  let unit_least = M.unit_least
  let commutative = false
  let needs_op_bounds = M.needs_op_bounds
  let implied_bounds bounds (m, _) = M.implied_bounds bounds m
  let inhabited bounds (m, _) = M.inhabited bounds m
  let events (m, _) = M.events m

  let of_lit = function
    | Grade.Top -> top
    | lit -> (
        match M.of_lit lit with
        | m -> (m, N.bottom)
        | exception (Grade.Invalid_literal _ as rejection) -> (
            match lit with
            | Grade.Tuple [ l1; l2 ] ->
                let component ordinal name =
                  Printf.sprintf "in the %s component ('%s'), " ordinal name
                in
                let m =
                  Grade.component_of_lit lit ~context:(component "first" M.name)
                    M.of_lit l1
                in
                let n =
                  match l2 with
                  | Grade.Top -> N.top
                  | l2 -> (
                      match N.of_lit l2 with
                      | n -> n
                      | exception Grade.Invalid_literal (_, reason) -> (
                          match M.of_lit l2 with
                          | _ -> raise rejection
                          | exception Grade.Invalid_literal _ ->
                              Grade.invalid_lit lit "%s%s"
                                (component "second" N.name)
                                reason))
                in
                (m, n)
            | _ -> raise rejection))

  let of_bounds b = (M.of_bounds b, N.bottom)
  let is_atomic name (m, _) = M.is_atomic name m

  let show ((m, n) as c) =
    if compare c top = 0 then "⊤"
    else if N.leq n N.bottom then M.show m
    else "(" ^ M.show m ^ "," ^ N.show n ^ ")"

  let witnesses bounds cs =
    let ms, _ = M.witnesses bounds (List.map fst cs) in
    ( List.map (fun m -> (m, N.bottom)) ms @ fst (Grade.sampled mul cs),
      Grade.Partial )
end

(* Maps from names to elements, with a default for the other names. *)
module Indexed = struct
  type 'a t = { named : (string * 'a) list; others : 'a }

  let fresh = "_"
  let at m s = Option.value (List.assoc_opt s m.named) ~default:m.others

  (* Drops the entries equal, by [compare], to the default. *)
  let trim compare m =
    {
      m with
      named = List.filter (fun (_, c) -> compare c m.others <> 0) m.named;
    }

  let by_name (s, _) (s', _) = String.compare s s'

  let of_list ~compare ~others entries =
    trim compare { named = List.sort_uniq by_name entries; others }

  let everywhere c = { named = []; others = c }
  let named m = m.named
  let others m = m.others

  let names ms =
    List.sort_uniq String.compare
      (fresh :: List.concat_map (fun m -> List.map fst m.named) ms)

  (* The names given their own element by [m] or [m']. *)
  let keys m m' =
    List.sort_uniq String.compare (List.map fst m.named @ List.map fst m'.named)

  let map compare f m =
    trim compare
      { named = List.map (fun (s, c) -> (s, f c)) m.named; others = f m.others }

  let map2 compare f m m' =
    trim compare
      {
        named = List.map (fun s -> (s, f (at m s) (at m' s))) (keys m m');
        others = f m.others m'.others;
      }

  let for_all2 p m m' =
    p m.others m'.others
    && List.for_all (fun s -> p (at m s) (at m' s)) (keys m m')

  let for_all p m = p m.others && List.for_all (fun (_, c) -> p c) m.named

  let compare_with compare m m' =
    match compare m.others m'.others with
    | 0 ->
        List.compare
          (fun (s, c) (s', c') ->
            match String.compare s s' with 0 -> compare c c' | d -> d)
          m.named m'.named
    | d -> d

  let hash_with hash m =
    Grade.combine (hash m.others)
      (Grade.hash_list
         (fun (s, c) -> Grade.combine (Hashtbl.hash s) (hash c))
         m.named)

  (* The text [text] without its outer parentheses, if they match. *)
  let unparenthesised text =
    let n = String.length text in
    let rec closes_at depth i =
      if i = n then false
      else
        match text.[i] with
        | '(' -> closes_at (depth + 1) (i + 1)
        | ')' when depth = 1 -> i = n - 1
        | ')' -> closes_at (depth - 1) (i + 1)
        | _ -> closes_at depth (i + 1)
    in
    if n >= 2 && text.[0] = '(' && closes_at 0 0 then String.sub text 1 (n - 2)
    else text

  let show_entry show (s, c) = "(" ^ s ^ "," ^ unparenthesised (show c) ^ ")"

  let show_entries ~is_default show m =
    String.concat ","
      (List.map (show_entry show)
         (m.named @ if is_default m.others then [] else [ (fresh, m.others) ]))

  let show ~is_default show m =
    match m with
    | { named = []; others } -> show others
    | { named = [ _ ]; others } when is_default others ->
        show_entries ~is_default show m
    | m -> "(" ^ show_entries ~is_default show m ^ ")"

  let entry of_lit = function
    | Grade.Tuple (Grade.Name s :: (_ :: _ as rest)) as lit ->
        let component = match rest with [ l ] -> l | ls -> Grade.Tuple ls in
        ( s,
          Grade.component_of_lit lit
            ~context:(Printf.sprintf "in the entry of '%s', " s)
            of_lit component )
    | lit ->
        Grade.invalid_lit lit
          "entries are tuples '(Name, ...)' of a name and its grade, not %s"
          (Grade.describe_lit lit)

  let of_entries ~compare ~others lit entries =
    let sorted = List.sort by_name entries in
    let rec check = function
      | (s, _) :: ((s', _) :: _ as rest) ->
          if String.equal s s' then
            Grade.invalid_lit lit "the name '%s' is listed twice" s
          else check rest
      | [ _ ] | [] ->
          let defaults, named =
            List.partition (fun (s, _) -> String.equal s fresh) sorted
          in
          let others = match defaults with (_, c) :: _ -> c | [] -> others in
          trim compare { named; others }
    in
    check sorted

  (* The entries of the literal [lit]: itself if it is one, its components if
     it is a tuple of them, and none otherwise. *)
  let entries_of_lit = function
    | Grade.Tuple (Grade.Name _ :: _ :: _) as lit -> Some [ lit ]
    | Grade.Tuple (Grade.Tuple (Grade.Name _ :: _) :: _ as lits) -> Some lits
    | _ -> None

  let of_entries_lit ~compare ~default of_lit lit lits =
    of_entries ~compare ~others:default lit
      (List.map (Grade.component_of_lit lit ~context:"" (entry of_lit)) lits)

  let of_lit ~compare ~default ~everywhere:all of_lit lit =
    match entries_of_lit lit with
    | Some lits -> of_entries_lit ~compare ~default of_lit lit lits
    | None -> all (of_lit lit)

  module OfSemilattice (C : SEMILATTICE) = struct
    type nonrec t = C.t t

    let name = C.name ^ " by name"
    let bottom = everywhere C.bottom
    let top = everywhere C.top
    let join = map2 C.compare C.join
    let leq = for_all2 C.leq
    let compare = compare_with C.compare
    let hash = hash_with C.hash
    let is_bottom c = C.compare c C.bottom = 0

    let of_lit = function
      | Grade.Top -> top
      | lit ->
          of_lit ~compare:C.compare ~default:C.bottom ~everywhere C.of_lit lit

    let show m =
      if compare m top = 0 then "⊤" else show ~is_default:is_bottom C.show m
  end

  module Action (C : SEMILATTICE) (A : ACTION with type n = C.t) = struct
    type m = A.m
    type nonrec n = C.t t

    let act a = map C.compare (A.act a)
  end

  module OfGrade (G : Grade.S) = struct
    type nonrec t = G.t t

    let name = G.name ^ " by name"
    let one = everywhere G.one
    let mul = map2 G.compare G.mul
    let leq bounds = for_all2 (G.leq bounds)
    let leq_symbol = G.leq_symbol
    let top = everywhere G.top
    let join = map2 G.compare G.join
    let of_nat n = everywhere (G.of_nat n)
    let equal bounds = for_all2 (G.equal bounds)
    let is_top bounds = for_all (G.is_top bounds)
    let compare = compare_with G.compare
    let hash = hash_with G.hash

    (* A witness at one name, the others keeping the lesser grade. *)
    let counterexample bounds m m' =
      List.find_map
        (fun s ->
          Option.map
            (fun e ->
              trim G.compare
                (if s = fresh then { m with others = e }
                 else
                   {
                     m with
                     named =
                       List.sort_uniq by_name
                         ((s, e) :: List.remove_assoc s m.named);
                   }))
            (G.counterexample bounds (at m s) (at m' s)))
        (names [ m; m' ])

    let unit_least = G.unit_least
    let commutative = G.commutative
    let needs_op_bounds = G.needs_op_bounds
    let implied_bounds _bounds _ = None
    let inhabited bounds = for_all (G.inhabited bounds)

    let events m =
      List.sort_uniq String.compare
        (List.concat_map G.events (m.others :: List.map snd m.named))

    let of_lit = function
      | Grade.Top -> top
      | lit -> of_lit ~compare:G.compare ~default:G.one ~everywhere G.of_lit lit

    let of_bounds b = everywhere (G.of_bounds b)
    let is_atomic name = for_all (G.is_atomic name)
    let is_one c = G.compare c G.one = 0
    let show m = show ~is_default:is_one G.show m

    (* An ordering fails iff it fails at one name, at a witness of the
       component there when its list is complete; the names no constant
       gives its own grade are alike, and [fresh] stands for them. *)
    let witnesses bounds cs =
      let at_name s =
        let ws, completeness =
          G.witnesses bounds (List.map (fun c -> at c s) cs)
        in
        ( List.map
            (fun w -> trim G.compare { named = [ (s, w) ]; others = G.one })
            ws,
          completeness )
      in
      let per_name = List.map at_name (names cs) in
      ( List.concat_map fst per_name,
        if List.for_all (fun (_, c) -> c = Grade.Complete) per_name then
          Grade.Complete
        else Grade.Partial )
  end
end
