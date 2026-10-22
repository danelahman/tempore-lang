module Ast = Language.Ast
module Const = Language.Const
module Primitives = Language.Primitives
module Location = Utils.Location
module Error = Utils.Error
module IntMap = Map.Make (Int)
module LabelMap = Map.Make (Ast.Label)
module StringMap = Map.Make (String)

type ty =
  | Nat
  | Int
  | Float
  | Bool
  | String
  | Tuple of ty list
  | Data of Ast.ty_name
  | Arrow of ty * ty
  | Meta of int

let rank = function
  | Nat -> 0
  | Int -> 1
  | Float -> 2
  | Bool -> 3
  | String -> 4
  | Tuple _ -> 5
  | Data _ -> 6
  | Arrow _ -> 7
  | Meta _ -> 8

let rec compare_ty t1 t2 =
  match (t1, t2) with
  | Tuple ts1, Tuple ts2 -> List.compare compare_ty ts1 ts2
  | Data n1, Data n2 -> Ast.TyName.compare n1 n2
  | Arrow (a1, b1), Arrow (a2, b2) ->
      let c = compare_ty a1 a2 in
      if c <> 0 then c else compare_ty b1 b2
  | Meta i1, Meta i2 -> Int.compare i1 i2
  | _ -> Int.compare (rank t1) (rank t2)

let rec substitute f = function
  | Meta i as ty -> Option.value (f i) ~default:ty
  | Tuple tys -> Tuple (List.map (substitute f) tys)
  | Arrow (a, b) -> Arrow (substitute f a, substitute f b)
  | (Nat | Int | Float | Bool | String | Data _) as ty -> ty

type global = { variable : Ast.variable; instance : ty list }

type value = { value : value_node; ty : ty }

and value_node =
  | Local of Ast.variable
  | Global of global
  | Constant of Const.t
  | Tuple_value of value list
  | Construct of Ast.label * value option
  | Closure of closure

and closure = {
  closure_name : Ast.variable;
  closure_at : Location.t;
  environment : (Ast.variable * ty) list;
  closure_parameter : pattern;
  closure_body : computation;
}

and pattern = { pattern : pattern_node; pattern_ty : ty }

and pattern_node =
  | PVar of Ast.variable
  | PAs of pattern * Ast.variable
  | PTuple of pattern list
  | PConstruct of Ast.label * pattern option
  | PConstant of Const.t
  | PSucc of pattern * Z.t
  | PAny

and callee = Self | Function of global | Primitive of Primitives.primitive
and computation = { computation : computation_node; result : ty }

and computation_node =
  | Return of value
  | Bind of pattern * computation * computation
  | Match of value * (pattern * computation) list
  | Call of callee * value list
  | Apply of value * value
  | Perform of Ast.operation * value
  | Delay of Grades.Rational.t * computation
  | Handle of handler_use * computation

and handler_use = { source : handler_source; arguments : value list }
and handler_source = Defined of global | Inline of Ast.variable * handler

and handler = {
  handler_parameters : pattern list;
  return_case : pattern * computation;
  operation_cases : operation_case list;
}

and operation_case = {
  case_operation : Ast.operation;
  case_parameter : pattern;
  case_body : computation;
}

type body =
  | Function_body of {
      parameters : pattern list;
      body : computation;
      recursive : bool;
    }
  | Constant_body of value
  | Handler_body of handler

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
  entries : Ast.VariableSet.t;
  warnings : Utils.Diagnostic.t list;
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

let map_global f g = { g with instance = List.map f g.instance }

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
  | Function g -> Function (map_global f g)
  | (Self | Primitive _) as callee -> callee

let rec map_value f v =
  let value =
    match v.value with
    | (Local _ | Constant _) as node -> node
    | Global g -> Global (map_global f g)
    | Tuple_value vs -> Tuple_value (List.map (map_value f) vs)
    | Construct (l, arg) -> Construct (l, Option.map (map_value f) arg)
    | Closure k ->
        Closure
          {
            k with
            environment = List.map (fun (x, ty) -> (x, f ty)) k.environment;
            closure_parameter = map_pattern f k.closure_parameter;
            closure_body = map_computation f k.closure_body;
          }
  in
  { value; ty = f v.ty }

and map_computation f c =
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
    | Apply (v1, v2) -> Apply (map_value f v1, map_value f v2)
    | Perform (op, v) -> Perform (op, map_value f v)
    | Delay (q, c) -> Delay (q, map_computation f c)
    | Handle (u, c) -> Handle (map_handler_use f u, map_computation f c)
  in
  { computation; result = f c.result }

and map_handler_use f u =
  {
    source =
      (match u.source with
      | Defined g -> Defined (map_global f g)
      | Inline (x, h) -> Inline (x, map_handler f h));
    arguments = List.map (map_value f) u.arguments;
  }

and map_handler f h =
  let p, c = h.return_case in
  {
    handler_parameters = List.map (map_pattern f) h.handler_parameters;
    return_case = (map_pattern f p, map_computation f c);
    operation_cases =
      List.map
        (fun oc ->
          {
            oc with
            case_parameter = map_pattern f oc.case_parameter;
            case_body = map_computation f oc.case_body;
          })
        h.operation_cases;
  }

let map_body f = function
  | Function_body { parameters; body; recursive } ->
      Function_body
        {
          parameters = List.map (map_pattern f) parameters;
          body = map_computation f body;
          recursive;
        }
  | Constant_body v -> Constant_body (map_value f v)
  | Handler_body h -> Handler_body (map_handler f h)

let rec calls_self c =
  match c.computation with
  | Call (Self, _) -> true
  | Return _ | Call _ | Apply _ | Perform _ -> false
  | Bind (_, c1, c2) -> calls_self c1 || calls_self c2
  | Match (_, cases) -> List.exists (fun (_, c) -> calls_self c) cases
  | Delay (_, c) | Handle (_, c) -> calls_self c

(* The types of the input and the output of a handler. *)
let handler_types h =
  let p, c = h.return_case in
  (p.pattern_ty, c.result)

