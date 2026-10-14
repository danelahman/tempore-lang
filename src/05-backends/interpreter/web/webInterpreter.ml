module Make (GS : Grades.GradeSystem.S) = struct
  include Interpreter.Make (GS)
  open Vdom
  module Ast = Language.Ast
  module PrettyPrint = Language.PrettyPrint
  module RS = RedexSelector.Make (GS)

  (* The state printed with the resource names in binding positions between
     resource label markers, so that only those, and not the references to
     resources in stored values, are highlighted as resources, and with the
     binding of [active], if any, between active state markers, so that it is
     highlighted as the active redex is. *)
  let string_of_state ?active state =
    let label_mark ppf =
      Format.pp_print_as ppf 0
        (String.make 1 SyntaxHighlight.resource_label_marker)
    in
    let active_mark ppf =
      Format.pp_print_as ppf 0
        (String.make 1 SyntaxHighlight.active_state_marker)
    in
    let is_active variable =
      match active with
      | Some v -> Ast.Variable.compare v variable = 0
      | None -> false
    in
    let print_var_and_expr (variable, (rho, expr)) ppf =
      let surround ppf = if is_active variable then active_mark ppf in
      Format.fprintf ppf "%t@[<hv 2>%t%t%t ↦@ %t@ # %t@]%t" surround label_mark
        (Ast.Variable.print variable)
        label_mark
        (PrettyPrint.print_expression ~abbreviated:true (module GS.R) expr)
        (PrettyPrint.print_rho (module GS.R) rho)
        surround
    in
    Format.asprintf "%t"
      (PrettyPrint.print_vars_and_exprs (module GS.R) print_var_and_expr state)

  (* The variable unboxed by the reduction [red] of the computation in the hole
     of [focus], if [red] is an [Unbox] of a variable, so that the
     corresponding state entry can be highlighted. *)
  let active_unbox_var red focus =
    match (red.redex, focus.subject.it) with
    | Unbox, Ast.Unbox ({ it = Ast.Var v; _ }, _) -> Some v
    | _ -> None

  let view_computation_redex = function
    | Match -> "match"
    | ApplyFun -> "applyFun"
    | DoReturn -> "doReturn"
    | DoOp -> "doOp"
    | Delay -> "delay"
    | Box -> "box"
    | Unbox -> "unbox"
    | HandleReturn -> "handleReturn"
    | HandleOp -> "handleOp"
    | DefaultOp -> "defaultOp"

  let view_computation_reduction red = view_computation_redex red.redex

  let view_step_label = function
    | ComputationReduction reduction ->
        text (view_computation_reduction reduction)
    | Return -> text "return"
    | Unhandled -> text "unhandled operation"

  let is_end_of_run_label = function
    | Return | Unhandled -> true
    | ComputationReduction _ -> false

  let is_done = function
    | { current = None; _ } -> true
    | { current = Some _; _ } -> false

  let view_run_state (run_state : run_state) step_label =
    match run_state with
    | { environment; current = Some focus; _ } ->
        let reduction =
          match step_label with
          | Some (ComputationReduction red) -> Some red
          | Some (Return | Unhandled) | None -> None
        in

        let active =
          match reduction with
          | Some red -> active_unbox_var red focus
          | None -> None
        in
        let state_nodes =
          RedexSelector.highlight_delimited SyntaxHighlight.active_state_marker
            (string_of_state ?active environment.state)
        in
        let computation_tree =
          RS.view_computation_with_redexes reduction
            (returned_value environment (computation focus))
        in
        div
          ~a:[ class_ "box" ]
          [
            elt "pre" ~a:[ class_ "syn-ml" ] state_nodes;
            elt "hr" [];
            elt "pre" ~a:[ class_ "syn-ml" ] computation_tree;
          ]
    | { current = None; _ } ->
        div ~a:[ class_ "box" ] [ elt "pre" [ text "done" ] ]
end
