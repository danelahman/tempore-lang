(* The printers and the phrases of the diagnostics of rejected commands. *)

module Ast = Language.Ast
module Diagnostic = Utils.Diagnostic
module Location = Utils.Location
module PrettyPrint = Language.PrettyPrint
module Reason = Inference.Reason
module Skeleton = Inference.Skeleton

module Make (C : Inference.Constraint.S) = struct
  module X = C.X
  module GS = X.GS
  module R = Inference.Residual.Make (C)
  module RS = Inference.RigidScope.Make (C)
  module S = Inference.Solver.Make (C)
  module N = Inference.GradeNormal.Make (X)

  type source = {
    context : S.context;
    constr : C.t option;
    solution : S.solution option;
    mismatch : S.mismatch option;
  }

  (* ------------------------------------------------------------------ *)
  (* Printing                                                            *)
  (* ------------------------------------------------------------------ *)

  (* Type unknowns are named by Greek letters other than [ε], which names
     effect unknowns. *)
  module Ty_names =
    PrettyPrint.MakeParamPrinter
      (Ast.TyParamMap)
      (struct
        let symbol_for_index n =
          PrettyPrint.type_symbol (if n < 4 then n else n + 1)
      end)

  module Rho_names =
    PrettyPrint.MakeParamPrinter
      (X.Rho_var.Map)
      (struct
        let symbol_for_index = PrettyPrint.rho_symbol
      end)

  module Eps_names =
    PrettyPrint.MakeParamPrinter
      (X.Eps_var.Map)
      (struct
        let symbol_for_index = PrettyPrint.eps_symbol
      end)

  type printer = {
    bounds : Grades.Grade.bounds;
    values : X.subst;
    ty_name : Ast.ty_param -> Format.formatter -> unit;
    rho_name : X.Rho_var.t -> Format.formatter -> unit;
    eps_name : X.Eps_var.t -> Format.formatter -> unit;
  }

  (* Whether a closed grade is the top and not the unit. *)
  let is_top_rho bounds rho =
    match X.Rho.value rho with
    | Some c -> GS.R.is_top bounds c && not (GS.R.equal bounds c GS.R.one)
    | None -> false

  let is_top_eps bounds eps =
    match X.Eps.value eps with
    | Some c -> GS.E.is_top bounds c && not (GS.E.equal bounds c GS.E.one)
    | None -> false

  let instance_values (context : S.context) (solution : S.solution) =
    let hyps = solution.hyps in
    let values, _ =
      RS.localise_all context
        {
          R.rho_orderings = hyps.rho_hyps;
          eps_orderings = hyps.eps_hyps;
          eternals = hyps.eternal_hyps;
          subs = hyps.sub_vars;
          disjunctions = hyps.disj_hyps;
          deferred = solution.obligations;
        }
    in
    let bounds = context.bounds in
    {
      X.rho_subst =
        X.Rho_var.Map.filter
          (fun _ rho -> not (is_top_rho bounds rho))
          values.X.rho_subst;
      eps_subst =
        X.Eps_var.Map.filter
          (fun _ eps -> not (is_top_eps bounds eps))
          values.eps_subst;
    }

  let rec rigid_origins = function
    | C.Forall_eps (rigid, origin, c) -> (rigid, origin) :: rigid_origins c
    | C.And (c, d) -> rigid_origins c @ rigid_origins d
    | C.Exists (_, c) -> rigid_origins c
    | C.True | C.Sub _ | C.Rho_leq _ | C.Eps_leq _ | C.Eternal _
    | C.Eternal_or_unit _ ->
        []

  let printer (source : source) =
    let origins =
      match source.constr with Some c -> rigid_origins c | None -> []
    in
    {
      bounds = source.context.bounds;
      values =
        Option.fold ~none:X.empty_subst
          ~some:(instance_values source.context)
          source.solution;
      ty_name = Ty_names.create ();
      rho_name = Rho_names.create ();
      eps_name =
        Eps_names.create_with
          ~named:(fun e ->
            Option.map
              (fun (origin : Reason.rigid_origin) ->
                PrettyPrint.rigid_symbol (Ast.OpName.string_of origin.clause.op))
              (List.assoc_opt e origins))
          ();
    }

  (* A diagnostic's text is one line; its layout is the renderer's. *)
  let render f =
    let buffer = Buffer.create 64 in
    let ppf = Format.formatter_of_buffer buffer in
    Format.pp_set_margin ppf 1000000;
    Format.fprintf ppf "@[<h>%t@]" f;
    Format.pp_print_flush ppf ();
    Buffer.contents buffer

  (* Grades are shown in canonical form, and as they are where their delays
     exceed the supported range. *)
  let canon_rho p rho =
    match N.Rho.canon p.bounds rho with
    | rho -> rho
    | exception Utils.Error.Error _ -> rho

  let canon_eps p eps =
    match N.Eps.canon p.bounds eps with
    | eps -> eps
    | exception Utils.Error.Error _ -> eps

  let paren wrap body ppf =
    if wrap then Format.fprintf ppf "(%t)" body else body ppf

  (* Operands of a join are printed at level 0, of a product at level 1. *)
  let binary level op_level symbol left right ppf =
    paren (level > op_level)
      (fun ppf -> Format.fprintf ppf "%t %s %t" left symbol right)
      ppf

  let rec eps_at p level eps ppf =
    match eps with
    | X.Eps_var e -> p.eps_name e ppf
    | X.Eps_const c -> Format.pp_print_string ppf (GS.E.show c)
    | X.Eps_mul (eps, eps') ->
        binary level 1 "·" (eps_at p 1 eps) (eps_at p 1 eps') ppf
    | X.Eps_join (eps, eps') ->
        binary level 0 "⊔" (eps_at p 0 eps) (eps_at p 0 eps') ppf

  let rec rho_at p level rho ppf =
    match rho with
    | X.Rho_var r -> p.rho_name r ppf
    | X.Rho_const c -> Format.pp_print_string ppf (GS.R.show c)
    | X.Rho_map eps -> Format.fprintf ppf "∣%t∣" (eps_at p 0 eps)
    | X.Rho_mul (rho, rho') ->
        binary level 1 "·" (rho_at p 1 rho) (rho_at p 1 rho') ppf
    | X.Rho_join (rho, rho') ->
        binary level 0 "⊔" (rho_at p 0 rho) (rho_at p 0 rho') ppf

  let print_rho p rho = rho_at p 0 (canon_rho p rho)
  let print_eps p eps = eps_at p 0 (canon_eps p eps)
  let rho_raw p rho = render (print_rho p rho)
  let eps_raw p eps = render (print_eps p eps)

  let is_unit_rho p rho =
    match X.Rho.value (canon_rho p rho) with
    | Some c -> GS.R.equal p.bounds c GS.R.one
    | None -> false

  let is_unit_eps p eps =
    match X.Eps.value (canon_eps p eps) with
    | Some c -> GS.E.equal p.bounds c GS.E.one
    | None -> false

  (* A computation's effect of the unit is not shown. *)
  let ty_raw p ty =
    let grades =
      { PrettyPrint.rho = print_rho p; eps = print_eps p; pure = is_unit_eps p }
    in
    render (PrettyPrint.print_ty grades p.ty_name ty)

  (* A skeleton, its box grades shown as [_]. *)
  let rec ty_of_skeleton : Skeleton.t -> (unit, unit) Ast.ty = function
    | Skeleton.Var a -> Ast.TyParam a
    | Skeleton.Const c -> Ast.TyConst c
    | Skeleton.Apply (name, ts) -> Ast.TyApply (name, List.map ty_of_skeleton ts)
    | Skeleton.Tuple ts -> Ast.TyTuple (List.map ty_of_skeleton ts)
    | Skeleton.Arrow (t, u) ->
        Ast.TyArrow (ty_of_skeleton t, Ast.CompTy (ty_of_skeleton u, ()))
    | Skeleton.Box t -> Ast.TyBox ((), ty_of_skeleton t)
    | Skeleton.Handler (t, u) ->
        Ast.TyHandler
          (Ast.CompTy (ty_of_skeleton t, ()), Ast.CompTy (ty_of_skeleton u, ()))

  let skeleton_raw p t =
    let blank () ppf = Format.pp_print_string ppf "_" in
    let grades =
      { PrettyPrint.rho = blank; eps = blank; pure = (fun () -> true) }
    in
    render (PrettyPrint.print_ty grades p.ty_name (ty_of_skeleton t))

  let code text = "`" ^ text ^ "`"
  let ty_code p ty = code (ty_raw p ty)
  let rho_code p rho = code (rho_raw p rho)

  (* ------------------------------------------------------------------ *)
  (* Grade sorts                                                         *)
  (* ------------------------------------------------------------------ *)

  type _ tag = Rho_tag : C.rho tag | Eps_tag : C.eps tag

  type 'e sort = {
    tag : 'e tag;
    noun : string;
    leq_symbol : string;
    raw : printer -> 'e -> string;
    eps_vars : 'e -> X.Eps_var.Set.t;
    subst : X.subst -> 'e -> 'e;
    stated_of : C.reason -> ('e * 'e) option;
    shares : 'e -> 'e -> bool;
    hyps_of : R.hyps -> ('e, C.reason) Inference.GradeNormal.ordering list;
    counterexample : printer -> 'e * 'e -> string option;
  }

  (** [counterexample_of (module G) value p (lhs, rhs)] is the counterexample
      [G] offers to [lhs ≾ rhs], printed, when [value] finds both sides constant
      and it is not [lhs] itself. *)
  let counterexample_of (type g) (module G : Grades.Grade.S with type t = g)
      value p (lhs, rhs) =
    match (value p lhs, value p rhs) with
    | Some c, Some d -> (
        match G.counterexample p.bounds c d with
        | Some e when not (G.equal p.bounds e c) -> Some (G.show e)
        | Some _ | None -> None)
    | _ -> None

  let rho_sort =
    {
      tag = Rho_tag;
      noun = "resource";
      leq_symbol = GS.R.leq_symbol;
      raw = rho_raw;
      eps_vars = X.Rho.free_eps_vars;
      subst = X.Rho.subst;
      stated_of =
        (fun r ->
          match r.stated with
          | Some (Reason.Stated_rho (rho, rho')) -> Some (rho, rho')
          | Some (Reason.Stated_eps _) | None -> None);
      shares =
        (fun rho rho' ->
          (not
             (X.Rho_var.Set.disjoint (X.Rho.free_rho_vars rho)
                (X.Rho.free_rho_vars rho')))
          || not
               (X.Eps_var.Set.disjoint (X.Rho.free_eps_vars rho)
                  (X.Rho.free_eps_vars rho')));
      hyps_of = (fun hyps -> hyps.R.rho_hyps);
      counterexample =
        counterexample_of
          (module GS.R)
          (fun p rho -> X.Rho.value (canon_rho p rho));
    }

  let eps_sort =
    {
      tag = Eps_tag;
      noun = "effect";
      leq_symbol = GS.E.leq_symbol;
      raw = eps_raw;
      eps_vars = X.Eps.free_vars;
      subst = X.Eps.subst;
      stated_of =
        (fun r ->
          match r.stated with
          | Some (Reason.Stated_eps (eps, eps')) -> Some (eps, eps')
          | Some (Reason.Stated_rho _) | None -> None);
      shares =
        (fun eps eps' ->
          not
            (X.Eps_var.Set.disjoint (X.Eps.free_vars eps) (X.Eps.free_vars eps')));
      hyps_of = (fun hyps -> hyps.R.eps_hyps);
      counterexample =
        counterexample_of
          (module GS.E)
          (fun p eps -> X.Eps.value (canon_eps p eps));
    }

  (* ------------------------------------------------------------------ *)
  (* Words                                                               *)
  (* ------------------------------------------------------------------ *)

  let label span text = { Diagnostic.span; text }
  let here = Diagnostic.place

  let diagnostic ~primary ~labels ~notes message =
    {
      Diagnostic.kind = Diagnostic.Typing;
      primary = Some primary;
      message;
      labels;
      notes;
    }

  let var_name x =
    if Ast.Variable.is_synthetic x then None
    else Some (code (Ast.Variable.string_of x))

  let op_name op = code (Ast.OpName.string_of op)
  let label_name lbl = code (Ast.label_string_of lbl)

  let subject x =
    match var_name x with
    | Some name -> "Variable " ^ name
    | None -> "This expression"

  let holder x =
    match var_name x with Some name -> name | None -> "This expression"

  let describe x =
    match var_name x with Some name -> name | None -> "this expression"

  let needed_eternal x =
    match var_name x with
    | Some name -> "the type of " ^ name
    | None -> "the type of a value it keeps while a grade accumulates"

  (* ------------------------------------------------------------------ *)
  (* Continuation grades                                                 *)
  (* ------------------------------------------------------------------ *)

  (* The continuation of a clause, as the subject of a sentence and as a noun
     phrase; it is named only when the clause binds it to a variable. *)
  let continuation_subject (o : Reason.rigid_origin) =
    match Option.map var_name o.continuation with
    | Some (Some name) -> name
    | Some None | None -> "the continuation"

  let continuation_phrase (o : Reason.rigid_origin) =
    match Option.map var_name o.continuation with
    | Some (Some name) -> "the continuation " ^ name
    | Some None | None -> "the continuation"

  type rigid = {
    var : X.Eps_var.t;
    origin : Reason.rigid_origin;
    value : GS.E.t;
  }

  let rigids_of source vars ~value =
    let origins =
      match source.constr with Some c -> rigid_origins c | None -> []
    in
    X.Eps_var.Set.elements vars
    |> List.filter_map (fun var ->
        Option.map
          (fun origin -> { var; origin; value = value var })
          (List.assoc_opt var origins))
    |> List.sort (fun r r' ->
        Location.compare r.origin.clause.case_at r'.origin.clause.case_at)

  let rigid_raw p r = render (p.eps_name r.var)

  let for_every p rs =
    "for every "
    ^ String.concat " and every "
        (List.map
           (fun r ->
             let name = code (rigid_raw p r) in
             Printf.sprintf "grade %s %s may have" name
               (continuation_phrase r.origin))
           rs)

  let rigid_labels p rs =
    List.map
      (fun r ->
        let name = code (rigid_raw p r) in
        label r.origin.continuation_at
          (Printf.sprintf "%s may have any grade %s"
             (continuation_subject r.origin)
             name))
      rs

  let mentioned_rigids source reasons =
    let vars =
      List.fold_left
        (fun acc reason ->
          Reason.fold_grades
            (fun rho acc -> X.Eps_var.Set.union acc (X.Rho.free_eps_vars rho))
            (fun eps acc -> X.Eps_var.Set.union acc (X.Eps.free_vars eps))
            reason acc)
        X.Eps_var.Set.empty reasons
    in
    rigids_of source vars ~value:(fun _ -> GS.E.top)

  let ty_rigids source = function
    | Some ty ->
        rigids_of source (C.free_vars_ty ty).free_eps ~value:(fun _ -> GS.E.top)
    | None -> []

  let union_rigids rs rs' =
    rs
    @ List.filter
        (fun r' -> not (List.exists (fun r -> X.Eps_var.equal r.var r'.var) rs))
        rs'

  let with_rigid_labels p rs labels =
    let rigid = rigid_labels p rs in
    let bound = "is bound " ^ here in
    let displaced (l : Diagnostic.label) =
      String.ends_with ~suffix:bound l.text
      && List.exists
           (fun (l' : Diagnostic.label) -> Location.equal l.span l'.span)
           rigid
    in
    List.filter (fun l -> not (displaced l)) labels @ rigid

  let quantified p rs text =
    match rs with
    | [] -> code text
    | rs ->
        let names = List.map (rigid_raw p) rs in
        code (Printf.sprintf "∀%s. %s" (String.concat " " names) text)

  (* ------------------------------------------------------------------ *)
  (* Refutations                                                         *)
  (* ------------------------------------------------------------------ *)

  type 'e refutation = {
    sort : 'e sort;
    stated : 'e * 'e;
    instance : 'e * 'e;
    rigids : rigid list;
    reasons : C.reason list;
  }

  let ineq_text p sort (lhs, rhs) =
    let lhs = sort.raw p lhs in
    let rhs = sort.raw p rhs in
    Printf.sprintf "%s %s %s" lhs sort.leq_symbol rhs

  let ineq_note p f =
    match f.rigids with
    | [] ->
        Printf.sprintf "the %s inequality %s does not hold" f.sort.noun
          (code (ineq_text p f.sort f.instance))
    | rs ->
        let stated = quantified p rs (ineq_text p f.sort f.stated) in
        let values =
          String.concat " and "
            (List.map
               (fun r ->
                 code
                   (Printf.sprintf "%s = %s" (rigid_raw p r) (GS.E.show r.value)))
               rs)
        in
        let instance = code (ineq_text p f.sort f.instance) in
        Printf.sprintf
          "the %s inequality %s does not hold: for %s it becomes %s" f.sort.noun
          stated values instance

  let counterexample_notes p f =
    let lhs, rhs = f.instance in
    match f.sort.counterexample p f.instance with
    | Some e ->
        [
          Printf.sprintf "the grade %s is below %s but not below %s" (code e)
            (code (f.sort.raw p lhs))
            (code (f.sort.raw p rhs));
        ]
    | None -> []

  let ineq_notes p f = ineq_note p f :: counterexample_notes p f
end
