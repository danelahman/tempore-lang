%{
  open SugaredAst
  open Utils
  module Grade = Grades.Grade
  module Rational = Grades.Rational

  (* The hint naming the grades [names]. *)
  let suggestion names =
    let quote name = "'" ^ name ^ "'" in
    match List.map quote names with
    | [] -> ""
    | [ name ] -> "; did you mean to use the " ^ name ^ " grading monoid?"
    | names ->
        let rev = List.rev names in
        "; did you mean to use one of the "
        ^ String.concat ", " (List.rev (List.tl rev))
        ^ " or " ^ List.hd rev ^ " grading monoids?"

  (* [grade ~loc name of_lit lit] is the grade [of_lit] reads the literal [lit]
     as. A rejection, the usual symptom of running a file under the wrong
     grades, is a syntax error at [loc] naming the grade [name]. *)
  let grade ~loc name of_lit lit =
    try of_lit lit
    with Grade.Invalid_literal (lit, reason) ->
      Error.syntax ~loc "in the '%s' grading monoid, %s%s" name reason
        (suggestion (Grades.GradeRegistry.accepting lit))

  (* [delay ~loc q] is [q] if the delays of the grade system read it;
     otherwise a syntax error at [loc] naming the grades whose delays do. *)
  let delay ~loc q =
    let lit = Grade.rational_lit q in
    match GS.R.Delay.read lit with
    | Some _ -> q
    | None ->
        Error.syntax ~loc "in the '%s' grading monoid, %s%s" GS.R.name
          (GS.R.Delay.rejection lit)
          (suggestion (Grades.GradeRegistry.accepting_delay lit))

  (* [runtime_bound ~loc q] is the runtime bound [q] if the delays of the
     grade system read it or its effect grades read no runtime bounds;
     otherwise a syntax error at [loc] naming the grades that read runtime
     bounds and [q]. *)
  let runtime_bound ~loc q =
    let lit = Grade.rational_lit q in
    match GS.E.Delay.read lit with
    | Some _ -> q
    | None when not GS.E.needs_op_bounds -> q
    | None ->
        Error.syntax ~loc
          "in the '%s' grading monoid, runtime bounds are delays, and %s%s"
          GS.E.name
          (GS.E.Delay.rejection lit)
          (suggestion (Grades.GradeRegistry.accepting_bounds lit))

  (* [open_runtime ~loc lo hi] is the runtime bounds at [loc] from [lo] to
     [hi], an end open: a syntax error if the interval is empty. Where the
     effect grades read runtime bounds, an open end is the closed one it
     abbreviates over their delays ({!Grades.Grade.close_runtime}), and an
     interval without a delay a syntax error. *)
  let open_runtime ~loc lo hi =
    match Grade.emptiness lo hi with
    | Some reason -> Error.syntax ~loc "%s" reason
    | None when not GS.E.needs_op_bounds -> (lo, hi)
    | None -> (
        let lo', hi' = Grade.close_runtime GS.E.Delay.adjacent (lo, hi) in
        match Grade.emptiness lo' hi' with
        | Some _ ->
            Error.syntax ~loc
              "in the '%s' grading monoid, the interval '%s' contains no \
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
      "an infinite endpoint of an interval is written with a parenthesis, \
       as in '[n, ∞)'"

  (* [interval ~loc ~lower_open ends ~upper_open] is the interval literal at
     [loc] with the endpoints [ends], open below iff [lower_open] and above iff
     [upper_open]. A finite endpoint is a grade literal other than [∞], and an
     infinite one is open. *)
  let interval ~loc ~lower_open ends ~upper_open =
    let forms () =
      Error.syntax ~loc
        "intervals are written '[n, m]', '(n, m)', '[n, m)' or '(n, m]', \
         with an infinite endpoint as in '[n, ∞)' or '(-∞, m]'"
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
    | Some reason -> Error.syntax ~loc "%s" reason
    | None -> Grade.Delays (lower, upper)

  (* The literals written as lowercase names. *)
  let named_lit ~loc = function
    | "top" -> Grade.Top
    | "inf" -> Grade.Inf
    | name ->
        Error.syntax ~loc
          "'%s' is no grade literal; grades are written as integers, \
           fractions such as '3/2' or '1.5', names such as 'High', '⊤' (ASCII \
           'top'), '∞' (ASCII 'inf'), tuples '(...)', intervals '[...]' and \
           brace literals '{...}'" name
%}

%parameter<GS : Grades.GradeSystem.S>

%token LPAREN RPAREN LBRACK RBRACK LBRACE RBRACE
%token COLON COMMA SEMI EQUAL CONS
%token BEGIN END
%token <string> LNAME
%token UNDERSCORE AS
%token <Z.t> INT
%token <string> STRING
%token <bool> BOOL
%token <string> FLOAT
%token <SugaredAst.label> UNAME
%token <SugaredAst.ty_param> PARAM
%token TYPE NONETERNAL OPERATION DEFAULT WITHIN ARROW SIGARROW OF HASH
%token MATCH WITH FUNCTION HANDLER HANDLE CONTINUE
%token RUN LET REC AND IN
%token DELAY BOX UNBOX PERFORM
%token FUN BAR BARBAR
%token IF THEN ELSE
%token PLUS STAR MINUS MINUSDOT
%token LSL LSR ASR
%token MOD OR
%token AMPER AMPERAMPER
%token LAND LOR LXOR
%token <string> PREFIXOP INFIXOP0 INFIXOP1 INFIXOP2 INFIXOP3 INFIXOP4
%token TOP INFINITY NEQ
%token EOF

%nonassoc ARROW IN
%nonassoc HASH
%right SEMI
%nonassoc ELSE
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

(* If you're going to "optimize" this, please make sure we don't require ;; at the
   end of the file. *)
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
  | DEFAULT op = UNAME p = simple_pattern EQUAL t = term
    { OpDefault (op, (p, t)) }
  | LET x = mark_position(ident) t = lambdas0(EQUAL)
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
  | MATCH t = term WITH cases = cases0(case) (* END *)
    { Match (t, cases) }
  | FUNCTION cases = cases(case) (* END *)
    { Function cases }
  | FUN t = lambdas1(ARROW)
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
    { Delay (delay ~loc:(Location.of_lexing $startpos(q) $endpos(q)) q) }
  | BOX rho = rho_grade e = term AS p = pattern IN c = term
    { Box (rho, e, (p, c)) }
  | BOX rho = rho_grade e = term
    { GenBox (rho, e) }
  | UNBOX e = term AS p = pattern IN c = term
    { Unbox (e, (p, c)) }
  | UNBOX e = term
    { GenUnbox (e) }
  | PERFORM op = mark_position(UNAME) e = comma_term
    { Perform (op, e) }
  | HANDLER BAR? ret_case = case
    { Handler (ret_case, []) }
  | HANDLER BAR? ret_case = case op_cases = bar_cases0(op_case)
    { Handler (ret_case, op_cases) }
  | HANDLE c = term WITH h = term
    { Handle (c, h) }
  | CONTINUE k = term WITH e = term 
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
    { let op_loc = Location.of_lexing $startpos(op) $endpos(op) in
      Apply ({it= Apply ({it= Var op; at= op_loc}, t1); at= Location.merge op_loc t1.at}, t2) }
  | t1 = binop_term CONS t2 = binop_term
    { let tuple = {it= Tuple [t1; t2]; at= Location.of_lexing $startpos $endpos} in
      Variant ({it= cons_label; at= Location.of_lexing $startpos($2) $endpos($2)}, Some tuple) }
  | t = plain_uminus_term
    { t }

uminus_term: mark_position(plain_uminus_term) { $1 }
plain_uminus_term:
  | MINUS uminus_term
    { Error.syntax ~loc:(Location.of_lexing $startpos $endpos)
        "Natural numbers have no negation" }
  | MINUSDOT t = uminus_term
    { let op_loc = Location.of_lexing $startpos($1) $endpos($1) in
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
      let op_loc = Location.of_lexing $startpos(op) $endpos(op) in
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
  | str = STRING
    { Language.Const.of_string str }
  | b = BOOL
    { Language.Const.of_boolean b }
  | f = FLOAT
    { Language.Const.of_float (float_of_string f) }

case:
  | p = pattern ARROW t = term
    { (p, t) }

op_case:
  | op = UNAME p = pattern k = pattern ARROW t = term
    { (op, ({it= PTuple [p; k]; at= Location.of_lexing $startpos $endpos}, t)) }

lambdas0(SEP):
  | SEP t = term
    { t }
  | p = simple_pattern t = lambdas0(SEP)
    { {it= Lambda (p, t); at= Location.of_lexing $startpos $endpos} }
  | COLON ty = ty SEP t = term
    { {it= Annotated (t, ty); at= Location.of_lexing $startpos $endpos} }
  | COLON ty = ty HASH eps = eps_grade SEP t = term
    { {it= AnnotatedComp (t, ty, eps); at= Location.of_lexing $startpos $endpos} }

lambdas1(SEP):
  | p = simple_pattern t = lambdas0(SEP)
    { {it= Lambda (p, t); at= Location.of_lexing $startpos $endpos} }

pure_lambdas(SEP):
  | SEP t = term
    { t }
  | p = simple_pattern t = pure_lambdas(SEP)
    { {it= PureLambda (p, t); at= Location.of_lexing $startpos $endpos} }
  | COLON ty = ty SEP t = term
    { {it= Annotated (t, ty); at= Location.of_lexing $startpos $endpos} }
  | COLON ty = ty HASH eps = eps_grade SEP t = term
    { {it= AnnotatedComp (t, ty, eps); at= Location.of_lexing $startpos $endpos} }

let_def:
  | p = pattern EQUAL t = term
    { (p, t) }
  | p = pattern COLON ty= ty EQUAL t = term
    { (p, {it= Annotated(t, ty); at= Location.of_lexing $startpos $endpos}) }
  | x = mark_position(ident) t = lambdas1(EQUAL)
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
    { let ptuple = {it= PTuple [p1; p2]; at= Location.of_lexing $startpos $endpos} in
      PVariant ({it= cons_label; at= Location.of_lexing $startpos($2) $endpos($2)}, Some ptuple) }

succ_pattern: mark_position(plain_succ_pattern) { $1 }
plain_succ_pattern:
  | p = variant_pattern
    { p.it }
  | p = succ_pattern PLUS k = INT
    { if Z.sign k > 0 then PSucc (p, k)
      else
        Error.syntax ~loc:(Location.of_lexing $startpos(k) $endpos(k))
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
    { "(" ^ op ^ ")" }

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

cases0(case):
  | BAR? cs = separated_list(BAR, case)
    { cs }

bar_cases0(case):
  | BAR cs = separated_list(BAR, case)
    { cs }

cases(case):
  | BAR? cs = separated_nonempty_list(BAR, case)
    { cs }

mark_position(X):
  x = X
  { {it= x; at= Location.of_lexing $startpos $endpos}}

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
    { let at = Location.of_lexing $startpos $endpos in
      TyArrow (t1, CompTy (t2, { it = GradeLit GS.E.one; at })) }
  | t = prod_ty
    { t.it }

prod_ty: mark_position(plain_prod_ty) { $1 }
plain_prod_ty:
  | ts = separated_nonempty_list(STAR, box_ty)
    {
      match ts with
      | [] -> assert false
      | [t] -> t.it
      | _ -> TyTuple ts
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

(* The runtime bounds an operation declares, an interval of durations with
   finite ends, each closed or open; [within n] is sugar for [within [n, n]].
   Only the grading monoids with costs read them. *)
op_bounds:
  | WITHIN n = runtime_bound
    { (Grade.Closed n, Grade.Closed n) }
  | WITHIN LBRACK n = runtime_bound COMMA m = runtime_bound RBRACK
    { (Grade.Closed n, Grade.Closed m) }
  | WITHIN LBRACK n = runtime_bound COMMA m = runtime_bound RPAREN
    { open_runtime ~loc:(Location.of_lexing $startpos($2) $endpos)
        (Grade.Closed n) (Grade.Open m) }
  | WITHIN LPAREN n = runtime_bound COMMA m = runtime_bound RBRACK
    { open_runtime ~loc:(Location.of_lexing $startpos($2) $endpos)
        (Grade.Open n) (Grade.Closed m) }
  | WITHIN LPAREN n = runtime_bound COMMA m = runtime_bound RPAREN
    { open_runtime ~loc:(Location.of_lexing $startpos($2) $endpos)
        (Grade.Open n) (Grade.Open m) }

(* A runtime bound, a duration read as a delay. *)
runtime_bound:
  | q = duration
    { runtime_bound ~loc:(Location.of_lexing $startpos $endpos) q }

(* A resource grade, a literal read by the resource grades of the grade system
   or a grade variable, at its location. *)
rho_grade:
  | lit = grade_lit
    { let at = Location.of_lexing $startpos $endpos in
      { it = GradeLit (grade ~loc:at GS.R.name GS.R.of_lit lit); at } }
  | p = PARAM
    { { it = GradeParam p; at = Location.of_lexing $startpos $endpos } }

(* An effect grade, a literal read by the effect grades of the grade system or
   a grade variable, at its location. *)
eps_grade:
  | lit = grade_lit
    { let at = Location.of_lexing $startpos $endpos in
      { it = GradeLit (grade ~loc:at GS.E.name GS.E.of_lit lit); at } }
  | p = PARAM
    { { it = GradeParam p; at = Location.of_lexing $startpos $endpos } }

(* A non-negative duration: an integer or a fraction. *)
duration:
  | n = INT { Rational.of_z n }
  | q = fraction
    { if Rational.sign q < 0 then
        Error.syntax ~loc:(Location.of_lexing $startpos $endpos)
          "durations must be non-negative"
      else q }

(* A fraction, exact: a decimal, or the quotient of two integers. *)
fraction:
  | f = FLOAT { Rational.of_decimal f }
  | n = INT op = INFIXOP3 d = INT
    { if op <> "/" then
        Error.syntax ~loc:(Location.of_lexing $startpos(op) $endpos(op))
          "unknown operator '%s' in a fraction" op
      else if Z.equal d Z.zero then
        Error.syntax ~loc:(Location.of_lexing $startpos(d) $endpos(d))
          "fractions have positive denominators"
      else Rational.make_z n d }

(* A grade literal, shared by all grades; each grade reads the forms it
   understands. *)
grade_lit:
  | n = INT
    { Grade.Int (small ~loc:(Location.of_lexing $startpos $endpos) "Grade literal" n) }
  | q = fraction { Grade.rational_lit q }
  | MINUS n = INT
    { Grade.Int (- small ~loc:(Location.of_lexing $startpos $endpos) "Grade literal" n) }
  | UNDERSCORE { Grade.Name "_" }
  | name = UNAME { Grade.Name name }
  | TOP { Grade.Top }
  | INFINITY { Grade.Inf }
  | NEQ { Grade.Name "≠" }
  | name = LNAME { named_lit ~loc:(Location.of_lexing $startpos $endpos) name }
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
    { interval ~loc:(Location.of_lexing $startpos $endpos)
        ~lower_open:false ends ~upper_open:false }
  | LBRACK ends = separated_nonempty_list(COMMA, endpoint) RPAREN
    { interval ~loc:(Location.of_lexing $startpos $endpos)
        ~lower_open:false ends ~upper_open:true }
  | LPAREN lo = minus_infinity COMMA ends = separated_nonempty_list(COMMA, endpoint) RBRACK
    { interval ~loc:(Location.of_lexing $startpos $endpos)
        ~lower_open:true (lo :: ends) ~upper_open:false }
  | LPAREN lo = minus_infinity COMMA ends = separated_nonempty_list(COMMA, endpoint) RPAREN
    { interval ~loc:(Location.of_lexing $startpos $endpos)
        ~lower_open:true (lo :: ends) ~upper_open:true }
  | LPAREN lit = grade_lit COMMA lits = separated_nonempty_list(COMMA, grade_lit) RBRACK
    { interval ~loc:(Location.of_lexing $startpos $endpos)
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
        Error.syntax ~loc:(Location.of_lexing $startpos $endpos)
          "'-%s' is no grade literal" name }

(* The regular expressions of brace literals, by increasing precedence: union
   [|], intersection [&], concatenation [;], complement [~] and repetition
   [*]. Braces group as parentheses do. An atom is an operation name, a delay,
   the wildcard [_], or an interval of delays [[a, b]], [(a, b)], [[a, b)],
   [(a, b]], [[a, ∞)] or [(a, ∞)]; a parenthesis followed by a delay and a
   comma opens an interval, and otherwise a group. *)
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
        Error.syntax ~loc:(Location.of_lexing $startpos(op) $endpos(op))
          "unknown operator '%s' in a brace literal" op }

regex_postfix:
  | r = regex_atom { r }
  | r = regex_postfix STAR { Grade.Star r }

regex_atom:
  | name = UNAME { Grade.Letter name }
  | n = INT
    { Grade.Tick (small ~loc:(Location.of_lexing $startpos $endpos) "Grade literal" n) }
  | q = fraction { Grade.rational_tick q }
  | LBRACK lo = duration COMMA hi = delay_end RBRACK
    { delays ~loc:(Location.of_lexing $startpos $endpos)
        ~lower_open:false lo hi ~upper_open:false }
  | LBRACK lo = duration COMMA hi = delay_end RPAREN
    { delays ~loc:(Location.of_lexing $startpos $endpos)
        ~lower_open:false lo hi ~upper_open:true }
  | LPAREN lo = duration COMMA hi = delay_end RBRACK
    { delays ~loc:(Location.of_lexing $startpos $endpos)
        ~lower_open:true lo hi ~upper_open:false }
  | LPAREN lo = duration COMMA hi = delay_end RPAREN
    { delays ~loc:(Location.of_lexing $startpos $endpos)
        ~lower_open:true lo hi ~upper_open:true }
  | UNDERSCORE { Grade.Any }
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
        Error.syntax ~loc:(Location.of_lexing $startpos $endpos)
          "'%s' is no delay" name }

%%