(* The reconstruction of types. A term of a function type, which is a
   top-level function, the function being defined, a primitive or a top-level
   handler of parameters, is kept as the target of an application missing the
   arguments of [remaining]. A handler known at compilation is kept with the
   types of its input and output. *)

type target =
  | Call_target of callee * ty  (** the callee and the type of its result *)
  | Handler_target of global * ty * ty
      (** the handler and the types of its input and output *)

type partial = {
  target : target;
  name : string;
  arguments : value list;
  remaining : ty list;
}

type known_handler = {
  use : handler_use;
  input : ty;
  output : ty;
  handler_name : string option;  (** the name of a top-level handler *)
}

type local = Value of ty | Partial of partial | Handler_local of known_handler

type state = {
  substitution : ty IntMap.t;
  next : int;
  type_parameters : ty Ast.TyParamMap.t;
      (** the types of the type parameters of the annotations of the definition
          being reconstructed *)
  definitions : definition Ast.VariableMap.t;
  order : definition list;  (** the definitions, the last first *)
  performed : (ty * ty) Ast.OpNameMap.t;
  comparisons : (Location.t * ty) list;
      (** the comparisons of the definition being reconstructed, each with the
          type of the compared values *)
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
  data : (unit, string) result Ast.TyNameMap.t;
      (** for each datatype without type parameters, whether it is in the
          fragment, or else why not *)
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
  | Arrow (a, b) -> Arrow (substituted st a, substituted st b)
  | ty -> ty

let rec has_string = function
  | String -> true
  | Tuple tys -> List.exists has_string tys
  | Arrow (a, b) -> has_string a || has_string b
  | Nat | Int | Float | Bool | Data _ | Meta _ -> false

let rec has_function = function
  | Arrow _ -> true
  | Tuple tys -> List.exists has_function tys
  | Nat | Int | Float | Bool | String | Data _ | Meta _ -> false

let rec occurs st i ty =
  match resolve st ty with
  | Meta j -> i = j
  | Tuple tys -> List.exists (occurs st i) tys
  | Arrow (a, b) -> occurs st i a || occurs st i b
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
  | Arrow (a1, b1), Arrow (a2, b2) ->
      Option.bind (unify st a1 a2) (fun st -> unify st b1 b2)
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

(* The types of the fragment named by the type names of the language. *)
let builtin_types =
  [
    (Ast.bool_ty_name, Bool);
    (Ast.nat_ty_name, Nat);
    (Ast.unit_ty_name, Tuple []);
    (Ast.string_ty_name, String);
    (Ast.float_ty_name, Float);
    (Ast.int_ty_name, Int);
  ]

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
  | Ast.TyArrow (a, Ast.CompTy (b, _)) ->
      let st, a = convert env ~visiting st a in
      let st, b = convert env ~visiting st b in
      (st, Arrow (a, b))
  | Ast.TyHandler _ -> raise (Unsupported_type "handler types")
  | Ast.TyApply (name, args) -> (
      match
        List.find_opt (fun (n, _) -> Ast.TyName.equal n name) builtin_types
      with
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
          | None, Some (params, constructors, _) ->
              (st, convert_sum env ~visiting st name params constructors)
          | None, None ->
              raise
                (Unsupported_type
                   (Printf.sprintf "the type `%s`" (ty_name_string name)))))

(* The datatype [name] of the type parameters [params] and the constructors
   [constructors], if it is in the fragment: without type parameters, not
   recursive, and without strings in the arguments of its constructors. The
   result of a datatype in [env.data] is taken from there. *)
and convert_sum env ~visiting st name params constructors =
  match (params, Ast.TyNameMap.find_opt name env.data) with
  | _ :: _, _ ->
      raise
        (Unsupported_type
           (Printf.sprintf "the type `%s`, which has type parameters"
              (ty_name_string name)))
  | [], Some (Ok ()) -> Data name
  | [], Some (Error what) -> raise (Unsupported_type what)
  | [], None ->
      if Ast.TyNameSet.mem name visiting then
        raise
          (Unsupported_type
             (Printf.sprintf "the recursive type `%s`" (ty_name_string name)));
      let visiting = Ast.TyNameSet.add name visiting in
      List.iter
        (fun (_, arg) ->
          Option.iter
            (fun ty ->
              let argument = snd (convert env ~visiting st ty) in
              let refuse what =
                raise
                  (Unsupported_type
                     (Printf.sprintf "the type `%s`, whose constructors take %s"
                        (ty_name_string name) what))
              in
              if has_string argument then refuse "strings";
              if has_function argument then refuse "functions")
            arg)
        constructors;
      Data name

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

let primitive_of x = Primitives.of_name (Ast.Variable.string_of x)

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

(* The types of the parameters of a definition, and of its result or, for a
   handler, of its input and output. *)
let signature d =
  match d.definition_body with
  | Function_body { parameters; body; _ } ->
      (List.map (fun p -> p.pattern_ty) parameters, [ body.result ])
  | Constant_body v -> ([], [ v.ty ])
  | Handler_body h ->
      let input, output = handler_types h in
      (List.map (fun p -> p.pattern_ty) h.handler_parameters, [ input; output ])

(* A use of the definition [d] at fresh types of its quantified variables,
   with the substitution of its types at them. *)
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
  (st, { variable = d.variable; instance }, substitute f)

let type_variables tys =
  let rec collect acc = function
    | Meta i -> if List.mem i acc then acc else i :: acc
    | Tuple tys -> List.fold_left collect acc tys
    | Arrow (a, b) -> collect (collect acc a) b
    | Nat | Int | Float | Bool | String | Data _ -> acc
  in
  List.rev (List.fold_left collect [] tys)

let function_type d =
  match d.definition_body with
  | Function_body { parameters; body; _ } ->
      Some (List.map (fun p -> p.pattern_ty) parameters, body.result)
  | Constant_body _ | Handler_body _ -> None

let rec strip_expression (e : _ Ast.expression) =
  match e.it with Ast.Annotated (e, _) -> strip_expression e | _ -> e

let rec strip_pattern (p : _ Ast.pattern) =
  match p.it with Ast.PAnnotated (p, _) -> strip_pattern p | _ -> p

