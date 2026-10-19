%{
  open SugaredAst
  open Utils
  module Grade = Grades.Grade
  module Rational = Grades.Rational

  (* The location of a pair of positions, such as [$loc]. *)
  let location (start, stop) = Location.of_lexing start stop

  (* [abstractions lambda (ps, t)] is the function [lambda] of the parameters
     [ps] and the body [t], each abstraction spanning from its parameter to the
     end of [t]. *)
  let abstractions lambda (ps, t) =
    List.fold_right
      (fun p t -> { it = lambda (p, t); at = Location.merge p.at t.at })
      ps t

  (* The hint naming the grades [names]. *)
  let suggestion names =
    let quote name = "`" ^ name ^ "`" in
    match List.rev_map quote names with
    | [] -> ""
    | [ name ] -> "; did you mean to use the " ^ name ^ " grading monoid?"
    | last :: rest ->
        "; did you mean to use one of the "
        ^ String.concat ", " (List.rev rest)
        ^ " or " ^ last ^ " grading monoids?"

  (* [grade ~loc name of_lit lit] is the grade [of_lit] reads the literal [lit]
     as. A rejection, the usual symptom of running a file under the wrong
     grades, is a syntax error at [loc] naming the grade [name]; an error
     raised without a location while reading it is pinned to [loc]. *)
  let grade ~loc name of_lit lit =
    try of_lit lit with
    | Grade.Invalid_literal (lit, reason) ->
      Error.syntax ~loc "In the `%s` grading monoid, %s%s" name reason
        (suggestion (Grades.GradeRegistry.accepting lit))
    | Error.Error ({ Diagnostic.primary = None; _ } as d) ->
      raise (Error.Error { d with Diagnostic.primary = Some loc })

  (* [delay ~loc q] is [q] if the delays of the grade system read it;
     otherwise a syntax error at [loc] naming the grades whose delays do. *)
  let delay ~loc q =
    let lit = Grade.rational_lit q in
    match GS.R.Delay.read lit with
    | Some _ -> q
    | None ->
        Error.syntax ~loc "In the `%s` grading monoid, %s%s" GS.R.name
          (GS.R.Delay.rejection lit)
          (suggestion (Grades.GradeRegistry.accepting_delay lit))

  (* [running_time_bound ~loc q] is the running-time bound [q] if the delays of
     the grade system read it or its effect grades read no running-time bounds;
     otherwise a syntax error at [loc] naming the grades that read running-time
     bounds and [q]. *)
  let running_time_bound ~loc q =
    let lit = Grade.rational_lit q in
    match GS.E.Delay.read lit with
    | Some _ -> q
    | None when not GS.E.needs_op_bounds -> q
    | None ->
        Error.syntax ~loc
          "In the `%s` grading monoid, running-time bounds are delays, and %s%s"
          GS.E.name
          (GS.E.Delay.rejection lit)
          (suggestion (Grades.GradeRegistry.accepting_bounds lit))

  (* [open_running_time ~loc lo hi] is the running-time bounds at [loc] from
     [lo] to [hi], an end open: a syntax error if the interval is empty. Where
     the effect grades read running-time bounds, an open end is the closed one
     it abbreviates over their delays ({!Grades.Grade.close_running_time}), and
     an interval without a delay a syntax error. *)
  let open_running_time ~loc lo hi =
    match Grade.emptiness lo hi with
    | Some reason -> Error.syntax ~loc "%s" (String.capitalize_ascii reason)
    | None when not GS.E.needs_op_bounds -> (lo, hi)
    | None -> (
        let lo', hi' = Grade.close_running_time GS.E.Delay.adjacent (lo, hi) in
        match Grade.emptiness lo' hi' with
        | Some _ ->
            Error.syntax ~loc
              "In the `%s` grading monoid, the interval `%s` contains no \
               whole number of time steps"
              GS.E.name
              (Grade.show_interval Rational.show lo hi)
        | None -> (lo', hi'))

  (* [small ~loc what n] is the number [n] as an OCaml [int]; a syntax error
     at [loc] naming [what] if [n] does not fit one. *)
  let small ~loc what n =
    if Z.fits_int n then Z.to_int n
    else Error.syntax ~loc "%s %s is too large" what (Z.to_string n)

  (* An endpoint of an interval literal: a grade literal, or [-∞]. *)
  type endpoint = Lit of Grade.lit | Minus_infinity

  (* [infinite_endpoint ~loc] is the syntax error at [loc] of an infinite
     endpoint written with a bracket. *)
  let infinite_endpoint ~loc =
    Error.syntax ~loc
      "An infinite endpoint of an interval is written with a parenthesis, \
       as in `[n, ∞)`"

  (* [interval ~loc ~lower_open ends ~upper_open] is the interval literal at
     [loc] with the endpoints [ends], open below iff [lower_open] and above iff
     [upper_open]. A finite endpoint is a grade literal other than [∞], and an
     infinite one is open. *)
  let interval ~loc ~lower_open ends ~upper_open =
    let forms () =
      Error.syntax ~loc
        "Intervals are written `[n, m]`, `(n, m)`, `[n, m)` or `(n, m]`, \
         with an infinite endpoint as in `[n, ∞)` or `(-∞, m]`"
    in
    match ends with
    | [ lo; hi ] ->
        let lower =
          match (lo, lower_open) with
          | Minus_infinity, true -> Grade.Unbounded
          | Minus_infinity, false -> infinite_endpoint ~loc
          | Lit Grade.Inf, _ -> forms ()
          | Lit lit, true -> Grade.Open lit
          | Lit lit, false -> Grade.Closed lit
        in
        let upper =
          match (hi, upper_open) with
          | Lit Grade.Inf, true -> Grade.Unbounded
          | Lit Grade.Inf, false -> infinite_endpoint ~loc
          | Minus_infinity, _ -> forms ()
          | Lit lit, true -> Grade.Open lit
          | Lit lit, false -> Grade.Closed lit
        in
        Grade.Interval (lower, upper)
    | _ -> forms ()

  (* [delays ~loc ~lower_open lo hi ~upper_open] is the interval atom at [loc]
     of a brace literal from the delay [lo] to the delay [hi], [None] being
     infinite, open below iff [lower_open] and above iff [upper_open]; a syntax
     error if it is empty. *)
  let delays ~loc ~lower_open lo hi ~upper_open =
    let lower = if lower_open then Grade.Open lo else Grade.Closed lo in
    let upper =
      match (hi, upper_open) with
      | None, true -> Grade.Unbounded
      | None, false -> infinite_endpoint ~loc
      | Some hi, true -> Grade.Open hi
      | Some hi, false -> Grade.Closed hi
    in
    match Grade.emptiness lower upper with
    | Some reason -> Error.syntax ~loc "%s" (String.capitalize_ascii reason)
    | None -> Grade.Delays (lower, upper)

  (* [below ~loc ~upper_open hi] is the one-sided interval atom at [loc] of
     the delays up to [hi], [None] being infinite, open iff [upper_open]; a
     syntax error if it is empty. *)
  let below ~loc ~upper_open hi =
    match (hi, upper_open) with
    | None, _ -> Grade.Below Grade.Unbounded
    | Some hi, false -> Grade.Below (Grade.Closed hi)
    | Some hi, true when Rational.sign hi > 0 -> Grade.Below (Grade.Open hi)
    | Some _, true -> Error.syntax ~loc "`<0` holds no delay"

  (* [above ~loc ~lower_open lo] is the one-sided interval atom at [loc] of
     the delays from [lo], open iff [lower_open]; a syntax error if [lo] is
     infinite. *)
  let above ~loc ~lower_open lo =
    match lo with
    | None ->
        Error.syntax ~loc "`%s∞` holds no delay"
          (if lower_open then ">" else "≥")
    | Some lo when lower_open -> Grade.Above (Grade.Open lo)
    | Some lo -> Grade.Above (Grade.Closed lo)

  (* [count ~loc ~lower_open m n ~upper_open] is the count at [loc] of a
     bounded repetition from [m] to [n], [None] being infinite, open below iff
     [lower_open] and above iff [upper_open]: an open endpoint abbreviates the
     closed one next to it over the natural numbers. A syntax error if the
     interval holds no natural number. *)
  let count ~loc ~lower_open m n ~upper_open =
    let least = if lower_open then m + 1 else m in
    let most =
      match (n, upper_open) with
      | None, true -> None
      | None, false -> infinite_endpoint ~loc
      | Some n, true -> Some (n - 1)
      | Some n, false -> Some n
    in
    match most with
    | Some most when most < least ->
        Error.syntax ~loc
          "The count of a repetition `^` holds no natural number"
    | most -> Grades.Count.make least most

  (* The name of the operator [op] in parentheses, as in OCaml separated from
     them by spaces if it begins with an asterisk, which would otherwise open a
     comment. *)
  let operator_name op =
    if String.starts_with ~prefix:"*" op then "( " ^ op ^ " )"
    else "(" ^ op ^ ")"

  (* The literals written as lowercase names. *)
  let named_lit ~loc = function
    | "top" -> Grade.Top
    | "inf" -> Grade.Inf
    | name ->
        Error.syntax ~loc
          "`%s` is no grade literal; grades are written as integers, \
           fractions such as `3/2` or `1.5`, names such as `High`, `⊤` (ASCII \
           `top`), `∞` (ASCII `inf`), tuples `(...)`, intervals `[...]` and \
           brace literals `{...}`" name
%}

