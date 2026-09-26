open Ast
module Print = Utils.Print
module Symbol = Utils.Symbol

(* Unicode subscripts for digits 0–9 *)
let subscript i =
  let digits =
    [|
      "\226\130\128";
      "\226\130\129";
      "\226\130\130";
      "\226\130\131";
      "\226\130\132";
      "\226\130\133";
      "\226\130\134";
      "\226\130\135";
      "\226\130\136";
      "\226\130\137";
    |]
  in
  let rec build_subscript n =
    if n < 10 then digits.(n) else build_subscript (n / 10) ^ digits.(n mod 10)
  in
  build_subscript i

(* Greek letters for type variables *)
let greek_letters =
  [|
    "α";
    "β";
    "γ";
    "δ";
    "ε";
    "ζ";
    "η";
    "θ";
    "ι";
    "κ";
    "λ";
    "μ";
    "ν";
    "ξ";
    "ο";
    "π";
    "σ";
    "τ";
  |]

let type_symbol n =
  if n < Array.length greek_letters then greek_letters.(n)
  else "σ" ^ subscript (n - Array.length greek_letters)

let rho_symbol n = "ρ" ^ subscript n
let eps_symbol n = "ε" ^ subscript n

module MakeParamPrinter
    (ParamMap : Map.S)
    (SymbolGen : sig
      val symbol_for_index : int -> string
    end) =
struct
  let create () =
    let names = ref ParamMap.empty in
    let counter = ref 0 in
    fun param ppf ->
      let symbol =
        match ParamMap.find_opt param !names with
        | Some sym -> sym
        | None ->
            let sym = SymbolGen.symbol_for_index !counter in
            incr counter;
            names := ParamMap.add param sym !names;
            sym
      in
      Format.fprintf ppf "%s" symbol
end

module TyPrintParam =
  MakeParamPrinter
    (TyParamMap)
    (struct
      let symbol_for_index = type_symbol
    end)

module RhoPrintParam =
  MakeParamPrinter
    (RhoParamMap)
    (struct
      let symbol_for_index = rho_symbol
    end)

module EpsPrintParam =
  MakeParamPrinter
    (EpsParamMap)
    (struct
      let symbol_for_index = eps_symbol
    end)

(* The grade parameters of the typechecker that grades resources and effects
   alike, which represents both sorts by effect grade expressions: they are
   printed as the parameters of either sort were before the sorts were told
   apart. *)
module SingleSortPrintParam =
  MakeParamPrinter
    (EpsParamMap)
    (struct
      let symbol_for_index = rho_symbol
    end)

let print_ty_params ty_pp ty_params ppf =
  Format.fprintf ppf "[";
  let rec print_helper = function
    | [] -> ()
    | [ last ] -> Format.fprintf ppf "%t" (ty_pp last)
    | hd :: tl ->
        Format.fprintf ppf "%t, " (ty_pp hd);
        print_helper tl
  in
  print_helper ty_params;
  Format.fprintf ppf "]"

let print_grade_params ?max_level:_ param_pp params ppf =
  Format.fprintf ppf "[";
  let rec print_helper = function
    | [] -> ()
    | [ last ] -> Format.fprintf ppf "%t" (param_pp last)
    | hd :: tl ->
        Format.fprintf ppf "%t, " (param_pp hd);
        print_helper tl
  in
  print_helper params;
  Format.fprintf ppf "]"

let print_rho (type a) (module R : Grade.S with type t = a) rho_pp =
  let rec aux (rho : a rho) ppf =
    match rho with
    | RhoConst c -> Format.fprintf ppf "%s" (R.show c)
    | RhoParam p -> rho_pp p ppf
    | RhoAdd (rho1, rho2) ->
        Format.fprintf ppf "@[%t + %t@]"
          (fun ppf -> aux rho1 ppf)
          (fun ppf -> aux rho2 ppf)
  in
  aux

let print_eps (type a) (module E : Grade.S with type t = a) eps_pp =
  let rec aux (eps : a eps) ppf =
    match eps with
    | EpsConst c -> Format.fprintf ppf "%s" (E.show c)
    | EpsParam p | EpsRigid p -> eps_pp p ppf
    | EpsAdd (eps1, eps2) ->
        Format.fprintf ppf "@[%t + %t@]"
          (fun ppf -> aux eps1 ppf)
          (fun ppf -> aux eps2 ppf)
  in
  aux

type ('rho, 'eps) grade_printer = {
  rho : 'rho -> Format.formatter -> unit;
  eps : 'eps -> Format.formatter -> unit;
  pure : 'eps -> bool;
}
(** How the grades of a type are printed: its resource grades by [rho] and its
    effect grades by [eps]. An arrow whose effect grade is [pure] is printed
    without it. *)