(* A term bound to a variable: a value, a function, or a handler. *)
type resolved =
  | Resolved_value of value
  | Resolved_function of partial
  | Resolved_handler of known_handler

(* A computation: one of the fragment, or a function or a handler, which only
   the bound computation of a [do] may be. *)
type elaborated =
  | Computed of computation
  | Applied of partial * Location.t
  | Handler_value of known_handler * Location.t

let reject_function p at =
  match p.arguments with
  | [] -> unsupported at "the function `%s` used as a value" p.name
  | _ :: _ -> unsupported at "the partial application of `%s`" p.name

let reject_handler h at =
  match h.handler_name with
  | Some name -> unsupported at "the handler `%s` used as a value" name
  | None -> unsupported at "handlers used as values"

let as_computation = function
  | Computed c -> c
  | Applied (p, at) -> reject_function p at
  | Handler_value (h, at) -> reject_handler h at

(* The tail-resumptive operation cases. The continuation of a case is denoted
   by the variables of [ks]: the variable of the case and those it is unboxed
   to. An occurrence of one of them is reported with whether it is the subject
   of an [unbox], that is, a resumption. *)

let rec expression_occurrence ks (e : _ Ast.expression) =
  match e.it with
  | Ast.Var x -> if Ast.VariableSet.mem x ks then Some (e.at, false) else None
  | Ast.Const _ -> None
  | Ast.Annotated (e, _) -> expression_occurrence ks e
  | Ast.Tuple es -> List.find_map (expression_occurrence ks) es
  | Ast.Variant (_, arg) -> Option.bind arg (expression_occurrence ks)
  | Ast.Lambda (_, c) | Ast.PureLambda (_, c) | Ast.RecLambda (_, _, (_, c)) ->
      computation_occurrence ks c
  | Ast.Handler ((_, c), cases) ->
      List.find_map
        (computation_occurrence ks)
        (c :: List.map (fun (_, (_, c)) -> c) (Ast.OpNameMap.bindings cases))

and computation_occurrence ks (c : _ Ast.computation) =
  let first f g = match f () with Some _ as o -> o | None -> g () in
  match c.it with
  | Ast.Return e -> expression_occurrence ks e
  | Ast.Do (c1, (_, c2)) ->
      first
        (fun () -> computation_occurrence ks c1)
        (fun () -> computation_occurrence ks c2)
  | Ast.Match (e, cases) ->
      first
        (fun () -> expression_occurrence ks e)
        (fun () ->
          List.find_map (fun (_, c) -> computation_occurrence ks c) cases)
  | Ast.Apply (e1, e2) ->
      first
        (fun () -> expression_occurrence ks e1)
        (fun () -> expression_occurrence ks e2)
  | Ast.Delay (_, c) -> computation_occurrence ks c
  | Ast.Box (_, e, (_, c)) | Ast.Perform (_, e, (_, c)) ->
      first
        (fun () -> expression_occurrence ks e)
        (fun () -> computation_occurrence ks c)
  | Ast.Unbox (e, (_, c)) ->
      first
        (fun () ->
          match expression_occurrence ks e with
          | Some (at, _) -> Some (at, true)
          | None -> None)
        (fun () -> computation_occurrence ks c)
  | Ast.Handle (c, e) ->
      first
        (fun () -> computation_occurrence ks c)
        (fun () -> expression_occurrence ks e)

let rec bound_variable (p : _ Ast.pattern) =
  match p.it with
  | Ast.PVar x -> Some x
  | Ast.PAnnotated (p, _) -> bound_variable p
  | _ -> None

(* The patterns of the argument and of the continuation of the pattern [p] of
   an operation case, if it is a pair. *)
let case_patterns (p : _ Ast.pattern) =
  match (strip_pattern p).it with
  | Ast.PTuple [ argument; continuation ] -> Some (argument, continuation)
  | _ -> None

(* The continuation that the pattern [k] binds: [Some (Some x)] for a variable
   [x], [Some None] for [_], and [None] for any other pattern. *)
let continuation_variable (k : _ Ast.pattern) =
  match (strip_pattern k).it with
  | Ast.PVar x -> Some (Some x)
  | Ast.PNonbinding -> Some None
  | _ -> None

(* The variables denoting the continuation [k], if it is named. *)
let continuation_set k =
  Option.fold ~none:Ast.VariableSet.empty ~some:Ast.VariableSet.singleton k

(* Why a case of a handler is not tail-resumptive: its continuation is
   resumed outside tail position, used other than by a resumption, or not
   resumed at the end of a branch. *)
type not_resuming = Resumed_outside_tail | Used_otherwise | Not_resumed

(* A case of the operation [op], of the continuation [k] if it is named, that
   is not tail-resumptive for [reason] at [at]. *)
type failure = {
  at : Location.t;
  op : Ast.operation;
  k : Ast.variable option;
  reason : not_resuming;
}

exception Not_tail_resumptive of failure

(* The failure [reason] of the case [case] of an operation, whose continuation
   is [k] if it is named. *)
let not_resuming_text ~case ~k reason =
  let continuation = Option.fold ~none:"" ~some:Ast.Variable.string_of k in
  match (reason, k) with
  | Resumed_outside_tail, _ ->
      Printf.sprintf
        "the continuation `%s` of %s is resumed outside tail position"
        continuation case
  | Used_otherwise, _ ->
      Printf.sprintf
        "the continuation `%s` of %s is used other than by its resumption in \
         tail position"
        continuation case
  | Not_resumed, Some _ ->
      Printf.sprintf "%s ends here without resuming its continuation `%s`" case
        continuation
  | Not_resumed, None ->
      Printf.sprintf "%s ends here without resuming its continuation" case

(* [resumed ~op ~k ks c] is the case [c] of the operation [op], whose
   continuation is [k] if it is named, with its resumption in tail position
   [continue k with v] replaced by [return v]; [do x <- c in return x] is
   [c].

   @raise Not_tail_resumptive at the first offending occurrence of [k]. *)
