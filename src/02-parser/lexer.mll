{
  open Token
  open Utils

  module StringMap = Map.Make (String)

  let reserved = StringMap.of_seq @@ List.to_seq [
    ("and", AND);
    ("as", AS);
    ("asr", ASR);
    ("begin", BEGIN);
    ("else", ELSE);
    ("end", END);
    ("false", BOOL false);
    ("fun", FUN);
    ("function", FUNCTION);
    ("if", IF);
    ("in", IN);
    ("land", LAND);
    ("let", LET);
    ("lor", LOR);
    ("lsl", LSL);
    ("lsr", LSR);
    ("lxor", LXOR);
    ("match", MATCH);
    ("mod", MOD);
    ("of", OF);
    ("or", OR);
    ("rec", REC);
    ("run", RUN);
    ("then", THEN);
    ("true", BOOL true);
    ("type", TYPE);
    ("noneternal", NONETERNAL);
    ("with", WITH);
    ("within", WITHIN);
    ("delay", DELAY);
    ("box", BOX);
    ("unbox", UNBOX);
    ("operation", OPERATION);
    ("default", DEFAULT);
    ("perform", PERFORM);
    ("handler", HANDLER);
    ("handle", HANDLE);
    ("continue", CONTINUE);
  ]

  let escaped_characters = [
    ("\"", "\"");
    ("\\", "\\");
    ("\'", "'");
    ("n", "\n");
    ("t", "\t");
    ("b", "\b");
    ("r", "\r");
    (" ", " ");
  ]

}

let lname = ( ['a'-'z'] ['_' 'a'-'z' 'A'-'Z' '0'-'9' '\'']*
            | ['_' 'a'-'z'] ['_' 'a'-'z' 'A'-'Z' '0'-'9' '\'']+)

let uname = ['A'-'Z'] ['_' 'a'-'z' 'A'-'Z' '0'-'9' '\'']*

let hexdig = ['0'-'9' 'a'-'f' 'A'-'F']

let int = ['0'-'9'] ['0'-'9' '_']*

let xxxint =
    ( ("0x" | "0X") hexdig (hexdig | '_')*
    | ("0o" | "0O") ['0'-'7'] ['0'-'7' '_']*
    | ("0b" | "0B") ['0' '1'] ['0' '1' '_']*)

let float =
  '-'? ['0'-'9'] ['0'-'9' '_']*
  (('.' ['0'-'9' '_']*) (['e' 'E'] ['+' '-']? ['0'-'9'] ['0'-'9' '_']*)? |
   ('.' ['0'-'9' '_']*)? (['e' 'E'] ['+' '-']? ['0'-'9'] ['0'-'9' '_']*))

let operatorchar = ['!' '$' '%' '&' '*' '+' '-' '.' '/' ':' '.' '<' '=' '>' '?' '@' '^' '|' '~']

let prefixop = ['~' '?' '!']                  operatorchar*
let infixop0 = ['=' '<' '>' '|' '&' '$']      operatorchar*
let infixop1 = ['@' '^']                      operatorchar*
let infixop2 = ['+' '-']                      operatorchar*
let infixop3 = ['*' '/' '%']                  operatorchar*
let infixop4 = "**"                           operatorchar*

