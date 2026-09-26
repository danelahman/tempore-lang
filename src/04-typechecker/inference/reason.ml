(* Sources of constraint atoms. *)

module Location = Utils.Location
module Ast = Language.Ast

type clause = {
  op : Ast.operation;
  signature_at : Location.t;
  case_at : Location.t;
}

type elapsed_kind =
  | Delayed of int
  | Performed of Ast.operation
  | Sequenced
  | Boxed
  | Handled
  | Clause_lock of clause

type 'rho elapsed = { grade : 'rho; at : Location.t; kind : elapsed_kind }

type step =
  | Argument
  | Result
  | Effect
  | Component of int
  | Type_argument of int
  | Box_content
  | Box_grade
  | Handler_input
  | Handler_output

type rigid_origin = {
  clause : clause;
  continuation : Ast.variable option;
  continuation_at : Location.t;
}

type ('rho, 'eps) why =
  | Application of { func_at : Location.t; arg_at : Location.t }
  | Match_scrutinee of { scrutinee_at : Location.t }
  | Match_branch
  | Annotation
  | Pattern_annotation
  | Variant_argument of Ast.label
  | Boxed_value
  | Unboxed of {
      var : Ast.variable;
      bound_at : Location.t option;
      elapsed : 'rho elapsed list;
    }
  | Use_after_time of {
      var : Ast.variable;
      bound_at : Location.t;
      elapsed : 'rho elapsed list;
    }
  | Op_case_capture of {
      var : Ast.variable;
      bound_at : Location.t;
      clause : clause;
      elapsed : 'rho elapsed list;
    }
  | Instance_of of {
      var : Ast.variable;
      defined_at : Location.t option;
      inner : ('rho, 'eps) t;
    }
  | Handler_case of { op : Ast.operation; signature_at : Location.t }
  | Continuation_grade of { op : Ast.operation; signature_at : Location.t }
  | Perform_argument of { op : Ast.operation; signature_at : Location.t }
  | Perform_continuation of { op : Ast.operation; signature_at : Location.t }
  | Handle_with
  | Handled_computation
  | Return_clause
  | Recursive_definition of Ast.variable
  | Function_body
  | Function_parameter
  | Pure_body
  | Sequencing
  | Continuation_effect of elapsed_kind
  | Default_of of { op : Ast.operation; signature_at : Location.t }
  | Top_definition of Ast.variable
  | Top_computation

and ('rho, 'eps) stated =
  | Stated_rho of 'rho * 'rho
  | Stated_eps of 'eps * 'eps

and ('rho, 'eps) t = {
  at : Location.t;
  why : ('rho, 'eps) why;
  path : step list;
  subject : Location.t option;
  stated : ('rho, 'eps) stated option;
}

let because at why = { at; why; path = []; subject = None; stated = None }
let step s reason = { reason with path = reason.path @ [ s ] }
let against subject reason = { reason with subject = Some subject }

let with_stated s reason =
  match reason.stated with
  | Some _ -> reason
  | None -> { reason with stated = Some s }

let clause_of_elapsed elapsed =
  List.find_map
    (fun e -> match e.kind with Clause_lock c -> Some c | _ -> None)
    elapsed

let map_elapsed on_rho = List.map (fun e -> { e with grade = on_rho e.grade })

let rec map_grades on_rho on_eps reason =
  let why =
    match reason.why with
    | Unboxed u -> Unboxed { u with elapsed = map_elapsed on_rho u.elapsed }
    | Use_after_time u ->
        Use_after_time { u with elapsed = map_elapsed on_rho u.elapsed }
    | Op_case_capture u ->
        Op_case_capture { u with elapsed = map_elapsed on_rho u.elapsed }
    | Instance_of i ->
        Instance_of { i with inner = map_grades on_rho on_eps i.inner }
    | Application a -> Application a
    | Match_scrutinee m -> Match_scrutinee m
    | Handler_case h -> Handler_case h
    | Continuation_grade c -> Continuation_grade c
    | Perform_argument p -> Perform_argument p
    | Perform_continuation p -> Perform_continuation p
    | Default_of d -> Default_of d
    | Variant_argument lbl -> Variant_argument lbl
    | Recursive_definition f -> Recursive_definition f
    | Continuation_effect kind -> Continuation_effect kind
    | Top_definition x -> Top_definition x
    | ( Match_branch | Annotation | Pattern_annotation | Boxed_value
      | Handle_with | Handled_computation | Return_clause | Function_body
      | Function_parameter | Pure_body | Sequencing | Top_computation ) as why
      ->
        why
  in
  let stated =
    Option.map
      (function
        | Stated_rho (rho, rho') -> Stated_rho (on_rho rho, on_rho rho')
        | Stated_eps (eps, eps') -> Stated_eps (on_eps eps, on_eps eps'))
      reason.stated
  in
  { reason with why; stated }

