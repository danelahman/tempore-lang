(* Reports: a solved definition simplified into a qualified scheme. *)

module Ast = Language.Ast
module TyParam = Ast.TyParamModule
module TyParamMap = Ast.TyParamMap
module TyParamSet = Ast.TyParamSet

module Make (C : Constraint.S) = struct
  module X = C.X
  module R = Residual.Make (C)
  module N = GradeNormal.Make (X)
  module Rho_set = X.Rho_var.Set
  module Eps_set = X.Eps_var.Set

  type context = R.context
  type hyps = R.hyps
  type deferred = R.deferred
  type t = { ty : C.ty; hyps : hyps; obligations : deferred list }

  (* ------------------------------------------------------------------ *)
  (* Unknowns and their occurrences                                      *)
  (* ------------------------------------------------------------------ *)

  (* An unknown of any sort. *)
  type unknown =
    | Ty_unknown of Ast.ty_param
    | Rho_unknown of X.Rho_var.t
    | Eps_unknown of X.Eps_var.t

  let same_param a b = TyParam.compare a b = 0

  let is_param u (ty : C.ty) =
    match (u, ty) with
    | Ty_unknown a, Ast.TyParam b -> same_param a b
    | (Ty_unknown _ | Rho_unknown _ | Eps_unknown _), _ -> false

  let in_rho u rho =
    match u with
    | Ty_unknown _ -> false
    | Rho_unknown k -> X.Rho.mem_rho_var k rho
    | Eps_unknown k -> X.Rho.mem_eps_var k rho

  let in_eps u eps =
    match u with
    | Ty_unknown _ | Rho_unknown _ -> false
    | Eps_unknown k -> X.Eps.mem_var k eps

  (* ------------------------------------------------------------------ *)
  (* Polarity                                                            *)
  (* ------------------------------------------------------------------ *)

  (* Whether some occurrence bounds the unknown above, or below. *)
  type polarity = { above : bool; below : bool }

  let neither = { above = false; below = false }
  let ( ++ ) p q = { above = p.above || q.above; below = p.below || q.below }

  let union_map f items =
    List.fold_left (fun p item -> p ++ f item) neither items

  (* The side of an ordering, or the variance of a position in a type. *)
  type sign = Plus | Minus

  let flip = function Plus -> Minus | Minus -> Plus

  let at sign occurs =
    match sign with
    | Plus -> { above = occurs; below = false }
    | Minus -> { above = false; below = occurs }

  let invariant p =
    let occurs = p.above || p.below in
    { above = occurs; below = occurs }

  let rec in_ty u sign (ty : C.ty) =
    match ty with
    | Ast.TyConst _ -> neither
    | Ast.TyParam _ -> at sign (is_param u ty)
    | Ast.TyTuple tys -> union_map (in_ty u sign) tys
    | Ast.TyApply (_, tys) -> invariant (union_map (in_ty u sign) tys)
    | Ast.TyArrow (ty, cty) -> in_ty u (flip sign) ty ++ in_comp_ty u sign cty
    | Ast.TyBox (rho, ty) -> at (flip sign) (in_rho u rho) ++ in_ty u sign ty
    | Ast.TyHandler (cty, cty') ->
        invariant (in_comp_ty u sign cty) ++ in_comp_ty u sign cty'

  and in_comp_ty u sign (Ast.CompTy (ty, eps)) =
    in_ty u sign ty ++ at sign (in_eps u eps)

  let in_ordering occurs (o : _ GradeNormal.ordering) =
    at Plus (occurs o.lhs) ++ at Minus (occurs o.rhs)

  let in_hyps u (hyps : hyps) =
    union_map (in_ordering (in_rho u)) hyps.rho_hyps
    ++ union_map (in_ordering (in_eps u)) hyps.eps_hyps
    ++ union_map
         (fun (s : R.sub) -> in_ty u Plus s.lhs ++ in_ty u Minus s.rhs)
         hyps.sub_vars
    ++ union_map
         (fun (d : R.disjunction) -> at Plus (in_rho u d.disj_grade))
         hyps.disj_hyps

  (* ------------------------------------------------------------------ *)
  (* Hypotheses                                                          *)
  (* ------------------------------------------------------------------ *)

  let to_residual (hyps : hyps) : R.t =
    {
      rho_orderings = hyps.rho_hyps;
      eps_orderings = hyps.eps_hyps;
      eternals = hyps.eternal_hyps;
      subs = hyps.sub_vars;
      disjunctions = hyps.disj_hyps;
      deferred = [];
    }

  let of_residual (r : R.t) : hyps =
    {
      rho_hyps = r.rho_orderings;
      eps_hyps = r.eps_orderings;
      eternal_hyps = r.eternals;
      sub_vars = r.subs;
      disj_hyps = r.disjunctions;
    }

  let free_hyps hyps = C.free_vars (R.hyps_to_constraint hyps)

  let grades_of (hyps : hyps) : R.reason N.hyps =
    { rho_hyps = hyps.rho_hyps; eps_hyps = hyps.eps_hyps }

  let mem equal lhs rhs orderings =
    List.exists
      (fun (o : _ GradeNormal.ordering) -> equal o.lhs lhs && equal o.rhs rhs)
      orderings

  (* An ordering entailed: one of the hypotheses, or derived from them. Applied
     to [context] and [grades] alone, the decision procedure of the hypotheses
     is shared by the orderings decided. *)
  let entails_rho context (grades : R.reason N.hyps) =
    let bounds = context.Residual.bounds in
    let decide = N.Rho.decide_leq bounds grades in
    fun lhs rhs ->
      mem (X.Rho.equal bounds) lhs rhs grades.rho_hyps
      || N.Rho.closed_leq bounds lhs rhs = Some true
      || Option.is_some (decide lhs rhs)

  let entails_eps context (grades : R.reason N.hyps) =
    let bounds = context.Residual.bounds in
    let decide = N.Eps.decide_leq bounds grades in
    fun lhs rhs ->
      mem (X.Eps.equal bounds) lhs rhs grades.eps_hyps
      || N.Eps.closed_leq bounds lhs rhs = Some true
      || Option.is_some (decide lhs rhs)

  let rec same_ty context (a : C.ty) (b : C.ty) =
    match (a, b) with
    | Ast.TyConst c, Ast.TyConst c' -> c = c'
    | Ast.TyParam a, Ast.TyParam b -> same_param a b
    | Ast.TyApply (name, tys), Ast.TyApply (name', tys') ->
        Ast.TyName.compare name name' = 0 && same_tys context tys tys'
    | Ast.TyTuple tys, Ast.TyTuple tys' -> same_tys context tys tys'
    | Ast.TyArrow (ty, cty), Ast.TyArrow (ty', cty') ->
        same_ty context ty ty' && same_comp_ty context cty cty'
    | Ast.TyBox (rho, ty), Ast.TyBox (rho', ty') ->
        X.Rho.equal context.Residual.bounds rho rho' && same_ty context ty ty'
    | Ast.TyHandler (c1, c2), Ast.TyHandler (c1', c2') ->
        same_comp_ty context c1 c1' && same_comp_ty context c2 c2'
    | ( ( Ast.TyConst _ | Ast.TyParam _ | Ast.TyApply _ | Ast.TyTuple _
        | Ast.TyArrow _ | Ast.TyBox _ | Ast.TyHandler _ ),
        _ ) ->
        false

  and same_tys context tys tys' =
    List.compare_lengths tys tys' = 0
    && List.for_all2 (same_ty context) tys tys'

  and same_comp_ty context (Ast.CompTy (ty, eps)) (Ast.CompTy (ty', eps')) =
    same_ty context ty ty' && X.Eps.equal context.Residual.bounds eps eps'

  (* ------------------------------------------------------------------ *)
  (* Subtyping and eternality atoms                                      *)
  (* ------------------------------------------------------------------ *)

  let edge (s : R.sub) =
    match (s.lhs, s.rhs) with
    | Ast.TyParam a, Ast.TyParam b -> Some (a, b)
    | _, _ -> None

  let edges subs = List.filter_map edge subs

  (* The targets of the edges out of each type unknown, in order. *)
  let successors edges =
    List.fold_right
      (fun (a, b) succ ->
        TyParamMap.update a
          (fun bs -> Some (b :: Option.value bs ~default:[]))
          succ)
      edges TyParamMap.empty

  let targets succ a = Option.value (TyParamMap.find_opt a succ) ~default:[]

  (* The type unknowns reached from [a] along [succ], in none or more
     steps. *)
  let reached succ a =
    let rec visit seen = function
      | [] -> seen
      | v :: rest when TyParamSet.mem v seen -> visit seen rest
      | v :: rest -> visit (TyParamSet.add v seen) (targets succ v @ rest)
    in
    visit TyParamSet.empty [ a ]

  (* Whether [b] is reached from [a] along [edges], in none or more steps. *)
  let reaches edges a b = TyParamSet.mem b (reached (successors edges) a)

  (* The type unknowns joined to [seeds] by [edges] in either direction. *)
  let rec joined edges seeds =
    let grown =
      List.fold_left
        (fun set (a, b) ->
          if TyParamSet.mem a set || TyParamSet.mem b set then
            TyParamSet.add a (TyParamSet.add b set)
          else set)
        seeds edges
    in
    if TyParamSet.equal grown seeds then seeds else joined edges grown

  let eternal_params eternals =
    TyParamSet.of_list
      (List.filter_map
         (fun (e : R.eternal) ->
           match e.eternal_ty with Ast.TyParam a -> Some a | _ -> None)
         eternals)

  (* The type unknowns entailed eternal by [hyps]. *)
  let eternal (hyps : hyps) =
    joined (edges hyps.sub_vars) (eternal_params hyps.eternal_hyps)

  (* ------------------------------------------------------------------ *)
  (* Canonical forms                                                     *)
  (* ------------------------------------------------------------------ *)

  let canon_ty context =
    let bounds = context.Residual.bounds in
    Ast.map_ty ~on_rho:(N.Rho.canon bounds) ~on_eps:(N.Eps.canon bounds)

  let canon_hyps context (hyps : hyps) =
    let bounds = context.Residual.bounds in
    let grades = N.canon_hyps bounds (grades_of hyps) in
    {
      hyps with
      rho_hyps = grades.rho_hyps;
      eps_hyps = grades.eps_hyps;
      disj_hyps =
        List.map
          (fun (d : R.disjunction) ->
            {
              d with
              disj_ty = canon_ty context d.disj_ty;
              disj_grade = N.Rho.canon bounds d.disj_grade;
            })
          hyps.disj_hyps;
    }

  let canon_deferred context (d : deferred) =
    let bounds = context.Residual.bounds in
    {
      d with
      rho_conditions = N.Rho.canon_orderings bounds d.rho_conditions;
      eps_conditions = N.Eps.canon_orderings bounds d.eps_conditions;
    }

  (* ------------------------------------------------------------------ *)
  (* Walks                                                               *)
  (* ------------------------------------------------------------------ *)

  (* The items that [settled ~seen ~rest] does not settle, in order; [seen]
     is the items kept before an item, [rest] those after it. *)
  let walk settled items =
    let rec go seen = function
      | [] -> List.rev seen
      | item :: rest ->
          if settled ~seen ~rest item then go seen rest
          else go (item :: seen) rest
    in
    go [] items

  (* ------------------------------------------------------------------ *)
  (* Disjunctions                                                        *)
  (* ------------------------------------------------------------------ *)

  let below_unit (d : R.disjunction) : R.rho_ordering =
    { lhs = d.disj_grade; rhs = X.Rho.unit; info = d.disj_reason }

  (* The hypotheses [acc] with the disjunction [d] settled against them. *)
  let settle context (d : R.disjunction) (acc : hyps) =
    if entails_rho context (grades_of acc) d.disj_grade X.Rho.unit then acc
    else
      match R.eternal_vars context d.disj_ty with
      | None -> { acc with rho_hyps = acc.rho_hyps @ [ below_unit d ] }
      | Some params ->
          let entailed = eternal acc in
          if List.for_all (fun a -> TyParamSet.mem a entailed) params then acc
          else if
            Option.is_some
              (N.Rho.refute_leq_unit context.Residual.bounds d.disj_grade)
          then
            let atom a : R.eternal =
              { eternal_ty = Ast.TyParam a; eternal_reason = d.disj_reason }
            in
            { acc with eternal_hyps = List.map atom params @ acc.eternal_hyps }
          else { acc with disj_hyps = d :: acc.disj_hyps }

  (* The disjunctions entailed by another dropped: one of the same type with
     a grade entailed above. *)
  let walk_disjunctions context (hyps : hyps) =
    let entails = entails_rho context (grades_of hyps) in
    let entailed ~seen ~rest (d : R.disjunction) =
      List.exists
        (fun (d' : R.disjunction) ->
          same_ty context d.disj_ty d'.disj_ty
          && entails d.disj_grade d'.disj_grade)
        (seen @ rest)
    in
    { hyps with disj_hyps = walk entailed hyps.disj_hyps }

  let settle_all context (hyps : hyps) =
    walk_disjunctions context
      (List.fold_right (settle context) hyps.disj_hyps
         { hyps with disj_hyps = [] })

  (* ------------------------------------------------------------------ *)
  (* Pruning and trimming                                                *)
  (* ------------------------------------------------------------------ *)

  (* The subtyping atoms reached along those kept before them dropped. *)
  let prune_subs subs =
    let keep (kept, succ) s =
      match edge s with
      | Some (a, b) when TyParamSet.mem b (reached succ a) -> (kept, succ)
      | Some (a, b) -> (s :: kept, TyParamMap.add a (b :: targets succ a) succ)
      | None -> (s :: kept, succ)
    in
    List.rev (fst (List.fold_left keep ([], TyParamMap.empty) subs))

  (* The eternality atoms joined to those kept before them dropped. *)
  let prune_eternals subs eternals =
    let edges = edges subs in
    List.rev
      (List.fold_left
         (fun kept (e : R.eternal) ->
           match e.eternal_ty with
           | Ast.TyParam a
             when TyParamSet.mem a (joined edges (eternal_params kept)) ->
               kept
           | _ -> e :: kept)
         [] eternals)

  let repeated equal ~seen ~rest:_ (o : _ GradeNormal.ordering) =
    equal o.lhs o.rhs || mem equal o.lhs o.rhs seen

  let prune context (hyps : hyps) =
    let bounds = context.Residual.bounds in
    let sub_vars = prune_subs hyps.sub_vars in
    {
      hyps with
      sub_vars;
      eternal_hyps = prune_eternals sub_vars hyps.eternal_hyps;
      eps_hyps = walk (repeated (X.Eps.equal bounds)) hyps.eps_hyps;
      rho_hyps = walk (repeated (X.Rho.equal bounds)) hyps.rho_hyps;
    }

  let simplify context hyps =
    prune context (settle_all context (canon_hyps context hyps))

  (* Each atom entailed by the others dropped in turn; on the subtyping atoms
     a greedy minimal equivalent graph, the transitive reduction where they
     are acyclic (Aho, Garey and Ullman, SIAM J. Comput. 1972). *)
  let trim context hyps =
    let hyps = settle_all context hyps in
    let reached ~seen ~rest s =
      match edge s with
      | Some (a, b) -> reaches (edges (seen @ rest)) a b
      | None -> false
    in
    let sub_vars = walk reached hyps.sub_vars in
    let eps_hyps =
      walk
        (fun ~seen ~rest (o : R.eps_ordering) ->
          entails_eps context
            { rho_hyps = []; eps_hyps = seen @ rest }
            o.lhs o.rhs)
        hyps.eps_hyps
    in
    let rho_hyps =
      walk
        (fun ~seen ~rest (o : R.rho_ordering) ->
          entails_rho context { rho_hyps = seen @ rest; eps_hyps } o.lhs o.rhs)
        hyps.rho_hyps
    in
    {
      hyps with
      sub_vars;
      eternal_hyps = prune_eternals sub_vars hyps.eternal_hyps;
      eps_hyps;
      rho_hyps;
    }

  (* ------------------------------------------------------------------ *)
  (* Elimination                                                         *)
  (* ------------------------------------------------------------------ *)

  (* The reported type and hypotheses being reduced. *)
  type state = { ty : C.ty; hyps : hyps }

  (* The state under [sigma]. A substitution of type unknowns alone is applied
     to the types only, leaving the grades and the reasons, which have no type
     unknown, as they are. *)
  let moved (sigma : C.subst) st =
    let ty = C.subst_ty sigma st.ty in
    if
      X.Rho_var.Map.is_empty sigma.grade_subst.rho_subst
      && X.Eps_var.Map.is_empty sigma.grade_subst.eps_subst
    then
      let on_sub (s : R.sub) =
        { s with lhs = C.subst_ty sigma s.lhs; rhs = C.subst_ty sigma s.rhs }
      and on_eternal (e : R.eternal) =
        { e with eternal_ty = C.subst_ty sigma e.eternal_ty }
      and on_disj (d : R.disjunction) =
        { d with disj_ty = C.subst_ty sigma d.disj_ty }
      in
      {
        ty;
        hyps =
          {
            st.hyps with
            sub_vars = List.map on_sub st.hyps.sub_vars;
            eternal_hyps = List.map on_eternal st.hyps.eternal_hyps;
            disj_hyps = List.map on_disj st.hyps.disj_hyps;
          };
      }
    else { ty; hyps = of_residual (R.subst sigma (to_residual st.hyps)) }

  let assign_eps k eps : C.subst =
    {
      C.empty_subst with
      grade_subst =
        { X.empty_subst with eps_subst = X.Eps_var.Map.singleton k eps };
    }

  let assign_rho k rho : C.subst =
    {
      C.empty_subst with
      grade_subst =
        { X.empty_subst with rho_subst = X.Rho_var.Map.singleton k rho };
    }

  let assign_ty a b : C.subst =
    { C.empty_subst with ty_subst = TyParamMap.singleton a (Ast.TyParam b) }

  (* The orderings and subtyping atoms made reflexive dropped. *)
  let apart context st =
    let bounds = context.Residual.bounds in
    let differ equal (o : _ GradeNormal.ordering) = not (equal o.lhs o.rhs) in
    {
      st with
      hyps =
        {
          st.hyps with
          rho_hyps = List.filter (differ (X.Rho.equal bounds)) st.hyps.rho_hyps;
          eps_hyps = List.filter (differ (X.Eps.equal bounds)) st.hyps.eps_hyps;
          sub_vars = List.filter (differ (same_ty context)) st.hyps.sub_vars;
        };
    }

  let decided_rho context = entails_rho context N.no_hyps
  let decided_eps context = entails_eps context N.no_hyps

  let eps_sort context k : _ Bounds.sort =
    {
      equal = X.Eps.equal context.Residual.bounds;
      occurs = in_eps (Eps_unknown k);
      is_unknown =
        (function X.Eps_var k' -> X.Eps_var.equal k k' | _ -> false);
      leq = decided_eps context;
      join = X.Eps.join;
    }

  let rho_sort context k : _ Bounds.sort =
    {
      equal = X.Rho.equal context.Residual.bounds;
      occurs = in_rho (Rho_unknown k);
      is_unknown =
        (function X.Rho_var k' -> X.Rho_var.equal k k' | _ -> false);
      leq = decided_rho context;
      join = X.Rho.join;
    }

  (* The expressions the orderings set against each unknown, in order: the
     right side against an unknown on the left, else the left side against an
     unknown on the right. *)
  let facing (type v) ~(compare : v -> v -> int) ~var_of orderings =
    let module M = Map.Make (struct
      type t = v

      let compare = compare
    end) in
    let add k e facing =
      M.update k (fun es -> Some (e :: Option.value es ~default:[])) facing
    in
    let facing =
      List.fold_right
        (fun (o : _ GradeNormal.ordering) facing ->
          match (var_of o.lhs, var_of o.rhs) with
          | Some k, Some k' when compare k k' <> 0 ->
              add k o.rhs (add k' o.lhs facing)
          | Some k, _ -> add k o.rhs facing
          | None, Some k' -> add k' o.lhs facing
          | None, None -> facing)
        orderings M.empty
    in
    fun k -> Option.value (M.find_opt k facing) ~default:[]

  (* The first expression facing the unknown, an earlier unknown or free of
     it, that the hypotheses equate with it. *)
  let equal_value ~occurs ~earlier ~entails facing unknown =
    List.find_opt
      (fun b ->
        (match earlier b with
          | Some earlier -> earlier
          | None -> not (occurs b))
        && entails unknown b && entails b unknown)
      facing

  let equate_eps context st =
    let entails = entails_eps context (grades_of st.hyps)
    and facing =
      facing ~compare:X.Eps_var.compare
        ~var_of:(function X.Eps_var k -> Some k | _ -> None)
        st.hyps.eps_hyps
    in
    fun k ->
      Option.map
        (fun b -> apart context (moved (assign_eps k b) st))
        (equal_value ~occurs:(in_eps (Eps_unknown k))
           ~earlier:(function
             | X.Eps_var j -> Some (X.Eps_var.compare j k < 0) | _ -> None)
           ~entails (facing k) (X.Eps.var k))

  let equate_rho context st =
    let entails = entails_rho context (grades_of st.hyps)
    and facing =
      facing ~compare:X.Rho_var.compare
        ~var_of:(function X.Rho_var k -> Some k | _ -> None)
        st.hyps.rho_hyps
    in
    fun k ->
      Option.map
        (fun b -> apart context (moved (assign_rho k b) st))
        (equal_value ~occurs:(in_rho (Rho_unknown k))
           ~earlier:(function
             | X.Rho_var j -> Some (X.Rho_var.compare j k < 0) | _ -> None)
           ~entails (facing k) (X.Rho.var k))

  (* Whether a value for [u] is blocked: [pick] holds of the polarity of [u]
     in the hypotheses left or in the reported type. *)
  let blocked pick u st hyps =
    pick (in_hyps u hyps) || pick (in_ty u Plus st.ty)

  let lower_eps context st k =
    let sort = eps_sort context k in
    match Bounds.lows sort st.hyps.eps_hyps with
    | Some { lower = x :: xs; lower_rest } ->
        let hyps = { st.hyps with eps_hyps = lower_rest } in
        if blocked (fun p -> p.below) (Eps_unknown k) st hyps then None
        else
          Some
            (moved (assign_eps k (Bounds.join_all sort x xs)) { st with hyps })
    | Some { lower = []; _ } | None -> None

  let lower_rho context st k =
    let sort = rho_sort context k in
    match Bounds.lows sort st.hyps.rho_hyps with
    | Some { lower = x :: xs; lower_rest } ->
        let hyps = { st.hyps with rho_hyps = lower_rest } in
        if blocked (fun p -> p.below) (Rho_unknown k) st hyps then None
        else
          Some
            (moved (assign_rho k (Bounds.join_all sort x xs)) { st with hyps })
    | Some { lower = []; _ } | None -> None

  let raise_eps context st k =
    match Bounds.ups (eps_sort context k) st.hyps.eps_hyps with
    | Some { cap; upper_rest } ->
        let hyps = { st.hyps with eps_hyps = upper_rest } in
        if blocked (fun p -> p.above) (Eps_unknown k) st hyps then None
        else Some (moved (assign_eps k cap) { st with hyps })
    | None -> None

  let raise_rho context st k =
    match Bounds.ups (rho_sort context k) st.hyps.rho_hyps with
    | Some { cap; upper_rest } ->
        let hyps = { st.hyps with rho_hyps = upper_rest } in
        if blocked (fun p -> p.above) (Rho_unknown k) st hyps then None
        else Some (moved (assign_rho k cap) { st with hyps })
    | None -> None

  (* A type unknown on a cycle of subtyping atoms sent to the representative
     of its component: a fixed member where there is one, else the earliest.
     This is cycle elimination (Fähndrich, Foster, Su and Aiken, PLDI 1998),
     the components by Kosaraju's algorithm ({!Reach.representatives}). *)
  let collapse_cycle context (fixed : C.free) st =
    let edges = edges st.hyps.sub_vars in
    let ends pick = TyParamSet.of_list (List.map pick edges) in
    let vertices =
      TyParamSet.elements (TyParamSet.inter (ends fst) (ends snd))
    in
    let is_fixed a = TyParamSet.mem a fixed.free_tys in
    let order =
      List.filter is_fixed vertices
      @ List.filter (fun a -> not (is_fixed a)) vertices
    in
    let representative =
      Reach.representatives ~compare:TyParam.compare edges order
    in
    List.find_map
      (fun a ->
        if is_fixed a then None
        else
          match representative a with
          | Some r when not (same_param a r) ->
              Some (apart context (moved (assign_ty a r) st))
          | Some _ | None -> None)
      vertices

  (* The first subtyping atom [β <: a], and the others. *)
  let rec lower_bound a before = function
    | [] -> None
    | (s : R.sub) :: after -> (
        match edge s with
        | Some (b, a') when same_param a a' ->
            Some (b, List.rev_append before after)
        | Some _ | None -> lower_bound a (s :: before) after)

  let lower_ty context st a =
    match lower_bound a [] st.hyps.sub_vars with
    | Some (b, rest) when not (same_param a b) ->
        let hyps = { st.hyps with sub_vars = rest } in
        if blocked (fun p -> p.below) (Ty_unknown a) st hyps then None
        else Some (apart context (moved (assign_ty a b) { st with hyps }))
    | Some _ | None -> None

  (* The unknowns of [st] outside [fixed], each sort by creation. *)
  let unknowns (fixed : C.free) st =
    let free = C.union_free (C.free_vars_ty st.ty) (free_hyps st.hyps) in
    ( TyParamSet.elements (TyParamSet.diff free.free_tys fixed.free_tys),
      Rho_set.elements (Rho_set.diff free.free_rhos fixed.free_rhos),
      Eps_set.elements (Eps_set.diff free.free_eps fixed.free_eps) )

  let any_step context fixed (tys, rhos, eps) st =
    let at step unknowns () = List.find_map (step context st) unknowns in
    List.find_map
      (fun step -> step ())
      [
        at equate_eps eps;
        at equate_rho rhos;
        at lower_eps eps;
        at lower_rho rhos;
        at raise_eps eps;
        at raise_rho rhos;
        (fun () -> collapse_cycle context fixed st);
        at lower_ty tys;
      ]

  (* The elimination of unknowns, the lowering and raising steps by polarity
     in the manner of Pottier (Simplifying subtyping constraints, ICFP 1996)
     and of Trifonov and Smith (Subtyping constrained types, SAS 1996). The
     steps are tried at the unknowns of the initial state, which include those
     of every later state: a step replaces an unknown by a part of the
     hypotheses and drops hypotheses, and no step applies at an unknown that
     does not occur in them. *)
  let eliminate context ~fixed ty hyps =
    let st = { ty; hyps } in
    let ((tys, rhos, eps) as unknowns) = unknowns fixed st in
    let rec reduce fuel st =
      if fuel = 0 then st
      else
        match any_step context fixed unknowns st with
        | Some st -> reduce (fuel - 1) st
        | None -> st
    in
    let st = reduce (List.length tys + List.length rhos + List.length eps) st in
    (st.ty, st.hyps)

  (* ------------------------------------------------------------------ *)
  (* Reports and schemes                                                 *)
  (* ------------------------------------------------------------------ *)

  let report context ~fixed ty hyps obligations =
    let fixed =
      List.fold_left
        (fun fixed d -> C.union_free fixed (R.free_vars_deferred d))
        fixed obligations
    in
    let ty, hyps = eliminate context ~fixed ty (simplify context hyps) in
    {
      ty = canon_ty context ty;
      hyps = trim context (canon_hyps context hyps);
      obligations = List.map (canon_deferred context) obligations;
    }

  let scheme ~(fixed : C.free) (report : t) =
    let qualifier =
      C.conj
        (R.hyps_to_constraint report.hyps)
        (C.conj_all (List.map R.deferred_to_constraint report.obligations))
    in
    let free =
      C.union_free (C.free_vars_ty report.ty) (C.free_vars qualifier)
    in
    {
      C.ty_params =
        TyParamSet.elements (TyParamSet.diff free.free_tys fixed.free_tys);
      rho_params =
        Rho_set.elements (Rho_set.diff free.free_rhos fixed.free_rhos);
      eps_params = Eps_set.elements (Eps_set.diff free.free_eps fixed.free_eps);
      qualifier;
      ty = report.ty;
    }
end