%parameter<GS : Grades.GradeSystem.S>

(* Precedences, by increasing strength. As in OCaml, a [let], [match],
   [function], [fun] or [handler] extends as far to the right as possible, and
   so does a nested [match], [function] or [handler] over the cases [| ...]
   that follow it ([below_BAR] below [BAR]). A [box] or [unbox] without a
   continuation, a [handle] and a [continue] end before [;], as an
   application does; a [box] or [unbox] followed by [as] has a continuation
   ([below_AS] below [AS]). *)
%nonassoc ARROW IN
%nonassoc below_BAR
%nonassoc BAR
%nonassoc HASH
%right SEMI
%nonassoc ELSE
%nonassoc below_AS
%nonassoc AS
%right OR BARBAR
%right AMPER AMPERAMPER
%left  INFIXOP0 EQUAL
%right INFIXOP1
%right CONS
%left  INFIXOP2 PLUS MINUS MINUSDOT
%left  INFIXOP3 STAR MOD LAND LOR LXOR
%right INFIXOP4 LSL LSR ASR

%start <(GS.R.t grade annotated, GS.E.t grade annotated) SugaredAst.term> payload
%start <(GS.R.t grade annotated, GS.E.t grade annotated) SugaredAst.command list> commands

%%

(* Toplevel syntax *)

