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

(* One equation of the problem being solved: its payload and the reversed path
   of the sub-skeletons being unified. *)
type 'info site = { info : 'info; rev_path : Ast.step list }

(* The unifier so far, idempotent, and the bindings that made it. *)
type 'info unifier = { sigma : subst; bindings : 'info bindings }

let descend site step = { site with rev_path = step :: site.rev_path }

let fail site mismatch st lhs rhs =
  Error
    ( {
        info = site.info;
        mismatch;
        lhs = apply st.sigma lhs;
        rhs = apply st.sigma rhs;
        path = List.rev site.rev_path;
      },
      st.bindings )

(* Where the value of an unknown facing the sub-skeleton [other], on side
   [side], comes from. *)
let source_of side = function Var b -> Through b | _ -> Side side

(* The binding of [a] to [t], composed with the idempotent unifier so that the
   result is idempotent. *)
let bind site st a t ~source ~lhs ~rhs =
  let t = apply st.sigma t in
  if occurs a t then fail site (Occurs a) st lhs rhs
  else
    let single = TyParamMap.singleton a t in
    let binding = { site = site.info; at = List.rev site.rev_path; source } in
    Ok
      {
        sigma = TyParamMap.add a t (TyParamMap.map (apply single) st.sigma);
        bindings = TyParamMap.add a binding st.bindings;
      }

(* The head of [t] under [sigma]. *)
let resolve sigma = function
  | Var a as t -> Option.value (TyParamMap.find_opt a sigma) ~default:t
  | t -> t

(* The outermost former of a skeleton and its parts. *)
let former : t -> (t, unit, unit) Former.t = function
  | Var a -> Former.Param a
  | Const c -> Former.Const c
  | Apply (name, ts) -> Former.Apply (name, ts)
  | Tuple ts -> Former.Tuple ts
  | Arrow (t, u) -> Former.Arrow (t, u, ())
  | Box t -> Former.Box ((), t)
  | Handler (t, u) -> Former.Handler ((t, ()), (u, ()))

(* [unify_at unfold site st lhs rhs] extends the unifier [st] to a most general
   unifier of [lhs] and [rhs], both the rigid-rigid and the flexible cases. It
   is Robinson's first-order unification with occurs check (Robinson, JACM
   1965), by recursion on the two skeletons along {!Former.decompose}, the
   unifier an idempotent substitution. *)
let rec unify_at unfold site st lhs rhs =
  match (resolve st.sigma lhs, resolve st.sigma rhs) with
  | Var a, Var b when TyParam.compare a b = 0 -> Ok st
  | Var a, t -> bind site st a t ~source:(source_of Right rhs) ~lhs ~rhs
  | t, Var a -> bind site st a t ~source:(source_of Left lhs) ~lhs ~rhs
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

(* The equations solved left to right under one growing unifier. *)
let unify_traced unfold equations =
  let unify_equation st ({ lhs; rhs; info } : _ equation) =
    Result.bind st (fun st ->
        unify_at unfold { info; rev_path = [] } st lhs rhs)
  in
  Result.map
    (fun st -> (st.sigma, st.bindings))
    (List.fold_left unify_equation
       (Ok { sigma = TyParamMap.empty; bindings = TyParamMap.empty })
       equations)

let unify unfold equations =
  Result.map fst (Result.map_error fst (unify_traced unfold equations))

(* The pairs of unknowns at the same positions of [t] and [u], in reverse
   order onto [acc], when the two have one shape as they stand. *)
let rec aligned_onto acc t u =
  match (t, u) with
  | Var a, Var b -> Some ((a, b) :: acc)
  | t, u ->
      Option.bind
        (Former.decompose (former t) (former u))
        (fun parts ->
          List.fold_left
            (fun acc part ->
              match part with
              | Former.Ty (_, _, t, u) ->
                  Option.bind acc (fun acc -> aligned_onto acc t u)
              | Former.Rho _ | Former.Eps _ -> acc)
            (Some acc) parts)

let aligned t u = Option.map List.rev (aligned_onto [] t u)

