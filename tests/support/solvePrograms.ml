(* Whole programs checked command by command by the constraint solver, shared
   by the solver tests and the typechecking benchmark. *)

module Ast = Language.Ast
module Grade = Grades.Grade
module GradeSystem = Grades.GradeSystem
module Location = Utils.Location
module Error = Utils.Error
module Diagnostic = Utils.Diagnostic

let fail = TestSupport.Failures.fail
let verbose = Array.exists (( = ) "-v") Sys.argv

type command_verdict = { line : int; kind : string; ok : bool; detail : string }
(** The verdict of the solver on one command. *)

module Programs (G : Grade.S) = struct
  module GS = GradeSystem.Identity (G)
  module X = Inference.GradeExp.Make (GS)
  module C = Inference.Constraint.Make (X)
  module Gen = Inference.Generate.Make (C)
  module P = Inference.Program.Make (C)
  module S = Inference.Solver.Make (C)
  module R = Inference.Residual.Make (C)
  module D = Desugarer.Make (GS)
  module Grammar = Parser.Grammar.Make (GS)

  type state = { desugarer : D.state; env : Gen.env }

  let parse lexbuf = Grammar.commands (Parser.Lexer.tokens ()) lexbuf

  let parse_source ~name source =
    let lexbuf = Lexing.from_string source in
    lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = name };
    parse lexbuf

  let initial =
    List.fold_left
      (fun st prim ->
        let x = Ast.Variable.fresh (Language.Primitives.primitive_name prim) in
        {
          desugarer = D.load_primitive st.desugarer x prim;
          env = Gen.load_primitive st.env x prim;
        })
      { desugarer = D.initial_state; env = Gen.initial_env }
      Language.Primitives.primitives

  let kind_of (cmd : _ Ast.command) =
    match cmd.it with
    | Ast.TyDef _ -> "type"
    | Ast.OpSig _ -> "operation"
    | Ast.OpDefault _ -> "default"
    | Ast.TopLet (x, _) -> "let " ^ Ast.Variable.string_of x
    | Ast.TopDo _ -> "run"

  let detail_of = function
    | P.Accepted -> ""
    | P.Defined (_, scheme) when verbose ->
        Format.asprintf "%t" (C.print_scheme scheme)
    | P.Defined _ -> ""
    | P.Rejected (P.Malformed d) -> d.Diagnostic.message
    | P.Rejected (P.Refuted f) -> Format.asprintf "%t" (R.print_failure f)
    | P.Rejected (P.Stuck _) -> "stuck"

  (* Each command desugared, then executed, until one stops the others; the
     verdicts, in order. *)
  let run st cmds =
    let step (st, verdicts, next) cmd =
      match next with
      | P.Stop -> (st, verdicts, next)
      | P.Continue ->
          let desugarer, cmd = D.desugar_command st.desugarer cmd in
          let env, (verdict : P.verdict), next = P.execute st.env cmd in
          let ok =
            match verdict.outcome with
            | P.Accepted | P.Defined _ -> true
            | P.Rejected _ -> false
          in
          let v =
            {
              line = cmd.at.Location.start.line;
              kind = kind_of cmd;
              ok;
              detail = detail_of verdict.outcome;
            }
          in
          ({ desugarer; env }, v :: verdicts, next)
    in
    let st, verdicts, _ = List.fold_left step (st, [], P.Continue) cmds in
    (st, List.rev verdicts)

  let with_stdlib =
    lazy
      (let st, verdicts =
         run initial (parse_source ~name:"stdlib.tpe" Loader.stdlib_source)
       in
       List.iter
         (fun v ->
           if not v.ok then
             fail "stdlib (%s) line %d, %s: %s" G.name v.line v.kind v.detail)
         verdicts;
       st)

  (* [declare cmds st] is [st] in the program of the standard library, which
     declares no operations, and [cmds]. *)
  let declare cmds st =
    {
      st with
      env = Gen.declare_operations (Loader.declared_operations cmds) st.env;
    }

  (* The solver's verdict on each command of [source], after the standard
     library: the command, whether it is accepted, and why not. *)
  let definitions source =
    let cmds = parse_source ~name:"small" source in
    let st = declare cmds (Lazy.force with_stdlib) in
    let _, _, verdicts =
      List.fold_left
        (fun (desugarer, env, verdicts) cmd ->
          let desugarer, cmd = D.desugar_command desugarer cmd in
          let env, (verdict : P.verdict), _ = P.execute env cmd in
          let ok =
            match verdict.outcome with
            | P.Accepted | P.Defined _ -> true
            | P.Rejected _ -> false
          in
          ( desugarer,
            env,
            (kind_of cmd, ok, detail_of verdict.outcome) :: verdicts ))
        (st.desugarer, st.env, []) cmds
    in
    List.rev verdicts

  (* The verdicts on a file, or [None] when it does not parse or desugar,
     after the declarations of the packages, each of whose commands must be
     accepted. *)
  let file ?(packages = []) path =
    match Parser.Lexer.read_file parse path with
    | cmds -> (
        let preceding =
          List.concat_map
            (fun (name, source, running_times) ->
              Loader.with_running_times
                (module GS.E)
                ~filename:name running_times
                (parse_source ~name source))
            packages
        in
        let st = declare (preceding @ cmds) (Lazy.force with_stdlib) in
        match run st preceding with
        | st, preceded -> (
            List.iter
              (fun v ->
                if not v.ok then
                  fail "%s: a package (%s) line %d, %s: %s" path G.name v.line
                    v.kind v.detail)
              preceded;
            match run st cmds with
            | _, verdicts -> Some verdicts
            | exception Error.Error _ -> None)
        | exception Error.Error _ -> None)
    | exception Error.Error _ -> None
    | exception Grammar.Error -> None
end

module type PROGRAMS = sig
  val file :
    ?packages:(string * string * (string * Grade.running_time) list) list ->
    string ->
    command_verdict list option

  val definitions : string -> (string * bool * string) list
end

(* The programs of each grade, the standard library loaded once. *)
let programs_of =
  let table = Hashtbl.create 8 in
  fun grades ->
    match Hashtbl.find_opt table grades with
    | Some p -> p
    | None ->
        let (module G) = TestPrograms.grade_module grades in
        let p = (module Programs (G) : PROGRAMS) in
        Hashtbl.add table grades p;
        p