(** [single_sort_printer grade eps_pp] prints the grades of the typechecker that
    grades resources and effects alike by [grade]. *)
let single_sort_printer (type a) grade eps_pp : (a eps, a eps) grade_printer =
  let module G = (val grade : Grade.S with type t = a) in
  let print = print_eps grade eps_pp in
  { rho = print; eps = print; pure = (fun eps -> eps = EpsConst G.one) }

(** [print_ty grades ty_print_param ty] prints [ty], its grades by [grades]. *)
let print_ty ?max_level grades ty_print_param =
  let rec aux ?max_level p ppf =
    let print ?at_level = Print.print ?max_level ?at_level ppf in
    match p with
    | TyConst c -> print "%t" (Const.print_ty c)
    | TyApply (ty_name, []) -> print "%t" (TyName.print ty_name)
    | TyApply (ty_name, [ ty ]) ->
        print ~at_level:1 "%t %t" (aux ~max_level:1 ty) (TyName.print ty_name)
    | TyApply (ty_name, tys) ->
        print ~at_level:1 "%t %t"
          (Print.print_tuple aux tys)
          (TyName.print ty_name)
    | TyParam a -> print "%t" (ty_print_param a)
    | TyArrow (ty1, CompTy (ty2, eps)) when grades.pure eps ->
        print ~at_level:3 "%t → %t" (aux ~max_level:2 ty1)
          (aux ~max_level:3 ty2)
    | TyArrow (ty1, CompTy (ty2, eps)) ->
        print ~at_level:3 "%t → %t # %t" (aux ~max_level:2 ty1)
          (aux ~max_level:3 ty2) (grades.eps eps)
    | TyTuple [] -> print "unit"
    | TyTuple tys ->
        print ~at_level:2 "%t"
          (Print.print_sequence " × " (aux ~max_level:1) tys)
    | TyBox (rho, ty) ->
        print ~at_level:1 "[%t]%t" (grades.rho rho) (aux ~max_level:0 ty)
    | TyHandler (CompTy (ty1, eps1), CompTy (ty2, eps2)) ->
        print ~at_level:3 "%t # %t ⇒ %t # %t" (aux ~max_level:2 ty1)
          (grades.eps eps1) (aux ~max_level:3 ty2) (grades.eps eps2)
  in
  aux ?max_level

(** [print_constr grade] prints a constraint of the typechecker that grades
    resources and effects alike by [grade]. *)
