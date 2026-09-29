(* Diagnostics of rejected commands. *)

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
    values : X.subst;  (** the values of the unknowns explained against *)
    ty_name : Ast.ty_param -> Format.formatter -> unit;
    rho_name : X.Rho_var.t -> Format.formatter -> unit;
    eps_name : X.Eps_var.t -> Format.formatter -> unit;
  }
  (** The printers of one diagnostic, which name the unknowns in the order they
      are first printed, so that a name means the same unknown in the headline,
      the labels and the notes. *)

  (* Whether a closed grade is the top and not the unit. *)
  let is_top_rho bounds rho =
    match X.Rho.value rho with
    | Some c -> GS.R.is_top bounds c && not (GS.R.equal bounds c GS.R.one)
    | None -> false

  let is_top_eps bounds eps =
    match X.Eps.value eps with
    | Some c -> GS.E.is_top bounds c && not (GS.E.equal bounds c GS.E.one)
    | None -> false

  (* The values of the grade unknowns of a solution in the search for a closed
     instance of its qualifier, except those sent to the top for want of any
     bound, which stay unknown. *)
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

  let printer (source : source) =
    {
      bounds = source.context.bounds;
      values =
        Option.fold ~none:X.empty_subst
          ~some:(instance_values source.context)
          source.solution;
      ty_name = Ty_names.create ();
      rho_name = Rho_names.create ();
      eps_name = Eps_names.create ();
    }

  (* A diagnostic's text is one line; its layout is the renderer's. *)
  let render f =
    let buffer = Buffer.create 64 in
    let ppf = Format.formatter_of_buffer buffer in
    Format.pp_set_margin ppf 1000000;
    Format.fprintf ppf "@[<h>%t@]" f;
    Format.pp_print_flush ppf ();
    Buffer.contents buffer

  (* Grades are shown in canonical form. *)
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

  (** A fragment of the user's code inside a sentence, marked as {!Diagnostic}
      marks it. *)
  let code text = "`" ^ text ^ "`"

  let ty_code p ty = code (ty_raw p ty)
  let rho_code p rho = code (rho_raw p rho)

  (* ------------------------------------------------------------------ *)
  (* Grade sorts                                                         *)
  (* ------------------------------------------------------------------ *)

  (** The two sorts of grade expressions. *)
  type _ tag = Rho_tag : C.rho tag | Eps_tag : C.eps tag

  type 'e sort = {
    tag : 'e tag;
    noun : string;  (** the sort in a sentence *)
    leq_symbol : string;
    raw : printer -> 'e -> string;
    eps_vars : 'e -> X.Eps_var.Set.t;  (** the effect unknowns *)
    subst : X.subst -> 'e -> 'e;
    stated_of : C.reason -> ('e * 'e) option;
        (** the ordering of this sort a reason records as stated *)
    shares : 'e -> 'e -> bool;
        (** whether two grades have an unknown in common *)
    hyps_of : R.hyps -> ('e, C.reason) Inference.GradeNormal.ordering list;
        (** the hypotheses of this sort *)
    counterexample : printer -> 'e * 'e -> string option;
        (** a grade below the first of two constant grades but not below the
            second, other than the first itself, printed, if the grades offer
            one *)
  }
  (** The operations a message needs on the grades of one sort. *)

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

  (** A variable as a message may name it. A compiler-invented one is not named:
      the message talks about the expression instead. *)
  let var_name x =
    if Ast.Variable.is_synthetic x then None
    else Some (code (Ast.Variable.string_of x))

  let op_name op = code (Ast.OpName.string_of op)
  let label_name lbl = code (Ast.Label.string_of lbl)

  (* "Variable x" or "This expression"; both start a sentence. *)
  let subject x =
    match var_name x with
    | Some name -> "Variable " ^ name
    | None -> "This expression"

  let holder x =
    match var_name x with Some name -> name | None -> "This expression"

  let describe x =
    match var_name x with Some name -> name | None -> "this expression"

  (* What a definition needs eternal, as "f needs ... to be eternal"
     continues. *)
  let needed_eternal x =
    match var_name x with
    | Some name -> "the type of " ^ name
    | None -> "the type of a value it keeps while a grade accumulates"

  (* ------------------------------------------------------------------ *)
  (* Continuation grades                                                 *)
  (* ------------------------------------------------------------------ *)

  (* The rigid effect variables of a constraint, each with its clause. *)
  let rec rigid_origins = function
    | C.Forall_eps (rigid, origin, c) -> (rigid, origin) :: rigid_origins c
    | C.And (c, d) -> rigid_origins c @ rigid_origins d
    | C.Exists (_, c) -> rigid_origins c
    | C.True | C.Sub _ | C.Rho_leq _ | C.Eps_leq _ | C.Eternal _
    | C.Eternal_or_unit _ ->
        []

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
    value : GS.E.t;  (** the grade at which the ordering fails *)
  }
  (** A rigid effect variable an ordering is quantified over. *)

  (* The rigids of [vars] whose clause is known, outermost clause first. *)
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

  (** The form the messages quantify with. *)
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

  (* The rigids whose grades the reasons mention. *)
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

  (* The rigids a type mentions. *)
  let ty_rigids source = function
    | Some ty ->
        rigids_of source (C.free_vars_ty ty).free_eps ~value:(fun _ -> GS.E.top)
    | None -> []

  (* The rigids of [rs] followed by those of [rs'] not among them. *)
  let union_rigids rs rs' =
    rs
    @ List.filter
        (fun r' -> not (List.exists (fun r -> X.Eps_var.equal r.var r'.var) rs))
        rs'

  (* The labels [labels] and those of the rigids [rs], a label of a binding
     giving way to that of a rigid on the same span. *)
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

  (* A fragment quantified over the rigids its sides mention. *)
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
    stated : 'e * 'e;  (** the sides as generated *)
    instance : 'e * 'e;  (** the variable-free sides that fail *)
    rigids : rigid list;  (** the rigids of [stated] and their values *)
    reasons : C.reason list;  (** the atoms it follows from, in chain order *)
  }
  (** A failing ordering. Where it is quantified over rigids, [instance] is
      [stated] at their values. *)

  let ineq_text p sort (lhs, rhs) =
    let lhs = sort.raw p lhs in
    let rhs = sort.raw p rhs in
    Printf.sprintf "%s %s %s" lhs sort.leq_symbol rhs

  (** The note spelling out the ordering: quantified over the rigids, with the
      instance that refutes it. *)
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

  (** The note naming a counterexample to the refuted ordering between the
      constant grades of its instance, if the grades offer one. *)
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

  (** The notes spelling out the ordering and a counterexample to it. *)
  let ineq_notes p f = ineq_note p f :: counterexample_notes p f

  (* ------------------------------------------------------------------ *)
  (* Accumulated grades                                                  *)
  (* ------------------------------------------------------------------ *)

  (* The grade of a lock as a label shows it: the image of an effect grade as
     the effect grade. *)
  let lock_grade_raw p rho =
    match canon_rho p rho with
    | X.Rho_map eps -> eps_raw p eps
    | rho -> rho_raw p rho

  (* The grade a label names for a lock: its own at the values of the
     instance explained against where that is closed, else the grade its
     construct declares, where there is one. *)
  let lock_grade p (e : C.rho Reason.lock) =
    let grade = X.Rho.subst p.values e.grade in
    match (X.Rho.value (canon_rho p grade), e.declared) with
    | None, Some declared -> declared
    | Some _, _ | None, None -> grade

  (* One lock that contributed to an accumulated grade, naming its grade and
     its construct. *)
  let lock_text p (e : C.rho Reason.lock) =
    let grade = code (lock_grade_raw p (lock_grade p e)) in
    let accumulates what =
      Printf.sprintf "grade %s accumulates %s (%s)" grade here what
    in
    match e.kind with
    | Reason.Delayed _ -> accumulates "delay"
    | Reason.Performed op -> accumulates ("operation " ^ op_name op)
    | Reason.Sequenced -> accumulates "this computation"
    | Reason.Boxed -> accumulates "the boxed value"
    | Reason.Handled -> accumulates "the handled computation"
    | Reason.Clause_lock clause ->
        Printf.sprintf
          "the case for %s is checked with the top grade %s accumulated"
          (op_name clause.op) grade
    | Reason.Recursive_lock f ->
        Printf.sprintf
          "%s is defined %s, its body checked with the top grade %s accumulated"
          (describe f) here grade

  (* A grade of the unit is no part of the explanation. *)
  let lock_labels p locks =
    List.filter_map
      (fun (e : C.rho Reason.lock) ->
        if is_unit_rho p (lock_grade p e) then None
        else Some (label e.at (lock_text p e)))
      locks

  (* The grade accumulated by locks, oldest first: the product of their
     grades. *)
  let accumulated_grade (locks : C.rho Reason.lock list) =
    match locks with
    | [] -> X.Rho.unit
    | e :: rest ->
        List.fold_left
          (fun rho (e : C.rho Reason.lock) -> X.Rho.mul rho e.grade)
          e.grade rest

  (* Labels a reader meets in the order the program reads. *)
  let in_span_order labels =
    List.stable_sort
      (fun (l : Diagnostic.label) (l' : Diagnostic.label) ->
        Location.compare l.span l'.span)
      labels

  let binding_labels x bound_at =
    match bound_at with
    | None -> []
    | Some at ->
        [
          label at
            (match var_name x with
            | Some name -> name ^ " is bound " ^ here
            | None -> "this value is bound " ^ here);
        ]

  let declared_label op signature_at =
    label signature_at ("operation " ^ op_name op ^ " is declared " ^ here)

  (* The places of a capture by the body of the recursive function [f]: where
     grades accumulated, and where [f] is defined, which the label of the lock
     of its body names unless that lock's grade is the unit. *)
  let rec_capture_labels p f defined_at locks =
    let names_f (e : C.rho Reason.lock) =
      match e.kind with
      | Reason.Recursive_lock g ->
          Ast.Variable.compare f g = 0 && not (is_unit_rho p (lock_grade p e))
      | _ -> false
    in
    let spent = lock_labels p locks in
    if List.exists names_f locks then spent
    else label defined_at (describe f ^ " is defined " ^ here) :: spent

  (* The use a var-rule atom began at, through the definitions whose schemes
     carried it: the reason of the use. *)
  let rec use_of (reason : C.reason) =
    match reason.why with
    | Reason.Instance_of { inner; _ } -> use_of inner
    | Reason.Use_under_locks _ | Reason.Op_case_capture _ | Reason.Rec_capture _
      ->
        Some reason
    | _ -> None

  (** The story of a use under locks, in source order: where the variable was
      bound, where grades accumulated since, and the use itself. *)
  let use_labels p (use : C.reason) =
    match use.why with
    | Reason.Use_under_locks { var; bound_at; locks } ->
        let total = accumulated_grade locks in
        let text =
          if is_unit_rho p total then
            Printf.sprintf "%s is used %s" (describe var) here
          else
            Printf.sprintf
              "%s is used %s with grade %s accumulated since it was bound, \
               which only an eternal type allows"
              (describe var) here (rho_code p total)
        in
        in_span_order
          (binding_labels var (Some bound_at)
          @ lock_labels p locks
          @ [ label use.at text ])
    | Reason.Op_case_capture { var; bound_at; clause; locks } ->
        let text =
          Printf.sprintf "%s is used %s, in the case for %s" (describe var) here
            (op_name clause.op)
        in
        in_span_order
          (declared_label clause.op clause.signature_at
           :: binding_labels var (Some bound_at)
          @ lock_labels p locks
          @ [ label use.at text ])
    | Reason.Rec_capture { var; bound_at; f; defined_at; locks } ->
        let text =
          Printf.sprintf "%s is used %s, in the body of %s" (describe var) here
            (describe f)
        in
        in_span_order
          (binding_labels var (Some bound_at)
          @ rec_capture_labels p f defined_at locks
          @ [ label use.at text ])
    | _ -> []

  (** The related places a reason contributes: where a variable was bound, where
      grades accumulated since, where an operation was declared, and the chain
      of definitions a scheme's atom came through. *)
  let rec labels_of_reason p (reason : C.reason) =
    match reason.why with
    | Reason.Use_under_locks { var; bound_at; locks } ->
        in_span_order (binding_labels var (Some bound_at) @ lock_labels p locks)
    | Reason.Unboxed { var; bound_at; locks } ->
        in_span_order (binding_labels var bound_at @ lock_labels p locks)
    | Reason.Op_case_capture { var; bound_at; clause; locks } ->
        in_span_order
          (declared_label clause.op clause.signature_at
           :: binding_labels var (Some bound_at)
          @ lock_labels p locks)
    | Reason.Rec_capture { var; bound_at; f; defined_at; locks } ->
        in_span_order
          (binding_labels var (Some bound_at)
          @ rec_capture_labels p f defined_at locks)
    | Reason.Instance_of { var; defined_at; inner } ->
        let definition =
          match defined_at with
          | None -> []
          | Some at -> [ label at (describe var ^ " is defined " ^ here) ]
        in
        let rest =
          match inner.why with
          | Reason.Use_under_locks _ | Reason.Op_case_capture _
          | Reason.Rec_capture _ ->
              use_labels p inner
          | _ -> labels_of_reason p inner
        in
        definition @ rest
    | Reason.Handler_case { op; signature_at }
    | Reason.Continuation_grade { op; signature_at }
    | Reason.Perform_argument { op; signature_at }
    | Reason.Perform_continuation { op; signature_at }
    | Reason.Default_of { op; signature_at } ->
        [ declared_label op signature_at ]
    | Reason.Application _ | Reason.Match_scrutinee _ | Reason.Match_branch
    | Reason.Annotation | Reason.Pattern_annotation | Reason.Variant_argument _
    | Reason.Successor_pattern | Reason.Boxed_value | Reason.Handle_with
    | Reason.Handled_computation | Reason.Return_clause
    | Reason.Recursive_definition _ | Reason.Function_body
    | Reason.Function_parameter | Reason.Pure_body | Reason.Sequencing
    | Reason.Continuation_effect _ | Reason.Top_definition _
    | Reason.Top_computation | Reason.Compared_values ->
        []

  (* The construct a reason names, as "the inequality goes through" continues. *)
  let construct (reason : C.reason) =
    match reason.why with
    | Reason.Application _ -> "the application"
    | Reason.Match_scrutinee _ -> "the matched value"
    | Reason.Match_branch -> "the branch"
    | Reason.Annotation | Reason.Pattern_annotation -> "the annotation"
    | Reason.Variant_argument lbl -> "the argument of " ^ label_name lbl
    | Reason.Successor_pattern -> "the successor pattern"
    | Reason.Boxed_value -> "the box"
    | Reason.Unboxed { var; _ } -> "the unboxing of " ^ describe var
    | Reason.Use_under_locks { var; _ }
    | Reason.Op_case_capture { var; _ }
    | Reason.Rec_capture { var; _ } ->
        "the use of " ^ describe var
    | Reason.Instance_of { var; _ } -> "the type of " ^ describe var
    | Reason.Handler_case { op; _ } | Reason.Continuation_grade { op; _ } ->
        "the case for " ^ op_name op
    | Reason.Perform_argument { op; _ } | Reason.Perform_continuation { op; _ }
      ->
        "the call of " ^ op_name op
    | Reason.Handle_with -> "the handler"
    | Reason.Handled_computation -> "the handled computation"
    | Reason.Return_clause -> "the return clause"
    | Reason.Recursive_definition f -> "the definition of " ^ describe f
    | Reason.Function_body | Reason.Pure_body -> "the function body"
    | Reason.Function_parameter -> "the parameter"
    | Reason.Sequencing | Reason.Continuation_effect _ -> "the computation"
    | Reason.Default_of { op; _ } ->
        "the default implementation of " ^ op_name op
    | Reason.Top_definition x -> "the definition of " ^ describe x
    | Reason.Top_computation -> "the computation"
    | Reason.Compared_values -> "the comparison"

  (* Whether a link of a chain of orderings is a source of grades: a type
     stated or inferred elsewhere, rather than a construct passing a grade
     on. *)
  let is_source (r : C.reason) =
    match r.why with
    | Reason.Instance_of _ | Reason.Annotation | Reason.Pattern_annotation
    | Reason.Boxed_value | Reason.Default_of _ | Reason.Handler_case _
    | Reason.Continuation_grade _ | Reason.Perform_argument _
    | Reason.Perform_continuation _ | Reason.Unboxed _
    | Reason.Use_under_locks _ | Reason.Op_case_capture _ | Reason.Rec_capture _
    | Reason.Variant_argument _ ->
        true
    | Reason.Application _ | Reason.Match_scrutinee _ | Reason.Match_branch
    | Reason.Successor_pattern | Reason.Handle_with | Reason.Handled_computation
    | Reason.Return_clause | Reason.Recursive_definition _
    | Reason.Function_body | Reason.Function_parameter | Reason.Pure_body
    | Reason.Sequencing | Reason.Continuation_effect _ | Reason.Top_definition _
    | Reason.Top_computation | Reason.Compared_values ->
        false

  (* The sources along a chain of orderings other than the places already
     pointed at. *)
  let chain_labels ~primary ~labels reasons =
    let pointed_at at =
      Location.equal at primary
      || List.exists
           (fun (l : Diagnostic.label) -> Location.equal l.span at)
           labels
    in
    List.fold_left
      (fun acc (r : C.reason) ->
        if
          (not (is_source r))
          || pointed_at r.at
          || List.exists
               (fun (l : Diagnostic.label) -> Location.equal l.span r.at)
               acc
        then acc
        else
          acc
          @ [
              label r.at
                (Printf.sprintf "the inequality goes through %s %s"
                   (construct r) here);
            ])
      [] reasons

  let dedup labels =
    List.fold_left
      (fun acc (l : Diagnostic.label) ->
        if
          List.exists
            (fun (l' : Diagnostic.label) ->
              Location.equal l.span l'.span && l.text = l'.text)
            acc
        then acc
        else acc @ [ l ])
      [] labels

  (* ------------------------------------------------------------------ *)
  (* Solutions without the failing atoms                                 *)
  (* ------------------------------------------------------------------ *)

  let erase (r : C.reason) =
    Reason.map_grades
      (fun _ -> ())
      (fun _ -> ())
      { r with path = []; stated = None }

  let rec is_prefix path path' =
    match (path, path') with
    | [], _ -> true
    | step :: path, step' :: path' -> step = step' && is_prefix path path'
    | _ :: _, [] -> false

  (* Whether an atom of reason [r] is one [failing] was decomposed out of. *)
  let generated_by (failing : C.reason) (r : C.reason) =
    is_prefix r.path failing.path && erase r = erase failing

  let rec atoms = function
    | C.True -> []
    | C.And (c, d) -> atoms c @ atoms d
    | C.Exists (_, c) | C.Forall_eps (_, _, c) -> atoms c
    | (C.Sub _ | C.Rho_leq _ | C.Eps_leq _ | C.Eternal _ | C.Eternal_or_unit _)
      as atom ->
        [ atom ]

  let rec drop dropped = function
    | C.And (c, d) -> C.conj (drop dropped c) (drop dropped d)
    | C.Exists (vs, c) -> C.Exists (vs, drop dropped c)
    | C.Forall_eps (rigid, origin, c) ->
        C.Forall_eps (rigid, origin, drop dropped c)
    | c -> if dropped c then C.True else c

  (* An instance of a solution as a message shows it: its grade unknowns given
     their values in the search for a closed instance of its qualifier
     ({!instance_values}). *)
  let instance context (solution : S.solution) =
    let values = instance_values context solution in
    fun ty ->
      C.subst_ty
        { C.empty_subst with grade_subst = values }
        (C.subst_ty solution.subst ty)

  (* The types of a solution of the constraint without the atoms [dropped],
     when it has one. *)
  let without source dropped =
    Option.bind source.constr (fun c ->
        match S.solve source.context (drop dropped c) with
        | S.Solved solution -> Some (instance source.context solution)
        | S.Refuted _ | S.Stuck _ -> None)

  (* The type of the var-rule atom of [reason], in a solution without it. *)
  let disjunction_ty source (reason : C.reason) =
    let is_disjunction = function
      | C.Eternal_or_unit (r, _, _) -> generated_by reason r
      | _ -> false
    in
    Option.bind source.constr (fun c ->
        match List.find_opt is_disjunction (atoms c) with
        | Some (C.Eternal_or_unit (_, ty, _)) ->
            Option.map
              (fun resolve -> resolve ty)
              (without source is_disjunction)
        | Some _ | None -> None)

  (* The subtyping atoms a failing atom of reason [reason] was decomposed out
     of, those of the longest path, and the types of a solution without
     them. *)
  let root source (reason : C.reason) =
    Option.bind source.constr (fun c ->
        let subs =
          List.filter_map
            (function
              | C.Sub (r, a, b) when generated_by reason r -> Some (r, a, b)
              | _ -> None)
            (atoms c)
        in
        let longest =
          List.fold_left
            (fun n ((r : C.reason), _, _) -> max n (List.length r.path))
            (-1) subs
        in
        match
          List.filter
            (fun ((r : C.reason), _, _) -> List.length r.path = longest)
            subs
        with
        | [] -> None
        | (r, a, b) :: _ as roots ->
            let dropped = function
              | C.Sub (r', _, _) ->
                  List.exists (fun (r'', _, _) -> r'' == r') roots
              | _ -> false
            in
            Option.map
              (fun resolve -> (r, resolve a, resolve b, resolve))
              (without source dropped))

  (* The sides of the generated atom of the function of an application. *)
  let function_atom source (reason : C.reason) ~func_at =
    let generated = erase { reason with subject = Some func_at } in
    Option.bind source.constr (fun c ->
        List.find_map
          (function
            | C.Sub (r, a, b) when r.path = [] && erase r = generated ->
                Some (a, b)
            | _ -> None)
          (atoms c))

  (* The type of the function of an application, from its generated atom. *)
  let function_ty source resolve reason ~func_at =
    Option.map (fun (a, _) -> resolve a) (function_atom source reason ~func_at)

  (* ------------------------------------------------------------------ *)
  (* Type mismatches                                                     *)
  (* ------------------------------------------------------------------ *)

  let step_of_skeleton : Ast.step -> Reason.step = function
    | Ast.Argument -> Reason.Argument
    | Ast.Result -> Reason.Result
    | Ast.Component i -> Reason.Component i
    | Ast.TypeArgument i -> Reason.Type_argument i
    | Ast.BoxContent -> Reason.Box_content
    | Ast.HandlerInput -> Reason.Handler_input
    | Ast.HandlerOutput -> Reason.Handler_output

  (* The steps of a path the solver took, after those the generation took. *)
  let solver_steps (reason : C.reason) path =
    match (reason.why, path) with
    | (Reason.Application _ | Reason.Default_of _), _ :: path -> path
    | _, path -> path

  (* Whether the sides of an atom at [path] are the other way round from the
     subject's and the expected type's: under an odd number of function
     domains. *)
  let flipped reason path =
    List.length (List.filter (( = ) Reason.Argument) (solver_steps reason path))
    mod 2
    = 1

  (** The sentence of a mismatch between the type [o] the subject offers and the
      type [e] expected, by the construct that relates them. *)
  let mismatch_message ~(reason : C.reason) ~path ~o ~e ~non_box =
    let at = reason.at in
    let generic = Printf.sprintf "Type %s is not compatible with type %s" o e in
    match (reason.why, path) with
    | Reason.Application { func_at; _ }, [] ->
        ( func_at,
          Printf.sprintf "This expression has type %s and cannot be applied" o
        )
    | Reason.Application { arg_at; _ }, Reason.Argument :: _ ->
        ( arg_at,
          Printf.sprintf "This argument has type %s but the function expects %s"
            o e )
    | Reason.Application _, Reason.Result :: _ ->
        ( at,
          Printf.sprintf "The application has type %s but %s is expected here" o
            e )
    | Reason.Match_scrutinee { scrutinee_at }, _
      when Location.equal at scrutinee_at ->
        ( at,
          Printf.sprintf
            "This expression has type %s but the patterns match values of type \
             %s"
            o e )
    | Reason.Match_scrutinee _, _ ->
        ( at,
          Printf.sprintf
            "This pattern matches values of type %s but the matched value has \
             type %s"
            e o )
    | Reason.Match_branch, _ ->
        ( at,
          Printf.sprintf
            "This branch has type %s but the other branches have type %s" o e )
    | Reason.Annotation, _ ->
        ( at,
          Printf.sprintf "This expression has type %s but is annotated with %s"
            o e )
    | Reason.Pattern_annotation, _ ->
        ( at,
          Printf.sprintf "This pattern has type %s but is annotated with %s" o e
        )
    | Reason.Variant_argument lbl, _ ->
        ( at,
          Printf.sprintf
            "Constructor %s expects an argument of type %s but is given %s"
            (label_name lbl) e o )
    | Reason.Successor_pattern, _ ->
        ( at,
          Printf.sprintf
            "This pattern matches values of type %s but, as the argument of a \
             successor pattern, is given values of type %s"
            e o )
    | Reason.Boxed_value, _ ->
        (at, Printf.sprintf "The boxed value has type %s but is bound as %s" o e)
    | Reason.Unboxed { var; _ }, [] ->
        ( at,
          Printf.sprintf
            "%s has type %s, which is not a boxed type, and cannot be unboxed"
            (subject var) non_box )
    | Reason.Unboxed { var; _ }, _ ->
        ( at,
          Printf.sprintf "%s holds a value of type %s but it is bound as %s"
            (holder var) o e )
    | Reason.Perform_argument { op; _ }, _ ->
        ( at,
          Printf.sprintf
            "Operation %s takes an argument of type %s but is given %s"
            (op_name op) e o )
    | Reason.Perform_continuation { op; _ }, _ ->
        ( at,
          Printf.sprintf
            "The result of %s has type %s but the continuation binds it as %s"
            (op_name op) o e )
    | Reason.Handler_case { op; _ }, Reason.Component 1 :: _ ->
        ( at,
          Printf.sprintf
            "The argument of %s has type %s but the case binds it as %s"
            (op_name op) o e )
    | Reason.Handler_case { op; _ }, Reason.Component 2 :: _ ->
        ( at,
          Printf.sprintf
            "The continuation of %s has type %s but the case binds it as %s"
            (op_name op) o e )
    | Reason.Handler_case { op; _ }, [] ->
        ( at,
          Printf.sprintf
            "The case for %s returns %s but the return clause returns %s"
            (op_name op) o e )
    | Reason.Handle_with, [] ->
        (at, Printf.sprintf "This expression has type %s and is not a handler" o)
    | Reason.Handle_with, Reason.Handler_input :: _ ->
        ( at,
          Printf.sprintf
            "This handler handles computations of type %s but the handled \
             computation has type %s"
            o e )
    | Reason.Handle_with, Reason.Handler_output :: _ ->
        ( at,
          Printf.sprintf
            "This handler returns values of type %s but %s is expected here" o e
        )
    | Reason.Handled_computation, _ ->
        ( at,
          Printf.sprintf
            "The handled computation has type %s but the handler handles \
             computations of type %s"
            o e )
    | Reason.Return_clause, _ ->
        ( at,
          Printf.sprintf
            "The return clause has type %s but the handler's result has type %s"
            o e )
    | Reason.Recursive_definition f, _ ->
        ( at,
          Printf.sprintf
            "The body of the recursive function %s has type %s but %s is used \
             as returning %s"
            (describe f) o (describe f) e )
    | Reason.Default_of { op; _ }, Reason.Argument :: _ ->
        let op = op_name op in
        ( at,
          Printf.sprintf
            "The default implementation of %s binds its argument as %s but %s \
             takes %s"
            op e op o )
    | Reason.Default_of { op; _ }, Reason.Result :: _ ->
        let op = op_name op in
        ( at,
          Printf.sprintf
            "The default implementation of %s returns %s but %s returns %s" op o
            op e )
    | Reason.Instance_of { var; _ }, _ ->
        ( at,
          Printf.sprintf "%s, as the type of %s requires" generic (describe var)
        )
    | _ -> (at, generic)

  (* Whether the construct of [reason] words a mismatch between whole types,
     rather than a shape alone or no construct in particular. *)
  let words_types (reason : C.reason) path =
    match (reason.why, path) with
    | (Reason.Application _ | Reason.Handle_with | Reason.Unboxed _), [] ->
        false
    | Reason.Application _, (Reason.Argument | Reason.Result) :: _
    | Reason.Handler_case _, ([] | Reason.Component (1 | 2) :: _)
    | Reason.Handle_with, (Reason.Handler_input | Reason.Handler_output) :: _
    | Reason.Default_of _, (Reason.Argument | Reason.Result) :: _ ->
        true
    | ( ( Reason.Match_scrutinee _ | Reason.Match_branch | Reason.Annotation
        | Reason.Pattern_annotation | Reason.Variant_argument _
        | Reason.Successor_pattern | Reason.Boxed_value | Reason.Unboxed _
        | Reason.Perform_argument _ | Reason.Perform_continuation _
        | Reason.Handled_computation | Reason.Return_clause
        | Reason.Recursive_definition _ ),
        _ ) ->
        true
    | _ -> false

  (* The sides of a subtyping atom one step down: the argument's type and the
     function's domain, or the two results. *)
  let descend step (a, b) =
    match (step, a, b) with
    | Reason.Argument, Ast.TyArrow (a, _), Ast.TyArrow (b, _) -> Some (b, a)
    | ( Reason.Result,
        Ast.TyArrow (_, Ast.CompTy (a, _)),
        Ast.TyArrow (_, Ast.CompTy (b, _)) ) ->
        Some (a, b)
    | _ -> None

  (* The path and sides at which the construct of the atom [root], generated
     with sides [sides], words a mismatch within it at [path]: its own, or
     one step down. *)
  let worded (root : C.reason) path sides =
    if words_types root root.path then Some (root.path, sides)
    else
      match List.filteri (fun i _ -> i >= List.length root.path) path with
      | step :: _ when words_types root (root.path @ [ step ]) ->
          Option.map
            (fun sides -> (root.path @ [ step ], sides))
            (descend step sides)
      | _ -> None

  (* The provenance of the failed expansion [f], as solving recorded it. *)
  let recorded source (f : C.reason Skeleton.failure) =
    match source.mismatch with
    | Some (m : S.mismatch) when m.atom.info == f.info -> Some m
    | Some _ | None -> None

  (* A label at the place each part [shown] of a mismatch was decided, other
     than the construct [at] of the failing atom and the places already
     pointed at. *)
  let decided_labels ~primary ~at ~labels sides =
    List.fold_left
      (fun acc (shown, decision) ->
        match decision with
        | Some (d : S.decision)
          when not
                 (Location.equal d.reason.at primary
                 || Location.equal d.reason.at at
                 || List.exists
                      (fun (l : Diagnostic.label) ->
                        Location.equal l.span d.reason.at)
                      (labels @ acc)) ->
            acc @ [ label d.reason.at (shown ^ " was inferred " ^ here) ]
        | Some _ | None -> acc)
      [] sides

  (* The application of a function to an argument as one subtyping: the
     function's type against the argument's type to the result. *)
  let application_root source resolve (reason : C.reason) ~func_at arg_ty =
    match function_atom source reason ~func_at with
    | Some (func_ty, Ast.TyArrow (_, result)) ->
        Some (resolve func_ty, Ast.TyArrow (arg_ty, result))
    | Some _ | None -> None

  let mismatch source (f : C.reason Skeleton.failure) =
    let p = printer source in
    let reason = f.info in
    let path = reason.path @ List.map step_of_skeleton f.path in
    let root = root source reason in
    let flipped = flipped reason path in
    let lhs, rhs = if flipped then (f.rhs, f.lhs) else (f.lhs, f.rhs) in
    let recorded = recorded source f in
    let lhs_decided, rhs_decided =
      match recorded with
      | Some m when flipped -> (m.rhs_decided, m.lhs_decided)
      | Some m -> (m.lhs_decided, m.rhs_decided)
      | None -> (None, None)
    in
    let message =
      match f.mismatch with
      | Skeleton.Occurs a ->
          let other =
            match f.lhs with
            | Skeleton.Var b when Ast.TyParamModule.compare a b = 0 -> f.rhs
            | _ -> f.lhs
          in
          let a = skeleton_raw p (Skeleton.Var a) in
          let other = skeleton_raw p other in
          ( reason.at,
            "Cannot construct the infinite type " ^ code (a ^ " = " ^ other) )
      | Skeleton.Clash ->
          let o = code (skeleton_raw p lhs) in
          let e = code (skeleton_raw p rhs) in
          let non_box =
            match f.lhs with
            | Skeleton.Box _ -> e
            | _ -> code (skeleton_raw p f.lhs)
          in
          mismatch_message ~reason ~path ~o ~e ~non_box
    in
    let primary, message = message in
    let function_label =
      match (reason.why, path, root) with
      | ( Reason.Application { func_at; _ },
          Reason.Argument :: _,
          Some (_, _, _, resolve) ) -> (
          match function_ty source resolve reason ~func_at with
          | Some ty ->
              [ label func_at ("the function has type " ^ ty_code p ty) ]
          | None -> [])
      | _ -> []
    in
    let scrutinee_label =
      match (reason.why, root) with
      | Reason.Match_scrutinee { scrutinee_at }, Some (_, a, _, _)
        when not (Location.equal reason.at scrutinee_at) ->
          [ label scrutinee_at ("the matched value has type " ^ ty_code p a) ]
      | _ -> []
    in
    let labels =
      dedup
        (with_rigid_labels p
           (mentioned_rigids source [ reason ])
           (function_label @ scrutinee_label @ labels_of_reason p reason))
    in
    let labels =
      labels
      @ decided_labels ~primary ~at:reason.at ~labels
          [
            (code (skeleton_raw p lhs), lhs_decided);
            (code (skeleton_raw p rhs), rhs_decided);
          ]
    in
    let matching (a, b) =
      [
        Printf.sprintf "while matching %s against %s" (ty_code p a)
          (ty_code p b);
      ]
    in
    let notes =
      match (reason.why, reason.path, root) with
      | ( Reason.Application { func_at; _ },
          Reason.Argument :: _,
          Some (_, a, _, resolve) ) ->
          Option.fold ~none:[] ~some:matching
            (application_root source resolve reason ~func_at a)
      | _, _, Some ((r : C.reason), a, b, _)
        when List.length r.path < List.length path ->
          matching (a, b)
      | _, _, None when f.path <> [] ->
          Option.fold ~none:[]
            ~some:(fun (m : S.mismatch) -> matching (m.atom.lhs, m.atom.rhs))
            recorded
      | _, _, (Some _ | None) -> []
    in
    diagnostic ~primary ~labels ~notes message

  (* ------------------------------------------------------------------ *)
  (* Eternality                                                          *)
  (* ------------------------------------------------------------------ *)

  (* An obligation inherited from a definition: the headline names the
     definition and what it needs eternal. *)
  let instance_eternal ty var inner =
    match (use_of inner, ty) with
    | ( Some
          {
            why =
              ( Reason.Use_under_locks { var = x; _ }
              | Reason.Op_case_capture { var = x; _ }
              | Reason.Rec_capture { var = x; _ } );
            _;
          },
        Some t ) ->
        Printf.sprintf "%s is not eternal, but %s needs %s to be eternal" t
          (describe var) (needed_eternal x)
    | ( Some
          {
            why =
              ( Reason.Use_under_locks { var = x; _ }
              | Reason.Op_case_capture { var = x; _ }
              | Reason.Rec_capture { var = x; _ } );
            _;
          },
        None ) ->
        Printf.sprintf "%s needs %s to be eternal, but it is not here"
          (String.capitalize_ascii (describe var))
          (needed_eternal x)
    | _, Some t ->
        Printf.sprintf "Type %s is not eternal, as required by the type of %s" t
          (describe var)
    | _, None ->
        Printf.sprintf "A type is not eternal, as required by the type of %s"
          (describe var)

  let box_note = function
    | Some (Ast.TyBox _) -> [ "a box type is never eternal" ]
    | _ -> []

  (* The case a capture crosses into runs with a grade the handler does not
     fix; the body of a recursive function may run at any later time. *)
  let capture_message var into t =
    let into =
      match into with
      | `Clause (clause : Reason.clause) ->
          Printf.sprintf
            "the case for %s: the case runs with a grade the handler does not \
             fix"
            (op_name clause.op)
      | `Recursive f ->
          Printf.sprintf
            "the body of the recursive function %s, which may run at any later \
             time"
            (describe f)
    in
    match t with
    | Some t ->
        Printf.sprintf
          "%s has type %s, which is not eternal, so it cannot be used in %s"
          (subject var) t into
    | None ->
        Printf.sprintf
          "%s does not have an eternal type, so it cannot be used in %s"
          (subject var) into

  let never_eternal source ty (reason : C.reason) =
    let p = printer source in
    let t = ty_code p ty in
    let message =
      match reason.why with
      | Reason.Use_under_locks { var; _ } ->
          Printf.sprintf
            "%s has type %s, which is not eternal, but is used with a grade \
             accumulated since it was bound that only an eternal type allows"
            (subject var) t
      | Reason.Op_case_capture { var; clause; _ } ->
          capture_message var (`Clause clause) (Some t)
      | Reason.Rec_capture { var; f; _ } ->
          capture_message var (`Recursive f) (Some t)
      | Reason.Instance_of { var; inner; _ } ->
          instance_eternal (Some t) var inner
      | _ -> Printf.sprintf "Type %s is not eternal" t
    in
    diagnostic ~primary:reason.at
      ~labels:
        (dedup
           (with_rigid_labels p
              (mentioned_rigids source [ reason ])
              (labels_of_reason p reason)))
      ~notes:(box_note (Some ty)) message

  (* ------------------------------------------------------------------ *)
  (* Orderings                                                           *)
  (* ------------------------------------------------------------------ *)

  (* Whether a reason names the promise an ordering breaks. *)
  let specific (r : C.reason) =
    match r.why with
    | Reason.Unboxed _ | Reason.Use_under_locks _ | Reason.Op_case_capture _
    | Reason.Rec_capture _ | Reason.Instance_of _ | Reason.Continuation_grade _
    | Reason.Default_of _ ->
        true
    | Reason.Annotation -> r.path = [ Reason.Effect ]
    | _ -> false

  (* The reason a headline is built on: the first that names a promise, else
     the last, which set the bound. *)
  let principal reasons =
    match List.find_opt specific reasons with
    | Some r -> r
    | None -> List.nth reasons (List.length reasons - 1)

  (* A grade shown in a headline: [preferred] when it is variable-free or
     quantified over rigids only, [fallback] otherwise. *)
  let shown_rho f preferred fallback =
    let rigid_vars = List.map (fun r -> r.var) f.rigids in
    if
      X.Rho_var.Set.is_empty (X.Rho.free_rho_vars preferred)
      && X.Eps_var.Set.for_all
           (fun e -> List.exists (X.Eps_var.equal e) rigid_vars)
           (X.Rho.free_eps_vars preferred)
    then preferred
    else fallback

  (* The failing ordering of a use or an unboxing, at the grade [total]
     accumulated since the binding where it alone fails. *)
  let at_accumulated p (f : C.rho refutation) total =
    match (f.rigids, N.Rho.closed_leq p.bounds total (snd f.instance)) with
    | [], Some false ->
        {
          f with
          stated = (total, snd f.stated);
          instance = (total, snd f.instance);
        }
    | _, (Some _ | None) -> f

  (* The headline, notes and labels of a failing ordering, by the reason it is
     built on. *)
  let ordering_message (type e) source p (f : e refutation) reason ~ty =
    let s1, s2 = f.stated in
    let g side = code (f.sort.raw p side) in
    let rs = f.rigids in
    match (reason.Reason.why, f.sort.tag) with
    | Reason.Use_under_locks { var; locks; _ }, Rho_tag ->
        let total = shown_rho f (accumulated_grade locks) (fst f.instance) in
        let f = at_accumulated p f total in
        let total = rho_code p total in
        let message =
          match Option.map (ty_code p) ty with
          | Some t ->
              Printf.sprintf
                "%s is used with grade %s accumulated since it was bound, but \
                 its type %s is not eternal"
                (subject var) total t
          | None ->
              Printf.sprintf
                "%s is used with grade %s accumulated since it was bound, but \
                 its type is not eternal"
                (subject var) total
        in
        (reason.at, message, ineq_notes p f)
    | Reason.Op_case_capture { var; clause; _ }, _ ->
        let message =
          capture_message var (`Clause clause) (Option.map (ty_code p) ty)
        in
        (reason.at, message, box_note ty @ ineq_notes p f)
    | Reason.Rec_capture { var; f = g; _ }, _ ->
        let message =
          capture_message var (`Recursive g) (Option.map (ty_code p) ty)
        in
        (reason.at, message, box_note ty @ ineq_notes p f)
    | Reason.Instance_of { var; inner; _ }, _ when Option.is_some (use_of inner)
      ->
        let t = Option.map (ty_code p) ty in
        (reason.at, instance_eternal t var inner, ineq_notes p f)
    | Reason.Unboxed { var; locks; _ }, Rho_tag ->
        let total = shown_rho f (accumulated_grade locks) (fst f.instance) in
        let f = at_accumulated p f total in
        let unit_word = if is_unit_rho p total then "the unit " else "" in
        let message =
          Printf.sprintf
            "%s is unboxed with %sgrade %s accumulated since it was bound, \
             which is not below its box grade %s"
            (subject var) unit_word (rho_code p total) (g s2)
        in
        (reason.at, message, ineq_notes p f)
    | Reason.Continuation_grade { op; _ }, _ when rs <> [] ->
        let quantifier = String.capitalize_ascii (for_every p rs) in
        let g2 = g s2 in
        let g1 = g s1 in
        ( reason.at,
          Printf.sprintf
            "%s, the case for %s must have a grade matching %s, but its grade \
             %s does not"
            quantifier (op_name op) g2 g1,
          ineq_notes p f )
    | Reason.Continuation_grade { op; _ }, _ ->
        let g1 = g s1 in
        let g2 = g s2 in
        ( reason.at,
          Printf.sprintf
            "The case for %s has grade %s, which does not match the grade %s \
             of %s followed by its continuation"
            (op_name op) g1 g2 (op_name op),
          ineq_notes p f )
    | Reason.Default_of { op; _ }, _ ->
        let g1 = g s1 in
        let g2 = g s2 in
        ( reason.at,
          Printf.sprintf
            "The default implementation of %s has grade %s, which does not \
             match the declared grade %s of %s"
            (op_name op) g1 g2 (op_name op),
          ineq_notes p f )
    | Reason.Annotation, _ when specific reason ->
        let g1 = g s1 in
        let g2 = g s2 in
        ( reason.at,
          Printf.sprintf
            "This function's body has grade %s, which does not match its \
             annotated grade %s"
            g1 g2,
          ineq_notes p f )
    | _ -> (
        let inequality =
          Printf.sprintf "The %s inequality %s does not hold" f.sort.noun
            (quantified p rs (ineq_text p f.sort f.stated))
        in
        let witness =
          if rs = [] then counterexample_notes p f else ineq_notes p f
        in
        match root source reason with
        | Some ((r : C.reason), a, b, _)
          when List.length r.path < List.length reason.path -> (
            match worded r reason.path (a, b) with
            | Some (path, (a, b)) ->
                let o = ty_code p a in
                let e = ty_code p b in
                let primary, message =
                  mismatch_message ~reason:r ~path ~o ~e ~non_box:e
                in
                (primary, message, ineq_notes p f)
            | None ->
                let o = ty_code p a in
                let e = ty_code p b in
                ( reason.at,
                  inequality,
                  Printf.sprintf "while matching %s against %s" o e :: witness
                ))
        | Some _ | None -> (reason.at, inequality, witness))

  let refuted_ordering source p f =
    let reason = principal f.reasons in
    let ty =
      match use_of reason with
      | Some _ -> disjunction_ty source reason
      | None -> None
    in
    let primary, message, notes = ordering_message source p f reason ~ty in
    let labels = labels_of_reason p reason in
    let labels =
      labels
      @ chain_labels ~primary ~labels
          (List.filter (fun r -> r != reason) f.reasons)
    in
    let rigids =
      union_rigids f.rigids
        (union_rigids
           (mentioned_rigids source [ reason ])
           (ty_rigids source ty))
    in
    diagnostic ~primary
      ~labels:(dedup (with_rigid_labels p rigids labels))
      ~notes message

  (* The rigids a rewritten ordering was stated with, each at the value the
     rewriting gave it: the top where it stood on the left, the unit on the
     right. *)
  let restated source sort
      (o : ('e, C.reason list) Inference.GradeNormal.ordering) =
    let reason = principal o.info in
    match sort.stated_of reason with
    | None -> ((o.lhs, o.rhs), [])
    | Some (lhs, rhs) -> (
        let instance =
          X.Eps_var.Set.union (sort.eps_vars o.lhs) (sort.eps_vars o.rhs)
        in
        let vars =
          X.Eps_var.Set.diff
            (X.Eps_var.Set.union (sort.eps_vars lhs) (sort.eps_vars rhs))
            instance
        in
        let value var =
          if X.Eps_var.Set.mem var (sort.eps_vars lhs) then GS.E.top
          else GS.E.one
        in
        match rigids_of source vars ~value with
        | [] -> ((o.lhs, o.rhs), [])
        | rs -> ((lhs, rhs), rs))

  (* The hypotheses an ordering of reason [reason] was bounded by, transitively
     through the unknowns of its left side ([`Below]) or of its right side
     ([`Above]), the farthest first. *)
  let bounds sort hyps (o : ('e, C.reason) Inference.GradeNormal.ordering)
      direction =
    let rec go depth frontier seen =
      if depth = 0 then []
      else
        let links =
          List.filter
            (fun (h : ('e, C.reason) Inference.GradeNormal.ordering) ->
              (not (List.memq h seen))
              &&
              match direction with
              | `Below -> sort.shares h.rhs frontier
              | `Above -> sort.shares h.lhs frontier)
            hyps
        in
        List.concat_map
          (fun (h : ('e, C.reason) Inference.GradeNormal.ordering) ->
            let next =
              match direction with `Below -> h.lhs | `Above -> h.rhs
            in
            go (depth - 1) next (links @ seen) @ [ h.info ])
          links
    in
    let start = match direction with `Below -> o.lhs | `Above -> o.rhs in
    go 4 start [ o ]

  (* The reasons of an ordering refuted in the search for a closed instance,
     completed by those of the hypotheses that gave its unknowns their
     values. *)
  let completed source sort
      (o : ('e, C.reason list) Inference.GradeNormal.ordering) =
    match
      (Option.map (fun (s : S.solution) -> s.hyps) source.solution, o.info)
    with
    | Some hyps, [ reason ] -> (
        let hyps = sort.hyps_of hyps in
        match
          List.find_opt
            (fun (h : ('e, C.reason) Inference.GradeNormal.ordering) ->
              h.info.path = reason.path && erase h.info = erase reason)
            hyps
        with
        | Some h ->
            bounds sort hyps h `Below @ [ reason ]
            @ List.rev (bounds sort hyps h `Above)
        | None -> o.info)
    | Some _, ([] | _ :: _ :: _) | None, _ -> o.info

  let refuted_orderings source sort o =
    let p = printer source in
    let stated, rigids = restated source sort o in
    refuted_ordering source p
      {
        sort;
        stated;
        instance = (o.lhs, o.rhs);
        rigids;
        reasons = completed source sort o;
      }

  let refuted_condition source (d : R.deferred) witness =
    let p = printer source in
    let values = List.combine (List.map fst d.rigids) witness in
    let rigids =
      rigids_of source
        (X.Eps_var.Set.of_list (List.map fst d.rigids))
        ~value:(fun var -> List.assoc var values)
    in
    let at_witness : X.subst =
      {
        X.empty_subst with
        eps_subst =
          List.fold_left
            (fun m (var, c) -> X.Eps_var.Map.add var (X.Eps.const c) m)
            X.Eps_var.Map.empty values;
      }
    in
    let refute : type e.
        e sort -> (e, C.reason) Inference.GradeNormal.ordering -> _ =
     fun sort o ->
      refuted_ordering source p
        {
          sort;
          stated = (o.lhs, o.rhs);
          instance = (sort.subst at_witness o.lhs, sort.subst at_witness o.rhs);
          rigids;
          reasons = [ o.info ];
        }
    in
    match (d.rho_conditions, d.eps_conditions) with
    | o :: _, _ -> refute rho_sort o
    | [], o :: _ -> refute eps_sort o
    | [], [] ->
        diagnostic ~primary:d.origin.clause.case_at ~labels:[] ~notes:[]
          (Printf.sprintf
             "The case for %s cannot be typed for every grade of %s"
             (op_name d.origin.clause.op)
             (continuation_phrase d.origin))

  (* ------------------------------------------------------------------ *)
  (* Continuation grades out of their clause                             *)
  (* ------------------------------------------------------------------ *)

  let rigid_escape source (origin : Reason.rigid_origin) =
    let p = printer source in
    let rs =
      match source.constr with
      | Some c ->
          List.filter_map
            (fun (var, o) ->
              if o = origin then Some { var; origin; value = GS.E.top }
              else None)
            (rigid_origins c)
      | None -> []
    in
    let grade =
      match rs with r :: _ -> " " ^ code (rigid_raw p r) | [] -> ""
    in
    diagnostic ~primary:origin.clause.case_at
      ~labels:
        (declared_label origin.clause.op origin.clause.signature_at
        :: rigid_labels p rs)
      ~notes:
        [
          "a type inferred outside the case would depend on the continuation's \
           grade";
        ]
      (Printf.sprintf
         "The grade%s of %s in the case for %s may be any grade, so it cannot \
          occur in a type outside the case"
         grade
         (continuation_phrase origin)
         (op_name origin.clause.op))

  (* A condition of a run that is neither discharged nor refuted, reported
     at its first ordering. *)
  let undecided_condition source (d : R.deferred) =
    let p = printer source in
    let origin = d.origin in
    let report (type e) (sort : e sort)
        (o : (e, C.reason) Inference.GradeNormal.ordering) =
      let mentioned =
        X.Eps_var.Set.union (sort.eps_vars o.lhs) (sort.eps_vars o.rhs)
      in
      let rs =
        List.filter_map
          (fun (var, origin) ->
            if X.Eps_var.Set.mem var mentioned then
              Some { var; origin; value = GS.E.top }
            else None)
          d.rigids
      in
      diagnostic ~primary:o.info.at
        ~labels:
          (dedup
             (labels_of_reason p o.info @ rigid_labels p rs
             @ [
                 label origin.clause.case_at
                   (Printf.sprintf "the case for %s begins %s"
                      (op_name origin.clause.op) here);
               ]))
        ~notes:
          [
            Printf.sprintf
              "a run requires the %s inequality to hold for every grade %s may \
               have, and it is neither derived nor refuted"
              sort.noun
              (continuation_phrase origin);
          ]
        (Printf.sprintf
           "The condition %s of the case for %s cannot be established"
           (quantified p rs (ineq_text p sort (o.lhs, o.rhs)))
           (op_name origin.clause.op))
    in
    match (d.rho_conditions, d.eps_conditions) with
    | o :: _, _ -> report rho_sort o
    | [], o :: _ -> report eps_sort o
    | [], [] ->
        diagnostic ~primary:origin.clause.case_at ~labels:[] ~notes:[]
          (Printf.sprintf
             "The case for %s cannot be typed for every grade of %s"
             (op_name origin.clause.op)
             (continuation_phrase origin))

  (* The conditions of a run that share unknowns and hold together at none of
     the grades tried, in reading order. *)
  let unestablished ?(subject = "this run") source ~rho_orderings ~eps_orderings
      ~conditions ~abandoned =
    let p = printer source in
    let ordering (type e) (sort : e sort) rigids
        (o : (e, C.reason) Inference.GradeNormal.ordering) =
      let mentioned =
        X.Eps_var.Set.union (sort.eps_vars o.lhs) (sort.eps_vars o.rhs)
      in
      let rs =
        List.filter_map
          (fun (var, origin) ->
            if X.Eps_var.Set.mem var mentioned then
              Some { var; origin; value = GS.E.top }
            else None)
          rigids
      in
      (o.info, rs, fun () -> quantified p rs (ineq_text p sort (o.lhs, o.rhs)))
    in
    let items =
      List.map (ordering rho_sort []) rho_orderings
      @ List.map (ordering eps_sort []) eps_orderings
      @ List.concat_map
          (fun (d : R.deferred) ->
            List.map (ordering rho_sort d.rigids) d.rho_conditions
            @ List.map (ordering eps_sort d.rigids) d.eps_conditions)
          conditions
      |> List.stable_sort (fun ((r : C.reason), _, _) ((r' : C.reason), _, _) ->
          Location.compare r.at r'.at)
    in
    let texts = List.map (fun (_, _, text) -> text ()) items in
    let shown = List.take 4 texts and hidden = List.length texts - 4 in
    let listed =
      match (List.rev shown, hidden > 0) with
      | [], _ -> ""
      | [ text ], false -> text
      | last :: rest, false ->
          String.concat ", " (List.rev rest) ^ " and " ^ last
      | _, true ->
          Printf.sprintf "%s and %d more" (String.concat ", " shown) hidden
    in
    let reasons = List.map (fun (r, _, _) -> r) items in
    let rs =
      List.fold_left (fun acc (_, rs, _) -> union_rigids acc rs) [] items
    in
    let message =
      Printf.sprintf "The conditions of %s could not be established: %s" subject
        listed
    and notes =
      Printf.sprintf
        "%s requires grades for its unknowns at which every one of these \
         holds; none of the grades tried does, although the definitions they \
         come from were accepted"
        subject
      ::
      (if abandoned then
         [
           Printf.sprintf
             "the search for such grades was abandoned after %d trials"
             RS.default_budget;
         ]
       else [])
    in
    match reasons with
    | [] ->
        {
          Diagnostic.kind = Diagnostic.Typing;
          primary = None;
          message;
          labels = [];
          notes;
        }
    | (first : C.reason) :: _ ->
        let primary = first.at in
        let labels = List.concat_map (labels_of_reason p) reasons in
        let labels = labels @ chain_labels ~primary ~labels reasons in
        diagnostic ~primary
          ~labels:(dedup (with_rigid_labels p rs labels))
          ~notes message

  let refuted ?subject source = function
    | R.Shape_mismatch f | R.Occurs_check f -> mismatch source f
    | R.Refuted_rho o -> refuted_orderings source rho_sort o
    | R.Refuted_eps o -> refuted_orderings source eps_sort o
    | R.Never_eternal { ty; reason } -> never_eternal source ty reason
    | R.Refuted_condition { condition; witness } ->
        refuted_condition source condition witness
    | R.Undecided_condition condition -> undecided_condition source condition
    | R.Unestablished { rho_orderings; eps_orderings; conditions; abandoned } ->
        unestablished ?subject source ~rho_orderings ~eps_orderings ~conditions
          ~abandoned
    | R.Rigid_escape origin -> rigid_escape source origin

  (* ------------------------------------------------------------------ *)
  (* Undecided clauses                                                   *)
  (* ------------------------------------------------------------------ *)

  (* An ordering of a clause that cannot be kept outside it nor decided for
     every value of the rigids it mentions. *)
  let undecided (type e) source p (origin : Reason.rigid_origin) (sort : e sort)
      (o : (e, C.reason) Inference.GradeNormal.ordering) =
    let rs =
      rigids_of source
        (X.Eps_var.Set.union (sort.eps_vars o.lhs) (sort.eps_vars o.rhs))
        ~value:(fun _ -> GS.E.top)
    in
    let ineq = quantified p rs (ineq_text p sort (o.lhs, o.rhs)) in
    let message =
      match rs with
      | [] ->
          Printf.sprintf
            "Cannot decide the %s inequality %s for every grade %s may have"
            sort.noun ineq
            (continuation_phrase origin)
      | rs ->
          Printf.sprintf "Cannot decide the %s inequality %s %s" sort.noun ineq
            (for_every p rs)
    in
    diagnostic ~primary:o.info.at
      ~labels:
        (dedup
           (labels_of_reason p o.info @ rigid_labels p rs
           @ [
               label origin.clause.case_at
                 (Printf.sprintf "the case for %s begins %s"
                    (op_name origin.clause.op) here);
             ]))
      ~notes:
        [
          Printf.sprintf
            "it relates grades inferred inside the case for %s to the grade of \
             %s, which the case must allow to be any grade"
            (op_name origin.clause.op)
            (continuation_phrase origin);
        ]
      message

  let stuck source (s : RS.stuck) =
    let p = printer source in
    let origin = s.stuck_origin in
    match s.blocking with
    | RS.Blocking_rho o -> undecided source p origin rho_sort o
    | RS.Blocking_eps o -> undecided source p origin eps_sort o
    | RS.Blocking_deferred d -> (
        match (d.rho_conditions, d.eps_conditions) with
        | o :: _, _ -> undecided source p origin rho_sort o
        | [], o :: _ -> undecided source p origin eps_sort o
        | [], [] ->
            diagnostic ~primary:origin.clause.case_at ~labels:[] ~notes:[]
              (Printf.sprintf
                 "The case for %s cannot be typed for every grade of %s"
                 (op_name origin.clause.op)
                 (continuation_phrase origin)))

  (* ------------------------------------------------------------------ *)
  (* Refuted atoms                                                       *)
  (* ------------------------------------------------------------------ *)

  (* The reason of the atom a failure refutes, the one its diagnostic is built
     on, when the failure names one. *)
  let refuted_reason = function
    | R.Shape_mismatch f | R.Occurs_check f -> Some f.info
    | R.Refuted_rho o -> Some (principal o.info)
    | R.Refuted_eps o -> Some (principal o.info)
    | R.Never_eternal { reason; _ } -> Some reason
    | R.Refuted_condition { condition; _ } | R.Undecided_condition condition
      -> (
        match (condition.rho_conditions, condition.eps_conditions) with
        | o :: _, _ -> Some o.info
        | [], o :: _ -> Some o.info
        | [], [] -> None)
    | R.Unestablished _ | R.Rigid_escape _ -> None

  let refutes_effect = function
    | R.Refuted_eps _ -> true
    | R.Refuted_condition { condition = { rho_conditions = []; _ }; _ }
    | R.Undecided_condition { rho_conditions = []; _ } ->
        true
    | R.Refuted_condition _ | R.Undecided_condition _ | R.Shape_mismatch _
    | R.Occurs_check _ | R.Refuted_rho _ | R.Never_eternal _ | R.Unestablished _
    | R.Rigid_escape _ ->
        false

  let reason_of_atom = function
    | C.Sub (r, _, _)
    | C.Rho_leq (r, _, _)
    | C.Eps_leq (r, _, _)
    | C.Eternal (r, _)
    | C.Eternal_or_unit (r, _, _) ->
        Some r
    | C.True | C.And _ | C.Exists _ | C.Forall_eps _ -> None

  let without_refuted failure c =
    Option.bind (refuted_reason failure) (fun reason ->
        let refuted atom =
          Option.fold ~none:false ~some:(generated_by reason)
            (reason_of_atom atom)
        in
        if List.exists refuted (atoms c) then Some (drop refuted c) else None)
end
