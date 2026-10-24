(* Diagnostics of rejected commands. *)

module Ast = Language.Ast
module Diagnostic = Utils.Diagnostic
module Location = Utils.Location
module Reason = Inference.Reason

module Make (C : Inference.Constraint.S) = struct
  module X = C.X
  module GS = X.GS
  module E = Inference.Entail.Make (X)
  module T = ExplainText.Make (C)
  module L = ExplainLabels.Make (C) (T)
  module M = ExplainMismatch.Make (C) (T) (L)
  module R = T.R
  module RS = T.RS
  module S = T.S
  open T
  open L
  open M

  type source = T.source = {
    context : S.context;
    constr : C.t option;
    solution : S.solution option;
    mismatch : S.mismatch option;
  }

  (* ------------------------------------------------------------------ *)
  (* Eternality                                                          *)
  (* ------------------------------------------------------------------ *)

  (* An obligation inherited from a definition: the headline names the
     definition and what it needs eternal. *)
  let instance_eternal ty var inner =
    match (use_of inner, ty) with
    | ( Some
          {
            why =
              ( Reason.Use_under_locks { var = x; _ }
              | Reason.Op_case_capture { var = x; _ }
              | Reason.Rec_capture { var = x; _ } );
            _;
          },
        Some t ) ->
        Printf.sprintf "%s is not eternal, but %s needs %s to be eternal" t
          (describe var) (needed_eternal x)
    | ( Some
          {
            why =
              ( Reason.Use_under_locks { var = x; _ }
              | Reason.Op_case_capture { var = x; _ }
              | Reason.Rec_capture { var = x; _ } );
            _;
          },
        None ) ->
        Printf.sprintf "%s needs %s to be eternal, but it is not here"
          (String.capitalize_ascii (describe var))
          (needed_eternal x)
    | _, Some t ->
        Printf.sprintf "Type %s is not eternal, as required by the type of %s" t
          (describe var)
    | _, None ->
        Printf.sprintf "A type is not eternal, as required by the type of %s"
          (describe var)

  let box_note = function
    | Some (Ast.TyBox _) -> [ "a box type is never eternal" ]
    | _ -> []

  (* The case a capture crosses into runs with a grade the handler does not
     fix; the body of a recursive function may run at any later time. *)
  let capture_message var into t =
    let into =
      match into with
      | `Clause (clause : Reason.clause) ->
          Printf.sprintf
            "the case for %s: the case runs with a grade the handler does not \
             fix"
            (op_name clause.op)
      | `Recursive f ->
          Printf.sprintf
            "the body of the recursive function %s, which may run at any later \
             time"
            (describe f)
    in
    match t with
    | Some t ->
        Printf.sprintf
          "%s has type %s, which is not eternal, so it cannot be used in %s"
          (subject var) t into
    | None ->
        Printf.sprintf
          "%s does not have an eternal type, so it cannot be used in %s"
          (subject var) into

  let never_eternal source ty (reason : C.reason) =
    let p = printer source in
    let t = ty_code p ty in
    let message =
      match reason.why with
      | Reason.Use_under_locks { var; _ } ->
          Printf.sprintf
            "%s has type %s, which is not eternal, but is used with a grade \
             accumulated since it was bound that only an eternal type allows"
            (subject var) t
      | Reason.Op_case_capture { var; clause; _ } ->
          capture_message var (`Clause clause) (Some t)
      | Reason.Rec_capture { var; f; _ } ->
          capture_message var (`Recursive f) (Some t)
      | Reason.Instance_of { var; inner; _ } ->
          instance_eternal (Some t) var inner
      | _ -> Printf.sprintf "Type %s is not eternal" t
    in
    diagnostic ~primary:reason.at
      ~labels:
        (dedup
           (with_rigid_labels p
              (mentioned_rigids source [ reason ])
              (labels_of_reason p reason)))
      ~notes:(box_note (Some ty)) message

  (* ------------------------------------------------------------------ *)
  (* Orderings                                                           *)
  (* ------------------------------------------------------------------ *)

  (* Whether a reason names the promise an ordering breaks. *)
  let specific (r : C.reason) =
    match r.why with
    | Reason.Unboxed _ | Reason.Use_under_locks _ | Reason.Op_case_capture _
    | Reason.Rec_capture _ | Reason.Instance_of _ | Reason.Continuation_grade _
    | Reason.Default_of _ ->
        true
    | Reason.Annotation -> List.equal Reason.equal_step r.path [ Reason.Effect ]
    | Reason.Application _ | Reason.Match_scrutinee _ | Reason.Match_branch
    | Reason.Pattern_annotation | Reason.Variant_argument _
    | Reason.Successor_pattern | Reason.Boxed_value | Reason.Handler_case _
    | Reason.Perform_argument _ | Reason.Perform_continuation _
    | Reason.Handle_with | Reason.Handled_computation | Reason.Return_clause
    | Reason.Recursive_definition _ | Reason.Function_body
    | Reason.Function_parameter | Reason.Pure_body | Reason.Sequencing _
    | Reason.Continuation_effect _ | Reason.Top_definition _
    | Reason.Top_computation | Reason.Compared_values ->
        false

  (* The reason a headline is built on: the first that names a promise, else
     the last, which set the bound; none for an empty chain. *)
  let principal reasons =
    match List.find_opt specific reasons with
    | Some r -> Some r
    | None -> (
        match List.rev reasons with last :: _ -> Some last | [] -> None)

  (* A grade shown in a headline: [preferred] when it is variable-free or
     quantified over rigids only, [fallback] otherwise. *)
  let shown_rho f preferred fallback =
    let rigid_vars = List.map (fun r -> r.var) f.rigids in
    if
      X.Rho_var.Set.is_empty (X.Rho.free_rho_vars preferred)
      && X.Eps_var.Set.for_all
           (fun e -> List.exists (X.Eps_var.equal e) rigid_vars)
           (X.Rho.free_eps_vars preferred)
    then preferred
    else fallback

  (* The failing ordering of a use or an unboxing, at the grade [total]
     accumulated since the binding where it alone fails. *)
  let at_accumulated p (f : C.rho refutation) total =
    match (f.rigids, E.Rho.closed p.bounds total (snd f.instance)) with
    | [], Some false ->
        {
          f with
          stated = (total, snd f.stated);
          instance = (total, snd f.instance);
        }
    | _, (Some _ | None) -> f

  (* The headline, notes and labels of a failing ordering, by the reason it is
     built on. *)
  let ordering_message (type e) source p (f : e refutation) reason ~ty =
    let s1, s2 = f.stated in
    let g side = code (f.sort.raw p side) in
    let rs = f.rigids in
    match (reason.Reason.why, f.sort.tag) with
    | Reason.Use_under_locks { var; locks; _ }, Rho_tag ->
        let total = shown_rho f (accumulated_grade locks) (fst f.instance) in
        let f = at_accumulated p f total in
        let total = rho_code p total in
        let message =
          match Option.map (ty_code p) ty with
          | Some t ->
              Printf.sprintf
                "%s is used with grade %s accumulated since it was bound, but \
                 its type %s is not eternal"
                (subject var) total t
          | None ->
              Printf.sprintf
                "%s is used with grade %s accumulated since it was bound, but \
                 its type is not eternal"
                (subject var) total
        in
        (reason.at, message, ineq_notes p f)
    | Reason.Op_case_capture { var; clause; _ }, _ ->
        let message =
          capture_message var (`Clause clause) (Option.map (ty_code p) ty)
        in
        (reason.at, message, box_note ty @ ineq_notes p f)
    | Reason.Rec_capture { var; f = g; _ }, _ ->
        let message =
          capture_message var (`Recursive g) (Option.map (ty_code p) ty)
        in
        (reason.at, message, box_note ty @ ineq_notes p f)
    | Reason.Instance_of { var; inner; _ }, _ when Option.is_some (use_of inner)
      ->
        let t = Option.map (ty_code p) ty in
        (reason.at, instance_eternal t var inner, ineq_notes p f)
    | Reason.Unboxed { var; locks; _ }, Rho_tag ->
        let total = shown_rho f (accumulated_grade locks) (fst f.instance) in
        let f = at_accumulated p f total in
        let unit_word = if is_unit_rho p total then "the unit " else "" in
        let message =
          Printf.sprintf
            "%s is unboxed with %sgrade %s accumulated since it was bound, \
             which is not below its box grade %s"
            (subject var) unit_word (rho_code p total) (g s2)
        in
        (reason.at, message, ineq_notes p f)
    | Reason.Continuation_grade { op; _ }, _ when not (List.is_empty rs) ->
        let quantifier = String.capitalize_ascii (for_every p rs) in
        let g2 = g s2 in
        let g1 = g s1 in
        ( reason.at,
          Printf.sprintf
            "%s, the case for %s must have a grade matching %s, but its grade \
             %s does not"
            quantifier (op_name op) g2 g1,
          ineq_notes p f )
    | Reason.Continuation_grade { op; _ }, _ ->
        let g1 = g s1 in
        let g2 = g s2 in
        ( reason.at,
          Printf.sprintf
            "The case for %s has grade %s, which does not match the grade %s \
             of %s followed by its continuation"
            (op_name op) g1 g2 (op_name op),
          ineq_notes p f )
    | Reason.Default_of { op; _ }, _ ->
        let g1 = g s1 in
        let g2 = g s2 in
        ( reason.at,
          Printf.sprintf
            "The default implementation of %s has grade %s, which does not \
             match the declared grade %s of %s"
            (op_name op) g1 g2 (op_name op),
          ineq_notes p f )
    | Reason.Annotation, _ when specific reason ->
        let g1 = g s1 in
        let g2 = g s2 in
        ( reason.at,
          Printf.sprintf
            "This function's body has grade %s, which does not match its \
             annotated grade %s"
            g1 g2,
          ineq_notes p f )
    | _ -> (
        let inequality =
          Printf.sprintf "The %s inequality %s does not hold" f.sort.noun
            (quantified p rs (ineq_text p f.sort f.stated))
        in
        let witness =
          if List.is_empty rs then counterexample_notes p f else ineq_notes p f
        in
        match root source reason with
        | Some ((r : C.reason), a, b, _)
          when List.length r.path < List.length reason.path -> (
            match worded r reason.path (a, b) with
            | Some (path, (a, b)) ->
                let o = ty_code p a in
                let e = ty_code p b in
                let primary, message =
                  mismatch_message ~reason:r ~path ~o ~e ~non_box:e
                in
                (primary, message, ineq_notes p f)
            | None ->
                let o = ty_code p a in
                let e = ty_code p b in
                ( reason.at,
                  inequality,
                  Printf.sprintf "while matching %s against %s" o e :: witness
                ))
        | Some _ | None -> (reason.at, inequality, witness))

  let refuted_ordering source p f =
    match principal f.reasons with
    | None ->
        {
          Diagnostic.kind = Diagnostic.Typing;
          primary = None;
          message = String.capitalize_ascii (ineq_note p f);
          labels = [];
          notes = [];
        }
    | Some reason ->
        let ty =
          match use_of reason with
          | Some _ -> disjunction_ty source reason
          | None -> None
        in
        let primary, message, notes = ordering_message source p f reason ~ty in
        let labels = labels_of_reason p reason in
        let labels =
          labels
          @ chain_labels ~primary ~labels
              (List.filter (fun r -> r != reason) f.reasons)
        in
        let rigids =
          union_rigids f.rigids
            (union_rigids
               (mentioned_rigids source [ reason ])
               (ty_rigids source ty))
        in
        diagnostic ~primary
          ~labels:(dedup (with_rigid_labels p rigids labels))
          ~notes message

  (* The rigids a rewritten ordering was stated with, each at the value the
     rewriting gave it: the top where it stood on the left, the unit on the
     right. *)
  let restated source sort
      (o : ('e, C.reason list) Inference.GradeNormal.ordering) =
    match Option.bind (principal o.info) sort.stated_of with
    | None -> ((o.lhs, o.rhs), [])
    | Some (lhs, rhs) -> (
        let instance =
          X.Eps_var.Set.union (sort.eps_vars o.lhs) (sort.eps_vars o.rhs)
        in
        let vars =
          X.Eps_var.Set.diff
            (X.Eps_var.Set.union (sort.eps_vars lhs) (sort.eps_vars rhs))
            instance
        in
        let value var =
          if X.Eps_var.Set.mem var (sort.eps_vars lhs) then GS.E.top
          else GS.E.one
        in
        match rigids_of source vars ~value with
        | [] -> ((o.lhs, o.rhs), [])
        | rs -> ((lhs, rhs), rs))

  (* Whether two reasons are atoms of the qualifier of one instance of a
     scheme: of the same variable at the same use. *)
  let same_instance (r : C.reason) (r' : C.reason) =
    match (r.why, r'.why) with
    | Reason.Instance_of { var; _ }, Reason.Instance_of { var = var'; _ } ->
        Location.equal r.at r'.at && Ast.Variable.equal var var'
    | _ -> false

  (* The hypotheses an ordering of reason [reason] was bounded by, transitively
     through the unknowns of its left side ([`Below]) or of its right side
     ([`Above]), the farthest first, up to four links away. A run of
     hypotheses of one instance of a scheme counts as one link. *)
  let bounds sort hyps (o : ('e, C.reason) Inference.GradeNormal.ordering)
      direction =
    let rec go depth (o : ('e, C.reason) Inference.GradeNormal.ordering) seen =
      if depth = 0 then []
      else
        let frontier =
          match direction with `Below -> o.lhs | `Above -> o.rhs
        in
        let links =
          List.filter
            (fun (h : ('e, C.reason) Inference.GradeNormal.ordering) ->
              (not (List.memq h seen))
              &&
              match direction with
              | `Below -> sort.shares h.rhs frontier
              | `Above -> sort.shares h.lhs frontier)
            hyps
        in
        List.concat_map
          (fun (h : ('e, C.reason) Inference.GradeNormal.ordering) ->
            let link = if same_instance h.info o.info then 0 else 1 in
            go (depth - link) h (links @ seen) @ [ h.info ])
          links
    in
    go 4 o [ o ]

  (* The reasons of an ordering refuted in the search for a closed instance,
     completed by those of the hypotheses that gave its unknowns their
     values. *)
  let completed source sort
      (o : ('e, C.reason list) Inference.GradeNormal.ordering) =
    match
      (Option.map (fun (s : S.solution) -> s.hyps) source.solution, o.info)
    with
    | Some hyps, [ reason ] -> (
        let hyps = sort.hyps_of hyps in
        match
          List.find_opt
            (fun (h : ('e, C.reason) Inference.GradeNormal.ordering) ->
              List.equal Reason.equal_step h.info.path reason.path
              && same_origin h.info reason)
            hyps
        with
        | Some h ->
            bounds sort hyps h `Below @ [ reason ]
            @ List.rev (bounds sort hyps h `Above)
        | None -> o.info)
    | Some _, ([] | _ :: _ :: _) | None, _ -> o.info

  let refuted_orderings source sort o =
    let p = printer source in
    let stated, rigids = restated source sort o in
    refuted_ordering source p
      {
        sort;
        stated;
        instance = (o.lhs, o.rhs);
        rigids;
        reasons = completed source sort o;
      }

  type at_ordering = {
    at :
      'e.
      'e sort -> ('e, C.reason) Inference.GradeNormal.ordering -> Diagnostic.t;
  }
  (** A diagnostic built on an ordering of either sort. *)

  (* The diagnostic [k] builds on the first ordering of the condition [d] of
     the case of [origin]; without one, the case cannot be typed. *)
  let first_condition (d : R.deferred) (origin : Reason.rigid_origin) k =
    match (d.rho_conditions, d.eps_conditions) with
    | o :: _, _ -> k.at rho_sort o
    | [], o :: _ -> k.at eps_sort o
    | [], [] ->
        diagnostic ~primary:origin.clause.case_at ~labels:[] ~notes:[]
          (Printf.sprintf
             "The case for %s cannot be typed for every grade of %s"
             (op_name origin.clause.op)
             (continuation_phrase origin))

  (* The diagnostic of an ordering [o] of the case of [origin], mentioning the
     rigids [rs], that cannot be decided. *)
  let clause_ordering p (origin : Reason.rigid_origin) rs
      (o : (_, C.reason) Inference.GradeNormal.ordering) ~note message =
    diagnostic ~primary:o.info.at
      ~labels:
        (dedup
           (labels_of_reason p o.info @ rigid_labels p rs
           @ [
               label origin.clause.case_at
                 (Printf.sprintf "the case for %s begins %s"
                    (op_name origin.clause.op) here);
             ]))
      ~notes:[ note ] message

  let refuted_condition source (d : R.deferred) witness =
    let p = printer source in
    let values = List.combine (List.map fst d.rigids) witness in
    let rigids =
      rigids_of source
        (X.Eps_var.Set.of_list (List.map fst d.rigids))
        ~value:(fun var -> List.assoc var values)
    in
    let at_witness : X.subst =
      {
        X.empty_subst with
        eps_subst =
          List.fold_left
            (fun m (var, c) -> X.Eps_var.Map.add var (X.Eps.const c) m)
            X.Eps_var.Map.empty values;
      }
    in
    let refute : type e.
        e sort -> (e, C.reason) Inference.GradeNormal.ordering -> _ =
     fun sort o ->
      refuted_ordering source p
        {
          sort;
          stated = (o.lhs, o.rhs);
          instance = (sort.subst at_witness o.lhs, sort.subst at_witness o.rhs);
          rigids;
          reasons = [ o.info ];
        }
    in
    first_condition d d.origin { at = refute }

  (* ------------------------------------------------------------------ *)
  (* Continuation grades out of their clause                             *)
  (* ------------------------------------------------------------------ *)

  let rigid_escape source (origin : Reason.rigid_origin) =
    let p = printer source in
    let rs =
      match source.constr with
      | Some c ->
          List.filter_map
            (fun (var, o) ->
              if Reason.equal_rigid_origin o origin then
                Some { var; origin; value = GS.E.top }
              else None)
            (rigid_origins c)
      | None -> []
    in
    let grade =
      match rs with r :: _ -> " " ^ code (rigid_raw p r) | [] -> ""
    in
    diagnostic ~primary:origin.clause.case_at
      ~labels:
        (declared_label origin.clause.op origin.clause.signature_at
        :: rigid_labels p rs)
      ~notes:
        [
          "a type inferred outside the case would depend on the continuation's \
           grade";
        ]
      (Printf.sprintf
         "The grade%s of %s in the case for %s may be any grade, so it cannot \
          occur in a type outside the case"
         grade
         (continuation_phrase origin)
         (op_name origin.clause.op))

  (* A condition of a run that is neither discharged nor refuted, reported
     at its first ordering. *)
  let undecided_condition source (d : R.deferred) =
    let p = printer source in
    let origin = d.origin in
    let report (type e) (sort : e sort)
        (o : (e, C.reason) Inference.GradeNormal.ordering) =
      let mentioned =
        X.Eps_var.Set.union (sort.eps_vars o.lhs) (sort.eps_vars o.rhs)
      in
      let rs =
        List.filter_map
          (fun (var, origin) ->
            if X.Eps_var.Set.mem var mentioned then
              Some { var; origin; value = GS.E.top }
            else None)
          d.rigids
      in
      clause_ordering p origin rs o
        ~note:
          (Printf.sprintf
             "a run requires the %s inequality to hold for every grade %s may \
              have, and it is neither derived nor refuted"
             sort.noun
             (continuation_phrase origin))
        (Printf.sprintf
           "The condition %s of the case for %s cannot be established"
           (quantified p rs (ineq_text p sort (o.lhs, o.rhs)))
           (op_name origin.clause.op))
    in
    first_condition d origin { at = report }

  (* The conditions of a run that share unknowns and hold together at none of
     the grades tried, in reading order. *)
  let unestablished ?(subject = "this run") source ~rho_orderings ~eps_orderings
      ~conditions ~abandoned =
    let p = printer source in
    let ordering (type e) (sort : e sort) rigids
        (o : (e, C.reason) Inference.GradeNormal.ordering) =
      let mentioned =
        X.Eps_var.Set.union (sort.eps_vars o.lhs) (sort.eps_vars o.rhs)
      in
      let rs =
        List.filter_map
          (fun (var, origin) ->
            if X.Eps_var.Set.mem var mentioned then
              Some { var; origin; value = GS.E.top }
            else None)
          rigids
      in
      (o.info, rs, fun () -> quantified p rs (ineq_text p sort (o.lhs, o.rhs)))
    in
    let items =
      List.map (ordering rho_sort []) rho_orderings
      @ List.map (ordering eps_sort []) eps_orderings
      @ List.concat_map
          (fun (d : R.deferred) ->
            List.map (ordering rho_sort d.rigids) d.rho_conditions
            @ List.map (ordering eps_sort d.rigids) d.eps_conditions)
          conditions
      |> List.stable_sort (fun ((r : C.reason), _, _) ((r' : C.reason), _, _) ->
          Location.compare r.at r'.at)
    in
    let texts = List.map (fun (_, _, text) -> text ()) items in
    let shown = List.take 4 texts and hidden = List.length texts - 4 in
    let listed =
      match (List.rev shown, hidden > 0) with
      | [], _ -> ""
      | [ text ], false -> text
      | last :: rest, false ->
          String.concat ", " (List.rev rest) ^ " and " ^ last
      | _, true ->
          Printf.sprintf "%s and %d more" (String.concat ", " shown) hidden
    in
    let reasons = List.map (fun (r, _, _) -> r) items in
    let rs =
      List.fold_left (fun acc (_, rs, _) -> union_rigids acc rs) [] items
    in
    let message =
      Printf.sprintf "The conditions of %s could not be established: %s" subject
        listed
    and notes =
      Printf.sprintf
        "%s requires grades for its unknowns at which every one of these \
         holds; none of the grades tried does, although the definitions they \
         come from were accepted"
        subject
      ::
      (if abandoned then
         [
           Printf.sprintf
             "the search for such grades was abandoned after %d trials"
             RS.default_budget;
         ]
       else [])
    in
    match reasons with
    | [] ->
        {
          Diagnostic.kind = Diagnostic.Typing;
          primary = None;
          message;
          labels = [];
          notes;
        }
    | (first : C.reason) :: _ ->
        let primary = first.at in
        let labels = List.concat_map (labels_of_reason p) reasons in
        let labels = labels @ chain_labels ~primary ~labels reasons in
        diagnostic ~primary
          ~labels:(dedup (with_rigid_labels p rs labels))
          ~notes message

  let refuted ?subject source = function
    | R.Shape_mismatch f | R.Occurs_check f -> mismatch source f
    | R.Refuted_rho o -> refuted_orderings source rho_sort o
    | R.Refuted_eps o -> refuted_orderings source eps_sort o
    | R.Never_eternal { ty; reason } -> never_eternal source ty reason
    | R.Refuted_condition { condition; witness } ->
        refuted_condition source condition witness
    | R.Undecided_condition condition -> undecided_condition source condition
    | R.Unestablished { rho_orderings; eps_orderings; conditions; abandoned } ->
        unestablished ?subject source ~rho_orderings ~eps_orderings ~conditions
          ~abandoned
    | R.Rigid_escape origin -> rigid_escape source origin

  (* ------------------------------------------------------------------ *)
  (* Undecided clauses                                                   *)
  (* ------------------------------------------------------------------ *)

  (* An ordering of a clause that cannot be kept outside it nor decided for
     every value of the rigids it mentions. *)
  let undecided (type e) source p (origin : Reason.rigid_origin) (sort : e sort)
      (o : (e, C.reason) Inference.GradeNormal.ordering) =
    let rs =
      rigids_of source
        (X.Eps_var.Set.union (sort.eps_vars o.lhs) (sort.eps_vars o.rhs))
        ~value:(fun _ -> GS.E.top)
    in
    let ineq = quantified p rs (ineq_text p sort (o.lhs, o.rhs)) in
    let message =
      match rs with
      | [] ->
          Printf.sprintf
            "Cannot decide the %s inequality %s for every grade %s may have"
            sort.noun ineq
            (continuation_phrase origin)
      | rs ->
          Printf.sprintf "Cannot decide the %s inequality %s %s" sort.noun ineq
            (for_every p rs)
    in
    clause_ordering p origin rs o
      ~note:
        (Printf.sprintf
           "it relates grades inferred inside the case for %s to the grade of \
            %s, which the case must allow to be any grade"
           (op_name origin.clause.op)
           (continuation_phrase origin))
      message

  let stuck source (s : RS.stuck) =
    let p = printer source in
    let origin = s.stuck_origin in
    match s.blocking with
    | RS.Blocking_rho o -> undecided source p origin rho_sort o
    | RS.Blocking_eps o -> undecided source p origin eps_sort o
    | RS.Blocking_deferred d ->
        first_condition d origin
          { at = (fun sort o -> undecided source p origin sort o) }

  (* ------------------------------------------------------------------ *)
  (* Refuted atoms                                                       *)
  (* ------------------------------------------------------------------ *)

  (* The reason of the atom a failure refutes, the one its diagnostic is built
     on, when the failure names one. *)
  let refuted_reason = function
    | R.Shape_mismatch f | R.Occurs_check f -> Some f.info
    | R.Refuted_rho o -> principal o.info
    | R.Refuted_eps o -> principal o.info
    | R.Never_eternal { reason; _ } -> Some reason
    | R.Refuted_condition { condition; _ } | R.Undecided_condition condition
      -> (
        match (condition.rho_conditions, condition.eps_conditions) with
        | o :: _, _ -> Some o.info
        | [], o :: _ -> Some o.info
        | [], [] -> None)
    | R.Unestablished _ | R.Rigid_escape _ -> None

  let refutes_effect = function
    | R.Refuted_eps _ -> true
    | R.Refuted_condition { condition = { rho_conditions = []; _ }; _ }
    | R.Undecided_condition { rho_conditions = []; _ } ->
        true
    | R.Refuted_condition _ | R.Undecided_condition _ | R.Shape_mismatch _
    | R.Occurs_check _ | R.Refuted_rho _ | R.Never_eternal _ | R.Unestablished _
    | R.Rigid_escape _ ->
        false

  let reason_of_atom = function
    | C.Sub (r, _, _)
    | C.Rho_leq (r, _, _)
    | C.Eps_leq (r, _, _)
    | C.Eternal (r, _)
    | C.Eternal_or_unit (r, _, _) ->
        Some r
    | C.True | C.And _ | C.Exists _ | C.Forall_eps _ -> None

  let without_refuted failure c =
    Option.bind (refuted_reason failure) (fun reason ->
        let refuted atom =
          Option.fold ~none:false ~some:(generated_by reason)
            (reason_of_atom atom)
        in
        if List.exists refuted (atoms c) then Some (drop refuted c) else None)
end
