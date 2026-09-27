(* Reports: a solved definition simplified into a qualified scheme. *)

module Ast = Language.Ast
module TyParam = Ast.TyParamModule
module TyParamMap = Ast.TyParamMap
module TyParamSet = Ast.TyParamSet

module Make (C : Constraint.S) = struct
  module X = C.X
  module R = Residual.Make (C)
  module N = GradeNormal.Make (X)
  module Rho_set = X.Rho_var.Set
  module Eps_set = X.Eps_var.Set

  type context = R.context
  type hyps = R.hyps
  type deferred = R.deferred
  type t = { ty : C.ty; hyps : hyps; obligations : deferred list }

  (* ------------------------------------------------------------------ *)
  (* Unknowns and their occurrences                                      *)
  (* ------------------------------------------------------------------ *)

  (* An unknown of any sort. *)
  type unknown =
    | Ty_unknown of Ast.ty_param
    | Rho_unknown of X.Rho_var.t
    | Eps_unknown of X.Eps_var.t

  let same_param a b = TyParam.compare a b = 0

  let is_param u (ty : C.ty) =
    match (u, ty) with
    | Ty_unknown a, Ast.TyParam b -> same_param a b
    | (Ty_unknown _ | Rho_unknown _ | Eps_unknown _), _ -> false

  let in_rho u rho =
    match u with
    | Ty_unknown _ -> false
    | Rho_unknown k -> X.Rho.mem_rho_var k rho
    | Eps_unknown k -> X.Rho.mem_eps_var k rho

  let in_eps u eps =
    match u with
    | Ty_unknown _ | Rho_unknown _ -> false
    | Eps_unknown k -> X.Eps.mem_var k eps

  (* ------------------------------------------------------------------ *)
  (* Polarity                                                            *)
  (* ------------------------------------------------------------------ *)

  (* Whether some occurrence bounds the unknown above, or below. *)
  type polarity = { above : bool; below : bool }

  let neither = { above = false; below = false }
  let ( ++ ) p q = { above = p.above || q.above; below = p.below || q.below }

  let union_map f items =
    List.fold_left (fun p item -> p ++ f item) neither items

  (* The side of an ordering, or the variance of a position in a type. *)
  type sign = Plus | Minus

  let flip = function Plus -> Minus | Minus -> Plus

  let at sign occurs =
    match sign with
    | Plus -> { above = occurs; below = false }
    | Minus -> { above = false; below = occurs }

  let invariant p =
    let occurs = p.above || p.below in
    { above = occurs; below = occurs }

  let rec in_ty u sign (ty : C.ty) =
    match ty with
    | Ast.TyConst _ -> neither
    | Ast.TyParam _ -> at sign (is_param u ty)
    | Ast.TyTuple tys -> union_map (in_ty u sign) tys
    | Ast.TyApply (_, tys) -> invariant (union_map (in_ty u sign) tys)
    | Ast.TyArrow (ty, cty) -> in_ty u (flip sign) ty ++ in_comp_ty u sign cty
    | Ast.TyBox (rho, ty) -> at (flip sign) (in_rho u rho) ++ in_ty u sign ty
    | Ast.TyHandler (cty, cty') ->
        invariant (in_comp_ty u sign cty) ++ in_comp_ty u sign cty'

  and in_comp_ty u sign (Ast.CompTy (ty, eps)) =
    in_ty u sign ty ++ at sign (in_eps u eps)

  let in_ordering occurs (o : _ GradeNormal.ordering) =
    at Plus (occurs o.lhs) ++ at Minus (occurs o.rhs)

  (* ------------------------------------------------------------------ *)
  (* Hypotheses                                                          *)
  (* ------------------------------------------------------------------ *)

  let free_hyps hyps = C.free_vars (R.hyps_to_constraint hyps)

  let grades_of (hyps : hyps) : R.reason N.hyps =
    { rho_hyps = hyps.rho_hyps; eps_hyps = hyps.eps_hyps }

  let mem equal lhs rhs orderings =
    List.exists
      (fun (o : _ GradeNormal.ordering) -> equal o.lhs lhs && equal o.rhs rhs)
      orderings

  (* An ordering entailed: one of the hypotheses, or derived from them. Applied
     to [context] and [grades] alone, the decision procedure of the hypotheses
     is shared by the orderings decided. *)
  let entails_rho context (grades : R.reason N.hyps) =
    let bounds = context.Residual.bounds in
    let decide = N.Rho.decide_leq bounds grades in
    fun lhs rhs ->
      mem (X.Rho.equal bounds) lhs rhs grades.rho_hyps
      || N.Rho.closed_leq bounds lhs rhs = Some true
      || Option.is_some (decide lhs rhs)

  let entails_eps context (grades : R.reason N.hyps) =
    let bounds = context.Residual.bounds in
    let decide = N.Eps.decide_leq bounds grades in
    fun lhs rhs ->
      mem (X.Eps.equal bounds) lhs rhs grades.eps_hyps
      || N.Eps.closed_leq bounds lhs rhs = Some true
      || Option.is_some (decide lhs rhs)

  let rec same_ty context (a : C.ty) (b : C.ty) =
    match (a, b) with
    | Ast.TyConst c, Ast.TyConst c' -> c = c'
    | Ast.TyParam a, Ast.TyParam b -> same_param a b
    | Ast.TyApply (name, tys), Ast.TyApply (name', tys') ->
        Ast.TyName.compare name name' = 0 && same_tys context tys tys'
    | Ast.TyTuple tys, Ast.TyTuple tys' -> same_tys context tys tys'
    | Ast.TyArrow (ty, cty), Ast.TyArrow (ty', cty') ->
        same_ty context ty ty' && same_comp_ty context cty cty'
    | Ast.TyBox (rho, ty), Ast.TyBox (rho', ty') ->
        X.Rho.equal context.Residual.bounds rho rho' && same_ty context ty ty'
    | Ast.TyHandler (c1, c2), Ast.TyHandler (c1', c2') ->
        same_comp_ty context c1 c1' && same_comp_ty context c2 c2'
    | ( ( Ast.TyConst _ | Ast.TyParam _ | Ast.TyApply _ | Ast.TyTuple _
        | Ast.TyArrow _ | Ast.TyBox _ | Ast.TyHandler _ ),
        _ ) ->
        false

  and same_tys context tys tys' =
    List.compare_lengths tys tys' = 0
    && List.for_all2 (same_ty context) tys tys'

  and same_comp_ty context (Ast.CompTy (ty, eps)) (Ast.CompTy (ty', eps')) =
    same_ty context ty ty' && X.Eps.equal context.Residual.bounds eps eps'

  (* ------------------------------------------------------------------ *)
  (* Subtyping and eternality atoms                                      *)
  (* ------------------------------------------------------------------ *)

  let edge (s : R.sub) =
    match (s.lhs, s.rhs) with
    | Ast.TyParam a, Ast.TyParam b -> Some (a, b)
    | _, _ -> None

  let edges subs = List.filter_map edge subs

  (* The targets of the edges out of each type unknown, in order. *)
  let successors edges =
    List.fold_right
      (fun (a, b) succ ->
        TyParamMap.update a
          (fun bs -> Some (b :: Option.value bs ~default:[]))
          succ)
      edges TyParamMap.empty

  let targets succ a = Option.value (TyParamMap.find_opt a succ) ~default:[]

  (* The type unknowns reached from [a] along [succ], in none or more
     steps. *)
  let reached succ a =
    let rec visit seen = function
      | [] -> seen
      | v :: rest when TyParamSet.mem v seen -> visit seen rest
      | v :: rest -> visit (TyParamSet.add v seen) (targets succ v @ rest)
    in
    visit TyParamSet.empty [ a ]

  (* Whether [b] is reached from [a] along [edges], in none or more steps. *)
  let reaches edges a b = TyParamSet.mem b (reached (successors edges) a)

  (* The type unknowns joined to [seeds] by [edges] in either direction. *)
  let rec joined edges seeds =
    let grown =
      List.fold_left
        (fun set (a, b) ->
          if TyParamSet.mem a set || TyParamSet.mem b set then
            TyParamSet.add a (TyParamSet.add b set)
          else set)
        seeds edges
    in
    if TyParamSet.equal grown seeds then seeds else joined edges grown

  let eternal_params eternals =
    TyParamSet.of_list
      (List.filter_map
         (fun (e : R.eternal) ->
           match e.eternal_ty with Ast.TyParam a -> Some a | _ -> None)
         eternals)

  (* The type unknowns entailed eternal by [hyps]. *)
  let eternal (hyps : hyps) =
    joined (edges hyps.sub_vars) (eternal_params hyps.eternal_hyps)

  (* ------------------------------------------------------------------ *)
  (* Canonical forms                                                     *)
  (* ------------------------------------------------------------------ *)

  let canon_ty context =
    let bounds = context.Residual.bounds in
    Ast.map_ty ~on_rho:(N.Rho.canon bounds) ~on_eps:(N.Eps.canon bounds)

  let canon_hyps context (hyps : hyps) =
    let bounds = context.Residual.bounds in
    let grades = N.canon_hyps bounds (grades_of hyps) in
    {
      hyps with
      rho_hyps = grades.rho_hyps;
      eps_hyps = grades.eps_hyps;
      disj_hyps =
        List.map
          (fun (d : R.disjunction) ->
            {
              d with
              disj_ty = canon_ty context d.disj_ty;
              disj_grade = N.Rho.canon bounds d.disj_grade;
            })
          hyps.disj_hyps;
    }

  let canon_deferred context (d : deferred) =
    let bounds = context.Residual.bounds in
    {
      d with
      rho_conditions = N.Rho.canon_orderings bounds d.rho_conditions;
      eps_conditions = N.Eps.canon_orderings bounds d.eps_conditions;
    }

  (* ------------------------------------------------------------------ *)
  (* Walks                                                               *)
  (* ------------------------------------------------------------------ *)

  (* The items that [settled ~seen ~rest] does not settle, in order; [seen]
     is the items kept before an item, [rest] those after it. *)
  let walk settled items =
    let rec go seen = function
      | [] -> List.rev seen
      | item :: rest ->
          if settled ~seen ~rest item then go seen rest
          else go (item :: seen) rest
    in
    go [] items

  (* ------------------------------------------------------------------ *)
  (* Disjunctions                                                        *)
  (* ------------------------------------------------------------------ *)

  let below_unit (d : R.disjunction) : R.rho_ordering =
    { lhs = d.disj_grade; rhs = X.Rho.unit; info = d.disj_reason }

  (* The hypotheses [acc] with the disjunction [d] settled against them. *)
  let settle context (d : R.disjunction) (acc : hyps) =
    if entails_rho context (grades_of acc) d.disj_grade X.Rho.unit then acc
    else
      match R.eternal_vars context d.disj_ty with
      | None -> { acc with rho_hyps = acc.rho_hyps @ [ below_unit d ] }
      | Some params ->
          let entailed = eternal acc in
          if List.for_all (fun a -> TyParamSet.mem a entailed) params then acc
          else if
            Option.is_some
              (N.Rho.refute_leq_unit context.Residual.bounds d.disj_grade)
          then
            let atom a : R.eternal =
              { eternal_ty = Ast.TyParam a; eternal_reason = d.disj_reason }
            in
            { acc with eternal_hyps = List.map atom params @ acc.eternal_hyps }
          else { acc with disj_hyps = d :: acc.disj_hyps }

  (* The disjunctions entailed by another dropped: one of the same type with
     a grade entailed above. *)
  let walk_disjunctions context (hyps : hyps) =
    let entails = entails_rho context (grades_of hyps) in
    let entailed ~seen ~rest (d : R.disjunction) =
      List.exists
        (fun (d' : R.disjunction) ->
          same_ty context d.disj_ty d'.disj_ty
          && entails d.disj_grade d'.disj_grade)
        (seen @ rest)
    in
    { hyps with disj_hyps = walk entailed hyps.disj_hyps }

  let settle_all context (hyps : hyps) =
    walk_disjunctions context
      (List.fold_right (settle context) hyps.disj_hyps
         { hyps with disj_hyps = [] })

  (* ------------------------------------------------------------------ *)
  (* Pruning and trimming                                                *)
  (* ------------------------------------------------------------------ *)

  (* The subtyping atoms reached along those kept before them dropped. *)
  let prune_subs subs =
    let keep (kept, succ) s =
      match edge s with
      | Some (a, b) when TyParamSet.mem b (reached succ a) -> (kept, succ)
      | Some (a, b) -> (s :: kept, TyParamMap.add a (b :: targets succ a) succ)
      | None -> (s :: kept, succ)
    in
    List.rev (fst (List.fold_left keep ([], TyParamMap.empty) subs))

  (* The eternality atoms joined to those kept before them dropped. *)
  let prune_eternals subs eternals =
    let edges = edges subs in
    List.rev
      (List.fold_left
         (fun kept (e : R.eternal) ->
           match e.eternal_ty with
           | Ast.TyParam a
             when TyParamSet.mem a (joined edges (eternal_params kept)) ->
               kept
           | _ -> e :: kept)
         [] eternals)

  let repeated equal ~seen ~rest:_ (o : _ GradeNormal.ordering) =
    equal o.lhs o.rhs || mem equal o.lhs o.rhs seen

  let prune context (hyps : hyps) =
    let bounds = context.Residual.bounds in
    let sub_vars = prune_subs hyps.sub_vars in
    {
      hyps with
      sub_vars;
      eternal_hyps = prune_eternals sub_vars hyps.eternal_hyps;
      eps_hyps = walk (repeated (X.Eps.equal bounds)) hyps.eps_hyps;
      rho_hyps = walk (repeated (X.Rho.equal bounds)) hyps.rho_hyps;
    }

  let simplify context hyps =
    prune context (settle_all context (canon_hyps context hyps))

  (* Each atom entailed by the others dropped in turn; on the subtyping atoms
     a greedy minimal equivalent graph, the transitive reduction where they
     are acyclic (Aho, Garey and Ullman, SIAM J. Comput. 1972). *)
  let trim context hyps =
    let hyps = settle_all context hyps in
    let reached ~seen ~rest s =
      match edge s with
      | Some (a, b) -> reaches (edges (seen @ rest)) a b
      | None -> false
    in
    let sub_vars = walk reached hyps.sub_vars in
    let eps_hyps =
      walk
        (fun ~seen ~rest (o : R.eps_ordering) ->
          entails_eps context
            { rho_hyps = []; eps_hyps = seen @ rest }
            o.lhs o.rhs)
        hyps.eps_hyps
    in
    let rho_hyps =
      walk
        (fun ~seen ~rest (o : R.rho_ordering) ->
          entails_rho context { rho_hyps = seen @ rest; eps_hyps } o.lhs o.rhs)
        hyps.rho_hyps
    in
    {
      hyps with
      sub_vars;
      eternal_hyps = prune_eternals sub_vars hyps.eternal_hyps;
      eps_hyps;
      rho_hyps;
    }

  (* ------------------------------------------------------------------ *)
  (* Elimination: atoms and their index                                  *)
  (* ------------------------------------------------------------------ *)

  module Unknown = struct
    type t = unknown

    let rank = function
      | Ty_unknown _ -> 0
      | Rho_unknown _ -> 1
      | Eps_unknown _ -> 2

    let compare u v =
      match (u, v) with
      | Ty_unknown a, Ty_unknown b -> TyParam.compare a b
      | Rho_unknown k, Rho_unknown k' -> X.Rho_var.compare k k'
      | Eps_unknown k, Eps_unknown k' -> X.Eps_var.compare k k'
      | (Ty_unknown _ | Rho_unknown _ | Eps_unknown _), _ ->
          Int.compare (rank u) (rank v)
  end

  module Unknown_map = Map.Make (Unknown)
  module Unknown_set = Set.Make (Unknown)
  module Int_map = Map.Make (Int)
  module Int_set = Set.Make (Int)

  (* A hypothesis of any kind. *)
  type atom =
    | Rho_atom of R.rho_ordering
    | Eps_atom of R.eps_ordering
    | Sub_atom of R.sub
    | Eternal_atom of R.eternal
    | Disj_atom of R.disjunction

  let add_eps eps us =
    Eps_set.fold
      (fun k -> Unknown_set.add (Eps_unknown k))
      (X.Eps.free_vars eps) us

  let add_rho rho us =
    Rho_set.fold
      (fun k -> Unknown_set.add (Rho_unknown k))
      (X.Rho.free_rho_vars rho)
      (Eps_set.fold
         (fun k -> Unknown_set.add (Eps_unknown k))
         (X.Rho.free_eps_vars rho) us)

  let add_ty ty us =
    Ast.fold_ty
      ~on_param:(fun a -> Unknown_set.add (Ty_unknown a))
      ~on_rho:add_rho ~on_eps:add_eps ty us

  (* The unknowns of an atom, its reason aside. *)
  let atom_unknowns atom =
    let none = Unknown_set.empty in
    match atom with
    | Rho_atom o -> add_rho o.lhs (add_rho o.rhs none)
    | Eps_atom o -> add_eps o.lhs (add_eps o.rhs none)
    | Sub_atom s -> add_ty s.lhs (add_ty s.rhs none)
    | Eternal_atom e -> add_ty e.eternal_ty none
    | Disj_atom d -> add_ty d.disj_ty (add_rho d.disj_grade none)

  (* The unknowns of the values of a substitution. *)
  let value_unknowns (sigma : C.subst) =
    let us =
      TyParamMap.fold (fun _ ty -> add_ty ty) sigma.ty_subst Unknown_set.empty
    in
    let us =
      X.Rho_var.Map.fold
        (fun _ rho -> add_rho rho)
        sigma.grade_subst.rho_subst us
    in
    X.Eps_var.Map.fold (fun _ eps -> add_eps eps) sigma.grade_subst.eps_subst us

  (* The polarity of [u] in an atom. *)
  let in_atom u = function
    | Rho_atom o -> in_ordering (in_rho u) o
    | Eps_atom o -> in_ordering (in_eps u) o
    | Sub_atom s -> in_ty u Plus s.lhs ++ in_ty u Minus s.rhs
    | Eternal_atom _ -> neither
    | Disj_atom d -> at Plus (in_rho u d.disj_grade)

  (* An atom under [sigma], its reason aside. *)
  let subst_atom (sigma : C.subst) atom =
    let on_rho = X.Rho.subst sigma.grade_subst
    and on_eps = X.Eps.subst sigma.grade_subst
    and on_ty = C.subst_ty sigma in
    match atom with
    | Rho_atom o -> Rho_atom { o with lhs = on_rho o.lhs; rhs = on_rho o.rhs }
    | Eps_atom o -> Eps_atom { o with lhs = on_eps o.lhs; rhs = on_eps o.rhs }
    | Sub_atom s -> Sub_atom { s with lhs = on_ty s.lhs; rhs = on_ty s.rhs }
    | Eternal_atom e -> Eternal_atom { e with eternal_ty = on_ty e.eternal_ty }
    | Disj_atom d ->
        Disj_atom
          { d with disj_ty = on_ty d.disj_ty; disj_grade = on_rho d.disj_grade }

  let is_reflexive context atom =
    let bounds = context.Residual.bounds in
    match atom with
    | Rho_atom o -> X.Rho.equal bounds o.lhs o.rhs
    | Eps_atom o -> X.Eps.equal bounds o.lhs o.rhs
    | Sub_atom s -> same_ty context s.lhs s.rhs
    | Eternal_atom _ | Disj_atom _ -> false

  (* The composite of substitutions [steps], the last first, each sending
     unknowns of none of the later ones to expressions free of the earlier
     ones: each unknown sent to its value under the later steps. *)
  let resolve steps =
    List.fold_left
      (fun (later : X.subst) (s : X.subst) : X.subst ->
        {
          rho_subst =
            X.Rho_var.Map.fold
              (fun k rho -> X.Rho_var.Map.add k (X.Rho.subst later rho))
              s.rho_subst later.rho_subst;
          eps_subst =
            X.Eps_var.Map.fold
              (fun k eps -> X.Eps_var.Map.add k (X.Eps.subst later eps))
              s.eps_subst later.eps_subst;
        })
      X.empty_subst steps

  (* ------------------------------------------------------------------ *)
  (* Elimination: steps                                                  *)
  (* ------------------------------------------------------------------ *)

  (* The kinds of step, in the order they are tried. *)
  type kind =
    | Equate_eps
    | Equate_rho
    | Lower_eps
    | Lower_rho
    | Raise_eps
    | Raise_rho
    | Collapse
    | Lower_ty

  let kinds =
    [
      Equate_eps;
      Equate_rho;
      Lower_eps;
      Lower_rho;
      Raise_eps;
      Raise_rho;
      Collapse;
      Lower_ty;
    ]

  module Kind_map = Map.Make (struct
    type t = kind

    let rank = function
      | Equate_eps -> 0
      | Equate_rho -> 1
      | Lower_eps -> 2
      | Lower_rho -> 3
      | Raise_eps -> 4
      | Raise_rho -> 5
      | Collapse -> 6
      | Lower_ty -> 7

    let compare a b = Int.compare (rank a) (rank b)
  end)

  (* Whether a kind of step is tested at an unknown alone, and at [u]. *)
  let tested_at kind u =
    match (kind, u) with
    | (Equate_eps | Lower_eps | Raise_eps), Eps_unknown _
    | (Equate_rho | Lower_rho | Raise_rho), Rho_unknown _
    | Lower_ty, Ty_unknown _ ->
        true
    | ( ( Equate_eps | Equate_rho | Lower_eps | Lower_rho | Raise_eps
        | Raise_rho | Collapse | Lower_ty ),
        _ ) ->
        false

  (* A step at an unknown: the substitution sending it to its value, the
     atoms dropped with it, and whether the atoms made reflexive are dropped
     after it. *)
  type plan = {
    value : C.subst;
    dropped : Int_set.t;
    apart : bool;
    chains : bool; (* whether it may add chains of atomic orderings *)
  }

  (* The tests of one kind: the unknowns where it succeeds, with the step,
     and, apart from them, the unknowns to be tested again. *)
  type tests = { passed : plan Unknown_map.t; stale : Unknown_set.t }

  (* An atom and its unknowns. *)
  type entry = { atom : atom; unknowns : Unknown_set.t }

  type env = {
    context : context;
    fixed : C.free;
    candidates : Unknown_set.t; (* the unknowns outside [fixed] *)
    tested : Unknown_set.t Kind_map.t;
        (* the candidates tested by each kind of step *)
  }

  type state = {
    ty : C.ty;
    atoms : entry Int_map.t; (* the hypotheses, by position *)
    occurrences : Int_set.t Unknown_map.t;
        (* the positions of the atoms of each unknown *)
    reflexive : Int_set.t;
        (* the positions of the reflexive orderings and subtyping atoms *)
    steps : X.subst list;
        (* the grade substitutions of the steps taken, the last first *)
    tests : tests Kind_map.t; (* the tests of each kind but collapsing *)
    cycle : (unknown * plan) list option;
        (* the collapsing steps due, in order, once found *)
  }

  let atom_at st id = (Int_map.find id st.atoms).atom

  let occurrences st u =
    Option.value (Unknown_map.find_opt u st.occurrences) ~default:Int_set.empty

  (* The atom at [id] set to [atom], or removed, its unknowns having been
     [before] and being [after]. *)
  let reindex context id atom ~before ~after st =
    let add ids =
      Some (Int_set.add id (Option.value ids ~default:Int_set.empty))
    and remove ids = Option.map (Int_set.remove id) ids in
    let update f us occurrences =
      Unknown_set.fold (fun u -> Unknown_map.update u f) us occurrences
    in
    let occurrences =
      update add
        (Unknown_set.diff after before)
        (update remove (Unknown_set.diff before after) st.occurrences)
    in
    match atom with
    | Some atom ->
        {
          st with
          atoms = Int_map.add id { atom; unknowns = after } st.atoms;
          occurrences;
          reflexive =
            (if is_reflexive context atom then Int_set.add id st.reflexive
             else Int_set.remove id st.reflexive);
        }
    | None ->
        {
          st with
          atoms = Int_map.remove id st.atoms;
          occurrences;
          reflexive = Int_set.remove id st.reflexive;
        }

  (* The atom at [id] replaced by [f] of it, or removed, with the unknowns of
     both added to [touched]. *)
  let replace context f id (st, touched) =
    let { atom; unknowns = before } = Int_map.find id st.atoms in
    let atom' = f atom in
    let after = Option.fold ~none:Unknown_set.empty ~some:atom_unknowns atom' in
    ( reindex context id atom' ~before ~after st,
      Unknown_set.union touched (Unknown_set.union before after) )

  (* The tests of [kind] at [us] due again. *)
  let due us t =
    {
      passed = Unknown_set.fold Unknown_map.remove us t.passed;
      stale = Unknown_set.union t.stale us;
    }

  (* The tests at the unknowns in [touched] due again. *)
  let mark env touched st =
    let touched = Unknown_set.inter touched env.candidates in
    let tys, grades =
      Unknown_set.partition
        (function
          | Ty_unknown _ -> true | Rho_unknown _ | Eps_unknown _ -> false)
        touched
    in
    let rhos, eps =
      Unknown_set.partition
        (function
          | Rho_unknown _ -> true | Ty_unknown _ | Eps_unknown _ -> false)
        grades
    in
    let mark_kind kind t =
      let us =
        match kind with
        | Equate_eps | Lower_eps | Raise_eps -> eps
        | Equate_rho | Lower_rho | Raise_rho -> rhos
        | Lower_ty -> tys
        | Collapse -> Unknown_set.empty
      in
      if Unknown_set.is_empty us then t else due us t
    in
    if Unknown_set.is_empty touched then st
    else { st with tests = Kind_map.mapi mark_kind st.tests }

  (* The tests of [kind] due again at the unknowns where it succeeds. *)
  let mark_passed kind st =
    let again t =
      due
        (Unknown_map.fold
           (fun u _ -> Unknown_set.add u)
           t.passed Unknown_set.empty)
        t
    in
    { st with tests = Kind_map.update kind (Option.map again) st.tests }

  (* The tests of [kind] due again at every unknown. *)
  let mark_all env kind st =
    {
      st with
      tests =
        Kind_map.add kind
          { passed = Unknown_map.empty; stale = Kind_map.find kind env.tested }
          st.tests;
    }

  (* The step [plan] of [kind] taken at [u].

     Only the collapsing steps and the lowering of type unknowns change the
     subtyping atoms between type unknowns. After a collapsing step the others
     stay due: the components of the other unknowns and their representatives
     are those before it. A lowering step, taken when none is due, closes no
     cycle: a cycle through [β <: y], from [a <: y] with [a] sent to [β], was
     one through [β <: a <: y].

     After an equating step the equating tests that succeeded are taken
     again, and every equating test when the step may add chains. *)
  let take env kind u plan st =
    let context = env.context and cycle = st.cycle in
    let drop _ = None in
    let st, touched =
      Int_set.fold (replace context drop) plan.dropped
        (st, Unknown_set.singleton u)
    in
    let st, touched =
      Int_set.fold
        (replace context (fun atom -> Some (subst_atom plan.value atom)))
        (occurrences st u) (st, touched)
    in
    let grades = plan.value.grade_subst in
    let st =
      {
        st with
        ty = C.subst_ty plan.value st.ty;
        steps =
          (if
             X.Rho_var.Map.is_empty grades.rho_subst
             && X.Eps_var.Map.is_empty grades.eps_subst
           then st.steps
           else grades :: st.steps);
      }
    in
    let st, touched =
      if plan.apart then
        Int_set.fold (replace context drop) st.reflexive (st, touched)
      else (st, touched)
    in
    let st =
      mark env (Unknown_set.union touched (value_unknowns plan.value)) st
    in
    let equate kinds =
      let again = if plan.chains then mark_all env else mark_passed in
      List.fold_left (fun st kind -> again kind st) st kinds
    in
    match (kind, cycle) with
    | Equate_eps, _ -> equate [ Equate_eps; Equate_rho ]
    | Equate_rho, _ -> equate [ Equate_rho ]
    | Collapse, Some (_ :: rest) -> { st with cycle = Some rest }
    | (Lower_eps | Lower_rho | Raise_eps | Raise_rho | Collapse | Lower_ty), _
      ->
        st

  (* ------------------------------------------------------------------ *)
  (* Elimination: tests                                                  *)
  (* ------------------------------------------------------------------ *)

  let decided_rho context = entails_rho context N.no_hyps
  let decided_eps context = entails_eps context N.no_hyps

  let eps_sort context k : _ Bounds.sort =
    {
      equal = X.Eps.equal context.Residual.bounds;
      occurs = in_eps (Eps_unknown k);
      is_unknown =
        (function X.Eps_var k' -> X.Eps_var.equal k k' | _ -> false);
      leq = decided_eps context;
      join = X.Eps.join;
    }

  let rho_sort context k : _ Bounds.sort =
    {
      equal = X.Rho.equal context.Residual.bounds;
      occurs = in_rho (Rho_unknown k);
      is_unknown =
        (function X.Rho_var k' -> X.Rho_var.equal k k' | _ -> false);
      leq = decided_rho context;
      join = X.Rho.join;
    }

  let assign_eps k eps : C.subst =
    {
      C.empty_subst with
      grade_subst =
        { X.empty_subst with eps_subst = X.Eps_var.Map.singleton k eps };
    }

  let assign_rho k rho : C.subst =
    {
      C.empty_subst with
      grade_subst =
        { X.empty_subst with rho_subst = X.Rho_var.Map.singleton k rho };
    }

  let assign_ty a b : C.subst =
    { C.empty_subst with ty_subst = TyParamMap.singleton a (Ast.TyParam b) }

  (* A grade unknown and how the orderings of its sort are read for it. *)
  type 'e grade = {
    unknown : unknown;
    self : 'e; (* the unknown as an expression *)
    sort : 'e Bounds.sort;
    ordering : atom -> ('e, R.reason) GradeNormal.ordering option;
    earlier : 'e -> bool option;
        (* for a variable, whether it is created before the unknown *)
    assign : 'e -> C.subst;
    atomic : 'e -> bool;
        (* whether an expression is a single atom of the decision procedure *)
  }

  let eps_grade context k =
    {
      unknown = Eps_unknown k;
      self = X.Eps.var k;
      sort = eps_sort context k;
      ordering = (function Eps_atom o -> Some o | _ -> None);
      earlier =
        (function X.Eps_var j -> Some (X.Eps_var.compare j k < 0) | _ -> None);
      assign = assign_eps k;
      atomic = (function X.Eps_var _ | X.Eps_const _ -> true | _ -> false);
    }

  let rho_grade context k =
    {
      unknown = Rho_unknown k;
      self = X.Rho.var k;
      sort = rho_sort context k;
      ordering = (function Rho_atom o -> Some o | _ -> None);
      earlier =
        (function X.Rho_var j -> Some (X.Rho_var.compare j k < 0) | _ -> None);
      assign = assign_rho k;
      atomic =
        (function
        | X.Rho_var _ | X.Rho_const _ | X.Rho_map (X.Eps_var _) -> true
        | _ -> false);
    }

  (* The orderings of the sort of [g] at its unknown, in order, each carrying
     its position. *)
  let orderings g st =
    List.filter_map
      (fun id ->
        Option.map
          (fun (o : _ GradeNormal.ordering) -> { o with info = id })
          (g.ordering (atom_at st id)))
      (Int_set.elements (occurrences st g.unknown))

  let positions orderings =
    Int_set.of_list
      (List.map (fun (o : _ GradeNormal.ordering) -> o.info) orderings)

  (* Whether a value for [u] is blocked: [pick] holds of the polarity of [u]
     in the atoms other than [dropped] or in the reported type. *)
  let blocked pick u st dropped =
    pick (in_ty u Plus st.ty)
    || Int_set.exists
         (fun id ->
           (not (Int_set.mem id dropped)) && pick (in_atom u (atom_at st id)))
         (occurrences st u)

  (* The first expression facing the unknown, an earlier unknown or free of
     it, that the hypotheses equate with it. *)
  let equal_value ~occurs ~earlier ~entails facing unknown =
    List.find_opt
      (fun b ->
        (match earlier b with
          | Some earlier -> earlier
          | None -> not (occurs b))
        && entails unknown b && entails b unknown)
      facing

  (* Whether an ordering [lhs ≾ rhs] of the sort of [g] is [atom]. *)
  let is_ordering g lhs rhs atom =
    match g.ordering atom with
    | Some o -> g.sort.equal o.lhs lhs && g.sort.equal o.rhs rhs
    | None -> false

  (* Whether sending the unknown [v] of [g] to [b] may add chains of atomic
     orderings: [b] is a single atom, and some grade ordering bounds [v] below
     without [v ≾ b] assumed, or above without [b ≾ v] assumed, [x ≾ v]
     becoming [x ≾ b] and [v ≾ y] becoming [b ≾ y]. *)
  let adds_chains g st b =
    let atoms =
      List.map (atom_at st) (Int_set.elements (occurrences st g.unknown))
    in
    let assumed lhs rhs = List.exists (is_ordering g lhs rhs) atoms in
    let bounded pick lhs rhs =
      List.exists
        (fun atom ->
          match atom with
          | Rho_atom _ | Eps_atom _ ->
              (not (is_ordering g lhs rhs atom))
              && pick (in_atom g.unknown atom)
          | Sub_atom _ | Eternal_atom _ | Disj_atom _ -> false)
        atoms
    in
    g.atomic b
    && ((bounded (fun p -> p.below) b g.self && not (assumed g.self b))
       || (bounded (fun p -> p.above) g.self b && not (assumed b g.self)))

  (* The expressions the orderings set against the unknown, in order: the
     right side where it is the left side, else the left side where it is the
     right side. *)
  let equate g entails st =
    let face id facing =
      match g.ordering (atom_at st id) with
      | Some o when g.sort.is_unknown o.lhs -> o.rhs :: facing
      | Some o when g.sort.is_unknown o.rhs -> o.lhs :: facing
      | Some _ | None -> facing
    in
    let facing = List.rev (Int_set.fold face (occurrences st g.unknown) []) in
    Option.map
      (fun b ->
        {
          value = g.assign b;
          dropped = Int_set.empty;
          apart = true;
          chains = adds_chains g st b;
        })
      (equal_value ~occurs:g.sort.occurs ~earlier:g.earlier ~entails facing
         g.self)

  let lower g st =
    let os = orderings g st in
    match Bounds.lows g.sort os with
    | Some { lower = x :: xs; lower_rest } ->
        let dropped = Int_set.diff (positions os) (positions lower_rest) in
        if blocked (fun p -> p.below) g.unknown st dropped then None
        else
          Some
            {
              value = g.assign (Bounds.join_all g.sort x xs);
              dropped;
              apart = false;
              chains = false;
            }
    | Some { lower = []; _ } | None -> None

  let raise_to_cap g st =
    let os = orderings g st in
    match Bounds.ups g.sort os with
    | Some { cap; upper_rest } ->
        let dropped = Int_set.diff (positions os) (positions upper_rest) in
        if blocked (fun p -> p.above) g.unknown st dropped then None
        else
          Some { value = g.assign cap; dropped; apart = false; chains = false }
    | None -> None

  (* The first subtyping atom [β <: a]: a type unknown with a lower bound
     sent to it. *)
  let lower_ty a st =
    let u = Ty_unknown a in
    let lower_bound id =
      match atom_at st id with
      | Sub_atom s -> (
          match edge s with
          | Some (b, a') when same_param a a' -> Some (id, b)
          | Some _ | None -> None)
      | Rho_atom _ | Eps_atom _ | Eternal_atom _ | Disj_atom _ -> None
    in
    match List.find_map lower_bound (Int_set.elements (occurrences st u)) with
    | Some (id, b) when not (same_param a b) ->
        let dropped = Int_set.singleton id in
        if blocked (fun p -> p.below) u st dropped then None
        else
          Some { value = assign_ty a b; dropped; apart = true; chains = false }
    | Some _ | None -> None

  (* Each type unknown on a cycle of subtyping atoms, in order, sent to the
     representative of its component: a fixed member where there is one, else
     the earliest. This is cycle elimination (Fähndrich, Foster, Su and Aiken, PLDI 1998),
     the components by Kosaraju's algorithm ({!Reach.representatives}). *)
  let collapse (fixed : C.free) st =
    let edges =
      List.filter_map
        (function Sub_atom s -> edge s | _ -> None)
        (List.map (fun (_, e) -> e.atom) (Int_map.bindings st.atoms))
    in
    let ends pick = TyParamSet.of_list (List.map pick edges) in
    let vertices =
      TyParamSet.elements (TyParamSet.inter (ends fst) (ends snd))
    in
    let is_fixed a = TyParamSet.mem a fixed.free_tys in
    let order =
      List.filter is_fixed vertices
      @ List.filter (fun a -> not (is_fixed a)) vertices
    in
    let representative =
      Reach.representatives ~compare:TyParam.compare edges order
    in
    List.filter_map
      (fun a ->
        if is_fixed a then None
        else
          match representative a with
          | Some r when not (same_param a r) ->
              Some
                ( Ty_unknown a,
                  {
                    value = assign_ty a r;
                    dropped = Int_set.empty;
                    apart = true;
                    chains = false;
                  } )
          | Some _ | None -> None)
      vertices

  (* The grade hypotheses, in order. *)
  let grades st : R.reason N.hyps =
    Seq.fold_left
      (fun (grades : R.reason N.hyps) atom ->
        match atom with
        | Rho_atom o -> { grades with rho_hyps = o :: grades.rho_hyps }
        | Eps_atom o -> { grades with eps_hyps = o :: grades.eps_hyps }
        | Sub_atom _ | Eternal_atom _ | Disj_atom _ -> grades)
      N.no_hyps
      (Seq.map (fun (_, e) -> e.atom) (Int_map.to_rev_seq st.atoms))

  (* The test of [kind] at an unknown; for equating, the decision procedure
     of the hypotheses is shared by the unknowns tested. *)
  let test env kind st =
    let context = env.context in
    let entails make = lazy (make context (grades st)) in
    let eps = entails entails_eps and rho = entails entails_rho in
    fun u ->
      match (kind, u) with
      | Equate_eps, Eps_unknown k ->
          equate (eps_grade context k) (fun a b -> Lazy.force eps a b) st
      | Equate_rho, Rho_unknown k ->
          equate (rho_grade context k) (fun a b -> Lazy.force rho a b) st
      | Lower_eps, Eps_unknown k -> lower (eps_grade context k) st
      | Lower_rho, Rho_unknown k -> lower (rho_grade context k) st
      | Raise_eps, Eps_unknown k -> raise_to_cap (eps_grade context k) st
      | Raise_rho, Rho_unknown k -> raise_to_cap (rho_grade context k) st
      | Lower_ty, Ty_unknown a -> lower_ty a st
      | ( ( Equate_eps | Equate_rho | Lower_eps | Lower_rho | Raise_eps
          | Raise_rho | Collapse | Lower_ty ),
          _ ) ->
          None

  (* The tests of [kind] that are due taken again, in order, up to the first
     unknown where it succeeds, and that unknown with its step. *)
  let refresh env kind st =
    let test = lazy (test env kind st) in
    let rec go t =
      match
        (Unknown_set.min_elt_opt t.stale, Unknown_map.min_binding_opt t.passed)
      with
      | Some u, Some (v, _) when Unknown.compare u v > 0 -> t
      | Some u, (Some _ | None) -> (
          let stale = Unknown_set.remove u t.stale in
          match Lazy.force test u with
          | Some plan -> { passed = Unknown_map.add u plan t.passed; stale }
          | None -> go { t with stale })
      | None, (Some _ | None) -> t
    in
    let t = Kind_map.find kind st.tests in
    let t' = go t in
    ( (if t' == t then st else { st with tests = Kind_map.add kind t' st.tests }),
      Unknown_map.min_binding_opt t'.passed )

  (* The first kind of step, in order, that succeeds at some unknown, and the
     first such unknown. *)
  let rec next env st = function
    | [] -> (st, None)
    | Collapse :: kinds -> (
        let st =
          match st.cycle with
          | Some _ -> st
          | None -> { st with cycle = Some (collapse env.fixed st) }
        in
        match st.cycle with
        | Some ((u, plan) :: _) -> (st, Some (Collapse, u, plan))
        | Some [] | None -> next env st kinds)
    | kind :: kinds -> (
        match refresh env kind st with
        | st, Some (u, plan) -> (st, Some (kind, u, plan))
        | st, None -> next env st kinds)

  (* The unknowns of [ty] and [hyps] outside [fixed]. *)
  let unknowns (fixed : C.free) ty hyps =
    let free = C.union_free (C.free_vars_ty ty) (free_hyps hyps) in
    Unknown_set.of_list
      (List.map
         (fun a -> Ty_unknown a)
         (TyParamSet.elements (TyParamSet.diff free.free_tys fixed.free_tys))
      @ List.map
          (fun k -> Rho_unknown k)
          (Rho_set.elements (Rho_set.diff free.free_rhos fixed.free_rhos))
      @ List.map
          (fun k -> Eps_unknown k)
          (Eps_set.elements (Eps_set.diff free.free_eps fixed.free_eps)))

  (* The unknowns outside [fixed] tested by each kind of step. *)
  let tested candidates =
    Kind_map.of_list
      (List.filter_map
         (fun kind ->
           match kind with
           | Collapse -> None
           | Equate_eps | Equate_rho | Lower_eps | Lower_rho | Raise_eps
           | Raise_rho | Lower_ty ->
               Some (kind, Unknown_set.filter (tested_at kind) candidates))
         kinds)

  let initial env ty (hyps : hyps) =
    let atoms =
      List.map (fun o -> Rho_atom o) hyps.rho_hyps
      @ List.map (fun o -> Eps_atom o) hyps.eps_hyps
      @ List.map (fun s -> Sub_atom s) hyps.sub_vars
      @ List.map (fun e -> Eternal_atom e) hyps.eternal_hyps
      @ List.map (fun d -> Disj_atom d) hyps.disj_hyps
    in
    let empty =
      {
        ty;
        atoms = Int_map.empty;
        occurrences = Unknown_map.empty;
        reflexive = Int_set.empty;
        steps = [];
        tests =
          Kind_map.map
            (fun stale -> { passed = Unknown_map.empty; stale })
            env.tested;
        cycle = None;
      }
    in
    let insert (id, st) atom =
      ( id + 1,
        reindex env.context id (Some atom) ~before:Unknown_set.empty
          ~after:(atom_unknowns atom) st )
    in
    snd (List.fold_left insert (0, empty) atoms)

  (* The hypotheses, in order, the grade substitutions of the steps applied
     to their reasons. *)
  let hyps_of st : hyps =
    let reason =
      C.subst_reason { C.empty_subst with grade_subst = resolve st.steps }
    in
    Seq.fold_left
      (fun (hyps : hyps) atom ->
        match atom with
        | Rho_atom o ->
            {
              hyps with
              rho_hyps = { o with info = reason o.info } :: hyps.rho_hyps;
            }
        | Eps_atom o ->
            {
              hyps with
              eps_hyps = { o with info = reason o.info } :: hyps.eps_hyps;
            }
        | Sub_atom s ->
            {
              hyps with
              sub_vars = { s with info = reason s.info } :: hyps.sub_vars;
            }
        | Eternal_atom e ->
            {
              hyps with
              eternal_hyps =
                { e with eternal_reason = reason e.eternal_reason }
                :: hyps.eternal_hyps;
            }
        | Disj_atom d ->
            {
              hyps with
              disj_hyps =
                { d with disj_reason = reason d.disj_reason } :: hyps.disj_hyps;
            })
      {
        rho_hyps = [];
        eps_hyps = [];
        sub_vars = [];
        eternal_hyps = [];
        disj_hyps = [];
      }
      (Seq.map (fun (_, e) -> e.atom) (Int_map.to_rev_seq st.atoms))

  (* The elimination of unknowns, the lowering and raising steps by polarity
     in the manner of Pottier (Simplifying subtyping constraints, ICFP 1996)
     and of Trifonov and Smith (Subtyping constrained types, SAS 1996). The
     steps are tried at the unknowns of the initial state, which include those
     of every later state: a step replaces an unknown by a part of the
     hypotheses and drops hypotheses, and no step applies at an unknown that
     does not occur in them.

     The hypotheses are indexed by the unknowns occurring in them; a step
     substitutes into the atoms of its unknown alone, and into the reasons
     once, at the end. The outcome of each test is kept, and taken again, in
     order and up to the first success, at the unknowns of the atoms a step
     changes or drops and of its value. A test reads the atoms of its unknown
     and the type alone, but for equating, which reads the chains of atomic
     orderings too ({!GradeNormal.Make.SORT.decide_leq}), decisions being
     monotone in them. At an unknown [v], lowering turns [x ≾ v ≾ y] into
     [x ≾ y] or drops it, raising turns [x ≾ v ≾ U] into [x ≾ U], equating
     with [b] turns [x ≾ v] into [x ≾ b] and [v ≾ y] into [b ≾ y], and steps
     drop orderings: no step adds a chain but an equating one to a single
     atom [b] without [v ≾ b], or [b ≾ v], assumed. An equating test that
     failed thus fails after any other step, unless the atoms of its unknown
     changed. *)
  let eliminate context ~fixed ty hyps =
    let candidates = unknowns fixed ty hyps in
    let env = { context; fixed; candidates; tested = tested candidates } in
    let rec reduce fuel st =
      if fuel = 0 then st
      else
        match next env st kinds with
        | st, Some (kind, u, plan) ->
            reduce (fuel - 1) (take env kind u plan st)
        | st, None -> st
    in
    let st = reduce (Unknown_set.cardinal candidates) (initial env ty hyps) in
    (st.ty, hyps_of st)

  (* ------------------------------------------------------------------ *)
  (* Reports and schemes                                                 *)
  (* ------------------------------------------------------------------ *)

  let report context ~fixed ty hyps obligations =
    let fixed =
      List.fold_left
        (fun fixed d -> C.union_free fixed (R.free_vars_deferred d))
        fixed obligations
    in
    let ty, hyps = eliminate context ~fixed ty (simplify context hyps) in
    {
      ty = canon_ty context ty;
      hyps = trim context (canon_hyps context hyps);
      obligations = List.map (canon_deferred context) obligations;
    }

  let scheme ~(fixed : C.free) (report : t) =
    let qualifier =
      C.conj
        (R.hyps_to_constraint report.hyps)
        (C.conj_all (List.map R.deferred_to_constraint report.obligations))
    in
    let free =
      C.union_free (C.free_vars_ty report.ty) (C.free_vars qualifier)
    in
    {
      C.ty_params =
        TyParamSet.elements (TyParamSet.diff free.free_tys fixed.free_tys);
      rho_params =
        Rho_set.elements (Rho_set.diff free.free_rhos fixed.free_rhos);
      eps_params = Eps_set.elements (Eps_set.diff free.free_eps fixed.free_eps);
      qualifier;
      ty = report.ty;
    }
end