(* A union-find forest on type unknowns with union by rank (Tarjan, JACM
   1975), persistent as a pair of finite maps: the parent of each unknown
   other than a root and the rank of each root above 0. *)
type classes = { parent : Ast.ty_param TyParamMap.t; rank : int TyParamMap.t }

let no_classes = { parent = TyParamMap.empty; rank = TyParamMap.empty }

let rec find classes a =
  match TyParamMap.find_opt a classes.parent with
  | Some b -> find classes b
  | None -> a

let rank classes a =
  Option.value (TyParamMap.find_opt a classes.rank) ~default:0

let join classes a b =
  let a = find classes a and b = find classes b in
  let under child root =
    { classes with parent = TyParamMap.add child root classes.parent }
  in
  let rank_a = rank classes a and rank_b = rank classes b in
  if TyParam.compare a b = 0 then classes
  else if rank_a < rank_b then under a b
  else if rank_a > rank_b then under b a
  else { (under b a) with rank = TyParamMap.add a (rank_a + 1) classes.rank }

let join_all classes pairs =
  List.fold_left (fun classes (a, b) -> join classes a b) classes pairs

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

  (* The left unknown of a demand between two unknowns. *)
  let between ({ lhs; rhs; _ } : (ty, _) GradeNormal.ordering) =
    match (lhs, rhs) with Ast.TyParam a, Ast.TyParam _ -> Some a | _ -> None

  (* The demands to unify, in order: those not between two unknowns, and those
     between two unknowns in the class of an unknown of the former. *)
  let select classes demands =
    let add_classes ty acc =
      Ast.fold_ty
        ~on_param:(fun a acc -> TyParamSet.add (find classes a) acc)
        ~on_rho:(fun _ acc -> acc)
        ~on_eps:(fun _ acc -> acc)
        ty acc
    in
    let touched =
      List.fold_left
        (fun acc (d : (ty, _) GradeNormal.ordering) ->
          match between d with
          | Some _ -> acc
          | None -> add_classes d.rhs (add_classes d.lhs acc))
        TyParamSet.empty demands
    in
    List.filter
      (fun d ->
        match between d with
        | Some a -> TyParamSet.mem (find classes a) touched
        | None -> true)
      demands

  (* Unifies the skeletons of the demands selected and instantiates the
     unknowns the unifier sends to a non-variable skeleton, by a decoration of
     it: the shape matching and expansion that reduce subtyping to atomic
     constraints (Fuh and Mishra, ESOP 1988; Mitchell, JFP 1991). Each unknown
     the unifier binds is joined with the unknowns its value has at the same
     positions, those of its decoration when it is instantiated. *)
  let expand_traced unfold classes demands =
    let equation ({ lhs; rhs; info } : (ty, _) GradeNormal.ordering) =
      { lhs = of_ty lhs; rhs = of_ty rhs; info }
    in
    let instantiate _ = function Var _ -> None | t -> Some (decorate t) in
    let join_aligned classes t u =
      Option.fold ~none:classes ~some:(join_all classes) (aligned t u)
    in
    Result.map
      (fun (sigma, bindings) ->
        let theta = TyParamMap.filter_map instantiate sigma in
        let value a =
          Option.value (TyParamMap.find_opt a theta) ~default:(Ast.TyParam a)
        in
        let classes =
          TyParamMap.fold
            (fun a t classes -> join_aligned classes t (of_ty (value a)))
            sigma classes
        in
        (theta, classes, bindings))
      (unify_traced unfold (List.map equation (select classes demands)))

  let expand unfold demands =
    let classes =
      List.fold_left
        (fun classes ({ lhs; rhs; _ } : (ty, _) GradeNormal.ordering) ->
          match (lhs, rhs) with
          | Ast.TyParam a, Ast.TyParam b -> join classes a b
          | _ -> classes)
        no_classes demands
    in
    Result.map
      (fun (theta, _, _) -> theta)
      (Result.map_error fst (expand_traced unfold classes demands))
end
