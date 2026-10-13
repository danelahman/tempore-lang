module Ast = Language.Ast
module Const = Language.Const
module Primitives = Language.Primitives
module Location = Utils.Location
module Error = Utils.Error
module IntMap = Map.Make (Int)
module LabelMap = Map.Make (Ast.Label)

type ty =
  | Nat
  | Int
  | Float
  | Bool
  | String
  | Tuple of ty list
  | Data of Ast.ty_name
  | Meta of int

let rank = function
  | Nat -> 0
  | Int -> 1
  | Float -> 2
  | Bool -> 3
  | String -> 4
  | Tuple _ -> 5
  | Data _ -> 6
  | Meta _ -> 7

let rec compare_ty t1 t2 =
  match (t1, t2) with
  | Tuple ts1, Tuple ts2 -> List.compare compare_ty ts1 ts2
  | Data n1, Data n2 -> Ast.TyName.compare n1 n2
  | Meta i1, Meta i2 -> Int.compare i1 i2
  | _ -> Int.compare (rank t1) (rank t2)

let rec substitute f = function
  | Meta i as ty -> Option.value (f i) ~default:ty
  | Tuple tys -> Tuple (List.map (substitute f) tys)
  | (Nat | Int | Float | Bool | String | Data _) as ty -> ty

type global = { variable : Ast.variable; instance : ty list }

type value = { value : value_node; ty : ty }

and value_node =
  | Local of Ast.variable
  | Global of global
  | Constant of Const.t
  | Tuple_value of value list
  | Construct of Ast.label * value option

type pattern = { pattern : pattern_node; pattern_ty : ty }

and pattern_node =
  | PVar of Ast.variable
  | PAs of pattern * Ast.variable
  | PTuple of pattern list
  | PConstruct of Ast.label * pattern option
  | PConstant of Const.t
  | PSucc of pattern * Z.t
  | PAny

type callee = Self | Function of global | Primitive of Primitives.primitive

type computation = { computation : computation_node; result : ty }

and computation_node =
  | Return of value
  | Bind of pattern * computation * computation
  | Match of value * (pattern * computation) list
  | Call of callee * value list
  | Perform of Ast.operation * value
  | Delay of Grades.Rational.t * computation

type body =
  | Function_body of {
      parameters : pattern list;
      body : computation;
      recursive : bool;
    }
  | Constant_body of value

type definition = {
  variable : Ast.variable;
  at : Location.t;
  in_sources : bool;
  quantified : int list;
  definition_body : body;
}

type datatype = {
  type_name : Ast.ty_name;
  constructors : (Ast.label * ty option) list;
  type_at : Location.t;
}

type operation = { operation : Ast.operation; argument : ty; result_ty : ty }

type program = {
  definitions : definition list;
  runs : computation list;
  datatypes : datatype list;
  operations : operation list;
}

(* Rejections. *)

let unsupported at fmt =
  Error.compilation ~loc:at ("The Arduino backend does not support " ^^ fmt)

(* The largest natural number of 32 bits. *)
let max_nat = Z.of_string "4294967295"
let fits_nat n = Z.leq Z.zero n && Z.leq n max_nat

