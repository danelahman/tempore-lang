module Location = Utils.Location
module StringMap = Utils.StringMap
module Sugared = SugaredAst

type sort = Value | Constructor | Type | Operation
type link = { use : Location.t; definition : Location.t; sort : sort }

type env = {
  values : Location.t StringMap.t;
  constructors : Location.t StringMap.t;
  types : Location.t StringMap.t;
  operations : Location.t StringMap.t;
}

let empty =
  {
    values = StringMap.empty;
    constructors = StringMap.empty;
    types = StringMap.empty;
    operations = StringMap.empty;
  }

let define { Sugared.it = name; at } scope = StringMap.add name at scope

(* [links] with the link of the occurrence [name] of a name of [scope], if it
   has a definition there. *)
let refer sort scope
    ({ Sugared.it = name; at = use } : string Sugared.annotated) links =
  match StringMap.find_opt name scope with
  | Some definition -> { use; definition; sort } :: links
  | None -> links

(* [env] with the variables [bound] shadowing its own. *)
let bind env bound =
  {
    env with
    values = StringMap.union (fun _ inner _ -> Some inner) bound env.values;
  }

let rec ty env links { Sugared.it; _ } =
  match it with
  | Sugared.TyParam _ -> links
  | Sugared.TyApply (name, tys) ->
      List.fold_left (ty env) (refer Type env.types name links) tys
  | Sugared.TyTuple tys -> List.fold_left (ty env) links tys
  | Sugared.TyArrow (a, c) -> comp_ty env (ty env links a) c
  | Sugared.TyBox (_, a) -> ty env links a
  | Sugared.TyHandler (c, d) -> comp_ty env (comp_ty env links c) d

and comp_ty env links (Sugared.CompTy (a, _)) = ty env links a

(* The links of a pattern, and the variables it binds with their
   definitions. *)
let rec pattern env (links, bound) { Sugared.it; at } =
  match it with
  | Sugared.PVar x -> (links, StringMap.add x at bound)
  | Sugared.PAnnotated (p, a) -> pattern env (ty env links a, bound) p
  | Sugared.PAs (p, x) ->
      let links, bound = pattern env (links, bound) p in
      (links, define x bound)
  | Sugared.PTuple ps -> List.fold_left (pattern env) (links, bound) ps
  | Sugared.PVariant (label, p) ->
      let links = refer Constructor env.constructors label links in
      Option.fold ~none:(links, bound) ~some:(pattern env (links, bound)) p
  | Sugared.PSucc (p, _) -> pattern env (links, bound) p
  | Sugared.PConst _ | Sugared.PNonbinding -> (links, bound)

let rec term env links { Sugared.it; at } =
  let terms = List.fold_left (term env) in
  let abstractions = List.fold_left (abstraction env) in
  match it with
  | Sugared.Var x -> refer Value env.values { it = x; at } links
  | Sugared.Const _ | Sugared.Delay _ -> links
  | Sugared.Annotated (t, a) | Sugared.AnnotatedComp (t, a, _) ->
      ty env (term env links t) a
  | Sugared.Tuple ts -> terms links ts
  | Sugared.Variant (label, t) ->
      let links = refer Constructor env.constructors label links in
      Option.fold ~none:links ~some:(term env links) t
  | Sugared.Lambda abs | Sugared.PureLambda abs -> abstraction env links abs
  | Sugared.Function cases -> abstractions links cases
  | Sugared.Let (p, t1, t2) -> abstraction env (term env links t1) (p, t2)
  | Sugared.LetRec (f, t1, t2) ->
      let env' = bind env (define f StringMap.empty) in
      term env' (term env' links t1) t2
  | Sugared.Match (t, cases) -> abstractions (term env links t) cases
  | Sugared.Conditional (t, t1, t2) -> terms links [ t; t1; t2 ]
  | Sugared.Apply (t1, t2) | Sugared.Handle (t1, t2) | Sugared.Continue (t1, t2)
    ->
      terms links [ t1; t2 ]
  | Sugared.Box (_, t, abs) | Sugared.Unbox (t, abs) ->
      abstraction env (term env links t) abs
  | Sugared.GenBox (_, t) | Sugared.GenUnbox t -> term env links t
  | Sugared.Perform (op, t) ->
      term env (refer Operation env.operations op links) t
  | Sugared.Handler (ret_case, op_cases) ->
      abstractions (abstraction env links ret_case) (List.map snd op_cases)

and abstraction env links (p, t) =
  let links, bound = pattern env (links, StringMap.empty) p in
  term (bind env bound) links t

(* The types of a group of type definitions are in scope in all of them, and
   each constructor from its declaration on. *)
let ty_defs env defs =
  let env =
    {
      env with
      types =
        List.fold_left
          (fun types (_, name, _) -> define name types)
          env.types defs;
    }
  in
  let variant (env, links) (label, a) =
    ( { env with constructors = define label env.constructors },
      Option.fold ~none:links ~some:(ty env links) a )
  in
  List.fold_left
    (fun (env, links) (_, _, def) ->
      match def with
      | Sugared.TyInline a -> (env, ty env links a)
      | Sugared.TySum variants -> List.fold_left variant (env, links) variants)
    (env, []) defs

let command env { Sugared.it; _ } =
  let env, links =
    match it with
    | Sugared.TyDef (_, defs) -> ty_defs env defs
    | Sugared.OpSig (op, a, b, _, _) ->
        ( { env with operations = define op env.operations },
          ty env (ty env [] a) b )
    | Sugared.OpDefault (_, abs) -> (env, abstraction env [] abs)
    (* A top-level definition is in scope after it, and a recursive one also in
       its own body. *)
    | Sugared.TopLet (x, t) ->
        (bind env (define x StringMap.empty), term env [] t)
    | Sugared.TopLetRec (x, t) ->
        let env = bind env (define x StringMap.empty) in
        (env, term env [] t)
    | Sugared.TopDo t -> (env, term env [] t)
  in
  (env, List.sort (fun l l' -> Location.compare l.use l'.use) links)