(* A program is a sequence of commands up to the end of the file, with no
   terminator after the last. *)
commands:
  | EOF
     { [] }
  | cmd = command cmds = commands
     { cmd :: cmds }

(* Things that can be defined on toplevel. *)
command: mark_position(plain_command) { $1 }
plain_command:
  | TYPE defs = separated_nonempty_list(AND, ty_def)
    { TyDef (Language.Ast.Derived, defs) }
  | NONETERNAL TYPE defs = separated_nonempty_list(AND, ty_def)
    { TyDef (Language.Ast.Noneternal, defs) }
  | OPERATION op = mark_position(UNAME) COLON ty1 = ty SIGARROW ty2 = ty HASH eps = eps_grade
    bounds = option(op_bounds)
    { OpSig (op, ty1, ty2, eps, bounds) }
  | DEFAULT op = mark_position(UNAME) p = simple_pattern EQUAL t = term
    { OpDefault (op, (p, t)) }
  | LET x = mark_position(ident) t = lambdas0(EQUAL, ty)
    { TopLet (x, t) }
  | LET REC def = let_rec_def
    { let (f, t) = def in TopLetRec (f, t) }
  | RUN trm = term
    { TopDo trm }

payload:
  | trm = term EOF
    { trm }

(* Main syntax tree *)

term: mark_position(plain_term) { $1 }
plain_term:
  | MATCH t = term WITH cases = cases0(case)
    { Match (t, cases) }
  | FUNCTION cases = cases(case)
    { Function cases }
  | FUN t = lambdas1(ARROW, prod_ty)
    { t.it }
  | LET def = let_def IN t2 = term
    { let (p, t1) = def in Let (p, t1, t2) }
  | LET REC def = let_rec_def IN t2 = term
    { let (f, t1) = def in LetRec (f, t1, t2) }
  | t1 = term SEMI t2 = term
    { Let ({it= PNonbinding; at= t1.at}, t1, t2) }
  | IF t_cond = comma_term THEN t_true = term ELSE t_false = term
    { Conditional (t_cond, t_true, t_false) }
  | DELAY q = duration
    { Delay (delay ~loc:(location $loc(q)) q) }
  (* Any other argument of [delay], read up to the token that ends the
     duration. *)
  | DELAY error
    { Error.syntax ~loc:(location $loc($2))
        "The argument of `delay` is a duration literal, such as `2`, `1/2` \
         or `0.25`" }
  | BOX rho = rho_grade e = term AS p = pattern IN c = term
    { Box (rho, e, (p, c)) }
  | BOX rho = rho_grade e = term %prec below_AS
    { GenBox (rho, e) }
  | UNBOX e = term AS p = pattern IN c = term
    { Unbox (e, (p, c)) }
  | UNBOX e = term %prec below_AS
    { GenUnbox (e) }
  | PERFORM op = mark_position(UNAME) e = comma_term
    { Perform (op, e) }
  | HANDLER BAR? ret_case = case %prec below_BAR
    { Handler (ret_case, []) }
  | HANDLER BAR? ret_case = case op_cases = bar_cases0(op_case)
    { Handler (ret_case, op_cases) }
  | HANDLE c = term WITH h = term %prec below_AS
    { Handle (c, h) }
  | CONTINUE k = term WITH e = term %prec below_AS
    { Continue (k, e) }
  | t = plain_comma_term
    { t }

comma_term: mark_position(plain_comma_term) { $1 }
plain_comma_term:
  | t = binop_term COMMA ts = separated_list(COMMA, binop_term)
    { Tuple (t :: ts) }
  | t = plain_binop_term
    { t }

