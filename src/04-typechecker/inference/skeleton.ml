(* Skeletons, their unification, decoration and expansion. *)

module Ast = Language.Ast
module Const = Language.Const
module TyParam = Ast.TyParamModule
module TyParamMap = Ast.TyParamMap
module TyParamSet = Ast.TyParamSet

type t =
  | Var of Ast.ty_param
  | Const of Const.ty
  | Apply of Ast.ty_name * t list
  | Tuple of t list
  | Arrow of t * t
  | Box of t
  | Handler of t * t

(* The skeleton of a type, its grades erased. *)
let rec of_ty : ('rho, 'eps) Ast.ty -> t = function
  | Ast.TyConst c -> Const c
  | Ast.TyParam a -> Var a
  | Ast.TyApply (name, tys) -> Apply (name, List.map of_ty tys)
  | Ast.TyTuple tys -> Tuple (List.map of_ty tys)
  | Ast.TyArrow (ty, cty) -> Arrow (of_ty ty, of_comp_ty cty)
  | Ast.TyBox (_, ty) -> Box (of_ty ty)
  | Ast.TyHandler (cty, cty') -> Handler (of_comp_ty cty, of_comp_ty cty')

and of_comp_ty : ('rho, 'eps) Ast.comp_ty -> t = function
  | Ast.CompTy (ty, _) -> of_ty ty

let rec equal t u =
  match (t, u) with
  | Var a, Var b -> TyParam.compare a b = 0
  | Const c, Const c' -> c = c'
  | Apply (name, ts), Apply (name', us) ->
      Ast.TyName.compare name name' = 0 && List.equal equal ts us
  | Tuple ts, Tuple us -> List.equal equal ts us
  | Arrow (t1, t2), Arrow (u1, u2) | Handler (t1, t2), Handler (u1, u2) ->
      equal t1 u1 && equal t2 u2
  | Box t, Box u -> equal t u
  | (Var _ | Const _ | Apply _ | Tuple _ | Arrow _ | Box _ | Handler _), _ ->
      false

let rec fold_vars f t acc =
  match t with
  | Var a -> f a acc
  | Const _ -> acc
  | Apply (_, ts) | Tuple ts ->
      List.fold_left (fun acc t -> fold_vars f t acc) acc ts
  | Arrow (t, u) | Handler (t, u) -> fold_vars f u (fold_vars f t acc)
  | Box t -> fold_vars f t acc

let free_vars t = fold_vars TyParamSet.add t TyParamSet.empty

let rec occurs a = function
  | Var b -> TyParam.compare a b = 0
  | Const _ -> false
  | Apply (_, ts) | Tuple ts -> List.exists (occurs a) ts
  | Arrow (t, u) | Handler (t, u) -> occurs a t || occurs a u
  | Box t -> occurs a t

(* The type of [t] with every grade [()]. *)
let rec to_ty : t -> (unit, unit) Ast.ty = function
  | Var a -> Ast.TyParam a
  | Const c -> Ast.TyConst c
  | Apply (name, ts) -> Ast.TyApply (name, List.map to_ty ts)
  | Tuple ts -> Ast.TyTuple (List.map to_ty ts)
  | Arrow (t, u) -> Ast.TyArrow (to_ty t, to_comp_ty u)
  | Box t -> Ast.TyBox ((), to_ty t)
  | Handler (t, u) -> Ast.TyHandler (to_comp_ty t, to_comp_ty u)

and to_comp_ty t = Ast.CompTy (to_ty t, ())

let print t ppf =
  let blank () ppf = Format.pp_print_string ppf "_" in
  let grades =
    { Language.PrettyPrint.rho = blank; eps = blank; pure = (fun () -> true) }
  in
  Language.PrettyPrint.print_ty grades TyParam.print (to_ty t) ppf

let to_string t = Format.asprintf "%t" (print t)

type subst = t TyParamMap.t

let rec apply sigma t =
  match t with
  | Var a -> Option.value (TyParamMap.find_opt a sigma) ~default:t
  | Const _ -> t
  | Apply (name, ts) -> Apply (name, List.map (apply sigma) ts)
  | Tuple ts -> Tuple (List.map (apply sigma) ts)
  | Arrow (t, u) -> Arrow (apply sigma t, apply sigma u)
  | Box t -> Box (apply sigma t)
  | Handler (t, u) -> Handler (apply sigma t, apply sigma u)

type unfold = Ast.ty_name -> t list -> t option
type 'info equation = { lhs : t; rhs : t; info : 'info }
type mismatch = Clash | Occurs of Ast.ty_param

