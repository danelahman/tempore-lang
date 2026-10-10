open Ast
module Print = Utils.Print
module Symbol = Utils.Symbol

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
  else "σ" ^ Print.subscript (n - Array.length greek_letters)

let rho_symbol n = "ρ" ^ Print.subscript n
let eps_symbol n = "ε" ^ Print.subscript n

(** [rigid_symbol op] is the name of an effect variable bound by a handler case
    for the operation [op], [ε_op]. *)
let rigid_symbol op = "ε_" ^ op

module MakeParamPrinter
    (ParamMap : Map.S)
    (SymbolGen : sig
      val symbol_for_index : int -> string
    end) =
struct
  (** [create_with ~named ()] names the parameters in the order they are first
      printed: by the next index, or by [base] where [named] gives [base], with
      as many primes [′] as parameters named [base] before it. *)
  let create_with ~named () =
    let names = ref ParamMap.empty in
    let counter = ref 0 in
    let bases = ref [] in
    fun param ppf ->
      let symbol =
        match ParamMap.find_opt param !names with
        | Some sym -> sym
        | None ->
            let sym =
              match named param with
              | Some base ->
                  let taken =
                    List.length (List.filter (String.equal base) !bases)
                  in
                  bases := base :: !bases;
                  base ^ String.concat "" (List.init taken (fun _ -> "′"))
              | None ->
                  let sym = SymbolGen.symbol_for_index !counter in
                  incr counter;
                  sym
            in
            names := ParamMap.add param sym !names;
            sym
      in
      Format.fprintf ppf "%s" symbol

  let create () = create_with ~named:(fun _ -> None) ()
end

let print_rho (type a) (module R : Grades.Grade.S with type t = a) =
  let rec aux (rho : a rho) ppf =
    match rho with
    | RhoConst (c, _) -> Format.fprintf ppf "%s" (R.show c)
    | RhoAdd (rho1, rho2) ->
        Format.fprintf ppf "@[%t + %t@]"
          (fun ppf -> aux rho1 ppf)
          (fun ppf -> aux rho2 ppf)
    | RhoVar r -> Rho_var.print r ppf
    | RhoImage e -> Format.fprintf ppf "∣%t∣" (Eps_var.print e)
  in
  aux

type ('rho, 'eps) grade_printer = {
  rho : 'rho -> Format.formatter -> unit;
  eps : 'eps -> Format.formatter -> unit;
  pure : 'eps -> bool;
}
(** How the grades of a type are printed: its resource grades by [rho] and its
    effect grades by [eps]. A computation type whose effect grade is [pure], the
    unit, is printed without it. *)

type 'a arrows = {
  domains : 'a list;
  codomain : 'a codomain;
  grade : 'a option;
}
(** A type as printed, in parts around its arrows: the [domains] of its
    outermost chain of arrows, in order, the [codomain] of the last arrow, and
    the effect grade of the last arrow where it is printed; the other arrows of
    a chain are printed without one. A type other than a function type has no
    domains and no grade. *)

(** A codomain, printed as it is or, where it is a function or handler type that
    {!parenthesised_codomain} selects, in parentheses. *)
and 'a codomain = Plain of 'a | Parenthesised of 'a arrows

(** [map_arrows f arrows] applies [f] to the parts of [arrows] in the order they
    are printed. *)
let rec map_arrows f { domains; codomain; grade } =
  let domains = List.map f domains in
  let codomain =
    match codomain with
    | Plain part -> Plain (f part)
    | Parenthesised arrows -> Parenthesised (map_arrows f arrows)
  in
  let grade = Option.map f grade in
  { domains; codomain; grade }