binop_term: mark_position(plain_binop_term) { $1 }
plain_binop_term:
  | t1 = binop_term op = binop t2 = binop_term
    { let op_loc = location $loc(op) in
      Apply ({it= Apply ({it= Var op; at= op_loc}, t1); at= Location.merge op_loc t1.at}, t2) }
  | t1 = binop_term CONS t2 = binop_term
    { let tuple = {it= Tuple [t1; t2]; at= location $loc} in
      Variant ({it= cons_label; at= location $loc($2)}, Some tuple) }
  | t = plain_uminus_term
    { t }

uminus_term: mark_position(plain_uminus_term) { $1 }
plain_uminus_term:
  (* As in OCaml, the negation of a float or integer literal is a literal. *)
  | MINUS t = uminus_term
    { match t.it with
      | Const (Language.Const.Float f) -> Const (Language.Const.of_float (-. f))
      | Const (Language.Const.Int n) -> Const (Language.Const.of_int (Z.neg n))
      | _ ->
          Error.syntax ~loc:(location $loc)
            "Natural numbers have no negation; floats are negated with `-.` \
             and integers with `~-!`" }
  | MINUSDOT t = uminus_term
    { let op_loc = location $loc($1) in
      Apply ({it= Var "(~-.)"; at= op_loc}, t) }
  | t = plain_app_term
    { t }

plain_app_term:
  | t = prefix_term ts = prefix_term+
    {
      match t.it, ts with
      | Variant (lbl, None), [t] -> Variant (lbl, Some t)
      | Variant (lbl, _), _ -> Error.syntax ~loc:(t.at) "Label %s applied to too many arguments" lbl.it
      | _, _ ->
        let apply t1 t2 = {it= Apply(t1, t2); at= Location.merge t1.at t2.at} in
        (List.fold_left apply t ts).it
    }
  | t = plain_prefix_term
    { t }

prefix_term: mark_position(plain_prefix_term) { $1 }
plain_prefix_term:
  | op = prefixop t = simple_term
    {
      let op_loc = location $loc(op) in
      Apply ({it= Var op; at= op_loc}, t)
    }
  | t = plain_simple_term
    { t }

simple_term: mark_position(plain_simple_term) { $1 }
plain_simple_term:
  | x = ident
    { Var x }
  | lbl = mark_position(UNAME)
    { Variant (lbl, None) }
  | cst = const
    { Const cst }
  | LBRACK ts = separated_list(SEMI, comma_term) RBRACK
    {
      let nil_at = Location.of_lexing $endpos $endpos in
      let nil = {it= Variant ({it= nil_label; at= nil_at}, None); at= nil_at} in
      let cons t ts =
        let loc = Location.merge t.at ts.at in
        let tuple = {it= Tuple [t; ts];at= loc} in
        {it= Variant ({it= cons_label; at= loc}, Some tuple); at= loc}
      in
      (List.fold_right cons ts nil).it
    }
  | LPAREN RPAREN
    { Tuple [] }
  | LPAREN t = term COLON ty = ty RPAREN
    { Annotated (t, ty) }
  | LPAREN t = plain_term RPAREN
    { t }
  | BEGIN t = plain_term END
    { t }

(* Auxilliary definitions *)

const:
  | n = INT
    { Language.Const.of_nat n }
  | n = INTEGER
    { Language.Const.of_int n }
  | str = STRING
    { Language.Const.of_string str }
  | b = BOOL
    { Language.Const.of_boolean b }
  | f = FLOAT
    { Language.Const.of_float (float_of_string f) }

case:
  | p = pattern ARROW t = term
    { (p, t) }

(* An operation case [Op p k -> t], its argument and continuation patterns
   simple, as the arguments of a constructor are. *)
op_case:
  | op = UNAME p = simple_pattern k = simple_pattern ARROW t = term
    { (op, ({it= PTuple [p; k]; at= location $loc}, t)) }

(* Parameters, an optional annotation of the result by a type of [TY], and the
   body after [SEP]: the parameters, and the body with its annotation. After
   [fun] the annotation is a type without an arrow at its top, as the arrow of
   [fun] would otherwise be read as one of the type; an arrow type is
   parenthesised there. *)
parameters(SEP, TY):
  | SEP t = term
    { ([], t) }
  | p = simple_pattern ps = parameters(SEP, TY)
    { let ps, t = ps in (p :: ps, t) }
  | COLON ty = TY SEP t = term
    { ([], {it= Annotated (t, ty); at= location $loc}) }
  | COLON ty = TY HASH eps = eps_grade SEP t = term
    { ([], {it= AnnotatedComp (t, ty, eps); at= location $loc}) }

(* A function of any number of parameters, and of one at least. *)
lambdas0(SEP, TY):
  | ps = parameters(SEP, TY)
    { abstractions (fun abs -> Lambda abs) ps }

