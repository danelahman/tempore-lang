(** Loading programs: parsing, desugaring, typechecking and running their
    commands.

    A program is loaded in two passes. First all its sources, the standard
    library included, are parsed, and the operation declarations are collected
    from them, the name and running-time bounds of each operation only
    ([Loader.declare]); the grades of every command are read over these
    operations, whether declared before or after the command. Then the sources
    are desugared, typechecked and run command by command, in order, so that an
    operation is still performed only after its declaration. *)

module Location = Utils.Location
module Error = Utils.Error
module Diagnostic = Utils.Diagnostic
module Ast = Language.Ast
open Backend

(** [declared_operations commands] is the operation declarations of [commands],
    in order, each the name of the operation with its running-time bounds if it
    declares them. Only these are read, so that an operation declared with a
    malformed or ill-typed signature is listed all the same. *)
let declared_operations commands =
  List.filter_map
    (fun (cmd : _ SugaredAst.command) ->
      match cmd.it with
      | SugaredAst.OpSig (name, _, _, _, bounds) -> Some (name.it, bounds)
      | SugaredAst.TyDef _ | SugaredAst.OpDefault _ | SugaredAst.TopLet _
      | SugaredAst.TopLetRec _ | SugaredAst.TopDo _ ->
          None)
    commands

(** The file name the standard library's locations are reported under, since it
    is loaded from a string rather than from a file. *)
let stdlib_filename = "stdlib.tpe"

