%{
  open SugaredAst
  open Utils
  module Grade = Grades.Grade

  (* The hint naming the grades that understand the literal [lit]. *)
  let suggestion lit =
    let quote name = "'" ^ name ^ "'" in
    match List.map quote (Grades.GradeRegistry.accepting lit) with
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
        (suggestion lit)

  (* The literals written as lowercase names. *)
  let named_lit ~loc = function
    | "top" -> Grade.Top
    | "inf" -> Grade.Inf
    | name ->
        Error.syntax ~loc
          "'%s' is no grade literal; grades are written as integers, names \
           such as 'High', '⊤' (ASCII 'top'), '∞' (ASCII 'inf'), tuples '(...)' \
           and brace literals '{...}'" name
%}

%parameter<GS : Grades.GradeSystem.S>

%token LPAREN RPAREN LBRACK RBRACK LBRACE RBRACE
%token COLON COMMA SEMI EQUAL CONS
%token BEGIN END
%token <string> LNAME
%token UNDERSCORE AS
%token <int> INT
%token <string> STRING
%token <bool> BOOL
%token <float> FLOAT
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
%token TOP INFINITY
%token EOF

%nonassoc ARROW IN
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

%start <(GS.R.t annotated, GS.E.t annotated) SugaredAst.term> payload
%start <(GS.R.t annotated, GS.E.t annotated) SugaredAst.command list> commands

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
  | OPERATION op = UNAME COLON ty1 = ty SIGARROW ty2 = ty HASH eps = eps_grade
    bounds = option(op_bounds)
    { OpSig (op, ty1, ty2, eps, bounds) }
  | DEFAULT op = UNAME p = simple_pattern EQUAL t = term
    { OpDefault (op, (p, t)) }
  | LET x = ident t = lambdas0(EQUAL)
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
  | DELAY grade = INT
    { Delay grade }
  | BOX rho = rho_grade e = term AS p = pattern IN c = term
    { Box (rho, e, (p, c)) }
  | BOX rho = rho_grade e = term
    { GenBox (rho, e) }
  | UNBOX e = term AS p = pattern IN c = term
    { Unbox (e, (p, c)) }
  | UNBOX e = term
    { GenUnbox (e) }
  | PERFORM op = UNAME e = comma_term
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
      Variant (cons_label, Some tuple) }
  | t = plain_uminus_term
    { t }

