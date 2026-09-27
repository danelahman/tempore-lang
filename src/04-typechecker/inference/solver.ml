(* The constraint solver, reducing a constraint to a substitution and a
   residual of undecided atoms, the solved form of HM(X) (Odersky, Sulzmann
   and Wehr, TAPOS 1999). *)

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
  type decision = { reason : C.reason; path : Ast.step list }

  type mismatch = {
    atom : R.sub;
    lhs_decided : decision option;
    rhs_decided : decision option;
  }

  (* A type unknown solved: where it was decided, and the value it was given,
     before the values given later were substituted into it. *)
  type solved = { decision : decision; value : C.ty }

  (* The state of the traversal: the values of the unknowns solved, an
     idempotent substitution; the unknowns in play, none solved; the residual;
     and each type unknown solved. *)
  type state = {
    theta : C.subst;
    live : C.free;
    residual : R.t;
    solved : solved TyParamMap.t;
  }

  (* The failures of [result], none of them a mismatch. *)
  let refused result = Result.map_error (fun f -> (RS.Refused f, None)) result
  let failed result = Result.map_error (fun e -> (e, None)) result

  (* The failures of an expansion. *)
  let expansion_refused result =
    Result.map_error (fun (f, mismatch) -> (RS.Refused f, mismatch)) result

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
      st with
      theta = compose st.theta sigma;
      live = moved_live st.live sigma;
      residual = R.subst sigma st.residual;
    }

  (* ------------------------------------------------------------------ *)
  (* Provenance                                                          *)
  (* ------------------------------------------------------------------ *)

  (* An atom unified by an expansion: its reason and its two sides before the
     values of the unknowns solved were substituted. *)
  type site = { site_reason : C.reason; generated : C.ty * C.ty }

  let side_of (site : site) = function
    | Skeleton.Left -> fst site.generated
    | Skeleton.Right -> snd site.generated

  (* The part of [ty] at [step] of a skeleton path. *)
  let child (ty : C.ty) (step : Ast.step) =
    match (step, ty) with
    | Ast.Argument, Ast.TyArrow (ty, _)
    | Ast.Result, Ast.TyArrow (_, Ast.CompTy (ty, _))
    | Ast.BoxContent, Ast.TyBox (_, ty)
    | Ast.HandlerInput, Ast.TyHandler (Ast.CompTy (ty, _), _)
    | Ast.HandlerOutput, Ast.TyHandler (_, Ast.CompTy (ty, _)) ->
        Some ty
    | Ast.Component i, Ast.TyTuple tys | Ast.TypeArgument i, Ast.TyApply (_, tys)
      ->
        List.nth_opt tys (i - 1)
    | _ -> None

  (* [decided context solved bindings] is where the part at a path of a type
     was decided: at the innermost unknown on the way to it, solved before or
     bound by [bindings], whose decision is known. An unknown bound facing
     another unknown, or facing the part of an atom's side that such an
     unknown stands for, inherits its decision; otherwise it is decided at its
     binding. *)
  let decided context solved (bindings : site Skeleton.bindings) =
    let rec along seen (ty : C.ty) path =
      match (ty, path) with
      | Ast.TyParam a, _ -> within seen a path
      | Ast.TyApply (name, args), _
        when Option.is_some (R.unfold_alias context name args) ->
          along seen (Option.get (R.unfold_alias context name args)) path
      | _, [] -> None
      | _, step :: path ->
          Option.bind (child ty step) (fun ty -> along seen ty path)
    (* The decision of the part at [path] of the value of [a]. *)
    and within seen a path =
      let deeper decision inner = Some (Option.value inner ~default:decision) in
      let seen' = TyParamSet.add a seen in
      match (TyParamMap.find_opt a bindings, TyParamMap.find_opt a solved) with
      | _, _ when TyParamSet.mem a seen -> None
      | Some (b : site Skeleton.binding), _ ->
          deeper
            { reason = b.site.site_reason; path = b.at }
            (match b.source with
            | Skeleton.Through c -> within seen' c path
            | Skeleton.Side side ->
                along seen' (side_of b.site side) (b.at @ path))
      | None, Some { decision; value } ->
          deeper decision (along seen' value path)
      | None, None -> None
    in
    along TyParamSet.empty

  (* The unknowns solved, extended by those [delta] instantiates. *)
  let solved_by context solved bindings delta =
    let decided = decided context solved bindings in
    TyParamMap.fold
      (fun a value solved ->
        match decided (Ast.TyParam a) [] with
        | Some decision -> TyParamMap.add a { decision; value } solved
        | None -> solved)
      delta solved

  (* The mismatch of a failed expansion at the state [st]. *)
  let mismatch_of context st bindings (f : site Skeleton.failure) =
    let decided = decided context st.solved bindings in
    let lhs, rhs = f.info.generated in
    {
      atom =
        {
          lhs = C.subst_ty st.theta lhs;
          rhs = C.subst_ty st.theta rhs;
          info = f.info.site_reason;
        };
      lhs_decided = decided lhs f.path;
      rhs_decided = decided rhs f.path;
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

  (* The failures of [result], without provenance. *)
  let untraced result = Result.map_error (fun f -> (f, None)) result

  (* The pending demands and [extra], each with its sides as generated,
     expanded, and the residual decomposed again under the instantiation. *)
  let expand context st extra =
    let open Result.Syntax in
    let demand generated (s : R.sub) : (C.ty, site) GradeNormal.ordering =
      { s with info = { site_reason = s.info; generated } }
    in
    let demands =
      List.map (fun (s, generated) -> demand generated s) extra
      @ List.map (fun (s : R.sub) -> demand (s.lhs, s.rhs) s) st.residual.subs
    in
    match Sk.expand_traced (R.skeleton_unfold context) demands with
    | Error (f, bindings) ->
        Error
          ( shape_failure { f with info = f.info.site_reason },
            Some (mismatch_of context st bindings f) )
    | Ok (delta, _) when TyParamMap.is_empty delta -> Ok (st, C.empty_subst)
    | Ok (delta, bindings) ->
        let sigma = { C.empty_subst with ty_subst = delta } in
        let solved = solved_by context st.solved bindings delta in
        let st = moved { st with solved } sigma in
        let* residual = untraced (R.atomise context st.residual) in
        Ok ({ st with residual }, sigma)

  let reexpand context st =
    let open Result.Syntax in
    let* st, _ = expand context st [] in
    let* residual = untraced (R.atomise context st.residual) in
    Ok { st with residual }

  (* The subtyping atom [s], whose sides as generated are [generated]. *)
  let sub_atom context st (s : R.sub) generated =
    let open Result.Syntax in
    if aligned (Skeleton.of_ty s.lhs) (Skeleton.of_ty s.rhs) then
      let* residual = untraced (R.push_sub context s st.residual) in
      Ok { st with residual }
    else
      let* st, sigma = expand context st [ (s, generated) ] in
      let s =
        { s with lhs = C.subst_ty sigma s.lhs; rhs = C.subst_ty sigma s.rhs }
      in
      let* residual = untraced (R.push_sub context s st.residual) in
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
        expansion_refused
          (sub_atom context st
             {
               lhs = C.subst_ty theta a;
               rhs = C.subst_ty theta b;
               info = reason why;
             }
             (a, b))
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
    let* inner = expansion_refused (reexpand context inner) in
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
        refused (Error (R.Rigid_escape origin))
      else Ok ()
    in
    let* kept = failed (RS.split context scope origin residual) in
    let outside = R.subst inner.theta st.residual in
    let* residual = refused (merge context outside kept) in
    let st =
      {
        inner with
        live =
          {
            inner.live with
            free_eps = Eps_set.remove rigid inner.live.free_eps;
          };
        residual;
      }
    in
    let* st = expansion_refused (reexpand context st) in
    let* residual = refused (RS.retry context st.residual) in
    Ok { st with residual }

  (* ------------------------------------------------------------------ *)
  (* The whole constraint                                                *)
  (* ------------------------------------------------------------------ *)

  let finish context st =
    let open Result.Syntax in
    let* residual = refused (RS.retry context st.residual) in
    let* st = expansion_refused (reexpand context { st with residual }) in
    let* hyps = refused (R.to_hyps context st.residual) in
    let* hyps = refused (R.check_closed context hyps) in
    Ok { subst = st.theta; hyps; obligations = st.residual.deferred; context }

  let solve_traced context c =
    let st =
      {
        theta = C.empty_subst;
        live = C.free_vars c;
        residual = R.empty;
        solved = TyParamMap.empty;
      }
    in
    let result = Result.bind (solve_in context st c) (finish context) in
    match result with
    | Ok solution -> (Solved solution, None)
    | Error (RS.Refused failure, mismatch) -> (Refuted failure, mismatch)
    | Error (RS.Stuck stuck, mismatch) -> (Stuck stuck, mismatch)

  let solve context c = fst (solve_traced context c)

  (* The residual of the search for a closed instance of the qualifier. *)
  let search context solution =
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
    Ok residual

  let satisfiable context solution = Result.map ignore (search context solution)

  let established context solution =
    Result.bind (search context solution) (fun (residual : R.t) ->
        match residual.deferred with
        | [] -> Ok ()
        | d :: _ -> Error (R.Undecided_condition d))

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

  let unsimplified ?(fixed = C.no_free) ty solution =
    let ty = C.subst_ty solution.subst ty in
    let qualifier = qualifier solution in
    let free = C.union_free (C.free_vars_ty ty) (C.free_vars qualifier) in
    {
      C.ty_params =
        TyParamSet.elements (TyParamSet.diff free.free_tys fixed.free_tys);
      rho_params =
        Rho_set.elements (Rho_set.diff free.free_rhos fixed.free_rhos);
      eps_params = Eps_set.elements (Eps_set.diff free.free_eps fixed.free_eps);
      qualifier;
      ty;
    }

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
