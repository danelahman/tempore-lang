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

(* The subterms of a term are read in the scope of its own bindings: those of
   its abstractions, and of [let rec f = t1 in t2] the function [f] in [t1]
   and [t2]. *)
let rec term env links ({ Sugared.it; at } as t) =
  let subterms env links =
    Sugared.fold_term
      ~term:(fun t links -> term env links t)
      ~abstraction:(fun abs links -> abstraction env links abs)
      t links
  in
  match it with
  | Sugared.Var x -> refer Value env.values { it = x; at } links
  | Sugared.Annotated (_, a) | Sugared.AnnotatedComp (_, a, _) ->
      ty env (subterms env links) a
  | Sugared.Variant (label, _) ->
      subterms env (refer Constructor env.constructors label links)
  | Sugared.LetRec (f, _, _) ->
      subterms (bind env (define f StringMap.empty)) links
  | Sugared.Perform (op, _) ->
      subterms env (refer Operation env.operations op links)
  | Sugared.Const _ | Sugared.Tuple _ | Sugared.Lambda _ | Sugared.PureLambda _
  | Sugared.Function _ | Sugared.Let _ | Sugared.Match _ | Sugared.Conditional _
  | Sugared.Apply _ | Sugared.Delay _ | Sugared.Box _ | Sugared.GenBox _
  | Sugared.Unbox _ | Sugared.GenUnbox _ | Sugared.Handler _
  | Sugared.Continue _ | Sugared.Handle _ ->
      subterms env links

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
