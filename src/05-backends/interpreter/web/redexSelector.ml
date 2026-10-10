module Print = Utils.Print
module Ast = Language.Ast
module PrettyPrint = Language.PrettyPrint

module Make (GS : Grades.GradeSystem.S) = struct
  open Interpreter.Types

  (* A NUL byte is used as the redex marker because it cannot appear in any
     output produced by [Format] and so makes a single-character separator
     suitable for [String.split_on_char]. *)
  let tag_marker = '\x00'
  let print_mark ppf = Format.pp_print_as ppf 0 (String.make 1 tag_marker)

  let print_computation_redex ?max_level red c ppf =
    let print ?at_level = Print.print ?max_level ?at_level ppf in
    match (red, c.Ast.it) with
    | DoReturn, Ast.Do (c1, (pat, c2)) ->
        print ~at_level:2 "@[<v 0>%t@[<hov 2>let %t =@ %t@]%t in@,%t@]"
          print_mark
          (PrettyPrint.print_pattern pat)
          (PrettyPrint.print_computation (module GS.R) ~max_level:1 c1)
          print_mark
          (PrettyPrint.print_computation (module GS.R) c2)
    | Box, Ast.Box (rho, e, (p, c)) ->
        print ~at_level:2 "@[<v 0>%t@[<hov 2>box %t %t as %t@]%t in@,%t@]"
          print_mark
          (PrettyPrint.print_rho (module GS.R) rho)
          (PrettyPrint.print_expression (module GS.R) ~max_level:0 e)
          (PrettyPrint.print_pattern ~max_level:0 p)
          print_mark
          (PrettyPrint.print_computation (module GS.R) c)
    | Unbox, Ast.Unbox (e, (p, c)) ->
        print ~at_level:2 "@[<v 0>%t@[<hov 2>unbox %t as %t@]%t in@,%t@]"
          print_mark
          (PrettyPrint.print_expression (module GS.R) ~max_level:0 e)
          (PrettyPrint.print_pattern p)
          print_mark
          (PrettyPrint.print_computation (module GS.R) c)
    | _, _ ->
        print "%t%t%t" print_mark
          (fun ppf ->
            PrettyPrint.print_computation (module GS.R) ?max_level c ppf)
          print_mark

  let rec print_computation_reduction ?max_level red c ppf =
    let print ?at_level = Print.print ?max_level ?at_level ppf in
    match (red, c.Ast.it) with
    | DoCtx red, Ast.Do (c1, ({ it = Ast.PNonbinding; _ }, c2)) ->
        print ~at_level:2 "@[<v 0>%t;@,%t@]"
          (print_computation_reduction ~max_level:1 red c1)
          (PrettyPrint.print_computation (module GS.R) c2)
    | DoCtx red, Ast.Do (c1, (pat, c2)) ->
        print ~at_level:2 "@[<v 0>@[<hov 2>let %t =@ %t@] in@,%t@]"
          (PrettyPrint.print_pattern pat)
          (print_computation_reduction ~max_level:1 red c1)
          (PrettyPrint.print_computation (module GS.R) c2)
    | HandleCtx red, Ast.Handle (c', h) ->
        print ~at_level:1 "@[<v 0>handle@;<1 2>%t@,with %t@]"
          (print_computation_reduction red c')
          (PrettyPrint.print_expression (module GS.R) ~max_level:0 h)
    | ComputationRedex redex, _ ->
        print_computation_redex ?max_level redex c ppf
    (* A context that does not fit the computation marks no redex. *)
    | (DoCtx _ | HandleCtx _), _ ->
        PrettyPrint.print_computation (module GS.R) ?max_level c ppf

  let view_computation_with_redexes red comp =
    let rendered =
      match red with
      | None ->
          Format.asprintf "%t"
            (PrettyPrint.print_computation (module GS.R) comp)
      | Some red -> Format.asprintf "%t" (print_computation_reduction red comp)
    in
    match String.split_on_char tag_marker rendered with
    | [ code ] -> SyntaxHighlight.highlight_text code
    | [ pre; redex; post ] ->
        SyntaxHighlight.highlight_text pre
        @ [
            Vdom.elt "span"
              ~a:[ Vdom.class_ "active-redex" ]
              (SyntaxHighlight.highlight_text redex);
          ]
        @ SyntaxHighlight.highlight_text post
    (* Markers that do not delimit one redex mark none. *)
    | parts -> SyntaxHighlight.highlight_text (String.concat "" parts)
end