uminus_term: mark_position(plain_uminus_term) { $1 }
plain_uminus_term:
  | MINUS t = uminus_term
    { let op_loc = Location.of_lexing $startpos($1) $endpos($1) in
      Apply ({it= Var "(~-)"; at= op_loc}, t) }
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
      | Variant (lbl, _), _ -> Error.syntax ~loc:(t.at) "Label %s applied to too many arguments" lbl
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
  | lbl = UNAME
    { Variant (lbl, None) }
  | cst = const
    { Const cst }
  | LBRACK ts = separated_list(SEMI, comma_term) RBRACK
    {
      let nil = {it= Variant (nil_label, None); at= Location.of_lexing $endpos $endpos} in
      let cons t ts =
        let loc = Location.merge t.at ts.at in
        let tuple = {it= Tuple [t; ts];at= loc} in
        {it= Variant (cons_label, Some tuple); at= loc}
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
    { Language.Const.of_integer n }
  | str = STRING
    { Language.Const.of_string str }
  | b = BOOL
    { Language.Const.of_boolean b }
  | f = FLOAT
    { Language.Const.of_float f }

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
  | f = ident t = pure_lambdas(EQUAL)
    { (f, t) }

pattern: mark_position(plain_pattern) { $1 }
plain_pattern:
  | p = comma_pattern
    { p.it }
  | p = pattern AS x = lname
    { PAs (p, x) }

comma_pattern: mark_position(plain_comma_pattern) { $1 }
plain_comma_pattern:
  | ps = separated_nonempty_list(COMMA, cons_pattern)
    { match ps with [p] -> p.it | ps -> PTuple ps }

cons_pattern: mark_position(plain_cons_pattern) { $1 }
plain_cons_pattern:
  | p = variant_pattern
    { p.it }
  | p1 = variant_pattern CONS p2 = cons_pattern
    { let ptuple = {it= PTuple [p1; p2]; at= Location.of_lexing $startpos $endpos} in
      PVariant (cons_label, Some ptuple) }

variant_pattern: mark_position(plain_variant_pattern) { $1 }
plain_variant_pattern:
  | lbl = UNAME p = simple_pattern
    { PVariant (lbl, Some p) }
  | p = simple_pattern
    { p.it }

simple_pattern: mark_position(plain_simple_pattern) { $1 }
plain_simple_pattern:
  | x = ident
    { PVar x }
  | lbl = UNAME
    { PVariant (lbl, None) }
  | UNDERSCORE
    { PNonbinding }
  | cst = const
    { PConst cst }
  | LBRACK ts = separated_list(SEMI, pattern) RBRACK
    {
      let nil = {it= PVariant (nil_label, None);at= Location.of_lexing $endpos $endpos} in
      let cons t ts =
        let loc = Location.merge t.at ts.at in
        let tuple = {it= PTuple [t; ts]; at= loc} in
        {it= PVariant (cons_label, Some tuple); at= loc}
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
  | ps = params t = tyname EQUAL x = defined_ty
    { (ps, t, x) }

defined_ty:
  | variants = cases(sum_case)
    { TySum variants }
  | t = ty
    { TyInline t }

ty: mark_position(plain_ty) { $1 }
plain_ty:
  | t1 = ty_apply ARROW t2 = ty HASH eps = eps_grade
    { TyArrow (t1, CompTy (t2, eps)) }
  | t1 = ty_apply ARROW t2 = ty
    { let at = Location.of_lexing $startpos $endpos in
      TyArrow (t1, CompTy (t2, { it = GS.E.one; at })) }
  | t = plain_prod_ty
    { t }

plain_prod_ty:
  | ts = separated_nonempty_list(STAR, ty_apply)
    {
      match ts with
      | [] -> assert false
      | [t] -> t.it
      | _ -> TyTuple ts
     }

ty_apply: mark_position(plain_ty_apply) { $1 }
plain_ty_apply:
  | LPAREN t = ty COMMA ts = separated_nonempty_list(COMMA, ty) RPAREN t2 = tyname
    { TyApply (t2, (t :: ts)) }
  | t = ty_apply t2 = tyname
    { TyApply (t2, [t]) }
  | t = plain_simple_ty
    { t }

plain_simple_ty:
  | t = tyname
    { TyApply (t, []) }
  | t = PARAM
    { TyParam t }
  | LBRACK rho = rho_grade RBRACK ty = ty
    { TyBox (rho, ty) }
  | LPAREN t = ty RPAREN
    { t.it }

sum_case:
  | lbl = UNAME
    { (lbl, None) }
  | lbl = UNAME OF t = ty
    { (lbl, Some t) }

(* The runtime bounds an operation declares; [within n] is sugar for
   [within (n, n)]. Only the timed-trace grading monoids read them. *)
op_bounds:
  | WITHIN n = INT { (n, n) }
  | WITHIN LPAREN n = INT COMMA m = INT RPAREN { (n, m) }

(* A resource grade, read by the resource grades of the grade system, at the
   location of its literal. *)
rho_grade:
  | lit = grade_lit
    { let at = Location.of_lexing $startpos $endpos in
      { it = grade ~loc:at GS.R.name GS.R.of_lit lit; at } }

(* An effect grade, read by the effect grades of the grade system, at the
   location of its literal. *)
eps_grade:
  | lit = grade_lit
    { let at = Location.of_lexing $startpos $endpos in
      { it = grade ~loc:at GS.E.name GS.E.of_lit lit; at } }

(* A grade literal, shared by all grades; each grade reads the forms it
   understands. *)
grade_lit:
  | n = INT { Grade.Int n }
  | MINUS n = INT { Grade.Int (-n) }
  | UNDERSCORE { Grade.Name "_" }
  | name = UNAME { Grade.Name name }
  | TOP { Grade.Top }
  | INFINITY { Grade.Inf }
  | name = LNAME { named_lit ~loc:(Location.of_lexing $startpos $endpos) name }
  | LPAREN lit = grade_lit COMMA lits = separated_nonempty_list(COMMA, grade_lit) RPAREN
    { Grade.Tuple (lit :: lits) }
  | LBRACE r = regex RBRACE { Grade.Braces r }

(* The regular expressions of brace literals, by increasing precedence: union
   [|], intersection [&], concatenation [;], complement [~] and repetition
   [*]. Braces group as parentheses do. *)
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
  | n = INT { Grade.Tick n }
  | UNDERSCORE { Grade.Any }
  | LPAREN r = regex RPAREN { r }
  | LBRACE r = regex RBRACE { r }

%%