let rec resumed ~op ~k ks (c : _ Ast.computation) =
  let located it = Ast.located c.at it in
  let absent occurrence =
    Option.iter
      (fun (at, resumption) ->
        raise
          (Not_tail_resumptive
             {
               at;
               op;
               k;
               reason =
                 (if resumption then Resumed_outside_tail else Used_otherwise);
             }))
      occurrence
  in
  let ends () =
    absent (computation_occurrence ks c);
    raise (Not_tail_resumptive { at = c.at; op; k; reason = Not_resumed })
  in
  let is_continuation e =
    match (strip_expression e).it with
    | Ast.Var x -> Ast.VariableSet.mem x ks
    | _ -> false
  in
  let continue_with c = resumed ~op ~k ks c in
  match c.it with
  | Ast.Apply (e1, e2) when is_continuation e1 ->
      absent (expression_occurrence ks e2);
      located (Ast.Return e2)
  | Ast.Apply (e1, e2) -> (
      match (strip_expression e1).it with
      | Ast.Lambda abs | Ast.PureLambda abs ->
          continue_with (located (Ast.Do (located (Ast.Return e2), abs)))
      | _ -> ends ())
  | Ast.Unbox (e, (p, c')) when is_continuation e ->
      let ks =
        Option.fold ~none:ks
          ~some:(fun z -> Ast.VariableSet.add z ks)
          (bound_variable p)
      in
      resumed ~op ~k ks c'
  | Ast.Do ({ it = Ast.Do (c0, (p0, c1)); at }, abs) ->
      continue_with
        (located (Ast.Do (c0, (p0, Ast.located at (Ast.Do (c1, abs))))))
  | Ast.Do (c1, (p, { it = Ast.Return e; _ }))
    when match (bound_variable p, (strip_expression e).it) with
         | Some x, Ast.Var y -> Ast.Variable.equal x y
         | _ -> false ->
      continue_with c1
  | Ast.Do (c1, (p, c2)) ->
      absent (computation_occurrence ks c1);
      located (Ast.Do (c1, (p, continue_with c2)))
  | Ast.Match (e, cases) ->
      absent (expression_occurrence ks e);
      located
        (Ast.Match (e, List.map (fun (p, c) -> (p, continue_with c)) cases))
  | Ast.Delay (q, c') -> located (Ast.Delay (q, continue_with c'))
  | Ast.Box (rho, e, (p, c')) ->
      absent (expression_occurrence ks e);
      located (Ast.Box (rho, e, (p, continue_with c')))
  | Ast.Unbox (e, (p, c')) ->
      absent (expression_occurrence ks e);
      located (Ast.Unbox (e, (p, continue_with c')))
  | Ast.Perform (op', e, (p, c')) ->
      absent (expression_occurrence ks e);
      located (Ast.Perform (op', e, (p, continue_with c')))
  | Ast.Return _ | Ast.Handle _ -> ends ()

(* The rejection of a case of the operation [op] that is not
   tail-resumptive. *)
let reject_not_tail_resumptive { at; op; k; reason } =
  Error.compilation ~loc:at
    "%s, so the handler cannot be compiled to direct calls"
    (String.capitalize_ascii
       (not_resuming_text
          ~case:(Printf.sprintf "the case of `%s`" (Ast.OpName.string_of op))
          ~k reason))

(* The handlers of the unreached definitions. A handler written in a top-level
   definition is checked for tail-resumption alone, without its types: the
   first of its cases, in the order {!Ast.OpName.compare}, that is not
   tail-resumptive is reported. *)

(* How a handler written in a top-level definition is named: by the
   definition, by a [let] in it, or not at all. *)
type handler_name = Top_level | Let_bound of Ast.variable | Anonymous

(* The handlers written in [e], each with its name, prepended in reverse order
   to [acc]. [name] is the name of [e], if it is a handler, and of the handlers
   that its functions return. *)
let rec expression_handlers ?(name = Anonymous) acc (e : _ Ast.expression) =
  match e.it with
  | Ast.Var _ | Ast.Const _ -> acc
  | Ast.Annotated (e, _) -> expression_handlers ~name acc e
  | Ast.Tuple es -> List.fold_left (expression_handlers ?name:None) acc es
  | Ast.Variant (_, arg) ->
      Option.fold ~none:acc ~some:(expression_handlers acc) arg
  | Ast.Lambda (_, c) | Ast.PureLambda (_, c) -> (
      match c.it with
      | Ast.Return e -> expression_handlers ~name acc e
      | _ -> computation_handlers acc c)
  | Ast.RecLambda (_, _, (_, c)) -> computation_handlers acc c
  | Ast.Handler ((_, c), cases) ->
      List.fold_left computation_handlers ((name, cases) :: acc)
        (c :: List.map (fun (_, (_, c)) -> c) (Ast.OpNameMap.bindings cases))

and computation_handlers acc (c : _ Ast.computation) =
  match c.it with
  | Ast.Return e -> expression_handlers acc e
  | Ast.Do ({ it = Ast.Return e; _ }, (p, c2)) ->
      let name =
        match ((strip_expression e).it, bound_variable p) with
        | Ast.Handler _, Some x -> Let_bound x
        | _ -> Anonymous
      in
      computation_handlers (expression_handlers ~name acc e) c2
  | Ast.Do (c1, (_, c2)) ->
      computation_handlers (computation_handlers acc c1) c2
  | Ast.Match (e, cases) ->
      List.fold_left
        (fun acc (_, c) -> computation_handlers acc c)
        (expression_handlers acc e)
        cases
  | Ast.Apply (e1, e2) -> expression_handlers (expression_handlers acc e1) e2
  | Ast.Delay (_, c) -> computation_handlers acc c
  | Ast.Box (_, e, (_, c)) | Ast.Unbox (e, (_, c)) | Ast.Perform (_, e, (_, c))
    ->
      computation_handlers (expression_handlers acc e) c
  | Ast.Handle (c, e) -> expression_handlers (computation_handlers acc c) e

(* The first case of the operation cases [cases] that is not tail-resumptive,
   if any, with the reason. A case whose continuation is bound by a pattern
   other than a variable or [_] is not checked. *)
let first_not_tail_resumptive cases =
  List.find_map
    (fun (op, (p, body)) ->
      match
        Option.bind (case_patterns p) (fun (_, k) -> continuation_variable k)
      with
      | Some k -> (
          match resumed ~op ~k (continuation_set k) body with
          | _ -> None
          | exception Not_tail_resumptive failure -> Some failure)
      | None -> None)
    (Ast.OpNameMap.bindings cases)

(* The warnings of the handlers that are not tail-resumptive among those
   written in the top-level definitions of [sources] that are not [reached],
   in order, each at the offending occurrence of its continuation. *)
let unreached_handler_warnings ~reached sources =
  List.concat_map
    (fun (cmd : _ Ast.command) ->
      match cmd.it with
      | Ast.TopLet (x, e) when not (reached x) ->
          let definition = Ast.Variable.string_of x in
          List.filter_map
            (fun (name, cases) ->
              Option.map
                (fun { at; op; k; reason } ->
                  let handler =
                    match name with
                    | Top_level -> Printf.sprintf "The handler `%s`" definition
                    | Let_bound h ->
                        Printf.sprintf
                          "The handler `%s` in the definition of `%s`"
                          (Ast.Variable.string_of h) definition
                    | Anonymous ->
                        Printf.sprintf "A handler in the definition of `%s`"
                          definition
                  in
                  {
                    Utils.Diagnostic.kind = Warning;
                    primary = Some at;
                    message =
                      Printf.sprintf
                        "%s is not tail-resumptive: %s; it is not compiled for \
                         the device, and the interpreter can run it"
                        handler
                        (not_resuming_text
                           ~case:
                             (Printf.sprintf "its case of `%s`"
                                (Ast.OpName.string_of op))
                           ~k reason);
                    labels = [];
                    notes = [];
                  })
                (first_not_tail_resumptive cases))
            (List.rev (expression_handlers ~name:Top_level [] e))
      | Ast.TopLet _ | Ast.TopDo _ | Ast.TyDef _ | Ast.OpSig _ | Ast.OpDefault _
        ->
          [])
    sources

(* The rejection of the comparisons of [st] whose values are of a type with a
   function component. *)
let check_comparisons st =
  List.iter
    (fun (at, ty) ->
      if has_function (substituted st ty) then
        unsupported at "the comparison of functions")
    (List.rev st.comparisons)

let add_local x local env =
  { env with locals = Ast.VariableMap.add x local env.locals }

(* The free variables of the patterns [ps] and the computations [cs] in their
   scope, in the order of their first occurrences: the variables of their values
   that their patterns do not bind. The handlers of their [handle]s are closed
   but for their arguments, and their closures but for their environments. *)
let free_variables ps cs =
  let rec value (refs, binders) v =
    match v.value with
    | Local x -> (x :: refs, binders)
    | Global _ | Constant _ -> (refs, binders)
    | Tuple_value vs -> List.fold_left value (refs, binders) vs
    | Construct (_, arg) ->
        Option.fold ~none:(refs, binders) ~some:(value (refs, binders)) arg
    | Closure k -> (List.rev_append (List.map fst k.environment) refs, binders)
  in
  let rec pattern (refs, binders) p =
    match p.pattern with
    | PVar x -> (refs, x :: binders)
    | PAs (p, x) -> pattern (refs, x :: binders) p
    | PTuple ps -> List.fold_left pattern (refs, binders) ps
    | PConstruct (_, arg) ->
        Option.fold ~none:(refs, binders) ~some:(pattern (refs, binders)) arg
    | PSucc (p, _) -> pattern (refs, binders) p
    | PConstant _ | PAny -> (refs, binders)
  in
  let rec computation acc c =
    match c.computation with
    | Return v | Perform (_, v) -> value acc v
    | Bind (p, c1, c2) -> computation (computation (pattern acc p) c1) c2
    | Match (v, cases) ->
        List.fold_left
          (fun acc (p, c) -> computation (pattern acc p) c)
          (value acc v) cases
    | Call (_, vs) -> List.fold_left value acc vs
    | Apply (v1, v2) -> value (value acc v1) v2
    | Delay (_, c) -> computation acc c
    | Handle (u, c) -> computation (List.fold_left value acc u.arguments) c
  in
  let refs, binders =
    List.fold_left computation (List.fold_left pattern ([], []) ps) cs
  in
  let _, free =
    List.fold_left
      (fun (excluded, free) x ->
        if Ast.VariableSet.mem x excluded then (excluded, free)
        else (Ast.VariableSet.add x excluded, x :: free))
      (Ast.VariableSet.of_list binders, [])
      (List.rev refs)
  in
  List.rev free

(* The free variables of the handler [h]. *)
let handler_free_variables (h : handler) =
  let ret_p, ret_c = h.return_case in
  free_variables
    (ret_p :: List.map (fun oc -> oc.case_parameter) h.operation_cases)
    (ret_c :: List.map (fun oc -> oc.case_body) h.operation_cases)

let rec resolve_variable env st at x =
  let name = Ast.Variable.string_of x in
  let function_value target params =
    Resolved_function { target; name; arguments = []; remaining = params }
  in
  match Ast.VariableMap.find_opt x env.locals with
  | Some (Value ty) -> (st, Resolved_value { value = Local x; ty })
  | Some (Partial p) -> (st, Resolved_function p)
  | Some (Handler_local h) -> (st, Resolved_handler h)
  | None -> (
      match (env.self, Ast.VariableMap.mem x env.commands, primitive_of x) with
      | Some (f, params, result), _, _ when Ast.Variable.equal f x ->
          (st, function_value (Call_target (Self, result)) params)
      | _, true, _ -> (
          let st, d = ensure env st x in
          let st, g, f = instantiate st d in
          let params, results = signature d in
          let params = List.map f params and results = List.map f results in
          match (d.definition_body, params, results) with
          | Function_body _, _, [ result ] ->
              (st, function_value (Call_target (Function g, result)) params)
          | Constant_body _, _, [ result ] ->
              (st, Resolved_value { value = Global g; ty = result })
          | Handler_body _, [], [ input; output ] ->
              ( st,
                Resolved_handler
                  {
                    use = { source = Defined g; arguments = [] };
                    input;
                    output;
                    handler_name = Some name;
                  } )
          | Handler_body _, _, [ input; output ] ->
              (st, function_value (Handler_target (g, input, output)) params)
          | _ -> invalid_arg "signature of a definition")
      | _, false, Some p ->
          let st, param, result = primitive_signature at st p in
          (st, function_value (Call_target (Primitive p, result)) [ param ])
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
  let saved = st.type_parameters and saved_comparisons = st.comparisons in
  let st =
    { st with type_parameters = Ast.TyParamMap.empty; comparisons = [] }
  in
  let env = { env with locals = Ast.VariableMap.empty; self = None } in
  let st, definition_body =
    match (strip_expression e).it with
    | Ast.Lambda abs | Ast.PureLambda abs -> function_body env st None abs
    | Ast.RecLambda (f, _, abs) -> function_body env st (Some f) abs
    | Ast.Handler (ret_case, op_cases) ->
        let st, h = handler env st [] ret_case op_cases in
        (st, Handler_body h)
    | _ ->
        let st, v = value env st e in
        (st, Constant_body v)
  in
  check_comparisons st;
  let definition_body = map_body (substituted st) definition_body in
  let d = { variable = x; at; in_sources; quantified = []; definition_body } in
  let params, results = signature d in
  let d = { d with quantified = type_variables (params @ results) } in
  ( {
      st with
      type_parameters = saved;
      comparisons = saved_comparisons;
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
  let returned_handler =
    match body.it with
    | Ast.Return e -> (
        match (strip_expression e).it with
        | Ast.Handler (ret_case, op_cases) -> Some (ret_case, op_cases)
        | _ -> None)
    | _ -> None
  in
  match (self, returned_handler) with
  | None, Some (ret_case, op_cases) ->
      let st, h = handler env st parameters ret_case op_cases in
      (st, Handler_body h)
  | _ ->
      let result, st = fresh st in
      let env =
        {
          env with
          self =
            Option.map
              (fun f ->
                (f, List.map (fun p -> p.pattern_ty) parameters, result))
              self;
        }
      in
      let st, elaborated = computation env st ~tail:true body in
      let body = as_computation elaborated in
      let st = unify_at (snd abs).at st result body.result in
      (st, Function_body { parameters; body; recursive = calls_self body })

(* The handler of a return case and the operation cases [op_cases], of the
   parameters [parameters] bound in [env]. *)
and handler env st parameters (ret_pattern, ret_body) op_cases =
  let input, st = fresh st in
  let st, ret_pattern, ret_env = pattern env st ret_pattern input in
  let st, ret_body = computation ret_env st ~tail:false ret_body in
  let st, operation_cases =
    List.fold_left_map
      (fun st (op, case) -> operation_case env st op case)
      st
      (Ast.OpNameMap.bindings op_cases)
  in
  ( st,
    {
      handler_parameters = parameters;
      return_case = (ret_pattern, as_computation ret_body);
      operation_cases;
    } )

(* The case of [op], whose resumption in tail position is replaced by the
   value it resumes with. *)
and operation_case env st op ((p, body) : _ Ast.abstraction) =
  let st, argument, result = operation_types p.at env st op in
  match case_patterns p with
  | Some (argument_pattern, continuation_pattern) ->
      let k =
        match continuation_variable continuation_pattern with
        | Some k -> k
        | None ->
            unsupported continuation_pattern.at
              "patterns of continuations other than variables"
      in
      let body =
        try resumed ~op ~k (continuation_set k) body
        with Not_tail_resumptive failure -> reject_not_tail_resumptive failure
      in
      let st, case_parameter, env = pattern env st argument_pattern argument in
      let st, case_body = computation env st ~tail:false body in
      let case_body = as_computation case_body in
      let st = unify_at body.at st result case_body.result in
      (st, { case_operation = op; case_parameter; case_body })
  | None -> invalid_arg "operation case without an argument and a continuation"

(* The types of the argument and the result of the operation [op]. *)
and operation_types at env st op =
  let argument, result = Ast.OpNameMap.find op env.signatures in
  let st, argument = convert_at at env st argument in
  let st, result = convert_at at env st result in
  if has_string result then
    unsupported at "the operation `%s`, whose result contains a string"
      (Ast.OpName.string_of op);
  (st, argument, result)

(* A handler written in a definition, whose parameters are its free
   variables. *)
and inline_handler env st ret_case op_cases =
  let st, h = handler env st [] ret_case op_cases in
  let free = handler_free_variables h in
  let typed =
    List.map
      (fun x ->
        match Ast.VariableMap.find_opt x env.locals with
        | Some (Value ty) -> (x, ty)
        | Some (Partial _ | Handler_local _) | None ->
            invalid_arg "free variable of a handler")
      free
  in
  let input, output = handler_types h in
  ( st,
    {
      use =
        {
          source =
            Inline
              ( Ast.Variable.fresh "handler",
                {
                  h with
                  handler_parameters =
                    List.map
                      (fun (x, ty) -> { pattern = PVar x; pattern_ty = ty })
                      typed;
                } );
          arguments = List.map (fun (x, ty) -> { value = Local x; ty }) typed;
        };
      input;
      output;
      handler_name = None;
    } )

(* The handler [e] of a [handle], which is known at compilation. *)
and handled_by env st (e : _ Ast.expression) =
  match (strip_expression e).it with
  | Ast.Var x -> (
      match resolve_variable env st e.at x with
      | st, Resolved_handler h -> (st, h)
      | _, Resolved_function p -> reject_function p e.at
      | _, Resolved_value _ ->
          unsupported e.at "the handler `%s`, which is not known at compilation"
            (Ast.Variable.string_of x))
  | Ast.Handler (ret_case, op_cases) -> inline_handler env st ret_case op_cases
  | _ -> unsupported e.at "handlers not known at compilation"

and value ?(strings = false) env st (e : _ Ast.expression) =
  match e.it with
  | Ast.Var x -> (
      match resolve_variable env st e.at x with
      | st, Resolved_value v -> (st, v)
      | _, Resolved_function p -> reject_function p e.at
      | _, Resolved_handler h -> reject_handler h e.at)
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
  | Ast.Lambda abs | Ast.PureLambda abs -> closure env st e.at abs
  | Ast.RecLambda _ -> unsupported e.at "local recursive functions"
  | Ast.Handler _ -> unsupported e.at "handlers used as values"

(* The closure of the function [fun p -> body] at [at], whose environment is
   its free variables. Its body is not in tail position of the function being
   defined. *)
and closure env st at ((p, body) : _ Ast.abstraction) =
  let parameter_ty, st = fresh st in
  let st, closure_parameter, inner = pattern env st p parameter_ty in
  let st, elaborated = computation inner st ~tail:false body in
  let closure_body = as_computation elaborated in
  let environment =
    List.map
      (fun x ->
        match Ast.VariableMap.find_opt x env.locals with
        | Some (Value ty) -> (x, ty)
        | Some (Partial _ | Handler_local _) | None ->
            invalid_arg "free variable of a closure")
      (free_variables [ closure_parameter ] [ closure_body ])
  in
  ( st,
    {
      value =
        Closure
          {
            closure_name = Ast.Variable.fresh "lambda";
            closure_at = at;
            environment;
            closure_parameter;
            closure_body;
          };
      ty = Arrow (parameter_ty, closure_body.result);
    } )

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
          | st, Resolved_function p -> (st, Applied (p, e.at))
          | st, Resolved_handler h -> (st, Handler_value (h, e.at)))
      | Ast.Handler (ret_case, op_cases) ->
          let st, h = inline_handler env st ret_case op_cases in
          (st, Handler_value (h, e.at))
      | _ ->
          let st, v = value env st e in
          (st, Computed { computation = Return v; result = v.ty }))
  | Ast.Do ({ it = Ast.Do (c0, (p0, c1)); at }, abs) ->
      computation env st ~tail
        (located (Ast.Do (c0, (p0, Ast.located at (Ast.Do (c1, abs))))))
  | Ast.Do (c1, (p, c2)) -> (
      (* A function or a handler bound to a variable. *)
      let bound st local reject =
        match (strip_pattern p).it with
        | Ast.PVar x -> computation (add_local x local env) st ~tail c2
        | Ast.PNonbinding -> computation env st ~tail c2
        | _ -> reject ()
      in
      match computation env st ~tail:false c1 with
      | st, Applied (partial, at) ->
          bound st (Partial partial) (fun () -> reject_function partial at)
      | st, Handler_value (h, at) ->
          bound st (Handler_local h) (fun () -> reject_handler h at)
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
          | st, Resolved_value f -> apply_closure env st e1.at f e2
          | _, Resolved_handler h -> reject_handler h e1.at)
      | _ ->
          let st, f = value env st e1 in
          apply_closure env st e1.at f e2)
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
      let st, argument, result = operation_types c.at env st op in
      let st, v = value ~strings:true env st e in
      let st = unify_at e.at st argument v.ty in
      let st =
        {
          st with
          performed = Ast.OpNameMap.add op (argument, result) st.performed;
        }
      in
      bind env st ~tail p { computation = Perform (op, v); result } c'
  | Ast.Handle (body, e) ->
      let st, h = handled_by env st e in
      let st, body' = computation env st ~tail:false body in
      let body' = as_computation body' in
      let st = unify_at body.at st h.input body'.result in
      (st, Computed { computation = Handle (h.use, body'); result = h.output })

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

(* The application of the closure [f] at [at] to [e]. *)
and apply_closure env st at f e =
  let a, st = fresh st in
  let b, st = fresh st in
  let st = unify_at at st f.ty (Arrow (a, b)) in
  let st, v = value env st e in
  let st = unify_at e.at st a v.ty in
  (st, Computed { computation = Apply (f, v); result = b })

(* The application of the function [p] to [e]: a call, or a handler, once it
   has all its arguments. *)
and apply env st ~tail at p e =
  let st, v = value env st e in
  match p.remaining with
  | [] -> invalid_arg "application of a function without parameters"
  | ty :: remaining -> (
      let st = unify_at e.at st ty v.ty in
      let arguments = p.arguments @ [ v ] in
      match (remaining, p.target) with
      | [], Call_target (callee, result) ->
          let st =
            match callee with
            | Self when not tail ->
                unsupported at
                  "the recursive call of `%s` outside a tail position" p.name
            | Primitive
                ( Primitives.CompareEq | Primitives.CompareLt
                | Primitives.CompareGt | Primitives.CompareLe
                | Primitives.CompareGe | Primitives.CompareNe ) ->
                { st with comparisons = (at, v.ty) :: st.comparisons }
            | Self | Function _ | Primitive _ -> st
          in
          (st, Computed { computation = Call (callee, arguments); result })
      | [], Handler_target (g, input, output) ->
          ( st,
            Handler_value
              ( {
                  use = { source = Defined g; arguments };
                  input;
                  output;
                  handler_name = Some p.name;
                },
                at ) )
      | _ :: _, _ -> (st, Applied ({ p with arguments; remaining }, at)))

(* The environment of the commands, each with whether it is in the sources. *)
let add_command env (in_sources, (cmd : _ Ast.command)) =
  match cmd.it with
  | Ast.TopLet (x, e) ->
      {
        env with
        commands = Ast.VariableMap.add x (cmd.at, in_sources, e) env.commands;
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
                  Ast.TyNameMap.add name (params, constructors, cmd.at) env.sums;
                labels =
                  List.fold_left
                    (fun labels (l, _) -> LabelMap.add l name labels)
                    env.labels constructors;
              })
        env defs
  | Ast.OpSig (op, ty1, ty2, _, _) ->
      { env with signatures = Ast.OpNameMap.add op (ty1, ty2) env.signatures }
  | Ast.OpDefault _ | Ast.TopDo _ -> env

let initial_state =
  {
    substitution = IntMap.empty;
    next = 0;
    type_parameters = Ast.TyParamMap.empty;
    definitions = Ast.VariableMap.empty;
    order = [];
    performed = Ast.OpNameMap.empty;
    comparisons = [];
  }

(* The environment of [library] and [sources], with the datatypes without type
   parameters checked against the fragment once. *)
let environment ~library sources =
  let env =
    List.fold_left add_command
      {
        commands = Ast.VariableMap.empty;
        aliases = Ast.TyNameMap.empty;
        sums = Ast.TyNameMap.empty;
        labels = LabelMap.empty;
        data = Ast.TyNameMap.empty;
        signatures = Ast.OpNameMap.empty;
        locals = Ast.VariableMap.empty;
        self = None;
      }
      (List.map (fun c -> (false, c)) library
      @ List.map (fun c -> (true, c)) sources)
  in
  let data =
    Ast.TyNameMap.filter_map
      (fun name (params, _, _) ->
        match params with
        | _ :: _ -> None
        | [] -> (
            match convert env initial_state (Ast.TyApply (name, [])) with
            | _ -> Some (Ok ())
            | exception Unsupported_type what -> Some (Error what)))
      env.sums
  in
  { env with data }

(* The reconstruction of the definitions of [sources] satisfying [included],
   in order, and of the [run] commands if [runs], the latter in reverse. *)
let reconstruct env ~runs included sources =
  List.fold_left
    (fun (st, runs_rev) (cmd : _ Ast.command) ->
      match cmd.it with
      | Ast.TopLet (x, _) when included x -> (fst (ensure env st x), runs_rev)
      | Ast.TopDo c when runs ->
          let st =
            { st with type_parameters = Ast.TyParamMap.empty; comparisons = [] }
          in
          let st, c = computation env st ~tail:true c in
          check_comparisons st;
          let c = map_computation (substituted st) (as_computation c) in
          (st, c :: runs_rev)
      | Ast.TopLet _ | Ast.TopDo _ | Ast.TyDef _ | Ast.OpSig _ | Ast.OpDefault _
        ->
          (st, runs_rev))
    (initial_state, []) sources

(* The variables of the last definitions of [sources] of the names [names]. *)
let root_variables names sources =
  let named =
    List.fold_left
      (fun named (cmd : _ Ast.command) ->
        match cmd.it with
        | Ast.TopLet (x, _) when List.mem (Ast.Variable.string_of x) names ->
            StringMap.add (Ast.Variable.string_of x) x named
        | _ -> named)
      StringMap.empty sources
  in
  StringMap.fold (fun _ x -> Ast.VariableSet.add x) named Ast.VariableSet.empty

(* The variables that [c] mentions outside the handled computation of every
   [handle], the handlers and their cases included. *)
let rec mentioned_computation (c : _ Ast.computation) acc =
  match c.it with
  | Ast.Handle (_, h) -> mentioned_expression h acc
  | _ ->
      Ast.fold_computation ~expression:mentioned_expression
        ~computation:mentioned_computation ~abstraction:mentioned_abstraction c
        acc

and mentioned_expression (e : _ Ast.expression) acc =
  match e.it with
  | Ast.Var x -> Ast.VariableSet.add x acc
  | _ ->
      Ast.fold_expression ~expression:mentioned_expression
        ~abstraction:mentioned_abstraction e acc

and mentioned_abstraction (_, c) acc = mentioned_computation c acc

(* The variables of the top-level definitions of [sources] that the [run]
   commands of [sources] mention outside every handled computation, or of all
   of them if [sources] has no [run] command. *)
let run_entries sources =
  let runs =
    List.filter_map
      (fun (cmd : _ Ast.command) ->
        match cmd.it with Ast.TopDo c -> Some c | _ -> None)
      sources
  in
  let defined =
    List.fold_left
      (fun acc (cmd : _ Ast.command) ->
        match cmd.it with
        | Ast.TopLet (x, _) -> Ast.VariableSet.add x acc
        | _ -> acc)
      Ast.VariableSet.empty sources
  in
  match runs with
  | [] -> defined
  | _ ->
      Ast.VariableSet.inter defined
        (List.fold_left
           (fun acc c -> mentioned_computation c acc)
           Ast.VariableSet.empty runs)

(* The datatypes of [env] in the fragment, their constructors in the order of
   their labels. *)
let datatypes env =
  Ast.TyNameMap.fold
    (fun type_name result acc ->
      match result with
      | Error _ -> acc
      | Ok () ->
          let _, constructors, type_at =
            Ast.TyNameMap.find type_name env.sums
          in
          let constructors =
            List.sort
              (fun (l1, _) (l2, _) -> Ast.Label.compare l1 l2)
              (List.map
                 (fun (l, arg) ->
                   ( l,
                     Option.map
                       (fun ty -> snd (convert env initial_state ty))
                       arg ))
                 constructors)
          in
          { type_name; constructors; type_at } :: acc)
    env.data []

let check ?roots ~runs ~library sources =
  let env = environment ~library sources in
  let st, runs_rev =
    match roots with
    | None -> reconstruct env ~runs (fun _ -> true) sources
    | Some names ->
        (* The definitions reached from the roots are reconstructed again in
           the order of the sources, so that the order of the definitions, and
           with it that of the compiled program and its names, does not depend
           on the order in which they are reached. *)
        let roots = root_variables names sources in
        let reached, _ =
          reconstruct env ~runs (fun x -> Ast.VariableSet.mem x roots) sources
        in
        reconstruct env ~runs
          (fun x -> Ast.VariableMap.mem x reached.definitions)
          sources
  in
  {
    definitions = List.rev st.order;
    runs = List.rev runs_rev;
    datatypes = datatypes env;
    entries =
      (match roots with
      | Some names -> root_variables names sources
      | None -> run_entries sources);
    operations =
      List.map
        (fun (operation, (argument, result_ty)) ->
          { operation; argument; result_ty })
        (Ast.OpNameMap.bindings st.performed);
    warnings =
      (match roots with
      | None -> []
      | Some _ ->
          unreached_handler_warnings
            ~reached:(fun x -> Ast.VariableMap.mem x st.definitions)
            sources);
  }
