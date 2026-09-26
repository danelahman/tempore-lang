(* The residual of constraint solving and its decomposition. *)

module Ast = Language.Ast
module Const = Language.Const
module TyParam = Ast.TyParamModule
module TyParamMap = Ast.TyParamMap
module TyParamSet = Ast.TyParamSet

type ('rho, 'eps) types = {
  bounds : Language.Grade.bounds;
  find_definition :
    Ast.ty_name -> (Ast.ty_param list * ('rho, 'eps) Ast.ty_def) option;
  is_noneternal : Ast.ty_name -> bool;
}

module Make (C : Constraint.S) = struct
  module X = C.X
  module N = GradeNormal.Make (X)

  type rho = C.rho
  type eps = C.eps
  type ty = C.ty
  type reason = C.reason
  type context = (rho, eps) types
  type rho_ordering = (rho, reason) GradeNormal.ordering
  type eps_ordering = (eps, reason) GradeNormal.ordering
  type sub = (ty, reason) GradeNormal.ordering
  type eternal = { eternal_ty : ty; eternal_reason : reason }
  type disjunction = { disj_ty : ty; disj_grade : rho; disj_reason : reason }

  type deferred = {
    origin : Reason.rigid_origin;
    rigids : (X.Eps_var.t * Reason.rigid_origin) list;
    rho_conditions : rho_ordering list;
    eps_conditions : eps_ordering list;
  }

  type t = {
    rho_orderings : rho_ordering list;
    eps_orderings : eps_ordering list;
    eternals : eternal list;
    subs : sub list;
    disjunctions : disjunction list;
    deferred : deferred list;
  }

  let empty =
    {
      rho_orderings = [];
      eps_orderings = [];
      eternals = [];
      subs = [];
      disjunctions = [];
      deferred = [];
    }

  let union r r' =
    {
      rho_orderings = r.rho_orderings @ r'.rho_orderings;
      eps_orderings = r.eps_orderings @ r'.eps_orderings;
      eternals = r.eternals @ r'.eternals;
      subs = r.subs @ r'.subs;
      disjunctions = r.disjunctions @ r'.disjunctions;
      deferred = r.deferred @ r'.deferred;
    }

  (* ------------------------------------------------------------------ *)
  (* Substitution                                                        *)
  (* ------------------------------------------------------------------ *)

  let subst_rho (sigma : C.subst) = X.Rho.subst sigma.grade_subst
  let subst_eps (sigma : C.subst) = X.Eps.subst sigma.grade_subst

  let subst_ordering on_exp sigma (o : _ GradeNormal.ordering) :
      _ GradeNormal.ordering =
    {
      lhs = on_exp o.lhs;
      rhs = on_exp o.rhs;
      info = C.subst_reason sigma o.info;
    }

  let subst_deferred sigma d =
    {
      d with
      rho_conditions =
        List.map (subst_ordering (subst_rho sigma) sigma) d.rho_conditions;
      eps_conditions =
        List.map (subst_ordering (subst_eps sigma) sigma) d.eps_conditions;
    }

  let subst sigma r =
    {
      rho_orderings =
        List.map (subst_ordering (subst_rho sigma) sigma) r.rho_orderings;
      eps_orderings =
        List.map (subst_ordering (subst_eps sigma) sigma) r.eps_orderings;
      eternals =
        List.map
          (fun e ->
            {
              eternal_ty = C.subst_ty sigma e.eternal_ty;
              eternal_reason = C.subst_reason sigma e.eternal_reason;
            })
          r.eternals;
      subs = List.map (subst_ordering (C.subst_ty sigma) sigma) r.subs;
      disjunctions =
        List.map
          (fun d ->
            {
              disj_ty = C.subst_ty sigma d.disj_ty;
              disj_grade = subst_rho sigma d.disj_grade;
              disj_reason = C.subst_reason sigma d.disj_reason;
            })
          r.disjunctions;
      deferred = List.map (subst_deferred sigma) r.deferred;
    }

  (* ------------------------------------------------------------------ *)
  (* Failures                                                            *)
  (* ------------------------------------------------------------------ *)

  type failure =
    | Shape_mismatch of reason Skeleton.failure
    | Occurs_check of reason Skeleton.failure
    | Refuted_rho of (rho, reason list) GradeNormal.ordering
    | Refuted_eps of (eps, reason list) GradeNormal.ordering
    | Never_eternal of { ty : ty; reason : reason }
    | Refuted_condition of { condition : deferred; witness : X.GS.E.t list }
    | Rigid_escape of Reason.rigid_origin

  (* The mismatch of the two sides of [s], whose formers differ. *)
  let mismatch (s : sub) =
    Shape_mismatch
      {
        info = s.info;
        mismatch = Skeleton.Clash;
        lhs = Skeleton.of_ty s.lhs;
        rhs = Skeleton.of_ty s.rhs;
        path = [];
      }

  (* ------------------------------------------------------------------ *)
  (* Type definitions                                                    *)
  (* ------------------------------------------------------------------ *)

  (* The map sending [params] to [args], of the same length. *)
  let param_map params args =
    List.fold_left2
      (fun m a arg -> TyParamMap.add a arg m)
      TyParamMap.empty params args

  (* A definition and the substitution sending its parameters to [args], when
     there are as many. *)
  let instance_of (params, definition) args =
    if List.compare_lengths params args <> 0 then None
    else
      Some (definition, { C.empty_subst with ty_subst = param_map params args })

  let unfold_alias context name args =
    match
      Option.bind (context.find_definition name) (fun d -> instance_of d args)
    with
    | Some (Ast.TyInline body, sigma) -> Some (C.subst_ty sigma body)
    | Some (Ast.TySum _, _) | None -> None

  let skeleton_unfold context name args =
    match context.find_definition name with
    | Some (params, Ast.TyInline body) when List.compare_lengths params args = 0
      ->
        Some (Skeleton.apply (param_map params args) (Skeleton.of_ty body))
    | Some _ | None -> None

  (* The type unknowns the eternality of a type depends on. An application
     of a type being unfolded is eternal; a [noneternal] declaration is
     consulted first, so that it also poisons the types recursing through
     it. *)
  let eternal_vars context ty =
    let open Option.Syntax in
    let rec all visited tys acc =
      List.fold_left
        (fun acc ty ->
          let* acc = acc in
          check visited ty acc)
        (Some acc) tys
    and check visited ty acc =
      match ty with
      | Ast.TyConst c -> if Const.is_eternal_ty c then Some acc else None
      | Ast.TyParam a -> Some (TyParamSet.add a acc)
      | Ast.TyArrow _ | Ast.TyBox _ | Ast.TyHandler _ -> None
      | Ast.TyTuple tys -> all visited tys acc
      | Ast.TyApply (name, args) -> (
          if context.is_noneternal name then None
          else if List.exists (fun n -> Ast.TyName.compare n name = 0) visited
          then Some acc
          else
            let visited = name :: visited in
            match
              Option.bind (context.find_definition name) (fun d ->
                  instance_of d args)
            with
            | None -> None
            | Some (Ast.TyInline body, sigma) ->
                check visited (C.subst_ty sigma body) acc
            | Some (Ast.TySum variants, sigma) ->
                all visited
                  (List.filter_map
                     (fun (_, arg) -> Option.map (C.subst_ty sigma) arg)
                     variants)
                  acc)
    in
    Option.map TyParamSet.elements (check [] ty TyParamSet.empty)

  (* ------------------------------------------------------------------ *)
  (* Pushing atoms                                                       *)
  (* ------------------------------------------------------------------ *)

  let push_rho context (o : rho_ordering) r =
    let bounds = context.bounds in
    match N.Rho.closed_leq bounds o.lhs o.rhs with
    | Some true -> Ok r
    | Some false -> Error (Refuted_rho { o with info = [ o.info ] })
    | None -> (
        match N.Rho.decide_leq bounds N.no_hyps o.lhs o.rhs with
        | Some _ -> Ok r
        | None -> Ok { r with rho_orderings = o :: r.rho_orderings })

  let push_eps context (o : eps_ordering) r =
    let bounds = context.bounds in
    match N.Eps.closed_leq bounds o.lhs o.rhs with
    | Some true -> Ok r
    | Some false -> Error (Refuted_eps { o with info = [ o.info ] })
    | None -> (
        match N.Eps.decide_leq bounds N.no_hyps o.lhs o.rhs with
        | Some _ -> Ok r
        | None -> Ok { r with eps_orderings = o :: r.eps_orderings })

  let is_param a = function
    | { eternal_ty = Ast.TyParam b; _ } -> TyParam.compare a b = 0
    | { eternal_ty = _; _ } -> false

  let push_eternal context e r =
    match eternal_vars context e.eternal_ty with
    | None ->
        Error (Never_eternal { ty = e.eternal_ty; reason = e.eternal_reason })
    | Some vars ->
        Ok
          {
            r with
            eternals =
              List.fold_left
                (fun eternals a ->
                  if List.exists (is_param a) eternals then eternals
                  else
                    {
                      eternal_ty = Ast.TyParam a;
                      eternal_reason = e.eternal_reason;
                    }
                    :: eternals)
                r.eternals vars;
          }

  (* The type side of a disjunction whose grade is not decided below the
     unit. *)
  let disjunction_by_type context d r =
    match eternal_vars context d.disj_ty with
    | None ->
        push_rho context
          { lhs = d.disj_grade; rhs = X.Rho.unit; info = d.disj_reason }
          r
    | Some [] -> Ok r
    | Some (_ :: _) -> Ok { r with disjunctions = d :: r.disjunctions }

  let below_unit context rho =
    let bounds = context.bounds in
    match N.Rho.closed_leq bounds rho X.Rho.unit with
    | Some leq -> leq
    | None -> Option.is_some (N.Rho.decide_leq bounds N.no_hyps rho X.Rho.unit)

  let push_disjunction context d r =
    if below_unit context d.disj_grade then Ok r
    else disjunction_by_type context d r

  let step s (o : _ GradeNormal.ordering) =
    { o with info = Reason.step s o.info }

  (* How the arguments of two types of one former are related. *)
  type variance = Covariant | Invariant

  let rec push_sub context (s : sub) r =
    let open Result.Syntax in
    let ordering lhs rhs info : _ GradeNormal.ordering = { lhs; rhs; info } in
    match (s.lhs, s.rhs) with
    | Ast.TyParam a, Ast.TyParam b ->
        if TyParam.compare a b = 0 then Ok r
        else Ok { r with subs = s :: r.subs }
    | Ast.TyApply (name, args), _
      when Option.is_some (unfold_alias context name args) ->
        push_sub context
          { s with lhs = Option.get (unfold_alias context name args) }
          r
    | _, Ast.TyApply (name, args)
      when Option.is_some (unfold_alias context name args) ->
        push_sub context
          { s with rhs = Option.get (unfold_alias context name args) }
          r
    | Ast.TyApply (name, args), Ast.TyApply (name', args')
      when Ast.TyName.compare name name' = 0
           && List.compare_lengths args args' = 0 ->
        push_pairs context
          (fun i -> Reason.Type_argument i)
          Invariant s.info args args' r
    | Ast.TyConst c, Ast.TyConst c' when c = c' -> Ok r
    | Ast.TyTuple tys, Ast.TyTuple tys' when List.compare_lengths tys tys' = 0
      ->
        push_pairs context
          (fun i -> Reason.Component i)
          Covariant s.info tys tys' r
    | ( Ast.TyArrow (dom, Ast.CompTy (cod, eps)),
        Ast.TyArrow (dom', Ast.CompTy (cod', eps')) ) ->
        let* r =
          push_sub context (step Reason.Argument (ordering dom' dom s.info)) r
        in
        let* r =
          push_sub context (step Reason.Result (ordering cod cod' s.info)) r
        in
        push_eps context (step Reason.Effect (ordering eps eps' s.info)) r
    | Ast.TyBox (rho, ty), Ast.TyBox (rho', ty') ->
        let* r =
          push_rho context (step Reason.Box_grade (ordering rho' rho s.info)) r
        in
        push_sub context (step Reason.Box_content (ordering ty ty' s.info)) r
    | ( Ast.TyHandler (Ast.CompTy (input, eps_in), Ast.CompTy (output, eps_out)),
        Ast.TyHandler
          (Ast.CompTy (input', eps_in'), Ast.CompTy (output', eps_out')) ) ->
        let at_input = Reason.step Reason.Handler_input s.info
        and at_output = Reason.step Reason.Handler_output s.info in
        let* r = push_sub context (ordering input input' at_input) r in
        let* r = push_sub context (ordering input' input at_input) r in
        let* r =
          push_eps context
            (step Reason.Effect (ordering eps_in eps_in' at_input))
            r
        in
        let* r =
          push_eps context
            (step Reason.Effect (ordering eps_in' eps_in at_input))
            r
        in
        let* r = push_sub context (ordering output output' at_output) r in
        push_eps context
          (step Reason.Effect (ordering eps_out eps_out' at_output))
          r
    | ( ( Ast.TyParam _ | Ast.TyApply _ | Ast.TyConst _ | Ast.TyTuple _
        | Ast.TyArrow _ | Ast.TyBox _ | Ast.TyHandler _ ),
        _ ) ->
        Error (mismatch s)

  (* The pairs of [tys] and [tys'], the [i]-th at [step i] counted from 1,
     related by subtyping or by equations. *)
  and push_pairs context step_at variance info tys tys' r =
    let open Result.Syntax in
    let push_pair (i, r) ty ty' =
      let info = Reason.step (step_at i) info in
      let r =
        let* r = r in
        let* r = push_sub context { lhs = ty; rhs = ty'; info } r in
        match variance with
        | Invariant -> push_sub context { lhs = ty'; rhs = ty; info } r
        | Covariant -> Ok r
      in
      (i + 1, r)
    in
    snd (List.fold_left2 push_pair (1, Ok r) tys tys')

  let fold_result f items r =
    List.fold_left (fun r item -> Result.bind r (f item)) (Ok r) items

  let is_atomic_sub (s : sub) =
    match (s.lhs, s.rhs) with
    | Ast.TyParam _, Ast.TyParam _ -> true
    | _, _ -> false

  let is_atomic_eternal e =
    match e.eternal_ty with Ast.TyParam _ -> true | _ -> false

  let atomise context r =
    let open Result.Syntax in
    let atomic_subs, subs = List.partition is_atomic_sub r.subs
    and atomic_eternals, eternals =
      List.partition is_atomic_eternal r.eternals
    in
    let r' =
      {
        r with
        subs = atomic_subs;
        eternals = atomic_eternals;
        disjunctions = [];
      }
    in
    let* r' = fold_result (push_sub context) (List.rev subs) r' in
    let* r' = fold_result (push_eternal context) (List.rev eternals) r' in
    fold_result (disjunction_by_type context) (List.rev r.disjunctions) r'

  (* ------------------------------------------------------------------ *)
  (* Hypotheses                                                          *)
  (* ------------------------------------------------------------------ *)

  type hyps = {
    eternal_hyps : eternal list;
    sub_vars : sub list;
    rho_hyps : rho_ordering list;
    eps_hyps : eps_ordering list;
    disj_hyps : disjunction list;
  }

  let to_hyps context r =
    Result.map
      (fun r ->
        {
          eternal_hyps = r.eternals;
          sub_vars = r.subs;
          rho_hyps = r.rho_orderings;
          eps_hyps = r.eps_orderings;
          disj_hyps = r.disjunctions;
        })
      (atomise context r)

  (* A disjunction of a variable-free grade: dropped when the grade is below
     the unit, refuting when it is not and the type is never eternal. *)
  let check_disjunction context d kept =
    match N.Rho.closed_leq context.bounds d.disj_grade X.Rho.unit with
    | Some true -> Ok kept
    | Some false when Option.is_none (eternal_vars context d.disj_ty) ->
        Error
          (Refuted_rho
             { lhs = d.disj_grade; rhs = X.Rho.unit; info = [ d.disj_reason ] })
    | Some false | None -> Ok (d :: kept)

  let check_closed context hyps =
    let open Result.Syntax in
    let grades = { N.rho_hyps = hyps.rho_hyps; eps_hyps = hyps.eps_hyps } in
    let* grades =
      Result.map_error
        (function
          | N.Rho_failure o -> Refuted_rho o | N.Eps_failure o -> Refuted_eps o)
        (N.check_closed_hyps context.bounds grades)
    in
    let* disjunctions =
      fold_result (check_disjunction context) hyps.disj_hyps []
    in
    Ok
      {
        hyps with
        rho_hyps = grades.rho_hyps;
        eps_hyps = grades.eps_hyps;
        disj_hyps = List.rev disjunctions;
      }

  let rho_atom (o : rho_ordering) = C.Rho_leq (o.info, o.lhs, o.rhs)
  let eps_atom (o : eps_ordering) = C.Eps_leq (o.info, o.lhs, o.rhs)

  let hyps_to_constraint hyps =
    C.conj_all
      (List.map
         (fun e -> C.Eternal (e.eternal_reason, e.eternal_ty))
         hyps.eternal_hyps
      @ List.map (fun (s : sub) -> C.Sub (s.info, s.lhs, s.rhs)) hyps.sub_vars
      @ List.map rho_atom hyps.rho_hyps
      @ List.map eps_atom hyps.eps_hyps
      @ List.map
          (fun d -> C.Eternal_or_unit (d.disj_reason, d.disj_ty, d.disj_grade))
          hyps.disj_hyps)

  let deferred_to_constraint d =
    List.fold_right
      (fun (rigid, origin) c -> C.Forall_eps (rigid, origin, c))
      d.rigids
      (C.conj_all
         (List.map rho_atom d.rho_conditions
         @ List.map eps_atom d.eps_conditions))

  let free_vars_deferred d = C.free_vars (deferred_to_constraint d)

  (* ------------------------------------------------------------------ *)
  (* Printing                                                            *)
  (* ------------------------------------------------------------------ *)

  let print_failure failure ppf =
    let print_ordering print (o : _ GradeNormal.ordering) ppf =
      Format.fprintf ppf "%t ≾ %t" (print o.lhs) (print o.rhs)
    in
    match failure with
    | Shape_mismatch f | Occurs_check f ->
        Format.fprintf ppf "cannot relate %t and %t (%t)" (Skeleton.print f.lhs)
          (Skeleton.print f.rhs) (Reason.print f.info)
    | Refuted_rho o ->
        Format.fprintf ppf "refuted %t"
          (print_ordering (fun r -> C.print_rho r) o)
    | Refuted_eps o ->
        Format.fprintf ppf "refuted %t"
          (print_ordering (fun e -> C.print_eps e) o)
    | Never_eternal { ty; reason } ->
        Format.fprintf ppf "%t is never eternal (%t)" (C.print_ty ty)
          (Reason.print reason)
    | Refuted_condition { condition; _ } ->
        Format.fprintf ppf "refuted deferred condition %t"
          (C.print (deferred_to_constraint condition))
    | Rigid_escape _ -> Format.pp_print_string ppf "rigid variable escapes"
end
