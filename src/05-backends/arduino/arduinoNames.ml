(* The word an operator character is spelt as. *)
let word = function
  | '+' -> Some "plus"
  | '-' -> Some "minus"
  | '*' -> Some "times"
  | '/' -> Some "div"
  | '<' -> Some "lt"
  | '>' -> Some "gt"
  | '=' -> Some "eq"
  | '.' -> Some "dot"
  | '&' -> Some "and"
  | '|' -> Some "or"
  | '~' -> Some "tilde"
  | '@' -> Some "at"
  | '^' -> Some "caret"
  | '!' -> Some "bang"
  | '%' -> Some "percent"
  | '\'' -> Some "p"
  | '$' -> Some "dollar"
  | '?' -> Some "q"
  | ':' -> Some "colon"
  | '#' -> Some "hash"
  | _ -> None

let is_alphanumeric c =
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')

(* The spelling of the Unicode scalar value [u], with [_] separating the words
   of the spellings of other characters. *)
let spelling u =
  let code = Uchar.to_int u in
  if code < 128 then
    let c = Char.chr code in
    if is_alphanumeric c then String.make 1 c
    else
      match word c with
      | Some w -> "_" ^ w ^ "_"
      | None ->
          if c = '_' || c = ' ' || c = '(' || c = ')' then "_"
          else Printf.sprintf "_u%x_" code
  else Printf.sprintf "_u%x_" code

let starts_with prefix s =
  String.length s >= String.length prefix
  && String.sub s 0 (String.length prefix) = prefix

let base name =
  let rec spelt i acc =
    if i >= String.length name then String.concat "" (List.rev acc)
    else
      let d = String.get_utf_8_uchar name i in
      spelt
        (i + Uchar.utf_decode_length d)
        (spelling (Uchar.utf_decode_uchar d) :: acc)
  in
  let parts =
    List.filter (fun s -> s <> "") (String.split_on_char '_' (spelt 0 []))
  in
  match String.concat "_" parts with
  | "" -> "v"
  | s when (s.[0] >= '0' && s.[0] <= '9') || starts_with "tempore" s -> "v" ^ s
  | s -> s

let identifier name index = Printf.sprintf "%s_%d" (base name) index
let operation name = "tempore_op_" ^ base name

let string_literal s =
  let char c =
    match c with
    | '"' -> "\\\""
    | '\\' -> "\\\\"
    | '?' -> "\\?"
    | c when c >= ' ' && c < '\127' -> String.make 1 c
    | c -> Printf.sprintf "\\%03o" (Char.code c)
  in
  "\"" ^ String.concat "" (List.map char (List.of_seq (String.to_seq s))) ^ "\""