let print_constr (type a) grade ty_pp eps_pp =
  let module G = (val grade : Grade.S with type t = a) in
  let print_ineq eps1 eps2 ppf =
    Format.fprintf ppf "%t %s %t"
      (print_eps grade eps_pp eps1)
      G.leq_symbol
      (print_eps grade eps_pp eps2)
  in
  let print_eternal ty ppf =
    Format.fprintf ppf "eternal %t"
      (print_ty ~max_level:0 (single_sort_printer grade eps_pp) ty_pp ty)
  in
  (* A constraint's reason is provenance for diagnostics, not part of what the
     constraint says, so a scheme's qualifier prints without it. *)
  fun (c : a constr) ppf ->
    match c with
    | Ineq (eps1, eps2, _) -> print_ineq eps1 eps2 ppf
    | Eternal (ty, _) -> print_eternal ty ppf
    | EternalOrIneq (ty, eps1, eps2, _) ->
        Format.fprintf ppf "%t ∨ %t" (print_eternal ty) (print_ineq eps1 eps2)

(** The qualifier of a type scheme, [{c1, ..., cn}], or nothing when there are
    no constraints. *)
let print_constrs grade ty_pp eps_pp constrs ppf =
  match constrs with
  | [] -> ()
  | _ ->
      Format.fprintf ppf "{%t} "
        (Print.print_sequence ", " (print_constr grade ty_pp eps_pp) constrs)

let rec print_pattern ?max_level p ppf =
  let print ?at_level = Print.print ?max_level ?at_level ppf in
  match p.it with
  | PVar x -> print "%t" (Variable.print x)
  | PAs (p, x) -> print "%t as %t" (print_pattern p) (Variable.print x)
  | PAnnotated (p, _ty) -> print_pattern ?max_level p ppf
  | PConst c -> Const.print c ppf
  | PTuple lst -> Print.print_tuple print_pattern lst ppf
  | PVariant (lbl, None) when lbl = nil_label -> print "[]"
  | PVariant (lbl, None) -> print "%t" (Label.print lbl)
  | PVariant (lbl, Some { it = PTuple [ v1; v2 ]; _ }) when lbl = cons_label ->
      print "%t::%t" (print_pattern v1) (print_pattern v2)
  | PVariant (lbl, Some p) ->
      print ~at_level:1 "%t @[<hov>%t@]" (Label.print lbl) (print_pattern p)
  | PNonbinding -> print "_"

and print_expression resource_grade =
  let rec aux ?max_level e ppf =
    let print ?at_level = Print.print ?max_level ?at_level ppf in
    match e.it with
    | Var x -> print "%t" (Variable.print x)
    | Const c -> print "%t" (Const.print c)
    | Annotated (t, _ty) -> aux ?max_level t ppf
    | Tuple lst ->
        Print.print_tuple (fun ?max_level e ppf -> aux ?max_level e ppf) lst ppf
    | Variant (lbl, None) when lbl = nil_label -> print "[]"
    | Variant (lbl, None) -> print "%t" (Label.print lbl)
    | Variant (lbl, Some { it = Tuple [ v1; v2 ]; _ }) when lbl = cons_label ->
        print ~at_level:1 "%t::%t" (aux ~max_level:0 v1) (aux ~max_level:1 v2)
    | Variant (lbl, Some arg) ->
        print ~at_level:1 "%t %t" (Label.print lbl) (aux ~max_level:0 arg)
    | Lambda (p, c) ->
        print ~at_level:2 "@[<hv 2>fun %t ↦@ %t@]" (print_pattern p)
          (print_computation resource_grade ?max_level:None c)
    | PureLambda (p, c) ->
        print ~at_level:2 "@[<hv 2>fun %t ↦@ %t@]" (print_pattern p)
          (print_computation resource_grade ?max_level:None c)
    | RecLambda (f, _ty) -> print ~at_level:2 "rec %t ..." (Variable.print f)
    | Handler (ret_case, op_cases) ->
        let print_op_cases ppf =
          List.iter
            (fun op_case ->
              Format.fprintf ppf "@,| %t" (print_op_case resource_grade op_case))
            (OpNameMap.bindings op_cases)
        in
        print "@[<v 0>handler@,| return %t%t@]"
          (print_abstraction resource_grade ret_case)
          print_op_cases
  in
  aux

and print_computation resource_grade =
  let rec aux ?max_level c ppf =
    let print ?at_level = Print.print ?max_level ?at_level ppf in
    match c.it with
    | Return e ->
        print ~at_level:1 "return %t"
          (print_expression resource_grade ~max_level:0 e)
    | Do (c1, ({ it = PNonbinding; _ }, c2)) ->
        print ~at_level:2 "@[<v 0>%t;@,%t@]" (aux ~max_level:1 c1) (aux c2)
    | Do (c1, (pat, c2)) ->
        print ~at_level:2 "@[<v 0>@[<hov 2>let %t =@ %t@] in@,%t@]"
          (print_pattern pat) (aux ~max_level:1 c1) (aux c2)
    | Match (e, lst) ->
        let print_cases ppf =
          List.iter
            (fun case ->
              Format.fprintf ppf "@,| %t" (print_case resource_grade case))
            lst
        in
        print "@[<v 0>match %t with%t@]"
          (print_expression resource_grade ~max_level:0 e)
          print_cases
    | Apply (e1, e2) ->
        print ~at_level:1 "@[<hov 2>%t@ %t@]"
          (print_expression resource_grade ~max_level:1 e1)
          (print_expression resource_grade ~max_level:0 e2)
    | Delay (n, c) ->
        print ~at_level:1 "@[<hov 2>delay %d@ %t@]" n (aux ~max_level:0 c)
    | Box (rho, e, (p, c)) ->
        let rho_pp = RhoPrintParam.create () in
        print ~at_level:2 "@[<v 0>box %t %t as %t in@,%t@]"
          (print_rho resource_grade rho_pp rho)
          (print_expression resource_grade ~max_level:0 e)
          (print_pattern ~max_level:0 p)
          (aux c)
    | Unbox (e, (p, c)) ->
        print ~at_level:2 "@[<v 0>unbox %t as %t in@,%t@]"
          (print_expression resource_grade ~max_level:0 e)
          (print_pattern p) (aux c)
    | Perform (op, e, (pat, c)) ->
        print ~at_level:1 "@[<hv 2>perform %t %t (%t.@ %t)@]" (OpName.print op)
          (print_expression resource_grade ~max_level:0 e)
          (print_pattern pat) (aux ~max_level:1 c)
    | Handle (c, h) ->
        print ~at_level:1 "@[<v 0>handle@;<1 2>%t@,with %t@]" (aux c)
          (print_expression resource_grade ~max_level:0 h)
  in
  aux

and print_abstraction resource_grade (p, c) ppf =
  Format.fprintf ppf "@[<hv 2>%t ↦@ %t@]" (print_pattern p)
    (print_computation resource_grade c)

and print_case resource_grade a ppf =
  Format.fprintf ppf "%t" (print_abstraction resource_grade a)

and print_op_case resource_grade (op, a) ppf =
  Format.fprintf ppf "%t %t" (OpName.print op)
    (print_abstraction resource_grade a)

(** [grade_of] reads the grade out of a context entry of the typechecker that
    grades resources and effects alike by [grade], which wraps it in what else
    it remembers about where the grade was accumulated. *)
let print_vars_and_tys grade grade_of print_var_and_ty lst ppf =
  let rec print_list = function
    | [] -> ()
    | VarMap map :: rest ->
        List.iter
          (fun entry ->
            let ty_pp = TyPrintParam.create () in
            let eps_pp = SingleSortPrintParam.create () in
            print_var_and_ty ty_pp eps_pp entry ppf)
          (VariableMap.bindings map);
        print_list rest
    | Rho n :: rest ->
        let eps_pp = SingleSortPrintParam.create () in
        print_eps grade eps_pp (grade_of n) ppf;
        Print.print ppf "\n";
        print_list rest
    (* A barrier has nothing to print: it carries no binding and no grade. *)
    | Barrier _ :: rest -> print_list rest
  in
  print_list (List.rev lst)

let print_vars_and_exprs resource_grade print_var_and_expr
    (lst : ('var, 'map, 'rho, 'bar) Ast.context_elem_ty list) ppf =
  let print_var_map map ppf =
    let elements = VariableMap.bindings map in
    Format.fprintf ppf "@[<hv 2>{ ";
    let rec print_elements = function
      | [] -> ()
      | [ entry ] -> print_var_and_expr entry ppf
      | entry :: tl ->
          print_var_and_expr entry ppf;
          Format.fprintf ppf ",@ ";
          print_elements tl
    in
    print_elements elements;
    Format.fprintf ppf "@;<1 -2>}@]"
  in
  let print_elem ppf = function
    | VarMap map -> print_var_map map ppf
    | Rho n ->
        let rho_pp = RhoPrintParam.create () in
        print_rho resource_grade rho_pp n ppf
    | Barrier _ -> ()
  in
  (* A barrier has nothing to print: it carries no binding and no grade. *)
  let elems =
    List.filter (function Barrier _ -> false | _ -> true) (List.rev lst)
  in
  match elems with
  | [] -> Format.fprintf ppf "State: []@\n"
  | _ ->
      Format.fprintf ppf "@[<v 2>State: [@,";
      let rec print_list = function
        | [] -> ()
        | [ e ] -> print_elem ppf e
        | e :: tl ->
            print_elem ppf e;
            Format.fprintf ppf ",@,";
            print_list tl
      in
      print_list elems;
      Format.fprintf ppf "@;<0 -2>]@]@\n"

(** [scheme_of] reads the type scheme out of a context entry, which the
    typechecker wraps in what else it remembers, such as where it was bound. *)
let print_variable_context grade grade_of scheme_of ctx =
  let print_var_and_ty ty_pp eps_pp (variable, entry) ppf =
    let { ty_params; eps_params; constrs; ty } = scheme_of entry in
    Format.fprintf ppf "@[<h>%t : %t, %t %t%t@]@." (Variable.print variable)
      (print_ty_params ty_pp ty_params)
      (print_grade_params eps_pp eps_params)
      (print_constrs grade ty_pp eps_pp constrs)
      (print_ty (single_sort_printer grade eps_pp) ty_pp ty)
  in
  print_vars_and_tys grade grade_of print_var_and_ty ctx

let print_interpreter_state resource_grade ctx ppf =
  let print_var_and_expr (variable, (rho, expr)) ppf =
    let rho_print_param = RhoPrintParam.create () in
    Format.fprintf ppf "@[<hv 2>%t ↦@ %t@ # %t@]" (Variable.print variable)
      (print_expression resource_grade expr)
      (print_rho resource_grade rho_print_param rho)
  in
  print_vars_and_exprs resource_grade print_var_and_expr ctx ppf

let string_of_variable_context grade grade_of scheme_of context =
  print_variable_context grade grade_of scheme_of context Format.str_formatter;
  Format.flush_str_formatter ()

let string_of_interpreter_state resource_grade context =
  print_interpreter_state resource_grade context Format.str_formatter;
  Format.flush_str_formatter ()

let string_of_expression resource_grade e =
  print_expression resource_grade e Format.str_formatter;
  Format.flush_str_formatter ()

let string_of_computation resource_grade c =
  print_computation resource_grade c Format.str_formatter;
  Format.flush_str_formatter ()
