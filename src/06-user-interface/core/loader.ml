module Location = Utils.Location
module Error = Utils.Error
module Diagnostic = Utils.Diagnostic
module List = Utils.List
module Ast = Language.Ast
open Backend

module Loader (Backend : Backend.S) = struct
  module D = Desugarer.Make (Backend.Grades)
  module TC = Typechecker.Make (Backend.Grades)
  module Grammar = Parser.Grammar.Make (Backend.Grades)

  type state = {
    desugarer : D.state;
    backend : Backend.load_state;
    typechecker : TC.state;
  }

  let load_primitive state prim =
    let x = Ast.Variable.fresh (Language.Primitives.primitive_name prim) in
    {
      desugarer = D.load_primitive state.desugarer x prim;
      typechecker = TC.load_primitive state.typechecker x prim;
      backend = Backend.load_primitive state.backend x prim;
    }

  let initial_state =
    List.fold_left load_primitive
      {
        desugarer = D.initial_state;
        typechecker = TC.initial_state;
        backend = Backend.initial_load_state;
      }
      Language.Primitives.primitives

  let parse_commands lexbuf =
    try Grammar.commands (Parser.Lexer.tokens ()) lexbuf with
    | Grammar.Error ->
        Error.syntax ~loc:(Location.of_lexbuf lexbuf) "parser error"
    | Failure failmsg when failmsg = "lexing: empty token" ->
        Error.syntax ~loc:(Location.of_lexbuf lexbuf) "unrecognised symbol"

  (* The backend loads a command the typechecker has accepted. *)
  let load_backend backend (cmd : _ Ast.command) =
    match cmd.it with
    | Ast.TyDef (eternality, ty_defs) ->
        Backend.load_ty_def backend (eternality, ty_defs)
    | Ast.OpSig (op, _, _, eps, _) -> Backend.load_op_sig backend op eps
    | Ast.OpDefault (op, abs) -> Backend.load_op_default backend op abs
    | Ast.TopLet (x, expr) -> Backend.load_top_let backend x expr
    | Ast.TopDo comp -> Backend.load_top_do backend comp

  (* A command checked and loaded, or the diagnostic of its rejection and how
     to go on. An error raised without a location of its own is pinned to the
     command. *)
  let execute_command state (cmd : _ Ast.command) =
    try
      match TC.check state.typechecker cmd with
      | Ok typechecker ->
          Ok
            { state with typechecker; backend = load_backend state.backend cmd }
      | Error (d, TC.Continue typechecker) ->
          (* The backend is left alone: nothing is run once there are
             errors. *)
          Error (d, Some { state with typechecker })
      | Error (d, TC.Stop) -> Error (d, None)
    with Error.Error ({ primary = None; _ } as d) ->
      raise (Error.Error { d with primary = Some cmd.at })

  (** Execute [cmds] in order, returning the state they leave behind and the
      diagnostics they produced. With [~recover:true] the typing errors the
      loader can carry on from are collected, so that a program's independent
      errors are reported at once; otherwise the first escapes as an exception.
      Errors of any other kind are fatal either way. *)
  let execute_commands ~recover state cmds =
    let step (state, diagnostics, stopped) cmd =
      if stopped then (state, diagnostics, stopped)
      else
        match execute_command state cmd with
        | Ok state' -> (state', diagnostics, false)
        | Error (d, _) when not recover -> raise (Error.Error d)
        | Error (d, Some state') -> (state', d :: diagnostics, false)
        | Error (d, None) -> (state, d :: diagnostics, true)
    in
    let state', diagnostics, _ = List.fold_left step (state, [], false) cmds in
    (state', List.rev diagnostics)

  let desugar_commands state cmds =
    let desugarer_state', cmds' =
      List.fold_map D.desugar_command state.desugarer cmds
    in
    ({ state with desugarer = desugarer_state' }, cmds')

  let load_commands_all state cmds =
    let state', cmds' = desugar_commands state cmds in
    execute_commands ~recover:true state' cmds'

  (* Without recovery the first error escapes as an exception and the
     diagnostic list is empty; re-raising covers the case all the same. *)
  let load_commands state cmds =
    let state', cmds' = desugar_commands state cmds in
    match execute_commands ~recover:false state' cmds' with
    | state'', [] -> state''
    | _, d :: _ -> raise (Error.Error d)

  let parse_source ?(filename = "") source =
    let lexbuf = Lexing.from_string source in
    lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = filename };
    parse_commands lexbuf

  let load_source ?filename state source =
    load_commands state (parse_source ?filename source)

  let load_file state source =
    load_commands state (Parser.Lexer.read_file parse_commands source)

  (** Load a source, reporting every typing error it contains rather than only
      the first. Parsing and desugaring stay fatal: a parse error leaves nothing
      to continue with, and an unknown name would only cascade. The standard
      library goes through {!load_source}, an error in it being a bug. *)
  let load_source_all ?filename state source =
    load_commands_all state (parse_source ?filename source)

  (** {!load_source_all} for a file. *)
  let load_file_all state source =
    load_commands_all state (Parser.Lexer.read_file parse_commands source)

  (** The module Stdlib_tpe is automatically generated from stdlib.tpe. Check
      the dune file for details. *)
  let stdlib_source = Stdlib_tpe.contents
end

(** The standard library's source, independently of any backend, for callers
    that need to know what precedes a program's own source. *)
let stdlib_source = Stdlib_tpe.contents

(** The file name the standard library's locations are reported under, since it
    is loaded from a string rather than from a file. *)
let stdlib_filename = "stdlib.tpe"
