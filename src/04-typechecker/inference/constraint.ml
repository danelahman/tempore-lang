(* Constraints and qualified schemes, after the constraints and constrained
   type schemes of HM(X) (Odersky, Sulzmann and Wehr, TAPOS 1999). *)

module Ast = Language.Ast
module PrettyPrint = Language.PrettyPrint

(* The parts of a scheme for a layout of its own. *)
type part = Format.formatter -> unit

type conjunct =
  | Formula of part
  | Ordering of { binder : part option; left : part; right : part }

type layout = {
  parameters : part option;
  conjuncts : conjunct list;
  arrows : part PrettyPrint.arrows;
}

module type S = sig
  module X : GradeExp.S

  type rho = X.rho
  type eps = X.eps
  type ty = (rho, eps) Ast.ty
  type comp_ty = (rho, eps) Ast.comp_ty
  type reason = (rho, eps) Reason.t

  type vars = {
    ty_vars : Ast.ty_param list;
    rho_vars : X.Rho_var.t list;
    eps_vars : X.Eps_var.t list;
  }

  val no_vars : vars
  val union_vars : vars -> vars -> vars

  type t =
    | True
    | And of t * t
    | Sub of reason * ty * ty
    | Rho_leq of reason * rho * rho
    | Eps_leq of reason * eps * eps
    | Eternal of reason * ty
    | Eternal_or_unit of reason * ty * rho
    | Exists of vars * t
    | Forall_eps of X.Eps_var.t * Reason.rigid_origin * t

  val conj : t -> t -> t
  val conj_all : t list -> t
  val exists : vars -> t -> t
  val equal_ty : reason -> ty -> ty -> t
  val map_reasons : (reason -> reason) -> t -> t

  type subst = { ty_subst : ty Ast.TyParamMap.t; grade_subst : X.subst }

  val empty_subst : subst
  val subst_ty : subst -> ty -> ty
  val subst_reason : subst -> reason -> reason
  val subst : subst -> t -> t
  val freshen : subst -> t -> t

  type free = {
    free_tys : Ast.TyParamSet.t;
    free_rhos : X.Rho_var.Set.t;
    free_eps : X.Eps_var.Set.t;
  }

  val no_free : free
  val union_free : free -> free -> free
  val free_vars_ty : ty -> free
  val free_vars_comp_ty : comp_ty -> free
  val free_vars : t -> free

  type scheme = {
    ty_params : Ast.ty_param list;
    rho_params : X.Rho_var.t list;
    eps_params : X.Eps_var.t list;
    qualifier : t;
    ty : ty;
  }

  val monomorphic : ty -> scheme
  val instantiate : scheme -> ty * t

  type names

  val is_unit_eps : Grades.Grade.bounds -> eps -> bool
  val names : ?bounds:Grades.Grade.bounds -> unit -> names
  val print_rho : ?names:names -> rho -> Format.formatter -> unit
  val print_eps : ?names:names -> eps -> Format.formatter -> unit
  val print_ty : ?names:names -> ty -> Format.formatter -> unit
  val print : ?names:names -> t -> Format.formatter -> unit
  val to_string : t -> string
  val print_inline : ?names:names -> t -> Format.formatter -> unit
  val print_scheme : ?names:names -> scheme -> Format.formatter -> unit
  val scheme_layout : ?names:names -> scheme -> layout
end