module Loader (Backend : Backend.S) = struct
  module D = Desugarer.Make (Backend.Grades)
  module TC = Typechecker.Make (Backend.Grades)
  module Grammar = Parser.Grammar.Make (Backend.Grades)

  type state = {
    desugarer : D.state;
    references : Desugarer.References.env;
    backend : Backend.load_state;
    typechecker : TC.state;
  }

  (** [declare sources state] is [state] in the program made of the parsed
      [sources], all of which are to be loaded into it: the grades of every
      command are read over the operations these sources declare
      ({!Typechecker.Make.declare_operations}), before or after the command. *)
  let declare sources state =
    {
      state with
      typechecker =
        TC.declare_operations
          (declared_operations (List.concat sources))
          state.typechecker;
    }

  let load_primitive state prim =
    let x = Ast.Variable.fresh (Language.Primitives.primitive_name prim) in
    {
      state with
      desugarer = D.load_primitive state.desugarer x prim;
      typechecker = TC.load_primitive state.typechecker x prim;
      backend = Backend.load_primitive state.backend x prim;
    }

  let initial_state =
    List.fold_left load_primitive
      {
        desugarer = D.initial_state;
        references = Desugarer.References.empty;
        typechecker = TC.initial_state;
        backend = Backend.initial_load_state;
      }
      Language.Primitives.primitives

  let parse_commands lexbuf =
    try Grammar.commands (Parser.Lexer.tokens ()) lexbuf
    with Grammar.Error ->
      Error.syntax ~loc:(Location.of_lexbuf lexbuf) "parser error"

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

  type definition = {
    variable : Ast.variable;
    at : Location.t;  (** the location of the defining command *)
    scheme : TC.scheme;
  }
  (** A top-level definition the typechecker has accepted. *)

  (** Execute [cmds] in order, returning the state they leave behind, the
      diagnostics they produced and the top-level definitions accepted before
      the first of them, in order. With [~recover:true] the typing errors the
      loader can carry on from are collected, so that a program's independent
      errors are reported at once; otherwise the first escapes as an exception.
      Errors of any other kind are fatal either way. *)
  let execute_commands ~recover state cmds =
    let step (state, diagnostics, defined, stopped) (cmd : _ Ast.command) =
      if stopped then (state, diagnostics, defined, stopped)
      else
        match execute_command state cmd with
        | Ok state' ->
            let defined =
              match (cmd.it, diagnostics) with
              | Ast.TopLet (x, _), [] -> (x, cmd.at) :: defined
              | _ -> defined
            in
            (state', diagnostics, defined, false)
        | Error (d, _) when not recover -> raise (Error.Error d)
        | Error (d, Some state') -> (state', d :: diagnostics, defined, false)
        | Error (d, None) -> (state, d :: diagnostics, defined, true)
    in
    let state', diagnostics, defined, _ =
      List.fold_left step (state, [], [], false) cmds
    in
    let schemes = TC.definitions state'.typechecker in
    let definition (variable, at) =
      List.find_map
        (fun (x, scheme) ->
          if Ast.Variable.compare x variable = 0 then
            Some { variable; at; scheme }
          else None)
        schemes
    in
    (state', List.rev diagnostics, List.filter_map definition (List.rev defined))

  (* The desugared commands, and the links of the names they use to their
     definitions. *)
  let desugar_commands state cmds =
    let desugarer_state', cmds' =
      List.fold_left_map D.desugar_command state.desugarer cmds
    in
    let references', links =
      List.fold_left_map Desugarer.References.command state.references cmds
    in
    ( { state with desugarer = desugarer_state'; references = references' },
      cmds',
      List.concat links )

  (** Load the parsed source [cmds] of a program {!declare}d, reporting every
      typing error it contains rather than only the first, together with the
      top-level definitions accepted before the first error and the links of the
      names of [cmds] to their definitions ({!Desugarer.References.command}).
      Desugaring stays fatal: an unknown name would only cascade. *)
  let load_commands_defining state cmds =
    let state', cmds', links = desugar_commands state cmds in
    let state'', diagnostics, defined =
      execute_commands ~recover:true state' cmds'
    in
    (state'', diagnostics, defined, links)

  (** As {!load_commands_defining}, without the definitions and links. *)
  let load_commands_all state cmds =
    let state', diagnostics, _, _ = load_commands_defining state cmds in
    (state', diagnostics)

  (* Without recovery the first error escapes as an exception and the
     diagnostic list is empty; re-raising covers the case all the same. *)
  let load_commands state cmds =
    let state', cmds', _ = desugar_commands state cmds in
    match execute_commands ~recover:false state' cmds' with
    | state'', [], _ -> state''
    | _, d :: _, _ -> raise (Error.Error d)

  let parse_source ?(filename = "") source =
    let lexbuf = Lexing.from_string source in
    lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = filename };
    parse_commands lexbuf

  let parse_file filename = Parser.Lexer.read_file parse_commands filename

  (** The module Stdlib_tpe is automatically generated from stdlib.tpe. Check
      the dune file for details. *)
  let stdlib_source = Stdlib_tpe.contents

  type 'link program = {
    library : state;  (** the state after the standard library *)
    library_definitions : definition list;
        (** the top-level definitions of the standard library *)
    loaded : state;  (** the state after every source *)
    diagnostics : Diagnostic.t list;  (** those of the sources, in order *)
    definitions : definition list;
        (** the top-level definitions of the sources accepted before the first
            error of each *)
    links : 'link list;
        (** the links of the names of the sources to their definitions *)
  }
  (** A program loaded by {!load_program}. *)

  (** [load_program ~use_stdlib sources] loads the parsed [sources] in order,
      preceded by the standard library if [use_stdlib], all of them {!declare}d
      first. Every source is loaded even when an earlier one has errors, so that
      all of them are reported at once. An error in the standard library is
      fatal. *)
  let load_program ~use_stdlib sources =
    let stdlib =
      if use_stdlib then parse_source ~filename:stdlib_filename stdlib_source
      else []
    in
    let library, library_definitions =
      match
        load_commands_defining
          (declare (stdlib :: sources) initial_state)
          stdlib
      with
      | state, [], definitions, _ -> (state, definitions)
      | _, d :: _, _, _ -> raise (Error.Error d)
    in
    let loaded, diagnostics, definitions, links =
      List.fold_left
        (fun (state, diagnostics, definitions, links) source ->
          let state', diagnostics', definitions', links' =
            load_commands_defining state source
          in
          ( state',
            diagnostics @ diagnostics',
            definitions @ definitions',
            links @ links' ))
        (library, [], [], []) sources
    in
    { library; library_definitions; loaded; diagnostics; definitions; links }
end

(** The standard library's source, independently of any backend, for callers
    that need to know what precedes a program's own source. *)
let stdlib_source = Stdlib_tpe.contents