rule token = parse
  | '\n'                { Lexing.new_line lexbuf; token lexbuf }
  | [' ' '\r' '\t']     { token lexbuf }
  | "(*"                { comment token 0 lexbuf }
  | int | xxxint        { INT (Z.of_string (Lexing.lexeme lexbuf)) }
  | float               { FLOAT (Lexing.lexeme lexbuf) }
  | '"'                 { STRING (string "" lexbuf) }
  | lname               { let s = Lexing.lexeme lexbuf in
                            match StringMap.find_opt s reserved with
                              | Some t -> t
                              | None -> LNAME s
                        }
  | uname               { UNAME (Lexing.lexeme lexbuf) }
  | '\'' lname          { let str = Lexing.lexeme lexbuf in
                          PARAM (String.sub str 1 (String.length str - 1)) }
  | '_'                 { UNDERSCORE }
  | "⊤"                 { TOP }
  | "∞"                 { INFINITY }
  | '('                 { LPAREN }
  | ')'                 { RPAREN }
  | '['                 { LBRACK }
  | ']'                 { RBRACK }
  | '{'                 { LBRACE }
  | '}'                 { RBRACE }
  | "::"                { CONS }
  | ':'                 { COLON }
  | ','                 { COMMA }
  | '|'                 { BAR }
  | "||"                { BARBAR }
  | ';'                 { SEMI }
  | "->"                { ARROW }
  | "~>"                { SIGARROW }
  | '#'                 { HASH }
  | '='                 { EQUAL }
  | '*'                 { STAR }
  | '+'                 { PLUS }
  | '-'                 { MINUS }
  | "-."                { MINUSDOT }
  | '&'                 { AMPER }
  | "&&"                { AMPERAMPER }
  | prefixop            { PREFIXOP(Lexing.lexeme lexbuf) }
  | ":="                { INFIXOP0(":=") }
  | infixop0            { INFIXOP0(Lexing.lexeme lexbuf) }
  | infixop1            { INFIXOP1(Lexing.lexeme lexbuf) }
  | infixop2            { INFIXOP2(Lexing.lexeme lexbuf) }
  (* infixop4 comes before infixop3 because ** would otherwise match infixop3 *)
  | infixop4            { INFIXOP4(Lexing.lexeme lexbuf) }
  | infixop3            { INFIXOP3(Lexing.lexeme lexbuf) }
  | eof                 { EOF }

(* Inside a brace literal each of the regular-expression operators [*], [|], [&]
   and [~] is a token of its own, so that, e.g., [A*|~B] needs no spaces; any
   other input is lexed as outside. *)
and brace_token = parse
  | '\n'                { Lexing.new_line lexbuf; brace_token lexbuf }
  | [' ' '\r' '\t']     { brace_token lexbuf }
  | "(*"                { comment brace_token 0 lexbuf }
  | '*'                 { STAR }
  | '|'                 { BAR }
  | '&'                 { AMPER }
  | '~'                 { PREFIXOP "~" }
  | ""                  { token lexbuf }

(* A comment nested [n] deep, after which lexing resumes with [continue]. *)
and comment continue n = parse
  | "*)"                { if n = 0 then continue lexbuf else comment continue (n - 1) lexbuf }
  | "(*"                { comment continue (n + 1) lexbuf }
  | '\n'                { Lexing.new_line lexbuf; comment continue n lexbuf }
  | _                   { comment continue n lexbuf }
  | eof                 { Error.syntax ~loc:(Location.of_lexbuf lexbuf) "Unterminated comment" }

and string acc = parse
  | '"'                 { acc }
  | '\\'                { let esc = escaped lexbuf in string (acc ^ esc) lexbuf }
  | [^'"' '\\']*        { string (acc ^ (Lexing.lexeme lexbuf)) lexbuf }
  | eof                 { Error.syntax ~loc:(Location.of_lexbuf lexbuf) "Unterminated string %s" acc}

and escaped = parse
  | _                   { let str = Lexing.lexeme lexbuf in
                          try List.assoc str escaped_characters
                          with Not_found -> Error.syntax ~loc:(Location.of_lexbuf lexbuf) "Unknown escaped character %s" str
                        }

{
  (** [tokens ()] is a lexer for one source: [token] outside brace literals and
      [brace_token] inside them. The lexer keeps the depth of the braces open,
      so each source needs a lexer of its own. *)
  let tokens () =
    let depth = ref 0 in
    fun lexbuf ->
      let tok = if !depth > 0 then brace_token lexbuf else token lexbuf in
      (match tok with
       | LBRACE -> incr depth
       | RBRACE -> depth := max 0 (!depth - 1)
       | EOF -> depth := 0
       | _ -> ());
      tok

  (* [In_channel.with_open_text] guarantees the channel is closed on any
     exception path (parser errors, lexer errors, asynchronous exceptions),
     replacing the older manual [open_in]/[close_in] dance. *)
  let read_file parser fn =
    try
      In_channel.with_open_text fn (fun ch ->
        let lex = Lexing.from_channel ch in
        lex.Lexing.lex_curr_p <-
          { lex.Lexing.lex_curr_p with Lexing.pos_fname = fn };
        parser lex)
    with Sys_error msg -> Error.fatal "%s" msg
}
