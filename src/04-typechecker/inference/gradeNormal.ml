(* Normal forms and decisions of open grade expressions. The sort-independent
   part is [Core], instantiated at both sorts in [Make]. *)

type ('c, 'v) atom = Const of 'c | Var of 'v
type ('e, 'a) ordering = { lhs : 'e; rhs : 'e; info : 'a }

(* A fold over the expressions of one sort, by their constants and variable
   atoms. *)
type ('c, 'v, 's) algebra = {
  const : 'c -> 's;
  var : 'v -> 's;
  mul : 's -> 's -> 's;
  join : 's -> 's -> 's;
}

(* What [Core] needs of a sort: its grade, its variable atoms and its
   expressions. *)
module type BASE = sig
  type exp
  type const
  type var

  val compare_var : var -> var -> int
  val one : const
  val top : const
  val mul : const -> const -> const
  val join : const -> const -> const
  val leq : Grades.Grade.bounds -> const -> const -> bool
  val equal : Grades.Grade.bounds -> const -> const -> bool
  val is_top : Grades.Grade.bounds -> const -> bool
  val unit_least : bool
  val commutative : bool

  (* The unit is below the variable atom by the other sort's leastness. *)
  val unit_below_var : var -> bool
  val fold_exp : (const, var, 's) algebra -> exp -> 's
  val exp_of_atom : (const, var) atom -> exp
  val exp_mul : exp -> exp -> exp
  val exp_join : exp -> exp -> exp

  (* The atom a side of a hypothesis is, if it is one. *)
  val as_atom : exp -> (const, var) atom option
  val value : exp -> const option
  val equal_exp : Grades.Grade.bounds -> exp -> exp -> bool
end

(* The first of two searches that succeeds, the second run only if needed
   ([_<∣>_]). *)
let ( <|> ) found next = match found with Some _ -> found | None -> next ()

(* A derivation using no hypothesis, when [holds]. *)
let derived_if holds = if holds then Some [] else None

module Core (S : BASE) = struct
  type exp = S.exp
  type const = S.const
  type var = S.var
  type nonrec atom = (const, var) atom
  type product = atom list
  type sum = product list

  let equal_var v w = S.compare_var v w = 0

  let equal_atom bounds a b =
    match (a, b) with
    | Const c, Const d -> S.equal bounds c d
    | Var v, Var w -> equal_var v w
    | (Const _ | Var _), _ -> false

  let equal_product bounds = List.equal (equal_atom bounds)

  let atom_is_top bounds = function
    | Const c -> S.is_top bounds c
    | Var _ -> false

  (* ---------------------------------------------------------------------- *)
  (* Flattening *)

  (* Consing an atom onto a product: adjacent constants are multiplied, and a
     constant that is the unit dropped. *)
  let rec cons bounds a p =
    match (a, p) with
    | Const c, Const d :: p -> cons bounds (Const (S.mul c d)) p
    | Const c, p when S.equal bounds c S.one -> p
    | a, p -> a :: p

  let app bounds p q = List.fold_right (cons bounds) p q

  (* Every alternative of the one sum against every alternative of the
     other. *)
  let cross bounds s t = List.concat_map (fun p -> List.map (app bounds p) t) s

  (* A repeated alternative is absorbed by its last occurrence. *)
  let nub bounds s =
    List.fold_right
      (fun p s' ->
        if List.exists (equal_product bounds p) s' then s' else p :: s')
      s []

  (* The constant top, or the empty product where the unit is the top. *)
  let is_top bounds = function
    | [] -> S.is_top bounds S.one
    | [ a ] -> atom_is_top bounds a
    | _ -> false

  (* A sum with a top alternative is the top. *)
  let absorb bounds s =
    if List.exists (is_top bounds) s then [ cons bounds (Const S.top) [] ]
    else s

  let flat bounds =
    S.fold_exp
      {
        const = (fun c -> [ cons bounds (Const c) [] ]);
        var = (fun v -> [ [ Var v ] ]);
        mul = (fun s t -> absorb bounds (nub bounds (cross bounds s t)));
        join = (fun s t -> absorb bounds (nub bounds (s @ t)));
      }

  (* A product as its constant followed by its variables in order. *)
  let commute bounds p =
    let c =
      List.fold_right
        (fun a c -> match a with Const d -> S.mul d c | Var _ -> c)
        p S.one
    in
    let vars =
      List.filter_map (function Var v -> Some v | Const _ -> None) p
    in
    cons bounds (Const c)
      (List.map (fun v -> Var v) (List.stable_sort S.compare_var vars))

  let comm_sum bounds s =
    if S.commutative then nub bounds (List.map (commute bounds) s) else s

  let normal bounds e = comm_sum bounds (flat bounds e)

  (* ---------------------------------------------------------------------- *)
  (* Read-back *)

  let rec read_back_product = function
    | [] -> S.exp_of_atom (Const S.one)
    | [ a ] -> S.exp_of_atom a
    | a :: p -> S.exp_mul (S.exp_of_atom a) (read_back_product p)

  let rec read_back = function
    | [] -> invalid_arg "GradeNormal.read_back: empty sum"
    | [ p ] -> read_back_product p
    | p :: s -> S.exp_join (read_back_product p) (read_back s)

  (* ---------------------------------------------------------------------- *)
  (* Grouping *)

  (* A product read as its variables with a constant slot before each and one
     at the end, an empty slot being the unit. *)
  type slots = { pairs : (const * var) list; last : const }

  let skeleton s = List.map snd s.pairs

  let to_slots p =
    let slot = Option.value ~default:S.one in
    let rec go acc = function
      | [] -> { pairs = []; last = slot acc }
      | Const c :: p ->
          go (Some (match acc with None -> c | Some b -> S.mul b c)) p
      | Var v :: p ->
          let s = go None p in
          { s with pairs = (slot acc, v) :: s.pairs }
    in
    go None p

  let of_slots bounds s =
    List.fold_right
      (fun (c, v) p -> cons bounds (Const c) (Var v :: p))
      s.pairs
      (cons bounds (Const s.last) [])

  (* The Grouping read-back [κ c · (ν a · ...)]. *)
  let exp_of_slots s =
    List.fold_right
      (fun (c, v) e ->
        S.exp_mul (S.exp_of_atom (Const c))
          (S.exp_mul (S.exp_of_atom (Var v)) e))
      s.pairs
      (S.exp_of_atom (Const s.last))

  let equal_slots bounds s t =
    List.equal
      (fun (c, v) (d, w) -> S.equal bounds c d && equal_var v w)
      s.pairs t.pairs
    && S.equal bounds s.last t.last

  (* [c₁ ⊔ (c₂ ⊔ … ⊔ cₙ)]. *)
  let rec join_right c = function
    | [] -> c
    | d :: ds -> S.join c (join_right d ds)

  let split_head s =
    match s.pairs with
    | (c, v) :: pairs -> Some (c, v, { s with pairs })
    | [] -> None

  (* A group, its members sharing a skeleton, folded into one alternative:
     with an empty skeleton the join of the constants; otherwise the same first
     slot and the rest folded, or else the same remaining slots and the first
     slot joined. *)
  let rec fold_slots bounds group =
    match group with
    | [] -> None
    | first :: rest -> (
        match first.pairs with
        | [] ->
            Some
              {
                pairs = [];
                last = join_right first.last (List.map (fun s -> s.last) rest);
              }
        | _ :: _ -> (
            match List.filter_map split_head group with
            | [] -> None
            | (c, v, tail) :: split ->
                let same_head () =
                  if List.for_all (fun (d, _, _) -> S.equal bounds c d) split
                  then
                    Option.map
                      (fun s -> { s with pairs = (c, v) :: s.pairs })
                      (fold_slots bounds
                         (tail :: List.map (fun (_, _, t) -> t) split))
                  else None
                in
                let same_tail () =
                  if
                    List.for_all
                      (fun (_, _, t) -> equal_slots bounds t tail)
                      split
                  then
                    Some
                      {
                        tail with
                        pairs =
                          (join_right c (List.map (fun (d, _, _) -> d) split), v)
                          :: tail.pairs;
                      }
                  else None
                in
                same_head () <|> same_tail))

  type group = { skel : var list; members : slots list }

  let skeleton_equal = List.equal equal_var
  let skeleton_less vs ws = List.compare S.compare_var vs ws < 0

  (* An alternative joins its group, unless already there ([add]), or starts
     a group in skeleton order ([insert]). *)
  let rec insert bounds s groups =
    let vs = skeleton s in
    match groups with
    | [] -> [ { skel = vs; members = [ s ] } ]
    | g :: gs when skeleton_equal vs g.skel ->
        let members =
          if List.exists (equal_slots bounds s) g.members then g.members
          else s :: g.members
        in
        { g with members } :: gs
    | g :: gs when skeleton_less vs g.skel ->
        { skel = vs; members = [ s ] } :: g :: gs
    | g :: gs -> g :: insert bounds s gs

  let fold_group bounds g =
    match fold_slots bounds g.members with
    | Some s -> { g with members = [ s ] }
    | None -> g

  let canonical bounds slots =
    List.concat_map
      (fun g -> (fold_group bounds g).members)
      (List.fold_right (insert bounds) slots [])

  let fold_sum bounds s =
    List.map (of_slots bounds) (canonical bounds (List.map to_slots s))

  (* ---------------------------------------------------------------------- *)
  (* Atomic hypotheses *)

  (* Two atoms linked: equal variables, or constants in order. *)
  let link bounds a b =
    match (a, b) with
    | Const c, Const d -> S.leq bounds c d
    | Var v, Var w -> equal_var v w
    | (Const _ | Var _), _ -> false

  module Var_map = Map.Make (struct
    type t = S.var

    let compare = S.compare_var
  end)

  module Int_set = Set.Make (Int)

  (* The atoms reached, each with its chain: a variable at most once, the
     constants newest first. *)
  type 'a reached = {
    vars : 'a list Var_map.t;
    consts : (const * 'a list) list;
  }

  let reached_from = function
    | Var v -> { vars = Var_map.singleton v []; consts = [] }
    | Const c -> { vars = Var_map.empty; consts = [ (c, []) ] }

  let add_reached a used reached =
    match a with
    | Var v -> { reached with vars = Var_map.add v used reached.vars }
    | Const c -> { reached with consts = (c, used) :: reached.consts }

  (* The chain of the newest atom reached linked to [b]. *)
  let find bounds reached b =
    match b with
    | Var v -> Var_map.find_opt v reached.vars
    | Const d ->
        List.find_map
          (fun (c, used) -> if S.leq bounds c d then Some used else None)
          reached.consts

  (* The edges by position, with the positions of those out of each variable
     and of those out of a constant. *)
  type 'a edges = {
    at : (atom * atom * 'a list) array;
    out_vars : int list Var_map.t;
    out_consts : (const * int) list;
  }

  let index edges =
    let add (out_vars, out_consts) (p, (a, _, _)) =
      match a with
      | Var v ->
          let ps = Option.value (Var_map.find_opt v out_vars) ~default:[] in
          (Var_map.add v (p :: ps) out_vars, out_consts)
      | Const c -> (out_vars, (c, p) :: out_consts)
    in
    let out_vars, out_consts =
      List.fold_left add (Var_map.empty, [])
        (List.mapi (fun p e -> (p, e)) edges)
    in
    { at = Array.of_list edges; out_vars; out_consts }

  (* The positions of the edges whose source the atom [a] is linked to. *)
  let out_of bounds edges = function
    | Var v -> Option.value (Var_map.find_opt v edges.out_vars) ~default:[]
    | Const c ->
        List.filter_map
          (fun (d, p) -> if S.leq bounds c d then Some p else None)
          edges.out_consts

  (* What a source reaches, with the chains: rounds along the edges from the
     last to the first, an edge whose source is reached and whose target is
     not adding its target with the chain of the source followed by the edge,
     until a round reaches nothing new. An edge acts at most once, in the
     first round that passes it with its source reached, so a round passes, in
     the same order, only the edges out of atoms newly reached: in the round
     an atom is reached, those before the edge that reached it, the others in
     the next round. This is single-source reachability by semi-naive
     iteration (Bancilhon, On Knowledge Base Management Systems, 1986). *)
  let saturate bounds edges source =
    let rec round reached now next =
      match Int_set.max_elt_opt now with
      | None when Int_set.is_empty next -> reached
      | None -> round reached next Int_set.empty
      | Some p -> (
          let now = Int_set.remove p now in
          let c, d, used = edges.at.(p) in
          match (find bounds reached d, find bounds reached c) with
          | None, Some chain ->
              let schedule (now, next) q =
                if q < p then (Int_set.add q now, next)
                else (now, Int_set.add q next)
              in
              let now, next =
                List.fold_left schedule (now, next) (out_of bounds edges d)
              in
              round (add_reached d (chain @ used) reached) now next
          | Some _, _ | None, None -> round reached now next)
    in
    round (reached_from source)
      (Int_set.of_list (out_of bounds edges source))
      Int_set.empty

  (* The distinct sources of the edges, each with what it reaches, computed
     when first needed: the variables by identity, the constants in order of
     first occurrence. *)
  type 'a table = {
    var_sources : 'a reached Lazy.t Var_map.t;
    const_sources : (const * 'a reached Lazy.t) list;
  }

  let table bounds edges =
    let indexed = lazy (index edges) in
    let from a = lazy (saturate bounds (Lazy.force indexed) a) in
    let add (vars, consts) (a, _, _) =
      match a with
      | Var v when Var_map.mem v vars -> (vars, consts)
      | Var v -> (Var_map.add v (from a) vars, consts)
      | Const c when List.exists (fun (d, _) -> S.equal bounds c d) consts ->
          (vars, consts)
      | Const c -> (vars, (c, from a) :: consts)
    in
    let var_sources, consts = List.fold_left add (Var_map.empty, []) edges in
    { var_sources; const_sources = List.rev consts }

  type 'a context = { bounds : Grades.Grade.bounds; table : 'a table }

  (* Whether [a] reaches [b] directly or along the table's edges. *)
  let reach ctx a b =
    derived_if (link ctx.bounds a b) <|> fun () ->
    match a with
    | Var v ->
        Option.bind (Var_map.find_opt v ctx.table.var_sources) (fun reached ->
            find ctx.bounds (Lazy.force reached) b)
    | Const c ->
        List.find_map
          (fun (d, reached) ->
            if S.leq ctx.bounds c d then find ctx.bounds (Lazy.force reached) b
            else None)
          ctx.table.const_sources

  (* An atom that the top reaches. *)
  let top_leq ctx b = reach ctx (Const S.top) b

  (* Whether the atom [a] is below the atom [b]: linked directly, or [b]
     reached from the top, or [b] reached from [a]. *)
  let atom_leq ctx a b =
    derived_if (link ctx.bounds a b) <|> fun () ->
    top_leq ctx b <|> fun () -> reach ctx a b

  (* Whether the unit is below the atom [b]. *)
  let unit_leq ctx b =
    derived_if S.unit_least <|> fun () ->
    (match b with Var v -> derived_if (S.unit_below_var v) | Const _ -> None)
    <|> fun () -> atom_leq ctx (Const S.one) b

  (* Whether the atom [a] is below the unit. *)
  let leq_unit ctx a = atom_leq ctx a (Const S.one)

  (* ---------------------------------------------------------------------- *)
  (* Products *)

  let remove_at i = List.filteri (fun j _ -> j <> i)

  (* Depth-first search for a sequence of steps to the empty pair; each step
     shortens the pair. The steps out of a pair are tried in the order
     [matches], [skips_right], [skips_left], [absorbs], [merges_right],
     [merges_left], and, where the product commutes, [picks] and [absorbs_at]
     past the right head. [absorbs_at] is tried at its first position only,
     every position leading to the same pair. *)
  let rec embed ctx left right =
    match (left, right) with
    | [], [] -> Some []
    | _ ->
        (* A step, when its condition is decided, to the pair it leads to. *)
        let step decide next =
          match decide () with
          | Some used ->
              let left, right = next () in
              Option.map (List.append used) (embed ctx left right)
          | None -> None
        in
        let matches () =
          match (left, right) with
          | a :: left', b :: right' ->
              step (fun () -> atom_leq ctx a b) (fun () -> (left', right'))
          | _ -> None
        and skips_right () =
          match right with
          | b :: right' ->
              step (fun () -> unit_leq ctx b) (fun () -> (left, right'))
          | [] -> None
        and skips_left () =
          match left with
          | a :: left' ->
              step (fun () -> leq_unit ctx a) (fun () -> (left', right))
          | [] -> None
        and absorbs () =
          match (left, right) with
          | _ :: left', b :: _ ->
              step (fun () -> top_leq ctx b) (fun () -> (left', right))
          | _ -> None
        and merges_right () =
          match right with
          | Const c :: b :: right' ->
              step
                (fun () -> unit_leq ctx b)
                (fun () -> (left, cons ctx.bounds (Const c) right'))
          | _ -> None
        and merges_left () =
          match left with
          | Const c :: a :: left' ->
              step
                (fun () -> leq_unit ctx a)
                (fun () -> (cons ctx.bounds (Const c) left', right))
          | _ -> None
        and picks () =
          match (left, right) with
          | a :: left', b :: right' when S.commutative ->
              let rec from i = function
                | [] -> None
                | b' :: rest ->
                    step
                      (fun () -> atom_leq ctx a b')
                      (fun () -> (left', b :: remove_at i right'))
                    <|> fun () -> from (i + 1) rest
              in
              from 0 right'
          | _ -> None
        and absorbs_at () =
          match (left, right) with
          | _ :: left', _ :: right' when S.commutative ->
              step
                (fun () -> List.find_map (top_leq ctx) right')
                (fun () -> (left', right))
          | _ -> None
        in
        matches () <|> skips_right <|> skips_left <|> absorbs <|> merges_right
        <|> merges_left <|> picks <|> absorbs_at

  (* Some alternative of [t] bounds [p]. *)
  let alt_sum_leq ctx p t = List.find_map (embed ctx p) t

  (* Every alternative of [s] is below [t]. *)
  let sum_leq ctx s t =
    List.fold_left
      (fun found p ->
        Option.bind found (fun used ->
            Option.map (List.append used) (alt_sum_leq ctx p t)))
      (Some []) s

  (* Decides orderings [e ≾ e'] along the given atomic edges, the table of the
     edges shared by the orderings decided. *)
  let decide bounds edges =
    let ctx = { bounds; table = table bounds edges } in
    fun e e' ->
      sum_leq ctx (normal bounds e) (fold_sum bounds (normal bounds e'))

  (* The orderings between two atoms, as edges. *)
  let atomic_edges orderings =
    List.filter_map
      (fun o ->
        match (S.as_atom o.lhs, S.as_atom o.rhs) with
        | Some a, Some b -> Some (a, b, [ o.info ])
        | _ -> None)
      orderings

  (* ---------------------------------------------------------------------- *)
  (* Canonical forms *)

  (* Every alternative strictly below another kept is dropped, and each kept
     one absorbs those below it, ties included. *)
  let prune leq slots =
    let place p kept =
      if List.exists (fun k -> leq p k && not (leq k p)) kept then kept
      else p :: List.filter (fun k -> not (leq k p)) kept
    in
    List.fold_right place slots []

  (* Rounds of folding and pruning, while the sum shrinks. *)
  let maximal bounds leq slots =
    let rec rounds n slots =
      if n = 0 then slots
      else
        let slots' = prune leq (canonical bounds slots) in
        if List.length slots' < List.length slots then rounds (n - 1) slots'
        else slots'
    in
    rounds (List.length slots) slots

  (* Where the unit is least, a product with the top is the top. *)
  let absorb_product bounds p =
    if S.unit_least && List.exists (atom_is_top bounds) p then
      cons bounds (Const S.top) []
    else p

  let canon_sum bounds s =
    let decide = decide bounds [] in
    let leq p p' = Option.is_some (decide (exp_of_slots p) (exp_of_slots p')) in
    List.map (of_slots bounds)
      (maximal bounds leq
         (List.map to_slots (List.map (absorb_product bounds) s)))

  let canon bounds e = read_back (canon_sum bounds (normal bounds e))

  let alternatives bounds e =
    List.map read_back_product (canon_sum bounds (normal bounds e))

  let split bounds o =
    let rhs = canon bounds o.rhs in
    List.map
      (fun lhs -> { lhs; rhs; info = o.info })
      (alternatives bounds o.lhs)

  let canon_orderings bounds orderings =
    List.concat_map (split bounds) orderings

  (* ---------------------------------------------------------------------- *)
  (* The graph of the hypotheses: decisions along it, and refutation *)

  let value = S.value
  let is_atom e = Option.is_some (S.as_atom e)

  let closed_leq bounds e e' =
    match (S.value e, S.value e') with
    | Some c, Some c' -> Some (S.leq bounds c c')
    | _ -> None

  (* An atom that the unit is below: a constant above it, or a variable where
     the unit is least, where {!S.unit_below_var} holds, or among [above]. *)
  let unit_below bounds above = function
    | Const c -> S.leq bounds S.one c
    | Var v ->
        S.unit_least || S.unit_below_var v || List.exists (equal_var v) above

  (* The edges from the factors of each side, given with its normal form, that
     is a single product of two or more atoms, unlabelled: from each atom whose
     co-factors are all above the unit, and from the product of the constants,
     in order, when there are two or more and every variable is above the unit.
     The variables [above] are taken to be above the unit. *)
  let factor_edges bounds above sides =
    let from_factors side = function
      | [ (_ :: _ :: _ as p) ] ->
          let atoms =
            List.filteri
              (fun i _ ->
                List.for_all (unit_below bounds above) (remove_at i p))
              p
          in
          let consts =
            List.filter_map (function Const c -> Some c | Var _ -> None) p
          in
          let vars_above =
            List.for_all
              (function
                | Var _ as a -> unit_below bounds above a | Const _ -> true)
              p
          in
          let product =
            match consts with
            | c :: (_ :: _ as cs) when vars_above ->
                [ Const (List.fold_left S.mul c cs) ]
            | _ -> []
          in
          List.map (fun a -> (S.exp_of_atom a, side, [])) (atoms @ product)
      | _ -> []
    in
    List.concat_map (fun (side, s) -> from_factors side s) sides

  (* The shape of an expression: its structure with every constant alike. *)
  type shape =
    | Shape_const
    | Shape_var of var
    | Shape_mul of shape * shape
    | Shape_join of shape * shape

  let shape =
    S.fold_exp
      {
        const = (fun _ -> Shape_const);
        var = (fun v -> Shape_var v);
        mul = (fun s s' -> Shape_mul (s, s'));
        join = (fun s s' -> Shape_join (s, s'));
      }

  let rec compare_shape s s' =
    match (s, s') with
    | Shape_const, Shape_const -> 0
    | Shape_var v, Shape_var w -> S.compare_var v w
    | Shape_mul (a, b), Shape_mul (a', b')
    | Shape_join (a, b), Shape_join (a', b') ->
        let c = compare_shape a a' in
        if c <> 0 then c else compare_shape b b'
    | Shape_const, _ -> -1
    | _, Shape_const -> 1
    | Shape_var _, _ -> -1
    | _, Shape_var _ -> 1
    | Shape_mul _, _ -> -1
    | _, Shape_mul _ -> 1

  module Shape_map = Map.Make (struct
    type t = shape

    let compare = compare_shape
  end)

  (* Expressions numbered in the order they are added, each once up to
     {!S.equal_exp}, found through their shapes. *)
  type numbering = { count : int; by_shape : (exp * int) list Shape_map.t }

  let no_numbers = { count = 0; by_shape = Shape_map.empty }

  (* The number of an expression equal to [e], if one is numbered. *)
  let number_of bounds numbering e =
    Option.bind
      (Shape_map.find_opt (shape e) numbering.by_shape)
      (fun es ->
        List.find_map
          (fun (e', i) -> if S.equal_exp bounds e e' then Some i else None)
          es)

  (* [e] numbered next, unless an equal expression is numbered. *)
  let add_number bounds numbering e =
    match number_of bounds numbering e with
    | Some _ -> numbering
    | None ->
        {
          count = numbering.count + 1;
          by_shape =
            Shape_map.update (shape e)
              (fun es ->
                Some ((e, numbering.count) :: Option.value es ~default:[]))
              numbering.by_shape;
        }

  (* Expressions numbered in order, and the edges between them. *)
  type 'a numbered = {
    vertices : exp array;
    edges : (int * int * 'a list) list;
    graph : 'a list Reach.graph;
  }

  (* The variables that are vertices reached along the edges from a
     variable-free vertex above the unit. *)
  let vars_reached bounds { vertices; graph; _ } =
    let starts =
      Array.to_seqi vertices
      |> Seq.filter_map (fun (i, e) ->
          match S.value e with
          | Some c when S.leq bounds S.one c -> Some i
          | Some _ | None -> None)
      |> List.of_seq
    in
    let reached = Reach.reached graph starts in
    Array.to_seqi vertices
    |> Seq.filter_map (fun (i, e) ->
        match S.as_atom e with
        | Some (Var v) when reached i -> Some v
        | Some (Var _ | Const _) | None -> None)
    |> List.of_seq

  (* The graph of the orderings and of the [extra] edges between atoms. Its
     vertices are the sides of the edges, in the order of their last
     occurrences, the left side of an edge before its right side, and then
     the sources of the factor edges, each once, compared syntactically
     ({!numbering}). Its edges are the orderings, each labelled with its
     payload, then [extra], followed, when [factors], by the {!factor_edges}
     of the sides. A variable is taken to be above the unit also when the
     graph reaches it from a variable-free vertex above the unit
     ({!vars_reached}); the graph is built again with the variables so found
     until no variable is added. *)
  let graph ~factors ?(extra = []) bounds orderings =
    let given =
      List.map (fun o -> (o.lhs, o.rhs, [ o.info ])) orderings @ extra
    in
    let add (numbering, order) e =
      match number_of bounds numbering e with
      | Some _ -> (numbering, order)
      | None -> (add_number bounds numbering e, e :: order)
    in
    let _, sides =
      List.fold_left
        (fun acc (a, b, _) -> add (add acc b) a)
        (no_numbers, []) (List.rev given)
    in
    let numbering = List.fold_left (add_number bounds) no_numbers sides in
    let index numbering e = Option.get (number_of bounds numbering e) in
    let given =
      List.map
        (fun (a, b, label) -> (index numbering a, index numbering b, label))
        given
    in
    let normals =
      if factors then List.map (fun side -> (side, normal bounds side)) sides
      else []
    in
    let build above =
      let steps = factor_edges bounds above normals in
      let numbering, added =
        List.fold_left (fun acc (a, _, _) -> add acc a) (numbering, []) steps
      in
      let vertices = Array.of_list (sides @ List.rev added) in
      let edges =
        given
        @ List.map
            (fun (a, b, label) -> (index numbering a, index numbering b, label))
            steps
      in
      { vertices; edges; graph = Reach.graph (Array.length vertices) edges }
    in
    let rec grow above =
      let graph = build above in
      let above' = vars_reached bounds graph in
      if List.compare_lengths above' above > 0 then grow above' else graph
    in
    if factors && not S.unit_least then grow [] else build []

  (* The edges between atoms of a graph and, through each vertex that is not
     an atom, from each atom with an edge to it to each atom it reaches along
     vertices that are not atoms. *)
  let atom_edges { vertices; edges; _ } =
    let is_atom i = Option.is_some (S.as_atom vertices.(i)) in
    let atom i = Option.get (S.as_atom vertices.(i)) in
    let indices = List.init (Array.length vertices) Fun.id in
    let within =
      Reach.graph (Array.length vertices)
        (List.filter (fun (i, _, _) -> not (is_atom i)) edges)
    in
    let through w =
      let chain = Reach.chain within w in
      let targets =
        List.filter_map
          (fun j ->
            if is_atom j then Option.map (fun labels -> (j, labels)) (chain j)
            else None)
          indices
      in
      List.concat_map
        (fun (i, j, label) ->
          if j = w && is_atom i then
            List.map
              (fun (k, labels) -> (atom i, atom k, label @ List.concat labels))
              targets
          else [])
        edges
    in
    List.filter_map
      (fun (i, j, label) ->
        if is_atom i && is_atom j then Some (atom i, atom j, label) else None)
      edges
    @ List.concat_map through (List.filter (fun w -> not (is_atom w)) indices)

  (* Decides orderings [e ≾ e'] from [orderings] and the [extra] edges
     between atoms, along the {!graph} with its factor edges: by {!decide}
     along its {!atom_edges} and, where [e] is a vertex, along a chain of the
     graph from [e] to a vertex that is [e'] or is so decided below it. Where
     every side is an atom, the graph has no other edges and adds no chain to
     {!decide}, and is not built. *)
  let decide_graph bounds ~extra orderings =
    let given =
      List.map (fun o -> (o.lhs, o.rhs, [ o.info ])) orderings @ extra
    in
    let atomic =
      List.filter_map
        (fun (a, b, used) ->
          match (S.as_atom a, S.as_atom b) with
          | Some a, Some b -> Some (a, b, used)
          | _ -> None)
        given
    in
    if List.compare_lengths atomic given = 0 then decide bounds atomic
    else
      let numbered = graph ~factors:true ~extra bounds orderings in
      let embed = decide bounds (atom_edges numbered) in
      let leq e e' = if S.equal_exp bounds e e' then Some [] else embed e e' in
      let along e e' =
        Option.bind
          (Array.find_index (S.equal_exp bounds e) numbered.vertices)
          (fun u ->
            let chain = Reach.chain numbered.graph u in
            let via (v, ev) =
              Option.bind (chain v) (fun labels ->
                  Option.map (List.append (List.concat labels)) (leq ev e'))
            in
            Seq.find_map via (Array.to_seqi numbered.vertices))
      in
      fun e e' -> embed e e' <|> fun () -> along e e'

  (* The edges between atoms of the {!graph} of [orderings], with its factor
     edges: the orderings themselves where every side is an atom. *)
  let chain_edges bounds orderings =
    let atomic = atomic_edges orderings in
    if List.compare_lengths atomic orderings = 0 then atomic
    else atom_edges (graph ~factors:true bounds orderings)

  (* The first ordering between two variable-free vertices of the {!graph},
     in the order of the vertices of the left side and then of the right side,
     that fails and joins them by a chain of two or more steps, the shortest
     chain of {!Reach.chain}, with the payloads along it. The chains from each
     variable-free vertex are found by one search. *)
  let failing_chain ~factors bounds orderings =
    let { vertices; graph; _ } = graph ~factors bounds orderings in
    let closed =
      Array.to_seqi vertices
      |> Seq.filter_map (fun (i, e) -> Option.map (fun c -> (i, c)) (S.value e))
      |> List.of_seq
    in
    List.find_map
      (fun (i, c) ->
        let chain = Reach.chain graph i in
        List.find_map
          (fun (j, c') ->
            match chain j with
            | Some (_ :: _ :: _ as labels) when not (S.leq bounds c c') ->
                Some
                  {
                    lhs = vertices.(i);
                    rhs = vertices.(j);
                    info = List.concat labels;
                  }
            | Some _ | None -> None)
          closed)
      closed

  let check_closed ?(factors = true) bounds orderings =
    let fails o = closed_leq bounds o.lhs o.rhs = Some false in
    let direct = List.map (fun o -> { o with info = [ o.info ] }) orderings in
    match
      List.find_opt fails direct <|> fun () ->
      failing_chain ~factors bounds orderings
    with
    | Some failure -> Error failure
    | None ->
        Ok
          (List.filter
             (fun o -> closed_leq bounds o.lhs o.rhs = None)
             orderings)

  let refute_leq_unit bounds e =
    List.find_map
      (List.find_map (function
        | Const c when not (S.leq bounds c S.one) -> Some c
        | Const _ | Var _ -> None))
      (normal bounds e)
end

module Make (X : GradeExp.S) = struct
  module R = X.GS.R
  module E = X.GS.E

  type rho_var = Resource of X.Rho_var.t | Image of X.Eps_var.t

  type 'a hyps = {
    rho_hyps : (X.rho, 'a) ordering list;
    eps_hyps : (X.eps, 'a) ordering list;
  }

  let no_hyps = { rho_hyps = []; eps_hyps = [] }

  module type SORT = sig
    type exp
    type const
    type var
    type product = (const, var) atom list
    type sum = product list

    val normal : Grades.Grade.bounds -> exp -> sum
    val fold_sum : Grades.Grade.bounds -> sum -> sum
    val canon_sum : Grades.Grade.bounds -> sum -> sum
    val read_back_product : product -> exp
    val read_back : sum -> exp
    val canon : Grades.Grade.bounds -> exp -> exp
    val alternatives : Grades.Grade.bounds -> exp -> exp list

    val decide_leq :
      Grades.Grade.bounds -> 'a hyps -> exp -> exp -> 'a list option

    val decide_leq_atomic :
      Grades.Grade.bounds -> 'a hyps -> exp -> exp -> 'a list option

    val split :
      Grades.Grade.bounds -> (exp, 'a) ordering -> (exp, 'a) ordering list

    val canon_orderings :
      Grades.Grade.bounds -> (exp, 'a) ordering list -> (exp, 'a) ordering list

    val value : exp -> const option
    val is_atom : exp -> bool
    val closed_leq : Grades.Grade.bounds -> exp -> exp -> bool option

    val check_closed :
      ?factors:bool ->
      Grades.Grade.bounds ->
      (exp, 'a) ordering list ->
      ((exp, 'a) ordering list, (exp, 'a list) ordering) result

    val refute_leq_unit : Grades.Grade.bounds -> exp -> const option
  end

  module Eps_base = struct
    type exp = X.eps
    type const = E.t
    type var = X.Eps_var.t

    let compare_var = X.Eps_var.compare
    let one = E.one
    let top = E.top
    let mul = E.mul
    let join = E.join
    let leq = E.leq
    let equal = E.equal
    let is_top = E.is_top
    let unit_least = E.unit_least
    let commutative = E.commutative
    let unit_below_var _ = false

    let rec fold_exp alg = function
      | X.Eps_var v -> alg.var v
      | X.Eps_const c -> alg.const c
      | X.Eps_mul (eps, eps') -> alg.mul (fold_exp alg eps) (fold_exp alg eps')
      | X.Eps_join (eps, eps') ->
          alg.join (fold_exp alg eps) (fold_exp alg eps')

    let exp_of_atom = function Const c -> X.Eps_const c | Var v -> X.Eps_var v
    let exp_mul = X.Eps.mul
    let exp_join = X.Eps.join

    let as_atom = function
      | X.Eps_var v -> Some (Var v)
      | X.Eps_const c -> Some (Const c)
      | X.Eps_mul _ | X.Eps_join _ -> None

    let value = X.Eps.value
    let equal_exp = X.Eps.equal
  end

  module Rho_base = struct
    type exp = X.rho
    type const = R.t
    type var = rho_var

    let compare_var v w =
      match (v, w) with
      | Resource x, Resource y -> X.Rho_var.compare x y
      | Resource _, Image _ -> -1
      | Image _, Resource _ -> 1
      | Image x, Image y -> X.Eps_var.compare x y

    let one = R.one
    let top = R.top
    let mul = R.mul
    let join = R.join
    let leq = R.leq
    let equal = R.equal
    let is_top = R.is_top
    let unit_least = R.unit_least
    let commutative = R.commutative

    let unit_below_var = function
      | Image _ -> E.unit_least
      | Resource _ -> false

    (* The image of an effect expression is folded through its constants'
       images and its variables' images. *)
    let rec fold_exp alg = function
      | X.Rho_var v -> alg.var (Resource v)
      | X.Rho_const c -> alg.const c
      | X.Rho_mul (rho, rho') -> alg.mul (fold_exp alg rho) (fold_exp alg rho')
      | X.Rho_join (rho, rho') ->
          alg.join (fold_exp alg rho) (fold_exp alg rho')
      | X.Rho_map eps ->
          Eps_base.fold_exp
            {
              const = (fun c -> alg.const (X.GS.map c));
              var = (fun v -> alg.var (Image v));
              mul = alg.mul;
              join = alg.join;
            }
            eps

    let exp_of_atom = function
      | Const c -> X.Rho_const c
      | Var (Resource v) -> X.Rho_var v
      | Var (Image v) -> X.Rho_map (X.Eps_var v)

    let exp_mul = X.Rho.mul
    let exp_join = X.Rho.join

    let as_atom = function
      | X.Rho_var v -> Some (Var (Resource v))
      | X.Rho_const c -> Some (Const c)
      | X.Rho_map (X.Eps_var v) -> Some (Var (Image v))
      | X.Rho_map (X.Eps_const _ | X.Eps_mul _ | X.Eps_join _)
      | X.Rho_mul _ | X.Rho_join _ ->
          None

    let value = X.Rho.value
    let equal_exp = X.Rho.equal
  end

  module Eps_core = Core (Eps_base)
  module Rho_core = Core (Rho_base)

  module Eps = struct
    include Eps_core

    let decide_leq bounds hyps = decide_graph bounds ~extra:[] hyps.eps_hyps

    let decide_leq_atomic bounds hyps =
      decide bounds (atomic_edges hyps.eps_hyps)
  end

  module Rho = struct
    include Rho_core

    (* The image of an effect atom. *)
    let image = function
      | Const c -> Const (X.GS.map c)
      | Var v -> Var (Image v)

    (* The resource hypotheses and the images of the edges between atoms of
       the effect ones. *)
    let decide_leq bounds hyps =
      let images =
        List.map
          (fun (a, b, used) ->
            ( Rho_base.exp_of_atom (image a),
              Rho_base.exp_of_atom (image b),
              used ))
          (Eps_core.chain_edges bounds hyps.eps_hyps)
      in
      decide_graph bounds ~extra:images hyps.rho_hyps

    (* The resource hypotheses between atoms and the images of the effect
       ones. *)
    let decide_leq_atomic bounds hyps =
      let images =
        List.map
          (fun (a, b, used) -> (image a, image b, used))
          (Eps_core.atomic_edges hyps.eps_hyps)
      in
      decide bounds (atomic_edges hyps.rho_hyps @ images)
  end

  type 'a closed_failure =
    | Rho_failure of (X.rho, 'a list) ordering
    | Eps_failure of (X.eps, 'a list) ordering

  let canon_hyps bounds hyps =
    {
      rho_hyps = Rho.canon_orderings bounds hyps.rho_hyps;
      eps_hyps = Eps.canon_orderings bounds hyps.eps_hyps;
    }

  let check_closed_hyps ?factors bounds hyps =
    match Rho.check_closed ?factors bounds hyps.rho_hyps with
    | Error failure -> Error (Rho_failure failure)
    | Ok rho_hyps -> (
        match Eps.check_closed ?factors bounds hyps.eps_hyps with
        | Error failure -> Error (Eps_failure failure)
        | Ok eps_hyps -> Ok { rho_hyps; eps_hyps })
end