type 'info failure = {
  info : 'info;
  mismatch : mismatch;
  lhs : t;
  rhs : t;
  path : Ast.step list;
}

type side = Left | Right
type source = Side of side | Through of Ast.ty_param
type 'info binding = { site : 'info; at : Ast.step list; source : source }
type 'info bindings = 'info binding TyParamMap.t
type 'info link = { joined_by : 'info; joined_at : Ast.step list; joined : t }
type 'info trace = { bindings : 'info bindings; related : 'info link list }

(* The binding of a class: the skeleton it is bound to, how, and the unknown
   whose unification bound it. *)
type 'info bound = { shape : t; binding : 'info binding; binder : Ast.ty_param }

(* A union-find forest on type unknowns with union by rank (Tarjan, JACM
   1975), persistent as finite maps: the parent of each unknown other than a
   root, the rank of each root above 0, and the members of each class of more
   than one unknown, at its root. A class is a multi-equation (Pottier and
   Rémy, "The Essence of ML Type Inference", 2005): the root of a class whose
   unknowns are bound to a skeleton other than an unknown maps to its binding.
   Beside it, an explanation forest with the same trees as the classes, each
   edge labelled with the payload and the position of the equation whose
   unification joined its two unknowns, and of those that equation depends on
   (Nieuwenhuis and Oliveras, "Proof-producing congruence closure", RTA
   2005). *)
