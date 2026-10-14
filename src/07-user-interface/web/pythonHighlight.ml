open Vdom

(* The keywords of Python 3, the soft ones excepted. *)
let keywords =
  [
    "False";
    "None";
    "True";
    "and";
    "as";
    "assert";
    "async";
    "await";
    "break";
    "class";
    "continue";
    "def";
    "del";
    "elif";
    "else";
    "except";
    "finally";
    "for";
    "from";
    "global";
    "if";
    "import";
    "in";
    "is";
    "lambda";
    "nonlocal";
    "not";
    "or";
    "pass";
    "raise";
    "return";
    "try";
    "while";
    "with";
    "yield";
  ]

let is_ident_start c =
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c = '_' || c >= '\x80'

let is_ident_char c = is_ident_start c || (c >= '0' && c <= '9')

(* The end of the string literal opened by the quote [q] at [i], [triple] if
   by three: after its closing quotes, or at the end of the line of a
   single-quoted literal left open, or at the end of [s]. *)
let string_end s i q triple =
  let n = String.length s in
  let rec go j =
    if j >= n then n
    else if s.[j] = '\\' then go (j + 2)
    else if triple then
      if j + 2 < n && s.[j] = q && s.[j + 1] = q && s.[j + 2] = q then j + 3
      else go (j + 1)
    else if s.[j] = q then j + 1
    else if s.[j] = '\n' then j
    else go (j + 1)
  in
  go (i + if triple then 3 else 1)

(* The token at [i] of [s]: its end and class, or the end of the text
   without a class that starts there. *)
let token_at s i =
  let n = String.length s in
  let rec past p j = if j < n && p s.[j] then past p (j + 1) else j in
  let c = s.[i] in
  if c = '#' then
    ( Option.value ~default:n (String.index_from_opt s i '\n'),
      Some "syn-comment" )
  else if c = '\'' || c = '"' then
    let triple = i + 2 < n && s.[i + 1] = c && s.[i + 2] = c in
    (string_end s i c triple, Some "syn-str")
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
