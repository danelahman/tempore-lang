(* The tokens of the lexer, shared by the grammar, which is merged with
   this file, and the module Token, generated from it alone. *)

%token LPAREN RPAREN LBRACK RBRACK LBRACE RBRACE
%token COLON COMMA SEMI EQUAL CONS
%token BEGIN END
%token <string> LNAME
%token UNDERSCORE AS
%token <Z.t> INT
%token <Z.t> INTEGER
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

%%