(* Whether an integer is of 32 bits in two's complement. *)
let fits_int n =
  Z.leq (Z.of_string "-2147483648") n && Z.leq n (Z.of_string "2147483647")

(* Maps of the types of terms. *)

let rec map_value f v =
  let value =
    match v.value with
    | (Local _ | Constant _) as node -> node
    | Global g -> Global { g with instance = List.map f g.instance }
    | Tuple_value vs -> Tuple_value (List.map (map_value f) vs)
    | Construct (l, arg) -> Construct (l, Option.map (map_value f) arg)
  in
  { value; ty = f v.ty }

let rec map_pattern f p =
  let pattern =
    match p.pattern with
    | (PVar _ | PConstant _ | PAny) as node -> node
    | PAs (p, x) -> PAs (map_pattern f p, x)
    | PTuple ps -> PTuple (List.map (map_pattern f) ps)
    | PConstruct (l, arg) -> PConstruct (l, Option.map (map_pattern f) arg)
    | PSucc (p, k) -> PSucc (map_pattern f p, k)
  in
  { pattern; pattern_ty = f p.pattern_ty }

let map_callee f = function
  | Function g -> Function { g with instance = List.map f g.instance }
  | (Self | Primitive _) as callee -> callee

let rec map_computation f c =
  let computation =
    match c.computation with
    | Return v -> Return (map_value f v)
    | Bind (p, c1, c2) ->
        Bind (map_pattern f p, map_computation f c1, map_computation f c2)
    | Match (v, cases) ->
        Match
          ( map_value f v,
            List.map
              (fun (p, c) -> (map_pattern f p, map_computation f c))
              cases )
    | Call (callee, vs) -> Call (map_callee f callee, List.map (map_value f) vs)
    | Perform (op, v) -> Perform (op, map_value f v)
    | Delay (q, c) -> Delay (q, map_computation f c)
  in
  { computation; result = f c.result }

let map_body f = function
  | Function_body { parameters; body; recursive } ->
      Function_body
        {
          parameters = List.map (map_pattern f) parameters;
          body = map_computation f body;
          recursive;
        }
  | Constant_body v -> Constant_body (map_value f v)

let rec calls_self c =
  match c.computation with
  | Call (Self, _) -> true
  | Return _ | Call _ | Perform _ -> false
  | Bind (_, c1, c2) -> calls_self c1 || calls_self c2
  | Match (_, cases) -> List.exists (fun (_, c) -> calls_self c) cases
  | Delay (_, c) -> calls_self c

(* The reconstruction of types. A term of a function type, which is a
   top-level function, the function being defined or a primitive, is kept as
   the callee of an application missing the arguments of [remaining]. *)

type partial = {
  callee : callee;
  name : string;
  arguments : value list;
  remaining : ty list;
  partial_result : ty;
}

type local = Value of ty | Partial of partial

type state = {
  substitution : ty IntMap.t;
  next : int;
  type_parameters : ty Ast.TyParamMap.t;
      (** the types of the type parameters of the annotations of the definition
          being reconstructed *)
  definitions : definition Ast.VariableMap.t;
  order : definition list;  (** the definitions, the last first *)
  performed : (ty * ty) Ast.OpNameMap.t;
}

type ('rho, 'eps) environment = {
  commands :
    (Location.t * bool * ('rho, 'eps) Ast.expression) Ast.VariableMap.t;
      (** the top-level definitions: location, whether in the sources, and
          expression *)
  aliases : (Ast.ty_param list * ('rho, 'eps) Ast.ty) Ast.TyNameMap.t;
  sums :
    (Ast.ty_param list
    * (Ast.label * ('rho, 'eps) Ast.ty option) list
    * Location.t)
    Ast.TyNameMap.t;
  labels : Ast.ty_name LabelMap.t;
  signatures : (('rho, 'eps) Ast.ty * ('rho, 'eps) Ast.ty) Ast.OpNameMap.t;
  locals : local Ast.VariableMap.t;
  self : (Ast.variable * ty list * ty) option;
      (** the recursive function being defined, its parameter and result types
      *)
}

let fresh st = (Meta st.next, { st with next = st.next + 1 })

let rec resolve st = function
  | Meta i as ty -> (
      match IntMap.find_opt i st.substitution with
      | Some ty -> resolve st ty
      | None -> ty)
  | ty -> ty

(* [ty] with its type variables replaced by their types in [st]. *)
let rec substituted st ty =
  match resolve st ty with
  | Tuple tys -> Tuple (List.map (substituted st) tys)
  | ty -> ty

(* Whether a converted type has a string component. *)
let rec has_string = function
  | String -> true
  | Tuple tys -> List.exists has_string tys
  | Nat | Int | Float | Bool | Data _ | Meta _ -> false

let rec occurs st i ty =
  match resolve st ty with
  | Meta j -> i = j
  | Tuple tys -> List.exists (occurs st i) tys
  | Nat | Int | Float | Bool | String | Data _ -> false

(* Unification, by a substitution of the type variables. *)
let rec unify st ty1 ty2 =
  match (resolve st ty1, resolve st ty2) with
  | Meta i, Meta j when i = j -> Some st
  | Meta i, ty | ty, Meta i ->
      if occurs st i ty then None
      else Some { st with substitution = IntMap.add i ty st.substitution }
  | Nat, Nat | Int, Int | Float, Float | Bool, Bool | String, String -> Some st
  | Data n1, Data n2 when Ast.TyName.equal n1 n2 -> Some st
  | Tuple tys1, Tuple tys2 when List.compare_lengths tys1 tys2 = 0 ->
      List.fold_left2
        (fun st ty1 ty2 -> Option.bind st (fun st -> unify st ty1 ty2))
        (Some st) tys1 tys2
  | _ -> None

let unify_at at st ty1 ty2 =
  match unify st ty1 ty2 with
  | Some st -> st
  | None ->
      Error.compilation ~loc:at
        "The Arduino backend cannot assign a single type to this term"

(* Types of the source. *)

exception Unsupported_type of string

let ty_name_string = Ast.TyName.string_of

(* [convert env ~visiting st ty] is the type of the fragment of [ty], with
   the type parameters of annotations given types by [st]. The datatypes in
   [visiting] are those whose definitions are being converted. *)
let rec convert env ?(visiting = Ast.TyNameSet.empty) st (ty : _ Ast.ty) =
  match ty with
  | Ast.TyConst Const.NatTy -> (st, Nat)
  | Ast.TyConst Const.IntTy -> (st, Int)
  | Ast.TyConst Const.FloatTy -> (st, Float)
  | Ast.TyConst Const.BooleanTy -> (st, Bool)
  | Ast.TyConst Const.StringTy -> (st, String)
  | Ast.TyTuple tys ->
      let st, tys = List.fold_left_map (convert env ~visiting) st tys in
      (st, Tuple tys)
  | Ast.TyBox (_, ty) -> convert env ~visiting st ty
  | Ast.TyParam a -> (
      match Ast.TyParamMap.find_opt a st.type_parameters with
      | Some ty -> (st, ty)
      | None ->
          let ty, st = fresh st in
          ( {
              st with
              type_parameters = Ast.TyParamMap.add a ty st.type_parameters;
            },
            ty ))
  | Ast.TyArrow _ -> raise (Unsupported_type "function types")
  | Ast.TyHandler _ -> raise (Unsupported_type "handler types")
  | Ast.TyApply (name, args) -> (
      let builtin =
        [
          (Ast.bool_ty_name, Bool);
          (Ast.nat_ty_name, Nat);
          (Ast.unit_ty_name, Tuple []);
          (Ast.string_ty_name, String);
          (Ast.float_ty_name, Float);
          (Ast.int_ty_name, Int);
        ]
      in
      match List.find_opt (fun (n, _) -> Ast.TyName.equal n name) builtin with
      | Some (_, ty) -> (st, ty)
      | None when Ast.TyName.equal name Ast.list_ty_name ->
          raise (Unsupported_type "lists")
      | None -> (
          match
            ( Ast.TyNameMap.find_opt name env.aliases,
              Ast.TyNameMap.find_opt name env.sums )
          with
          | Some (params, body), _ ->
              let subst =
                List.fold_left2
                  (fun subst a ty -> Ast.TyParamMap.add a ty subst)
                  Ast.TyParamMap.empty params args
              in
              convert env ~visiting st
                (Ast.substitute_ty subst ~on_rho:Fun.id ~on_eps:Fun.id body)
          | None, Some (_ :: _, _, _) ->
              raise
                (Unsupported_type
                   (Printf.sprintf "the type `%s`, which has type parameters"
                      (ty_name_string name)))
          | None, Some ([], constructors, _) ->
              if Ast.TyNameSet.mem name visiting then
                raise
                  (Unsupported_type
                     (Printf.sprintf "the recursive type `%s`"
                        (ty_name_string name)));
              let visiting = Ast.TyNameSet.add name visiting in
              List.iter
                (fun (_, arg) ->
                  Option.iter
                    (fun ty ->
                      if has_string (snd (convert env ~visiting st ty)) then
                        raise
                          (Unsupported_type
                             (Printf.sprintf
                                "the type `%s`, whose constructors take strings"
                                (ty_name_string name))))
                    arg)
                constructors;
              (st, Data name)
          | None, None ->
              raise
                (Unsupported_type
                   (Printf.sprintf "the type `%s`" (ty_name_string name)))))

let convert_at at env st ty =
  try convert env st ty with Unsupported_type what -> unsupported at "%s" what

(* An annotation constrains the type when the type is in the fragment. *)
let annotate at env st ty annotation =
  match convert env st annotation with
  | st, annotated -> unify_at at st ty annotated
  | exception Unsupported_type _ -> st

(* The datatype of the constructor [l] and the type of its argument, if any. *)
let constructor at env st l =
  if Ast.Label.equal l Ast.nil_label || Ast.Label.equal l Ast.cons_label then
    unsupported at "lists";
  let name = LabelMap.find l env.labels in
  let st, data = convert_at at env st (Ast.TyApply (name, [])) in
  let _, constructors, _ = Ast.TyNameMap.find name env.sums in
  let _, arg = List.find (fun (l', _) -> Ast.Label.equal l l') constructors in
  match arg with
  | None -> (st, data, None)
  | Some ty ->
      let st, ty = convert_at at env st ty in
      (st, data, Some ty)

let constant_ty at ~strings = function
  | Const.Nat n ->
      if not (fits_nat n) then
        unsupported at "the natural number literal `%s`, which exceeds 32 bits"
          (Z.to_string n);
      Nat
  | Const.Int n ->
      if not (fits_int n) then
        unsupported at "the integer literal `%si`, which exceeds 32 bits"
          (Z.to_string n);
      Int
  | Const.Float _ -> Float
  | Const.Boolean _ -> Bool
  | Const.String _ ->
      if not strings then
        unsupported at "strings other than constant arguments of operations";
      String

let primitive_of x =
  List.find_opt
    (fun p -> Primitives.primitive_name p = Ast.Variable.string_of x)
    Primitives.primitives

(* The parameter and result types of a primitive. *)
let primitive_signature at st = function
  | Primitives.CompareEq | Primitives.CompareLt | Primitives.CompareGt
  | Primitives.CompareLe | Primitives.CompareGe | Primitives.CompareNe ->
      let a, st = fresh st in
      (st, Tuple [ a; a ], Bool)
  | Primitives.NatAdd | Primitives.NatMul | Primitives.NatSub
  | Primitives.NatDiv | Primitives.NatMod ->
      (st, Tuple [ Nat; Nat ], Nat)
  | Primitives.FloatAdd | Primitives.FloatMul | Primitives.FloatSub
  | Primitives.FloatDiv | Primitives.FloatPow | Primitives.FloatAtan2 ->
      (st, Tuple [ Float; Float ], Float)
  | Primitives.FloatNeg | Primitives.FloatSqrt | Primitives.FloatAtan ->
      (st, Float, Float)
  | Primitives.FloatOfNat -> (st, Nat, Float)
  | Primitives.NatOfFloat -> (st, Float, Nat)
  | Primitives.IntAdd | Primitives.IntMul | Primitives.IntSub
  | Primitives.IntDiv | Primitives.IntMod ->
      (st, Tuple [ Int; Int ], Int)
  | Primitives.IntNeg -> (st, Int, Int)
  | Primitives.IntOfNat -> (st, Nat, Int)
  | Primitives.NatOfInt -> (st, Int, Nat)
  | Primitives.FloatOfInt -> (st, Int, Float)
  | Primitives.IntOfFloat -> (st, Float, Int)
  | Primitives.ToString -> unsupported at "`to_string`"

(* The types of the parameters and the result of a definition. *)
let signature d =
  match d.definition_body with
  | Function_body { parameters; body; _ } ->
      (List.map (fun p -> p.pattern_ty) parameters, body.result)
  | Constant_body v -> ([], v.ty)

(* A use of the definition [d] at fresh types of its quantified variables,
   with its parameter and result types at them. *)
let instantiate st d =
  let st, instance =
    List.fold_left_map
      (fun st _ ->
        let ty, st = fresh st in
        (st, ty))
      st d.quantified
  in
  let assoc = List.combine d.quantified instance in
  let f i = List.assoc_opt i assoc in
  let params, result = signature d in
  ( st,
    { variable = d.variable; instance },
    List.map (substitute f) params,
    substitute f result )

(* The type variables of [ty], prepended to [acc] unless already in it. *)
let rec metas acc ty =
  match ty with
  | Meta i -> if List.mem i acc then acc else i :: acc
  | Tuple tys -> List.fold_left metas acc tys
  | Nat | Int | Float | Bool | String | Data _ -> acc

let rec strip_expression (e : _ Ast.expression) =
  match e.it with Ast.Annotated (e, _) -> strip_expression e | _ -> e

let rec strip_pattern (p : _ Ast.pattern) =
  match p.it with Ast.PAnnotated (p, _) -> strip_pattern p | _ -> p

(* A term bound to a variable: a value, or a function. *)
type resolved = Resolved_value of value | Resolved_function of partial

(* A computation: one of the fragment, or a function, which only the bound
   computation of a [do] may be. *)
type elaborated = Computed of computation | Applied of partial * Location.t

let reject_function p at =
  match p.arguments with
  | [] -> unsupported at "the function `%s` used as a value" p.name
  | _ :: _ -> unsupported at "the partial application of `%s`" p.name

let as_computation = function
  | Computed c -> c
  | Applied (p, at) -> reject_function p at

let add_local x local env =
  { env with locals = Ast.VariableMap.add x local env.locals }

let rec resolve_variable env st at x =
  let name = Ast.Variable.string_of x in
  let function_value callee params result =
    Resolved_function
      {
        callee;
        name;
        arguments = [];
        remaining = params;
        partial_result = result;
      }
  in
  match Ast.VariableMap.find_opt x env.locals with
  | Some (Value ty) -> (st, Resolved_value { value = Local x; ty })
  | Some (Partial p) -> (st, Resolved_function p)
  | None -> (
      match (env.self, Ast.VariableMap.mem x env.commands, primitive_of x) with
      | Some (f, params, result), _, _ when Ast.Variable.equal f x ->
          (st, function_value Self params result)
      | _, true, _ -> (
          let st, d = ensure env st x in
          let st, g, params, result = instantiate st d in
          match d.definition_body with
          | Function_body _ -> (st, function_value (Function g) params result)
          | Constant_body _ ->
              (st, Resolved_value { value = Global g; ty = result }))
      | _, false, Some p ->
          let st, param, result = primitive_signature at st p in
          (st, function_value (Primitive p) [ param ] result)
      | _, false, None -> invalid_arg ("unbound variable " ^ name))

(* The top-level definition [x], reconstructed first if it is not yet. *)
and ensure env st x =
  match Ast.VariableMap.find_opt x st.definitions with
  | Some d -> (st, d)
  | None ->
      let at, in_sources, e = Ast.VariableMap.find x env.commands in
      define env st x at in_sources e

(* The reconstruction of the top-level definition [x] of [e], generalised
   over the type variables of its type. *)
and define env st x at in_sources e =
  let saved = st.type_parameters in
  let st = { st with type_parameters = Ast.TyParamMap.empty } in
  let env = { env with locals = Ast.VariableMap.empty; self = None } in
  let st, definition_body =
    match (strip_expression e).it with
    | Ast.Lambda abs | Ast.PureLambda abs -> function_body env st None abs
    | Ast.RecLambda (f, _, abs) -> function_body env st (Some f) abs
    | _ ->
        let st, v = value env st e in
        (st, Constant_body v)
  in
  let definition_body = map_body (substituted st) definition_body in
  let d = { variable = x; at; in_sources; quantified = []; definition_body } in
  let params, result = signature d in
  let d =
    {
      d with
      quantified = List.rev (List.fold_left metas [] (params @ [ result ]));
    }
  in
  ( {
      st with
      type_parameters = saved;
      definitions = Ast.VariableMap.add x d st.definitions;
      order = d :: st.order;
    },
    d )

and function_body env st self abs =
  let params, body = Ast.curried_layers abs in
  let st, env, parameters =
    List.fold_left
      (fun (st, env, parameters) p ->
        let ty, st = fresh st in
        let st, p, env = pattern env st p ty in
        (st, env, p :: parameters))
      (st, env, []) params
  in
  let parameters = List.rev parameters in
  let result, st = fresh st in
  let env =
    {
      env with
      self =
        Option.map
          (fun f -> (f, List.map (fun p -> p.pattern_ty) parameters, result))
          self;
    }
  in
  let st, elaborated = computation env st ~tail:true body in
  let body = as_computation elaborated in
  let st = unify_at (snd abs).at st result body.result in
  (st, Function_body { parameters; body; recursive = calls_self body })

and value ?(strings = false) env st (e : _ Ast.expression) =
  match e.it with
  | Ast.Var x -> (
      match resolve_variable env st e.at x with
      | st, Resolved_value v -> (st, v)
      | _, Resolved_function p -> reject_function p e.at)
  | Ast.Const c -> (st, { value = Constant c; ty = constant_ty e.at ~strings c })
  | Ast.Annotated (e', annotation) ->
      let st, v = value ~strings env st e' in
      (annotate e.at env st v.ty annotation, v)
  | Ast.Tuple es ->
      let st, vs = List.fold_left_map (value ~strings env) st es in
      (st, { value = Tuple_value vs; ty = Tuple (List.map (fun v -> v.ty) vs) })
  | Ast.Variant (l, arg) -> (
      let st, data, arg_ty = constructor e.at env st l in
      match (arg, arg_ty) with
      | Some arg, Some arg_ty ->
          let st, v = value ~strings env st arg in
          let st = unify_at arg.at st arg_ty v.ty in
          (st, { value = Construct (l, Some v); ty = data })
      | _ -> (st, { value = Construct (l, None); ty = data }))
  | Ast.Lambda _ | Ast.PureLambda _ | Ast.RecLambda _ ->
      unsupported e.at "functions other than top-level definitions"
  | Ast.Handler _ -> unsupported e.at "handlers"

and pattern env st (p : _ Ast.pattern) ty =
  let make st node env = (st, { pattern = node; pattern_ty = ty }, env) in
  match p.it with
  | Ast.PVar x -> make st (PVar x) (add_local x (Value ty) env)
  | Ast.PAnnotated (p', annotation) ->
      pattern env (annotate p.at env st ty annotation) p' ty
  | Ast.PAs (p', x) ->
      let st, p', env = pattern env st p' ty in
      make st (PAs (p', x)) (add_local x (Value ty) env)
  | Ast.PTuple ps ->
      let st, tys =
        List.fold_left_map
          (fun st _ ->
            let ty, st = fresh st in
            (st, ty))
          st ps
      in
      let st = unify_at p.at st ty (Tuple tys) in
      let (st, env), ps =
        List.fold_left_map
          (fun (st, env) (p, ty) ->
            let st, p, env = pattern env st p ty in
            ((st, env), p))
          (st, env) (List.combine ps tys)
      in
      make st (PTuple ps) env
  | Ast.PVariant (l, arg) -> (
      let st, data, arg_ty = constructor p.at env st l in
      let st = unify_at p.at st ty data in
      match (arg, arg_ty) with
      | Some arg, Some arg_ty ->
          let st, arg, env = pattern env st arg arg_ty in
          make st (PConstruct (l, Some arg)) env
      | _ -> make st (PConstruct (l, None)) env)
  | Ast.PConst c ->
      let st = unify_at p.at st ty (constant_ty p.at ~strings:false c) in
      make st (PConstant c) env
  | Ast.PSucc (p', k) ->
      if not (fits_nat k) then
        unsupported p.at
          "the natural number literal `%s`, which exceeds 32 bits"
          (Z.to_string k);
      let st = unify_at p.at st ty Nat in
      let st, p', env = pattern env st p' Nat in
      make st (PSucc (p', k)) env
  | Ast.PNonbinding -> make st PAny env

(* A computation, [tail] if in tail position of the function being defined. *)
and computation env st ~tail (c : _ Ast.computation) =
  let located it = Ast.located c.at it in
  match c.it with
  | Ast.Return e -> (
      match (strip_expression e).it with
      | Ast.Var x -> (
          match resolve_variable env st e.at x with
          | st, Resolved_value v ->
              (st, Computed { computation = Return v; result = v.ty })
          | st, Resolved_function p -> (st, Applied (p, e.at)))
      | _ ->
          let st, v = value env st e in
          (st, Computed { computation = Return v; result = v.ty }))
  | Ast.Do ({ it = Ast.Do (c0, (p0, c1)); at }, abs) ->
      computation env st ~tail
        (located (Ast.Do (c0, (p0, Ast.located at (Ast.Do (c1, abs))))))
  | Ast.Do (c1, (p, c2)) -> (
      match computation env st ~tail:false c1 with
      | st, Applied (partial, at) -> (
          match (strip_pattern p).it with
          | Ast.PVar x ->
              computation (add_local x (Partial partial) env) st ~tail c2
          | Ast.PNonbinding -> computation env st ~tail c2
          | _ -> reject_function partial at)
      | st, Computed c1 -> bind env st ~tail p c1 c2)
  | Ast.Match (_, []) -> unsupported c.at "a match without cases"
  | Ast.Match (e, cases) ->
      let st, v = value env st e in
      let result, st = fresh st in
      let st, cases =
        List.fold_left_map
          (fun st (p, (body : _ Ast.computation)) ->
            let st, p, env = pattern env st p v.ty in
            let st, elaborated = computation env st ~tail body in
            let c = as_computation elaborated in
            (unify_at body.at st result c.result, (p, c)))
          st cases
      in
      (st, Computed { computation = Match (v, cases); result })
  | Ast.Apply (e1, e2) -> (
      match (strip_expression e1).it with
      | Ast.Lambda abs | Ast.PureLambda abs ->
          computation env st ~tail
            (located (Ast.Do (located (Ast.Return e2), abs)))
      | Ast.Var x -> (
          match resolve_variable env st e1.at x with
          | st, Resolved_function p -> apply env st ~tail c.at p e2
          | _, Resolved_value _ ->
              unsupported e1.at
                "the application of a function other than a top-level \
                 definition")
      | _ ->
          unsupported e1.at
            "the application of a function other than a top-level definition")
  | Ast.Delay (q, c') ->
      if
        not
          (fits_nat (Grades.Rational.num q) && fits_nat (Grades.Rational.den q))
      then
        unsupported c.at
          "the delay `%s`, whose numerator or denominator exceeds 32 bits"
          (Grades.Rational.show q);
      let st, c' = computation env st ~tail c' in
      let c' = as_computation c' in
      (st, Computed { computation = Delay (q, c'); result = c'.result })
  | Ast.Box (_, e, abs) | Ast.Unbox (e, abs) ->
      computation env st ~tail (located (Ast.Do (located (Ast.Return e), abs)))
  | Ast.Perform (op, e, (p, c')) ->
      let argument, result = Ast.OpNameMap.find op env.signatures in
      let st, argument = convert_at c.at env st argument in
      let st, result = convert_at c.at env st result in
      if has_string result then
        unsupported c.at "the operation `%s`, whose result contains a string"
          (Ast.OpName.string_of op);
      let st, v = value ~strings:true env st e in
      let st = unify_at e.at st argument v.ty in
      let st =
        {
          st with
          performed = Ast.OpNameMap.add op (argument, result) st.performed;
        }
      in
      bind env st ~tail p { computation = Perform (op, v); result } c'
  | Ast.Handle _ -> unsupported c.at "handlers"

(* The binding of the result of [c1] to [p] in [c2]; [do x <- c1 in return x]
   is [c1]. *)
and bind env st ~tail p c1 c2 =
  let st, p, env = pattern env st p c1.result in
  let st, c2 = computation env st ~tail c2 in
  let c2 = as_computation c2 in
  match (p.pattern, c2.computation) with
  | PVar x, Return { value = Local y; _ } when Ast.Variable.equal x y ->
      (st, Computed c1)
  | _ -> (st, Computed { computation = Bind (p, c1, c2); result = c2.result })

(* The application of the function [p] to [e]: a call once it has all its
   arguments. *)
and apply env st ~tail at p e =
  let st, v = value env st e in
  match p.remaining with
  | [] -> invalid_arg "application of a function without parameters"
  | ty :: remaining -> (
      let st = unify_at e.at st ty v.ty in
      let arguments = p.arguments @ [ v ] in
      match remaining with
      | [] ->
          (match p.callee with
          | Self when not tail ->
              unsupported at
                "the recursive call of `%s` outside a tail position" p.name
          | Self | Function _ | Primitive _ -> ());
          ( st,
            Computed
              {
                computation = Call (p.callee, arguments);
                result = p.partial_result;
              } )
      | _ -> (st, Applied ({ p with arguments; remaining }, at)))

let check ~runs ~library sources =
  let environment =
    let add_command env (in_sources, (cmd : _ Ast.command)) =
      match cmd.it with
      | Ast.TopLet (x, e) ->
          {
            env with
            commands =
              Ast.VariableMap.add x (cmd.at, in_sources, e) env.commands;
          }
      | Ast.TyDef (_, defs) ->
          List.fold_left
            (fun env (params, name, def) ->
              match def with
              | Ast.TyInline ty ->
                  {
                    env with
                    aliases = Ast.TyNameMap.add name (params, ty) env.aliases;
                  }
              | Ast.TySum constructors ->
                  {
                    env with
                    sums =
                      Ast.TyNameMap.add name
                        (params, constructors, cmd.at)
                        env.sums;
                    labels =
                      List.fold_left
                        (fun labels (l, _) -> LabelMap.add l name labels)
                        env.labels constructors;
                  })
            env defs
      | Ast.OpSig (op, ty1, ty2, _, _) ->
          {
            env with
            signatures = Ast.OpNameMap.add op (ty1, ty2) env.signatures;
          }
      | Ast.OpDefault _ | Ast.TopDo _ -> env
    in
    List.fold_left add_command
      {
        commands = Ast.VariableMap.empty;
        aliases = Ast.TyNameMap.empty;
        sums = Ast.TyNameMap.empty;
        labels = LabelMap.empty;
        signatures = Ast.OpNameMap.empty;
        locals = Ast.VariableMap.empty;
        self = None;
      }
      (List.map (fun c -> (false, c)) library
      @ List.map (fun c -> (true, c)) sources)
  in
  let initial =
    {
      substitution = IntMap.empty;
      next = 0;
      type_parameters = Ast.TyParamMap.empty;
      definitions = Ast.VariableMap.empty;
      order = [];
      performed = Ast.OpNameMap.empty;
    }
  in
  let st, runs_rev =
    List.fold_left
      (fun (st, runs_rev) (cmd : _ Ast.command) ->
        match cmd.it with
        | Ast.TopLet (x, _) -> (fst (ensure environment st x), runs_rev)
        | Ast.TopDo c when runs ->
            let st = { st with type_parameters = Ast.TyParamMap.empty } in
            let st, c = computation environment st ~tail:true c in
            let c = map_computation (substituted st) (as_computation c) in
            (st, c :: runs_rev)
        | Ast.TopDo _ | Ast.TyDef _ | Ast.OpSig _ | Ast.OpDefault _ ->
            (st, runs_rev))
      (initial, []) sources
  in
  let datatypes =
    Ast.TyNameMap.fold
      (fun type_name (params, _, type_at) acc ->
        match params with
        | _ :: _ -> acc
        | [] -> (
            match convert environment initial (Ast.TyApply (type_name, [])) with
            | exception Unsupported_type _ -> acc
            | _ ->
                let constructors =
                  let _, constructors, _ =
                    Ast.TyNameMap.find type_name environment.sums
                  in
                  List.sort
                    (fun (l1, _) (l2, _) -> Ast.Label.compare l1 l2)
                    (List.map
                       (fun (l, arg) ->
                         ( l,
                           Option.map
                             (fun ty -> snd (convert environment initial ty))
                             arg ))
                       constructors)
                in
                { type_name; constructors; type_at } :: acc))
      environment.sums []
  in
  {
    definitions = List.rev st.order;
    runs = List.rev runs_rev;
    datatypes;
    operations =
      List.map
        (fun (operation, (argument, result_ty)) ->
          { operation; argument; result_ty })
        (Ast.OpNameMap.bindings st.performed);
  }
