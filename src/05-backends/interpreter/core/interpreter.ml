module Error = Utils.Error
module Ast = Language.Ast
module Const = Language.Const
module Context = Language.Context
module PrettyPrint = Language.PrettyPrint
module Grade = Grades.Grade
module Rational = Grades.Rational

module Types = struct
  type computation_redex =
    | Match
    | ApplyFun
    | DoReturn
    | DoOp
    | Delay
    | Box
    | Unbox
    | HandleReturn
    | HandleOp
    | DefaultOp

  (* A frame of a reduction context: a [do] or a [handle] around the hole, with
     the location of that node and its part outside the hole. *)
  type ('abstraction, 'expression) context_frame =
    | DoFrame of Utils.Location.t * 'abstraction
    | HandleFrame of Utils.Location.t * 'expression

  (* A reduction: a redex in a reduction context, given by its frames, the
     innermost first. *)
  type 'frame computation_reduction = {
    context : 'frame list;
    redex : computation_redex;
  }

  (* A step of a top-level [run] command: a reduction of its computation, or
     the end of the command at a returned value or at an unhandled operation
     call. *)
  type 'frame run_step_label =
    | ComputationReduction of 'frame computation_reduction
    | Return
    | Unhandled
end

module Make (GS : Grades.GradeSystem.S) = struct
  module Grades = GS
  module Graded = Ast.Graded (GS)

  (* The interpreter has no use for anything but the accumulated resource grade
     itself, so its contexts record just that. *)
  module Elapsed = struct
    module Grade = struct
      type t = Graded.rho

      let one = Ast.RhoConst (GS.R.one, None)
    end

    type t = Graded.rho

    let grade rho = rho
  end

  module ContextHolderModule =
    Context.Make (Ast.Variable) (Map.Make (Ast.Variable)) (Elapsed)

  module P = Primitives.Make (GS)
  include Types

  (* The delay of the literal [q], which the parser has read. *)
  let delay q =
    match GS.R.Delay.read (Grade.rational_lit q) with
    | Some d -> d
    | None -> invalid_arg ("Interpreter.delay: " ^ Rational.show q)

  (* The state holds each resource with the resource grade it was boxed at,
     interleaved with the resource grades that have passed; operations are
     graded by effect grades. *)
  type evaluation_environment = {
    state : (Graded.rho * Graded.expression) ContextHolderModule.t;
    variables : Graded.expression ContextHolderModule.t;
    builtin_functions :
      (Graded.expression -> Graded.computation) ContextHolderModule.t;
    resource_counter : int;
    op_signatures : Graded.eps Ast.OpNameMap.t;
    op_defaults : Graded.abstraction Ast.OpNameMap.t;
  }

  let initial_environment =
    {
      state = ContextHolderModule.empty;
      variables = ContextHolderModule.empty;
      builtin_functions = ContextHolderModule.empty;
      resource_counter = 0;
      op_signatures = Ast.OpNameMap.empty;
      op_defaults = Ast.OpNameMap.empty;
    }

  exception PatternMismatch

  (** [rho_of_eps eps] is the resource grade [∣eps∣] of the effect grade [eps]
      of an operation signature. *)
  let rec rho_of_eps = function
    | Ast.EpsConst (c, at) -> Ast.RhoConst (GS.map c, at)
    | Ast.EpsAdd (eps, eps') -> Ast.RhoAdd (rho_of_eps eps, rho_of_eps eps')
    | Ast.EpsVar e -> Ast.RhoImage e

  let rec eval_tuple (env : evaluation_environment) (expr : _ Ast.expression) =
    match expr.it with
    | Ast.Annotated (expr', _) -> eval_tuple env expr'
    | Ast.Tuple exprs -> exprs
    | Ast.Var x ->
        eval_tuple env (ContextHolderModule.find_variable x env.variables)
    | _ ->
        Error.runtime "Tuple expected but got %t"
          (PrettyPrint.print_expression (module GS.R) expr)

  let rec eval_variant (env : evaluation_environment) (expr : _ Ast.expression)
      =
    match expr.it with
    | Ast.Annotated (expr', _) -> eval_variant env expr'
    | Ast.Variant (lbl, arg) -> (lbl, arg)
    | Ast.Var x ->
        eval_variant env (ContextHolderModule.find_variable x env.variables)
    | _ ->
        Error.runtime "Variant expected but got %t"
          (PrettyPrint.print_expression (module GS.R) expr)

  let rec eval_const (env : evaluation_environment) (expr : _ Ast.expression) =
    match expr.it with
    | Ast.Annotated (expr', _) -> eval_const env expr'
    | Ast.Const c -> c
    | Ast.Var x ->
        eval_const env (ContextHolderModule.find_variable x env.variables)
    | _ ->
        Error.runtime "Const expected but got %t"
          (PrettyPrint.print_expression (module GS.R) expr)

  (* The argument [expr] of a primitive, its annotations dropped and its
     top-level variables replaced by their values, through tuples and variants;
     a replaced subexpression keeps the location of the one it replaces. *)
  let rec eval_value (env : evaluation_environment) (expr : _ Ast.expression) :
      _ Ast.expression =
    match expr.it with
    | Ast.Annotated (expr', _) -> { (eval_value env expr') with at = expr.at }
    | Ast.Var x -> (
        match ContextHolderModule.find_variable_opt x env.variables with
        | Some expr' -> { (eval_value env expr') with at = expr.at }
        | None -> expr)
    | Ast.Tuple exprs ->
        { expr with it = Ast.Tuple (List.map (eval_value env) exprs) }
    | Ast.Variant (lbl, arg) ->
        { expr with it = Ast.Variant (lbl, Option.map (eval_value env) arg) }
    | Ast.Const _ | Ast.Lambda _ | Ast.PureLambda _ | Ast.RecLambda _
    | Ast.Handler _ ->
        expr

  let rec match_pattern_with_expression env (pat : _ Ast.pattern) expr =
    match pat.it with
    | Ast.PVar x -> Ast.VariableMap.singleton x expr
    | Ast.PAnnotated (pat, _) -> match_pattern_with_expression env pat expr
    | Ast.PAs (pat, x) ->
        let subst = match_pattern_with_expression env pat expr in
        Ast.VariableMap.add x expr subst
    | Ast.PTuple pats ->
        let exprs = eval_tuple env expr in
        List.fold_left2
          (fun subst pat expr ->
            let subst' = match_pattern_with_expression env pat expr in
            Ast.VariableMap.union (fun _ _ _ -> assert false) subst subst')
          Ast.VariableMap.empty pats exprs
    | Ast.PVariant (label, pat) -> (
        match (pat, eval_variant env expr) with
        | None, (label', None) when label = label' -> Ast.VariableMap.empty
        | Some pat, (label', Some expr) when label = label' ->
            match_pattern_with_expression env pat expr
        | _, _ -> raise PatternMismatch)
    | Ast.PConst c when Const.equal c (eval_const env expr) ->
        Ast.VariableMap.empty
    | Ast.PSucc (pat, k) -> (
        match eval_const env expr with
        | Const.Nat n when Z.geq n k ->
            match_pattern_with_expression env pat
              { expr with it = Ast.Const (Const.Nat (Z.sub n k)) }
        | _ -> raise PatternMismatch)
    | Ast.PNonbinding -> Ast.VariableMap.empty
    | _ -> raise PatternMismatch

  let rec remove_pattern_bound_variables subst (pat : _ Ast.pattern) =
    match pat.it with
    | Ast.PVar x -> Ast.VariableMap.remove x subst
    | Ast.PAnnotated (pat, _) -> remove_pattern_bound_variables subst pat
    | Ast.PAs (pat, x) ->
        let subst = remove_pattern_bound_variables subst pat in
        Ast.VariableMap.remove x subst
    | Ast.PTuple pats ->
        List.fold_left remove_pattern_bound_variables subst pats
    | Ast.PVariant (_, None) -> subst
    | Ast.PVariant (_, Some pat) | Ast.PSucc (pat, _) ->
        remove_pattern_bound_variables subst pat
    | Ast.PConst _ -> subst
    | Ast.PNonbinding -> subst

  (* Refreshing rebuilds the pattern, but every node keeps the span it was
     written at: the variables change, the source they came from does not. *)
  let rec refresh_pattern (pat : _ Ast.pattern) =
    match pat.it with
    | Ast.PVar x ->
        let x' = Ast.Variable.refresh x in
        ({ pat with it = Ast.PVar x' }, [ (x, x') ])
    | Ast.PAnnotated (pat', _) -> refresh_pattern pat'
    | Ast.PAs (pat', x) ->
        let pat'', vars = refresh_pattern pat' in
        let x' = Ast.Variable.refresh x in
        ({ pat with it = Ast.PAs (pat'', x') }, (x, x') :: vars)
    | Ast.PTuple pats ->
        let fold pat' (pats', vars) =
          let pat'', vars' = refresh_pattern pat' in
          (pat'' :: pats', vars' @ vars)
        in
        let pats', vars = List.fold_right fold pats ([], []) in
        ({ pat with it = Ast.PTuple pats' }, vars)
    | Ast.PVariant (lbl, Some pat') ->
        let pat'', vars = refresh_pattern pat' in
        ({ pat with it = Ast.PVariant (lbl, Some pat'') }, vars)
    | Ast.PSucc (pat', k) ->
        let pat'', vars = refresh_pattern pat' in
        ({ pat with it = Ast.PSucc (pat'', k) }, vars)
    | Ast.PVariant (_, None) | Ast.PConst _ | Ast.PNonbinding -> (pat, [])

  let rec refresh_expression vars (expr : _ Ast.expression) =
    match expr.it with
    | Ast.Var x -> (
        match List.assoc_opt x vars with
        | None -> expr
        | Some x' -> { expr with it = Ast.Var x' })
    | Ast.Const _ -> expr
    | Ast.Annotated (e, ty) ->
        { expr with it = Ast.Annotated (refresh_expression vars e, ty) }
    | Ast.Tuple exprs ->
        { expr with it = Ast.Tuple (List.map (refresh_expression vars) exprs) }
    | Ast.Variant (label, arg) ->
        {
          expr with
          it = Ast.Variant (label, Option.map (refresh_expression vars) arg);
        }
    | Ast.Lambda abs ->
        { expr with it = Ast.Lambda (refresh_abstraction vars abs) }
    | Ast.PureLambda abs ->
        { expr with it = Ast.PureLambda (refresh_abstraction vars abs) }
    | Ast.RecLambda (x, eps, abs) ->
        let x' = Ast.Variable.refresh x in
        {
          expr with
          it = Ast.RecLambda (x', eps, refresh_abstraction ((x, x') :: vars) abs);
        }
    | Ast.Handler (ret_case, op_cases) ->
        let ret_case' = refresh_abstraction vars ret_case in
        let op_cases' =
          Ast.OpNameMap.map
            (fun op_case -> refresh_abstraction vars op_case)
            op_cases
        in
        { expr with it = Ast.Handler (ret_case', op_cases') }

  and refresh_computation vars (comp : _ Ast.computation) =
    match comp.it with
    | Ast.Return expr ->
        { comp with it = Ast.Return (refresh_expression vars expr) }
    | Ast.Do (c, abs) ->
        {
          comp with
          it = Ast.Do (refresh_computation vars c, refresh_abstraction vars abs);
        }
    | Ast.Match (expr, cases) ->
        {
          comp with
          it =
            Ast.Match
              ( refresh_expression vars expr,
                List.map (refresh_abstraction vars) cases );
        }
    | Ast.Apply (expr1, expr2) ->
        {
          comp with
          it =
            Ast.Apply
              (refresh_expression vars expr1, refresh_expression vars expr2);
        }
    | Ast.Delay (n, c) ->
        { comp with it = Ast.Delay (n, refresh_computation vars c) }
    | Ast.Box (rho, e, abs) ->
        let e' = refresh_expression vars e in
        let abs' = refresh_abstraction vars abs in
        { comp with it = Ast.Box (rho, e', abs') }
    | Ast.Unbox (e, abs) ->
        let e' = refresh_expression vars e in
        let abs' = refresh_abstraction vars abs in
        { comp with it = Ast.Unbox (e', abs') }
    | Ast.Perform (op, e, abs) ->
        let e' = refresh_expression vars e in
        let abs' = refresh_abstraction vars abs in
        { comp with it = Ast.Perform (op, e', abs') }
    | Ast.Handle (c, h) ->
        let c' = refresh_computation vars c in
        let h' = refresh_expression vars h in
        { comp with it = Ast.Handle (c', h') }

  and refresh_abstraction vars (pat, comp) =
    let pat', vars' = refresh_pattern pat in
    (pat', refresh_computation (vars @ vars') comp)

  (* A substituted variable takes the span of the value bound to it; every
     other node keeps its own. *)
  let rec substitute_expression subst (expr : _ Ast.expression) =
    match expr.it with
    | Ast.Var x -> (
        match Ast.VariableMap.find_opt x subst with
        | None -> expr
        | Some expr' -> expr')
    | Ast.Const _ -> expr
    | Ast.Annotated (e, ty) ->
        { expr with it = Ast.Annotated (substitute_expression subst e, ty) }
    | Ast.Tuple exprs ->
        {
          expr with
          it = Ast.Tuple (List.map (substitute_expression subst) exprs);
        }
    | Ast.Variant (label, arg) ->
        {
          expr with
          it = Ast.Variant (label, Option.map (substitute_expression subst) arg);
        }
    | Ast.Lambda abs ->
        { expr with it = Ast.Lambda (substitute_abstraction subst abs) }
    | Ast.PureLambda abs ->
        { expr with it = Ast.PureLambda (substitute_abstraction subst abs) }
    | Ast.RecLambda (x, eps, abs) ->
        {
          expr with
          it = Ast.RecLambda (x, eps, substitute_abstraction subst abs);
        }
    | Ast.Handler (ret_case, op_cases) ->
        {
          expr with
          it =
            Ast.Handler
              ( substitute_abstraction subst ret_case,
                Ast.OpNameMap.map
                  (fun op_case -> substitute_abstraction subst op_case)
                  op_cases );
        }

  and substitute_computation subst (comp : _ Ast.computation) =
    match comp.it with
    | Ast.Return expr ->
        { comp with it = Ast.Return (substitute_expression subst expr) }
    | Ast.Do (c, abs) ->
        {
          comp with
          it =
            Ast.Do
              (substitute_computation subst c, substitute_abstraction subst abs);
        }
    | Ast.Match (expr, cases) ->
        {
          comp with
          it =
            Ast.Match
              ( substitute_expression subst expr,
                List.map (substitute_abstraction subst) cases );
        }
    | Ast.Apply (expr1, expr2) ->
        {
          comp with
          it =
            Ast.Apply
              ( substitute_expression subst expr1,
                substitute_expression subst expr2 );
        }
    | Ast.Delay (n, c) ->
        { comp with it = Ast.Delay (n, substitute_computation subst c) }
    | Ast.Box (rho, e, abs) ->
        {
          comp with
          it =
            Ast.Box
              ( rho,
                substitute_expression subst e,
                substitute_abstraction subst abs );
        }
    | Ast.Unbox (e, abs) ->
        {
          comp with
          it =
            Ast.Unbox
              (substitute_expression subst e, substitute_abstraction subst abs);
        }
    | Ast.Perform (op, e, abs) ->
        {
          comp with
          it =
            Ast.Perform
              ( op,
                substitute_expression subst e,
                substitute_abstraction subst abs );
        }
    | Ast.Handle (c, h) ->
        {
          comp with
          it =
            Ast.Handle
              (substitute_computation subst c, substitute_expression subst h);
        }

  and substitute_abstraction subst (pat, comp) =
    let subst' = remove_pattern_bound_variables subst pat in
    (pat, substitute_computation subst' comp)

  let substitute subst comp =
    let subst = Ast.VariableMap.map (refresh_expression []) subst in
    substitute_computation subst comp

  let rec eval_function env (expr : _ Ast.expression) =
    match expr.it with
    | Ast.Annotated (expr', _) -> eval_function env expr'
    | Ast.Lambda (pat, comp) ->
        fun arg ->
          let subst = match_pattern_with_expression env pat arg in
          substitute subst comp
    | Ast.PureLambda (pat, comp) ->
        fun arg ->
          let subst = match_pattern_with_expression env pat arg in
          substitute subst comp
    | Ast.RecLambda (f, _, (pat, comp)) ->
        fun arg ->
          let subst =
            match_pattern_with_expression env pat arg
            |> Ast.VariableMap.add f expr
          in
          substitute subst comp
    | Ast.Var x -> (
        match ContextHolderModule.find_variable_opt x env.variables with
        | Some expr' -> eval_function env expr'
        | None ->
            let f = ContextHolderModule.find_variable x env.builtin_functions in
            fun arg -> f (eval_value env arg))
    | _ ->
        Error.runtime "Function expected but got %t"
          (PrettyPrint.print_expression (module GS.R) expr)

  let rec eval_handler env (expr : _ Ast.expression) =
    match expr.it with
    | Ast.Annotated (expr', _) -> eval_handler env expr'
    | Ast.Handler (ret_case, op_cases) -> (ret_case, op_cases)
    | Ast.Var x -> (
        match ContextHolderModule.find_variable_opt x env.variables with
        | Some expr' -> eval_handler env expr'
        | None ->
            Error.runtime
              "Handler expected but did not find it from environment")
    | _ ->
        Error.runtime "Handler expected but got %t"
          (PrettyPrint.print_expression (module GS.R) expr)

  type frame = (Graded.abstraction, Graded.expression) context_frame

  (* A computation decomposed into a reduction context, its frames the
     innermost first, and the subcomputation in its hole. Unless the context
     is empty, the subcomputation is not a [return] or an operation call. *)
  type focus = { frames : frame list; subject : Graded.computation }

  let plug frame (comp : _ Ast.computation) =
    match frame with
    | DoFrame (at, abs) -> Ast.located at (Ast.Do (comp, abs))
    | HandleFrame (at, handler) -> Ast.located at (Ast.Handle (comp, handler))

  (** [computation focus] is the computation [focus] decomposes. *)
  let computation { frames; subject } =
    List.fold_left (Fun.flip plug) subject frames

  let is_terminal (comp : _ Ast.computation) =
    match comp.it with Ast.Return _ | Ast.Perform _ -> true | _ -> false

  (* The decomposition at its redex of the computation formed by [frames]
     around [comp]: the context is extended through every [do] and [handle]
     whose body is not terminal, and a terminal [comp] is plugged into the
     innermost frame, where it forms a redex. Refocusing (Danvy and Nielsen,
     Refocusing in Reduction Semantics, 2004): a step decomposes its contractum
     in place instead of the whole computation. *)
  let rec refocus frames (comp : _ Ast.computation) =
    match (comp.it, frames) with
    | Ast.Do (comp1, abs), _ when not (is_terminal comp1) ->
        refocus (DoFrame (comp.at, abs) :: frames) comp1
    | Ast.Handle (body, handler), _ when not (is_terminal body) ->
        refocus (HandleFrame (comp.at, handler) :: frames) body
    | (Ast.Return _ | Ast.Perform _), frame :: frames ->
        { frames; subject = plug frame comp }
    | _ -> { frames; subject = comp }

  (* The reductions of the computation [comp] at its top, each with the
     environment after it, the redex and the contractum. A [do] or a [handle]
     reduces at its top only when its body is terminal. Every computation the
     interpreter builds is a contraction of the redex it is reducing, so it is
     reported at the redex's span. *)
  let contract env (comp : _ Ast.computation) =
    let at = comp.at in
    match comp.it with
    | Ast.Return _ -> []
    | Ast.Match (expr, cases) ->
        let rec find_case = function
          | (env, pat, comp) :: cases -> (
              match match_pattern_with_expression env pat expr with
              | subst -> [ (env, Match, fun () -> substitute subst comp) ]
              | exception PatternMismatch -> find_case cases)
          | [] -> []
        in
        let cases' =
          List.map
            (fun (pat, comp) ->
              let pat', vars = refresh_pattern pat in
              let comp' = refresh_computation vars comp in
              (env, pat', comp'))
            cases
        in
        find_case cases'
    | Ast.Apply (expr1, expr2) ->
        let f = eval_function env expr1 in
        [ (env, ApplyFun, fun () -> f expr2) ]
    | Ast.Do (comp1, comp2) -> (
        match comp1.it with
        | Ast.Return expr ->
            let pat, comp2' = comp2 in
            let subst = match_pattern_with_expression env pat expr in
            [ (env, DoReturn, fun () -> substitute subst comp2') ]
        | Ast.Perform (op, expr, (pat, cont)) ->
            [
              ( env,
                DoOp,
                fun () ->
                  Ast.located at
                    (Ast.Perform
                       (op, expr, (pat, Ast.located at (Ast.Do (cont, comp2)))))
              );
            ]
        | _ -> [])
    | Ast.Delay (q, comp) ->
        let rho = Ast.RhoConst (GS.R.of_delay (delay q), None) in
        let env' =
          { env with state = ContextHolderModule.add_temp rho env.state }
        in
        [ (env', Delay, fun () -> comp) ]
    | Ast.Box (rho, expr, (pat, body)) ->
        let rec doBox rho expr (pat : _ Ast.pattern) body =
          match pat.it with
          | Ast.PVar x ->
              let resource_counter = env.resource_counter in
              let x' =
                Ast.Variable.fresh ("resource_" ^ string_of_int resource_counter)
              in
              let state' =
                ContextHolderModule.add_variable x' (rho, expr) env.state
              in
              let env' =
                {
                  env with
                  state = state';
                  resource_counter = resource_counter + 1;
                }
              in
              [ (env', Box, fun () -> refresh_computation [ (x, x') ] body) ]
          | Ast.PAnnotated (pat', _) -> doBox rho expr pat' body
          | _ ->
              Error.runtime "Box expected a variable but got pattern %t"
                (PrettyPrint.print_pattern pat)
        in
        doBox rho expr pat body
    | Ast.Unbox (expr, (pat, body)) ->
        let rec doUnbox (expr : _ Ast.expression) pat body =
          match expr.it with
          | Ast.Var x ->
              let _rho', expr' =
                ContextHolderModule.find_variable x env.state
              in
              let subst = match_pattern_with_expression env pat expr' in
              [ (env, Unbox, fun () -> substitute subst body) ]
          | Ast.Annotated (expr', _) -> doUnbox expr' pat body
          | _ ->
              Error.runtime "Unbox expected a variable but got expression %t"
                (PrettyPrint.print_expression (module GS.R) expr)
        in
        doUnbox expr pat body
    (* An operation call at the top of a run is reduced by [steps]. *)
    | Ast.Perform _ -> []
    | Ast.Handle (body, handler) -> (
        let (pat, ret_comp), op_cases = eval_handler env handler in
        match body.it with
        | Ast.Return expr ->
            let subst = match_pattern_with_expression env pat expr in
            (env, HandleReturn, fun () -> substitute subst ret_comp) :: []
        | Ast.Perform (op, expr, (op_pat, op_cont)) -> (
            let op_case = Ast.OpNameMap.find_opt op op_cases in
            match op_case with
            | Some ({ it = Ast.PTuple [ op_arg_pat; op_cont_pat ]; _ }, op_case)
              -> (
                let op_sig = Ast.OpNameMap.find_opt op env.op_signatures in
                match op_sig with
                | Some eps ->
                    let resource_counter = env.resource_counter in
                    let x =
                      Ast.Variable.fresh
                        ("resource_" ^ string_of_int resource_counter)
                    in
                    let env' =
                      { env with resource_counter = resource_counter + 1 }
                    in
                    let arg_subst =
                      match_pattern_with_expression env' op_arg_pat expr
                    in
                    let cont_subst =
                      match_pattern_with_expression env' op_cont_pat
                        (Ast.located at (Ast.Var x))
                    in
                    (* The continuation is boxed at the resource grade the
                       operation's effect grade maps to. *)
                    ( env',
                      HandleOp,
                      fun () ->
                        Ast.located at
                          (Ast.Box
                             ( rho_of_eps eps,
                               Ast.located at
                                 (Ast.Lambda
                                    ( op_pat,
                                      Ast.located at
                                        (Ast.Handle (op_cont, handler)) )),
                               ( Ast.located at (Ast.PVar x),
                                 substitute cont_subst
                                   (substitute arg_subst op_case) ) )) )
                    :: []
                | None ->
                    Error.runtime
                      "Internal error: operation %t has no signature in the \
                       runtime state"
                      (Ast.OpName.print op))
            | Some _ ->
                Error.runtime
                  "Internal error: the case of operation %t does not bind an \
                   argument and a continuation"
                  (Ast.OpName.print op)
            | _ ->
                ( env,
                  HandleOp,
                  fun () ->
                    Ast.located at
                      (Ast.Perform
                         ( op,
                           expr,
                           ( op_pat,
                             Ast.located at (Ast.Handle (op_cont, handler)) ) ))
                )
                :: [])
        | _ -> [])

  (** [returned_value env comp] is [comp] with the value it returns, if it is a
      [return], given by {!eval_value}: its top-level variables are replaced by
      their values in [env]. *)
  let returned_value env (comp : _ Ast.computation) =
    match comp.it with
    | Ast.Return expr -> { comp with it = Ast.Return (eval_value env expr) }
    | _ -> comp

  (* The [run] commands loaded so far, the last first, each with the
     environment of the commands above it. *)
  type load_state = {
    environment : evaluation_environment;
    runs : (evaluation_environment * Graded.computation) list;
  }

  let initial_load_state = { environment = initial_environment; runs = [] }

  let load_primitive load_state x prim =
    {
      load_state with
      environment =
        {
          load_state.environment with
          builtin_functions =
            ContextHolderModule.add_variable x
              (P.primitive_function prim)
              load_state.environment.builtin_functions;
        };
    }

  let load_ty_def load_state _ = load_state

  let load_top_let load_state x expr =
    {
      load_state with
      environment =
        {
          load_state.environment with
          variables =
            ContextHolderModule.add_variable x expr
              load_state.environment.variables;
        };
    }

  let load_top_do load_state comp =
    { load_state with runs = (load_state.environment, comp) :: load_state.runs }

  let load_op_sig load_state op eps =
    {
      load_state with
      environment =
        {
          load_state.environment with
          op_signatures =
            Ast.OpNameMap.add op eps load_state.environment.op_signatures;
        };
    }

  let load_op_default load_state op abs =
    {
      load_state with
      environment =
        {
          load_state.environment with
          op_defaults =
            Ast.OpNameMap.add op abs load_state.environment.op_defaults;
        };
    }

  (* The computation of the current [run] command, if any, decomposed at its
     redex, with its environment, and the [run] commands after it, each with
     the environment of the commands above it. *)
  type run_state = {
    environment : evaluation_environment;
    current : focus option;
    pending : (evaluation_environment * Graded.computation) list;
  }

  type step_label = frame run_step_label

  type step = {
    environment : evaluation_environment;
    label : step_label;
    next_state : unit -> run_state;
  }

  (* The state at the start of the first of [runs], or the final state
     [environment] if there is none. *)
  let start environment = function
    | [] -> { environment; current = None; pending = [] }
    | (environment, comp) :: pending ->
        { environment; current = Some (refocus [] comp); pending }

  let run (load_state : load_state) =
    start load_state.environment (List.rev load_state.runs)

  (* The step labelled [label] that ends the current top-level [run] command
     and passes to the next one, which executes in the environment of the
     commands above it, with an empty resource store. *)
  let end_run label (environment : evaluation_environment) pending =
    {
      environment;
      label;
      next_state =
        (fun () ->
          start { environment with state = ContextHolderModule.empty } pending);
    }

  let steps = function
    | { current = None; _ } -> []
    | {
        current = Some { frames = []; subject = { it = Ast.Return _; _ } };
        environment;
        pending;
      } ->
        [ end_run Return environment pending ]
    (* A default implementation fires only here, where the operation call has
       bubbled out of every enclosing [do] and [handle] and so is known to be
       unhandled; [contract] deliberately gets no [Perform] rule. The body runs
       in place of the call and its result is passed to the continuation,
       exactly as a handled operation's result would be. Only the defaults
       declared above the [run] command are in its environment. *)
    | {
        current =
          Some
            {
              frames = [];
              subject = { it = Ast.Perform (op, expr, (pat, cont)); at };
            };
        environment;
        pending;
      }
      when Ast.OpNameMap.mem op environment.op_defaults ->
        let dpat, dcomp = Ast.OpNameMap.find op environment.op_defaults in
        let dpat', vars = refresh_pattern dpat in
        let dcomp' = refresh_computation vars dcomp in
        let subst = match_pattern_with_expression environment dpat' expr in
        [
          {
            environment;
            label = ComputationReduction { context = []; redex = DefaultOp };
            next_state =
              (fun () ->
                {
                  current =
                    Some
                      (refocus []
                         (Ast.located at
                            (Ast.Do (substitute subst dcomp', (pat, cont)))));
                  environment;
                  pending;
                });
          };
        ]
    (* An operation call without a default that has bubbled out of every
       enclosing [do] and [handle] is unhandled: the run stops there and
       execution passes to the next top-level [run] command. *)
    | {
        current = Some { frames = []; subject = { it = Ast.Perform _; _ } };
        environment;
        pending;
      } ->
        [ end_run Unhandled environment pending ]
    | { current = Some { frames; subject }; environment; pending } ->
        List.map
          (fun (env, redex, comp') ->
            {
              environment = env;
              label = ComputationReduction { context = frames; redex };
              next_state =
                (fun () ->
                  {
                    current = Some (refocus frames (comp' ()));
                    environment = env;
                    pending;
                  });
            })
          (contract environment subject)
end
