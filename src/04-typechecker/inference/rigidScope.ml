(* Closing a rigid scope: localisation, the split of its atoms, and the retry
   of deferred conditions. *)

module Make (C : Constraint.S) = struct
  module X = C.X
  module R = Residual.Make (C)
  module N = GradeNormal.Make (X)
  module Rho_set = X.Rho_var.Set
  module Eps_set = X.Eps_var.Set

  type residual = R.t

  type scope = {
    rigid : X.Eps_var.t;
    outer_rhos : Rho_set.t;
    outer_eps : Eps_set.t;
  }

  type blocking =
    | Blocking_rho of R.rho_ordering
    | Blocking_eps of R.eps_ordering
    | Blocking_deferred of R.deferred

  type stuck = { stuck_origin : Reason.rigid_origin; blocking : blocking }
  type error = Refused of R.failure | Stuck of stuck

  (* ------------------------------------------------------------------ *)
  (* Unknowns and their occurrences                                      *)
  (* ------------------------------------------------------------------ *)

  (* A grade unknown of either sort. *)
  type unknown = Rho_unknown of X.Rho_var.t | Eps_unknown of X.Eps_var.t

  let in_rho u rho =
    match u with
    | Rho_unknown k -> Rho_set.mem k (X.Rho.free_rho_vars rho)
    | Eps_unknown k -> Eps_set.mem k (X.Rho.free_eps_vars rho)

  let in_eps u eps =
    match u with
    | Rho_unknown _ -> false
    | Eps_unknown k -> Eps_set.mem k (X.Eps.free_vars eps)

  let in_ty u ty =
    let free = C.free_vars_ty ty in
    match u with
    | Rho_unknown k -> Rho_set.mem k free.free_rhos
    | Eps_unknown k -> Eps_set.mem k free.free_eps

  let is_rigid scope k = X.Eps_var.equal k scope.rigid

  let is_local scope = function
    | Rho_unknown k -> not (Rho_set.mem k scope.outer_rhos)
    | Eps_unknown k -> not (Eps_set.mem k scope.outer_eps || is_rigid scope k)

  (* Whether an expression mentions only unknowns outer to the scope and
     rigids of [rigids]. *)
  let outer_rho scope ~rigids rho =
    Rho_set.subset (X.Rho.free_rho_vars rho) scope.outer_rhos
    && Eps_set.for_all
         (fun k -> Eps_set.mem k scope.outer_eps || Eps_set.mem k rigids)
         (X.Rho.free_eps_vars rho)

  let outer_eps scope ~rigids eps =
    Eps_set.for_all
      (fun k -> Eps_set.mem k scope.outer_eps || Eps_set.mem k rigids)
      (X.Eps.free_vars eps)

  (* Whether [u] occurs in no type of [r]. *)
  let clean u (r : residual) =
    not
      (List.exists (fun (e : R.eternal) -> in_ty u e.eternal_ty) r.eternals
      || List.exists (fun (s : R.sub) -> in_ty u s.lhs || in_ty u s.rhs) r.subs
      || List.exists
           (fun (d : R.disjunction) -> in_ty u d.disj_ty)
           r.disjunctions)

  (* Whether [u] occurs in no disjunction's grade of [r]. *)
  let disj_free u (r : residual) =
    not
      (List.exists
         (fun (d : R.disjunction) -> in_rho u d.disj_grade)
         r.disjunctions)

  (* The sides of the deferred conditions: the greater ones, which a lowering
     must leave, or the smaller ones, which a raising must leave. *)
  type side = Greater | Smaller

  let on_side side u (d : R.deferred) =
    let pick (o : _ GradeNormal.ordering) =
      match side with Greater -> o.rhs | Smaller -> o.lhs
    in
    List.exists (fun o -> in_rho u (pick o)) d.rho_conditions
    || List.exists (fun o -> in_eps u (pick o)) d.eps_conditions

  (* Whether a value for [u] keeps every deferred condition: [u] is on no side
     the value moves. *)
  let still side u (r : residual) =
    not (List.exists (on_side side u) r.deferred)

  (* ------------------------------------------------------------------ *)
  (* Decisions at no hypotheses                                          *)
  (* ------------------------------------------------------------------ *)

  let decided_rho context lhs rhs =
    let bounds = context.Residual.bounds in
    match N.Rho.closed_leq bounds lhs rhs with
    | Some leq -> leq
    | None -> Option.is_some (N.Rho.decide_leq bounds N.no_hyps lhs rhs)

  let decided_eps context lhs rhs =
    let bounds = context.Residual.bounds in
    match N.Eps.closed_leq bounds lhs rhs with
    | Some leq -> leq
    | None -> Option.is_some (N.Eps.decide_leq bounds N.no_hyps lhs rhs)

  (* ------------------------------------------------------------------ *)
  (* Bounds of one unknown                                               *)
  (* ------------------------------------------------------------------ *)

  (* How the orderings of one sort are read for one unknown. *)
  type 'e sort = {
    equal : 'e -> 'e -> bool;
    occurs : 'e -> bool;  (** whether the unknown occurs *)
    is_unknown : 'e -> bool;  (** whether the expression is the unknown *)
    leq : 'e -> 'e -> bool;  (** decided at no hypotheses *)
    join : 'e -> 'e -> 'e;
  }

  let eps_sort context k =
    {
      equal = X.Eps.equal context.Residual.bounds;
      occurs = in_eps (Eps_unknown k);
      is_unknown =
        (function X.Eps_var k' -> X.Eps_var.equal k k' | _ -> false);
      leq = decided_eps context;
      join = X.Eps.join;
    }

  let rho_sort context u =
    {
      equal = X.Rho.equal context.Residual.bounds;
      occurs = in_rho u;
      is_unknown =
        (fun rho ->
          match (u, rho) with
          | Rho_unknown k, X.Rho_var k' -> X.Rho_var.equal k k'
          | (Rho_unknown _ | Eps_unknown _), _ -> false);
      leq = decided_rho context;
      join = X.Rho.join;
    }

  (* The lower bounds of the unknown, in order, when each ordering is one of
     them ([x ≾ v], [x] free of [v]), is reflexive, or has [v] on no right
     side. *)
  let lows_of sort orderings =
    List.fold_right
      (fun (o : _ GradeNormal.ordering) bounds ->
        Option.bind bounds (fun bounds ->
            if sort.is_unknown o.rhs && not (sort.occurs o.lhs) then
              Some (o.lhs :: bounds)
            else if sort.equal o.lhs o.rhs || not (sort.occurs o.rhs) then
              Some bounds
            else None))
      orderings (Some [])

  let free_right sort orderings =
    List.for_all
      (fun (o : _ GradeNormal.ordering) ->
        sort.equal o.lhs o.rhs || not (sort.occurs o.rhs))
      orderings

  let free_left sort orderings =
    List.for_all
      (fun (o : _ GradeNormal.ordering) ->
        sort.equal o.lhs o.rhs || not (sort.occurs o.lhs))
      orderings

  (* The first upper bound [U] of the unknown, [v ≾ U] with [U] free of [v],
     such that each ordering is reflexive, has [v] on no left side, or is
     [v ≾ x'] with [x'] the bound or decided above it. *)
  let ups_of sort orderings =
    let caps =
      List.filter_map
        (fun (o : _ GradeNormal.ordering) ->
          if sort.is_unknown o.lhs && not (sort.occurs o.rhs) then Some o.rhs
          else None)
        orderings
    in
    let capped cap (o : _ GradeNormal.ordering) =
      sort.equal o.lhs o.rhs
      || (not (sort.occurs o.lhs))
      || (sort.is_unknown o.lhs && (sort.equal o.rhs cap || sort.leq cap o.rhs))
    in
    List.find_opt (fun cap -> List.for_all (capped cap) orderings) caps

  let join_all sort x xs = List.fold_left sort.join x xs

  (* ------------------------------------------------------------------ *)
  (* The value of one unknown                                            *)
  (* ------------------------------------------------------------------ *)

  (* The orderings a value settles: those with the unknown on their greater
     side, for a lowering; none otherwise. *)
  type drops = Drop_greater | Keep_all

  let first rules = List.find_map (fun rule -> rule ()) rules

  (* Whether [u] occurs on a left side, in a disjunction's grade or in a
     deferred condition. *)
  let occurs_below u (r : residual) =
    List.exists (fun (o : R.eps_ordering) -> in_eps u o.lhs) r.eps_orderings
    || List.exists (fun (o : R.rho_ordering) -> in_rho u o.lhs) r.rho_orderings
    || (not (disj_free u r))
    || List.exists (on_side Greater u) r.deferred
    || List.exists (on_side Smaller u) r.deferred

  (* Whether [u] occurs on a right side or a greater side of a deferred
     condition. *)
  let occurs_above u (r : residual) =
    List.exists (fun (o : R.eps_ordering) -> in_eps u o.rhs) r.eps_orderings
    || List.exists (fun (o : R.rho_ordering) -> in_rho u o.rhs) r.rho_orderings
    || List.exists (on_side Greater u) r.deferred

  let eps_value context k (r : residual) =
    let u = Eps_unknown k in
    let es = eps_sort context k and rs = rho_sort context u in
    let lows = lows_of es r.eps_orderings in
    let free_right_rs = free_right rs r.rho_orderings in
    let lower () =
      match lows with
      | Some (x :: xs) when free_right_rs && still Greater u r ->
          Some (join_all es x xs, Drop_greater)
      | Some _ | None -> None
    and raise () =
      if free_left rs r.rho_orderings && disj_free u r && still Smaller u r then
        Option.map (fun cap -> (cap, Keep_all)) (ups_of es r.eps_orderings)
      else None
    and unit () =
      match lows with
      | Some []
        when X.GS.E.unit_least && free_right_rs && occurs_below u r
             && still Greater u r ->
          Some (X.Eps.unit, Drop_greater)
      | Some _ | None -> None
    and top () =
      if
        free_left es r.eps_orderings
        && free_left rs r.rho_orderings
        && disj_free u r && occurs_above u r && still Smaller u r
      then Some (X.Eps.top, Keep_all)
      else None
    in
    if clean u r then first [ lower; raise; unit; top ] else None

  let rho_value context k (r : residual) =
    let u = Rho_unknown k in
    let rs = rho_sort context u in
    let lows = lows_of rs r.rho_orderings in
    let lower () =
      match lows with
      | Some (x :: xs) when still Greater u r ->
          Some (join_all rs x xs, Drop_greater)
      | Some _ | None -> None
    and raise () =
      if disj_free u r && still Smaller u r then
        Option.map (fun cap -> (cap, Keep_all)) (ups_of rs r.rho_orderings)
      else None
    and unit () =
      match lows with
      | Some [] when X.GS.R.unit_least && occurs_below u r && still Greater u r
        ->
          Some (X.Rho.unit, Drop_greater)
      | Some _ | None -> None
    and top () =
      if
        free_left rs r.rho_orderings
        && disj_free u r && occurs_above u r && still Smaller u r
      then Some (X.Rho.top, Keep_all)
      else None
    in
    if clean u r then first [ lower; raise; unit; top ] else None

  (* ------------------------------------------------------------------ *)
  (* Assignments                                                         *)
  (* ------------------------------------------------------------------ *)

  let empty_grade_subst = X.empty_subst

  let apply (sigma : X.subst) r =
    R.subst { C.empty_subst with grade_subst = sigma } r

  (* [compose sigma sigma'] is [sigma] followed by [sigma']. *)
  let compose (sigma : X.subst) (sigma' : X.subst) : X.subst =
    let union _ v _ = Some v in
    {
      rho_subst =
        X.Rho_var.Map.union union
          (X.Rho_var.Map.map (X.Rho.subst sigma') sigma.rho_subst)
          sigma'.rho_subst;
      eps_subst =
        X.Eps_var.Map.union union
          (X.Eps_var.Map.map (X.Eps.subst sigma') sigma.eps_subst)
          sigma'.eps_subst;
    }

  let assign_eps k eps : X.subst =
    { empty_grade_subst with eps_subst = X.Eps_var.Map.singleton k eps }

  let assign_rho k rho : X.subst =
    { empty_grade_subst with rho_subst = X.Rho_var.Map.singleton k rho }

  (* The residual less the orderings of the unknown's sort with it on the
     greater side. *)
  let drop_greater u (r : residual) =
    match u with
    | Eps_unknown _ ->
        {
          r with
          eps_orderings =
            List.filter
              (fun (o : R.eps_ordering) -> not (in_eps u o.rhs))
              r.eps_orderings;
        }
    | Rho_unknown _ ->
        {
          r with
          rho_orderings =
            List.filter
              (fun (o : R.rho_ordering) -> not (in_rho u o.rhs))
              r.rho_orderings;
        }

  let assigned u sigma drops (acc, r) =
    let r =
      match drops with Drop_greater -> drop_greater u r | Keep_all -> r
    in
    (compose acc sigma, apply sigma r)

  (* ------------------------------------------------------------------ *)
  (* The local unknowns                                                  *)
  (* ------------------------------------------------------------------ *)

  let grades_of_rho rho (rhos, eps) =
    ( Rho_set.union (X.Rho.free_rho_vars rho) rhos,
      Eps_set.union (X.Rho.free_eps_vars rho) eps )

  let grades_of_eps e (rhos, eps) = (rhos, Eps_set.union (X.Eps.free_vars e) eps)

  let grades_of_free (free : C.free) (rhos, eps) =
    (Rho_set.union free.free_rhos rhos, Eps_set.union free.free_eps eps)

  (* The grade unknowns of the orderings, disjunction grades and deferred
     conditions of [r], the rigids of the conditions excepted. *)
  let grade_unknowns (r : residual) =
    let over on_item items acc =
      List.fold_left (fun acc item -> on_item item acc) acc items
    and sides on_exp (o : _ GradeNormal.ordering) acc =
      on_exp o.rhs (on_exp o.lhs acc)
    in
    (Rho_set.empty, Eps_set.empty)
    |> over (sides grades_of_rho) r.rho_orderings
    |> over (sides grades_of_eps) r.eps_orderings
    |> over
         (fun (d : R.disjunction) -> grades_of_rho d.disj_grade)
         r.disjunctions
    |> over (fun d -> grades_of_free (R.free_vars_deferred d)) r.deferred

  let local_unknowns scope r =
    let rhos, eps = grade_unknowns r in
    ( List.filter
        (fun k -> is_local scope (Rho_unknown k))
        (Rho_set.elements rhos),
      List.filter
        (fun k -> is_local scope (Eps_unknown k))
        (Eps_set.elements eps) )

  (* ------------------------------------------------------------------ *)
  (* Normal forms and settled atoms                                      *)
  (* ------------------------------------------------------------------ *)

  let rec eps_has_join = function
    | X.Eps_var _ | X.Eps_const _ -> false
    | X.Eps_mul (eps, eps') -> eps_has_join eps || eps_has_join eps'
    | X.Eps_join _ -> true

  let rec rho_has_join = function
    | X.Rho_var _ | X.Rho_const _ -> false
    | X.Rho_mul (rho, rho') -> rho_has_join rho || rho_has_join rho'
    | X.Rho_join _ -> true
    | X.Rho_map eps -> eps_has_join eps

  (* Whether a left side has a join. *)
  let joined (r : residual) =
    List.exists (fun (o : R.rho_ordering) -> rho_has_join o.lhs) r.rho_orderings
    || List.exists
         (fun (o : R.eps_ordering) -> eps_has_join o.lhs)
         r.eps_orderings

  (* Both sides of each ordering canonical, one ordering per alternative of
     its left side; each disjunction's grade canonical. *)
  let normal context (r : residual) =
    let bounds = context.Residual.bounds in
    {
      r with
      rho_orderings = N.Rho.canon_orderings bounds r.rho_orderings;
      eps_orderings = N.Eps.canon_orderings bounds r.eps_orderings;
      disjunctions =
        List.map
          (fun (d : R.disjunction) ->
            { d with disj_grade = N.Rho.canon bounds d.disj_grade })
          r.disjunctions;
    }

  (* The orderings decided at no hypotheses dropped, and the disjunctions met
     outright; a disjunction whose type is never eternal becomes its grade
     below the unit. *)
  let settle context (r : residual) =
    let rho_orderings =
      List.filter
        (fun (o : R.rho_ordering) -> not (decided_rho context o.lhs o.rhs))
        r.rho_orderings
    and eps_orderings =
      List.filter
        (fun (o : R.eps_ordering) -> not (decided_eps context o.lhs o.rhs))
        r.eps_orderings
    in
    let kept, grades =
      List.fold_right
        (fun (d : R.disjunction) (kept, grades) ->
          if decided_rho context d.disj_grade X.Rho.unit then (kept, grades)
          else
            match R.eternal_vars context d.disj_ty with
            | Some [] -> (kept, grades)
            | Some (_ :: _) -> (d :: kept, grades)
            | None ->
                ( kept,
                  ({
                     lhs = d.disj_grade;
                     rhs = X.Rho.unit;
                     info = d.disj_reason;
                   }
                    : R.rho_ordering)
                  :: grades ))
        r.disjunctions ([], [])
    in
    {
      r with
      rho_orderings = rho_orderings @ grades;
      eps_orderings;
      disjunctions = kept;
    }

  (* ------------------------------------------------------------------ *)
  (* Cycles of whole unknowns                                            *)
  (* ------------------------------------------------------------------ *)

  (* The moves of the members of cycles of [edges] that may move to the
     representative of their component: the first member in the order outer,
     then fixed, then movable, each by creation. *)
  let moves ~compare ~outer ~movable edges =
    let ends pick = List.sort_uniq compare (List.map pick edges) in
    let targets = ends (fun (_, b, ()) -> b) in
    let vertices =
      List.filter
        (fun v -> List.exists (fun w -> compare v w = 0) targets)
        (ends (fun (a, _, ()) -> a))
    in
    let equal v w = compare v w = 0 in
    let closure = Reach.closure ~equal vertices edges in
    let order =
      List.filter outer vertices
      @ List.filter (fun v -> not (outer v || movable v)) vertices
      @ List.filter movable vertices
    in
    List.filter_map
      (fun v ->
        if movable v && Reach.on_cycle closure v then
          match Reach.representative closure order v with
          | Some (rep, _, _) when not (equal rep v) -> Some (v, rep)
          | Some _ | None -> None
        else None)
      vertices

  let collapse scope (r : residual) =
    let eps_edges =
      List.filter_map
        (fun (o : R.eps_ordering) ->
          match (o.lhs, o.rhs) with
          | X.Eps_var a, X.Eps_var b -> Some (a, b, ())
          | _, _ -> None)
        r.eps_orderings
    and rho_edges =
      List.filter_map
        (fun (o : R.rho_ordering) ->
          match (o.lhs, o.rhs) with
          | X.Rho_var a, X.Rho_var b -> Some (a, b, ())
          | _, _ -> None)
        r.rho_orderings
    in
    let movable u = is_local scope u && clean u r in
    let eps_moves =
      moves ~compare:X.Eps_var.compare
        ~outer:(fun k -> not (is_local scope (Eps_unknown k)))
        ~movable:(fun k -> movable (Eps_unknown k))
        eps_edges
    and rho_moves =
      moves ~compare:X.Rho_var.compare
        ~outer:(fun k -> not (is_local scope (Rho_unknown k)))
        ~movable:(fun k -> movable (Rho_unknown k))
        rho_edges
    in
    match (eps_moves, rho_moves) with
    | [], [] -> None
    | _, _ ->
        Some
          {
            X.rho_subst =
              X.Rho_var.Map.of_seq
                (List.to_seq
                   (List.map (fun (v, rep) -> (v, X.Rho.var rep)) rho_moves));
            eps_subst =
              X.Eps_var.Map.of_seq
                (List.to_seq
                   (List.map (fun (v, rep) -> (v, X.Eps.var rep)) eps_moves));
          }

  (* ------------------------------------------------------------------ *)
  (* A set of unknowns raised to the top at once                         *)
  (* ------------------------------------------------------------------ *)

  let is_member members u =
    List.exists
      (fun m ->
        match (m, u) with
        | Rho_unknown k, Rho_unknown k' -> X.Rho_var.equal k k'
        | Eps_unknown k, Eps_unknown k' -> X.Eps_var.equal k k'
        | (Rho_unknown _ | Eps_unknown _), _ -> false)
      members

  let hit_rho members rho = List.exists (fun u -> in_rho u rho) members
  let hit_eps members eps = List.exists (fun u -> in_eps u eps) members

  let tops members =
    List.fold_left
      (fun sigma -> function
        | Rho_unknown k -> compose sigma (assign_rho k X.Rho.top)
        | Eps_unknown k -> compose sigma (assign_eps k X.Eps.top))
      empty_grade_subst members

  (* The first unknown [k] allowed by [ok], not a member, with an ordering
     [x ≾ k] whose [x] is decided the top once the rigid and the members
     are. *)
  let find context scope ~ok members (r : residual) =
    let reached = Eps_unknown scope.rigid :: members in
    let sigma = tops reached in
    let from_eps (o : R.eps_ordering) =
      match o.rhs with
      | X.Eps_var k
        when ok (Eps_unknown k)
             && (not (is_member members (Eps_unknown k)))
             && hit_eps reached o.lhs
             && decided_eps context X.Eps.top (X.Eps.subst sigma o.lhs) ->
          Some (Eps_unknown k)
      | _ -> None
    and from_rho (o : R.rho_ordering) =
      match o.rhs with
      | X.Rho_var k
        when ok (Rho_unknown k)
             && (not (is_member members (Rho_unknown k)))
             && hit_rho reached o.lhs
             && decided_rho context X.Rho.top (X.Rho.subst sigma o.lhs) ->
          Some (Rho_unknown k)
      | _ -> None
    in
    match List.find_map from_eps r.eps_orderings with
    | Some u -> Some u
    | None -> List.find_map from_rho r.rho_orderings

  let rec grow context scope ~ok fuel members r =
    if fuel <= 0 then members
    else
      match find context scope ~ok members r with
      | Some u -> grow context scope ~ok (fuel - 1) (u :: members) r
      | None -> members

  (* An ordering with a member on its left has on its right an expression
     decided the top once the members are, or one of outer unknowns other
     than the rigid and no member. *)
  let up_rho context scope members sigma (o : R.rho_ordering) =
    (not (hit_rho members o.lhs))
    || decided_rho context X.Rho.top (X.Rho.subst sigma o.rhs)
    || outer_rho scope ~rigids:Eps_set.empty o.rhs
       && not (hit_rho members o.rhs)

  let up_eps context scope members sigma (o : R.eps_ordering) =
    (not (hit_eps members o.lhs))
    || decided_eps context X.Eps.top (X.Eps.subst sigma o.rhs)
    || outer_eps scope ~rigids:Eps_set.empty o.rhs
       && not (hit_eps members o.rhs)

  (* Whether a member occurs where no raise may reach it: in a type, a
     disjunction's grade or on a smaller side of a deferred condition. *)
  let fixed u (r : residual) =
    (not (clean u r)) || (not (disj_free u r)) || not (still Smaller u r)

  let usable context scope members (r : residual) =
    let sigma = tops members in
    members <> []
    && List.for_all (up_eps context scope members sigma) r.eps_orderings
    && List.for_all (up_rho context scope members sigma) r.rho_orderings
    && List.for_all (fun u -> not (fixed u r)) members

  (* The members that break a condition of {!usable}. *)
  let bad context scope members (r : residual) =
    let sigma = tops members in
    let failing_eps =
      List.filter
        (fun o -> not (up_eps context scope members sigma o))
        r.eps_orderings
    and failing_rho =
      List.filter
        (fun o -> not (up_rho context scope members sigma o))
        r.rho_orderings
    in
    List.filter
      (fun u ->
        List.exists (fun (o : R.eps_ordering) -> in_eps u o.lhs) failing_eps
        || List.exists (fun (o : R.rho_ordering) -> in_rho u o.lhs) failing_rho
        || fixed u r)
      members

  let raise_set context scope r =
    let rhos, eps = local_unknowns scope r in
    let fuel = List.length rhos + List.length eps in
    let rec select attempts disabled =
      if attempts <= 0 then None
      else
        let ok u = is_local scope u && not (is_member disabled u) in
        let members = grow context scope ~ok fuel [] r in
        if usable context scope members r then Some (tops members)
        else
          match bad context scope members r with
          | [] -> None
          | bad -> select (attempts - 1) (bad @ disabled)
    in
    select (fuel + 1) []

  (* ------------------------------------------------------------------ *)
  (* Rounds                                                              *)
  (* ------------------------------------------------------------------ *)

  (* Each unknown of [unknowns] in turn given the value of the first rule
     that applies to it, if any. *)
  let pass value assign unknowns (acc, r, changed) =
    List.fold_left
      (fun (acc, r, changed) k ->
        match value k r with
        | Some (b, drops) ->
            let acc, r = assign k b drops (acc, r) in
            (acc, r, true)
        | None -> (acc, r, changed))
      (acc, r, changed) unknowns

  let rec rounds context scope n (acc, r) =
    if n <= 0 then (acc, r)
    else
      let r =
        if joined r then settle context (normal context r) else normal context r
      in
      let acc, r, changed =
        match collapse scope r with
        | Some sigma -> (compose acc sigma, apply sigma r, true)
        | None -> (acc, r, false)
      in
      let rhos, eps = local_unknowns scope r in
      let acc, r, changed =
        pass (eps_value context)
          (fun k b drops -> assigned (Eps_unknown k) (assign_eps k b) drops)
          eps (acc, r, changed)
      in
      let acc, r, changed =
        pass (rho_value context)
          (fun k b drops -> assigned (Rho_unknown k) (assign_rho k b) drops)
          rhos (acc, r, changed)
      in
      if changed then rounds context scope (n - 1) (acc, settle context r)
      else
        match raise_set context scope r with
        | Some sigma ->
            rounds context scope (n - 1)
              (compose acc sigma, settle context (apply sigma r))
        | None -> (acc, r)

  let localise context scope r =
    let r = settle context r in
    let rhos, eps = local_unknowns scope r in
    let n = List.length rhos + List.length eps + 1 in
    let acc, r = rounds context scope n (empty_grade_subst, r) in
    (acc, settle context r)

  (* Every unknown local, the rigid a fresh variable occurring nowhere. *)
  let localise_all context r =
    localise context
      {
        rigid = X.Eps_var.fresh_indexed ();
        outer_rhos = Rho_set.empty;
        outer_eps = Eps_set.empty;
      }
      r

  (* ------------------------------------------------------------------ *)
  (* Split                                                               *)
  (* ------------------------------------------------------------------ *)

  (* The fate of an ordering of the scope. *)
  type 'o fate = Keep of 'o | Discharge | Defer of 'o | Block of 'o

  let at_rigid scope value : X.subst = assign_eps scope.rigid value

  (* How the orderings of one sort are split. *)
  type 'e splitting = {
    mentions : 'e -> bool;  (** whether the rigid occurs *)
    decided : 'e -> 'e -> bool;  (** decided at no hypotheses *)
    at_unit : 'e -> 'e;  (** the rigid sent to the unit *)
    at_top : 'e -> 'e;  (** the rigid sent to the top *)
    outer_with_rigid : 'e -> bool;
    outer_without_rigid : 'e -> bool;
    stated : 'e -> 'e -> (C.rho, C.eps) Reason.stated;
  }

  let rho_splitting context scope =
    let rigid = Eps_set.singleton scope.rigid in
    {
      mentions = in_rho (Eps_unknown scope.rigid);
      decided = decided_rho context;
      at_unit = X.Rho.subst (at_rigid scope X.Eps.unit);
      at_top = X.Rho.subst (at_rigid scope X.Eps.top);
      outer_with_rigid = outer_rho scope ~rigids:rigid;
      outer_without_rigid = outer_rho scope ~rigids:Eps_set.empty;
      stated = (fun lhs rhs -> Reason.Stated_rho (lhs, rhs));
    }

  let eps_splitting context scope =
    let rigid = Eps_set.singleton scope.rigid in
    {
      mentions = in_eps (Eps_unknown scope.rigid);
      decided = decided_eps context;
      at_unit = X.Eps.subst (at_rigid scope X.Eps.unit);
      at_top = X.Eps.subst (at_rigid scope X.Eps.top);
      outer_with_rigid = outer_eps scope ~rigids:rigid;
      outer_without_rigid = outer_eps scope ~rigids:Eps_set.empty;
      stated = (fun lhs rhs -> Reason.Stated_eps (lhs, rhs));
    }

  (* The fate of an ordering: kept free of the rigid, with the rigid at the
     unit on a right side or at the top on a left side; discharged; deferred;
     or blocking. *)
  let fate sp (o : (_, C.reason) GradeNormal.ordering) =
    let defer () =
      if sp.outer_with_rigid o.lhs && sp.outer_with_rigid o.rhs then Defer o
      else Block o
    in
    let restated lhs rhs : _ GradeNormal.ordering =
      { lhs; rhs; info = Reason.with_stated (sp.stated o.lhs o.rhs) o.info }
    in
    match (sp.mentions o.lhs, sp.mentions o.rhs) with
    | false, false -> Keep o
    | _, _ when sp.decided o.lhs o.rhs -> Discharge
    | false, true ->
        if X.GS.E.unit_least then Keep (restated o.lhs (sp.at_unit o.rhs))
        else defer ()
    | true, false ->
        if sp.outer_without_rigid o.rhs then
          Keep (restated (sp.at_top o.lhs) o.rhs)
        else defer ()
    | true, true -> defer ()

  (* The kept and deferred orderings, in order, or the first that blocks. *)
  let split_orderings sp orderings =
    List.fold_right
      (fun o acc ->
        Result.bind acc (fun (kept, deferred) ->
            match fate sp o with
            | Keep o -> Ok (o :: kept, deferred)
            | Discharge -> Ok (kept, deferred)
            | Defer o -> Ok (kept, o :: deferred)
            | Block o -> Error o))
      orderings
      (Ok ([], []))

  (* The condition closed over the rigid where it mentions it. *)
  let close_over scope origin (d : R.deferred) =
    let rigid = Eps_unknown scope.rigid in
    if
      List.exists
        (fun (o : R.rho_ordering) -> in_rho rigid o.lhs || in_rho rigid o.rhs)
        d.rho_conditions
      || List.exists
           (fun (o : R.eps_ordering) ->
             in_eps rigid o.lhs || in_eps rigid o.rhs)
           d.eps_conditions
    then { d with rigids = (scope.rigid, origin) :: d.rigids }
    else d

  (* An inner condition carried outward: its unknowns outer, besides the
     rigids. *)
  let carried scope (d : R.deferred) =
    let rigids =
      Eps_set.add scope.rigid (Eps_set.of_list (List.map fst d.rigids))
    in
    List.for_all
      (fun (o : R.rho_ordering) ->
        outer_rho scope ~rigids o.lhs && outer_rho scope ~rigids o.rhs)
      d.rho_conditions
    && List.for_all
         (fun (o : R.eps_ordering) ->
           outer_eps scope ~rigids o.lhs && outer_eps scope ~rigids o.rhs)
         d.eps_conditions

  let split context scope origin (r : residual) =
    let open Result.Syntax in
    let rigid = Eps_unknown scope.rigid in
    let stuck blocking = Stuck { stuck_origin = origin; blocking } in
    let* () =
      if
        List.exists (fun (e : R.eternal) -> in_ty rigid e.eternal_ty) r.eternals
        || List.exists
             (fun (s : R.sub) -> in_ty rigid s.lhs || in_ty rigid s.rhs)
             r.subs
        || List.exists
             (fun (d : R.disjunction) -> in_ty rigid d.disj_ty)
             r.disjunctions
      then Error (Refused (R.Rigid_escape origin))
      else Ok ()
    in
    let* rho_kept, rho_deferred =
      Result.map_error
        (fun o -> stuck (Blocking_rho o))
        (split_orderings (rho_splitting context scope) r.rho_orderings)
    in
    let* eps_kept, eps_deferred =
      Result.map_error
        (fun o -> stuck (Blocking_eps o))
        (split_orderings (eps_splitting context scope) r.eps_orderings)
    in
    let* inner =
      match List.find_opt (fun d -> not (carried scope d)) r.deferred with
      | Some d -> Error (stuck (Blocking_deferred d))
      | None -> Ok (List.map (close_over scope origin) r.deferred)
    in
    let fresh =
      match (rho_deferred, eps_deferred) with
      | [], [] -> []
      | _, _ ->
          [
            close_over scope origin
              {
                origin;
                rigids = [];
                rho_conditions = rho_deferred;
                eps_conditions = eps_deferred;
              };
          ]
    in
    let at_top = X.Rho.subst (at_rigid scope X.Eps.top) in
    Ok
      {
        R.rho_orderings = rho_kept;
        eps_orderings = eps_kept;
        eternals = r.eternals;
        subs = r.subs;
        disjunctions =
          List.map
            (fun (d : R.disjunction) ->
              { d with disj_grade = at_top d.disj_grade })
            r.disjunctions;
        deferred = fresh @ inner;
      }

  (* ------------------------------------------------------------------ *)
  (* Retry                                                               *)
  (* ------------------------------------------------------------------ *)

  (* The grades tried for a rigid: the unit, the top and one time step,
     without repetition. *)
  let candidates context =
    List.fold_left
      (fun cs c ->
        if List.exists (X.GS.E.equal context.Residual.bounds c) cs then cs
        else cs @ [ c ])
      []
      [ X.GS.E.one; X.GS.E.top; X.GS.E.of_nat 1 ]

  (* Every assignment of a candidate to each of [rigids]. *)
  let witnesses context rigids =
    let candidates = candidates context in
    List.fold_right
      (fun rigid tails ->
        List.concat_map
          (fun c -> List.map (fun tail -> (rigid, c) :: tail) tails)
          candidates)
      rigids [ [] ]

  let witness_subst witness : X.subst =
    {
      empty_grade_subst with
      eps_subst =
        X.Eps_var.Map.of_seq
          (List.to_seq
             (List.map (fun (rigid, c) -> (rigid, X.Eps.const c)) witness));
    }

  (* The verdict on one ordering of a condition. *)
  type verdict = Settled | Refuted_at of X.GS.E.t list | Undecided

  let verdict ~decide ~closed_leq ~subst witnesses (o : _ GradeNormal.ordering)
      =
    if decide o.lhs o.rhs then Settled
    else
      match
        List.find_opt
          (fun witness ->
            let sigma = witness_subst witness in
            closed_leq (subst sigma o.lhs) (subst sigma o.rhs) = Some false)
          witnesses
      with
      | Some witness -> Refuted_at (List.map snd witness)
      | None -> Undecided

  (* The orderings left undecided, or the first refuted with its witness. *)
  let sift judge orderings =
    List.fold_right
      (fun o acc ->
        Result.bind acc (fun left ->
            match judge o with
            | Settled -> Ok left
            | Undecided -> Ok (o :: left)
            | Refuted_at witness -> Error (o, witness)))
      orderings (Ok [])

  let retry_condition context (hyps : C.reason N.hyps) (d : R.deferred) =
    let open Result.Syntax in
    let bounds = context.Residual.bounds in
    let witnesses = witnesses context (List.map fst d.rigids) in
    let refuted condition witness =
      R.Refuted_condition { condition; witness }
    in
    let* rho_conditions =
      Result.map_error
        (fun (o, witness) ->
          refuted { d with rho_conditions = [ o ]; eps_conditions = [] } witness)
        (sift
           (verdict
              ~decide:(fun x y ->
                Option.is_some (N.Rho.decide_leq bounds hyps x y))
              ~closed_leq:(N.Rho.closed_leq bounds) ~subst:X.Rho.subst witnesses)
           d.rho_conditions)
    in
    let* eps_conditions =
      Result.map_error
        (fun (o, witness) ->
          refuted { d with rho_conditions = []; eps_conditions = [ o ] } witness)
        (sift
           (verdict
              ~decide:(fun x y ->
                Option.is_some (N.Eps.decide_leq bounds hyps x y))
              ~closed_leq:(N.Eps.closed_leq bounds) ~subst:X.Eps.subst witnesses)
           d.eps_conditions)
    in
    match (rho_conditions, eps_conditions) with
    | [], [] -> Ok []
    | _, _ -> Ok [ { d with rho_conditions; eps_conditions } ]

  let retry context (r : residual) =
    let hyps = { N.rho_hyps = r.rho_orderings; eps_hyps = r.eps_orderings } in
    Result.map
      (fun deferred -> { r with deferred = List.concat deferred })
      (List.fold_right
         (fun d acc ->
           Result.bind acc (fun kept ->
               Result.map (fun d -> d :: kept) (retry_condition context hyps d)))
         r.deferred (Ok []))
end
