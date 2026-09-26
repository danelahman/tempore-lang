(* Constraint generation in checking mode. *)

module Ast = Language.Ast
module Const = Language.Const
module Location = Utils.Location
module Error = Utils.Error
module StringMap = Utils.StringMap
module LabelMap = Map.Make (Ast.Label)

module Make (C : Constraint.S) = struct
  module X = C.X
  module GS = X.GS
  module Rho = X.Rho
  module Eps = X.Eps
  module Primitive_schemes = PrimitiveSchemes.Make (C)

  type rho = C.rho
  type eps = C.eps
  type ty = C.ty
  type comp_ty = C.comp_ty
  type reason = C.reason
  type program_rho = GS.R.t Ast.rho
  type program_eps = GS.E.t Ast.eps
  type program_ty = (program_rho, program_eps) Ast.ty
  type expression = (program_rho, program_eps) Ast.expression
  type computation = (program_rho, program_eps) Ast.computation
  type abstraction = (program_rho, program_eps) Ast.abstraction

  (* ------------------------------------------------------------------ *)
  (* Program syntax                                                      *)
  (* ------------------------------------------------------------------ *)

  let rec open_rho = function
    | Ast.RhoConst c -> Rho.const c
    | Ast.RhoAdd (rho, rho') -> Rho.mul (open_rho rho) (open_rho rho')
    | Ast.RhoParam _ -> invalid_arg "open_rho: a grade parameter in a program"

  let rec open_eps = function
    | Ast.EpsConst c -> Eps.const c
    | Ast.EpsAdd (eps, eps') -> Eps.mul (open_eps eps) (open_eps eps')
    | Ast.EpsParam _ | Ast.EpsRigid _ ->
        invalid_arg "open_eps: a grade parameter in a program"

  let open_ty ty = Ast.map_ty ~on_rho:open_rho ~on_eps:open_eps ty

  let open_ty_def = function
    | Ast.TySum variants ->
        Ast.TySum
          (List.map (fun (lbl, ty) -> (lbl, Option.map open_ty ty)) variants)
    | Ast.TyInline ty -> Ast.TyInline (open_ty ty)

  (* ------------------------------------------------------------------ *)
  (* Environments                                                        *)
  (* ------------------------------------------------------------------ *)

  type ty_definition = {
    params : Ast.ty_param list;
    definition : (rho, eps) Ast.ty_def;
  }

  type op_signature = {
    param : ty;
    arity : ty;
    op_grade : eps;
    signature_at : Location.t;
  }

  (* An entry of the context: a binding [x : A] or a lock [⟨ρ⟩]. *)
  type entry =
    | Bound of Ast.variable * ty * Location.t
    | Lock of rho Reason.elapsed

  type global = { scheme : C.scheme; defined_at : Location.t option }

  type env = {
    context : entry list;  (** newest first *)
    globals : global Ast.VariableMap.t;
    type_definitions : ty_definition Ast.TyNameMap.t;
    constructors : Ast.ty_name LabelMap.t;
    noneternal : Ast.TyNameSet.t;
    op_signatures : op_signature Ast.OpNameMap.t;
    op_bounds : (int * int) StringMap.t;
    op_defaults : Ast.OpNameSet.t;
  }

  let add_type_definition name def env =
    let constructors =
      match def.definition with
      | Ast.TyInline _ -> env.constructors
      | Ast.TySum variants ->
          List.fold_left
            (fun cs (lbl, _) -> LabelMap.add lbl name cs)
            env.constructors variants
    in
    {
      env with
      type_definitions = Ast.TyNameMap.add name def env.type_definitions;
      constructors;
    }

  let initial_env =
    let a = Ast.TyParamModule.fresh "list" in
    let alias ty = { params = []; definition = Ast.TyInline ty } in
    let list_def =
      Ast.TySum
        [
          (Ast.nil_label, None);
          ( Ast.cons_label,
            Some
              (Ast.TyTuple
                 [
                   Ast.TyParam a;
                   Ast.TyApply (Ast.list_ty_name, [ Ast.TyParam a ]);
                 ]) );
        ]
    in
    {
      context = [];
      globals = Ast.VariableMap.empty;
      type_definitions = Ast.TyNameMap.empty;
      constructors = LabelMap.empty;
      noneternal = Ast.TyNameSet.empty;
      op_signatures = Ast.OpNameMap.empty;
      op_bounds = StringMap.empty;
      op_defaults = Ast.OpNameSet.empty;
    }
    |> add_type_definition Ast.bool_ty_name
         (alias (Ast.TyConst Const.BooleanTy))
    |> add_type_definition Ast.int_ty_name (alias (Ast.TyConst Const.IntegerTy))
    |> add_type_definition Ast.unit_ty_name (alias (Ast.TyTuple []))
    |> add_type_definition Ast.string_ty_name
         (alias (Ast.TyConst Const.StringTy))
    |> add_type_definition Ast.float_ty_name (alias (Ast.TyConst Const.FloatTy))
    |> add_type_definition Ast.empty_ty_name
         { params = []; definition = Ast.TySum [] }
    |> add_type_definition Ast.list_ty_name
         { params = [ a ]; definition = list_def }

  let find_type_definition env name =
    Ast.TyNameMap.find_opt name env.type_definitions

  let is_noneternal env name = Ast.TyNameSet.mem name env.noneternal
  let find_op_signature env op = Ast.OpNameMap.find_opt op env.op_signatures
  let op_bounds env = env.op_bounds

  (* Every type application in a type has as many arguments as its type has
     parameters. *)
  let rec check_ty ~loc env = function
    | Ast.TyConst _ | Ast.TyParam _ -> ()
    | Ast.TyApply (name, tys) ->
        let expected =
          match find_type_definition env name with
          | Some def -> List.length def.params
          | None -> List.length tys
        and actual = List.length tys in
        if expected <> actual then
          Error.typing ~loc "Type `%t` expects %d argument%s but is given %d"
            (Ast.TyName.print name) expected
            (if expected = 1 then "" else "s")
            actual
        else List.iter (check_ty ~loc env) tys
    | Ast.TyArrow (ty, cty) ->
        check_ty ~loc env ty;
        check_comp_ty ~loc env cty
    | Ast.TyTuple tys -> List.iter (check_ty ~loc env) tys
    | Ast.TyBox (_, ty) -> check_ty ~loc env ty
    | Ast.TyHandler (cty, cty') ->
        check_comp_ty ~loc env cty;
        check_comp_ty ~loc env cty'

  and check_comp_ty ~loc env (Ast.CompTy (ty, _)) = check_ty ~loc env ty

  let check_ty_def ~loc env = function
    | Ast.TySum variants ->
        List.iter (fun (_, ty) -> Option.iter (check_ty ~loc env) ty) variants
    | Ast.TyInline ty -> check_ty ~loc env ty

  (* An alias is unfolded before its eternality is decided, so it cannot be
     declared [noneternal]. *)
  let check_noneternal_definable ~loc (_, name, def) =
    match def with
    | Ast.TySum _ -> ()
    | Ast.TyInline _ ->
        let name = Ast.TyName.string_of name in
        Error.typing ~loc
          "type `%s` is an alias and cannot be declared noneternal; wrap it in \
           a constructor, as in `noneternal type %s = %s of ...`"
          name name
          (String.capitalize_ascii name)

  let add_type_definitions ~loc env (eternality, defs) =
    (match eternality with
    | Ast.Derived -> ()
    | Ast.Noneternal -> List.iter (check_noneternal_definable ~loc) defs);
    let env' =
      List.fold_left
        (fun env (params, name, def) ->
          let env =
            add_type_definition name
              { params; definition = open_ty_def def }
              env
          in
          match eternality with
          | Ast.Derived -> env
          | Ast.Noneternal ->
              { env with noneternal = Ast.TyNameSet.add name env.noneternal })
        env defs
    in
    List.iter (fun (_, _, def) -> check_ty_def ~loc env' (open_ty_def def)) defs;
    env'

  (* The runtime bounds of the operations, extended by those of [op_name],
     declared or implied by its grade. *)
  let checked_op_bounds ~loc env op_name grade bounds =
    let event_bounds ev =
      match StringMap.find_opt ev env.op_bounds with
      | Some bounds -> bounds
      | None ->
          Error.typing ~loc "unknown event `%s` in the grade of operation `%s`"
            ev op_name
    in
    match (GS.E.needs_op_bounds, grade, bounds) with
    | false, _, Some _ ->
        Error.typing ~loc
          "runtime bounds are only used by the timed-trace grading monoids; \
           under `%s` the operation grade already carries them"
          GS.E.name
    | false, _, None -> env.op_bounds
    | true, (Ast.EpsParam _ | Ast.EpsRigid _ | Ast.EpsAdd _), _ ->
        Error.typing ~loc
          "the grade of operation `%s` must be a literal under the `%s` \
           grading monoid"
          op_name GS.E.name
    | true, Ast.EpsConst c, _ when GS.E.is_atomic op_name c -> (
        match bounds with
        | None ->
            Error.typing ~loc
              "atomic operation `%s` needs runtime bounds `within (lo, hi)` \
               under the `%s` grading monoid"
              op_name GS.E.name
        | Some (lo, hi) when lo > hi ->
            Error.typing ~loc
              "the runtime bounds of operation `%s` must satisfy `lo <= hi`"
              op_name
        | Some (_, hi) when hi < 1 ->
            Error.typing ~loc
              "the upper runtime bound of operation `%s` must be at least 1"
              op_name
        | Some bounds -> StringMap.add op_name bounds env.op_bounds)
    | true, Ast.EpsConst c, Some _ ->
        Error.typing ~loc
          "operation `%s` is compound, so its runtime bounds follow from its \
           grade `%s` and must not be declared"
          op_name (GS.E.show c)
    | true, Ast.EpsConst c, None -> (
        if List.mem op_name (GS.E.events c) then
          Error.typing ~loc
            "compound operation `%s` may not name itself in its grade `%s`"
            op_name (GS.E.show c);
        match GS.E.implied_bounds event_bounds c with
        | Some bounds -> StringMap.add op_name bounds env.op_bounds
        | None -> env.op_bounds)

  let add_operation_signature ~loc env (op, param, arity, grade, bounds) =
    let op_name = Ast.OpName.string_of op in
    let op_bounds = checked_op_bounds ~loc env op_name grade bounds in
    let signature =
      {
        param = open_ty param;
        arity = open_ty arity;
        op_grade = open_eps grade;
        signature_at = loc;
      }
    in
    {
      env with
      op_signatures = Ast.OpNameMap.add op signature env.op_signatures;
      op_bounds;
    }

  let add_global env x ~defined_at scheme =
    {
      env with
      globals = Ast.VariableMap.add x { scheme; defined_at } env.globals;
    }

  let load_primitive env x prim =
    add_global env x ~defined_at:None (Primitive_schemes.scheme prim)

  let add_operation_default env op =
    { env with op_defaults = Ast.OpNameSet.add op env.op_defaults }

  let bind env x ty ~bound_at =
    { env with context = Bound (x, ty, bound_at) :: env.context }

  let lock env elapsed = { env with context = Lock elapsed :: env.context }

  (* A variable in the environment: bound in the context, with the locks since
     its binding, oldest first, or a top-level definition or primitive. *)
  type lookup =
    | Local of {
        ty : ty;
        bound_at : Location.t;
        elapsed : rho Reason.elapsed list;
      }
    | Global of global

  let lookup ~loc env x =
    let rec find elapsed = function
      | Bound (y, ty, bound_at) :: _ when Ast.Variable.compare x y = 0 ->
          Local { ty; bound_at; elapsed }
      | Bound _ :: context -> find elapsed context
      | Lock e :: context -> find (e :: elapsed) context
      | [] -> (
          match Ast.VariableMap.find_opt x env.globals with
          | Some global -> Global global
          | None ->
              Error.typing ~loc "Unknown variable `%s`"
                (Ast.Variable.string_of x))
    in
    find [] env.context

  (* The locks of the whole context, oldest first. *)
  let all_locks env =
    List.fold_left
      (fun elapsed -> function Lock e -> e :: elapsed | Bound _ -> elapsed)
      [] env.context

  (* The product of the grades of [elapsed], oldest first, the unit for none. *)
  let elapsed_grade = function
    | [] -> Rho.unit
    | (e : rho Reason.elapsed) :: rest ->
        List.fold_left
          (fun rho (e : rho Reason.elapsed) -> Rho.mul rho e.grade)
          e.grade rest

  (* The constructor [lbl]: its type's name and parameters, and its argument
     type. *)
  let find_constructor ~loc env lbl =
    let unknown () =
      Error.typing ~loc "Unknown constructor `%s`" (Ast.Label.string_of lbl)
    in
    match LabelMap.find_opt lbl env.constructors with
    | None -> unknown ()
    | Some name -> (
        match find_type_definition env name with
        | Some { params; definition = Ast.TySum variants } -> (
            match List.assoc_opt lbl variants with
            | Some arg -> (name, params, arg)
            | None -> unknown ())
        | Some { definition = Ast.TyInline _; _ } | None -> unknown ())

  (* ------------------------------------------------------------------ *)
  (* Fresh unknowns                                                      *)
  (* ------------------------------------------------------------------ *)

  type 'a expected = { bound : 'a; because : reason }

  let expect bound because = { bound; because }

  (* [exists_ty k] is [∃α. k α]; likewise for the other sorts. *)
  let exists_ty k =
    let a = Ast.TyParamModule.fresh "ty" in
    C.exists { C.no_vars with ty_vars = [ a ] } (k (Ast.TyParam a))

  let exists_rho k =
    let r = X.Rho_var.fresh_indexed () in
    C.exists { C.no_vars with rho_vars = [ r ] } (k (Rho.var r))

  let exists_eps k =
    let e = X.Eps_var.fresh_indexed () in
    C.exists { C.no_vars with eps_vars = [ e ] } (k (Eps.var e))

  (* [exists_tys n k] is [∃α₁ … αₙ. k [α₁; …; αₙ]]. *)
  let exists_tys n k =
    let vars = List.init n (fun _ -> Ast.TyParamModule.fresh "ty") in
    C.exists
      { C.no_vars with ty_vars = vars }
      (k (List.map (fun a -> Ast.TyParam a) vars))

  (* The substitution sending the parameters [params] to the types [args]. *)
  let instance_subst params args =
    {
      C.empty_subst with
      ty_subst =
        List.fold_left2
          (fun m a arg -> Ast.TyParamMap.add a arg m)
          Ast.TyParamMap.empty params args;
    }

  (* [exists_instance name params k] is [∃β̄. k (T β̄) σ] for the type [T] of
     name [name] and parameters [params], [σ] sending [params] to [β̄]; type
     arguments are invariant, so an instance is determined by [β̄]. *)
  let exists_instance name params k =
    exists_tys (List.length params) (fun args ->
        k (Ast.TyApply (name, args)) (instance_subst params args))

  (* ------------------------------------------------------------------ *)
  (* Atoms against an expected bound                                     *)
  (* ------------------------------------------------------------------ *)

  (* [sub_expected at ty expected] is [ty <: expected], the term at [at] being
     the subject. *)
  let sub_expected at ty expected =
    C.Sub (Reason.against at expected.because, ty, expected.bound)

  let eq_expected at ty expected =
    C.equal_ty (Reason.against at expected.because) ty expected.bound

  let leq_expected at eps expected =
    C.Eps_leq (Reason.against at expected.because, eps, expected.bound)

  (* ------------------------------------------------------------------ *)
  (* Patterns                                                            *)
  (* ------------------------------------------------------------------ *)

  (* A pattern matched against a value of the expected type: the unknowns it
     introduces, the atoms relating the expected type to its shape, and the
     variables it binds. *)
  type pattern_result = {
    vars : C.vars;
    constr : C.t;
    bindings : (Ast.variable * ty * Location.t) list;
  }

  let no_pattern = { vars = C.no_vars; constr = C.True; bindings = [] }

  let union_patterns p p' =
    {
      vars = C.union_vars p.vars p'.vars;
      constr = C.conj p.constr p'.constr;
      bindings = p.bindings @ p'.bindings;
    }

  let fresh_ty_vars n = List.init n (fun _ -> Ast.TyParamModule.fresh "ty")

  let arity_mismatch ~loc lbl = function
    | `Unexpected ->
        Error.typing ~loc "Constructor `%s` takes no argument but is given one"
          (Ast.Label.string_of lbl)
    | `Missing ->
        Error.typing ~loc "Constructor `%s` takes an argument but is given none"
          (Ast.Label.string_of lbl)

  (* A pattern consumes a value of type [expected.bound], a subtype of its
     shape. The components of a tuple type are passed to the components of a
     tuple pattern of the same length without an atom. *)
  let rec pattern env (pat : _ Ast.pattern) (expected : ty expected) =
    let at = pat.Ast.at in
    match pat.Ast.it with
    | Ast.PVar x -> { no_pattern with bindings = [ (x, expected.bound, at) ] }
    | Ast.PAs (pat', x) ->
        let p = pattern env pat' expected in
        { p with bindings = (x, expected.bound, at) :: p.bindings }
    | Ast.PNonbinding -> no_pattern
    | Ast.PAnnotated (pat', ty) ->
        let ty = open_ty ty in
        let because = Reason.because at Reason.Pattern_annotation in
        let p = pattern env pat' (expect ty because) in
        {
          p with
          constr =
            C.conj
              (C.Sub (Reason.against at because, expected.bound, ty))
              p.constr;
        }
    | Ast.PConst c ->
        {
          no_pattern with
          constr =
            C.Sub
              ( Reason.against at expected.because,
                expected.bound,
                Ast.TyConst (Const.infer_ty c) );
        }
    | Ast.PTuple pats -> tuple_pattern env at pats expected
    | Ast.PVariant (lbl, arg) -> variant_pattern env at lbl arg expected

  and tuple_pattern env at pats expected =
    let components, vars, constr =
      match expected.bound with
      | Ast.TyTuple tys when List.length tys = List.length pats ->
          (tys, C.no_vars, C.True)
      | ty ->
          let vars = fresh_ty_vars (List.length pats) in
          let tys = List.map (fun a -> Ast.TyParam a) vars in
          ( tys,
            { C.no_vars with ty_vars = vars },
            C.Sub (Reason.against at expected.because, ty, Ast.TyTuple tys) )
    in
    List.fold_left
      (fun acc (i, (pat, ty)) ->
        union_patterns acc
          (pattern env pat
             (expect ty (Reason.step (Reason.Component i) expected.because))))
      { no_pattern with vars; constr }
      (List.mapi (fun i p -> (i + 1, p)) (List.combine pats components))

  and variant_pattern env at lbl arg expected =
    let name, params, arg_ty = find_constructor ~loc:at env lbl in
    let vars = fresh_ty_vars (List.length params) in
    let args = List.map (fun a -> Ast.TyParam a) vars in
    let sigma = instance_subst params args in
    let head =
      {
        no_pattern with
        vars = { C.no_vars with ty_vars = vars };
        constr =
          C.Sub
            ( Reason.against at expected.because,
              expected.bound,
              Ast.TyApply (name, args) );
      }
    in
    match (arg_ty, arg) with
    | None, None -> head
    | Some arg_ty, Some arg ->
        union_patterns head
          (pattern env arg
             (expect (C.subst_ty sigma arg_ty)
                (Reason.because arg.Ast.at (Reason.Variant_argument lbl))))
    | None, Some _ -> arity_mismatch ~loc:at lbl `Unexpected
    | Some _, None -> arity_mismatch ~loc:at lbl `Missing

  (* [with_pattern env pat expected body] is the pattern's atoms and [body] of
     the context extended by its bindings, in the scope of its unknowns. *)
  let with_pattern env pat expected body =
    let p = pattern env pat expected in
    let env' =
      List.fold_left
        (fun env (x, ty, bound_at) -> bind env x ty ~bound_at)
        env p.bindings
    in
    C.exists p.vars (C.conj p.constr (body env'))

  (* ------------------------------------------------------------------ *)
  (* Auxiliary information for reasons                                   *)
  (* ------------------------------------------------------------------ *)

  (* An abstraction spans its pattern and its body. *)
  let abstraction_span ((pat, comp) : abstraction) =
    Location.merge pat.Ast.at comp.Ast.at

  (* The variable a pattern binds the whole value to, if the programmer named
     it. *)
  let rec pattern_variable (pat : _ Ast.pattern) =
    match pat.Ast.it with
    | Ast.PVar x | Ast.PAs (_, x) ->
        if Ast.Variable.is_synthetic x then None else Some x
    | Ast.PAnnotated (pat, _) -> pattern_variable pat
    | Ast.PNonbinding | Ast.PConst _ | Ast.PTuple _ | Ast.PVariant _ -> None

  (* The clause a rigid continuation effect belongs to; the parser pairs the
     parameter and continuation patterns. *)
  let rigid_origin clause ((pat, _) : abstraction) =
    let k = match pat.Ast.it with Ast.PTuple [ _; k ] -> Some k | _ -> None in
    {
      Reason.clause;
      continuation = Option.bind k pattern_variable;
      continuation_at =
        (match k with Some k -> k.Ast.at | None -> clause.Reason.case_at);
    }

  (* The kind of the lock a [Do] puts in the context: the desugarer turns
     [delay n; c] and [perform Op e; c] into [Do]s bound to exactly these. *)
  let sequenced_kind (comp : computation) =
    match comp.Ast.it with
    | Ast.Delay (n, { it = Ast.Return _; _ }) -> Reason.Delayed n
    | Ast.Perform (op, _, (_, { it = Ast.Return _; _ })) -> Reason.Performed op
    | _ -> Reason.Sequenced

  let signature ~loc env op =
    match find_op_signature env op with
    | Some signature -> signature
    | None ->
        Error.typing ~loc "Unknown operation `%s`" (Ast.OpName.string_of op)

  (* The atoms of a scheme's qualifier, owed by the use of [x] at [at]. *)
  let instance_of at x defined_at qualifier =
    C.map_reasons
      (fun inner ->
        Reason.because at (Reason.Instance_of { var = x; defined_at; inner }))
      qualifier

  (* The use of the variable [x] at [at]: its type is a subtype of the expected
     type, and it is eternal or the grades elapsed since its binding are below
     the unit. A scheme is instantiated first and its qualifier owed. *)
  let variable env at x expected =
    match lookup ~loc:at env x with
    | Local { ty; bound_at; elapsed } ->
        let why =
          match Reason.clause_of_elapsed elapsed with
          | Some clause ->
              Reason.Op_case_capture { var = x; bound_at; clause; elapsed }
          | None -> Reason.Use_after_time { var = x; bound_at; elapsed }
        in
        C.conj
          (sub_expected at ty expected)
          (C.Eternal_or_unit (Reason.because at why, ty, elapsed_grade elapsed))
    | Global { scheme; defined_at } ->
        let ty, qualifier = C.instantiate scheme in
        C.conj
          (sub_expected at ty expected)
          (instance_of at x defined_at qualifier)

  (* ------------------------------------------------------------------ *)
  (* Expressions and computations                                        *)
  (* ------------------------------------------------------------------ *)

  type function_kind = Impure | Pure | Recursive of Ast.variable

  let rec generate_expression env (e : expression) (expected : ty expected) =
    let at = e.Ast.at in
    match e.Ast.it with
    | Ast.Var x -> variable env at x expected
    | Ast.Const c ->
        (* the constant's type equals the expected type *)
        eq_expected at (Ast.TyConst (Const.infer_ty c)) expected
    | Ast.Annotated (e', ty) ->
        (* the expression against the annotation, a subtype of the expected
           type *)
        let ty = open_ty ty in
        C.conj
          (generate_expression env e'
             (expect ty (Reason.because at Reason.Annotation)))
          (sub_expected at ty expected)
    | Ast.Tuple es ->
        (* [α₁ × … × αₙ] equals the expected type, component [i] against [αᵢ] *)
        exists_tys (List.length es) (fun tys ->
            C.conj_all
              (eq_expected at (Ast.TyTuple tys) expected
              :: List.mapi
                   (fun i (e, ty) ->
                     generate_expression env e
                       (expect ty
                          (Reason.step
                             (Reason.Component (i + 1))
                             expected.because)))
                   (List.combine es tys)))
    | Ast.Variant (lbl, arg) -> variant env at lbl arg expected
    | Ast.Lambda abs -> function_ env at Impure abs expected
    | Ast.PureLambda abs -> function_ env at Pure abs expected
    | Ast.RecLambda (f, abs) -> function_ env at (Recursive f) abs expected
    | Ast.Handler (ret_case, op_cases) ->
        handler env at ret_case op_cases expected

  and variant env at lbl arg expected =
    let name, params, arg_ty = find_constructor ~loc:at env lbl in
    exists_instance name params (fun ty sigma ->
        let head = sub_expected at ty expected in
        match (arg_ty, arg) with
        | None, None -> head
        | Some arg_ty, Some arg ->
            C.conj head
              (generate_expression env arg
                 (expect (C.subst_ty sigma arg_ty)
                    (Reason.because arg.Ast.at (Reason.Variant_argument lbl))))
        | None, Some _ -> arity_mismatch ~loc:at lbl `Unexpected
        | Some _, None -> arity_mismatch ~loc:at lbl `Missing)

  (* [ε ≾ 1 ∧ 1 ≾ ε] *)
  and pure_body at eps =
    let reason = Reason.because at Reason.Pure_body in
    C.conj
      (C.Eps_leq (reason, eps, Eps.unit))
      (C.Eps_leq (reason, Eps.unit, eps))

  (* A function: the body is typed at the arrow [α → β ! ε] the function
     synthesises, a subtype of the expected type. A recursive function binds
     itself at that arrow; the body of a pure or recursive function has effect
     the unit, as two orderings. *)
  and function_ env at kind (pat, body) expected =
    exists_ty (fun param_ty ->
        exists_ty (fun result_ty ->
            exists_eps (fun eps ->
                let arrow =
                  Ast.TyArrow (param_ty, Ast.CompTy (result_ty, eps))
                in
                let because =
                  match kind with
                  | Recursive f ->
                      Reason.because at (Reason.Recursive_definition f)
                  | Impure | Pure -> Reason.because at Reason.Function_body
                in
                let env_body =
                  match kind with
                  | Recursive f -> bind env f arrow ~bound_at:at
                  | Impure | Pure -> env
                in
                C.conj_all
                  [
                    sub_expected at arrow expected;
                    with_pattern env_body pat
                      (expect param_ty
                         (Reason.because pat.Ast.at Reason.Function_parameter))
                      (fun env' ->
                        generate_computation env' body
                          (expect result_ty because) (expect eps because));
                    (match kind with
                    | Impure -> C.True
                    | Pure | Recursive _ -> pure_body at eps);
                  ])))

  (* A handler value of type [α ! ε_in ⇒ β ! ε_out]: the return clause under
     the lock [⟨∣ε_in∣⟩], each clause under [∀ε'']. *)
  and handler env at (ret_pat, ret_body) op_cases expected =
    exists_ty (fun input_ty ->
        exists_eps (fun input_eps ->
            exists_ty (fun output_ty ->
                exists_eps (fun output_eps ->
                    let handler_ty =
                      Ast.TyHandler
                        ( Ast.CompTy (input_ty, input_eps),
                          Ast.CompTy (output_ty, output_eps) )
                    in
                    let env_ret =
                      lock env
                        { grade = Rho.map input_eps; at; kind = Reason.Handled }
                    in
                    let because =
                      Reason.because ret_body.Ast.at Reason.Return_clause
                    in
                    let return_clause =
                      with_pattern env_ret ret_pat
                        (expect input_ty
                           (Reason.because ret_pat.Ast.at Reason.Return_clause))
                        (fun env' ->
                          generate_computation env' ret_body
                            (expect output_ty because)
                            (expect output_eps because))
                    in
                    let clauses =
                      List.map
                        (fun (op, abs) -> clause env ~output_ty op abs)
                        (Ast.OpNameMap.bindings op_cases)
                    in
                    C.conj_all
                      (sub_expected at handler_ty expected
                      :: return_clause :: clauses)))))

  (* The clause for [op], under the lock [⟨⊤⟩], for every continuation effect
     [ε'']: its parameter and continuation [[∣op∣](arity → β ! ε'')], its
     result of type [β] and effect below [op · ε'']. *)
  and clause env ~output_ty op ((pat, body) as abs) =
    let case_at = abstraction_span abs in
    let { param; arity; op_grade; signature_at } =
      match find_op_signature env op with
      | Some signature -> signature
      | None ->
          Error.typing ~loc:case_at "Case for an unknown operation `%s`"
            (Ast.OpName.string_of op)
    in
    let clause = { Reason.op; signature_at; case_at } in
    let rigid = X.Eps_var.fresh_indexed () in
    let env_clause =
      lock env
        { grade = Rho.top; at = case_at; kind = Reason.Clause_lock clause }
    in
    let continuation_ty =
      Ast.TyBox
        ( Rho.map op_grade,
          Ast.TyArrow (arity, Ast.CompTy (output_ty, Eps.var rigid)) )
    in
    let why = Reason.Handler_case { op; signature_at } in
    C.Forall_eps
      ( rigid,
        rigid_origin clause abs,
        with_pattern env_clause pat
          (expect
             (Ast.TyTuple [ param; continuation_ty ])
             (Reason.because pat.Ast.at why))
          (fun env' ->
            generate_computation env' body
              (expect output_ty (Reason.because case_at why))
              (expect
                 (Eps.mul op_grade (Eps.var rigid))
                 (Reason.because case_at
                    (Reason.Continuation_grade { op; signature_at })))) )

  and generate_computation env (c : computation) (ty : ty expected)
      (eps : eps expected) =
    let at = c.Ast.at in
    match c.Ast.it with
    | Ast.Return e ->
        (* [return e]: the unit effect below the expected one *)
        C.conj (generate_expression env e ty) (leq_expected at Eps.unit eps)
    | Ast.Do (c1, (pat, c2)) -> sequence env at c1 pat c2 ty eps
    | Ast.Apply (e1, e2) -> apply env at e1 e2 ty eps
    | Ast.Match (e, cases) -> match_ env at e cases ty eps
    | Ast.Delay (n, c') ->
        (* [delay n c]: [c] under the lock [⟨n⟩], the effect [n · ε] below the
           expected one *)
        exists_eps (fun eps' ->
            let kind = Reason.Delayed n in
            C.conj
              (generate_computation
                 (lock env { grade = Rho.of_nat n; at; kind })
                 c' ty
                 (expect eps'
                    (Reason.because c'.Ast.at (Reason.Continuation_effect kind))))
              (leq_expected at (Eps.mul (Eps.of_nat n) eps') eps))
    | Ast.Box (rho, e, (pat, c')) -> box env at (open_rho rho) e pat c' ty eps
    | Ast.Unbox (e, (pat, c')) -> unbox env at e pat c' ty eps
    | Ast.Perform (op, e, (pat, c')) -> perform env at op e pat c' ty eps
    | Ast.Handle (c', h) -> handle env at c' h ty eps

  (* [let p = c₁ in c₂]: the continuation under the lock [⟨∣ε₁∣⟩], the effect
     [ε₁ · ε₂] below the expected one. *)
  and sequence env at c1 pat c2 ty eps =
    exists_ty (fun ty1 ->
        exists_eps (fun eps1 ->
            exists_eps (fun eps2 ->
                let kind = sequenced_kind c1 in
                let bound = Reason.because c1.Ast.at Reason.Sequencing in
                let env' =
                  lock env { grade = Rho.map eps1; at = c1.Ast.at; kind }
                in
                C.conj_all
                  [
                    generate_computation env c1 (expect ty1 bound)
                      (expect eps1 bound);
                    with_pattern env' pat
                      (expect ty1
                         (Reason.because pat.Ast.at
                            (Reason.Match_scrutinee { scrutinee_at = c1.Ast.at })))
                      (fun env'' ->
                        generate_computation env'' c2 ty
                          (expect eps2
                             (Reason.because c2.Ast.at
                                (Reason.Continuation_effect kind))));
                    leq_expected at (Eps.mul eps1 eps2) eps;
                  ])))

  (* [e₁ e₂]: the function's result type is a subtype of the expected type,
     its latent effect below the expected effect. *)
  and apply env at e1 e2 ty eps =
    exists_ty (fun arg_ty ->
        exists_ty (fun result_ty ->
            exists_eps (fun latent ->
                let because =
                  Reason.because at
                    (Reason.Application
                       { func_at = e1.Ast.at; arg_at = e2.Ast.at })
                in
                C.conj_all
                  [
                    generate_expression env e1
                      (expect
                         (Ast.TyArrow (arg_ty, Ast.CompTy (result_ty, latent)))
                         because);
                    generate_expression env e2
                      (expect arg_ty (Reason.step Reason.Argument because));
                    sub_expected at result_ty ty;
                    leq_expected at latent eps;
                  ])))

  (* [match e with …]: the scrutinee against a fresh type, each branch against
     a shared type and effect below the expected ones. *)
  and match_ env at e cases ty eps =
    exists_ty (fun scrutinee_ty ->
        exists_ty (fun branch_ty ->
            exists_eps (fun branch_eps ->
                let scrutinee_at = e.Ast.at in
                let branch (pat, body) =
                  let because =
                    Reason.because body.Ast.at Reason.Match_branch
                  in
                  with_pattern env pat
                    (expect scrutinee_ty
                       (Reason.because pat.Ast.at
                          (Reason.Match_scrutinee { scrutinee_at })))
                    (fun env' ->
                      generate_computation env' body (expect branch_ty because)
                        (expect branch_eps because))
                in
                C.conj_all
                  (generate_expression env e
                     (expect scrutinee_ty
                        (Reason.because scrutinee_at
                           (Reason.Match_scrutinee { scrutinee_at })))
                  :: sub_expected at branch_ty ty
                  :: leq_expected at branch_eps eps
                  :: List.map branch cases))))

  (* [box ρ e as p in c]: the payload under the lock [⟨ρ⟩], the pattern
     against [[ρ] α]. *)
  and box env at rho e pat c' ty eps =
    exists_ty (fun payload_ty ->
        let because = Reason.because at Reason.Boxed_value in
        C.conj
          (generate_expression
             (lock env { grade = rho; at; kind = Reason.Boxed })
             e
             (expect payload_ty because))
          (with_pattern env pat
             (expect (Ast.TyBox (rho, payload_ty)) because)
             (fun env' -> generate_computation env' c' ty eps)))

  (* [unbox x as p in c], of a variable only: its type is a box [[r] α] whose
     grade covers the grades elapsed since its binding, the pattern against
     [α]. *)
  and unbox env at e pat c' ty eps =
    let rec find_var (e : expression) =
      match e.Ast.it with
      | Ast.Var x -> x
      | Ast.Annotated (e', _) -> find_var e'
      | _ -> Error.typing ~loc:e.Ast.at "Only a variable can be unboxed"
    in
    let x = find_var e in
    let boxed_ty, bound_at, elapsed, instance =
      match lookup ~loc:e.Ast.at env x with
      | Local { ty; bound_at; elapsed } -> (ty, Some bound_at, elapsed, C.True)
      | Global { scheme; defined_at } ->
          let ty, qualifier = C.instantiate scheme in
          ( ty,
            defined_at,
            all_locks env,
            instance_of e.Ast.at x defined_at qualifier )
    in
    exists_ty (fun payload_ty ->
        exists_rho (fun rho ->
            let because =
              Reason.because at (Reason.Unboxed { var = x; bound_at; elapsed })
            in
            C.conj_all
              [
                C.equal_ty because boxed_ty (Ast.TyBox (rho, payload_ty));
                C.Rho_leq (because, elapsed_grade elapsed, rho);
                with_pattern env pat
                  (expect payload_ty
                     (Reason.because pat.Ast.at
                        (Reason.Unboxed { var = x; bound_at; elapsed })))
                  (fun env' -> generate_computation env' c' ty eps);
                instance;
              ]))

  (* [perform op e]: the continuation under the lock [⟨∣op∣⟩], the effect
     [op · ε] below the expected one. *)
  and perform env at op e pat c' ty eps =
    let { param; arity; op_grade; signature_at } = signature ~loc:at env op in
    exists_eps (fun eps' ->
        let kind = Reason.Performed op in
        let env' = lock env { grade = Rho.map op_grade; at; kind } in
        C.conj_all
          [
            generate_expression env e
              (expect param
                 (Reason.because e.Ast.at
                    (Reason.Perform_argument { op; signature_at })));
            with_pattern env' pat
              (expect arity
                 (Reason.because pat.Ast.at
                    (Reason.Perform_continuation { op; signature_at })))
              (fun env'' ->
                generate_computation env'' c' ty
                  (expect eps'
                     (Reason.because c'.Ast.at (Reason.Continuation_effect kind))));
            leq_expected at (Eps.mul op_grade eps') eps;
          ])

  (* [handle c with h]: [c : α ! ε₁], [h : α ! ε₁ ⇒ γ ! ε₂], [γ] below the
     expected type and [ε₁ · ε₂] below the expected effect. *)
  and handle env at c' h ty eps =
    exists_ty (fun input_ty ->
        exists_ty (fun output_ty ->
            exists_eps (fun eps1 ->
                exists_eps (fun eps2 ->
                    let handled =
                      Reason.because c'.Ast.at Reason.Handled_computation
                    in
                    C.conj_all
                      [
                        generate_computation env c' (expect input_ty handled)
                          (expect eps1 handled);
                        generate_expression env h
                          (expect
                             (Ast.TyHandler
                                ( Ast.CompTy (input_ty, eps1),
                                  Ast.CompTy (output_ty, eps2) ))
                             (Reason.because h.Ast.at Reason.Handle_with));
                        sub_expected at output_ty ty;
                        leq_expected at (Eps.mul eps1 eps2) eps;
                      ]))))

  (* ------------------------------------------------------------------ *)
  (* Top-level commands                                                  *)
  (* ------------------------------------------------------------------ *)

  let generate_top_let env ~loc x e =
    let a = Ast.TyParam (Ast.TyParamModule.fresh "ty") in
    ( a,
      generate_expression env e
        (expect a (Reason.because loc (Reason.Top_definition x))) )

  let generate_run env ~loc c =
    let a = Ast.TyParam (Ast.TyParamModule.fresh "ty") in
    let eps = Eps.var (X.Eps_var.fresh_indexed ()) in
    let because = Reason.because loc Reason.Top_computation in
    ( Ast.CompTy (a, eps),
      generate_computation env c (expect a because) (expect eps because) )

  let generate_default env ~loc op (pat, body) =
    let op_name = Ast.OpName.string_of op in
    let { param; arity; op_grade; signature_at } =
      match find_op_signature env op with
      | Some signature -> signature
      | None -> Error.typing ~loc "unknown operation `%s`" op_name
    in
    if Ast.OpNameSet.mem op env.op_defaults then
      Error.typing ~loc "operation `%s` already has a default implementation"
        op_name;
    (match op_grade with
    | X.Eps_const c when not (GS.E.is_atomic op_name c) ->
        Error.typing ~loc
          "a default implementation may only be given for an atomic operation, \
           but the grade of `%s` is `%s`; handle it with a handler in terms of \
           the operations it names"
          op_name (GS.E.show c)
    | X.Eps_const _ | X.Eps_var _ | X.Eps_mul _ | X.Eps_join _ -> ());
    let bound =
      match StringMap.find_opt op_name env.op_bounds with
      | Some bounds -> Eps.const (GS.E.of_bounds bounds)
      | None -> op_grade
    in
    let clause = { Reason.op; signature_at; case_at = loc } in
    let env' =
      lock env { grade = Rho.top; at = loc; kind = Reason.Clause_lock clause }
    in
    let default = Reason.because loc (Reason.Default_of { op; signature_at }) in
    with_pattern env' pat
      (expect param (Reason.step Reason.Argument default))
      (fun env'' ->
        generate_computation env'' body
          (expect arity (Reason.step Reason.Result default))
          (expect bound (Reason.step Reason.Effect default)))
end