lambdas1(SEP, TY):
  | p = simple_pattern ps = parameters(SEP, TY)
    { let ps, t = ps in abstractions (fun abs -> Lambda abs) (p :: ps, t) }

(* The parameters of a recursive function. *)
pure_lambdas(SEP):
  | ps = parameters(SEP, ty)
    { abstractions (fun abs -> PureLambda abs) ps }

let_def:
  | p = pattern EQUAL t = term
    { (p, t) }
  | p = pattern COLON ty= ty EQUAL t = term
    { (p, {it= Annotated(t, ty); at= location $loc}) }
  | x = mark_position(ident) t = lambdas1(EQUAL, ty)
    { ({it= PVar x.it; at= x.at}, t) }

let_rec_def:
  | f = mark_position(ident) t = pure_lambdas(EQUAL)
    { (f, t) }

pattern: mark_position(plain_pattern) { $1 }
plain_pattern:
  | p = comma_pattern
    { p.it }
  | p = pattern AS x = mark_position(lname)
    { PAs (p, x) }

comma_pattern: mark_position(plain_comma_pattern) { $1 }
plain_comma_pattern:
  | ps = separated_nonempty_list(COMMA, cons_pattern)
    { match ps with [p] -> p.it | ps -> PTuple ps }

cons_pattern: mark_position(plain_cons_pattern) { $1 }
plain_cons_pattern:
  | p = succ_pattern
    { p.it }
  | p1 = succ_pattern CONS p2 = cons_pattern
    { let ptuple = {it= PTuple [p1; p2]; at= location $loc} in
      PVariant ({it= cons_label; at= location $loc($2)}, Some ptuple) }

succ_pattern: mark_position(plain_succ_pattern) { $1 }
plain_succ_pattern:
  | p = variant_pattern
    { p.it }
  | p = succ_pattern PLUS k = INT
    { if Z.sign k > 0 then PSucc (p, k)
      else
        Error.syntax ~loc:(location $loc(k))
          "The number added in a successor pattern must be positive" }

variant_pattern: mark_position(plain_variant_pattern) { $1 }
plain_variant_pattern:
  | lbl = mark_position(UNAME) p = simple_pattern
    { PVariant (lbl, Some p) }
  | p = simple_pattern
    { p.it }

simple_pattern: mark_position(plain_simple_pattern) { $1 }
plain_simple_pattern:
  | x = ident
    { PVar x }
  | lbl = mark_position(UNAME)
    { PVariant (lbl, None) }
  | UNDERSCORE
    { PNonbinding }
  | cst = const
    { PConst cst }
  | MINUS f = FLOAT
    { PConst (Language.Const.of_float (-. float_of_string f)) }
  | MINUS n = INTEGER
    { PConst (Language.Const.of_int (Z.neg n)) }
  | LBRACK ts = separated_list(SEMI, pattern) RBRACK
    {
      let nil_at = Location.of_lexing $endpos $endpos in
      let nil = {it= PVariant ({it= nil_label; at= nil_at}, None); at= nil_at} in
      let cons t ts =
        let loc = Location.merge t.at ts.at in
        let tuple = {it= PTuple [t; ts]; at= loc} in
        {it= PVariant ({it= cons_label; at= loc}, Some tuple); at= loc}
      in
      (List.fold_right cons ts nil).it
    }
  | LPAREN RPAREN
    { PTuple [] }
  | LPAREN p = pattern COLON t = ty RPAREN
    { PAnnotated (p, t) }
  | LPAREN p = pattern RPAREN
    { p.it }

lname:
  | x = LNAME
    { x }

tyname:
  | t = lname
    { t }

ident:
  | x = lname
    { x }
  | LPAREN op = binop RPAREN
    { op }
  | LPAREN op = prefixop RPAREN
    { op }

%inline binop:
  | op = binop_symbol
    { operator_name op }

%inline binop_symbol:
  | OR
    { "or" }
  | BARBAR
    { "||" }
  | AMPER
    { "&" }
  | AMPERAMPER
    { "&&" }
  | op = INFIXOP0
    { op }
  | op = INFIXOP1
    { op }
  | op = INFIXOP2
    { op }
  | PLUS
    { "+" }
  | MINUSDOT
    { "-." }
  | MINUS
    { "-" }
  | EQUAL
    { "=" }
  | op = INFIXOP3
    { op }
  | STAR
    { "*" }
  | op = INFIXOP4
    { op }
  | MOD
    { "mod" }
  | LAND
    { "land" }
  | LOR
    { "lor" }
  | LXOR
    { "lxor" }
  | LSL
    { "lsl" }
  | LSR
    { "lsr" }
  | ASR
    { "asr" }

%inline prefixop:
  | op = PREFIXOP
    { "(" ^ op ^ ")" }

