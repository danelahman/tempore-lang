(* The diagnostics of type mismatches. *)

module Ast = Language.Ast
module Diagnostic = Utils.Diagnostic
module Location = Utils.Location
module Reason = Inference.Reason
module Skeleton = Inference.Skeleton

module Make
    (C : Inference.Constraint.S)
    (T : module type of struct
      include ExplainText.Make (C)
    end)
    (L : module type of struct
      include ExplainLabels.Make (C) (T)
    end) =
struct
  module S = T.S
  open T
  open L

  (* ------------------------------------------------------------------ *)
  (* Solutions without the failing atoms                                 *)
  (* ------------------------------------------------------------------ *)

  let same_origin (r : C.reason) (r' : C.reason) =
    let any _ _ = true in
    Reason.equal any any
      { r with path = []; stated = None }
      { r' with path = []; stated = None }

  let rec is_prefix path path' =
    match (path, path') with
    | [], _ -> true
    | step :: path, step' :: path' ->
        Reason.equal_step step step' && is_prefix path path'
    | _ :: _, [] -> false

  let generated_by (failing : C.reason) (r : C.reason) =
    is_prefix r.path failing.path && same_origin r failing

  let rec atoms = function
    | C.True -> []
    | C.And (c, d) -> atoms c @ atoms d
    | C.Exists (_, c) | C.Forall_eps (_, _, c) -> atoms c
    | (C.Sub _ | C.Rho_leq _ | C.Eps_leq _ | C.Eternal _ | C.Eternal_or_unit _)
      as atom ->
        [ atom ]

  let rec drop dropped = function
    | C.And (c, d) -> C.conj (drop dropped c) (drop dropped d)
    | C.Exists (vs, c) -> C.Exists (vs, drop dropped c)
    | C.Forall_eps (rigid, origin, c) ->
        C.Forall_eps (rigid, origin, drop dropped c)
    | c -> if dropped c then C.True else c

  (* An instance of a solution as a message shows it: its grade unknowns given
     their values in the search for a closed instance of its qualifier
     ({!instance_values}). *)
  let instance context (solution : S.solution) =
    let values = instance_values context solution in
    fun ty ->
      C.subst_ty
        { C.empty_subst with grade_subst = values }
        (C.subst_ty solution.subst ty)

  (* The types of a solution of the constraint without the atoms [dropped],
     when it has one. *)
  let without source dropped =
    Option.bind source.constr (fun c ->
        match S.solve source.context (drop dropped c) with
        | S.Solved solution -> Some (instance source.context solution)
        | S.Refuted _ | S.Stuck _ -> None)

  let disjunction_ty source (reason : C.reason) =
    let is_disjunction = function
      | C.Eternal_or_unit (r, _, _) -> generated_by reason r
      | _ -> false
    in
    Option.bind source.constr (fun c ->
        match List.find_opt is_disjunction (atoms c) with
        | Some (C.Eternal_or_unit (_, ty, _)) ->
            Option.map
              (fun resolve -> resolve ty)
              (without source is_disjunction)
        | Some _ | None -> None)

  let root source (reason : C.reason) =
    Option.bind source.constr (fun c ->
        let subs =
          List.filter_map
            (function
              | C.Sub (r, a, b) when generated_by reason r -> Some (r, a, b)
              | _ -> None)
            (atoms c)
        in
        let longest =
          List.fold_left
            (fun n ((r : C.reason), _, _) -> max n (List.length r.path))
            (-1) subs
        in
        let is_root (r : C.reason) =
          generated_by reason r && List.length r.path = longest
        in
        match List.filter (fun (r, _, _) -> is_root r) subs with
        | [] -> None
        | (r, a, b) :: _ ->
            let dropped = function
              | C.Sub (r', _, _) -> is_root r'
              | _ -> false
            in
            Option.map
              (fun resolve -> (r, resolve a, resolve b, resolve))
              (without source dropped))

  (* The sides of the generated atom of the function of an application. *)
  let function_atom source (reason : C.reason) ~func_at =
    let generated = { reason with subject = Some func_at } in
    Option.bind source.constr (fun c ->
        List.find_map
          (function
            | C.Sub (r, a, b)
              when List.is_empty r.path && same_origin r generated ->
                Some (a, b)
            | _ -> None)
          (atoms c))

  (* The type of the function of an application, from its generated atom. *)
  let function_ty source resolve reason ~func_at =
    Option.map (fun (a, _) -> resolve a) (function_atom source reason ~func_at)

  (* ------------------------------------------------------------------ *)
  (* Type mismatches                                                     *)
  (* ------------------------------------------------------------------ *)

  (* The steps of a path the solver took, after those the generation took. *)
  let solver_steps (reason : C.reason) path =
    match (reason.why, path) with
    | (Reason.Application _ | Reason.Default_of _), _ :: path -> path
    | _, path -> path

  (* Whether the sides of an atom at [path] are the other way round from the
     subject's and the expected type's: under an odd number of function
     domains. *)
  let flipped reason path =
    List.length
      (List.filter
         (Reason.equal_step Reason.Argument)
         (solver_steps reason path))
    mod 2
    = 1

  (* The place and the sentence by which the construct of [reason] words a
     mismatch at [path] between the whole type [o] the subject offers and the
     type [e] expected, where it words one. *)
  let types_sentence (reason : C.reason) path =
    let at = reason.at in
    let sentence at f = Some (at, f) in
    match (reason.why, path) with
    | Reason.Application { arg_at; _ }, Reason.Argument :: _ ->
        sentence arg_at (fun o e ->
            Printf.sprintf
              "This argument has type %s but the function expects %s" o e)
    | Reason.Application _, Reason.Result :: _ ->
        sentence at (fun o e ->
            Printf.sprintf "The application has type %s but %s is expected here"
              o e)
    | Reason.Match_scrutinee { scrutinee_at }, _
      when Location.equal at scrutinee_at ->
        sentence at (fun o e ->
            Printf.sprintf
              "This expression has type %s but the patterns match values of \
               type %s"
              o e)
    | Reason.Match_scrutinee _, _ ->
        sentence at (fun o e ->
            Printf.sprintf
              "This pattern matches values of type %s but the matched value \
               has type %s"
              e o)
    | Reason.Match_branch, _ ->
        sentence at (fun o e ->
            Printf.sprintf
              "This branch has type %s but the other branches have type %s" o e)
    | Reason.Annotation, _ ->
        sentence at (fun o e ->
            Printf.sprintf
              "This expression has type %s but is annotated with %s" o e)
    | Reason.Pattern_annotation, _ ->
        sentence at (fun o e ->
            Printf.sprintf "This pattern has type %s but is annotated with %s" o
              e)
    | Reason.Variant_argument lbl, _ ->
        sentence at (fun o e ->
            Printf.sprintf
              "Constructor %s expects an argument of type %s but is given %s"
              (label_name lbl) e o)
    | Reason.Successor_pattern, _ ->
        sentence at (fun o e ->
            Printf.sprintf
              "This pattern matches values of type %s but, as the argument of \
               a successor pattern, is given values of type %s"
              e o)
    | Reason.Boxed_value, _ ->
        sentence at (fun o e ->
            Printf.sprintf "The boxed value has type %s but is bound as %s" o e)
    | Reason.Unboxed { var; _ }, _ :: _ ->
        sentence at (fun o e ->
            Printf.sprintf "%s holds a value of type %s but it is bound as %s"
              (holder var) o e)
    | Reason.Perform_argument { op; _ }, _ ->
        sentence at (fun o e ->
            Printf.sprintf
              "Operation %s takes an argument of type %s but is given %s"
              (op_name op) e o)
    | Reason.Perform_continuation { op; _ }, _ ->
        sentence at (fun o e ->
            Printf.sprintf
              "The result of %s has type %s but the continuation binds it as %s"
              (op_name op) o e)
    | Reason.Handler_case { op; _ }, Reason.Component 1 :: _ ->
        sentence at (fun o e ->
            Printf.sprintf
              "The argument of %s has type %s but the case binds it as %s"
              (op_name op) o e)
    | Reason.Handler_case { op; _ }, Reason.Component 2 :: _ ->
        sentence at (fun o e ->
            Printf.sprintf
              "The continuation of %s has type %s but the case binds it as %s"
              (op_name op) o e)
    | Reason.Handler_case { op; _ }, [] ->
        sentence at (fun o e ->
            Printf.sprintf
              "The case for %s returns %s but the return clause returns %s"
              (op_name op) o e)
    | Reason.Handle_with, Reason.Handler_input :: _ ->
        sentence at (fun o e ->
            Printf.sprintf
              "This handler handles computations of type %s but the handled \
               computation has type %s"
              o e)
    | Reason.Handle_with, Reason.Handler_output :: _ ->
        sentence at (fun o e ->
            Printf.sprintf
              "This handler returns values of type %s but %s is expected here" o
              e)
    | Reason.Handled_computation, _ ->
        sentence at (fun o e ->
            Printf.sprintf
              "The handled computation has type %s but the handler handles \
               computations of type %s"
              o e)
    | Reason.Return_clause, _ ->
        sentence at (fun o e ->
            Printf.sprintf
              "The return clause has type %s but the handler's result has type \
               %s"
              o e)
    | Reason.Recursive_definition f, _ ->
        sentence at (fun o e ->
            Printf.sprintf
              "The body of the recursive function %s has type %s but %s is \
               used as returning %s"
              (describe f) o (describe f) e)
    | Reason.Default_of { op; _ }, Reason.Argument :: _ ->
        let op = op_name op in
        sentence at (fun o e ->
            Printf.sprintf
              "The default implementation of %s binds its argument as %s but \
               %s takes %s"
              op e op o)
    | Reason.Default_of { op; _ }, Reason.Result :: _ ->
        let op = op_name op in
        sentence at (fun o e ->
            Printf.sprintf
              "The default implementation of %s returns %s but %s returns %s" op
              o op e)
    | ( ( Reason.Application _ | Reason.Handler_case _ | Reason.Handle_with
        | Reason.Default_of _ | Reason.Unboxed _ | Reason.Instance_of _
        | Reason.Use_under_locks _ | Reason.Op_case_capture _
        | Reason.Rec_capture _ | Reason.Continuation_grade _
        | Reason.Function_body | Reason.Function_parameter | Reason.Pure_body
        | Reason.Sequencing _ | Reason.Continuation_effect _
        | Reason.Top_definition _ | Reason.Top_computation
        | Reason.Compared_values ),
        _ ) ->
        None

  let mismatch_message ~(reason : C.reason) ~path ~o ~e ~non_box =
    let at = reason.at in
    match (reason.why, path) with
    | Reason.Application { func_at; _ }, [] ->
        ( func_at,
          Printf.sprintf "This expression has type %s and cannot be applied" o
        )
    | Reason.Unboxed { var; annotated; _ }, [] ->
        ( at,
          Printf.sprintf
            "%s %s type %s, which is not a boxed type, and cannot be unboxed"
            (subject var)
            (if annotated then "is annotated with" else "has")
            non_box )
    | Reason.Handle_with, [] ->
        (at, Printf.sprintf "This expression has type %s and is not a handler" o)
    | _ -> (
        let generic =
          Printf.sprintf "Type %s is not compatible with type %s" o e
        in
        match (types_sentence reason path, reason.why) with
        | Some (at, sentence), _ -> (at, sentence o e)
        | None, Reason.Instance_of { var; _ } ->
            ( at,
              Printf.sprintf "%s, as the type of %s requires" generic
                (describe var) )
        | None, _ -> (at, generic))

  (* Whether the construct of [reason] words a mismatch between whole types,
     rather than a shape alone or no construct in particular. *)
  let words_types reason path = Option.is_some (types_sentence reason path)

  (* The sides of a subtyping atom one step down: the argument's type and the
     function's domain, or the two results. *)
  let descend step (a, b) =
    match (step, a, b) with
    | Reason.Argument, Ast.TyArrow (a, _), Ast.TyArrow (b, _) -> Some (b, a)
    | ( Reason.Result,
        Ast.TyArrow (_, Ast.CompTy (a, _)),
        Ast.TyArrow (_, Ast.CompTy (b, _)) ) ->
        Some (a, b)
    | _ -> None

  let worded (root : C.reason) path sides =
    if words_types root root.path then Some (root.path, sides)
    else
      match List.filteri (fun i _ -> i >= List.length root.path) path with
      | step :: _ when words_types root (root.path @ [ step ]) ->
          Option.map
            (fun sides -> (root.path @ [ step ], sides))
            (descend step sides)
      | _ -> None

  (* The provenance of the failed expansion [f], as solving recorded it. The
     solver records the reason of the failing atom itself, so the provenance
     of [f] is recognised by the identity of that reason. *)
  let recorded source (f : C.reason Skeleton.failure) =
    match source.mismatch with
    | Some (m : S.mismatch) when m.atom.info == f.info -> Some m
    | Some _ | None -> None

  (* A label at the place each part [shown] of a mismatch was decided, other
     than the construct [at] of the failing atom and the places already
     pointed at. *)
  let decided_labels ~primary ~at ~labels sides =
    List.rev
    @@ List.fold_left
         (fun acc (shown, decision) ->
           match decision with
           | Some (d : S.decision)
             when not
                    (Location.equal d.reason.at primary
                    || Location.equal d.reason.at at
                    || List.exists
                         (fun (l : Diagnostic.label) ->
                           Location.equal l.span d.reason.at)
                         (labels @ acc)) ->
               label d.reason.at (shown ^ " was inferred " ^ here) :: acc
           | Some _ | None -> acc)
         [] sides

  (* Whether the span [outer] encloses the span [inner]. *)
  let encloses (outer : Location.t) (inner : Location.t) =
    String.equal outer.filename inner.filename
    && outer.start.offset <= inner.start.offset
    && inner.stop.offset <= outer.stop.offset

  (* The [i]th component of [noun], counting from 1. *)
  let component_of i noun =
    let ordinals =
      [
        "first";
        "second";
        "third";
        "fourth";
        "fifth";
        "sixth";
        "seventh";
        "eighth";
        "ninth";
        "tenth";
      ]
    in
    match List.nth_opt ordinals (i - 1) with
    | Some ordinal -> Printf.sprintf "the %s component of %s" ordinal noun
    | None -> Printf.sprintf "component %d of %s" i noun

  (* [noun], or its component at the first step of [path] when that step is
     one. *)
  let leading_part path noun =
    match path with Reason.Component i :: _ -> component_of i noun | _ -> noun

  (* A variable a message names, or [fallback]. *)
  let named fallback x =
    match Option.bind x var_name with Some name -> name | None -> fallback

  (* What the atom of a related decision does at its place, from its
     construct and the position [path] of the unknowns it relates; a use no
     construct words is stated by the skeleton [joined] they stand for. *)
  let use_text p (reason : C.reason) path joined =
    let given what whose = Printf.sprintf "%s is given %s %s" what whose here in
    match (reason.why, path) with
    | Reason.Application { func; arg; _ }, Reason.Argument :: _ ->
        let argument =
          match Option.bind arg var_name with
          | Some name -> "the argument " ^ name
          | None -> "the argument"
        in
        given argument ("the parameter type of " ^ named "the function" func)
    | Reason.Application { func; _ }, Reason.Result :: _ ->
        given "the application"
          ("the result type of " ^ named "the function" func)
    | Reason.Application { func; _ }, _ ->
        Printf.sprintf "%s is applied %s" (named "the function" func) here
    | Reason.Match_scrutinee { scrutinee_at }, _
      when Location.equal reason.at scrutinee_at ->
        Printf.sprintf "this value is matched against the patterns %s" here
    | Reason.Match_scrutinee _, Reason.Component i :: _ ->
        Printf.sprintf "%s binds %s %s"
          (component_of i "this pattern")
          (component_of i "the matched value")
          here
    | Reason.Match_scrutinee _, _ ->
        given "this pattern" "the type of the matched value"
    | Reason.Match_branch, _ -> given "this branch" "the type of the match"
    | Reason.Annotation, _ ->
        given (leading_part path "this expression") "the annotated type"
    | Reason.Pattern_annotation, _ ->
        given (leading_part path "this pattern") "the annotated type"
    | Reason.Variant_argument lbl, _ when Ast.Label.equal lbl Ast.cons_label ->
        Printf.sprintf "the elements of this list are given one type %s" here
    | Reason.Variant_argument lbl, _ ->
        given "this argument"
          ("the argument type of constructor " ^ label_name lbl)
    | Reason.Successor_pattern, _ ->
        Printf.sprintf "this pattern matches natural numbers %s" here
    | Reason.Boxed_value, _ ->
        given "the boxed value" "the content type of the box"
    | Reason.Unboxed { var; _ }, _ ->
        Printf.sprintf "the content of %s is bound %s" (describe var) here
    | ( ( Reason.Use_under_locks { var; _ }
        | Reason.Op_case_capture { var; _ }
        | Reason.Rec_capture { var; _ } ),
        _ ) ->
        Printf.sprintf "%s is used %s" (describe var) here
    | Reason.Instance_of { var; _ }, _ ->
        Printf.sprintf "%s is used at an instance of its type %s" (describe var)
          here
    | Reason.Handler_case { op; _ }, Reason.Component 1 :: _ ->
        Printf.sprintf "the case for %s binds the argument of %s %s"
          (op_name op) (op_name op) here
    | Reason.Handler_case { op; _ }, Reason.Component 2 :: _ ->
        Printf.sprintf "the case for %s binds the continuation of %s %s"
          (op_name op) (op_name op) here
    | Reason.Handler_case { op; _ }, _ ->
        given ("the case for " ^ op_name op) "the result type of the handler"
    | Reason.Perform_argument { op; _ }, _ ->
        given "this argument" ("the parameter type of operation " ^ op_name op)
    | Reason.Perform_continuation { op; _ }, _ ->
        given "this pattern" ("the result type of operation " ^ op_name op)
    | Reason.Handle_with, Reason.Handler_input :: _ ->
        given "the handled computation" "the input type of this handler"
    | Reason.Handle_with, Reason.Handler_output :: _ ->
        given "the result of the handling" "the output type of this handler"
    | Reason.Handle_with, _ ->
        Printf.sprintf "this expression is used as a handler %s" here
    | Reason.Handled_computation, _ ->
        given "the handled computation" "the input type of the handler"
    | Reason.Return_clause, _ ->
        given "the return clause" "the input and output types of the handler"
    | Reason.Recursive_definition f, _ ->
        given ("the body of " ^ describe f) ("the result type of " ^ describe f)
    | Reason.Function_body, _ ->
        given "the body" "the result type of the function"
    | Reason.Function_parameter, _ ->
        given "this parameter" "the parameter type of the function"
    | Reason.Sequencing x, _ -> (
        match Option.bind x var_name with
        | Some name ->
            Printf.sprintf "the value of this computation is bound to %s %s"
              name here
        | None ->
            Printf.sprintf
              "the value of this computation is matched against the pattern %s"
              here)
    | Reason.Default_of { op; _ }, Reason.Argument :: _ ->
        given
          ("the parameter of the default implementation of " ^ op_name op)
          ("the parameter type of " ^ op_name op)
    | Reason.Default_of { op; _ }, Reason.Result :: _ ->
        given
          ("the result of the default implementation of " ^ op_name op)
          ("the result type of " ^ op_name op)
    | Reason.Top_definition x, _ ->
        Printf.sprintf "%s is defined %s" (describe x) here
    | ( ( Reason.Continuation_grade _ | Reason.Default_of _ | Reason.Pure_body
        | Reason.Continuation_effect _ | Reason.Top_computation
        | Reason.Compared_values ),
        _ ) ->
        code (skeleton_raw p joined) ^ " is equated with another type " ^ here

  (* A label at the place of each atom [related] names, stating what it does
     there, other than a place that encloses or lies within the construct
     [at] of the failing atom or a place already pointed at; of nested places
     of [related] the outermost is kept. The labels are in the order of their
     places. *)
  let related_labels p ~primary ~at ~labels related =
    let places = List.map (fun ((d : S.decision), _) -> d.reason.at) related in
    let pointed =
      primary :: at :: List.map (fun (l : Diagnostic.label) -> l.span) labels
    in
    let nested place place' = encloses place place' || encloses place' place in
    List.rev
    @@ List.fold_left
         (fun acc ((d : S.decision), joined) ->
           let place = d.reason.at in
           if
             List.exists (nested place) pointed
             || List.exists
                  (fun place' ->
                    encloses place' place && not (Location.equal place' place))
                  places
             || List.exists
                  (fun (l : Diagnostic.label) -> Location.equal l.span place)
                  acc
           then acc
           else
             label place
               (use_text p d.reason
                  (d.reason.path @ List.map Reason.of_ast_step d.path)
                  joined)
             :: acc)
         []
         (List.stable_sort
            (fun ((d : S.decision), _) ((d' : S.decision), _) ->
              Location.compare d.reason.at d'.reason.at)
            related)

  (* The application of a function to an argument as one subtyping: the
     function's type against the argument's type to the result. *)
  let application_root source resolve (reason : C.reason) ~func_at arg_ty =
    match function_atom source reason ~func_at with
    | Some (func_ty, Ast.TyArrow (_, result)) ->
        Some (resolve func_ty, Ast.TyArrow (arg_ty, result))
    | Some _ | None -> None

  let mismatch source (f : C.reason Skeleton.failure) =
    let p = printer source in
    let reason = f.info in
    let path = reason.path @ List.map Reason.of_ast_step f.path in
    let root = root source reason in
    let flipped = flipped reason path in
    let lhs, rhs = if flipped then (f.rhs, f.lhs) else (f.lhs, f.rhs) in
    let recorded = recorded source f in
    let lhs_decided, rhs_decided =
      match recorded with
      | Some m when flipped -> (m.rhs_decided, m.lhs_decided)
      | Some m -> (m.lhs_decided, m.rhs_decided)
      | None -> (None, None)
    in
    let related =
      Option.fold ~none:[] ~some:(fun (m : S.mismatch) -> m.related) recorded
    in
    let message =
      match f.mismatch with
      | Skeleton.Occurs a ->
          let other =
            match f.lhs with
            | Skeleton.Var b when Ast.TyParamModule.equal a b -> f.rhs
            | _ -> f.lhs
          in
          let a = skeleton_raw p (Skeleton.Var a) in
          let other = skeleton_raw p other in
          ( reason.at,
            "Cannot construct the infinite type " ^ code (a ^ " = " ^ other) )
      | Skeleton.Clash ->
          let o = code (skeleton_raw p lhs) in
          let e = code (skeleton_raw p rhs) in
          let non_box =
            match f.lhs with
            | Skeleton.Box _ -> e
            | _ -> code (skeleton_raw p f.lhs)
          in
          mismatch_message ~reason ~path ~o ~e ~non_box
    in
    let primary, message = message in
    let function_label =
      match (reason.why, path, root) with
      | ( Reason.Application { func_at; _ },
          Reason.Argument :: _,
          Some (_, _, _, resolve) ) -> (
          match function_ty source resolve reason ~func_at with
          | Some ty ->
              [ label func_at ("the function has type " ^ ty_code p ty) ]
          | None -> [])
      | _ -> []
    in
    let scrutinee_label =
      match (reason.why, root) with
      | Reason.Match_scrutinee { scrutinee_at }, Some (_, a, _, _)
        when not (Location.equal reason.at scrutinee_at) ->
          [ label scrutinee_at ("the matched value has type " ^ ty_code p a) ]
      | _ -> []
    in
    let labels =
      dedup
        (with_rigid_labels p
           (mentioned_rigids source [ reason ])
           (function_label @ scrutinee_label @ labels_of_reason p reason))
    in
    let labels =
      labels
      @ decided_labels ~primary ~at:reason.at ~labels
          [
            (code (skeleton_raw p lhs), lhs_decided);
            (code (skeleton_raw p rhs), rhs_decided);
          ]
    in
    let labels =
      labels @ related_labels p ~primary ~at:reason.at ~labels related
    in
    let matching (a, b) =
      [
        Printf.sprintf "while matching %s against %s" (ty_code p a)
          (ty_code p b);
      ]
    in
    let notes =
      match (reason.why, reason.path, root) with
      | ( Reason.Application { func_at; _ },
          Reason.Argument :: _,
          Some (_, a, _, resolve) ) ->
          Option.fold ~none:[] ~some:matching
            (application_root source resolve reason ~func_at a)
      | _, _, Some ((r : C.reason), a, b, _)
        when List.length r.path < List.length path ->
          matching (a, b)
      | _, _, None when not (List.is_empty f.path) ->
          Option.fold ~none:[]
            ~some:(fun (m : S.mismatch) -> matching (m.atom.lhs, m.atom.rhs))
            recorded
      | _, _, (Some _ | None) -> []
    in
    diagnostic ~primary ~labels ~notes message
end
