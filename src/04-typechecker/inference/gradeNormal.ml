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
  val leq : Language.Grade.bounds -> const -> const -> bool
  val equal : Language.Grade.bounds -> const -> const -> bool
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
  val equal_exp : Language.Grade.bounds -> exp -> exp -> bool
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
    | [] -> S.equal bounds S.one S.top
    | [ Const c ] -> S.equal bounds c S.top
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
     the next round. *)
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

  type 'a context = { bounds : Language.Grade.bounds; table : 'a table }

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

  (* The atomic hypotheses among orderings, as edges. *)
  let edges orderings =
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
    if S.unit_least && List.exists (equal_atom bounds (Const S.top)) p then
      cons bounds (Const S.top) []
    else p

  let canon_sum bounds s =
    let decide = decide bounds [] in
    let leq p p' = Option.is_some (decide (exp_of_slots p) (exp_of_slots p')) in
    List.map (of_slots bounds)
      (maximal bounds leq
         (List.map to_slots (List.map (absorb_product bounds) s)))

  let canon bounds e = read_back (canon_sum bounds (normal bounds e))

  let split bounds o =
    let rhs = canon bounds o.rhs in
    List.map
      (fun p -> { lhs = read_back_product p; rhs; info = o.info })
      (canon_sum bounds (normal bounds o.lhs))

  let canon_orderings bounds orderings =
    List.concat_map (split bounds) orderings

  (* ---------------------------------------------------------------------- *)
  (* Closed orderings and refutation *)

  let value = S.value

  let closed_leq bounds e e' =
    match (S.value e, S.value e') with
    | Some c, Some c' -> Some (S.leq bounds c c')
    | _ -> None

  (* The sides of the orderings, each once, sides compared syntactically. *)
  let sides bounds orderings =
    let equal = S.equal_exp bounds in
    let insert e es = if List.exists (equal e) es then es else e :: es in
    List.fold_right (fun o vs -> insert o.lhs (insert o.rhs vs)) orderings []

  let chains bounds orderings =
    let equal = S.equal_exp bounds in
    let vertices = sides bounds orderings in
    let closure =
      Reach.closure ~equal vertices
        (List.map (fun o -> (o.lhs, o.rhs, o.info)) orderings)
    in
    let closed = List.filter (fun e -> Option.is_some (S.value e)) vertices in
    List.concat_map
      (fun lhs ->
        List.filter_map
          (fun rhs ->
            match Reach.reach closure lhs rhs with
            | Some (_ :: _ :: _ as info) -> Some { lhs; rhs; info }
            | Some ([] | [ _ ]) | None -> None)
          closed)
      closed

  (* Whether some variable-free side of the orderings reaches along them
     another that it is not below. Where no ordering between variable-free
     sides fails, this is whether some chain of {!chains} fails, decided by
     reachability alone. *)
  let chain_fails bounds orderings =
    let vertices = Array.of_list (sides bounds orderings) in
    let index e =
      Option.get (Array.find_index (fun v -> S.equal_exp bounds e v) vertices)
    in
    let edges = List.map (fun o -> (index o.lhs, index o.rhs)) orderings in
    let successors =
      Array.init (Array.length vertices) (fun i ->
          List.filter_map (fun (a, b) -> if a = i then Some b else None) edges)
    in
    let rec visit seen = function
      | [] -> seen
      | i :: rest when Int_set.mem i seen -> visit seen rest
      | i :: rest -> visit (Int_set.add i seen) (successors.(i) @ rest)
    in
    let fails_from i c =
      Int_set.exists
        (fun j ->
          j <> i
          &&
          match S.value vertices.(j) with
          | Some c' -> not (S.leq bounds c c')
          | None -> false)
        (visit Int_set.empty [ i ])
    in
    Seq.exists
      (fun (i, v) ->
        match S.value v with Some c -> fails_from i c | None -> false)
      (Array.to_seqi vertices)

  let check_closed bounds orderings =
    let fails o = closed_leq bounds o.lhs o.rhs = Some false in
    let direct = List.map (fun o -> { o with info = [ o.info ] }) orderings in
    let failure =
      match List.find_opt fails direct with
      | Some failure -> Some failure
      | None when chain_fails bounds orderings ->
          List.find_opt fails (chains bounds orderings)
      | None -> None
    in
    match failure with
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

    val normal : Language.Grade.bounds -> exp -> sum
    val fold_sum : Language.Grade.bounds -> sum -> sum
    val canon_sum : Language.Grade.bounds -> sum -> sum
    val read_back_product : product -> exp
    val read_back : sum -> exp
    val canon : Language.Grade.bounds -> exp -> exp

    val decide_leq :
      Language.Grade.bounds -> 'a hyps -> exp -> exp -> 'a list option

    val split :
      Language.Grade.bounds -> (exp, 'a) ordering -> (exp, 'a) ordering list

    val canon_orderings :
      Language.Grade.bounds ->
      (exp, 'a) ordering list ->
      (exp, 'a) ordering list

    val value : exp -> const option
    val closed_leq : Language.Grade.bounds -> exp -> exp -> bool option

    val chains :
      Language.Grade.bounds ->
      (exp, 'a) ordering list ->
      (exp, 'a list) ordering list

    val check_closed :
      Language.Grade.bounds ->
      (exp, 'a) ordering list ->
      ((exp, 'a) ordering list, (exp, 'a list) ordering) result

    val refute_leq_unit : Language.Grade.bounds -> exp -> const option
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

    let decide_leq bounds hyps = decide bounds (edges hyps.eps_hyps)
  end

  module Rho = struct
    include Rho_core

    (* The image of an effect atom. *)
    let image = function
      | Const c -> Const (X.GS.map c)
      | Var v -> Var (Image v)

    (* The resource hypotheses and the images of the effect ones. *)
    let decide_leq bounds hyps =
      let images =
        List.map
          (fun (a, b, used) -> (image a, image b, used))
          (Eps_core.edges hyps.eps_hyps)
      in
      decide bounds (edges hyps.rho_hyps @ images)
  end

  type 'a closed_failure =
    | Rho_failure of (X.rho, 'a list) ordering
    | Eps_failure of (X.eps, 'a list) ordering

  let canon_hyps bounds hyps =
    {
      rho_hyps = Rho.canon_orderings bounds hyps.rho_hyps;
      eps_hyps = Eps.canon_orderings bounds hyps.eps_hyps;
    }

  let check_closed_hyps bounds hyps =
    match Rho.check_closed bounds hyps.rho_hyps with
    | Error failure -> Error (Rho_failure failure)
    | Ok rho_hyps -> (
        match Eps.check_closed bounds hyps.eps_hyps with
        | Error failure -> Error (Eps_failure failure)
        | Ok eps_hyps -> Ok { rho_hyps; eps_hyps })
end
