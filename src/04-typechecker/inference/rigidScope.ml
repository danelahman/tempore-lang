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
    | Rho_unknown k -> X.Rho.mem_rho_var k rho
    | Eps_unknown k -> X.Rho.mem_eps_var k rho

  let in_eps u eps =
    match u with Rho_unknown _ -> false | Eps_unknown k -> X.Eps.mem_var k eps

  let in_ty u ty =
    Language.Ast.fold_ty
      ~on_param:(fun _ found -> found)
      ~on_rho:(fun rho found -> found || in_rho u rho)
      ~on_eps:(fun eps found -> found || in_eps u eps)
      ty false

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

  let eps_sort context k : _ Bounds.sort =
    {
      equal = X.Eps.equal context.Residual.bounds;
      occurs = in_eps (Eps_unknown k);
      is_unknown =
        (function X.Eps_var k' -> X.Eps_var.equal k k' | _ -> false);
      leq = decided_eps context;
      join = X.Eps.join;
    }

  let rho_sort context u : _ Bounds.sort =
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

  let lows sort orderings =
    Option.map (fun (l : _ Bounds.lows) -> l.lower) (Bounds.lows sort orderings)

  let ups sort orderings =
    Option.map (fun (u : _ Bounds.ups) -> u.cap) (Bounds.ups sort orderings)

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
    let lows = lows es r.eps_orderings in
    let free_right_rs = Bounds.free_right rs r.rho_orderings in
    let lower () =
      match lows with
      | Some (x :: xs) when free_right_rs && still Greater u r ->
          Some (Bounds.join_all es x xs, Drop_greater)
      | Some _ | None -> None
    and raise () =
      if
        Bounds.free_left rs r.rho_orderings
        && disj_free u r && still Smaller u r
      then Option.map (fun cap -> (cap, Keep_all)) (ups es r.eps_orderings)
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
        Bounds.free_left es r.eps_orderings
        && Bounds.free_left rs r.rho_orderings
        && disj_free u r && occurs_above u r && still Smaller u r
      then Some (X.Eps.top, Keep_all)
      else None
    in
    if clean u r then first [ lower; raise; unit; top ] else None

  let rho_value context k (r : residual) =
    let u = Rho_unknown k in
    let rs = rho_sort context u in
    let lows = lows rs r.rho_orderings in
    let lower () =
      match lows with
      | Some (x :: xs) when still Greater u r ->
          Some (Bounds.join_all rs x xs, Drop_greater)
      | Some _ | None -> None
    and raise () =
      if disj_free u r && still Smaller u r then
        Option.map (fun cap -> (cap, Keep_all)) (ups rs r.rho_orderings)
      else None
    and unit () =
      match lows with
      | Some [] when X.GS.R.unit_least && occurs_below u r && still Greater u r
        ->
          Some (X.Rho.unit, Drop_greater)
      | Some _ | None -> None
    and top () =
      if
        Bounds.free_left rs r.rho_orderings
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
    let order =
      List.filter outer vertices
      @ List.filter (fun v -> not (outer v || movable v)) vertices
      @ List.filter movable vertices
    in
    let representative =
      Reach.representatives ~compare
        (List.map (fun (a, b, ()) -> (a, b)) edges)
        order
    in
    List.filter_map
      (fun v ->
        if movable v then
          match representative v with
          | Some rep when compare rep v <> 0 -> Some (v, rep)
          | Some _ | None -> None
        else None)
      vertices

  (* Cycle elimination (Fähndrich, Foster, Su and Aiken, PLDI 1998): the
     local members occurring in no type of each strongly connected component
     of the orderings between whole unknowns sent to its representative, the
     components computed by Kosaraju's algorithm ({!Reach.representatives}). *)
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

  (* Rounds of localisation, until no unknown receives a value, at most [n] of
     them. Each value is a least or a greatest solution for its unknown, chosen
     by the sides it occurs on, as the elimination of {!Report} chooses by
     polarity. *)
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

  (* What the retry reads of the expressions of one sort. *)
  type 'e sort = {
    decide : 'e -> 'e -> bool;
    closed_leq : 'e -> 'e -> bool option;
    subst : X.subst -> 'e -> 'e;
    rho_vars : 'e -> Rho_set.t;
    eps_vars : 'e -> Eps_set.t;
    constants : 'e -> X.GS.R.t list * X.GS.E.t list;
    occurrences : Eps_set.t -> 'e -> int;
  }

  (* The number of occurrences of the variables [ks] in an expression. *)
  let rec eps_occurrences ks = function
    | X.Eps_var k -> if Eps_set.mem k ks then 1 else 0
    | X.Eps_const _ -> 0
    | X.Eps_mul (eps, eps') | X.Eps_join (eps, eps') ->
        eps_occurrences ks eps + eps_occurrences ks eps'

  let rec rho_occurrences ks = function
    | X.Rho_var _ | X.Rho_const _ -> 0
    | X.Rho_map eps -> eps_occurrences ks eps
    | X.Rho_mul (rho, rho') | X.Rho_join (rho, rho') ->
        rho_occurrences ks rho + rho_occurrences ks rho'

  let rho_sort bounds hyps =
    {
      decide = (fun x y -> Option.is_some (N.Rho.decide_leq bounds hyps x y));
      closed_leq = N.Rho.closed_leq bounds;
      subst = X.Rho.subst;
      rho_vars = X.Rho.free_rho_vars;
      eps_vars = X.Rho.free_eps_vars;
      constants = X.Rho.constants;
      occurrences = rho_occurrences;
    }

  let eps_sort bounds hyps =
    {
      decide = (fun x y -> Option.is_some (N.Eps.decide_leq bounds hyps x y));
      closed_leq = N.Eps.closed_leq bounds;
      subst = X.Eps.subst;
      rho_vars = (fun _ -> Rho_set.empty);
      eps_vars = X.Eps.free_vars;
      constants = (fun eps -> ([], X.Eps.constants eps));
      occurrences = eps_occurrences;
    }

  (* The grades tried for a rigid of an ordering with the constants
     [(rcs, ecs)] and at most [degree] occurrences of the rigids on either
     side: the unit, the top and the grade of one delay step, without repetition, then the
     witnesses the grades supply, with their completeness. *)
  let candidates context ~degree (rcs, ecs) =
    let bounds = context.Residual.bounds in
    let base =
      List.fold_left
        (fun cs c ->
          if List.exists (X.GS.E.equal bounds c) cs then cs else cs @ [ c ])
        []
        [ X.GS.E.one; X.GS.E.top; X.GS.E.of_nat 1 ]
    in
    let supplied, completeness = X.GS.witnesses ~degree bounds rcs ecs in
    (base @ supplied, completeness)

  (* Every assignment of a candidate to each of [rigids], lazily. *)
  let assignments candidates rigids =
    List.fold_right
      (fun rigid tails ->
        Seq.flat_map
          (fun c -> Seq.map (fun tail -> (rigid, c) :: tail) tails)
          (List.to_seq candidates))
      rigids (Seq.return [])

  let witness_subst assignment : X.subst =
    {
      empty_grade_subst with
      eps_subst =
        X.Eps_var.Map.of_seq
          (List.to_seq
             (List.map (fun (rigid, c) -> (rigid, X.Eps.const c)) assignment));
    }

  (* An ordering evaluated at a sequence of assignments: the first at which
     it fails, else whether it holds at every one. *)
  type search = Fails_at of (X.Eps_var.t * X.GS.E.t) list | Holds | Open

  let rec search holds_at found assignments =
    match assignments () with
    | Seq.Nil -> found
    | Seq.Cons (a, rest) -> (
        match holds_at a with
        | Some false -> Fails_at a
        | Some true -> search holds_at found rest
        | None -> search holds_at Open rest)

  (* The verdict on one ordering of a condition. *)
  type verdict = Settled | Refuted_at of X.GS.E.t list | Undecided

  (* An ordering decided from the hypotheses is settled. One whose unknowns
     are rigids of [rigids] alone is evaluated at every assignment of
     candidates to the rigids it mentions: it is refuted at the first that
     fails, the other rigids at the unit, and settled when it holds at all of
     them and mentions no rigid, or one whose candidates are complete. *)
  let verdict context sort rigids (o : _ GradeNormal.ordering) =
    let eps_vars = Eps_set.union (sort.eps_vars o.lhs) (sort.eps_vars o.rhs) in
    let rho_vars = Rho_set.union (sort.rho_vars o.lhs) (sort.rho_vars o.rhs) in
    if sort.decide o.lhs o.rhs then Settled
    else if
      not
        (Rho_set.is_empty rho_vars
        && Eps_set.subset eps_vars (Eps_set.of_list rigids))
    then Undecided
    else
      let mentioned = List.filter (fun k -> Eps_set.mem k eps_vars) rigids in
      let rcs, ecs = sort.constants o.lhs
      and rcs', ecs' = sort.constants o.rhs in
      let degree =
        let ks = Eps_set.of_list rigids in
        Int.max (sort.occurrences ks o.lhs) (sort.occurrences ks o.rhs)
      in
      let candidates, completeness =
        candidates context ~degree (rcs @ rcs', ecs @ ecs')
      in
      let holds_at a =
        let sigma = witness_subst a in
        sort.closed_leq (sort.subst sigma o.lhs) (sort.subst sigma o.rhs)
      in
      let value a k =
        Option.value ~default:X.GS.E.one
          (List.find_map
             (fun (k', c) -> if X.Eps_var.equal k k' then Some c else None)
             a)
      in
      match
        ( search holds_at Holds (assignments candidates mentioned),
          mentioned,
          completeness )
      with
      | Fails_at a, _, _ -> Refuted_at (List.map (value a) rigids)
      | Holds, [], _ | Holds, [ _ ], Grades.Grade.Complete -> Settled
      | Holds, _, _ | Open, _, _ -> Undecided

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
    let rigids = List.map fst d.rigids in
    let refuted condition witness =
      R.Refuted_condition { condition; witness }
    in
    let* rho_conditions =
      Result.map_error
        (fun (o, witness) ->
          refuted { d with rho_conditions = [ o ]; eps_conditions = [] } witness)
        (sift (verdict context (rho_sort bounds hyps) rigids) d.rho_conditions)
    in
    let* eps_conditions =
      Result.map_error
        (fun (o, witness) ->
          refuted { d with rho_conditions = []; eps_conditions = [ o ] } witness)
        (sift (verdict context (eps_sort bounds hyps) rigids) d.eps_conditions)
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

  (* ------------------------------------------------------------------ *)
  (* Closed instances                                                    *)
  (* ------------------------------------------------------------------ *)

  (* An atom a closed instance must meet. *)
  type item =
    | Rho_item of R.rho_ordering
    | Eps_item of R.eps_ordering
    | Condition of R.deferred

  let no_grades = (Rho_set.empty, Eps_set.empty)

  (* The grade unknowns of an item, the rigids of a condition excepted. *)
  let item_unknowns = function
    | Rho_item o -> grades_of_rho o.rhs (grades_of_rho o.lhs no_grades)
    | Eps_item o -> grades_of_eps o.rhs (grades_of_eps o.lhs no_grades)
    | Condition d -> grades_of_free (R.free_vars_deferred d) no_grades

  let shares (rhos, eps) (rhos', eps') =
    not (Rho_set.disjoint rhos rhos' && Eps_set.disjoint eps eps')

  let union_grades (rhos, eps) (rhos', eps') =
    (Rho_set.union rhos rhos', Eps_set.union eps eps')

  (* The sides of the orderings of an item, each read by [on_rho] or
     [on_eps]. *)
  let item_sides ~on_rho ~on_eps = function
    | Rho_item o -> [ on_rho o.lhs; on_rho o.rhs ]
    | Eps_item o -> [ on_eps o.lhs; on_eps o.rhs ]
    | Condition d ->
        List.concat_map
          (fun (o : R.rho_ordering) -> [ on_rho o.lhs; on_rho o.rhs ])
          d.rho_conditions
        @ List.concat_map
            (fun (o : R.eps_ordering) -> [ on_eps o.lhs; on_eps o.rhs ])
            d.eps_conditions

  let item_constants item =
    List.fold_left
      (fun (rcs, ecs) (rcs', ecs') -> (rcs @ rcs', ecs @ ecs'))
      ([], [])
      (item_sides ~on_rho:X.Rho.constants
         ~on_eps:(fun eps -> ([], X.Eps.constants eps))
         item)

  (* The number of occurrences of the unknowns [(rhos, eps)] in a resource
     expression. *)
  let rec rho_unknown_occurrences ((rhos, eps) as unknowns) = function
    | X.Rho_var k -> if Rho_set.mem k rhos then 1 else 0
    | X.Rho_const _ -> 0
    | X.Rho_map e -> eps_occurrences eps e
    | X.Rho_mul (rho, rho') | X.Rho_join (rho, rho') ->
        rho_unknown_occurrences unknowns rho
        + rho_unknown_occurrences unknowns rho'

  (* The largest number of occurrences of the unknowns [(rhos, eps)] on one
     side of an ordering of the item. *)
  let item_degree ((_, eps) as unknowns) item =
    List.fold_left Int.max 0
      (item_sides
         ~on_rho:(rho_unknown_occurrences unknowns)
         ~on_eps:(eps_occurrences eps) item)

  (* Whether an item holds at the values [sigma] of its unknowns: an ordering
     decided true between variable-free sides, a condition discharged by its
     retry at no hypotheses. *)
  let holds context sigma = function
    | Rho_item o ->
        N.Rho.closed_leq context.Residual.bounds (X.Rho.subst sigma o.lhs)
          (X.Rho.subst sigma o.rhs)
        = Some true
    | Eps_item o ->
        N.Eps.closed_leq context.Residual.bounds (X.Eps.subst sigma o.lhs)
          (X.Eps.subst sigma o.rhs)
        = Some true
    | Condition d -> (
        match (apply sigma { R.empty with deferred = [ d ] }).deferred with
        | [ d ] -> retry_condition context N.no_hyps d = Ok []
        | _ -> false)

  let by_index (i, _) (j, _) = Int.compare i j

  (* The items in classes sharing unknowns, each in the order of the items,
     the classes in the order of their first items. *)
  let components items =
    let classes =
      List.fold_left
        (fun classes (i, item) ->
          let unknowns = item_unknowns item in
          let joined, apart =
            List.partition
              (fun (unknowns', _) -> shares unknowns unknowns')
              classes
          in
          List.fold_left
            (fun (unknowns, members) (unknowns', members') ->
              (union_grades unknowns unknowns', members' @ members))
            (unknowns, [ (i, item) ])
            joined
          :: apart)
        []
        (List.mapi (fun i item -> (i, item)) items)
    in
    List.map
      (fun (unknowns, members) -> (unknowns, List.sort by_index members))
      classes
    |> List.sort (fun (_, members) (_, members') ->
        by_index (List.hd members) (List.hd members'))
    |> List.map (fun (unknowns, members) -> (unknowns, List.map snd members))

  (* The grades of [cs] without repetition, in order. *)
  let distinct equal cs =
    List.fold_left
      (fun kept c -> if List.exists (equal c) kept then kept else kept @ [ c ])
      [] cs

  (* The grades tried for the unknowns of a component with the constants
     [(rcs, ecs)] and at most [degree] occurrences of its unknowns on one side
     of an item: the unit, the top, the grade of one delay step and the constants of the
     sort, the images of the effect constants for a resource, then the
     witnesses the grades supply. *)
  let eps_candidates context ~degree (rcs, ecs) =
    let bounds = context.Residual.bounds in
    distinct (X.GS.E.equal bounds)
      ([ X.GS.E.one; X.GS.E.top; X.GS.E.of_nat 1 ]
      @ ecs
      @ fst (X.GS.witnesses ~degree bounds rcs ecs))

  let rho_candidates context ~degree (rcs, ecs) =
    let bounds = context.Residual.bounds in
    let rcs = rcs @ List.map X.GS.map ecs in
    distinct (X.GS.R.equal bounds)
      ([ X.GS.R.one; X.GS.R.top; X.GS.R.of_nat 1 ]
      @ rcs
      @ fst (X.GS.R.witnesses ~degree bounds rcs))

  (* The outcome of the search of one component. *)
  type found = Found of X.subst | Exhausted | Abandoned

  (* Depth-first backtracking over the candidates of each unknown in turn,
     each level the candidates of an unknown and the items whose last unknown
     it is, checked as soon as it is assigned. Each candidate tried spends one
     trial of [budget]. *)
  let rec descend context levels sigma budget =
    match levels with
    | [] -> (Found sigma, budget)
    | (candidates, checks) :: levels ->
        let rec try_each budget = function
          | [] -> (Exhausted, budget)
          | _ :: _ when budget <= 0 -> (Abandoned, budget)
          | value :: values ->
              let sigma' = compose sigma value in
              if List.for_all (holds context sigma') checks then
                match descend context levels sigma' (budget - 1) with
                | Exhausted, budget -> try_each budget values
                | ((Found _ | Abandoned), _) as outcome -> outcome
              else try_each (budget - 1) values
        in
        try_each budget candidates

  (* The levels of a component: its unknowns, those occurring in more items
     first, each with its candidates and the items whose last unknown it is;
     and the items without unknowns. *)
  let levels context ((rhos, eps) as unknowns) items =
    let tagged = List.map (fun item -> (item_unknowns item, item)) items in
    let count u =
      List.length (List.filter (fun ((rhos, eps), _) -> u rhos eps) tagged)
    in
    let order =
      List.map
        (fun k -> (Eps_unknown k, count (fun _ eps -> Eps_set.mem k eps)))
        (Eps_set.elements eps)
      @ List.map
          (fun k -> (Rho_unknown k, count (fun rhos _ -> Rho_set.mem k rhos)))
          (Rho_set.elements rhos)
      |> List.stable_sort (fun (_, n) (_, n') -> Int.compare n' n)
      |> List.map fst
    in
    let degree =
      List.fold_left Int.max 0 (List.map (item_degree unknowns) items)
    and constants =
      List.fold_left
        (fun (rcs, ecs) item ->
          let rcs', ecs' = item_constants item in
          (rcs @ rcs', ecs @ ecs'))
        ([], []) items
    in
    let eps_values =
      lazy (List.map X.Eps.const (eps_candidates context ~degree constants))
    and rho_values =
      lazy (List.map X.Rho.const (rho_candidates context ~degree constants))
    in
    let position (rhos, eps) =
      List.fold_left Int.max (-1)
        (List.mapi
           (fun i u ->
             match u with
             | Eps_unknown k when Eps_set.mem k eps -> i
             | Rho_unknown k when Rho_set.mem k rhos -> i
             | Eps_unknown _ | Rho_unknown _ -> -1)
           order)
    in
    let at i =
      List.filter_map
        (fun (unknowns, item) ->
          if position unknowns = i then Some item else None)
        tagged
    in
    ( List.mapi
        (fun i u ->
          let values =
            match u with
            | Eps_unknown k -> List.map (assign_eps k) (Lazy.force eps_values)
            | Rho_unknown k -> List.map (assign_rho k) (Lazy.force rho_values)
          in
          (values, at i))
        order,
      at (-1) )

  let unestablished ~abandoned items =
    R.Unestablished
      {
        rho_orderings =
          List.filter_map (function Rho_item o -> Some o | _ -> None) items;
        eps_orderings =
          List.filter_map (function Eps_item o -> Some o | _ -> None) items;
        conditions =
          List.filter_map (function Condition d -> Some d | _ -> None) items;
        abandoned;
      }

  (* The number of candidates tried by default, over all components. *)
  let default_budget = 100_000

  (* A closed instance of the orderings and deferred conditions of [r]:
     backtracking search (Golomb and Baumert, JACM 1965) over a finite grid of
     candidates per unknown, a constraint satisfaction problem solved one
     component of unknowns sharing items at a time. The type unknowns are left
     out: after [atomise], the subtyping and eternality demands relate type
     unknowns alone, and each disjunction kept has a type whose eternality
     depends on type unknowns, so [unit] for every type unknown meets them
     all. Where [r] is the residual of localisation, its values, the
     assignment found and [unit] for the type unknowns form a closed instance
     of the qualifier. An assignment found is an instance; an instance outside
     the grid is not found. *)
  let instance ?(budget = default_budget) context (r : residual) =
    let items =
      List.map (fun o -> Rho_item o) r.rho_orderings
      @ List.map (fun o -> Eps_item o) r.eps_orderings
      @ List.map (fun d -> Condition d) r.deferred
    in
    let search (found, budget) (unknowns, items) =
      match found with
      | Error _ -> (found, budget)
      | Ok sigma -> (
          let levels, closed = levels context unknowns items in
          if not (List.for_all (holds context empty_grade_subst) closed) then
            (Error (unestablished ~abandoned:false items), budget)
          else
            match descend context levels empty_grade_subst budget with
            | Found sigma', budget -> (Ok (compose sigma sigma'), budget)
            | Exhausted, budget ->
                (Error (unestablished ~abandoned:false items), budget)
            | Abandoned, budget ->
                (Error (unestablished ~abandoned:true items), budget))
    in
    fst
      (List.fold_left search (Ok empty_grade_subst, budget) (components items))
end
