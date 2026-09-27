(* The constraint solver. *)

module Ast = Language.Ast
module TyParamMap = Ast.TyParamMap
module TyParamSet = Ast.TyParamSet

module Make (C : Constraint.S) = struct
  module X = C.X
  module R = Residual.Make (C)
  module RS = RigidScope.Make (C)
  module Rep = Report.Make (C)
  module Sk = Skeleton.Make (X)
  module Rho_set = X.Rho_var.Set
  module Eps_set = X.Eps_var.Set

  type context = R.context
  type failure = R.failure
  type stuck = RS.stuck

  type solution = {
    subst : C.subst;
    hyps : R.hyps;
    obligations : R.deferred list;
    context : context;
  }

  type outcome = Solved of solution | Refuted of failure | Stuck of stuck

  (* The state of the traversal: the values of the unknowns solved, an
     idempotent substitution; the unknowns in play, none solved; and the
     residual. *)
  type state = { theta : C.subst; live : C.free; residual : R.t }

  let refused result = Result.map_error (fun f -> RS.Refused f) result

  (* ------------------------------------------------------------------ *)
  (* Substitutions                                                       *)
  (* ------------------------------------------------------------------ *)

  let compose_grades (sigma : X.subst) (sigma' : X.subst) : X.subst =
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

  (* [compose theta sigma] is [theta] followed by [sigma]. *)
  let compose (theta : C.subst) (sigma : C.subst) : C.subst =
    {
      ty_subst =
        TyParamMap.union
          (fun _ ty _ -> Some ty)
          (TyParamMap.map (C.subst_ty sigma) theta.ty_subst)
          sigma.ty_subst;
      grade_subst = compose_grades theta.grade_subst sigma.grade_subst;
    }

  let free_of_rho rho : C.free =
    {
      C.no_free with
      free_rhos = X.Rho.free_rho_vars rho;
      free_eps = X.Rho.free_eps_vars rho;
    }

  let free_of_eps eps : C.free =
    { C.no_free with free_eps = X.Eps.free_vars eps }

  let free_of_list (vs : C.vars) : C.free =
    {
      free_tys = TyParamSet.of_list vs.ty_vars;
      free_rhos = Rho_set.of_list vs.rho_vars;
      free_eps = Eps_set.of_list vs.eps_vars;
    }

  (* The unknowns in play once [sigma] is made: those of its domain are
     replaced by those of their values. *)
  let moved_live (live : C.free) (sigma : C.subst) =
    let remove_keys keys remove set =
      List.fold_left (fun set (k, _) -> remove k set) set keys
    in
    let live : C.free =
      {
        free_tys =
          remove_keys
            (TyParamMap.bindings sigma.ty_subst)
            TyParamSet.remove live.free_tys;
        free_rhos =
          remove_keys
            (X.Rho_var.Map.bindings sigma.grade_subst.rho_subst)
            Rho_set.remove live.free_rhos;
        free_eps =
          remove_keys
            (X.Eps_var.Map.bindings sigma.grade_subst.eps_subst)
            Eps_set.remove live.free_eps;
      }
    in
    let add_free free acc = C.union_free acc free in
    live
    |> TyParamMap.fold (fun _ ty -> add_free (C.free_vars_ty ty)) sigma.ty_subst
    |> X.Rho_var.Map.fold
         (fun _ rho -> add_free (free_of_rho rho))
         sigma.grade_subst.rho_subst
    |> X.Eps_var.Map.fold
         (fun _ eps -> add_free (free_of_eps eps))
         sigma.grade_subst.eps_subst

  (* The state once [sigma] is made. *)
  let moved st sigma =
    {
      theta = compose st.theta sigma;
      live = moved_live st.live sigma;
      residual = R.subst sigma st.residual;
    }

  (* ------------------------------------------------------------------ *)
  (* Expansion                                                           *)
  (* ------------------------------------------------------------------ *)

  let shape_failure (f : C.reason Skeleton.failure) =
    match f.mismatch with
    | Skeleton.Clash -> R.Shape_mismatch f
    | Skeleton.Occurs _ -> R.Occurs_check f

  (* Whether two skeletons have one shape, each unknown of one facing an
     unknown of the other: their unification instantiates no unknown. *)
  let rec aligned (t : Skeleton.t) (u : Skeleton.t) =
    match (t, u) with
    | Var _, Var _ -> true
    | Const c, Const c' -> c = c'
    | Apply (name, ts), Apply (name', us) ->
        Ast.TyName.compare name name' = 0 && aligned_all ts us
    | Tuple ts, Tuple us -> aligned_all ts us
    | Arrow (t1, t2), Arrow (u1, u2) | Handler (t1, t2), Handler (u1, u2) ->
        aligned t1 u1 && aligned t2 u2
    | Box t, Box u -> aligned t u
    | (Var _ | Const _ | Apply _ | Tuple _ | Arrow _ | Handler _ | Box _), _ ->
        false

  and aligned_all ts us =
    List.compare_lengths ts us = 0 && List.for_all2 aligned ts us

  (* The pending demands and [extra] expanded, and the residual decomposed
     again under the instantiation. *)
  let expand context st extra =
    let open Result.Syntax in
    let* delta =
      Result.map_error shape_failure
        (Sk.expand (R.skeleton_unfold context) (extra @ st.residual.subs))
    in
    if TyParamMap.is_empty delta then Ok (st, C.empty_subst)
    else
      let sigma = { C.empty_subst with ty_subst = delta } in
      let st = moved st sigma in
      let* residual = R.atomise context st.residual in
      Ok ({ st with residual }, sigma)

  let reexpand context st =
    let open Result.Syntax in
    let* st, _ = expand context st [] in
    let* residual = R.atomise context st.residual in
    Ok { st with residual }

  let sub_atom context st (s : R.sub) =
    let open Result.Syntax in
    if aligned (Skeleton.of_ty s.lhs) (Skeleton.of_ty s.rhs) then
      let* residual = R.push_sub context s st.residual in
      Ok { st with residual }
    else
      let* st, sigma = expand context st [ s ] in
      let s =
        { s with lhs = C.subst_ty sigma s.lhs; rhs = C.subst_ty sigma s.rhs }
      in
      let* residual = R.push_sub context s st.residual in
      Ok { st with residual }

  (* ------------------------------------------------------------------ *)
  (* Rigid scopes                                                        *)
  (* ------------------------------------------------------------------ *)

  (* The unknowns free in the values of [vars]. *)
  let images (theta : C.subst) (vars : C.free) : C.free =
    let image_ty a acc =
      match TyParamMap.find_opt a theta.ty_subst with
      | Some ty -> C.union_free acc (C.free_vars_ty ty)
      | None -> { acc with free_tys = TyParamSet.add a acc.free_tys }
    and image_rho k acc =
      match X.Rho_var.Map.find_opt k theta.grade_subst.rho_subst with
      | Some rho -> C.union_free acc (free_of_rho rho)
      | None -> { acc with free_rhos = Rho_set.add k acc.free_rhos }
    and image_eps k acc =
      match X.Eps_var.Map.find_opt k theta.grade_subst.eps_subst with
      | Some eps -> C.union_free acc (free_of_eps eps)
      | None -> { acc with free_eps = Eps_set.add k acc.free_eps }
    in
    C.no_free
    |> TyParamSet.fold image_ty vars.free_tys
    |> Rho_set.fold image_rho vars.free_rhos
    |> Eps_set.fold image_eps vars.free_eps

  (* The atoms kept outside a scope added to the residual outside it, the
     orderings decided as they are pushed. *)
  let merge context (outer : R.t) (kept : R.t) =
    let open Result.Syntax in
    let* outer =
      List.fold_right
        (fun o r -> Result.bind r (R.push_rho context o))
        kept.rho_orderings (Ok outer)
    in
    let* outer =
      List.fold_right
        (fun o r -> Result.bind r (R.push_eps context o))
        kept.eps_orderings (Ok outer)
    in
    Ok (R.union outer { kept with rho_orderings = []; eps_orderings = [] })

  (* The state with the residual [push] leaves. *)
  let pushed st push =
    Result.map
      (fun residual -> { st with residual })
      (refused (push st.residual))

  let rec solve_in context st c =
    let open Result.Syntax in
    let theta = st.theta in
    let reason = C.subst_reason theta in
    match c with
    | C.True -> Ok st
    | C.And (c, d) ->
        let* st = solve_in context st c in
        solve_in context st d
    | C.Sub (why, a, b) ->
        refused
          (sub_atom context st
             {
               lhs = C.subst_ty theta a;
               rhs = C.subst_ty theta b;
               info = reason why;
             })
    | C.Rho_leq (why, rho, rho') ->
        pushed st
          (R.push_rho context
             {
               lhs = X.Rho.subst theta.grade_subst rho;
               rhs = X.Rho.subst theta.grade_subst rho';
               info = reason why;
             })
    | C.Eps_leq (why, eps, eps') ->
        pushed st
          (R.push_eps context
             {
               lhs = X.Eps.subst theta.grade_subst eps;
               rhs = X.Eps.subst theta.grade_subst eps';
               info = reason why;
             })
    | C.Eternal (why, ty) ->
        pushed st
          (R.push_eternal context
             { eternal_ty = C.subst_ty theta ty; eternal_reason = reason why })
    | C.Eternal_or_unit (why, ty, rho) ->
        pushed st
          (R.push_disjunction context
             {
               disj_ty = C.subst_ty theta ty;
               disj_grade = X.Rho.subst theta.grade_subst rho;
               disj_reason = reason why;
             })
    | C.Exists (vars, c) ->
        solve_in context
          { st with live = C.union_free st.live (free_of_list vars) }
          c
    | C.Forall_eps (rigid, origin, c) -> rigid_scope context st rigid origin c

  (* The clause solved for a fresh rigid [rigid], with a residual of its own,
     and closed. *)
  and rigid_scope context st rigid origin body =
    let open Result.Syntax in
    let entered = st.live in
    let inner =
      {
        st with
        live = { st.live with free_eps = Eps_set.add rigid st.live.free_eps };
        residual = R.empty;
      }
    in
    let* inner = solve_in context inner body in
    let* inner = refused (reexpand context inner) in
    let outer = images inner.theta entered in
    let scope =
      {
        RS.rigid;
        outer_rhos = outer.free_rhos;
        outer_eps = Eps_set.remove rigid outer.free_eps;
      }
    in
    let values, residual = RS.localise context scope inner.residual in
    let inner =
      moved
        { inner with residual = R.empty }
        { C.empty_subst with grade_subst = values }
    in
    let* () =
      if Eps_set.mem rigid (images inner.theta entered).free_eps then
        Error (RS.Refused (R.Rigid_escape origin))
      else Ok ()
    in
    let* kept = RS.split context scope origin residual in
    let outside = R.subst inner.theta st.residual in
    let* residual = refused (merge context outside kept) in
    let st =
      {
        theta = inner.theta;
        live =
          {
            inner.live with
            free_eps = Eps_set.remove rigid inner.live.free_eps;
          };
        residual;
      }
    in
    let* st = refused (reexpand context st) in
    let* residual = refused (RS.retry context st.residual) in
    Ok { st with residual }

  (* ------------------------------------------------------------------ *)
  (* The whole constraint                                                *)
  (* ------------------------------------------------------------------ *)

  let finish context st =
    let open Result.Syntax in
    let* residual = RS.retry context st.residual in
    let* st = reexpand context { st with residual } in
    let* hyps = R.to_hyps context st.residual in
    let* hyps = R.check_closed context hyps in
    Ok { subst = st.theta; hyps; obligations = st.residual.deferred; context }

  let solve context c =
    let st =
      { theta = C.empty_subst; live = C.free_vars c; residual = R.empty }
    in
    match solve_in context st c with
    | Error (RS.Refused failure) -> Refuted failure
    | Error (RS.Stuck stuck) -> Stuck stuck
    | Ok st -> (
        match finish context st with
        | Ok solution -> Solved solution
        | Error failure -> Refuted failure)

  let satisfiable context solution =
    let open Result.Syntax in
    let hyps = solution.hyps in
    let _, residual =
      RS.localise_all context
        {
          rho_orderings = hyps.rho_hyps;
          eps_orderings = hyps.eps_hyps;
          eternals = hyps.eternal_hyps;
          subs = hyps.sub_vars;
          disjunctions = hyps.disj_hyps;
          deferred = solution.obligations;
        }
    in
    let* residual = RS.retry context residual in
    let* hyps = R.to_hyps context residual in
    let* _ = R.check_closed context hyps in
    Ok ()

  (* ------------------------------------------------------------------ *)
  (* Generalisation                                                      *)
  (* ------------------------------------------------------------------ *)

  let qualifier solution =
    C.conj
      (R.hyps_to_constraint solution.hyps)
      (C.conj_all (List.map R.deferred_to_constraint solution.obligations))

  let generalise ?(fixed = C.no_free) ty solution =
    Rep.scheme ~fixed
      (Rep.report solution.context ~fixed
         (C.subst_ty solution.subst ty)
         solution.hyps solution.obligations)

  let print_outcome outcome ppf =
    match outcome with
    | Solved solution ->
        Format.fprintf ppf "solved@.%t" (C.print (qualifier solution))
    | Refuted failure ->
        Format.fprintf ppf "refuted: %t" (R.print_failure failure)
    | Stuck { stuck_origin; _ } ->
        Format.fprintf ppf "stuck at the clause for %t"
          (Ast.OpName.print stuck_origin.clause.op)
end