(** [print_arrows arrows ppf] prints [arrows], the domains followed by [→] and
    the effect grade preceded by [#]. *)
let rec print_arrows { domains; codomain; grade } ppf =
  List.iter (fun domain -> Format.fprintf ppf "%t → " domain) domains;
  (match codomain with
  | Plain part -> part ppf
  | Parenthesised arrows -> Format.fprintf ppf "(%t)" (print_arrows arrows));
  Option.iter (fun grade -> Format.fprintf ppf " # %t" grade) grade

(** [parenthesised_codomain grades eps ty] is whether the codomain [ty] of an
    arrow of effect grade [eps] is printed in parentheses: where it is a handler
    type, or a function type and one of the two arrows is printed with its
    effect grade. Each grade then follows its own arrow. *)
let parenthesised_codomain grades eps = function
  | TyArrow (_, CompTy (_, eps')) -> not (grades.pure eps && grades.pure eps')
  | TyHandler _ -> true
  | TyConst _ | TyApply _ | TyParam _ | TyTuple _ | TyBox _ -> false

(** [print_ty grades ty_print_param ty] prints [ty], its grades by [grades],
    with the parentheses the precedences of the types require: by decreasing
    precedence, application of a type constructor (level 1), the box (2),
    products (3), and arrows and handler types (4). *)
let rec print_ty ?max_level grades ty_print_param ty ppf =
  let aux ?max_level ty = print_ty ?max_level grades ty_print_param ty in
  let print ?at_level = Print.print ?max_level ?at_level ppf in
  match ty with
  | TyConst c -> print "%t" (Const.print_ty c)
  | TyApply (ty_name, []) -> print "%t" (TyName.print ty_name)
  | TyApply (ty_name, [ ty ]) ->
      print ~at_level:1 "%t %t" (aux ~max_level:1 ty) (TyName.print ty_name)
  | TyApply (ty_name, tys) ->
      print ~at_level:1 "%t %t"
        (Print.print_tuple aux tys)
        (TyName.print ty_name)
  | TyParam a -> print "%t" (ty_print_param a)
  | TyArrow _ ->
      print ~at_level:4 "%t"
        (print_arrows (arrow_parts grades ty_print_param ty))
  | TyTuple [] -> print "unit"
  | TyTuple tys ->
      print ~at_level:3 "%t" (Print.print_sequence " × " (aux ~max_level:2) tys)
  | TyBox (rho, ty) ->
      print ~at_level:2 "[%t]%t" (grades.rho rho) (aux ~max_level:2 ty)
  | TyHandler (CompTy (ty1, eps1), CompTy (ty2, eps2)) ->
      let computation ty eps ppf =
        if grades.pure eps then aux ~max_level:3 ty ppf
        else Format.fprintf ppf "%t # %t" (aux ~max_level:3 ty) (grades.eps eps)
      in
      print ~at_level:4 "%t ⇒ %t" (computation ty1 eps1) (computation ty2 eps2)

(** [arrow_parts grades ty_print_param ty] is [ty] as
    [print_ty grades ty_print_param ty] prints it, in parts around its arrows.
*)
and arrow_parts grades ty_print_param ty =
  let print ?max_level = print_ty ?max_level grades ty_print_param in
  match ty with
  | TyArrow (ty1, CompTy (ty2, eps)) -> (
      let domain = print ~max_level:3 ty1 in
      let grade = if grades.pure eps then None else Some (grades.eps eps) in
      match ty2 with
      | _ when parenthesised_codomain grades eps ty2 ->
          {
            domains = [ domain ];
            codomain = Parenthesised (arrow_parts grades ty_print_param ty2);
            grade;
          }
      | TyArrow _ ->
          let arrows = arrow_parts grades ty_print_param ty2 in
          { arrows with domains = domain :: arrows.domains }
      | _ ->
          {
            domains = [ domain ];
            codomain = Plain (print ~max_level:3 ty2);
            grade;
          })
  | _ -> { domains = []; codomain = Plain (print ty); grade = None }

let rec print_pattern ?max_level p ppf =
  let print ?at_level = Print.print ?max_level ?at_level ppf in
  match p.it with
  | PVar x -> print "%t" (Variable.print x)
  | PAs (p, x) -> print "%t as %t" (print_pattern p) (Variable.print x)
  | PAnnotated (p, _ty) -> print_pattern ?max_level p ppf
  | PConst c -> Const.print c ppf
  | PSucc (p, k) ->
      print ~at_level:2 "%t + %s" (print_pattern ~max_level:2 p) (Z.to_string k)
  | PTuple lst -> Print.print_tuple print_pattern lst ppf
  | PVariant (lbl, None) when Label.equal lbl nil_label -> print "[]"
  | PVariant (lbl, None) -> print "%t" (Label.print lbl)
  | PVariant (lbl, Some { it = PTuple [ v1; v2 ]; _ })
    when Label.equal lbl cons_label ->
      print "%t::%t" (print_pattern v1) (print_pattern v2)
  | PVariant (lbl, Some p) ->
      print ~at_level:1 "%t @[<hov>%t@]" (Label.print lbl)
        (print_pattern ~max_level:0 p)
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
    | Variant (lbl, None) when Label.equal lbl nil_label -> print "[]"
    | Variant (lbl, None) -> print "%t" (Label.print lbl)
    | Variant (lbl, Some { it = Tuple [ v1; v2 ]; _ })
      when Label.equal lbl cons_label ->
        print ~at_level:1 "%t::%t" (aux ~max_level:0 v1) (aux ~max_level:1 v2)
    | Variant (lbl, Some arg) ->
        print ~at_level:1 "%t %t" (Label.print lbl) (aux ~max_level:0 arg)
    | Lambda (p, c) | PureLambda (p, c) ->
        print ~at_level:2 "@[<hv 2>fun %t ↦@ %t@]" (print_pattern p)
          (print_computation resource_grade ?max_level:None c)
    | RecLambda (f, _, _) -> print ~at_level:2 "rec %t ..." (Variable.print f)
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
              Format.fprintf ppf "@,| %t"
                (print_abstraction resource_grade case))
            lst
        in
        print "@[<v 0>match %t with%t@]"
          (print_expression resource_grade ~max_level:0 e)
          print_cases
    | Apply (e1, e2) ->
        print ~at_level:1 "@[<hov 2>%t@ %t@]"
          (print_expression resource_grade ~max_level:1 e1)
          (print_expression resource_grade ~max_level:0 e2)
    | Delay (q, c) ->
        print ~at_level:1 "@[<hov 2>delay %s@ %t@]" (Grades.Rational.show q)
          (aux ~max_level:0 c)
    | Box (rho, e, (p, c)) ->
        print ~at_level:2 "@[<v 0>box %t %t as %t in@,%t@]"
          (print_rho resource_grade rho)
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

and print_op_case resource_grade (op, a) ppf =
  Format.fprintf ppf "%t %t" (OpName.print op)
    (print_abstraction resource_grade a)

let print_vars_and_exprs resource_grade print_var_and_expr
    (lst : ('var, 'map, 'rho) Ast.context_elem_ty list) ppf =
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
    | Rho n -> print_rho resource_grade n ppf
  in
  match List.rev lst with
  | [] -> Format.fprintf ppf "State: []@\n"
  | elems ->
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

let print_interpreter_state resource_grade ctx ppf =
  let print_var_and_expr (variable, (rho, expr)) ppf =
    Format.fprintf ppf "@[<hv 2>%t ↦@ %t@ # %t@]" (Variable.print variable)
      (print_expression resource_grade expr)
      (print_rho resource_grade rho)
  in
  print_vars_and_exprs resource_grade print_var_and_expr ctx ppf

let string_of_interpreter_state resource_grade context =
  Format.asprintf "%t" (print_interpreter_state resource_grade context)

let string_of_expression resource_grade e =
  Format.asprintf "%t" (print_expression resource_grade e)
