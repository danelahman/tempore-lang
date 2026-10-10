(* Constraint generation in checking mode, against an expected type, in the
   manner of Pottier and Rémy (The Essence of ML Type Inference, ATTAPL,
   2005). *)

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
  (* Environments                                                        *)
  (* ------------------------------------------------------------------ *)

  type ty_definition = {
    params : Ast.ty_param list;
    definition : (rho, eps) Ast.ty_def;
    strictly_positive : bool list;
  }

  type op_signature = {
    param : ty;
    arity : ty;
    op_grade : eps;
    signature_at : Location.t;
  }

  (* An entry of the context: a binding [x : A], a persistent binding
     [x :[⊤] A], used with an implicit unbox, or a lock [⟨ρ⟩]. *)
  type entry =
    | Bound of Ast.variable * ty * Location.t
    | Persistent of Ast.variable * ty * Location.t
    | Lock of rho Reason.lock

  type global = { scheme : C.scheme; defined_at : Location.t option }

  type env = {
    context : entry list;  (** newest first *)
    globals : global Ast.VariableMap.t;
    global_performs : Ast.OpNameSet.t Ast.VariableMap.t;
    type_definitions : ty_definition Ast.TyNameMap.t;
    constructors : Ast.ty_name LabelMap.t;
    noneternal : Ast.TyNameSet.t;
    op_signatures : op_signature Ast.OpNameMap.t;
    op_bounds : Grades.Grade.running_time StringMap.t;
    op_defaults : DefaultGraph.default Ast.OpNameMap.t;
    world : Grades.Grade.running_time StringMap.t;
        (** the operations the whole program declares with running-time bounds
        *)
  }

  let set_type_definition name def env =
    {
      env with
      type_definitions = Ast.TyNameMap.add name def env.type_definitions;
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
    { (set_type_definition name def env) with constructors }

  let find_type_definition env name =
    Ast.TyNameMap.find_opt name env.type_definitions

  (* ------------------------------------------------------------------ *)
  (* Strict positivity                                                   *)
  (* ------------------------------------------------------------------ *)

  (* A position at which an occurrence is not strictly positive. *)
  type position =
    | Function_domain
    | Handler_input
    | Grouped_argument of Ast.ty_name
        (** an argument of a type defined together with the occurring one *)
    | Nonpositive_argument of Ast.ty_name
        (** an argument of a type at a parameter not strictly positive *)

  (* The types a definition is made of: the arguments of its constructors, or
     the body of an alias. *)
  let components = function
    | Ast.TySum variants -> List.filter_map snd variants
    | Ast.TyInline ty -> [ ty ]

  let immediate_subtypes = function
    | Ast.TyConst _ | Ast.TyParam _ -> []
    | Ast.TyApply (_, tys) | Ast.TyTuple tys -> tys
    | Ast.TyArrow (ty, Ast.CompTy (ty', _))
    | Ast.TyHandler (Ast.CompTy (ty, _), Ast.CompTy (ty', _)) ->
        [ ty; ty' ]
    | Ast.TyBox (_, ty) -> [ ty ]

  (* The first subtype of [ty], outermost first, that [target] finds. *)
  let rec occurrence target ty =
    match target ty with
    | Some _ as found -> found
    | None -> List.find_map (occurrence target) (immediate_subtypes ty)

  (* The first occurrence of [target] in [ty] that is not strictly positive,
     with its position, at the parameter polarities of [env]; [grouped name]
     is whether [name] is defined together with the types [target] finds. *)
  let rec nonpositive env ~target ~grouped ty =
    let at position ty =
      Option.map (fun found -> (found, position)) (occurrence target ty)
    in
    let within = nonpositive env ~target ~grouped in
    let first found ty =
      match found with Some _ -> found | None -> within ty
    in
    match ty with
    | Ast.TyConst _ | Ast.TyParam _ -> None
    | Ast.TyTuple tys -> List.find_map within tys
    | Ast.TyBox (_, ty) -> within ty
    | Ast.TyArrow (ty, Ast.CompTy (ty', _)) -> first (at Function_domain ty) ty'
    | Ast.TyHandler (Ast.CompTy (ty, _), Ast.CompTy (ty', _)) ->
        first (at Handler_input ty) ty'
    | Ast.TyApply (name, tys) when grouped name ->
        List.find_map (at (Grouped_argument name)) tys
    | Ast.TyApply (name, tys) ->
        let positive =
          match find_type_definition env name with
          | Some def -> def.strictly_positive
          | None -> []
        in
        List.find_map
          (fun (i, ty) ->
            if List.nth_opt positive i = Some true then within ty
            else at (Nonpositive_argument name) ty)
          (List.mapi (fun i ty -> (i, ty)) tys)

  (* Whether each parameter of [def] occurs only strictly positively in it, at
     the parameter polarities of [env]. *)
  let polarity env def =
    List.map
      (fun a ->
        let target = function
          | Ast.TyParam b when Ast.TyParamModule.compare a b = 0 -> Some ()
          | _ -> None
        in
        List.for_all
          (fun ty ->
            Option.is_none
              (nonpositive env ~target ~grouped:(fun _ -> false) ty))
          (components def.definition))
      def.params

  (* [env] with the definitions [group], defined together, their parameter
     polarities the greatest fixpoint below those they record. *)
  let rec settle_polarities env group =
    let env =
      List.fold_left
        (fun env (name, def) -> set_type_definition name def env)
        env group
    in
    let settled =
      List.map
        (fun (name, def) ->
          ( name,
            {
              def with
              strictly_positive =
                List.map2 ( && ) def.strictly_positive (polarity env def);
            } ))
        group
    in
    if
      List.equal
        (fun (_, def) (_, def') ->
          List.equal Bool.equal def.strictly_positive def'.strictly_positive)
        group settled
    then env
    else settle_polarities env settled

  let describe_position = function
    | Function_domain -> "in the domain of a function type"
    | Handler_input -> "in the input type of a handler type"
    | Grouped_argument name ->
        Format.asprintf "in an argument of `%t`, a type being defined,"
          (Ast.TyName.print name)
    | Nonpositive_argument name ->
        Format.asprintf
          "in an argument of `%t`, at a parameter that is not strictly \
           positive,"
          (Ast.TyName.print name)

  (* Every type of the definitions [group], defined together, occurs only
     strictly positively in each of them: the positivity condition of
     inductive types (Coquand and Paulin, COLOG-88, 1990). *)
  let check_strictly_positive ~loc env group =
    let grouped name =
      List.exists (fun (name', _) -> Ast.TyName.compare name name' = 0) group
    in
    let target = function
      | Ast.TyApply (name, _) when grouped name -> Some name
      | _ -> None
    in
    let check where ty =
      match nonpositive env ~target ~grouped ty with
      | None -> ()
      | Some (name, position) ->
          Error.typing ~loc
            ~notes:
              [
                "a type occurring other than strictly positively in its own \
                 definition admits non-terminating programs without recursion";
              ]
            "Type `%t` is not strictly positive: it occurs %s %s"
            (Ast.TyName.print name)
            (describe_position position)
            where
    in
    List.iter
      (fun (name, def) ->
        match def.definition with
        | Ast.TySum variants ->
            List.iter
              (fun (lbl, ty) ->
                Option.iter
                  (check
                     (Printf.sprintf "in the argument of constructor `%s`"
                        (Ast.Label.string_of lbl)))
                  ty)
              variants
        | Ast.TyInline ty ->
            check
              (Printf.sprintf "in the definition of `%s`"
                 (Ast.TyName.string_of name))
              ty)
      group

  (* [env] with the definitions [group], defined together. *)
  let add_type_group env group =
    settle_polarities
      (List.fold_left
         (fun env (name, def) -> add_type_definition name def env)
         env group)
      group

  (* A definition whose parameters are assumed strictly positive. *)
  let assumed_positive params definition =
    { params; definition; strictly_positive = List.map (fun _ -> true) params }

  let initial_env =
    let a = Ast.TyParamModule.fresh "list" in
    let alias ty = assumed_positive [] (Ast.TyInline ty) in
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
      global_performs = Ast.VariableMap.empty;
      type_definitions = Ast.TyNameMap.empty;
      constructors = LabelMap.empty;
      noneternal = Ast.TyNameSet.empty;
      op_signatures = Ast.OpNameMap.empty;
      op_bounds = StringMap.empty;
      op_defaults = Ast.OpNameMap.empty;
      world = StringMap.empty;
    }
    |> add_type_definition Ast.bool_ty_name
         (alias (Ast.TyConst Const.BooleanTy))
    |> add_type_definition Ast.nat_ty_name (alias (Ast.TyConst Const.NatTy))
    |> add_type_definition Ast.unit_ty_name (alias (Ast.TyTuple []))
    |> add_type_definition Ast.string_ty_name
         (alias (Ast.TyConst Const.StringTy))
    |> add_type_definition Ast.float_ty_name (alias (Ast.TyConst Const.FloatTy))
    |> add_type_definition Ast.empty_ty_name
         (assumed_positive [] (Ast.TySum []))
    |> fun env ->
    add_type_group env [ (Ast.list_ty_name, assumed_positive [ a ] list_def) ]

  let is_noneternal env name = Ast.TyNameSet.mem name env.noneternal
  let find_op_signature env op = Ast.OpNameMap.find_opt op env.op_signatures

  let declare_operations declarations env =
    let add world (name, bounds) =
      match bounds with
      | Some bounds when not (StringMap.mem name world) ->
          StringMap.add name bounds world
      | Some _ | None -> world
    in
    { env with world = List.fold_left add StringMap.empty declarations }

  (* ------------------------------------------------------------------ *)
  (* Program syntax                                                      *)
  (* ------------------------------------------------------------------ *)

  let running_times ~loc env =
    let bounds event =
      match StringMap.find_opt event env.world with
      | Some bounds -> Some bounds
      | None -> StringMap.find_opt event env.op_bounds
    in
    {
      Grades.Grade.running_time =
        (fun event ->
          match bounds event with
          | Some bounds -> bounds
          | None ->
              Error.typing ~loc
                "Unknown event `%s`; the events of a grade must be declared \
                 operations"
                event);
      operations = List.map fst (StringMap.bindings env.world);
    }

  (* A grade constant read from the source at [at] must denote a trace of the
     operations declared in [env]. *)
  let check_inhabited ~inhabited ~show env c = function
    | Some loc when not (inhabited (running_times ~loc env) c) ->
        Error.typing ~loc
          "The grade `%s` permits no trace over the declared operations"
          (show c)
    | Some _ | None -> ()

  (* The grade variables of an annotation are unknowns of the command it
     belongs to, bound by [with_annotation_vars]. *)
  let rec open_rho env = function
    | Ast.RhoConst (c, at) ->
        check_inhabited ~inhabited:GS.R.inhabited ~show:GS.R.show env c at;
        Rho.const c
    | Ast.RhoAdd (rho, rho') -> Rho.mul (open_rho env rho) (open_rho env rho')
    | Ast.RhoVar r -> Rho.var r
    | Ast.RhoImage e -> Rho.map (Eps.var e)

  let rec open_eps env = function
    | Ast.EpsConst (c, at) ->
        check_inhabited ~inhabited:GS.E.inhabited ~show:GS.E.show env c at;
        Eps.const c
    | Ast.EpsAdd (eps, eps') -> Eps.mul (open_eps env eps) (open_eps env eps')
    | Ast.EpsVar e -> Eps.var e

  let open_ty env ty =
    Ast.map_ty ~on_rho:(open_rho env) ~on_eps:(open_eps env) ty

  let open_ty_def env = function
    | Ast.TySum variants ->
        Ast.TySum
          (List.map
             (fun (lbl, ty) -> (lbl, Option.map (open_ty env) ty))
             variants)
    | Ast.TyInline ty -> Ast.TyInline (open_ty env ty)

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

  (* An argument of an alias being unfolded: a type with the aliases unfolded
     around it and the arguments of its parameters. *)
  type argument =
    | Argument of
        Ast.ty_name list * argument Ast.TyParamMap.t * (rho, eps) Ast.ty

  (* Whether unfolding the aliases in a type reaches an alias of [path], the
     aliases being unfolded. Types defined by constructors are not unfolded,
     but their arguments are searched. The parameters of the type are bound to
     their arguments by [args]; a parameter without an argument is left as it
     is. *)
  let rec reaches_unfolded env ~path ~args = function
    | Ast.TyConst _ -> false
    | Ast.TyParam p -> (
        match Ast.TyParamMap.find_opt p args with
        | Some (Argument (path, args, ty)) ->
            reaches_unfolded env ~path ~args ty
        | None -> false)
    | Ast.TyApply (name, tys) -> (
        match find_type_definition env name with
        | Some { params; definition = Ast.TyInline body; _ } ->
            List.exists (fun name' -> Ast.TyName.compare name name' = 0) path
            ||
            let args' =
              List.fold_left2
                (fun args' p ty ->
                  Ast.TyParamMap.add p (Argument (path, args, ty)) args')
                Ast.TyParamMap.empty params tys
            in
            reaches_unfolded env ~path:(name :: path) ~args:args' body
        | Some { definition = Ast.TySum _; _ } | None ->
            List.exists (reaches_unfolded env ~path ~args) tys)
    | ty ->
        List.exists (reaches_unfolded env ~path ~args) (immediate_subtypes ty)

  (* No alias of [group] unfolds, through aliases only, to a type containing
     itself. *)
  let check_acyclic_aliases ~loc env group =
    List.iter
      (fun (name, def) ->
        match def.definition with
        | Ast.TySum _ -> ()
        | Ast.TyInline body ->
            if
              reaches_unfolded env ~path:[ name ] ~args:Ast.TyParamMap.empty
                body
            then
              Error.typing ~loc "The type alias `%t` is cyclic"
                (Ast.TyName.print name))
      group

  let add_type_definitions ~loc env (eternality, defs) =
    (match eternality with
    | Ast.Derived -> ()
    | Ast.Noneternal -> List.iter (check_noneternal_definable ~loc) defs);
    let group =
      List.map
        (fun (params, name, def) ->
          (name, assumed_positive params (open_ty_def env def)))
        defs
    in
    let env' =
      List.fold_left
        (fun env (name, def) ->
          let env = add_type_definition name def env in
          match eternality with
          | Ast.Derived -> env
          | Ast.Noneternal ->
              { env with noneternal = Ast.TyNameSet.add name env.noneternal })
        env group
    in
    List.iter (fun (_, def) -> check_ty_def ~loc env' def.definition) group;
    check_acyclic_aliases ~loc env' group;
    check_strictly_positive ~loc env' group;
    settle_polarities env' group

  (* The running-time bounds of the operations, extended by those of [op_name],
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
          "running-time bounds are only used by the trace and the regular \
           expression grading monoids of timed operations, and must not be \
           declared under the `%s` grading monoid"
          GS.E.name
    | false, _, None -> env.op_bounds
    | true, (Ast.EpsAdd _ | Ast.EpsVar _), _ ->
        Error.typing ~loc
          "the grade of operation `%s` must be a literal under the `%s` \
           grading monoid"
          op_name GS.E.name
    | true, Ast.EpsConst (c, _), _ when GS.E.is_atomic op_name c -> (
        match bounds with
        | None ->
            Error.typing ~loc
              "atomic operation `%s` needs running-time bounds `within [lo, \
               hi]` under the `%s` grading monoid"
              op_name GS.E.name
        | Some (lo, hi)
          when Grades.Rational.compare
                 (Grades.Grade.end_value lo)
                 (Grades.Grade.end_value hi)
               > 0 ->
            Error.typing ~loc
              "the running-time bounds of operation `%s` must satisfy `lo <= \
               hi`"
              op_name
        | Some (_, hi)
          when Grades.Rational.sign (Grades.Grade.end_value hi) <= 0 ->
            Error.typing ~loc
              "the upper running-time bound of operation `%s` must be positive"
              op_name
        | Some bounds -> StringMap.add op_name bounds env.op_bounds)
    | true, Ast.EpsConst (c, _), Some _ ->
        Error.typing ~loc
          "operation `%s` is compound, so its running-time bounds follow from \
           its grade `%s` and must not be declared"
          op_name (GS.E.show c)
    | true, Ast.EpsConst (c, _), None -> (
        if List.mem op_name (GS.E.events c) then
          Error.typing ~loc
            "compound operation `%s` may not name itself in its grade `%s`"
            op_name (GS.E.show c);
        match
          GS.E.implied_bounds
            { (running_times ~loc env) with running_time = event_bounds }
            c
        with
        | Some bounds -> StringMap.add op_name bounds env.op_bounds
        | None -> env.op_bounds)

  type higher_order = Function_type | Handler_type

  (* The first function or handler type in [ty], with the outermost type
     whose definition it is found in, if any; definitions are unfolded, a
     type of [unfolding] being ground. *)
  let rec higher_order env ~unfolding = function
    | Ast.TyConst _ | Ast.TyParam _ -> None
    | Ast.TyArrow _ -> Some (Function_type, None)
    | Ast.TyHandler _ -> Some (Handler_type, None)
    | Ast.TyTuple tys -> List.find_map (higher_order env ~unfolding) tys
    | Ast.TyBox (_, ty) -> higher_order env ~unfolding ty
    | Ast.TyApply (name, tys) -> (
        match List.find_map (higher_order env ~unfolding) tys with
        | Some _ as found -> found
        | None
          when List.exists (fun n -> Ast.TyName.compare n name = 0) unfolding ->
            None
        | None ->
            Option.bind (find_type_definition env name) (fun def ->
                List.find_map
                  (higher_order env ~unfolding:(name :: unfolding))
                  (components def.definition))
            |> Option.map (fun (former, _) -> (former, Some name)))

  (* The parameter or result type [ty] of the operation [op] contains no
     function or handler type. *)
  let check_ground ~loc env op which ty =
    match higher_order env ~unfolding:[] ty with
    | None -> ()
    | Some (former, through) ->
        Error.typing ~loc
          ~notes:
            [
              "a function or handler in an operation's parameter or result \
               lets a handler build non-terminating programs without recursion";
            ]
          "The operation `%s` has a %s type containing a %s type%s; operation \
           parameter and result types must be ground"
          (Ast.OpName.string_of op) which
          (match former with
          | Function_type -> "function"
          | Handler_type -> "handler")
          (match through with
          | Some name ->
              Printf.sprintf " through the definition of `%s`"
                (Ast.TyName.string_of name)
          | None -> "")

  let add_operation_signature ~loc env (op, param, arity, grade, bounds) =
    let op_name = Ast.OpName.string_of op in
    let op_bounds = checked_op_bounds ~loc env op_name grade bounds in
    let op_grade = open_eps env grade in
    let arity = open_ty env arity in
    let param = open_ty env param in
    check_ground ~loc env op "parameter" param;
    check_ground ~loc env op "result" arity;
    let signature = { param; arity; op_grade; signature_at = loc } in
    {
      env with
      op_signatures = Ast.OpNameMap.add op signature env.op_signatures;
      op_bounds;
    }

  let add_global env x ~defined_at ~performs scheme =
    {
      env with
      globals = Ast.VariableMap.add x { scheme; defined_at } env.globals;
      global_performs = Ast.VariableMap.add x performs env.global_performs;
    }

  let load_primitive env x prim =
    add_global env x ~defined_at:None ~performs:Ast.OpNameSet.empty
      (Primitive_schemes.scheme prim)

  let add_operation_default env op default =
    { env with op_defaults = Ast.OpNameMap.add op default env.op_defaults }

  let global_performs env x =
    Ast.VariableMap.find_opt x env.global_performs
    |> Option.value ~default:Ast.OpNameSet.empty

  let find_operation_default env op = Ast.OpNameMap.find_opt op env.op_defaults

  let bind env x ty ~bound_at =
    { env with context = Bound (x, ty, bound_at) :: env.context }

  let bind_persistent env x ty ~bound_at =
    { env with context = Persistent (x, ty, bound_at) :: env.context }

  let lock env l = { env with context = Lock l :: env.context }

  (* A variable in the environment: bound in the context, with the locks since
     its binding, oldest first, bound persistently in the context, or a
     top-level definition or primitive. *)
  type lookup =
    | Local of { ty : ty; bound_at : Location.t; locks : rho Reason.lock list }
    | Persistent_local of { ty : ty; bound_at : Location.t }
    | Global of global

  let lookup ~loc env x =
    let rec find locks = function
      | Bound (y, ty, bound_at) :: _ when Ast.Variable.compare x y = 0 ->
          Local { ty; bound_at; locks }
      | Persistent (y, ty, bound_at) :: _ when Ast.Variable.compare x y = 0 ->
          Persistent_local { ty; bound_at }
      | (Bound _ | Persistent _) :: context -> find locks context
      | Lock e :: context -> find (e :: locks) context
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
      (fun locks -> function
        | Lock e -> e :: locks | Bound _ | Persistent _ -> locks)
      [] env.context

  (* The grade accumulated by locks, oldest first: the product of their
     grades, the unit for none. *)
  let accumulated_grade = function
    | [] -> Rho.unit
    | (e : rho Reason.lock) :: rest ->
        List.fold_left
          (fun rho (e : rho Reason.lock) -> Rho.mul rho e.grade)
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

  let datatype_constructors env lbl =
    match
      Option.bind
        (LabelMap.find_opt lbl env.constructors)
        (find_type_definition env)
    with
    | Some { definition = Ast.TySum variants; _ } ->
        List.map (fun (lbl, arg) -> (lbl, Option.is_some arg)) variants
    | Some { definition = Ast.TyInline _; _ } | None -> []

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
          (Ast.label_string_of lbl)
    | `Missing ->
        Error.typing ~loc "Constructor `%s` takes an argument but is given none"
          (Ast.label_string_of lbl)

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
        let ty = open_ty env ty in
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
    | Ast.PSucc (pat', _) ->
        let nat = Ast.TyConst Const.NatTy in
        let p =
          pattern env pat'
            (expect nat (Reason.because pat'.Ast.at Reason.Successor_pattern))
        in
        {
          p with
          constr =
            C.conj
              (C.Sub (Reason.against at expected.because, expected.bound, nat))
              p.constr;
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
    | Ast.PNonbinding | Ast.PConst _ | Ast.PSucc _ | Ast.PTuple _
    | Ast.PVariant _ ->
        None

  (* The variable an expression is, if the programmer named it. *)
  let expression_variable (e : expression) =
    match e.Ast.it with
    | Ast.Var x when not (Ast.Variable.is_synthetic x) -> Some x
    | _ -> None

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

  (* The delay of the literal [q], which the parser has read. *)
  let delay q =
    match GS.E.Delay.read (Grades.Grade.rational_lit q) with
    | Some d -> d
    | None -> invalid_arg ("Generate.delay: " ^ Grades.Rational.show q)

  (* The kind of the lock a [Do] puts in the context and the grade its bound
     computation declares: the desugarer turns [delay q; c] and
     [perform Op e; c] into [Do]s bound to exactly these. *)
  let sequenced_kind env (comp : computation) =
    match comp.Ast.it with
    | Ast.Delay (q, { it = Ast.Return _; _ }) ->
        (Reason.Delayed q, Some (Rho.of_delay (delay q)))
    | Ast.Perform (op, _, (_, { it = Ast.Return _; _ })) ->
        ( Reason.Performed op,
          Option.map
            (fun signature -> Rho.map signature.op_grade)
            (find_op_signature env op) )
    | _ -> (Reason.Sequenced, None)

  let signature ~loc env op =
    match find_op_signature env op with
    | Some signature -> signature
    | None ->
        Error.typing ~loc "Unknown operation `%s`" (Ast.OpName.string_of op)

  (* The qualifier [Q ∧ R] of a scheme, its atoms and obligations owed by the
     use of [x] at [at]. *)
  let instance_of at x defined_at qualifier =
    C.map_reasons
      (fun inner ->
        Reason.because at (Reason.Instance_of { var = x; defined_at; inner }))
      qualifier

  (* The use of the variable [x] at [at]: its type is a subtype of the expected
     type, and it is eternal or the grade accumulated since its binding is
     below the unit, unless it is bound persistently. A scheme is instantiated
     first and its qualifier [Q ∧ R] owed. *)
  let variable env at x expected =
    match lookup ~loc:at env x with
    | Local { ty; bound_at; locks } ->
        let why = Reason.use_under ~var:x ~bound_at locks in
        C.conj
          (sub_expected at ty expected)
          (C.Eternal_or_unit (Reason.because at why, ty, accumulated_grade locks))
    | Persistent_local { ty; _ } -> sub_expected at ty expected
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
        let ty = open_ty env ty in
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
    | Ast.RecLambda (f, None, abs) ->
        function_ env at (Recursive f) abs expected
    | Ast.RecLambda (f, Some eps, abs) ->
        annotated_recursive env at f (open_eps env eps) abs expected
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
     synthesises, a subtype of the expected type. The body of a recursive
     function sees its surrounding context behind the lock [⟨⊤⟩], and the
     function itself bound persistently at that arrow after it; the body of a
     pure or recursive function has effect the unit, as two orderings. *)
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
                  | Recursive f -> recursive_env env at f arrow
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

  (* The context of the body of the recursive function [f] of type [ty]: the
     surrounding context behind the lock [⟨⊤⟩], then [f] bound persistently. *)
  and recursive_env env at f ty =
    bind_persistent
      (lock env
         {
           grade = Rho.top;
           at;
           kind = Reason.Recursive_lock f;
           declared = None;
         })
      f ty ~bound_at:at

  (* A recursive function [rec f p₁ … pₙ] annotated with the effect [ε] of its
     innermost arrow has the type [T = α₁ → (… (αₙ → β ! ε) ! 1 …) ! 1], a
     subtype of the expected type. Its body is typed at the outermost arrow of
     [T], with [f : T] as in [recursive_env], and its inner functions against
     the inner arrows of [T]. *)
  and annotated_recursive env at f eps ((pat, body) as abs) expected =
    let inner_layers = List.length (fst (Ast.curried_layers abs)) - 1 in
    exists_ty (fun param_ty ->
        exists_tys inner_layers (fun inner_params ->
            exists_ty (fun result_ty ->
                let (Ast.CompTy (body_ty, body_eps) as body_comp_ty) =
                  List.fold_right
                    (fun a cty -> Ast.CompTy (Ast.TyArrow (a, cty), Eps.unit))
                    inner_params
                    (Ast.CompTy (result_ty, eps))
                in
                let arrow = Ast.TyArrow (param_ty, body_comp_ty) in
                let because =
                  Reason.because at (Reason.Recursive_definition f)
                in
                C.conj
                  (sub_expected at arrow expected)
                  (with_pattern
                     (recursive_env env at f arrow)
                     pat
                     (expect param_ty
                        (Reason.because pat.Ast.at Reason.Function_parameter))
                     (fun env' ->
                       generate_computation env' body (expect body_ty because)
                         (expect body_eps because))))))

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
                        {
                          grade = Rho.map input_eps;
                          at;
                          kind = Reason.Handled;
                          declared = None;
                        }
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
        {
          grade = Rho.top;
          at = case_at;
          kind = Reason.Clause_lock clause;
          declared = None;
        }
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
    | Ast.Delay (q, c') ->
        (* [delay q c]: [c] under the lock [⟨q⟩], the effect [q · ε] below the
           expected one *)
        let d = delay q in
        exists_eps (fun eps' ->
            let kind = Reason.Delayed q in
            C.conj
              (generate_computation
                 (lock env
                    { grade = Rho.of_delay d; at; kind; declared = None })
                 c' ty
                 (expect eps'
                    (Reason.because c'.Ast.at (Reason.Continuation_effect kind))))
              (leq_expected at (Eps.mul (Eps.of_delay d) eps') eps))
    | Ast.Box (rho, e, (pat, c')) ->
        box env at (open_rho env rho) e pat c' ty eps
    | Ast.Unbox (e, (pat, c')) -> unbox env at e pat c' ty eps
    | Ast.Perform (op, e, (pat, c')) -> perform env at op e pat c' ty eps
    | Ast.Handle (c', h) -> handle env at c' h ty eps

  (* [let p = c₁ in c₂]: the continuation under the lock [⟨∣ε₁∣⟩], the effect
     [ε₁ · ε₂] below the expected one. *)
  and sequence env at c1 pat c2 ty eps =
    exists_ty (fun ty1 ->
        exists_eps (fun eps1 ->
            exists_eps (fun eps2 ->
                let kind, declared = sequenced_kind env c1 in
                let bound =
                  Reason.because c1.Ast.at
                    (Reason.Sequencing (pattern_variable pat))
                in
                let env' =
                  lock env
                    { grade = Rho.map eps1; at = c1.Ast.at; kind; declared }
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
                       {
                         func_at = e1.Ast.at;
                         arg_at = e2.Ast.at;
                         func = expression_variable e1;
                         arg = expression_variable e2;
                       })
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
     a shared type and effect below the expected ones. A match without cases
     has a scrutinee of type [empty]. *)
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
                let because =
                  Reason.because scrutinee_at
                    (Reason.Match_scrutinee { scrutinee_at })
                in
                let empty =
                  match cases with
                  | [] ->
                      [
                        sub_expected scrutinee_at scrutinee_ty
                          (expect (Ast.TyApply (Ast.empty_ty_name, [])) because);
                      ]
                  | _ :: _ -> []
                in
                C.conj_all
                  (generate_expression env e (expect scrutinee_ty because)
                  :: sub_expected at branch_ty ty
                  :: leq_expected at branch_eps eps
                  :: (empty @ List.map branch cases)))))

  (* [box ρ e as p in c]: the payload under the lock [⟨ρ⟩], the pattern
     against [[ρ] α]. *)
  and box env at rho e pat c' ty eps =
    exists_ty (fun payload_ty ->
        let because = Reason.because at Reason.Boxed_value in
        C.conj
          (generate_expression
             (lock env
                { grade = rho; at; kind = Reason.Boxed; declared = None })
             e
             (expect payload_ty because))
          (with_pattern env pat
             (expect (Ast.TyBox (rho, payload_ty)) because)
             (fun env' -> generate_computation env' c' ty eps)))

  (* [unbox x as p in c], of a variable only: its type is a box [[r] α] whose
     grade covers the grade accumulated since its binding, the pattern against
     [α]. An annotation [(x : A)] requires the type of [x] to be a subtype of
     [A]; the box unboxed is that of [x]. *)
  and unbox env at e pat c' ty eps =
    let rec find_var (e : expression) =
      match e.Ast.it with
      | Ast.Var x -> (x, e.Ast.at, [])
      | Ast.Annotated (e', ann) ->
          let x, var_at, anns = find_var e' in
          (x, var_at, (e'.Ast.at, e.Ast.at, ann) :: anns)
      | _ -> Error.typing ~loc:e.Ast.at "Only a variable can be unboxed"
    in
    let x, var_at, anns = find_var e in
    let var_ty, bound_at, locks, instance =
      match lookup ~loc:var_at env x with
      | Local { ty; bound_at; locks } -> (ty, Some bound_at, locks, C.True)
      | Persistent_local { ty; bound_at } -> (ty, Some bound_at, [], C.True)
      | Global { scheme; defined_at } ->
          let ty, qualifier = C.instantiate scheme in
          ( ty,
            defined_at,
            all_locks env,
            instance_of var_at x defined_at qualifier )
    in
    let _, annotations =
      List.fold_right
        (fun (inner_at, ann_at, ann) (inner_ty, atoms) ->
          let ann = open_ty env ann in
          ( ann,
            sub_expected inner_at inner_ty
              (expect ann (Reason.because ann_at Reason.Annotation))
            :: atoms ))
        anns (var_ty, [])
    in
    exists_ty (fun payload_ty ->
        exists_rho (fun rho ->
            let because =
              Reason.because at (Reason.Unboxed { var = x; bound_at; locks })
            in
            C.conj_all
              (annotations
              @ [
                  C.equal_ty because var_ty (Ast.TyBox (rho, payload_ty));
                  C.Rho_leq (because, accumulated_grade locks, rho);
                  with_pattern env pat
                    (expect payload_ty
                       (Reason.because pat.Ast.at
                          (Reason.Unboxed { var = x; bound_at; locks })))
                    (fun env' -> generate_computation env' c' ty eps);
                  instance;
                ])))

  (* [perform op e]: the continuation under the lock [⟨∣op∣⟩], the effect
     [op · ε] below the expected one. *)
  and perform env at op e pat c' ty eps =
    let { param; arity; op_grade; signature_at } = signature ~loc:at env op in
    exists_eps (fun eps' ->
        let kind = Reason.Performed op in
        let env' =
          lock env { grade = Rho.map op_grade; at; kind; declared = None }
        in
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

  (* [with_annotation_vars result c] is [c] in the scope of the type and
     grade variables of the annotations of a command, the unknowns free in [c]
     but not in [result]: they are unknowns of the whole command. *)
  let with_annotation_vars (result : C.free) c =
    let free = C.free_vars c in
    C.exists
      {
        ty_vars =
          Ast.TyParamSet.elements
            (Ast.TyParamSet.diff free.free_tys result.free_tys);
        rho_vars =
          X.Rho_var.Set.elements
            (X.Rho_var.Set.diff free.free_rhos result.free_rhos);
        eps_vars =
          X.Eps_var.Set.elements
            (X.Eps_var.Set.diff free.free_eps result.free_eps);
      }
      c

  let generate_top_let env ~loc x e =
    let a = Ast.TyParam (Ast.TyParamModule.fresh "ty") in
    ( a,
      with_annotation_vars (C.free_vars_ty a)
        (generate_expression env e
           (expect a (Reason.because loc (Reason.Top_definition x)))) )

  let generate_run env ~loc c =
    let a = Ast.TyParam (Ast.TyParamModule.fresh "ty") in
    let eps = Eps.var (X.Eps_var.fresh_indexed ()) in
    let because = Reason.because loc Reason.Top_computation in
    let comp_ty = Ast.CompTy (a, eps) in
    ( comp_ty,
      with_annotation_vars
        (C.free_vars_comp_ty comp_ty)
        (generate_computation env c (expect a because) (expect eps because)) )

  (* The constraint that [(pat, body)] at [loc] is a function from the
     parameter of the operation [op] of signature [signature] to its result
     type, of effect below [eps], under the lock [⟨⊤⟩]. *)
  let default_constraint env ~loc op signature (pat, body) eps =
    let clause =
      { Reason.op; signature_at = signature.signature_at; case_at = loc }
    in
    let env' =
      lock env
        {
          grade = Rho.top;
          at = loc;
          kind = Reason.Clause_lock clause;
          declared = None;
        }
    in
    let default =
      Reason.because loc
        (Reason.Default_of { op; signature_at = signature.signature_at })
    in
    with_pattern env' pat
      (expect signature.param (Reason.step Reason.Argument default))
      (fun env'' ->
        generate_computation env'' body
          (expect signature.arity (Reason.step Reason.Result default))
          (expect eps (Reason.step Reason.Effect default)))

  (* The signature of the operation [op] of a default implementation at [loc]. *)
  let signature_of_default env ~loc op =
    match find_op_signature env op with
    | Some signature -> signature
    | None ->
        Error.typing ~loc "unknown operation `%s`" (Ast.OpName.string_of op)

  let generate_default env ~loc op abs =
    let op_name = Ast.OpName.string_of op in
    let signature = signature_of_default env ~loc op in
    if Ast.OpNameMap.mem op env.op_defaults then
      Error.typing ~loc "operation `%s` already has a default implementation"
        op_name;
    (match signature.op_grade with
    | X.Eps_const c when not (GS.E.is_atomic op_name c) ->
        Error.typing ~loc
          "a default implementation may only be given for an atomic operation, \
           but the grade of `%s` is `%s`; handle it with a handler in terms of \
           the operations it names"
          op_name (GS.E.show c)
    | X.Eps_const _ | X.Eps_var _ | X.Eps_mul _ | X.Eps_join _ -> ());
    let bound =
      match StringMap.find_opt op_name env.op_bounds with
      | Some (lo, hi) ->
          let read =
            Grades.Grade.map_end (Grades.Grade.read_bound GS.E.Delay.read)
          in
          Eps.const (GS.E.of_bounds (read lo, read hi))
      | None -> signature.op_grade
    in
    with_annotation_vars C.no_free
      (default_constraint env ~loc op signature abs bound)

  let generate_default_effect env ~loc op abs =
    let signature = signature_of_default env ~loc op in
    let eps = Eps.var (X.Eps_var.fresh_indexed ()) in
    let ty = Ast.TyArrow (signature.param, Ast.CompTy (signature.arity, eps)) in
    ( ty,
      with_annotation_vars (C.free_vars_ty ty)
        (default_constraint env ~loc op signature abs eps) )

  let check_default_duration env ~loc op grade =
    let op_name = Ast.OpName.string_of op in
    match
      ( StringMap.find_opt op_name env.op_bounds,
        GS.E.implied_bounds (running_times ~loc env) grade )
    with
    | Some (lo, hi), Some (lo', hi')
      when Grades.Grade.compare_ends ~lower:true lo lo' > 0
           || Grades.Grade.compare_ends ~lower:false hi' hi > 0 ->
        let show (lo, hi) =
          Grades.Grade.show_interval Grades.Rational.show lo hi
        in
        let labels =
          Option.to_list
            (Option.map
               (fun { signature_at; _ } ->
                 {
                   Utils.Diagnostic.span = signature_at;
                   text =
                     "operation `" ^ op_name ^ "` is declared "
                     ^ Utils.Diagnostic.place;
                 })
               (find_op_signature env op))
        in
        Error.typing ~loc ~labels
          "The default implementation of `%s` takes a duration in `%s`, which \
           is not within the running-time bounds `%s` of `%s`"
          op_name
          (show (lo', hi'))
          (show (lo, hi))
          op_name
    | Some _, Some _ | None, _ | _, None -> ()
end
