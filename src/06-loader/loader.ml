module Location = Utils.Location
module Error = Utils.Error
module Diagnostic = Utils.Diagnostic
module Ast = Language.Ast
open Backend

let declared_operations commands =
  List.filter_map
    (fun (cmd : _ SugaredAst.command) ->
      match cmd.it with
      | SugaredAst.OpSig (name, _, _, _, bounds) -> Some (name.it, bounds)
      | SugaredAst.TyDef _ | SugaredAst.OpDefault _ | SugaredAst.TopLet _
      | SugaredAst.TopLetRec _ | SugaredAst.TopDo _ ->
          None)
    commands

let with_running_times (type e) (module E : Grades.Grade.S with type t = e)
    ~filename running_times
    (commands : ('r, e SugaredAst.grade Ast.located) SugaredAst.command list) =
  let declared = List.map fst (declared_operations commands) in
  List.iter
    (fun (op, _) ->
      if not (List.mem op declared) then
        Error.compilation
          "The source %s declares no operation %s, whose running-time bounds \
           are given"
          filename op)
    running_times;
  (* The running times of no operations, which the grades read only of
     events, where they read running times. *)
  let no_operations =
    {
      Grades.Grade.running_time =
        (fun event ->
          invalid_arg
            ("Loader.with_running_times: the event " ^ event
           ^ " is not a declared operation"));
      operations = [];
    }
  in
  let read ~loc (lo, hi) =
    let read_end =
      Grades.Grade.map_end (fun q ->
          match E.Delay.read (Grades.Grade.rational_lit q) with
          | Some d -> d
          | None ->
              Error.compilation ~loc
                "In the `%s` grading monoid, the running-time bound %s is not \
                 a delay: %s"
                E.name (Grades.Rational.show q)
                (E.Delay.rejection (Grades.Grade.rational_lit q)))
    in
    let lo = read_end lo in
    (lo, read_end hi)
  in
  (* [open_at_zero declared bounds] is [bounds] with a closed lower end at 0
     made open where the [declared] one is open at 0, the running time being
     positive. *)
  let open_at_zero declared (lo, hi) =
    match (declared, lo) with
    | (Grades.Grade.Open z, _), Grades.Grade.Closed z'
      when Grades.Rational.(equal z zero && equal z' zero) ->
        (Grades.Grade.Open z', hi)
    | _ -> (lo, hi)
  in
  (* [finite own bounds] is [own] with each infinite end, that of a grade
     bounding durations on one side only, replaced by the end of [bounds]. *)
  let finite (lo, hi) (lo', hi') =
    let pick b b' = match b with Grades.Grade.Unbounded -> b' | _ -> b in
    (pick lo lo', pick hi hi')
  in
  List.map
    (fun (cmd : _ SugaredAst.command) ->
      match cmd.it with
      | SugaredAst.OpSig (name, t1, t2, (eps : _ Ast.located), declared) -> (
          match (List.assoc_opt name.it running_times, declared, eps.it) with
          | None, _, _ | Some _, None, SugaredAst.GradeParam _ -> cmd
          | Some bounds, Some declared, _ ->
              {
                cmd with
                it =
                  SugaredAst.OpSig
                    (name, t1, t2, eps, Some (open_at_zero declared bounds));
              }
          | Some bounds, None, SugaredAst.GradeLit g -> (
              match if E.needs_op_bounds then E.events g else [] with
              | event :: _ -> Error.typing "Unknown event `%s`" event
              | [] -> (
                  match E.duration_bounds no_operations g with
                  | None -> cmd
                  | Some own
                    when E.equal no_operations g
                           (E.of_bounds (read ~loc:eps.at (finite own bounds)))
                    ->
                      let g = E.of_bounds (read ~loc:eps.at bounds) in
                      {
                        cmd with
                        it =
                          SugaredAst.OpSig
                            ( name,
                              t1,
                              t2,
                              { eps with it = SugaredAst.GradeLit g },
                              None );
                      }
                  | Some _ ->
                      Error.compilation ~loc:eps.at
                        "The grade of the operation %s is not that of its \
                         running-time bounds, which therefore cannot be \
                         replaced"
                        name.it)))
      | SugaredAst.TyDef _ | SugaredAst.OpDefault _ | SugaredAst.TopLet _
      | SugaredAst.TopLetRec _ | SugaredAst.TopDo _ ->
          cmd)
    commands

let stdlib_filename = "stdlib.tpe"

let grades_of_sources ~grades sources =
  match
    List.find_map
      (fun (filename, text) -> Parser.LevelsDeclaration.scan ~filename text)
      sources
  with
  | None -> (
      match List.assoc_opt grades Grades.GradeRegistry.grade_modules with
      | Some grade -> (grade, None)
      | None ->
          invalid_arg ("Loader.grades_of_sources: unknown grades " ^ grades))
  | Some (at, chains) -> (
      let lattice = Grades.LevelLattice.of_chains ~at chains in
      match Grades.GradeRegistry.over_levels grades lattice with
      | Some grade -> (grade, Some lattice)
      | None ->
          Error.syntax ~loc:at "%s" (Grades.GradeRegistry.without_levels grades)
      )

module Loader (Backend : Backend.S) = struct
  module D = Desugarer.Make (Backend.Grades)
  module TC = Typechecker.Make (Backend.Grades)
  module Grammar = Parser.Grammar.Make (Backend.Grades)

  type command =
    ( Backend.Grades.R.t SugaredAst.grade Ast.located,
      Backend.Grades.E.t SugaredAst.grade Ast.located )
    SugaredAst.command

  type state = {
    desugarer : D.state;
    references : Desugarer.References.env;
    backend : Backend.load_state;
    typechecker : TC.state;
  }

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
      Error.syntax ~loc:(Location.of_lexbuf lexbuf) "Parser error"

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
    at : Location.t;
    scheme : TC.scheme;
  }

  (** Execute [cmds] in order, returning the state they leave behind, the
      diagnostics they produced and the top-level definitions accepted before
      the first of them, in order. With [~recover:true] the typing errors the
      loader can carry on from are collected, so that a program's independent
      errors are reported at once; otherwise the first escapes as an exception.
      Errors of any other kind are fatal either way. *)
  let execute_commands ~recover state cmds =
    let step (state, diagnostics, defined, accepted, stopped)
        (cmd : _ Ast.command) =
      if stopped then (state, diagnostics, defined, accepted, stopped)
      else
        match execute_command state cmd with
        | Ok state' ->
            let defined =
              match (cmd.it, diagnostics) with
              | Ast.TopLet (x, _), [] -> (x, cmd.at) :: defined
              | _ -> defined
            in
            (state', diagnostics, defined, cmd :: accepted, false)
        | Error (d, _) when not recover -> raise (Error.Error d)
        | Error (d, Some state') ->
            (state', d :: diagnostics, defined, accepted, false)
        | Error (d, None) -> (state, d :: diagnostics, defined, accepted, true)
    in
    let state', diagnostics, defined, accepted, _ =
      List.fold_left step (state, [], [], [], false) cmds
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
    ( state',
      List.rev diagnostics,
      List.filter_map definition (List.rev defined),
      List.rev accepted )

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
    let state'', diagnostics, defined, accepted =
      execute_commands ~recover:true state' cmds'
    in
    (state'', diagnostics, defined, links, accepted)

  let load_commands_all state cmds =
    let state', diagnostics, _, _, _ = load_commands_defining state cmds in
    (state', diagnostics)

  (* Without recovery the first error escapes as an exception and the
     diagnostic list is empty; re-raising covers the case all the same. *)
  let load_commands state cmds =
    let state', cmds', _ = desugar_commands state cmds in
    match execute_commands ~recover:false state' cmds' with
    | state'', [], _, _ -> state''
    | _, d :: _, _, _ -> raise (Error.Error d)

  let parse_source ?(filename = "") ?(running_times = []) source =
    let lexbuf = Lexing.from_string source in
    lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = filename };
    let commands = parse_commands lexbuf in
    if running_times = [] then commands
    else
      with_running_times
        (module Backend.Grades.E)
        ~filename running_times commands

  let parse_file filename = Parser.Lexer.read_file parse_commands filename
  let stdlib_source = Stdlib_tpe.contents

  type 'link program = {
    library : state;
    library_definitions : definition list;
    loaded : state;
    diagnostics : Diagnostic.t list;
    definitions : definition list;
    links : 'link list;
    commands : Ast.Graded(Backend.Grades).command list;
    operations :
      (Ast.operation
      * (Grades.Rational.t Grades.Grade.bound
        * Grades.Rational.t Grades.Grade.bound)
        option)
      list;
    compound_operations : Ast.operation list;
  }

  (* The operations [cmds] declare, each with the bounds of its running time:
     those it declares, or else those its grade implies
     ({!Grades.Grade.S.duration_bounds}), read over the declared ones and those
     of the operations before it with finite bounds, as the typechecker reads
     them, where the grade names no other operation. *)
  let operations_of cmds =
    let signatures =
      List.filter_map
        (fun (cmd : _ Ast.command) ->
          match cmd.it with
          | Ast.OpSig (op, _, _, eps, bounds) -> Some (op, eps, bounds)
          | Ast.TyDef _ | Ast.OpDefault _ | Ast.TopLet _ | Ast.TopDo _ -> None)
        cmds
    in
    let declared =
      List.filter_map
        (fun (op, _, bounds) ->
          Option.map (fun b -> (Ast.OpName.string_of op, b)) bounds)
        signatures
    in
    let operations = List.map fst declared in
    let step (known, acc) (op, eps, bounds) =
      let bounds =
        match (bounds, eps) with
        | Some _, _ -> bounds
        | None, Ast.EpsConst (grade, _)
          when (not Backend.Grades.E.needs_op_bounds)
               || List.for_all
                    (fun name -> List.mem_assoc name known)
                    (Backend.Grades.E.events grade) ->
            let running_time name = List.assoc name known in
            Backend.Grades.E.duration_bounds
              { Grades.Grade.running_time; operations }
              grade
        | None, Ast.EpsConst _ | None, (Ast.EpsAdd _ | Ast.EpsVar _) -> None
      in
      let known =
        match bounds with
        | Some ((_, (Grades.Grade.Closed _ | Grades.Grade.Open _)) as b) ->
            (Ast.OpName.string_of op, b) :: known
        | Some (_, Grades.Grade.Unbounded) | None -> known
      in
      (known, (op, bounds) :: acc)
    in
    List.rev (snd (List.fold_left step (declared, []) signatures))

  (* The operations [cmds] declare whose grade is a literal that is not that
     of an atomic operation. *)
  let compound_operations_of cmds =
    List.filter_map
      (fun (cmd : _ Ast.command) ->
        match cmd.it with
        | Ast.OpSig (op, _, _, Ast.EpsConst (grade, _), _)
          when not (Backend.Grades.E.is_atomic (Ast.OpName.string_of op) grade)
          ->
            Some op
        | Ast.OpSig _ | Ast.TyDef _ | Ast.OpDefault _ | Ast.TopLet _
        | Ast.TopDo _ ->
            None)
      cmds

  let load_program ~use_stdlib sources =
    let stdlib =
      if use_stdlib then parse_source ~filename:stdlib_filename stdlib_source
      else []
    in
    let library, library_definitions, library_commands =
      match
        load_commands_defining
          (declare (stdlib :: sources) initial_state)
          stdlib
      with
      | state, [], definitions, _, accepted -> (state, definitions, accepted)
      | _, d :: _, _, _, _ -> raise (Error.Error d)
    in
    let loaded, diagnostics, definitions, links, commands =
      List.fold_left
        (fun (state, diagnostics, definitions, links, commands) source ->
          let state', diagnostics', definitions', links', accepted =
            load_commands_defining state source
          in
          ( state',
            diagnostics @ diagnostics',
            definitions @ definitions',
            links @ links',
            commands @ accepted ))
        (library, [], [], [], library_commands)
        sources
    in
    {
      library;
      library_definitions;
      loaded;
      diagnostics;
      definitions;
      links;
      commands;
      operations = operations_of commands;
      compound_operations = compound_operations_of commands;
    }
end

let stdlib_source = Stdlib_tpe.contents
