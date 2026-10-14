open Vdom

(* The keywords of C++17 that the generated code and the scaffold use, with
   the fundamental types. *)
let keywords =
  [
    "auto";
    "bool";
    "break";
    "case";
    "char";
    "class";
    "const";
    "constexpr";
    "continue";
    "default";
    "do";
    "double";
    "else";
    "enum";
    "extern";
    "false";
    "float";
    "for";
    "if";
    "inline";
    "int";
    "long";
    "namespace";
    "nullptr";
    "return";
    "short";
    "signed";
    "sizeof";
    "static";
    "static_cast";
    "struct";
    "switch";
    "true";
    "typedef";
    "union";
    "unsigned";
    "using";
    "void";
    "volatile";
    "while";
  ]

let is_ident_start c =
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c = '_'

let is_ident_char c = is_ident_start c || (c >= '0' && c <= '9')

(* The end of the line at or after [i]: the index of its newline, or the end
   of [s]. *)
let line_end s i =
  Option.value ~default:(String.length s) (String.index_from_opt s i '\n')

(* The end of the literal opened by the quote [q] at [i]: after its closing
   quote, or at the end of the line if it is left open. *)
let literal_end s i q =
  let n = String.length s in
  let rec go j =
    if j >= n then n
    else if s.[j] = '\\' then go (j + 2)
    else if s.[j] = q then j + 1
    else if s.[j] = '\n' then j
    else go (j + 1)
  in
  go (i + 1)

(* The end of the block comment opened at [i]: after its closing delimiter, or
   at the end of [s]. *)
let comment_end s i =
  let n = String.length s in
  let rec go j =
    if j + 1 >= n then n
    else if s.[j] = '*' && s.[j + 1] = '/' then j + 2
    else go (j + 1)
  in
  go (i + 2)

(* Whether [i] starts a line of [s] up to blanks. *)
let at_line_start s i =
  let rec go j =
    j < 0 || s.[j] = '\n' || ((s.[j] = ' ' || s.[j] = '\t') && go (j - 1))
  in
  go (i - 1)

(* The token at [i] of [s]: its end and class, or the end of the text without
   a class that starts there. A preprocessor directive is highlighted as a
   keyword up to the end of its name. *)
let token_at s i =
  let n = String.length s in
  let rec past p j = if j < n && p s.[j] then past p (j + 1) else j in
  let c = s.[i] in
  let next = if i + 1 < n then s.[i + 1] else ' ' in
  if c = '/' && next = '/' then (line_end s i, Some "syn-comment")
  else if c = '/' && next = '*' then (comment_end s i, Some "syn-comment")
  else if c = '#' && at_line_start s i then
    (past is_ident_char (i + 1), Some "syn-kw")
  else if c = '"' || c = '\'' then (literal_end s i c, Some "syn-str")
  else if c >= '0' && c <= '9' then
    (past (fun c -> is_ident_char c || c = '.') i, Some "syn-num")
  else if is_ident_start c then
    let j = past is_ident_char i in
    ( j,
      if List.mem (String.sub s i (j - i)) keywords then Some "syn-kw" else None
    )
  else (i + 1, None)

(* The runs of [s], each with the class of its token, if any, by a single
   left-to-right scan; the text between tokens forms runs without a class.
   [plain] is the start of the text without a class before [i]. *)
let runs s =
  let n = String.length s in
  let rec scan i plain acc =
    let flush acc =
      if plain < i then (String.sub s plain (i - plain), None) :: acc else acc
    in
    if i >= n then List.rev (flush acc)
    else
      match token_at s i with
      | stop, None -> scan stop plain acc
      | stop, Some cls ->
          scan stop stop ((String.sub s i (stop - i), Some cls) :: flush acc)
  in
  scan 0 0 []

let highlight s =
  List.map
    (function
      | text', None -> text text'
      | text', Some cls -> elt "span" ~a:[ class_ cls ] [ text text' ])
    (runs s)
