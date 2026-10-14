(* The places the diagnostics of rejected commands point at. *)

module Ast = Language.Ast
module Diagnostic = Utils.Diagnostic
module Location = Utils.Location
module Reason = Inference.Reason

module Make
    (C : Inference.Constraint.S)
    (T : module type of struct
      include ExplainText.Make (C)
    end) =
struct
  module X = C.X
  open T

  (* ------------------------------------------------------------------ *)
  (* Accumulated grades                                                  *)
  (* ------------------------------------------------------------------ *)

  (* The grade of a lock as a label shows it: the image of an effect grade as
     the effect grade. *)
  let lock_grade_raw p rho =
    match canon_rho p rho with
    | X.Rho_map eps -> eps_raw p eps
    | rho -> rho_raw p rho

  (* The grade a label names for a lock: its own at the values of the
     instance explained against where that is closed, else the grade its
     construct declares, where there is one. *)
  let lock_grade p (e : C.rho Reason.lock) =
    let grade = X.Rho.subst p.values e.grade in
    match (X.Rho.value (canon_rho p grade), e.declared) with
    | None, Some declared -> declared
    | Some _, _ | None, None -> grade

  (* One lock that contributed to an accumulated grade, naming its grade and
     its construct. *)
  let lock_text p (e : C.rho Reason.lock) =
    let grade = code (lock_grade_raw p (lock_grade p e)) in
    let accumulates what =
      Printf.sprintf "grade %s accumulates %s (%s)" grade here what
    in
    match e.kind with
    | Reason.Delayed _ -> accumulates "delay"
    | Reason.Performed op -> accumulates ("operation " ^ op_name op)
    | Reason.Sequenced -> accumulates "this computation"
    | Reason.Boxed -> accumulates "the boxed value"
    | Reason.Handled -> accumulates "the handled computation"
    | Reason.Clause_lock clause ->
        Printf.sprintf
          "the case for %s is checked with the top grade %s accumulated"
          (op_name clause.op) grade
    | Reason.Recursive_lock f ->
        Printf.sprintf
          "%s is defined %s, its body checked with the top grade %s accumulated"
          (describe f) here grade

  (* A grade of the unit is no part of the explanation. *)
  let lock_labels p locks =
    List.filter_map
      (fun (e : C.rho Reason.lock) ->
        if is_unit_rho p (lock_grade p e) then None
        else Some (label e.at (lock_text p e)))
      locks

  let accumulated_grade (locks : C.rho Reason.lock list) =
    match locks with
    | [] -> X.Rho.unit
    | e :: rest ->
        List.fold_left
          (fun rho (e : C.rho Reason.lock) -> X.Rho.mul rho e.grade)
          e.grade rest

  (* Labels a reader meets in the order the program reads. *)
  let in_span_order labels =
    List.stable_sort
      (fun (l : Diagnostic.label) (l' : Diagnostic.label) ->
        Location.compare l.span l'.span)
      labels

  let binding_labels x bound_at =
    match bound_at with
    | None -> []
    | Some at ->
        [
          label at
            (match var_name x with
            | Some name -> name ^ " is bound " ^ here
            | None -> "this value is bound " ^ here);
        ]

  let declared_label op signature_at =
    label signature_at ("operation " ^ op_name op ^ " is declared " ^ here)

  (* The places of a capture by the body of the recursive function [f]: where
     grades accumulated, and where [f] is defined, which the label of the lock
     of its body names unless that lock's grade is the unit. *)
  let rec_capture_labels p f defined_at locks =
    let names_f (e : C.rho Reason.lock) =
      match e.kind with
      | Reason.Recursive_lock g ->
          Ast.Variable.equal f g && not (is_unit_rho p (lock_grade p e))
      | _ -> false
    in
    let spent = lock_labels p locks in
    if List.exists names_f locks then spent
    else label defined_at (describe f ^ " is defined " ^ here) :: spent

  let rec use_of (reason : C.reason) =
    match reason.why with
    | Reason.Instance_of { inner; _ } -> use_of inner
    | Reason.Use_under_locks _ | Reason.Op_case_capture _ | Reason.Rec_capture _
      ->
        Some reason
    | _ -> None

  (** The story of a use under locks, in source order: where the variable was
      bound, where grades accumulated since, and the use itself. *)
  let use_labels p (use : C.reason) =
    match use.why with
    | Reason.Use_under_locks { var; bound_at; locks } ->
        let total = accumulated_grade locks in
        let text =
          if is_unit_rho p total then
            Printf.sprintf "%s is used %s" (describe var) here
          else
            Printf.sprintf
              "%s is used %s with grade %s accumulated since it was bound, \
               which only an eternal type allows"
              (describe var) here (rho_code p total)
        in
        in_span_order
          (binding_labels var (Some bound_at)
          @ lock_labels p locks
          @ [ label use.at text ])
    | Reason.Op_case_capture { var; bound_at; clause; locks } ->
        let text =
          Printf.sprintf "%s is used %s, in the case for %s" (describe var) here
            (op_name clause.op)
        in
        in_span_order
          (declared_label clause.op clause.signature_at
           :: binding_labels var (Some bound_at)
          @ lock_labels p locks
          @ [ label use.at text ])
    | Reason.Rec_capture { var; bound_at; f; defined_at; locks } ->
        let text =
          Printf.sprintf "%s is used %s, in the body of %s" (describe var) here
            (describe f)
        in
        in_span_order
          (binding_labels var (Some bound_at)
          @ rec_capture_labels p f defined_at locks
          @ [ label use.at text ])
    | _ -> []

  let rec labels_of_reason p (reason : C.reason) =
    match reason.why with
    | Reason.Use_under_locks { var; bound_at; locks } ->
        in_span_order (binding_labels var (Some bound_at) @ lock_labels p locks)
    | Reason.Unboxed { var; bound_at; locks } ->
        in_span_order (binding_labels var bound_at @ lock_labels p locks)
    | Reason.Op_case_capture { var; bound_at; clause; locks } ->
        in_span_order
          (declared_label clause.op clause.signature_at
           :: binding_labels var (Some bound_at)
          @ lock_labels p locks)
    | Reason.Rec_capture { var; bound_at; f; defined_at; locks } ->
        in_span_order
          (binding_labels var (Some bound_at)
          @ rec_capture_labels p f defined_at locks)
    | Reason.Instance_of { var; defined_at; inner } ->
        let definition =
          match defined_at with
          | None -> []
          | Some at -> [ label at (describe var ^ " is defined " ^ here) ]
        in
        let rest =
          match inner.why with
          | Reason.Use_under_locks _ | Reason.Op_case_capture _
          | Reason.Rec_capture _ ->
              use_labels p inner
          | _ -> labels_of_reason p inner
        in
        definition @ rest
    | Reason.Handler_case { op; signature_at }
    | Reason.Continuation_grade { op; signature_at }
    | Reason.Perform_argument { op; signature_at }
    | Reason.Perform_continuation { op; signature_at }
    | Reason.Default_of { op; signature_at } ->
        [ declared_label op signature_at ]
    | Reason.Application _ | Reason.Match_scrutinee _ | Reason.Match_branch
    | Reason.Annotation | Reason.Pattern_annotation | Reason.Variant_argument _
    | Reason.Successor_pattern | Reason.Boxed_value | Reason.Handle_with
    | Reason.Handled_computation | Reason.Return_clause
    | Reason.Recursive_definition _ | Reason.Function_body
    | Reason.Function_parameter | Reason.Pure_body | Reason.Sequencing _
    | Reason.Continuation_effect _ | Reason.Top_definition _
    | Reason.Top_computation | Reason.Compared_values ->
        []

  (* The construct a reason names, as "the inequality goes through" continues. *)
  let construct (reason : C.reason) =
    match reason.why with
    | Reason.Application _ -> "the application"
    | Reason.Match_scrutinee _ -> "the matched value"
    | Reason.Match_branch -> "the branch"
    | Reason.Annotation | Reason.Pattern_annotation -> "the annotation"
    | Reason.Variant_argument lbl -> "the argument of " ^ label_name lbl
    | Reason.Successor_pattern -> "the successor pattern"
    | Reason.Boxed_value -> "the box"
    | Reason.Unboxed { var; _ } -> "the unboxing of " ^ describe var
    | Reason.Use_under_locks { var; _ }
    | Reason.Op_case_capture { var; _ }
    | Reason.Rec_capture { var; _ } ->
        "the use of " ^ describe var
    | Reason.Instance_of { var; _ } -> "the type of " ^ describe var
    | Reason.Handler_case { op; _ } | Reason.Continuation_grade { op; _ } ->
        "the case for " ^ op_name op
    | Reason.Perform_argument { op; _ } | Reason.Perform_continuation { op; _ }
      ->
        "the call of " ^ op_name op
    | Reason.Handle_with -> "the handler"
    | Reason.Handled_computation -> "the handled computation"
    | Reason.Return_clause -> "the return clause"
    | Reason.Recursive_definition f -> "the definition of " ^ describe f
    | Reason.Function_body | Reason.Pure_body -> "the function body"
    | Reason.Function_parameter -> "the parameter"
    | Reason.Sequencing _ | Reason.Continuation_effect _ -> "the computation"
    | Reason.Default_of { op; _ } ->
        "the default implementation of " ^ op_name op
    | Reason.Top_definition x -> "the definition of " ^ describe x
    | Reason.Top_computation -> "the computation"
    | Reason.Compared_values -> "the comparison"

  (* Whether a link of a chain of orderings is a source of grades: a type
     stated or inferred elsewhere, rather than a construct passing a grade
     on. *)
  let is_source (r : C.reason) =
    match r.why with
    | Reason.Instance_of _ | Reason.Annotation | Reason.Pattern_annotation
    | Reason.Boxed_value | Reason.Default_of _ | Reason.Handler_case _
    | Reason.Continuation_grade _ | Reason.Perform_argument _
    | Reason.Perform_continuation _ | Reason.Unboxed _
    | Reason.Use_under_locks _ | Reason.Op_case_capture _ | Reason.Rec_capture _
    | Reason.Variant_argument _ ->
        true
    | Reason.Application _ | Reason.Match_scrutinee _ | Reason.Match_branch
    | Reason.Successor_pattern | Reason.Handle_with | Reason.Handled_computation
    | Reason.Return_clause | Reason.Recursive_definition _
    | Reason.Function_body | Reason.Function_parameter | Reason.Pure_body
    | Reason.Sequencing _ | Reason.Continuation_effect _
    | Reason.Top_definition _ | Reason.Top_computation | Reason.Compared_values
      ->
        false

  let chain_labels ~primary ~labels reasons =
    let pointed_at at =
      Location.equal at primary
      || List.exists
           (fun (l : Diagnostic.label) -> Location.equal l.span at)
           labels
    in
    List.rev
    @@ List.fold_left
         (fun acc (r : C.reason) ->
           if
             (not (is_source r))
             || pointed_at r.at
             || List.exists
                  (fun (l : Diagnostic.label) -> Location.equal l.span r.at)
                  acc
           then acc
           else
             label r.at
               (Printf.sprintf "the inequality goes through %s %s" (construct r)
                  here)
             :: acc)
         [] reasons

  let dedup labels =
    List.rev
    @@ List.fold_left
         (fun acc (l : Diagnostic.label) ->
           if
             List.exists
               (fun (l' : Diagnostic.label) ->
                 Location.equal l.span l'.span && String.equal l.text l'.text)
               acc
           then acc
           else l :: acc)
         [] labels
end