let fold_elapsed on_rho elapsed acc =
  List.fold_left (fun acc e -> on_rho e.grade acc) acc elapsed

let rec fold_grades on_rho on_eps reason acc =
  let acc =
    match reason.why with
    | Unboxed { elapsed; _ }
    | Use_after_time { elapsed; _ }
    | Op_case_capture { elapsed; _ } ->
        fold_elapsed on_rho elapsed acc
    | Instance_of { inner; _ } -> fold_grades on_rho on_eps inner acc
    | _ -> acc
  in
  match reason.stated with
  | None -> acc
  | Some (Stated_rho (rho, rho')) -> on_rho rho' (on_rho rho acc)
  | Some (Stated_eps (eps, eps')) -> on_eps eps' (on_eps eps acc)

let print_step s ppf =
  match s with
  | Argument -> Format.pp_print_string ppf "argument"
  | Result -> Format.pp_print_string ppf "result"
  | Effect -> Format.pp_print_string ppf "effect"
  | Component i -> Format.fprintf ppf "component %d" i
  | Type_argument i -> Format.fprintf ppf "type argument %d" i
  | Box_content -> Format.pp_print_string ppf "box content"
  | Box_grade -> Format.pp_print_string ppf "box grade"
  | Handler_input -> Format.pp_print_string ppf "handler input"
  | Handler_output -> Format.pp_print_string ppf "handler output"

let print_elapsed_kind kind ppf =
  match kind with
  | Delayed n -> Format.fprintf ppf "delay %d" n
  | Performed op -> Format.fprintf ppf "perform %t" (Ast.OpName.print op)
  | Sequenced -> Format.pp_print_string ppf "sequencing"
  | Boxed -> Format.pp_print_string ppf "box"
  | Handled -> Format.pp_print_string ppf "handled computation"
  | Clause_lock { op; _ } ->
      Format.fprintf ppf "clause for %t" (Ast.OpName.print op)

let print_why why ppf =
  let text = Format.pp_print_string ppf in
  let op_rule name op = Format.fprintf ppf "%s %t" name (Ast.OpName.print op) in
  let var_rule name x =
    Format.fprintf ppf "%s %t" name (Ast.Variable.print x)
  in
  match why with
  | Application _ -> text "application"
  | Match_scrutinee _ -> text "match scrutinee"
  | Match_branch -> text "match branch"
  | Annotation -> text "annotation"
  | Pattern_annotation -> text "pattern annotation"
  | Variant_argument lbl ->
      Format.fprintf ppf "argument of %t" (Ast.Label.print lbl)
  | Boxed_value -> text "boxed value"
  | Unboxed { var; _ } -> var_rule "unbox" var
  | Use_after_time { var; _ } -> var_rule "use of" var
  | Op_case_capture { var; clause; _ } ->
      Format.fprintf ppf "use of %t in the clause for %t"
        (Ast.Variable.print var)
        (Ast.OpName.print clause.op)
  | Instance_of { var; _ } -> var_rule "instance of" var
  | Handler_case { op; _ } -> op_rule "clause for" op
  | Continuation_grade { op; _ } -> op_rule "continuation grade of" op
  | Perform_argument { op; _ } -> op_rule "argument of" op
  | Perform_continuation { op; _ } -> op_rule "result of" op
  | Handle_with -> text "handle with"
  | Handled_computation -> text "handled computation"
  | Return_clause -> text "return clause"
  | Recursive_definition f -> var_rule "recursive definition of" f
  | Function_body -> text "function body"
  | Function_parameter -> text "function parameter"
  | Pure_body -> text "pure body"
  | Sequencing -> text "sequencing"
  | Continuation_effect kind ->
      Format.fprintf ppf "continuation of %t" (print_elapsed_kind kind)
  | Default_of { op; _ } -> op_rule "default of" op
  | Top_definition x -> var_rule "definition of" x
  | Top_computation -> text "top-level computation"

let print reason ppf =
  Format.fprintf ppf "%t at %t" (print_why reason.why)
    (Location.print_short reason.at);
  match reason.path with
  | [] -> ()
  | path ->
      Format.fprintf ppf ", %a"
        (Format.pp_print_list
           ~pp_sep:(fun ppf () -> Format.pp_print_string ppf " / ")
           (fun ppf s -> print_step s ppf))
        path
