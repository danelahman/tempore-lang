(* Closing a rigid scope: localisation, the split of its atoms, and the retry
   of deferred conditions. *)

module Make (C : Constraint.S) = struct
  module X = C.X
  module R = Residual.Make (C)
  module N = GradeNormal.Make (X)
  module E = Entail.Make (X)
  module V = Values.Make (X)
  module Rho_set = X.Rho_var.Set
  module Eps_set = X.Eps_var.Set

  type residual = R.t

  type scope = {
    rigid : X.Eps_var.t;
    outer_rhos : Rho_set.t;
    outer_eps : Eps_set.t;
  }

  type blocking =
    | Blocking_rho of R.rho_ordering
    | Blocking_eps of R.eps_ordering
    | Blocking_deferred of R.deferred

  type stuck = { stuck_origin : Reason.rigid_origin; blocking : blocking }
  type error = Refused of R.failure | Stuck of stuck

  (* ------------------------------------------------------------------ *)
  (* Unknowns and their occurrences                                      *)
  (* ------------------------------------------------------------------ *)

  (* A grade unknown of either sort. *)
  type unknown = Rho_unknown of X.Rho_var.t | Eps_unknown of X.Eps_var.t

  let in_rho u rho =
    match u with
    | Rho_unknown k -> X.Rho.mem_rho_var k rho
    | Eps_unknown k -> X.Rho.mem_eps_var k rho

  let in_eps u eps =
    match u with Rho_unknown _ -> false | Eps_unknown k -> X.Eps.mem_var k eps

  let in_ty u ty =
    Language.Ast.fold_ty
      ~on_param:(fun _ found -> found)
      ~on_rho:(fun rho found -> found || in_rho u rho)
      ~on_eps:(fun eps found -> found || in_eps u eps)
      ty false

  let is_rigid scope k = X.Eps_var.equal k scope.rigid

  let is_local scope = function
    | Rho_unknown k -> not (Rho_set.mem k scope.outer_rhos)
    | Eps_unknown k -> not (Eps_set.mem k scope.outer_eps || is_rigid scope k)

  (* Whether an expression mentions only unknowns outer to the scope and
     rigids of [rigids]. *)
  let outer_rho scope ~rigids rho =
    Rho_set.subset (X.Rho.free_rho_vars rho) scope.outer_rhos
    && Eps_set.for_all
         (fun k -> Eps_set.mem k scope.outer_eps || Eps_set.mem k rigids)
         (X.Rho.free_eps_vars rho)

  let outer_eps scope ~rigids eps =
    Eps_set.for_all
      (fun k -> Eps_set.mem k scope.outer_eps || Eps_set.mem k rigids)
      (X.Eps.free_vars eps)

  (* Whether [u] occurs in no type of [r]. *)
  let clean u (r : residual) =
    not
      (List.exists (fun (e : R.eternal) -> in_ty u e.eternal_ty) r.eternals
      || List.exists (fun (s : R.sub) -> in_ty u s.lhs || in_ty u s.rhs) r.subs
      || List.exists
           (fun (d : R.disjunction) -> in_ty u d.disj_ty)
           r.disjunctions)

  (* Whether [u] occurs in no disjunction's grade of [r]. *)
  let disj_free u (r : residual) =
    not
      (List.exists
         (fun (d : R.disjunction) -> in_rho u d.disj_grade)
         r.disjunctions)

  (* The sides of the deferred conditions: the greater ones, which a lowering
     must leave, or the smaller ones, which a raising must leave. *)
  type side = Greater | Smaller

  let on_side side u (d : R.deferred) =
    let pick (o : _ GradeNormal.ordering) =
      match side with Greater -> o.rhs | Smaller -> o.lhs
    in
    List.exists (fun o -> in_rho u (pick o)) d.rho_conditions
    || List.exists (fun o -> in_eps u (pick o)) d.eps_conditions

  (* Whether a value for [u] keeps every deferred condition: [u] is on no side
     the value moves. *)
  let still side u (r : residual) =
    not (List.exists (on_side side u) r.deferred)

  (* ------------------------------------------------------------------ *)
  (* The value of one unknown                                            *)
  (* ------------------------------------------------------------------ *)

  (* The orderings a value settles: those with the unknown on their greater
     side, for a lowering; none otherwise. *)
  type drops = Drop_greater | Keep_all

  let first rules = List.find_map (fun rule -> rule ()) rules

  (* Whether [u] occurs on a left side, in a disjunction's grade or in a
     deferred condition. *)
  let occurs_below u (r : residual) =
    List.exists (fun (o : R.eps_ordering) -> in_eps u o.lhs) r.eps_orderings
    || List.exists (fun (o : R.rho_ordering) -> in_rho u o.lhs) r.rho_orderings
    || (not (disj_free u r))
    || List.exists (on_side Greater u) r.deferred
    || List.exists (on_side Smaller u) r.deferred

  (* Whether [u] occurs on a right side or a greater side of a deferred
     condition. *)
  let occurs_above u (r : residual) =
    List.exists (fun (o : R.eps_ordering) -> in_eps u o.rhs) r.eps_orderings
    || List.exists (fun (o : R.rho_ordering) -> in_rho u o.rhs) r.rho_orderings
    || List.exists (on_side Greater u) r.deferred

  (* The occurrence oracle of [u], [image] reading the resource orderings for
     an effect unknown: [u] may decrease where it is on no right side of a
     resource ordering not valid and no greater side of a deferred condition,
     and increase where it is on no left side of a resource ordering not
     valid, in no disjunction's grade and on no smaller side of a deferred
     condition. *)
  let oracle u ?image (r : residual) : _ Values.oracle =
    let resource free =
      Option.fold ~none:true
        ~some:(fun image -> free image r.rho_orderings)
        image
    in
    {
      may_lower = (fun _ -> resource Values.free_right && still Greater u r);
      may_raise =
        (fun _ ->
          resource Values.free_left && disj_free u r && still Smaller u r);
    }

  (* The value of [u] occurring in no type by the first rule of {!Values}
     that applies, in the order lowering, raising, least and top, the least
     only where [occurs_below] holds and the top only where [occurs_above]
     does; a lowering and the least drop the orderings with [u] on the greater
     side. *)
  let value sort oracle u (r : residual) orderings =
    let rule apply drops () =
      Option.map
        (fun (v : _ Values.value) -> (v.value, drops))
        (apply sort oracle orderings)
    and where occurs rule () = if occurs u r then rule () else None in
    if clean u r then
      first
        [
          rule Values.lower Drop_greater;
          rule Values.raise Keep_all;
          where occurs_below (rule Values.least Drop_greater);
          where occurs_above (rule Values.top Keep_all);
        ]
    else None

  let eps_value context k (r : residual) =
    let u = Eps_unknown k and bounds = context.Residual.bounds in
    value (V.eps bounds k)
      (oracle u ~image:(V.image bounds k) r)
      u r r.eps_orderings

  let rho_value context k (r : residual) =
    let u = Rho_unknown k in
    value (V.rho context.Residual.bounds k) (oracle u r) u r r.rho_orderings

  (* ------------------------------------------------------------------ *)
  (* Assignments                                                         *)
  (* ------------------------------------------------------------------ *)

  let empty_grade_subst = X.empty_subst

  let apply (sigma : X.subst) r =
    R.subst { C.empty_subst with grade_subst = sigma } r

  let assign_eps k eps : X.subst =
    { empty_grade_subst with eps_subst = X.Eps_var.Map.singleton k eps }

  let assign_rho k rho : X.subst =
    { empty_grade_subst with rho_subst = X.Rho_var.Map.singleton k rho }

  (* The residual less the orderings of the unknown's sort with it on the
     greater side, and those orderings. *)
  let drop_greater u (r : residual) =
    match u with
    | Eps_unknown _ ->
        let dropped, eps_orderings =
          List.partition
            (fun (o : R.eps_ordering) -> in_eps u o.rhs)
            r.eps_orderings
        in
        ({ r with eps_orderings }, { R.empty with eps_orderings = dropped })
    | Rho_unknown _ ->
        let dropped, rho_orderings =
          List.partition
            (fun (o : R.rho_ordering) -> in_rho u o.rhs)
            r.rho_orderings
        in
        ({ r with rho_orderings }, { R.empty with rho_orderings = dropped })

  (* ------------------------------------------------------------------ *)
  (* The local unknowns                                                  *)
  (* ------------------------------------------------------------------ *)

  (* Sets of grade unknowns of the two sorts. *)
  let no_grades = (Rho_set.empty, Eps_set.empty)

  let union_grades (rhos, eps) (rhos', eps') =
    (Rho_set.union rhos rhos', Eps_set.union eps eps')

  let grades_of_rho rho =
    union_grades (X.Rho.free_rho_vars rho, X.Rho.free_eps_vars rho)

  let grades_of_eps eps = union_grades (Rho_set.empty, X.Eps.free_vars eps)

  let grades_of_free (free : C.free) =
    union_grades (free.free_rhos, free.free_eps)

  (* The grade unknowns of an atom, the rigids of a condition excepted. *)
  let sides on_exp (o : _ GradeNormal.ordering) acc =
    on_exp o.rhs (on_exp o.lhs acc)

  let disjunction_grades (d : R.disjunction) = grades_of_rho d.disj_grade
  let deferred_grades d = grades_of_free (R.free_vars_deferred d)

  (* The grade unknowns of the orderings, disjunction grades and deferred
     conditions of [r]. *)
  let grade_unknowns (r : residual) =
    let over on_item items acc =
      List.fold_left (fun acc item -> on_item item acc) acc items
    in
    no_grades
    |> over (sides grades_of_rho) r.rho_orderings
    |> over (sides grades_of_eps) r.eps_orderings
    |> over disjunction_grades r.disjunctions
    |> over deferred_grades r.deferred

  let local_unknowns scope r =
    let rhos, eps = grade_unknowns r in
    ( List.filter
        (fun k -> is_local scope (Rho_unknown k))
        (Rho_set.elements rhos),
      List.filter
        (fun k -> is_local scope (Eps_unknown k))
        (Eps_set.elements eps) )

  (* ------------------------------------------------------------------ *)
  (* Canonical and settled atoms                                         *)
  (* ------------------------------------------------------------------ *)

  (* The canonical forms of atoms: an ordering with the sides marked
     [~lhs] and [~rhs] written canonically, the others being so already,
     split into one ordering per alternative of its left side, less those
     decided at no hypotheses; a disjunction's grade canonical. *)
  type canon = {
    rho_ordering :
      lhs:bool -> rhs:bool -> R.rho_ordering -> R.rho_ordering list;
    eps_ordering :
      lhs:bool -> rhs:bool -> R.eps_ordering -> R.eps_ordering list;
    grade : X.rho -> X.rho;
  }

  let canon_ordering ~alternatives ~canon ~decided ~lhs ~rhs
      (o : _ GradeNormal.ordering) =
    let rhs = if rhs then canon o.rhs else o.rhs in
    List.filter_map
      (fun lhs ->
        if decided lhs rhs then None else Some { o with GradeNormal.lhs; rhs })
      (if lhs then alternatives o.lhs else [ o.lhs ])

  let canon context =
    let bounds = context.Residual.bounds in
    {
      rho_ordering =
        canon_ordering
          ~alternatives:(fun e ->
            List.map N.Rho.read_back_product
              (N.Rho.canon_sum bounds (N.Rho.normal bounds e)))
          ~canon:(N.Rho.canon bounds) ~decided:(E.Rho.decided bounds);
      eps_ordering =
        canon_ordering
          ~alternatives:(fun e ->
            List.map N.Eps.read_back_product
              (N.Eps.canon_sum bounds (N.Eps.normal bounds e)))
          ~canon:(N.Eps.canon bounds) ~decided:(E.Eps.decided bounds);
      grade = N.Rho.canon bounds;
    }

  let normal canon (r : residual) =
    {
      r with
      rho_orderings =
        List.concat_map (canon.rho_ordering ~lhs:true ~rhs:true) r.rho_orderings;
      eps_orderings =
        List.concat_map (canon.eps_ordering ~lhs:true ~rhs:true) r.eps_orderings;
      disjunctions =
        List.map
          (fun (d : R.disjunction) ->
            { d with disj_grade = canon.grade d.disj_grade })
          r.disjunctions;
    }

  (* The disjunctions settled against the orderings ({!Residual.Make.settle})
     until none is: one whose grade follows below the unit from the orderings
     is dropped, and one whose type is never eternal becomes its grade below
     the unit, in canonical form. With the disjunctions removed. *)
  let rec settle context canon (r : residual) =
    match r.disjunctions with
    | [] -> (r, [])
    | disjunctions -> (
        let entail =
          lazy
            (E.make context.Residual.bounds
               { rho_hyps = r.rho_orderings; eps_hyps = r.eps_orderings })
        in
        let settling =
          R.by_grade (fun rho ->
              E.Rho.follows (Lazy.force entail) rho X.Rho.unit)
        in
        let kept, grades, removed =
          List.fold_right
            (fun (d : R.disjunction) (kept, grades, removed) ->
              match R.settle context settling d with
              | Drop -> (kept, grades, d :: removed)
              | Below_unit o -> (kept, o :: grades, d :: removed)
              | Keep | Eternal _ -> (d :: kept, grades, removed))
            disjunctions ([], [], [])
        in
        let r =
          {
            r with
            rho_orderings =
              r.rho_orderings
              @ List.concat_map (canon.rho_ordering ~lhs:true ~rhs:true) grades;
            disjunctions = kept;
          }
        in
        match grades with
        | [] -> (r, removed)
        | _ :: _ ->
            let r, removed' = settle context canon r in
            (r, removed @ removed'))

  (* ------------------------------------------------------------------ *)
  (* Cycles of whole unknowns                                            *)
  (* ------------------------------------------------------------------ *)

  (* The orderings between whole unknowns, as edges. *)
  let eps_edges (r : residual) =
    List.filter_map
      (fun (o : R.eps_ordering) ->
        match (o.lhs, o.rhs) with
        | X.Eps_var a, X.Eps_var b -> Some (a, b)
        | _, _ -> None)
      r.eps_orderings

  let rho_edges (r : residual) =
    List.filter_map
      (fun (o : R.rho_ordering) ->
        match (o.lhs, o.rhs) with
        | X.Rho_var a, X.Rho_var b -> Some (a, b)
        | _, _ -> None)
      r.rho_orderings

  (* Whether an ordering between whole unknowns of [fresh], among those of
     [r], lies on a cycle of them. *)
  let cyclic (r : residual) fresh =
    let closes compare edges fresh =
      fresh <> [] && Reach.closes_cycle ~compare (edges r) fresh
    in
    closes X.Eps_var.compare eps_edges (eps_edges fresh)
    || closes X.Rho_var.compare rho_edges (rho_edges fresh)

  (* Cycle elimination (Fähndrich, Foster, Su and Aiken, PLDI 1998;
     {!Reach.collapse}): the local members occurring in no
     type of each strongly connected component of the orderings between whole
     unknowns sent to its representative, the first member in the order outer,
     then fixed, then movable, each by creation. *)
  let collapse scope (r : residual) =
    let movable u = is_local scope u && clean u r in
    let eps_moves =
      Reach.collapse ~compare:X.Eps_var.compare
        ~preferred:(fun k -> not (is_local scope (Eps_unknown k)))
        ~movable:(fun k -> movable (Eps_unknown k))
        (eps_edges r)
    and rho_moves =
      Reach.collapse ~compare:X.Rho_var.compare
        ~preferred:(fun k -> not (is_local scope (Rho_unknown k)))
        ~movable:(fun k -> movable (Rho_unknown k))
        (rho_edges r)
    in
    match (eps_moves, rho_moves) with
    | [], [] -> None
    | _, _ ->
        Some
          {
            X.rho_subst =
              X.Rho_var.Map.of_seq
                (List.to_seq
                   (List.map (fun (v, rep) -> (v, X.Rho.var rep)) rho_moves));
            eps_subst =
              X.Eps_var.Map.of_seq
                (List.to_seq
                   (List.map (fun (v, rep) -> (v, X.Eps.var rep)) eps_moves));
          }

  (* ------------------------------------------------------------------ *)
  (* A set of unknowns raised to the top at once                         *)
  (* ------------------------------------------------------------------ *)

  let is_member members u =
    List.exists
      (fun m ->
        match (m, u) with
        | Rho_unknown k, Rho_unknown k' -> X.Rho_var.equal k k'
        | Eps_unknown k, Eps_unknown k' -> X.Eps_var.equal k k'
        | (Rho_unknown _ | Eps_unknown _), _ -> false)
      members

  let hit_rho members rho = List.exists (fun u -> in_rho u rho) members
  let hit_eps members eps = List.exists (fun u -> in_eps u eps) members

  let tops members =
    List.fold_left
      (fun sigma -> function
        | Rho_unknown k -> X.compose_subst sigma (assign_rho k X.Rho.top)
        | Eps_unknown k -> X.compose_subst sigma (assign_eps k X.Eps.top))
      empty_grade_subst members

  (* The first unknown [k] allowed by [ok], not a member, with an ordering
     [x ≾ k] whose [x] is decided the top once the rigid and the members
     are. *)
  let find context scope ~ok members (r : residual) =
    let decided_rho = E.Rho.decided context.Residual.bounds
    and decided_eps = E.Eps.decided context.Residual.bounds in
    let reached = Eps_unknown scope.rigid :: members in
    let sigma = tops reached in
    let from_eps (o : R.eps_ordering) =
      match o.rhs with
      | X.Eps_var k
        when ok (Eps_unknown k)
             && (not (is_member members (Eps_unknown k)))
             && hit_eps reached o.lhs
             && decided_eps X.Eps.top (X.Eps.subst sigma o.lhs) ->
          Some (Eps_unknown k)
      | _ -> None
    and from_rho (o : R.rho_ordering) =
      match o.rhs with
      | X.Rho_var k
        when ok (Rho_unknown k)
             && (not (is_member members (Rho_unknown k)))
             && hit_rho reached o.lhs
             && decided_rho X.Rho.top (X.Rho.subst sigma o.lhs) ->
          Some (Rho_unknown k)
      | _ -> None
    in
    match List.find_map from_eps r.eps_orderings with
    | Some u -> Some u
    | None -> List.find_map from_rho r.rho_orderings

  let rec grow context scope ~ok fuel members r =
    if fuel <= 0 then members
    else
      match find context scope ~ok members r with
      | Some u -> grow context scope ~ok (fuel - 1) (u :: members) r
      | None -> members

  (* An ordering with a member on its left has on its right an expression
     decided the top once the members are, or one of outer unknowns other
     than the rigid and no member. *)
  let up_rho context scope members sigma (o : R.rho_ordering) =
    (not (hit_rho members o.lhs))
    || E.Rho.decided context.Residual.bounds X.Rho.top (X.Rho.subst sigma o.rhs)
    || outer_rho scope ~rigids:Eps_set.empty o.rhs
       && not (hit_rho members o.rhs)

  let up_eps context scope members sigma (o : R.eps_ordering) =
    (not (hit_eps members o.lhs))
    || E.Eps.decided context.Residual.bounds X.Eps.top (X.Eps.subst sigma o.rhs)
    || outer_eps scope ~rigids:Eps_set.empty o.rhs
       && not (hit_eps members o.rhs)

  (* Whether a member occurs where no raise may reach it: in a type, a
     disjunction's grade or on a smaller side of a deferred condition. *)
  let fixed u (r : residual) =
    (not (clean u r)) || (not (disj_free u r)) || not (still Smaller u r)

  let usable context scope members (r : residual) =
    let sigma = tops members in
    members <> []
    && List.for_all (up_eps context scope members sigma) r.eps_orderings
    && List.for_all (up_rho context scope members sigma) r.rho_orderings
    && List.for_all (fun u -> not (fixed u r)) members

  (* The members that break a condition of {!usable}. *)
  let bad context scope members (r : residual) =
    let sigma = tops members in
    let failing_eps =
      List.filter
        (fun o -> not (up_eps context scope members sigma o))
        r.eps_orderings
    and failing_rho =
      List.filter
        (fun o -> not (up_rho context scope members sigma o))
        r.rho_orderings
    in
    List.filter
      (fun u ->
        List.exists (fun (o : R.eps_ordering) -> in_eps u o.lhs) failing_eps
        || List.exists (fun (o : R.rho_ordering) -> in_rho u o.lhs) failing_rho
        || fixed u r)
      members

  let raise_set context scope r =
    let rhos, eps = local_unknowns scope r in
    let fuel = List.length rhos + List.length eps in
    let rec select attempts disabled =
      if attempts <= 0 then None
      else
        let ok u = is_local scope u && not (is_member disabled u) in
        let members = grow context scope ~ok fuel [] r in
        if usable context scope members r then Some (tops members)
        else
          match bad context scope members r with
          | [] -> None
          | bad -> select (attempts - 1) (bad @ disabled)
    in
    select (fuel + 1) []

  (* ------------------------------------------------------------------ *)
  (* Rewriting the atoms an assignment changes                           *)
  (* ------------------------------------------------------------------ *)

  let mentions_rho moved (o : R.rho_ordering) =
    hit_rho moved o.lhs || hit_rho moved o.rhs

  let mentions_eps moved (o : R.eps_ordering) =
    hit_eps moved o.lhs || hit_eps moved o.rhs

  let mentions_grade moved (d : R.disjunction) = hit_rho moved d.disj_grade

  let mentions_deferred moved (d : R.deferred) =
    List.exists (mentions_rho moved) d.rho_conditions
    || List.exists (mentions_eps moved) d.eps_conditions

  (* The substitution [sigma] on the grades and reasons of an atom whose type,
     if any, it leaves as it is. *)
  let on_reason sigma =
    C.subst_reason { C.empty_subst with grade_subst = sigma }

  let on_ordering on_exp sigma (o : _ GradeNormal.ordering) :
      _ GradeNormal.ordering =
    {
      lhs = on_exp sigma o.lhs;
      rhs = on_exp sigma o.rhs;
      info = on_reason sigma o.info;
    }

  let on_disjunction sigma (d : R.disjunction) =
    {
      d with
      disj_grade = X.Rho.subst sigma d.disj_grade;
      disj_reason = on_reason sigma d.disj_reason;
    }

  let on_deferred sigma (d : R.deferred) =
    {
      d with
      rho_conditions = List.map (on_ordering X.Rho.subst sigma) d.rho_conditions;
      eps_conditions = List.map (on_ordering X.Eps.subst sigma) d.eps_conditions;
    }

  (* The items of [items], each satisfying [mentions] replaced by [rewrite]
     of it, in order; with the grade unknowns, by [grades], of the items
     replaced and of their replacements, and the replacements. *)
  let rewritten mentions grades rewrite items =
    List.fold_right
      (fun item (items, changed, fresh) ->
        if mentions item then
          let items' = rewrite item in
          ( items' @ items,
            List.fold_right grades (item :: items') changed,
            items' @ fresh )
        else (item :: items, changed, fresh))
      items ([], no_grades, [])

  (* [r] with the atoms mentioning one of [moved], the domain of [sigma],
     under [sigma] and in canonical form, and the others as they are; with
     the grade unknowns of those atoms, before and after, and the orderings
     rewritten. No type mentions one of [moved]. *)
  let rewrite canon moved sigma (r : residual) =
    let rho_orderings, rho_changed, fresh_rho =
      rewritten (mentions_rho moved) (sides grades_of_rho)
        (fun (o : R.rho_ordering) ->
          canon.rho_ordering ~lhs:(hit_rho moved o.lhs)
            ~rhs:(hit_rho moved o.rhs)
            (on_ordering X.Rho.subst sigma o))
        r.rho_orderings
    and eps_orderings, eps_changed, fresh_eps =
      rewritten (mentions_eps moved) (sides grades_of_eps)
        (fun (o : R.eps_ordering) ->
          canon.eps_ordering ~lhs:(hit_eps moved o.lhs)
            ~rhs:(hit_eps moved o.rhs)
            (on_ordering X.Eps.subst sigma o))
        r.eps_orderings
    and disjunctions, disjunctions_changed, _ =
      rewritten (mentions_grade moved) disjunction_grades
        (fun d ->
          let d = on_disjunction sigma d in
          [ { d with disj_grade = canon.grade d.disj_grade } ])
        r.disjunctions
    and deferred, deferred_changed, _ =
      rewritten (mentions_deferred moved) deferred_grades
        (fun d -> [ on_deferred sigma d ])
        r.deferred
    in
    ( { r with rho_orderings; eps_orderings; disjunctions; deferred },
      List.fold_left union_grades rho_changed
        [ eps_changed; disjunctions_changed; deferred_changed ],
      { R.empty with rho_orderings = fresh_rho; eps_orderings = fresh_eps } )

  (* ------------------------------------------------------------------ *)
  (* The worklist                                                        *)
  (* ------------------------------------------------------------------ *)

  (* The local unknowns of [(rhos, eps)], other than [moved] and those of
     [worklist], added to the end of [worklist], a queue without repetition:
     the effect unknowns first, each sort in decreasing order of creation. The
     unknowns of a term are created before those of its subterms, mostly its
     lower bounds, which thus receive their values first. *)
  let push scope ?(moved = []) (rhos, eps) worklist =
    let latest_first elements set wrap = List.rev_map wrap (elements set) in
    worklist
    @ List.filter
        (fun u ->
          is_local scope u
          && (not (is_member moved u))
          && not (is_member worklist u))
        (latest_first Eps_set.elements eps (fun k -> Eps_unknown k)
        @ latest_first Rho_set.elements rhos (fun k -> Rho_unknown k))

  (* ------------------------------------------------------------------ *)
  (* Localisation                                                        *)
  (* ------------------------------------------------------------------ *)

  (* The values given, the residual and the local unknowns whose atoms
     changed since a rule was last tried on them. Invariant: every atom of the
     residual is canonical ({!canon}); an atom is rewritten exactly when a
     value changes it. *)
  type state = {
    values : X.subst;
    residual : residual;
    worklist : unknown list;
  }

  (* The unknowns [sigma] gives values. *)
  let domain (sigma : X.subst) =
    X.Rho_var.Map.fold
      (fun k _ us -> Rho_unknown k :: us)
      sigma.rho_subst
      (X.Eps_var.Map.fold
         (fun k _ us -> Eps_unknown k :: us)
         sigma.eps_subst [])

  (* The values [sigma] given, [dropped] being the orderings they settle:
     the atoms mentioning an unknown moved are rewritten canonically, and the
     local unknowns of the atoms changed or dropped, before and after, are
     added to the worklist. Where an ordering between whole unknowns results
     on a cycle, the cycles are collapsed. *)
  let rec step canon scope sigma ?(dropped = R.empty) st =
    let moved = domain sigma in
    let r, changed, fresh = rewrite canon moved sigma st.residual in
    let st =
      {
        values = X.compose_subst st.values sigma;
        residual = r;
        worklist =
          push scope ~moved
            (union_grades (grade_unknowns dropped) changed)
            st.worklist;
      }
    in
    if cyclic r fresh then
      match collapse scope r with
      | Some sigma -> step canon scope sigma st
      | None -> st
    else st

  (* The disjunctions settled ({!settle}), the unknowns of those removed
     added to the worklist; [None] where none is. *)
  let settled context canon scope st =
    match settle context canon st.residual with
    | _, [] -> None
    | residual, removed ->
        let grades = List.fold_right disjunction_grades removed no_grades in
        Some { st with residual; worklist = push scope grades st.worklist }

  let value_of context u r =
    match u with
    | Eps_unknown k ->
        Option.map
          (fun (b, drops) -> (assign_eps k b, drops))
          (eps_value context k r)
    | Rho_unknown k ->
        Option.map
          (fun (b, drops) -> (assign_rho k b, drops))
          (rho_value context k r)

  (* Chaotic iteration with a worklist (Cousot and Cousot, POPL 1977): an
     unknown taken from the worklist is given the value of the first rule of
     {!value} that applies to it, which reads only the atoms mentioning it.
     Where the worklist is empty, the disjunctions, which depend on every
     ordering, are settled; where none is, a set of unknowns is raised to the
     top at once. Each value is a least or a greatest solution for its
     unknown, chosen by the sides it occurs on, as the elimination of
     {!Report} chooses by polarity. Each step sends at least one local
     unknown of the residual to an expression free of it and brings in none,
     a settling removes at least one disjunction, and an unknown given no
     value leaves the worklist: the number of local unknowns of the residual,
     then the number of disjunctions, then the length of the worklist,
     decreases. *)
  let rec fixpoint context canon scope st =
    match st.worklist with
    | u :: worklist -> (
        let st = { st with worklist } in
        match value_of context u st.residual with
        | Some (sigma, Drop_greater) ->
            let residual, dropped = drop_greater u st.residual in
            fixpoint context canon scope
              (step canon scope sigma ~dropped { st with residual })
        | Some (sigma, Keep_all) ->
            fixpoint context canon scope (step canon scope sigma st)
        | None -> fixpoint context canon scope st)
    | [] -> (
        match settled context canon scope st with
        | Some st -> fixpoint context canon scope st
        | None -> (
            match raise_set context scope st.residual with
            | Some sigma ->
                fixpoint context canon scope (step canon scope sigma st)
            | None -> (st.values, st.residual)))

  (* The atoms written canonically and the disjunctions settled, the cycles
     collapsed, then {!fixpoint} from every local unknown; the reasons of the
     atoms no value changed receive the values at the end. *)
  let localise context scope r =
    let canon = canon context in
    let r, _ = settle context canon (normal canon r) in
    let st =
      {
        values = empty_grade_subst;
        residual = r;
        worklist = push scope (grade_unknowns r) [];
      }
    in
    let st =
      match collapse scope r with
      | Some sigma -> step canon scope sigma st
      | None -> st
    in
    let values, r = fixpoint context canon scope st in
    (values, apply values r)

  (* Every unknown local, the rigid a fresh variable occurring nowhere. *)
  let localise_all context r =
    localise context
      {
        rigid = X.Eps_var.fresh_indexed ();
        outer_rhos = Rho_set.empty;
        outer_eps = Eps_set.empty;
      }
      r

  (* ------------------------------------------------------------------ *)
  (* Split                                                               *)
  (* ------------------------------------------------------------------ *)

  (* The fate of an ordering of the scope. *)
  type 'o fate = Keep of 'o | Discharge | Defer of 'o | Block of 'o

  let at_rigid scope value : X.subst = assign_eps scope.rigid value

  (* How the orderings of one sort are split. *)
  type 'e splitting = {
    mentions : 'e -> bool;  (** whether the rigid occurs *)
    follows : 'e -> 'e -> bool;
        (** following from the orderings free of the rigid *)
    at_unit : 'e -> 'e;  (** the rigid sent to the unit *)
    at_top : 'e -> 'e;  (** the rigid sent to the top *)
    outer_with_rigid : 'e -> bool;
    outer_without_rigid : 'e -> bool;
    stated : 'e -> 'e -> (C.rho, C.eps) Reason.stated;
  }

  let rho_splitting scope entail =
    let rigid = Eps_set.singleton scope.rigid in
    {
      mentions = in_rho (Eps_unknown scope.rigid);
      follows = E.Rho.follows entail;
      at_unit = X.Rho.subst (at_rigid scope X.Eps.unit);
      at_top = X.Rho.subst (at_rigid scope X.Eps.top);
      outer_with_rigid = outer_rho scope ~rigids:rigid;
      outer_without_rigid = outer_rho scope ~rigids:Eps_set.empty;
      stated = (fun lhs rhs -> Reason.Stated_rho (lhs, rhs));
    }

  let eps_splitting scope entail =
    let rigid = Eps_set.singleton scope.rigid in
    {
      mentions = in_eps (Eps_unknown scope.rigid);
      follows = E.Eps.follows entail;
      at_unit = X.Eps.subst (at_rigid scope X.Eps.unit);
      at_top = X.Eps.subst (at_rigid scope X.Eps.top);
      outer_with_rigid = outer_eps scope ~rigids:rigid;
      outer_without_rigid = outer_eps scope ~rigids:Eps_set.empty;
      stated = (fun lhs rhs -> Reason.Stated_eps (lhs, rhs));
    }

  (* The fate of an ordering: kept free of the rigid, with the rigid at the
     unit on a right side or at the top on a left side; discharged; deferred;
     or blocking. *)
  let fate sp (o : (_, C.reason) GradeNormal.ordering) =
    let defer () =
      if sp.outer_with_rigid o.lhs && sp.outer_with_rigid o.rhs then Defer o
      else Block o
    in
    let restated lhs rhs : _ GradeNormal.ordering =
      { lhs; rhs; info = Reason.with_stated (sp.stated o.lhs o.rhs) o.info }
    in
    match (sp.mentions o.lhs, sp.mentions o.rhs) with
    | false, false -> Keep o
    | _, _ when sp.follows o.lhs o.rhs -> Discharge
    | false, true ->
        if X.GS.E.unit_least then Keep (restated o.lhs (sp.at_unit o.rhs))
        else defer ()
    | true, false ->
        if sp.outer_without_rigid o.rhs then
          Keep (restated (sp.at_top o.lhs) o.rhs)
        else defer ()
    | true, true -> defer ()

  (* The kept and deferred orderings, in order, or the first that blocks. *)
  let split_orderings sp orderings =
    List.fold_right
      (fun o acc ->
        Result.bind acc (fun (kept, deferred) ->
            match fate sp o with
            | Keep o -> Ok (o :: kept, deferred)
            | Discharge -> Ok (kept, deferred)
            | Defer o -> Ok (kept, o :: deferred)
            | Block o -> Error o))
      orderings
      (Ok ([], []))

  (* The condition closed over the rigid where it mentions it. *)
  let close_over scope origin (d : R.deferred) =
    let rigid = Eps_unknown scope.rigid in
    if
      List.exists
        (fun (o : R.rho_ordering) -> in_rho rigid o.lhs || in_rho rigid o.rhs)
        d.rho_conditions
      || List.exists
           (fun (o : R.eps_ordering) ->
             in_eps rigid o.lhs || in_eps rigid o.rhs)
           d.eps_conditions
    then { d with rigids = (scope.rigid, origin) :: d.rigids }
    else d

  (* An inner condition carried outward: its unknowns outer, besides the
     rigids. *)
  let carried scope (d : R.deferred) =
    let rigids =
      Eps_set.add scope.rigid (Eps_set.of_list (List.map fst d.rigids))
    in
    List.for_all
      (fun (o : R.rho_ordering) ->
        outer_rho scope ~rigids o.lhs && outer_rho scope ~rigids o.rhs)
      d.rho_conditions
    && List.for_all
         (fun (o : R.eps_ordering) ->
           outer_eps scope ~rigids o.lhs && outer_eps scope ~rigids o.rhs)
         d.eps_conditions

  let split context scope origin (r : residual) =
    let open Result.Syntax in
    let rigid = Eps_unknown scope.rigid in
    let stuck blocking = Stuck { stuck_origin = origin; blocking } in
    let* () =
      if
        List.exists (fun (e : R.eternal) -> in_ty rigid e.eternal_ty) r.eternals
        || List.exists
             (fun (s : R.sub) -> in_ty rigid s.lhs || in_ty rigid s.rhs)
             r.subs
        || List.exists
             (fun (d : R.disjunction) -> in_ty rigid d.disj_ty)
             r.disjunctions
      then Error (Refused (R.Rigid_escape origin))
      else Ok ()
    in
    let entail =
      E.make context.Residual.bounds
        {
          rho_hyps =
            List.filter
              (fun (o : R.rho_ordering) ->
                not (in_rho rigid o.lhs || in_rho rigid o.rhs))
              r.rho_orderings;
          eps_hyps =
            List.filter
              (fun (o : R.eps_ordering) ->
                not (in_eps rigid o.lhs || in_eps rigid o.rhs))
              r.eps_orderings;
        }
    in
    let* rho_kept, rho_deferred =
      Result.map_error
        (fun o -> stuck (Blocking_rho o))
        (split_orderings (rho_splitting scope entail) r.rho_orderings)
    in
    let* eps_kept, eps_deferred =
      Result.map_error
        (fun o -> stuck (Blocking_eps o))
        (split_orderings (eps_splitting scope entail) r.eps_orderings)
    in
    let* inner =
      match List.find_opt (fun d -> not (carried scope d)) r.deferred with
      | Some d -> Error (stuck (Blocking_deferred d))
      | None -> Ok (List.map (close_over scope origin) r.deferred)
    in
    let fresh =
      match (rho_deferred, eps_deferred) with
      | [], [] -> []
      | _, _ ->
          [
            close_over scope origin
              {
                origin;
                rigids = [];
                rho_conditions = rho_deferred;
                eps_conditions = eps_deferred;
              };
          ]
    in
    let at_top = X.Rho.subst (at_rigid scope X.Eps.top) in
    Ok
      {
        R.rho_orderings = rho_kept;
        eps_orderings = eps_kept;
        eternals = r.eternals;
        subs = r.subs;
        disjunctions =
          List.map
            (fun (d : R.disjunction) ->
              { d with disj_grade = at_top d.disj_grade })
            r.disjunctions;
        deferred = fresh @ inner;
      }

  (* ------------------------------------------------------------------ *)
  (* Retry                                                               *)
  (* ------------------------------------------------------------------ *)

  (* What the retry reads of the expressions of one sort. *)
  type 'e sort = {
    decide : 'e -> 'e -> bool;
    closed_leq : 'e -> 'e -> bool option;
    subst : X.subst -> 'e -> 'e;
    rho_vars : 'e -> Rho_set.t;
    eps_vars : 'e -> Eps_set.t;
    constants : 'e -> X.GS.R.t list * X.GS.E.t list;
    occurrences : Rho_set.t * Eps_set.t -> 'e -> int;
  }

  (* The number of occurrences of the unknowns [(rhos, eps)] in an
     expression. *)
  let rec eps_occurrences eps = function
    | X.Eps_var k -> if Eps_set.mem k eps then 1 else 0
    | X.Eps_const _ -> 0
    | X.Eps_mul (e, e') | X.Eps_join (e, e') ->
        eps_occurrences eps e + eps_occurrences eps e'

  let rec rho_occurrences ((rhos, eps) as unknowns) = function
    | X.Rho_var k -> if Rho_set.mem k rhos then 1 else 0
    | X.Rho_const _ -> 0
    | X.Rho_map e -> eps_occurrences eps e
    | X.Rho_mul (rho, rho') | X.Rho_join (rho, rho') ->
        rho_occurrences unknowns rho + rho_occurrences unknowns rho'

  let rho_sort entail bounds =
    {
      decide = E.Rho.follows entail;
      closed_leq = E.Rho.closed bounds;
      subst = X.Rho.subst;
      rho_vars = X.Rho.free_rho_vars;
      eps_vars = X.Rho.free_eps_vars;
      constants = X.Rho.constants;
      occurrences = rho_occurrences;
    }

  let eps_sort entail bounds =
    {
      decide = E.Eps.follows entail;
      closed_leq = E.Eps.closed bounds;
      subst = X.Eps.subst;
      rho_vars = (fun _ -> Rho_set.empty);
      eps_vars = X.Eps.free_vars;
      constants = (fun eps -> ([], X.Eps.constants eps));
      occurrences = (fun (_, eps) -> eps_occurrences eps);
    }

  (* The grades of [cs] without repetition, in order. *)
  let distinct equal cs =
    List.fold_left
      (fun kept c -> if List.exists (equal c) kept then kept else kept @ [ c ])
      [] cs

  (* The unit, the top and the grade of one delay step, of either sort. *)
  let eps_base = [ X.GS.E.one; X.GS.E.top; X.GS.E.of_nat 1 ]
  let rho_base = [ X.GS.R.one; X.GS.R.top; X.GS.R.of_nat 1 ]

  (* The grades tried for a rigid of an ordering with the constants
     [(rcs, ecs)] and at most [degree] occurrences of the rigids on either
     side: the unit, the top and the grade of one delay step, without
     repetition, then the witnesses the grades supply, with their
     completeness. *)
  let candidates context ~degree (rcs, ecs) =
    let bounds = context.Residual.bounds in
    let supplied, completeness = X.GS.witnesses ~degree bounds rcs ecs in
    (distinct (X.GS.E.equal bounds) eps_base @ supplied, completeness)

  (* Every assignment of a candidate to each of [rigids], lazily. *)
  let assignments candidates rigids =
    List.fold_right
      (fun rigid tails ->
        Seq.flat_map
          (fun c -> Seq.map (fun tail -> (rigid, c) :: tail) tails)
          (List.to_seq candidates))
      rigids (Seq.return [])

  let witness_subst assignment : X.subst =
    {
      empty_grade_subst with
      eps_subst =
        X.Eps_var.Map.of_seq
          (List.to_seq
             (List.map (fun (rigid, c) -> (rigid, X.Eps.const c)) assignment));
    }

  (* An ordering evaluated at a sequence of assignments: the first at which
     it fails, else whether it holds at every one. *)
  type search = Fails_at of (X.Eps_var.t * X.GS.E.t) list | Holds | Open

  let rec search holds_at found assignments =
    match assignments () with
    | Seq.Nil -> found
    | Seq.Cons (a, rest) -> (
        match holds_at a with
        | Some false -> Fails_at a
        | Some true -> search holds_at found rest
        | None -> search holds_at Open rest)

  (* The verdict on one ordering of a condition. *)
  type verdict = Settled | Refuted_at of X.GS.E.t list | Undecided

  (* An ordering that follows from the hypotheses is settled. One whose
     unknowns are rigids of [rigids] alone is evaluated at every assignment of
     candidates to the rigids it mentions: it is refuted at the first that
     fails, the other rigids at the unit, and settled when it holds at all of
     them and mentions no rigid, or one whose candidates are complete. *)
  let verdict context sort rigids (o : _ GradeNormal.ordering) =
    let eps_vars = Eps_set.union (sort.eps_vars o.lhs) (sort.eps_vars o.rhs) in
    let rho_vars = Rho_set.union (sort.rho_vars o.lhs) (sort.rho_vars o.rhs) in
    if sort.decide o.lhs o.rhs then Settled
    else if
      not
        (Rho_set.is_empty rho_vars
        && Eps_set.subset eps_vars (Eps_set.of_list rigids))
    then Undecided
    else
      let mentioned = List.filter (fun k -> Eps_set.mem k eps_vars) rigids in
      let rcs, ecs = sort.constants o.lhs
      and rcs', ecs' = sort.constants o.rhs in
      let degree =
        let ks = (Rho_set.empty, Eps_set.of_list rigids) in
        Int.max (sort.occurrences ks o.lhs) (sort.occurrences ks o.rhs)
      in
      let candidates, completeness =
        candidates context ~degree (rcs @ rcs', ecs @ ecs')
      in
      let holds_at a =
        let sigma = witness_subst a in
        sort.closed_leq (sort.subst sigma o.lhs) (sort.subst sigma o.rhs)
      in
      let value a k =
        Option.value ~default:X.GS.E.one
          (List.find_map
             (fun (k', c) -> if X.Eps_var.equal k k' then Some c else None)
             a)
      in
      match
        ( search holds_at Holds (assignments candidates mentioned),
          mentioned,
          completeness )
      with
      | Fails_at a, _, _ -> Refuted_at (List.map (value a) rigids)
      | Holds, [], _ | Holds, [ _ ], Grades.Grade.Complete -> Settled
      | Holds, _, _ | Open, _, _ -> Undecided

  (* The orderings left undecided, or the first refuted with its witness. *)
  let sift judge orderings =
    List.fold_right
      (fun o acc ->
        Result.bind acc (fun left ->
            match judge o with
            | Settled -> Ok left
            | Undecided -> Ok (o :: left)
            | Refuted_at witness -> Error (o, witness)))
      orderings (Ok [])

  let retry_condition context (entail : C.reason E.t) (d : R.deferred) =
    let open Result.Syntax in
    let bounds = context.Residual.bounds in
    let rigids = List.map fst d.rigids in
    let refuted condition witness =
      R.Refuted_condition { condition; witness }
    in
    let* rho_conditions =
      Result.map_error
        (fun (o, witness) ->
          refuted { d with rho_conditions = [ o ]; eps_conditions = [] } witness)
        (sift
           (verdict context (rho_sort entail bounds) rigids)
           d.rho_conditions)
    in
    let* eps_conditions =
      Result.map_error
        (fun (o, witness) ->
          refuted { d with rho_conditions = []; eps_conditions = [ o ] } witness)
        (sift
           (verdict context (eps_sort entail bounds) rigids)
           d.eps_conditions)
    in
    match (rho_conditions, eps_conditions) with
    | [], [] -> Ok []
    | _, _ -> Ok [ { d with rho_conditions; eps_conditions } ]

  let retry context (r : residual) =
    let entail =
      E.make context.Residual.bounds
        { rho_hyps = r.rho_orderings; eps_hyps = r.eps_orderings }
    in
    Result.map
      (fun deferred -> { r with deferred = List.concat deferred })
      (List.fold_right
         (fun d acc ->
           Result.bind acc (fun kept ->
               Result.map
                 (fun d -> d :: kept)
                 (retry_condition context entail d)))
         r.deferred (Ok []))

  (* ------------------------------------------------------------------ *)
  (* Closed instances                                                    *)
  (* ------------------------------------------------------------------ *)

  (* An atom a closed instance must meet. *)
  type item =
    | Rho_item of R.rho_ordering
    | Eps_item of R.eps_ordering
    | Condition of R.deferred

  (* The grade unknowns of an item, the rigids of a condition excepted. *)
  let item_unknowns = function
    | Rho_item o -> sides grades_of_rho o no_grades
    | Eps_item o -> sides grades_of_eps o no_grades
    | Condition d -> deferred_grades d no_grades

  let shares (rhos, eps) (rhos', eps') =
    not (Rho_set.disjoint rhos rhos' && Eps_set.disjoint eps eps')

  (* The sides of the orderings of an item, each read by [on_rho] or
     [on_eps]. *)
  let item_sides ~on_rho ~on_eps = function
    | Rho_item o -> [ on_rho o.lhs; on_rho o.rhs ]
    | Eps_item o -> [ on_eps o.lhs; on_eps o.rhs ]
    | Condition d ->
        List.concat_map
          (fun (o : R.rho_ordering) -> [ on_rho o.lhs; on_rho o.rhs ])
          d.rho_conditions
        @ List.concat_map
            (fun (o : R.eps_ordering) -> [ on_eps o.lhs; on_eps o.rhs ])
            d.eps_conditions

  let item_constants item =
    List.fold_left
      (fun (rcs, ecs) (rcs', ecs') -> (rcs @ rcs', ecs @ ecs'))
      ([], [])
      (item_sides ~on_rho:X.Rho.constants
         ~on_eps:(fun eps -> ([], X.Eps.constants eps))
         item)

  (* The largest number of occurrences of the unknowns [(rhos, eps)] on one
     side of an ordering of the item. *)
  let item_degree ((_, eps) as unknowns) item =
    List.fold_left Int.max 0
      (item_sides ~on_rho:(rho_occurrences unknowns)
         ~on_eps:(eps_occurrences eps) item)

  (* Whether an item holds at the values [sigma] of its unknowns: an ordering
     decided true between variable-free sides, a condition discharged by its
     retry at no hypotheses. *)
  let holds context sigma = function
    | Rho_item o ->
        E.Rho.closed context.Residual.bounds (X.Rho.subst sigma o.lhs)
          (X.Rho.subst sigma o.rhs)
        = Some true
    | Eps_item o ->
        E.Eps.closed context.Residual.bounds (X.Eps.subst sigma o.lhs)
          (X.Eps.subst sigma o.rhs)
        = Some true
    | Condition d -> (
        match (apply sigma { R.empty with deferred = [ d ] }).deferred with
        | [ d ] ->
            retry_condition context (E.make context.Residual.bounds N.no_hyps) d
            = Ok []
        | _ -> false)

  let by_index (i, _) (j, _) = Int.compare i j

  (* The items in classes sharing unknowns, each in the order of the items,
     the classes in the order of their first items. *)
  let components items =
    let classes =
      List.fold_left
        (fun classes (i, item) ->
          let unknowns = item_unknowns item in
          let joined, apart =
            List.partition
              (fun (unknowns', _) -> shares unknowns unknowns')
              classes
          in
          List.fold_left
            (fun (unknowns, members) (unknowns', members') ->
              (union_grades unknowns unknowns', members' @ members))
            (unknowns, [ (i, item) ])
            joined
          :: apart)
        []
        (List.mapi (fun i item -> (i, item)) items)
    in
    List.map
      (fun (unknowns, members) -> (unknowns, List.sort by_index members))
      classes
    |> List.sort (fun (_, members) (_, members') ->
        by_index (List.hd members) (List.hd members'))
    |> List.map (fun (unknowns, members) -> (unknowns, List.map snd members))

  (* The grades tried for the unknowns of a component with the constants
     [(rcs, ecs)] and at most [degree] occurrences of its unknowns on one side
     of an item: the unit, the top, the grade of one delay step and the
     constants of the sort, the images of the effect constants for a resource,
     then the witnesses the grades supply. *)
  let eps_candidates context ~degree (rcs, ecs) =
    let bounds = context.Residual.bounds in
    distinct (X.GS.E.equal bounds)
      (eps_base @ ecs @ fst (X.GS.witnesses ~degree bounds rcs ecs))

  let rho_candidates context ~degree (rcs, ecs) =
    let bounds = context.Residual.bounds in
    let rcs = rcs @ List.map X.GS.map ecs in
    distinct (X.GS.R.equal bounds)
      (rho_base @ rcs @ fst (X.GS.R.witnesses ~degree bounds rcs))

  (* The outcome of the search of one component. *)
  type found = Found of X.subst | Exhausted | Abandoned

  (* Depth-first backtracking over the candidates of each unknown in turn,
     each level the candidates of an unknown and the items whose last unknown
     it is, checked as soon as it is assigned. Each candidate tried spends one
     trial of [budget]. *)
  let rec descend context levels sigma budget =
    match levels with
    | [] -> (Found sigma, budget)
    | (candidates, checks) :: levels ->
        let rec try_each budget = function
          | [] -> (Exhausted, budget)
          | _ :: _ when budget <= 0 -> (Abandoned, budget)
          | value :: values ->
              let sigma' = X.compose_subst sigma value in
              if List.for_all (holds context sigma') checks then
                match descend context levels sigma' (budget - 1) with
                | Exhausted, budget -> try_each budget values
                | ((Found _ | Abandoned), _) as outcome -> outcome
              else try_each (budget - 1) values
        in
        try_each budget candidates

  (* The levels of a component: its unknowns, those occurring in more items
     first, each with its candidates and the items whose last unknown it is;
     and the items without unknowns. The order by degree follows the
     fail-first principle (Haralick and Elliott, AIJ 1980). *)
  let levels context ((rhos, eps) as unknowns) items =
    let tagged = List.map (fun item -> (item_unknowns item, item)) items in
    let count u =
      List.length (List.filter (fun ((rhos, eps), _) -> u rhos eps) tagged)
    in
    let order =
      List.map
        (fun k -> (Eps_unknown k, count (fun _ eps -> Eps_set.mem k eps)))
        (Eps_set.elements eps)
      @ List.map
          (fun k -> (Rho_unknown k, count (fun rhos _ -> Rho_set.mem k rhos)))
          (Rho_set.elements rhos)
      |> List.stable_sort (fun (_, n) (_, n') -> Int.compare n' n)
      |> List.map fst
    in
    let degree =
      List.fold_left Int.max 0 (List.map (item_degree unknowns) items)
    and constants =
      List.fold_left
        (fun (rcs, ecs) item ->
          let rcs', ecs' = item_constants item in
          (rcs @ rcs', ecs @ ecs'))
        ([], []) items
    in
    let eps_values =
      lazy (List.map X.Eps.const (eps_candidates context ~degree constants))
    and rho_values =
      lazy (List.map X.Rho.const (rho_candidates context ~degree constants))
    in
    let position (rhos, eps) =
      List.fold_left Int.max (-1)
        (List.mapi
           (fun i u ->
             match u with
             | Eps_unknown k when Eps_set.mem k eps -> i
             | Rho_unknown k when Rho_set.mem k rhos -> i
             | Eps_unknown _ | Rho_unknown _ -> -1)
           order)
    in
    let at i =
      List.filter_map
        (fun (unknowns, item) ->
          if position unknowns = i then Some item else None)
        tagged
    in
    ( List.mapi
        (fun i u ->
          let values =
            match u with
            | Eps_unknown k -> List.map (assign_eps k) (Lazy.force eps_values)
            | Rho_unknown k -> List.map (assign_rho k) (Lazy.force rho_values)
          in
          (values, at i))
        order,
      at (-1) )

  let unestablished ~abandoned items =
    R.Unestablished
      {
        rho_orderings =
          List.filter_map (function Rho_item o -> Some o | _ -> None) items;
        eps_orderings =
          List.filter_map (function Eps_item o -> Some o | _ -> None) items;
        conditions =
          List.filter_map (function Condition d -> Some d | _ -> None) items;
        abandoned;
      }

  (* The number of candidates tried by default in each component. *)
  let default_budget = 100_000

  (* A closed instance of the orderings and deferred conditions of [r]:
     backtracking search (Golomb and Baumert, JACM 1965) over a finite grid of
     candidates per unknown, a constraint satisfaction problem solved one
     component of unknowns sharing items at a time, each within [budget]
     trials. The type unknowns are left out: after [atomise], the subtyping
     and eternality demands relate type unknowns alone, and each disjunction
     kept has a type whose eternality depends on type unknowns, so [unit] for
     every type unknown meets them all. Where [r] is the residual of
     localisation, its values, the assignment found and [unit] for the type
     unknowns form a closed instance of the qualifier. An assignment found is
     an instance; an instance outside the grid is not found. *)
  let instance ?(budget = default_budget) context (r : residual) =
    let items =
      List.map (fun o -> Rho_item o) r.rho_orderings
      @ List.map (fun o -> Eps_item o) r.eps_orderings
      @ List.map (fun d -> Condition d) r.deferred
    in
    let search found (unknowns, items) =
      Result.bind found (fun sigma ->
          let levels, closed = levels context unknowns items in
          if not (List.for_all (holds context empty_grade_subst) closed) then
            Error (unestablished ~abandoned:false items)
          else
            match fst (descend context levels empty_grade_subst budget) with
            | Found sigma' -> Ok (X.compose_subst sigma sigma')
            | Exhausted -> Error (unestablished ~abandoned:false items)
            | Abandoned -> Error (unestablished ~abandoned:true items))
    in
    List.fold_left search (Ok empty_grade_subst) (components items)
end