type 'info unifier = {
  parent : Ast.ty_param TyParamMap.t;
  rank : int TyParamMap.t;
  members : TyParamSet.t TyParamMap.t;
  shapes : 'info bound TyParamMap.t;
  edges : (Ast.ty_param * ('info * Ast.step list) list) TyParamMap.t;
}

let empty =
  {
    parent = TyParamMap.empty;
    rank = TyParamMap.empty;
    members = TyParamMap.empty;
    shapes = TyParamMap.empty;
    edges = TyParamMap.empty;
  }

let rec find u a =
  match TyParamMap.find_opt a u.parent with Some b -> find u b | None -> a

let rank u a = Option.value (TyParamMap.find_opt a u.rank) ~default:0

let members u a =
  Option.value
    (TyParamMap.find_opt a u.members)
    ~default:(TyParamSet.singleton a)

(* The explanation tree of [a] re-rooted at [a], its edges reversed along the
   path from [a] to the former root. *)
let rec reroot edges a =
  match TyParamMap.find_opt a edges with
  | None -> edges
  | Some (b, label) ->
      TyParamMap.add b (a, label) (TyParamMap.remove a (reroot edges b))

(* The union of the classes of the distinct roots [a] and [b], neither bound,
   by an equation between their members [x] and [y] with the labels [labels];
   at equal ranks [a] is placed under [b]. *)
let union u (x, a) (y, b) labels =
  let under child root =
    {
      u with
      parent = TyParamMap.add child root u.parent;
      members =
        TyParamMap.add root
          (TyParamSet.union (members u child) (members u root))
          (TyParamMap.remove child u.members);
      edges = TyParamMap.add x (y, labels) (reroot u.edges x);
    }
  in
  let rank_a = rank u a and rank_b = rank u b in
  if rank_a < rank_b then under a b
  else if rank_a > rank_b then under b a
  else { (under a b) with rank = TyParamMap.add b (rank_b + 1) u.rank }

(* The labels of the path between [a] and [b] in their explanation tree, from
   [a] to [b]. *)
let explanation u a b =
  let rec ancestry a =
    match TyParamMap.find_opt a u.edges with
    | Some (c, label) -> (a, Some label) :: ancestry c
    | None -> [ (a, None) ]
  in
  let up = ancestry a and up' = ancestry b in
  let set up = TyParamSet.of_list (List.map fst up) in
  let rec below common = function
    | (c, Some labels) :: rest when not (TyParamSet.mem c common) ->
        labels @ below common rest
    | _ -> []
  in
  below (set up') up @ List.rev (below (set up) up')

(* The head of [t] under [u]: for an unknown, the skeleton its class is bound
   to, or the root of its class when the class is not bound. *)
let resolve u = function
  | Var a -> (
      let root = find u a in
      match TyParamMap.find_opt root u.shapes with
      | Some { shape; _ } -> shape
      | None -> Var root)
  | t -> t

(* The immediate sub-skeletons of a skeleton. *)
let parts = function
  | Var _ | Const _ -> []
  | Apply (_, ts) | Tuple ts -> ts
  | Arrow (t, t') | Handler (t, t') -> [ t; t' ]
  | Box t -> [ t ]

(* [t] under [u], resolved throughout. *)
let rec value u t =
  match resolve u t with
  | (Var _ | Const _) as t -> t
  | Apply (name, ts) -> Apply (name, List.map (value u) ts)
  | Tuple ts -> Tuple (List.map (value u) ts)
  | Arrow (t, t') -> Arrow (value u t, value u t')
  | Box t -> Box (value u t)
  | Handler (t, t') -> Handler (value u t, value u t')

(* An unknown of [t] in the class of the root [a], found through the classes
   bound, with the pairs of each unknown of a bound class passed and the
   binder of its class. *)
let rec occurrence u a = function
  | Var b -> (
      let root = find u b in
      if TyParam.compare root a = 0 then Some (b, [])
      else
        match TyParamMap.find_opt root u.shapes with
        | Some { shape; binder; _ } ->
            Option.map
              (fun (c, pairs) -> (c, (b, binder) :: pairs))
              (occurrence u a shape)
        | None -> None)
  | t -> List.find_map (occurrence u a) (parts t)

let substitution u =
  let add a _ sigma =
    match value u (Var a) with
    | Var b when TyParam.compare a b = 0 -> sigma
    | t -> TyParamMap.add a t sigma
  in
  TyParamMap.empty
  |> TyParamMap.fold add u.parent
  |> TyParamMap.fold add u.shapes

(* One equation being solved: its payload, the reversed path of the
   sub-skeletons being unified, the labels of the equations it depends on, and
   the pairs of each unknown of a bound class met on the way and the binder of
   its class. *)
type 'info site = {
  info : 'info;
  rev_path : Ast.step list;
  because : ('info * Ast.step list) list;
  entered : (Ast.ty_param * Ast.ty_param) list;
}

(* A unification in progress: the unifier so far and the roots of the classes
   it has bound, latest first. *)
type 'info progress = { unifier : 'info unifier; bound : Ast.ty_param list }

(* The binding of each unknown of the classes bound in [st]. *)
let bindings st =
  List.fold_left
    (fun acc root ->
      let { binding; _ } = TyParamMap.find root st.unifier.shapes in
      TyParamSet.fold
        (fun a acc -> TyParamMap.add a binding acc)
        (members st.unifier root) acc)
    TyParamMap.empty st.bound

let descend site step = { site with rev_path = step :: site.rev_path }

(* [site] with the pair of [t] and the binder of its class, when [t] is an
   unknown of a bound class other than its binder. *)
let enter u site = function
  | Var a -> (
      match TyParamMap.find_opt (find u a) u.shapes with
      | Some { binder; _ } when TyParam.compare a binder <> 0 ->
          { site with entered = (a, binder) :: site.entered }
      | Some _ | None -> site)
  | _ -> site

(* The failure at [site], with the links on the explanations of [pairs] and of
   the pairs entered at [site], each with the skeleton its unknowns stand
   for. *)
let fail ?(pairs = []) site mismatch st lhs rhs =
  let u = st.unifier in
  let related (a, b) =
    List.map
      (fun (info, at) ->
        { joined_by = info; joined_at = at; joined = value u (Var a) })
      (explanation u a b)
  in
  Error
    ( {
        info = site.info;
        mismatch;
        lhs = value u lhs;
        rhs = value u rhs;
        path = List.rev site.rev_path;
      },
      {
        bindings = bindings st;
        related = List.concat_map related (pairs @ List.rev site.entered);
      } )

(* Where the value of an unknown facing the sub-skeleton [other], on side
   [side], comes from. *)
let source_of side = function Var b -> Through b | _ -> Side side

(* The unknown [t] is, or [a]. *)
let unknown_or a = function Var x -> x | _ -> a

(* The class of the unbound root [a], that of the unknown [var], bound to
   [t], the head of [other], with occurs check. *)
let bind site st a t ~var ~other ~source ~lhs ~rhs =
  let binder = unknown_or a var in
  match occurrence st.unifier a other with
  | Some (c, pairs) ->
      fail ~pairs:((binder, c) :: pairs) site (Occurs a) st lhs rhs
  | None ->
      let binding = { site = site.info; at = List.rev site.rev_path; source } in
      Ok
        {
          unifier =
            {
              st.unifier with
              shapes =
                TyParamMap.add a
                  { shape = t; binding; binder }
                  st.unifier.shapes;
            };
          bound = a :: st.bound;
        }

(* The outermost former of a skeleton and its parts. *)
let former : t -> (t, unit, unit) Former.t = function
  | Var a -> Former.Param a
  | Const c -> Former.Const c
  | Apply (name, ts) -> Former.Apply (name, ts)
  | Tuple ts -> Former.Tuple ts
  | Arrow (t, u) -> Former.Arrow (t, u, ())
  | Box t -> Former.Box ((), t)
  | Handler (t, u) -> Former.Handler ((t, ()), (u, ()))

(* [unify_at unfold site st lhs rhs] extends the unifier of [st] to a most
   general unifier of [lhs] and [rhs]. It is first-order unification with
   occurs check (Robinson, JACM 1965) on the union-find representation of the
   unifier (Huet, thesis 1976), by recursion on the two skeletons along
   {!Former.decompose}. *)
let rec unify_at unfold site st lhs rhs =
  let site = enter st.unifier (enter st.unifier site lhs) rhs in
  match (resolve st.unifier lhs, resolve st.unifier rhs) with
  | Var a, Var b when TyParam.compare a b = 0 -> Ok st
  | Var a, Var b ->
      let labels = (site.info, List.rev site.rev_path) :: site.because in
      Ok
        {
          st with
          unifier =
            union st.unifier (unknown_or a lhs, a) (unknown_or b rhs, b) labels;
        }
  | Var a, t ->
      bind site st a t ~var:lhs ~other:rhs ~source:(source_of Right rhs) ~lhs
        ~rhs
  | t, Var a ->
      bind site st a t ~var:rhs ~other:lhs ~source:(source_of Left lhs) ~lhs
        ~rhs
  | Apply (name, ts), Apply (name', us) ->
      unify_applications unfold site st (name, ts) (name', us)
  | Apply (name, ts), u -> unfold_left unfold site st (name, ts) u
  | t, Apply (name, us) -> unfold_right unfold site st t (name, us)
  | t, u -> unify_formers unfold site st t u ~lhs ~rhs

(* Two applications: an alias on either side is unfolded, otherwise the heads
   and arities must agree and the arguments are unified. *)
and unify_applications unfold site st (name, ts) (name', us) =
  match (unfold name ts, unfold name' us) with
  | Some t, _ -> unify_at unfold site st t (Apply (name', us))
  | None, Some u -> unify_at unfold site st (Apply (name, ts)) u
  | None, None ->
      let t = Apply (name, ts) and u = Apply (name', us) in
      unify_formers unfold site st t u ~lhs:t ~rhs:u

and unfold_left unfold site st (name, ts) u =
  match unfold name ts with
  | Some t -> unify_at unfold site st t u
  | None -> fail site Clash st (Apply (name, ts)) u

and unfold_right unfold site st t (name, us) =
  match unfold name us with
  | Some u -> unify_at unfold site st t u
  | None -> fail site Clash st t (Apply (name, us))

(* Two skeletons other than unknowns: their parts unified at their steps, or a
   clash between [lhs] and [rhs]. *)
and unify_formers unfold site st t u ~lhs ~rhs =
  match Former.decompose (former t) (former u) with
  | Some parts ->
      List.fold_left
        (fun st part ->
          match part with
          | Former.Ty (_, step, t, u) ->
              Result.bind st (fun st ->
                  unify_at unfold (descend site step) st t u)
          | Former.Rho _ | Former.Eps _ -> st)
        (Ok st) parts
  | None -> fail site Clash st lhs rhs

(* The equation [lhs = rhs] with payload [info] solved from [st], at the
   position [at], depending on the equations of [because]. *)
let unify_from ?(because = []) unfold st ~at ({ lhs; rhs; info } : _ equation) =
  unify_at unfold
    { info; rev_path = List.rev at; because; entered = [] }
    st lhs rhs

(* The equations solved left to right from [st]. *)
let solve unfold st equations =
  List.fold_left
    (fun st equation ->
      Result.bind st (fun st -> unify_from unfold st ~at:[] equation))
    (Ok st) equations

let unify unfold equations =
  Result.map
    (fun st -> substitution st.unifier)
    (Result.map_error fst
       (solve unfold { unifier = empty; bound = [] } equations))

module Make (X : GradeExp.S) = struct
  type ty = (X.rho, X.eps) Ast.ty
  type comp_ty = (X.rho, X.eps) Ast.comp_ty
  type ty_subst = ty TyParamMap.t

  let fresh_ty () = Ast.TyParam (TyParam.fresh "ty")
  let fresh_rho () = X.Rho.var (X.Rho_var.fresh_indexed ())
  let fresh_eps () = X.Eps.var (X.Eps_var.fresh_indexed ())

  (* Fresh variables are drawn left to right. *)
  let rec decorate : t -> ty = function
    | Var _ -> fresh_ty ()
    | Const c -> Ast.TyConst c
    | Apply (name, ts) -> Ast.TyApply (name, List.map decorate ts)
    | Tuple ts -> Ast.TyTuple (List.map decorate ts)
    | Arrow (t, u) ->
        let ty = decorate t in
        Ast.TyArrow (ty, decorate_comp u)
    | Box t ->
        let rho = fresh_rho () in
        Ast.TyBox (rho, decorate t)
    | Handler (t, u) ->
        let cty = decorate_comp t in
        Ast.TyHandler (cty, decorate_comp u)

  and decorate_comp t : comp_ty =
    let ty = decorate t in
    Ast.CompTy (ty, fresh_eps ())

  let substitute theta ty =
    Ast.substitute_ty theta ~on_rho:Fun.id ~on_eps:Fun.id ty

  (* Each unknown of the classes bound in [st] instantiated by a decoration of
     the skeleton its class is bound to, in the order of the unknowns; each
     decoration is unified with that skeleton, under the payload and at the
     position of the binding of the class, and depending on the equations
     that placed the unknown in the class of its binder, so that its unknowns
     join the classes at the same positions. *)
  let instantiate unfold st =
    let u = st.unifier in
    let unknowns =
      List.fold_left
        (fun acc root -> TyParamSet.union (members u root) acc)
        TyParamSet.empty st.bound
    in
    let theta =
      TyParamSet.fold
        (fun a -> TyParamMap.add a (decorate (value u (Var a))))
        unknowns TyParamMap.empty
    in
    let join st (a, ty) =
      let { binding; binder; _ } = TyParamMap.find (find u a) u.shapes in
      Result.bind st (fun st ->
          unify_from unfold st ~at:binding.at ~because:(explanation u a binder)
            { lhs = of_ty ty; rhs = Var a; info = binding.site })
    in
    Result.map
      (fun st -> (theta, st.unifier))
      (List.fold_left join
         (Ok { unifier = u; bound = [] })
         (TyParamMap.bindings theta))

  (* The skeletons of the demands unified under [u], and the unknowns of the
     classes they bind instantiated: the shape matching and expansion that
     reduce subtyping to atomic constraints (Fuh and Mishra, ESOP 1988;
     Mitchell, JFP 1991). *)
  let expand_traced unfold u demands =
    let equation ({ lhs; rhs; info } : (ty, _) GradeNormal.ordering) =
      { lhs = of_ty lhs; rhs = of_ty rhs; info }
    in
    Result.bind
      (solve unfold { unifier = u; bound = [] } (List.map equation demands))
      (fun st ->
        let bindings = bindings st in
        Result.map
          (fun (theta, u) -> (theta, u, bindings))
          (instantiate unfold st))

  let expand unfold demands =
    Result.map
      (fun (theta, _, _) -> theta)
      (Result.map_error fst (expand_traced unfold empty demands))
end