module Make (X : GradeExp.S) = struct
  module X = X

  type rho = X.rho
  type eps = X.eps
  type ty = (rho, eps) Ast.ty
  type comp_ty = (rho, eps) Ast.comp_ty
  type reason = (rho, eps) Reason.t

  type vars = {
    ty_vars : Ast.ty_param list;
    rho_vars : X.Rho_var.t list;
    eps_vars : X.Eps_var.t list;
  }

  let no_vars = { ty_vars = []; rho_vars = []; eps_vars = [] }

  let union_vars vs vs' =
    {
      ty_vars = vs.ty_vars @ vs'.ty_vars;
      rho_vars = vs.rho_vars @ vs'.rho_vars;
      eps_vars = vs.eps_vars @ vs'.eps_vars;
    }

  let is_empty_vars = function
    | { ty_vars = []; rho_vars = []; eps_vars = [] } -> true
    | _ -> false

  type t =
    | True
    | And of t * t
    | Sub of reason * ty * ty
    | Rho_leq of reason * rho * rho
    | Eps_leq of reason * eps * eps
    | Eternal of reason * ty
    | Eternal_or_unit of reason * ty * rho
    | Exists of vars * t
    | Forall_eps of X.Eps_var.t * Reason.rigid_origin * t

  let conj c d = match (c, d) with True, c | c, True -> c | c, d -> And (c, d)
  let conj_all cs = List.fold_right conj cs True

  let exists vs c =
    match c with
    | _ when is_empty_vars vs -> c
    | Exists (vs', c') -> Exists (union_vars vs vs', c')
    | c -> Exists (vs, c)

  let equal_ty reason a b = And (Sub (reason, a, b), Sub (reason, b, a))

  let rec map_reasons f = function
    | True -> True
    | And (c, d) -> And (map_reasons f c, map_reasons f d)
    | Sub (r, a, b) -> Sub (f r, a, b)
    | Rho_leq (r, rho, rho') -> Rho_leq (f r, rho, rho')
    | Eps_leq (r, eps, eps') -> Eps_leq (f r, eps, eps')
    | Eternal (r, a) -> Eternal (f r, a)
    | Eternal_or_unit (r, a, rho) -> Eternal_or_unit (f r, a, rho)
    | Exists (vs, c) -> Exists (vs, map_reasons f c)
    | Forall_eps (e, origin, c) -> Forall_eps (e, origin, map_reasons f c)

  (* ------------------------------------------------------------------ *)
  (* Substitution                                                        *)
  (* ------------------------------------------------------------------ *)

  type subst = { ty_subst : ty Ast.TyParamMap.t; grade_subst : X.subst }

  let empty_subst =
    { ty_subst = Ast.TyParamMap.empty; grade_subst = X.empty_subst }

  let subst_rho sigma = X.Rho.subst sigma.grade_subst
  let subst_eps sigma = X.Eps.subst sigma.grade_subst

  let subst_ty sigma =
    Ast.substitute_ty sigma.ty_subst ~on_rho:(subst_rho sigma)
      ~on_eps:(subst_eps sigma)

  let subst_reason sigma = Reason.map_grades (subst_rho sigma) (subst_eps sigma)

  let add_ty_var a a' sigma =
    {
      sigma with
      ty_subst = Ast.TyParamMap.add a (Ast.TyParam a') sigma.ty_subst;
    }

  let add_rho_var rho_var rho_var' sigma =
    let g = sigma.grade_subst in
    {
      sigma with
      grade_subst =
        {
          g with
          rho_subst = X.Rho_var.Map.add rho_var (X.Rho.var rho_var') g.rho_subst;
        };
    }

  let add_eps_var eps_var eps_var' sigma =
    let g = sigma.grade_subst in
    {
      sigma with
      grade_subst =
        {
          g with
          eps_subst = X.Eps_var.Map.add eps_var (X.Eps.var eps_var') g.eps_subst;
        };
    }

  let remove_eps_var eps_var sigma =
    let g = sigma.grade_subst in
    {
      sigma with
      grade_subst =
        { g with eps_subst = X.Eps_var.Map.remove eps_var g.eps_subst };
    }

  let remove_vars vs sigma =
    let g = sigma.grade_subst in
    {
      ty_subst =
        List.fold_left
          (fun m a -> Ast.TyParamMap.remove a m)
          sigma.ty_subst vs.ty_vars;
      grade_subst =
        {
          rho_subst =
            List.fold_left
              (fun m r -> X.Rho_var.Map.remove r m)
              g.rho_subst vs.rho_vars;
          eps_subst =
            List.fold_left
              (fun m e -> X.Eps_var.Map.remove e m)
              g.eps_subst vs.eps_vars;
        };
    }

  let fresh_ty_var () = Ast.TyParamModule.fresh "ty"

  (* [rename_vars vs sigma] is fresh unknowns for [vs] and [sigma] extended to
     send each unknown of [vs] to its fresh counterpart. *)
  let rename_vars vs sigma =
    let ty_vars = List.map (fun _ -> fresh_ty_var ()) vs.ty_vars
    and rho_vars = List.map (fun _ -> X.Rho_var.fresh_indexed ()) vs.rho_vars
    and eps_vars = List.map (fun _ -> X.Eps_var.fresh_indexed ()) vs.eps_vars in
    let sigma =
      List.fold_left2 (fun s a a' -> add_ty_var a a' s) sigma vs.ty_vars ty_vars
    in
    let sigma =
      List.fold_left2
        (fun s r r' -> add_rho_var r r' s)
        sigma vs.rho_vars rho_vars
    in
    let sigma =
      List.fold_left2
        (fun s e e' -> add_eps_var e e' s)
        sigma vs.eps_vars eps_vars
    in
    ({ ty_vars; rho_vars; eps_vars }, sigma)

  (* How a traversal treats a binder: [Keep] leaves its unknowns and removes
     them from the substitution, [Rename] renames them afresh. *)
  type binders = Keep | Rename

  let rec apply binders sigma = function
    | True -> True
    | And (c, d) -> And (apply binders sigma c, apply binders sigma d)
    | Sub (r, a, b) ->
        Sub (subst_reason sigma r, subst_ty sigma a, subst_ty sigma b)
    | Rho_leq (r, rho, rho') ->
        Rho_leq (subst_reason sigma r, subst_rho sigma rho, subst_rho sigma rho')
    | Eps_leq (r, eps, eps') ->
        Eps_leq (subst_reason sigma r, subst_eps sigma eps, subst_eps sigma eps')
    | Eternal (r, a) -> Eternal (subst_reason sigma r, subst_ty sigma a)
    | Eternal_or_unit (r, a, rho) ->
        Eternal_or_unit
          (subst_reason sigma r, subst_ty sigma a, subst_rho sigma rho)
    | Exists (vs, c) -> (
        match binders with
        | Keep -> Exists (vs, apply binders (remove_vars vs sigma) c)
        | Rename ->
            let vs', sigma' = rename_vars vs sigma in
            Exists (vs', apply binders sigma' c))
    | Forall_eps (e, origin, c) -> (
        match binders with
        | Keep ->
            Forall_eps (e, origin, apply binders (remove_eps_var e sigma) c)
        | Rename ->
            let e' = X.Eps_var.fresh_indexed () in
            Forall_eps (e', origin, apply binders (add_eps_var e e' sigma) c))

  let subst sigma c = apply Keep sigma c
  let freshen sigma c = apply Rename sigma c

  (* ------------------------------------------------------------------ *)
  (* Free unknowns                                                       *)
  (* ------------------------------------------------------------------ *)

  type free = {
    free_tys : Ast.TyParamSet.t;
    free_rhos : X.Rho_var.Set.t;
    free_eps : X.Eps_var.Set.t;
  }

  let no_free =
    {
      free_tys = Ast.TyParamSet.empty;
      free_rhos = X.Rho_var.Set.empty;
      free_eps = X.Eps_var.Set.empty;
    }

  let union_free f f' =
    {
      free_tys = Ast.TyParamSet.union f.free_tys f'.free_tys;
      free_rhos = X.Rho_var.Set.union f.free_rhos f'.free_rhos;
      free_eps = X.Eps_var.Set.union f.free_eps f'.free_eps;
    }

  let free_rho rho acc =
    {
      acc with
      free_rhos = X.Rho_var.Set.union acc.free_rhos (X.Rho.free_rho_vars rho);
      free_eps = X.Eps_var.Set.union acc.free_eps (X.Rho.free_eps_vars rho);
    }

  let free_eps eps acc =
    {
      acc with
      free_eps = X.Eps_var.Set.union acc.free_eps (X.Eps.free_vars eps);
    }

  let free_param a acc =
    { acc with free_tys = Ast.TyParamSet.add a acc.free_tys }

  let add_free_ty a acc =
    Ast.fold_ty ~on_param:free_param ~on_rho:free_rho ~on_eps:free_eps a acc

  let free_vars_ty a = add_free_ty a no_free

  let free_vars_comp_ty c =
    Ast.fold_comp_ty ~on_param:free_param ~on_rho:free_rho ~on_eps:free_eps c
      no_free

  let remove_free vs f =
    {
      free_tys =
        List.fold_left
          (fun s a -> Ast.TyParamSet.remove a s)
          f.free_tys vs.ty_vars;
      free_rhos =
        List.fold_left
          (fun s r -> X.Rho_var.Set.remove r s)
          f.free_rhos vs.rho_vars;
      free_eps =
        List.fold_left
          (fun s e -> X.Eps_var.Set.remove e s)
          f.free_eps vs.eps_vars;
    }

  (* The unknowns free in a constraint added to [acc]. *)
  let rec add_free c acc =
    match c with
    | True -> acc
    | And (c, d) -> add_free d (add_free c acc)
    | Sub (_, a, b) -> add_free_ty b (add_free_ty a acc)
    | Rho_leq (_, rho, rho') -> free_rho rho (free_rho rho' acc)
    | Eps_leq (_, eps, eps') -> free_eps eps (free_eps eps' acc)
    | Eternal (_, a) -> add_free_ty a acc
    | Eternal_or_unit (_, a, rho) -> free_rho rho (add_free_ty a acc)
    | Exists (vs, c) -> union_free acc (remove_free vs (free_vars c))
    | Forall_eps (e, _, c) ->
        let f = free_vars c in
        union_free acc { f with free_eps = X.Eps_var.Set.remove e f.free_eps }

  and free_vars c = add_free c no_free

  (* ------------------------------------------------------------------ *)
  (* Schemes                                                             *)
  (* ------------------------------------------------------------------ *)

  type scheme = {
    ty_params : Ast.ty_param list;
    rho_params : X.Rho_var.t list;
    eps_params : X.Eps_var.t list;
    qualifier : t;
    ty : ty;
  }

  let monomorphic ty =
    { ty_params = []; rho_params = []; eps_params = []; qualifier = True; ty }

  let instantiate scheme =
    let _, sigma =
      rename_vars
        {
          ty_vars = scheme.ty_params;
          rho_vars = scheme.rho_params;
          eps_vars = scheme.eps_params;
        }
        empty_subst
    in
    (subst_ty sigma scheme.ty, freshen sigma scheme.qualifier)

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

  type names = {
    ty_name : Ast.ty_param -> Format.formatter -> unit;
    rho_name : X.Rho_var.t -> Format.formatter -> unit;
    eps_name : X.Eps_var.t -> Format.formatter -> unit;
    rigid_ops : string X.Eps_var.Map.t ref;
        (** the operations of the clauses of the rigid variables whose binders
            have been printed *)
    unit_eps : eps -> bool;  (** whether an effect is the unit *)
  }

  module N = GradeNormal.Make (X)

  let is_unit_eps bounds eps =
    let canonical =
      match N.Eps.canon bounds eps with
      | eps -> eps
      | exception Utils.Error.Error _ -> eps
    in
    match X.Eps.value canonical with
    | Some c -> (
        try X.GS.E.equal bounds c X.GS.E.one with Utils.Error.Error _ -> false)
    | None -> false

  (* The running times of a program that declares no operations. *)
  let no_operations =
    {
      Grades.Grade.running_time =
        (fun event -> Utils.Error.typing "Unknown event `%s`" event);
      operations = [];
    }

  (* A rigid variable is named after the operation of its clause. *)
  let names ?(bounds = no_operations) () =
    let rigid_ops = ref X.Eps_var.Map.empty in
    {
      unit_eps = is_unit_eps bounds;
      ty_name = Ty_names.create ();
      rho_name = Rho_names.create ();
      eps_name =
        Eps_names.create_with
          ~named:(fun e ->
            Option.map PrettyPrint.rigid_symbol
              (X.Eps_var.Map.find_opt e !rigid_ops))
          ();
      rigid_ops;
    }

  (* The binder of the rigid variable [e] of the clause of [origin]. *)
  let rigid_binder names e (origin : Reason.rigid_origin) ppf =
    names.rigid_ops :=
      X.Eps_var.Map.add e
        (Ast.OpName.string_of origin.clause.op)
        !(names.rigid_ops);
    names.eps_name e ppf

  let names_or = function Some names -> names | None -> names ()

  (* [paren wrap body ppf] prints [body], in parentheses when [wrap]. *)
  let paren wrap body ppf =
    if wrap then Format.fprintf ppf "(%t)" body else body ppf

  (* Operands of a join are printed at level 0, of a product at level 1. *)
  let print_binary level op_level symbol left right ppf =
    paren (level > op_level)
      (fun ppf -> Format.fprintf ppf "%t %s %t" left symbol right)
      ppf

  let rec eps_at names level eps ppf =
    match eps with
    | X.Eps_var e -> names.eps_name e ppf
    | X.Eps_const c -> Format.pp_print_string ppf (X.GS.E.show c)
    | X.Eps_mul (eps, eps') ->
        print_binary level 1 "·" (eps_at names 1 eps) (eps_at names 1 eps') ppf
    | X.Eps_join (eps, eps') ->
        print_binary level 0 "⊔" (eps_at names 0 eps) (eps_at names 0 eps') ppf

  let rec rho_at names level rho ppf =
    match rho with
    | X.Rho_var r -> names.rho_name r ppf
    | X.Rho_const c -> Format.pp_print_string ppf (X.GS.R.show c)
    | X.Rho_map eps -> Format.fprintf ppf "∣%t∣" (eps_at names 0 eps)
    | X.Rho_mul (rho, rho') ->
        print_binary level 1 "·" (rho_at names 1 rho) (rho_at names 1 rho') ppf
    | X.Rho_join (rho, rho') ->
        print_binary level 0 "⊔" (rho_at names 0 rho) (rho_at names 0 rho') ppf

  let print_rho ?names rho = rho_at (names_or names) 0 rho
  let print_eps ?names eps = eps_at (names_or names) 0 eps

  let grades names =
    {
      PrettyPrint.rho = rho_at names 0;
      eps = eps_at names 0;
      pure = names.unit_eps;
    }

  let ty_with names ty ppf =
    Format.fprintf ppf "@[<h>%t@]"
      (PrettyPrint.print_ty (grades names) names.ty_name ty)

  let print_ty ?names ty = ty_with (names_or names) ty

  let print_vars names vs ppf =
    let printers =
      List.map names.ty_name vs.ty_vars
      @ List.map names.rho_name vs.rho_vars
      @ List.map names.eps_name vs.eps_vars
    in
    Format.pp_print_list
      ~pp_sep:(fun ppf () -> Format.pp_print_string ppf " ")
      (fun ppf print -> print ppf)
      ppf printers

  let rec conjuncts = function
    | And (c, d) -> conjuncts c @ conjuncts d
    | c -> [ c ]

  let rec print_with names c ppf =
    let ty = ty_with names and rho = rho_at names 0 and eps = eps_at names 0 in
    match c with
    | True -> Format.pp_print_string ppf "⊤"
    | And _ ->
        Format.fprintf ppf "@[<v>%a@]"
          (Format.pp_print_list (fun ppf c -> print_with names c ppf))
          (conjuncts c)
    | Sub (_, a, b) -> Format.fprintf ppf "@[<h>%t <: %t@]" (ty a) (ty b)
    | Rho_leq (_, r, r') -> Format.fprintf ppf "@[<h>%t ≾ %t@]" (rho r) (rho r')
    | Eps_leq (_, e, e') -> Format.fprintf ppf "@[<h>%t ≾ %t@]" (eps e) (eps e')
    | Eternal (_, a) -> Format.fprintf ppf "@[<h>Et(%t)@]" (ty a)
    | Eternal_or_unit (_, a, r) ->
        Format.fprintf ppf "@[<h>Et(%t) ∨ %t ≾ %s@]" (ty a) (rho r)
          (X.GS.R.show X.GS.R.one)
    | Exists (vs, c) ->
        Format.fprintf ppf "@[<v 2>∃%t.@,%t@]" (print_vars names vs)
          (print_with names c)
    | Forall_eps (e, origin, c) ->
        Format.fprintf ppf "@[<v 2>∀%t.@,%t@]"
          (rigid_binder names e origin)
          (print_with names c)

  let print ?names c = print_with (names_or names) c
  let to_string c = Format.asprintf "%t" (print c)

  (* A formula on one line: conjuncts joined by [∧], a binder or a
     disjunction within a conjunction in parentheses. *)
  let rec inline_with names c ppf =
    match c with
    | And _ ->
        Format.pp_print_list
          ~pp_sep:(fun ppf () -> Format.fprintf ppf " ∧@ ")
          (fun ppf c -> conjunct_with names c ppf)
          ppf (conjuncts c)
    | Exists (vs, c) ->
        Format.fprintf ppf "∃%t.@ %t" (print_vars names vs)
          (inline_with names c)
    | Forall_eps (e, origin, c) ->
        Format.fprintf ppf "∀%t.@ %t"
          (rigid_binder names e origin)
          (inline_with names c)
    | True | Sub _ | Rho_leq _ | Eps_leq _ | Eternal _ | Eternal_or_unit _ ->
        print_with names c ppf

  and conjunct_with names c ppf =
    match c with
    | Exists _ | Forall_eps _ | Eternal_or_unit _ ->
        paren true (inline_with names c) ppf
    | True | And _ | Sub _ | Rho_leq _ | Eps_leq _ | Eternal _ ->
        inline_with names c ppf

  let print_inline ?names c ppf =
    Format.fprintf ppf "@[<hov 2>%t@]" (inline_with (names_or names) c)

  (* The unknowns of types and constraints in the reverse order of their
     occurrences. *)
  type occurrences = {
    ty_occ : Ast.ty_param list;
    rho_occ : X.Rho_var.t list;
    eps_occ : X.Eps_var.t list;
  }

  let add_eps_occ e occ = { occ with eps_occ = e :: occ.eps_occ }
  let add_rho_occ r occ = { occ with rho_occ = r :: occ.rho_occ }
  let eps_occurrences = X.Eps.fold_vars add_eps_occ
  let rho_occurrences = X.Rho.fold_vars ~on_rho:add_rho_occ ~on_eps:add_eps_occ

  let ty_occurrences ty occ =
    Ast.fold_ty
      ~on_param:(fun a occ -> { occ with ty_occ = a :: occ.ty_occ })
      ~on_rho:rho_occurrences ~on_eps:eps_occurrences ty occ

  let rec occurrences c occ =
    match c with
    | True -> occ
    | And (c, d) -> occurrences d (occurrences c occ)
    | Sub (_, a, b) -> ty_occurrences b (ty_occurrences a occ)
    | Rho_leq (_, rho, rho') -> rho_occurrences rho' (rho_occurrences rho occ)
    | Eps_leq (_, eps, eps') -> eps_occurrences eps' (eps_occurrences eps occ)
    | Eternal (_, a) -> ty_occurrences a occ
    | Eternal_or_unit (_, a, rho) -> rho_occurrences rho (ty_occurrences a occ)
    | Exists (_, c) | Forall_eps (_, _, c) -> occurrences c occ

  (* [params] ordered by [occ], reversed, those absent from it last. *)
  let ordered equal params occ =
    let seen = List.rev occ in
    let first =
      List.fold_left
        (fun acc v ->
          if List.exists (equal v) params && not (List.exists (equal v) acc)
          then v :: acc
          else acc)
        [] seen
    in
    List.rev first
    @ List.filter (fun p -> not (List.exists (equal p) first)) params

  (* The parameters of [scheme], ordered by their first occurrences in its type
     and then in its qualifier. *)
  let scheme_parameters names scheme =
    let occ =
      occurrences scheme.qualifier
        (ty_occurrences scheme.ty { ty_occ = []; rho_occ = []; eps_occ = [] })
    in
    let vs =
      {
        ty_vars =
          ordered
            (fun a b -> Ast.TyParamModule.compare a b = 0)
            scheme.ty_params occ.ty_occ;
        rho_vars = ordered X.Rho_var.equal scheme.rho_params occ.rho_occ;
        eps_vars = ordered X.Eps_var.equal scheme.eps_params occ.eps_occ;
      }
    in
    match vs with
    | { ty_vars = []; rho_vars = []; eps_vars = [] } -> None
    | _ -> Some (print_vars names vs)

  let scheme_parts ?names scheme =
    let names = names_or names in
    let qualifier =
      match scheme.qualifier with
      | True -> None
      | q -> Some (inline_with names q)
    in
    (scheme_parameters names scheme, qualifier, ty_with names scheme.ty)

  let scheme_layout ?names scheme =
    let names = names_or names in
    let horizontal part ppf = Format.fprintf ppf "@[<h>%t@]" part in
    let ordering binder (left, right) =
      Ordering { binder; left = horizontal left; right = horizontal right }
    in
    let sides = function
      | Rho_leq (_, r, r') -> Some (rho_at names 0 r, rho_at names 0 r')
      | Eps_leq (_, e, e') -> Some (eps_at names 0 e, eps_at names 0 e')
      | True | And _ | Sub _ | Eternal _ | Eternal_or_unit _ | Exists _
      | Forall_eps _ ->
          None
    in
    let conjunct c =
      match (c, sides c) with
      | _, Some sides -> ordering None sides
      | Forall_eps (e, origin, body), None -> (
          match sides body with
          | Some sides -> ordering (Some (rigid_binder names e origin)) sides
          | None -> Formula (conjunct_with names c))
      | _, None -> Formula (conjunct_with names c)
    in
    {
      parameters = scheme_parameters names scheme;
      conjuncts =
        (match scheme.qualifier with
        | True -> []
        | q -> List.map conjunct (conjuncts q));
      arrows =
        PrettyPrint.map_arrows horizontal
          (PrettyPrint.arrow_parts (grades names) names.ty_name scheme.ty);
    }

  let print_scheme ?names scheme ppf =
    let quantifier, qualifier, ty = scheme_parts ?names scheme in
    let quantifier ppf = Option.iter (Format.fprintf ppf "∀ %t.@ ") quantifier
    and qualifier ppf = Option.iter (Format.fprintf ppf "%t ⇒@ ") qualifier in
    Format.fprintf ppf "@[<hov 2>%t%t%t@]" quantifier qualifier ty
end
