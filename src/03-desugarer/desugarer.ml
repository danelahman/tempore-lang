(** Desugaring of syntax into the core language. *)

module Error = Utils.Error
module List = Utils.List
module Sugared = SugaredAst
module Untyped = Language.Ast
module Context = Language.Context
module Const = Language.Const
module StringMap = Map.Make (String)
module StringSet = Set.Make (String)

module Make (GS : Grades.GradeSystem.S) = struct
  let add_unique ~loc kind str symb string_map =
    StringMap.update str
      (function
        | None -> Some symb
        | Some _ -> Error.syntax ~loc "%s `%s` defined multiple times" kind str)
      string_map

  (* The grade variables of the annotations of a definition: those with an
     occurrence in an effect position are effect variables, the others
     resource variables. *)
  type grade_params = {
    effects : Untyped.Eps_var.t StringMap.t;
    resources : Untyped.Rho_var.t StringMap.t;
  }

  type state = {
    ty_names : Untyped.ty_name StringMap.t;
    ty_params : Untyped.ty_param StringMap.t;
        (** those of the type definition or of the annotations of the definition
            being desugared *)
    variables : Untyped.variable StringMap.t;
    labels : Untyped.label StringMap.t;
    operations : Untyped.operation StringMap.t;
    grade_params : grade_params option;
        (** those of the definition being desugared, [None] outside one *)
  }

  let initial_state =
    {
      ty_names =
        StringMap.empty
        |> StringMap.add Sugared.bool_ty_name Untyped.bool_ty_name
        |> StringMap.add Sugared.nat_ty_name Untyped.nat_ty_name
        |> StringMap.add Sugared.unit_ty_name Untyped.unit_ty_name
        |> StringMap.add Sugared.string_ty_name Untyped.string_ty_name
        |> StringMap.add Sugared.float_ty_name Untyped.float_ty_name
        |> StringMap.add Sugared.empty_ty_name Untyped.empty_ty_name
        |> StringMap.add Sugared.list_ty_name Untyped.list_ty_name;
      ty_params = StringMap.empty;
      variables = StringMap.empty;
      labels =
        StringMap.empty
        |> StringMap.add Sugared.nil_label Untyped.nil_label
        |> StringMap.add Sugared.cons_label Untyped.cons_label;
      operations = StringMap.empty;
      grade_params = None;
    }

  let find_symbol ~loc map name =
    match StringMap.find_opt name map with
    | None -> Error.syntax ~loc "Unknown name `%s`" name
    | Some symbol -> symbol

  let lookup_ty_name ~loc state = find_symbol ~loc state.ty_names
  let lookup_ty_param ~loc state = find_symbol ~loc state.ty_params
  let lookup_variable ~loc state = find_symbol ~loc state.variables
  let lookup_label ~loc state = find_symbol ~loc state.labels
  let lookup_operation ~loc state = find_symbol ~loc state.operations

  (* ------------------------------------------------------------------ *)
  (* Annotation variables                                                *)
  (* ------------------------------------------------------------------ *)

  (* The names of type and grade variables in the annotations of a term, and
     those among the grade variables with an occurrence in an effect position.
     The grade of [box] is not an annotation. *)
  type annotation_names = {
    tys : StringSet.t;
    grades : StringSet.t;
    effects : StringSet.t;
  }

  let no_annotation_names =
    {
      tys = StringSet.empty;
      grades = StringSet.empty;
      effects = StringSet.empty;
    }

  let grade_name ~in_effect names { Sugared.it; _ } =
    match it with
    | Sugared.GradeLit _ -> names
    | Sugared.GradeParam p ->
        {
          names with
          grades = StringSet.add p names.grades;
          effects =
            (if in_effect then StringSet.add p names.effects else names.effects);
        }

  let rec ty_annotation_names names { Sugared.it = ty; _ } =
    match ty with
    | Sugared.TyConst _ -> names
    | Sugared.TyParam a -> { names with tys = StringSet.add a names.tys }
    | Sugared.TyApply (_, tys) | Sugared.TyTuple tys ->
        List.fold_left ty_annotation_names names tys
    | Sugared.TyArrow (ty, cty) ->
        comp_ty_annotation_names (ty_annotation_names names ty) cty
    | Sugared.TyBox (rho, ty) ->
        ty_annotation_names (grade_name ~in_effect:false names rho) ty
    | Sugared.TyHandler (cty, cty') ->
        comp_ty_annotation_names (comp_ty_annotation_names names cty) cty'

  and comp_ty_annotation_names names (Sugared.CompTy (ty, eps)) =
    grade_name ~in_effect:true (ty_annotation_names names ty) eps

  let rec pattern_annotation_names names { Sugared.it = pat; _ } =
    match pat with
    | Sugared.PAnnotated (pat, ty) ->
        ty_annotation_names (pattern_annotation_names names pat) ty
    | Sugared.PAs (pat, _)
    | Sugared.PVariant (_, Some pat)
    | Sugared.PSucc (pat, _) ->
        pattern_annotation_names names pat
    | Sugared.PTuple pats -> List.fold_left pattern_annotation_names names pats
    | Sugared.PVar _
    | Sugared.PVariant (_, None)
    | Sugared.PConst _ | Sugared.PNonbinding ->
        names

  let rec term_annotation_names names { Sugared.it = term; _ } =
    let terms = List.fold_left term_annotation_names in
    let abstractions = List.fold_left abstraction_annotation_names in
    match term with
    | Sugared.Var _ | Sugared.Const _ | Sugared.Delay _
    | Sugared.Variant (_, None) ->
        names
    | Sugared.Annotated (t, ty) ->
        ty_annotation_names (term_annotation_names names t) ty
    | Sugared.AnnotatedComp (t, ty, eps) ->
        comp_ty_annotation_names
          (term_annotation_names names t)
          (Sugared.CompTy (ty, eps))
    | Sugared.Variant (_, Some t)
    | Sugared.GenBox (_, t)
    | Sugared.GenUnbox t
    | Sugared.Perform (_, t) ->
        term_annotation_names names t
    | Sugared.Tuple ts -> terms names ts
    | Sugared.Apply (t1, t2)
    | Sugared.LetRec (_, t1, t2)
    | Sugared.Handle (t1, t2)
    | Sugared.Continue (t1, t2) ->
        terms names [ t1; t2 ]
    | Sugared.Conditional (t, t1, t2) -> terms names [ t; t1; t2 ]
    | Sugared.Let (pat, t1, t2) ->
        terms (pattern_annotation_names names pat) [ t1; t2 ]
    | Sugared.Lambda abs | Sugared.PureLambda abs ->
        abstraction_annotation_names names abs
    | Sugared.Function cases -> abstractions names cases
    | Sugared.Match (t, cases) ->
        abstractions (term_annotation_names names t) cases
    | Sugared.Box (_, t, abs) | Sugared.Unbox (t, abs) ->
        abstraction_annotation_names (term_annotation_names names t) abs
    | Sugared.Handler (ret_case, op_cases) ->
        abstractions
          (abstraction_annotation_names names ret_case)
          (List.map snd op_cases)

  and abstraction_annotation_names names (pat, t) =
    term_annotation_names (pattern_annotation_names names pat) t

  (* [state] within a definition whose annotations have the type and grade
     variables [names], each a fresh variable of its sort. *)
  let in_definition state names =
    let fresh fresh_var set =
      StringSet.fold
        (fun p params -> StringMap.add p (fresh_var p) params)
        set StringMap.empty
    in
    let grade_params =
      {
        effects =
          fresh (fun _ -> Untyped.Eps_var.fresh_indexed ()) names.effects;
        resources =
          fresh
            (fun _ -> Untyped.Rho_var.fresh_indexed ())
            (StringSet.diff names.grades names.effects);
      }
    in
    {
      state with
      ty_params = fresh Untyped.TyParamModule.fresh names.tys;
      grade_params = Some grade_params;
    }

  let outside_definition state =
    { state with ty_params = StringMap.empty; grade_params = None }

  let misplaced_grade_param ~loc p =
    Error.syntax ~loc
      "Grade variable `'%s` is not allowed here; grade variables may only \
       occur in type annotations"
      p

  (* The grade constants of grade literals, at their locations, where grade
     variables are not allowed. *)
  let rho_const { Sugared.it; at } =
    match it with
    | Sugared.GradeLit c -> Untyped.RhoConst (c, Some at)
    | Sugared.GradeParam p -> misplaced_grade_param ~loc:at p

  let eps_const { Sugared.it; at } =
    match it with
    | Sugared.GradeLit c -> Untyped.EpsConst (c, Some at)
    | Sugared.GradeParam p -> misplaced_grade_param ~loc:at p

  (* The grades of an annotation: a variable of an effect in a resource
     position stands for its image. *)
  let rho_grade state ({ Sugared.it; at } as rho) =
    match (it, state.grade_params) with
    | Sugared.GradeLit _, _ -> rho_const rho
    | Sugared.GradeParam p, None -> misplaced_grade_param ~loc:at p
    | Sugared.GradeParam p, Some params -> (
        match StringMap.find_opt p params.effects with
        | Some e -> Untyped.RhoImage e
        | None -> Untyped.RhoVar (StringMap.find p params.resources))

  let eps_grade state ({ Sugared.it; at } as eps) =
    match (it, state.grade_params) with
    | Sugared.GradeLit _, _ -> eps_const eps
    | Sugared.GradeParam p, None -> misplaced_grade_param ~loc:at p
    | Sugared.GradeParam p, Some params ->
        Untyped.EpsVar (StringMap.find p params.effects)

  (* ------------------------------------------------------------------ *)
  (* Types, patterns and terms                                           *)
  (* ------------------------------------------------------------------ *)

  let rec desugar_ty state { Sugared.it = plain_ty; at = loc } =
    desugar_plain_ty ~loc state plain_ty

  and desugar_plain_ty ~loc state = function
    | Sugared.TyApply (ty_name, tys) ->
        let ty_name' = lookup_ty_name ~loc state ty_name in
        let tys' = List.map (desugar_ty state) tys in
        Untyped.TyApply (ty_name', tys')
    | Sugared.TyParam ty_param ->
        let ty_param' = lookup_ty_param ~loc state ty_param in
        Untyped.TyParam ty_param'
    | Sugared.TyArrow (ty1, CompTy (ty2, eps)) ->
        let ty1' = desugar_ty state ty1 in
        let ty2' = desugar_ty state ty2 in
        Untyped.TyArrow (ty1', CompTy (ty2', eps_grade state eps))
    | Sugared.TyTuple tys ->
        let tys' = List.map (desugar_ty state) tys in
        Untyped.TyTuple tys'
    | Sugared.TyConst c -> Untyped.TyConst c
    | Sugared.TyBox (rho, ty) ->
        let rho' = rho_grade state rho in
        let ty' = desugar_ty state ty in
        Untyped.TyBox (rho', ty')
    | Sugared.TyHandler (CompTy (ty1, eps1), CompTy (ty2, eps2)) ->
        let ty1' = desugar_ty state ty1 in
        let eps1' = eps_grade state eps1 in
        let ty2' = desugar_ty state ty2 in
        let eps2' = eps_grade state eps2 in
        Untyped.TyHandler (CompTy (ty1', eps1'), CompTy (ty2', eps2'))

  let rec desugar_pattern state vars { Sugared.it = pat; at = loc } =
    let vars, pat' = desugar_plain_pattern ~loc state vars pat in
    (vars, Untyped.located loc pat')

  and desugar_plain_pattern ~loc state vars = function
    | Sugared.PVar x ->
        let x' = Untyped.Variable.fresh x in
        (StringMap.singleton x x', Untyped.PVar x')
    | Sugared.PAnnotated (pat, ty) ->
        let vars, pat' = desugar_pattern state vars pat
        and ty' = desugar_ty state ty in
        (vars, Untyped.PAnnotated (pat', ty'))
    | Sugared.PAs (pat, x) ->
        let vars, pat' = desugar_pattern state vars pat in
        let x' = Untyped.Variable.fresh x in
        (add_unique ~loc "Variable" x x' vars, Untyped.PAs (pat', x'))
    | Sugared.PTuple ps ->
        let aux p (vars, ps') =
          let vars', p' = desugar_pattern state vars p in
          (StringMap.fold (add_unique ~loc "Variable") vars' vars, p' :: ps')
        in
        let vars, ps' = List.fold_right aux ps (StringMap.empty, []) in
        (vars, Untyped.PTuple ps')
    | Sugared.PVariant (lbl, None) ->
        let lbl' = lookup_label ~loc state lbl in
        (StringMap.empty, Untyped.PVariant (lbl', None))
    | Sugared.PVariant (lbl, Some pat) ->
        let lbl' = lookup_label ~loc state lbl in
        let vars, pat' = desugar_pattern state vars pat in
        (vars, Untyped.PVariant (lbl', Some pat'))
    | Sugared.PConst c -> (StringMap.empty, Untyped.PConst c)
    | Sugared.PSucc (pat, k) ->
        let vars, pat' = desugar_pattern state vars pat in
        (vars, Untyped.PSucc (pat', k))
    | Sugared.PNonbinding -> (StringMap.empty, Untyped.PNonbinding)

  let add_fresh_variables state vars =
    let aux x x' variables = StringMap.add x x' variables in
    let variables' = StringMap.fold aux vars state.variables in
    { state with variables = variables' }

  let rec desugar_expression state { Sugared.it = term; at = loc } =
    let binds, expr = desugar_plain_expression ~loc state term in
    (binds, Untyped.located loc expr)

  and desugar_plain_expression ~loc state = function
    | Sugared.Var x ->
        let x' = lookup_variable ~loc state x in
        ([], Untyped.Var x')
    | Sugared.Const k -> ([], Untyped.Const k)
    | Sugared.Annotated (term, ty) ->
        let binds, expr = desugar_expression state term in
        let ty' = desugar_ty state ty in
        (binds, Untyped.Annotated (expr, ty'))
    | Sugared.Lambda a ->
        let a' = desugar_abstraction state a in
        ([], Untyped.Lambda a')
    | Sugared.PureLambda a ->
        let a' = desugar_abstraction state a in
        ([], Untyped.PureLambda a')
    | Sugared.Function cases ->
        (* Neither the argument nor the match it is scrutinised by is written
           anywhere, so both are reported at the [function] itself. *)
        let x = Untyped.Variable.fresh_synthetic "arg" in
        let cases' = List.map (desugar_abstraction state) cases in
        ( [],
          Untyped.Lambda
            ( Untyped.located loc (Untyped.PVar x),
              Untyped.located loc
                (Untyped.Match (Untyped.located loc (Untyped.Var x), cases')) )
        )
    | Sugared.Tuple ts ->
        let binds, es = desugar_expressions state ts in
        (binds, Untyped.Tuple es)
    | Sugared.Variant (lbl, None) ->
        let lbl' = lookup_label ~loc state lbl in
        ([], Untyped.Variant (lbl', None))
    | Sugared.Variant (lbl, Some term) ->
        let lbl' = lookup_label ~loc state lbl in
        let binds, expr = desugar_expression state term in
        (binds, Untyped.Variant (lbl', Some expr))
    | Sugared.Handler (ret_case, op_cases) ->
        let ret_case' = desugar_abstraction state ret_case in
        let op_cases' =
          List.fold_left
            (fun op_cases'' (op, op_case) ->
              let op' = lookup_operation ~loc state op in
              match Untyped.OpNameMap.find_opt op' op_cases'' with
              | None ->
                  Untyped.OpNameMap.add op'
                    (desugar_abstraction state op_case)
                    op_cases''
              | Some _ ->
                  Error.syntax ~loc "Multiple cases for the same operation")
            Untyped.OpNameMap.empty op_cases
        in
        ([], Untyped.Handler (ret_case', op_cases'))
    | ( Sugared.Apply _ | Sugared.Match _ | Sugared.Let _ | Sugared.LetRec _
      | Sugared.Delay _ | Sugared.Box _ | Sugared.GenBox _ | Sugared.Unbox _
      | Sugared.GenUnbox _ | Sugared.Conditional _ | Sugared.Perform _
      | Sugared.Handle _ | Sugared.Continue _ | Sugared.AnnotatedComp _ ) as
      term ->
        let x = Untyped.Variable.fresh_synthetic "b" in
        let comp = desugar_computation state { Sugared.it = term; at = loc } in
        let hoist = (Untyped.located loc (Untyped.PVar x), comp) in
        ([ hoist ], Untyped.Var x)

  and desugar_computation state { Sugared.it = term; at = loc } =
    let binds, comp = desugar_plain_computation ~loc state term in
    (* The [do] binds that hoist the subterms of an expression position are
       invented here, so they are reported at the term that needed them. *)
    List.fold_right
      (fun (p, c1) c2 -> Untyped.located loc (Untyped.Do (c1, (p, c2))))
      binds (Untyped.located loc comp)

  and desugar_plain_computation ~loc state =
    let if_then_else e c1 c2 =
      let true_p = Untyped.located loc (Untyped.PConst Const.of_true) in
      let false_p = Untyped.located loc (Untyped.PConst Const.of_false) in
      Untyped.Match (e, [ (true_p, c1); (false_p, c2) ])
    in
    function
    | Sugared.Apply
        ({ it = Sugared.Var "(&&)"; _ }, { it = Sugared.Tuple [ t1; t2 ]; _ })
      ->
        let binds1, e1 = desugar_expression state t1 in
        let c1 = desugar_computation state t2 in
        let c2 =
          Untyped.located loc
            (Untyped.Return
               (Untyped.located loc (Untyped.Const (Const.Boolean false))))
        in
        (binds1, if_then_else e1 c1 c2)
    | Sugared.Apply
        ({ it = Sugared.Var "(||)"; _ }, { it = Sugared.Tuple [ t1; t2 ]; _ })
      ->
        let binds1, e1 = desugar_expression state t1 in
        let c1 =
          Untyped.located loc
            (Untyped.Return
               (Untyped.located loc (Untyped.Const (Const.Boolean true))))
        in
        let c2 = desugar_computation state t2 in
        (binds1, if_then_else e1 c1 c2)
    | Sugared.Apply (t1, t2) ->
        let binds1, e1 = desugar_expression state t1 in
        let binds2, e2 = desugar_expression state t2 in
        (binds1 @ binds2, Untyped.Apply (e1, e2))
    | Sugared.Match (t, cs) ->
        let binds, e = desugar_expression state t in
        let cs' = List.map (desugar_abstraction state) cs in
        (binds, Untyped.Match (e, cs'))
    | Sugared.Conditional (t, t1, t2) ->
        let binds, e = desugar_expression state t in
        let c1 = desugar_computation state t1 in
        let c2 = desugar_computation state t2 in
        (binds, if_then_else e c1 c2)
    | Sugared.Let (pat, term1, term2) ->
        let c1 = desugar_computation state term1 in
        let c2 = desugar_abstraction state (pat, term2) in
        ([], Untyped.Do (c1, c2))
    | Sugared.LetRec (x, term1, term2) ->
        let state', f, expr1 = desugar_let_rec_def state (x, term1) in
        let c = desugar_computation state' term2 in
        ( [],
          Untyped.Do
            ( Untyped.located loc (Untyped.Return expr1),
              (Untyped.located loc (Untyped.PVar f), c) ) )
    | Sugared.Delay q ->
        ( [],
          Untyped.Delay
            ( q,
              Untyped.located loc
                (Untyped.Return (Untyped.located loc (Untyped.Tuple []))) ) )
    | Sugared.Box (rho, e, (p, c)) ->
        let binds, e' = desugar_expression state e in
        let abs = desugar_abstraction state (p, c) in
        (binds, Untyped.Box (rho_const rho, e', abs))
    | Sugared.GenBox (rho, e) ->
        let binds, e' = desugar_expression state e in
        let var = Untyped.Variable.fresh_synthetic "box_var" in
        ( binds,
          Untyped.Box
            ( rho_const rho,
              e',
              ( Untyped.located loc (Untyped.PVar var),
                Untyped.located loc
                  (Untyped.Return (Untyped.located loc (Untyped.Var var))) ) )
        )
    | Sugared.Unbox (e, (p, c)) ->
        let binds, e' = desugar_expression state e in
        let abs = desugar_abstraction state (p, c) in
        (binds, Untyped.Unbox (e', abs))
    | Sugared.GenUnbox e ->
        let binds, e' = desugar_expression state e in
        let var = Untyped.Variable.fresh_synthetic "unbox_var" in
        ( binds,
          Untyped.Unbox
            ( e',
              ( Untyped.located loc (Untyped.PVar var),
                Untyped.located loc
                  (Untyped.Return (Untyped.located loc (Untyped.Var var))) ) )
        )
    | Sugared.Perform (op, e) ->
        let operation = lookup_operation ~loc state op in
        let binds, expr = desugar_expression state e in
        let var = Untyped.Variable.fresh_synthetic "op_var" in
        ( binds,
          Untyped.Perform
            ( operation,
              expr,
              ( Untyped.located loc (Untyped.PVar var),
                Untyped.located loc
                  (Untyped.Return (Untyped.located loc (Untyped.Var var))) ) )
        )
    | Sugared.Handle (c, h) ->
        let c' = desugar_computation state c in
        let binds, h' = desugar_expression state h in
        (binds, Untyped.Handle (c', h'))
    | Sugared.Continue (k, e) ->
        let binds, k' = desugar_expression state k in
        let binds', e' = desugar_expression state e in
        let var = Untyped.Variable.fresh_synthetic "unbox_var" in
        ( binds @ binds',
          Untyped.Unbox
            ( k',
              ( Untyped.located loc (Untyped.PVar var),
                Untyped.located loc
                  (Untyped.Apply (Untyped.located loc (Untyped.Var var), e')) )
            ) )
    (* A computation annotated with its type has no node of its own: it is the
       immediate application of a thunk annotated with the arrow type
       [unit -> ty # eps], which the typechecker already knows how to check
       and which the interpreter reduces in one step. *)
    | Sugared.AnnotatedComp (term, ty, eps) ->
        let comp = desugar_computation state term in
        let thunk_ty =
          Untyped.TyArrow
            ( Untyped.TyTuple [],
              CompTy (desugar_ty state ty, eps_grade state eps) )
        in
        let thunk =
          Untyped.located loc
            (Untyped.Annotated
               ( Untyped.located loc
                   (Untyped.Lambda
                      (Untyped.located loc (Untyped.PTuple []), comp)),
                 thunk_ty ))
        in
        ([], Untyped.Apply (thunk, Untyped.located loc (Untyped.Tuple [])))
    (* The remaining cases are expressions, which we list explicitly to catch any
     future changeSugared. *)
    | ( Sugared.Var _ | Sugared.Const _ | Sugared.Annotated _ | Sugared.Tuple _
      | Sugared.Variant _ | Sugared.Lambda _ | Sugared.PureLambda _
      | Sugared.Function _ | Sugared.Handler _ ) as term ->
        let binds, expr = desugar_expression state { it = term; at = loc } in
        (binds, Untyped.Return expr)

  and desugar_abstraction state (pat, term) =
    let vars, pat' = desugar_pattern state StringMap.empty pat in
    let state' = add_fresh_variables state vars in
    let comp = desugar_computation state' term in
    (pat', comp)

  and desugar_let_rec_def state (f, { it = exp; at = loc }) =
    let f' = Untyped.Variable.fresh f in
    let state' = add_fresh_variables state (StringMap.singleton f f') in
    let abs' =
      match exp with
      | Sugared.PureLambda a -> desugar_abstraction state' a
      | Sugared.Function cs ->
          let x = Untyped.Variable.fresh_synthetic "rf" in
          let cs = List.map (desugar_abstraction state') cs in
          let new_match =
            Untyped.located loc
              (Untyped.Match (Untyped.located loc (Untyped.Var x), cs))
          in
          (Untyped.located loc (Untyped.PVar x), new_match)
      | _ ->
          Error.syntax ~loc
            "This kind of expression is not allowed in a recursive definition"
    in
    let expr = Untyped.located loc (Untyped.RecLambda (f', abs')) in
    (state', f', expr)

  and desugar_expressions state = function
    | [] -> ([], [])
    | t :: ts ->
        let binds, e = desugar_expression state t in
        let ws, es = desugar_expressions state ts in
        (binds @ ws, e :: es)

  let desugar_pure_expression state term =
    let binds, expr = desugar_expression state term in
    match binds with
    | [] -> expr
    | _ -> Error.syntax ~loc:term.at "Only pure expressions are allowed"

  let add_label ~loc state label label' =
    let labels' = add_unique ~loc "Label" label label' state.labels in
    { state with labels = labels' }

  let add_fresh_ty_names ~loc state vars =
    let aux ty_names (x, x') = add_unique ~loc "Type" x x' ty_names in
    let ty_names' = List.fold_left aux state.ty_names vars in
    { state with ty_names = ty_names' }

  let add_fresh_ty_params state vars =
    let aux ty_params (x, x') = StringMap.add x x' ty_params in
    let ty_params' = List.fold_left aux state.ty_params vars in
    { state with ty_params = ty_params' }

  let add_operation ~loc state operation operation' =
    let operations' =
      add_unique ~loc "Operation" operation operation' state.operations
    in
    { state with operations = operations' }

  let desugar_ty_def ~loc state = function
    | Sugared.TyInline ty -> (state, Untyped.TyInline (desugar_ty state ty))
    | Sugared.TySum variants ->
        let aux state (label, ty) =
          let label' = Untyped.Label.fresh label in
          let ty' = Option.map (desugar_ty state) ty in
          let state' = add_label ~loc state label label' in
          (state', (label', ty'))
        in
        let state', variants' = List.fold_map aux state variants in
        (state', Untyped.TySum variants')

  let desugar_command state { Sugared.it = cmd; at = loc } =
    let state', cmd' =
      match cmd with
      | Sugared.TyDef (eternality, defs) ->
          let def_name (_, ty_name, _) =
            let ty_name' = Untyped.TyName.fresh ty_name in
            (ty_name, ty_name')
          in
          let new_names = List.map def_name defs in
          let state' = add_fresh_ty_names ~loc state new_names in
          let aux (params, _, ty_def) (_, ty_name') (state', defs) =
            let params' =
              List.map (fun a -> (a, Untyped.TyParamModule.fresh a)) params
            in
            let state'' = add_fresh_ty_params state' params' in
            let state''', ty_def' = desugar_ty_def ~loc state'' ty_def in
            ( { state''' with ty_params = state'.ty_params },
              (List.map snd params', ty_name', ty_def') :: defs )
          in
          let state'', defs' =
            List.fold_right2 aux defs new_names (state', [])
          in
          (state'', Untyped.TyDef (eternality, defs'))
      | Sugared.OpSig (op_name, ty1_name, ty2_name, eps_val, bounds) ->
          let operation = Untyped.OpName.fresh op_name in
          let ty1 = desugar_ty state ty1_name in
          let ty2 = desugar_ty state ty2_name in
          let eps = eps_const eps_val in
          let state' = add_operation ~loc state op_name operation in
          (state', Untyped.OpSig (operation, ty1, ty2, eps, bounds))
      | Sugared.OpDefault (op_name, abs) ->
          let operation = lookup_operation ~loc state op_name in
          let scoped =
            in_definition state
              (abstraction_annotation_names no_annotation_names abs)
          in
          (state, Untyped.OpDefault (operation, desugar_abstraction scoped abs))
      | Sugared.TopLet (x, term) ->
          let x' = Untyped.Variable.fresh x in
          let state' = add_fresh_variables state (StringMap.singleton x x') in
          let scoped =
            in_definition state'
              (term_annotation_names no_annotation_names term)
          in
          let expr = desugar_pure_expression scoped term in
          (state', Untyped.TopLet (x', expr))
      | Sugared.TopDo term ->
          let scoped =
            in_definition state (term_annotation_names no_annotation_names term)
          in
          let comp = desugar_computation scoped term in
          (state, Untyped.TopDo comp)
      | Sugared.TopLetRec (f, term) ->
          let scoped =
            in_definition state (term_annotation_names no_annotation_names term)
          in
          let state', f, expr = desugar_let_rec_def scoped (f, term) in
          (outside_definition state', Untyped.TopLet (f, expr))
    in
    (state', { Untyped.it = cmd'; at = loc })

  let load_primitive state x prim =
    let str = Language.Primitives.primitive_name prim in
    add_fresh_variables state (StringMap.singleton str x)
end