(* Cases separated by [|], the first optionally preceded by one. A nested
   [match], [function] or [handler] takes the cases that follow it. *)
cases0(case):
  | %prec below_BAR
    { [] }
  | cs = cases(case)
    { cs }

bar_cases0(case):
  | BAR
    { [] }
  | BAR cs = case_list(case)
    { cs }

cases(case):
  | cs = case_list(case)
    { cs }
  | BAR cs = case_list(case)
    { cs }

case_list(case):
  | c = case %prec below_BAR
    { [ c ] }
  | c = case BAR cs = case_list(case)
    { c :: cs }

mark_position(X):
  x = X
  { {it= x; at= location $loc}}

params:
  |
    { [] }
  | p = PARAM
    { [p] }
  | LPAREN ps = separated_nonempty_list(COMMA, PARAM) RPAREN
    { ps }

ty_def:
  | ps = params t = mark_position(tyname) EQUAL x = defined_ty
    { (ps, t, x) }

defined_ty:
  | variants = cases(sum_case)
    { TySum variants }
  | t = ty
    { TyInline t }

(* Types, by decreasing precedence: application of a type constructor
   [α list], the box [[ρ]α], products [α * β], n-ary and non-associative, and
   arrows [α -> β # ε], right-associative, an effect [# ε] belonging to the
   innermost arrow. *)
ty: mark_position(plain_ty) { $1 }
plain_ty:
  | t1 = prod_ty ARROW t2 = ty HASH eps = eps_grade
    { TyArrow (t1, CompTy (t2, eps)) }
  | t1 = prod_ty ARROW t2 = ty
    { let at = location $loc in
      TyArrow (t1, CompTy (t2, { it = GradeLit GS.E.one; at })) }
  | t = prod_ty
    { t.it }

prod_ty: mark_position(plain_prod_ty) { $1 }
plain_prod_ty:
  | ts = separated_nonempty_list(STAR, box_ty)
    {
      match ts with
      | [t] -> t.it
      | ts -> TyTuple ts
     }

box_ty: mark_position(plain_box_ty) { $1 }
plain_box_ty:
  | LBRACK rho = rho_grade RBRACK ty = box_ty
    { TyBox (rho, ty) }
  | t = plain_ty_apply
    { t }

ty_apply: mark_position(plain_ty_apply) { $1 }
plain_ty_apply:
  | LPAREN t = ty COMMA ts = separated_nonempty_list(COMMA, ty) RPAREN t2 = mark_position(tyname)
    { TyApply (t2, (t :: ts)) }
  | t = ty_apply t2 = mark_position(tyname)
    { TyApply (t2, [t]) }
  | t = plain_simple_ty
    { t }

plain_simple_ty:
  | t = mark_position(tyname)
    { TyApply (t, []) }
  | t = PARAM
    { TyParam t }
  | LPAREN t = ty RPAREN
    { t.it }

sum_case:
  | lbl = mark_position(UNAME)
    { (lbl, None) }
  | lbl = mark_position(UNAME) OF t = ty
    { (lbl, Some t) }

(* The running-time bounds an operation declares, an interval of durations with
   finite ends, each closed or open; [within n] is sugar for [within [n, n]].
   Only the grading monoids of timed operations read them. *)
op_bounds:
  | WITHIN n = running_time_bound
    { (Grade.Closed n, Grade.Closed n) }
  | WITHIN LBRACK n = running_time_bound COMMA m = running_time_bound RBRACK
    { (Grade.Closed n, Grade.Closed m) }
  | WITHIN LBRACK n = running_time_bound COMMA m = running_time_bound RPAREN
    { open_running_time ~loc:(Location.of_lexing $startpos($2) $endpos)
        (Grade.Closed n) (Grade.Open m) }
  | WITHIN LPAREN n = running_time_bound COMMA m = running_time_bound RBRACK
    { open_running_time ~loc:(Location.of_lexing $startpos($2) $endpos)
        (Grade.Open n) (Grade.Closed m) }
  | WITHIN LPAREN n = running_time_bound COMMA m = running_time_bound RPAREN
    { open_running_time ~loc:(Location.of_lexing $startpos($2) $endpos)
        (Grade.Open n) (Grade.Open m) }

(* A running-time bound, a duration read as a delay. *)
running_time_bound:
  | q = duration
    { running_time_bound ~loc:(location $loc) q }

(* A resource grade, a literal read by the resource grades of the grade system
   or a grade variable, at its location. *)
rho_grade:
  | lit = grade_lit
    { let at = location $loc in
      { it = GradeLit (grade ~loc:at GS.R.name GS.R.of_lit lit); at } }
  | p = PARAM
    { { it = GradeParam p; at = location $loc } }

(* An effect grade, a literal read by the effect grades of the grade system or
   a grade variable, at its location. *)
eps_grade:
  | lit = grade_lit
    { let at = location $loc in
      { it = GradeLit (grade ~loc:at GS.E.name GS.E.of_lit lit); at } }
  | p = PARAM
    { { it = GradeParam p; at = location $loc } }

(* A non-negative duration: an integer or a fraction. *)
duration:
  | n = INT { Rational.of_z n }
  | q = fraction { q }
  | MINUS INT | MINUS fraction
    { Error.syntax ~loc:(location $loc)
        "Durations must be non-negative" }

(* A fraction, exact: a decimal, or the quotient of two integers. *)
fraction:
  | f = FLOAT { Rational.of_decimal f }
  | n = INT op = INFIXOP3 d = INT
    { if op <> "/" then
        Error.syntax ~loc:(location $loc(op))
          "Unknown operator `%s` in a fraction" op
      else if Z.equal d Z.zero then
        Error.syntax ~loc:(location $loc(d))
          "Fractions have positive denominators"
      else Rational.make_z n d }

(* A grade literal, shared by all grades; each grade reads the forms it
   understands. *)
grade_lit:
  | n = INT
    { Grade.Int (small ~loc:(location $loc) "Grade literal" n) }
  | q = fraction { Grade.rational_lit q }
  | MINUS n = INT
    { Grade.Int (- small ~loc:(location $loc) "Grade literal" n) }
  | MINUS q = fraction { Grade.rational_lit (Rational.neg q) }
  | UNDERSCORE { Grade.Name "_" }
  | name = UNAME { Grade.Name name }
  | TOP { Grade.Top }
  | INFINITY { Grade.Inf }
  | NEQ { Grade.Name "≠" }
  | name = LNAME { named_lit ~loc:(location $loc) name }
  | LPAREN lit = grade_lit COMMA lits = separated_nonempty_list(COMMA, grade_lit) RPAREN
    { Grade.Tuple (lit :: lits) }
  | lit = interval_lit { lit }
  | LBRACE r = regex RBRACE { Grade.Braces r }

(* An interval of grade literals, each finite endpoint closed or open and each
   infinite one open: [[n, m]], [[n, m)], [(n, m]], [[n, ∞)], [(-∞, m]],
   [(-∞, m)] or [(-∞, ∞)]. An open interval [(n, m)] of finite endpoints is
   the tuple [(n, m)], which the grades that read intervals of numbers read as
   such. Any other bracketing of two endpoints is a syntax error. *)
interval_lit:
  | LBRACK ends = separated_nonempty_list(COMMA, endpoint) RBRACK
    { interval ~loc:(location $loc)
        ~lower_open:false ends ~upper_open:false }
  | LBRACK ends = separated_nonempty_list(COMMA, endpoint) RPAREN
    { interval ~loc:(location $loc)
        ~lower_open:false ends ~upper_open:true }
  | LPAREN lo = minus_infinity COMMA ends = separated_nonempty_list(COMMA, endpoint) RBRACK
    { interval ~loc:(location $loc)
        ~lower_open:true (lo :: ends) ~upper_open:false }
  | LPAREN lo = minus_infinity COMMA ends = separated_nonempty_list(COMMA, endpoint) RPAREN
    { interval ~loc:(location $loc)
        ~lower_open:true (lo :: ends) ~upper_open:true }
  | LPAREN lit = grade_lit COMMA lits = separated_nonempty_list(COMMA, grade_lit) RBRACK
    { interval ~loc:(location $loc)
        ~lower_open:true (List.map (fun lit -> Lit lit) (lit :: lits))
        ~upper_open:false }

endpoint:
  | lit = grade_lit { Lit lit }
  | e = minus_infinity { e }

(* The endpoint [-∞] (ASCII [-inf]). *)
minus_infinity:
  | MINUS INFINITY { Minus_infinity }
  | MINUS name = LNAME
    { if name = "inf" then Minus_infinity
      else
        Error.syntax ~loc:(location $loc)
          "`-%s` is no grade literal" name }

(* The regular expressions of brace literals, by increasing precedence: union
   [|], intersection [&], concatenation [;], complement [~] and repetition
   [*], bounded repetition [r^n], [r^[m, n]] or [r^[m, ∞)] and the optional
   [r?], which is [(r | 0)], the strict delay [!] binding as the complement
   but applying to the operand of a repetition [*]; [!r^c] is the strict
   delay of the delays of [r^c], and [(!r)^c] a repetition of strict delays.
   Braces group as parentheses do. An atom is an operation name, a delay,
   the wildcard [_], an interval of delays [[a, b]], [(a, b)], [[a, b)],
   [(a, b]], [[a, ∞)] or [(a, ∞)], or a one-sided interval of delays [≤d],
   [<d], [≥d] or [>d] (ASCII [<=d] and [>=d]), [≤∞] and [<∞] being all
   delays; a parenthesis followed by a delay and a comma opens an interval,
   and otherwise a group. *)
regex:
  | r = regex_inter { r }
  | r = regex BAR s = regex_inter { Grade.Union (r, s) }

regex_inter:
  | r = regex_seq { r }
  | r = regex_inter AMPER s = regex_seq { Grade.Inter (r, s) }

regex_seq:
  | r = regex_unary { r }
  | r = regex_seq SEMI s = regex_unary { Grade.Seq (r, s) }

regex_unary:
  | r = regex_postfix { r }
  | op = PREFIXOP r = regex_unary
    { if op = "~" then Grade.Compl r
      else
        Error.syntax ~loc:(location $loc(op))
          "Unknown operator `%s` in a brace literal" op }
  | BANG r = regex_unary
    { (* [!] binds to the operand of a repetition: [!_*] is [(!_)*]. *)
      let rec strict = function
        | Grade.Star r -> Grade.Star (strict r)
        | Grade.Compl s as r when Grade.delays_only s -> Grade.Strict r
        | r when r = Grade.Any || Grade.delays_only r -> Grade.Strict r
        | r ->
            Error.syntax ~loc:(location $loc(r))
              "A strict wait `!` applies to a length or an interval of \
               lengths, not to `%s`" (Grade.show_regex r)
      in
      strict r }

regex_postfix:
  | r = regex_atom { r }
  | r = regex_postfix STAR { Grade.Star r }
  | r = regex_postfix CARET c = repeat_count { Grade.Repeat (r, c) }
  | r = regex_postfix QUESTION { Grade.Union (r, Grade.Tick 0) }

(* The count of a bounded repetition: a natural number [n], or an interval
   [[m, n]], [(m, n)], [[m, n)], [(m, n]], [[m, ∞)] or [(m, ∞)] of natural
   numbers, an open endpoint abbreviating the closed one next to it. *)
repeat_count:
  | n = INT
    { let n = small ~loc:(location $loc) "Count" n in
      Grades.Count.make n (Some n) }
  | LBRACK m = count_int COMMA n = count_end RBRACK
    { count ~loc:(location $loc) ~lower_open:false m n ~upper_open:false }
  | LBRACK m = count_int COMMA n = count_end RPAREN
    { count ~loc:(location $loc) ~lower_open:false m n ~upper_open:true }
  | LPAREN m = count_int COMMA n = count_end RBRACK
    { count ~loc:(location $loc) ~lower_open:true m n ~upper_open:false }
  | LPAREN m = count_int COMMA n = count_end RPAREN
    { count ~loc:(location $loc) ~lower_open:true m n ~upper_open:true }

count_int:
  | n = INT { small ~loc:(location $loc) "Count" n }

(* The upper endpoint of a count: a natural number, or [∞] (ASCII [inf]),
   [None]. *)
count_end:
  | n = count_int { Some n }
  | INFINITY { None }
  | name = LNAME
    { if name = "inf" then None
      else
        Error.syntax ~loc:(location $loc)
          "`%s` is no count" name }

regex_atom:
  | name = UNAME { Grade.Letter name }
  | n = INT
    { Grade.Tick (small ~loc:(location $loc) "Grade literal" n) }
  | q = fraction { Grade.rational_tick q }
  | LBRACK lo = duration COMMA hi = delay_end RBRACK
    { delays ~loc:(location $loc)
        ~lower_open:false lo hi ~upper_open:false }
  | LBRACK lo = duration COMMA hi = delay_end RPAREN
    { delays ~loc:(location $loc)
        ~lower_open:false lo hi ~upper_open:true }
  | LPAREN lo = duration COMMA hi = delay_end RBRACK
    { delays ~loc:(location $loc)
        ~lower_open:true lo hi ~upper_open:false }
  | LPAREN lo = duration COMMA hi = delay_end RPAREN
    { delays ~loc:(location $loc)
        ~lower_open:true lo hi ~upper_open:true }
  | UNDERSCORE { Grade.Any }
  | LEQ hi = delay_end { below ~loc:(location $loc) ~upper_open:false hi }
  | LT hi = delay_end { below ~loc:(location $loc) ~upper_open:true hi }
  | GEQ lo = delay_end { above ~loc:(location $loc) ~lower_open:false lo }
  | GT lo = delay_end { above ~loc:(location $loc) ~lower_open:true lo }
  | LPAREN r = regex RPAREN { r }
  | LBRACE r = regex RBRACE { r }

(* The upper endpoint of an interval of delays: a delay, or [∞] (ASCII
   [inf]), [None]. *)
delay_end:
  | q = duration { Some q }
  | INFINITY { None }
  | name = LNAME
    { if name = "inf" then None
      else
        Error.syntax ~loc:(location $loc)
          "`%s` is no delay" name }

%%
