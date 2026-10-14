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

let is_alphanumeric c = c <> '_' && ArduinoCpp.is_identifier_char c

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

(* The spelling of [name] by the spelling of its characters, the words
   separated by single underscores, without an underscore at either end. *)
let spelt name =
  let rec spelt i acc =
    if i >= String.length name then String.concat "" (List.rev acc)
    else
      let d = String.get_utf_8_uchar name i in
      spelt
        (i + Uchar.utf_decode_length d)
        (spelling (Uchar.utf_decode_uchar d) :: acc)
  in
  String.concat "_"
    (List.filter (fun s -> s <> "") (String.split_on_char '_' (spelt 0 [])))

let identifier name index =
  let s = spelt name in
  let lower = String.lowercase_ascii s in
  let s =
    if
      s = ""
      || (s.[0] >= '0' && s.[0] <= '9')
      || String.starts_with ~prefix:"tempore" lower
      || String.starts_with ~prefix:"binding" lower
    then "v" ^ s
    else s
  in
  Printf.sprintf "%s_%d" s index

(* Whether [name] consists of ASCII letters and digits, with single
   underscores between them. *)
let is_plain name =
  name <> ""
  && List.for_all
       (fun part -> part <> "" && String.for_all is_alphanumeric part)
       (String.split_on_char '_' name)

(* The bytes of [name] in hexadecimal, two lower-case digits each. *)
let hexadecimal name =
  String.concat ""
    (List.map
       (fun c -> Printf.sprintf "%02x" (Char.code c))
       (List.of_seq (String.to_seq name)))

let base name =
  if is_plain name then name
  else
    match spelt name with
    | "" -> hexadecimal name ^ "_"
    | s -> s ^ "_" ^ hexadecimal name ^ "_"

let operation name = "tempore_op_" ^ base name
let monitor name = "tempore_monitor_" ^ base name
let bounds name = "tempore_bounds_" ^ base name
let binding name = "binding_" ^ base name
let performs name = "TEMPORE_PERFORMS_" ^ base name
let argument_type name = "tempore_argument_" ^ base name
let result_type name = "tempore_result_" ^ base name
