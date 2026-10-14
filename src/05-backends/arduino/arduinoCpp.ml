type stmt =
  | Line of string
  | Block of string * stmt list * string
  | If of (string option * stmt list) list

let rec lines indent = function
  | Line s -> [ indent ^ s ]
  | Block (header, body, closing) ->
      ((indent ^ header ^ " {") :: List.concat_map (lines (indent ^ "  ")) body)
      @ [ indent ^ closing ]
  | If branches ->
      List.concat
        (List.mapi
           (fun i (condition, body) ->
             let opening =
               match (i, condition) with
               | 0, Some c -> "if (" ^ c ^ ") {"
               | _, Some c -> "} else if (" ^ c ^ ") {"
               | _, None -> "} else {"
             in
             (indent ^ opening) :: List.concat_map (lines (indent ^ "  ")) body)
           branches)
      @ [ indent ^ "}" ]

let render stmts = String.concat "\n" (List.concat_map (lines "") stmts) ^ "\n"
let blank = Line ""
let comment text = Line ("// " ^ text)
let block header body = Block (header, body, "}")
let statement e = Line (e ^ ";")
let return e = Line ("return " ^ e ^ ";")
let assign x e = Line (x ^ " = " ^ e ^ ";")

let constant ?(static = false) ty x e =
  Line
    ((if static then "static " else "")
    ^ "const " ^ ty ^ " " ^ x ^ " = " ^ e ^ ";")

let variable ?init ty x =
  match init with
  | Some e -> Line (ty ^ " " ^ x ^ " = " ^ e ^ ";")
  | None -> Line (ty ^ " " ^ x ^ "{};")

let call f arguments = f ^ "(" ^ String.concat ", " arguments ^ ")"

let declarator ?(static = false) ?(inline = false) result name parameters =
  (if static then "static " else "")
  ^ (if inline then "inline " else "")
  ^ result ^ " "
  ^ call name
      (List.map
         (fun (ty, x) -> Option.fold ~none:ty ~some:(fun x -> ty ^ " " ^ x) x)
         parameters)

let prototype ?static result name types =
  Line
    (declarator ?static result name (List.map (fun ty -> (ty, None)) types)
    ^ ";")

let definition ?static ?inline result name parameters body =
  block (declarator ?static ?inline result name parameters) body

let typedef ty name = Line ("typedef " ^ ty ^ " " ^ name ^ ";")

let null_terminated declaration elements =
  Line (declaration ^ " = {")
  :: List.map (fun e -> Line ("    " ^ e ^ ",")) elements
  @ [ Line "    nullptr};" ]

let system_include h = Line ("#include <" ^ h ^ ">")
let local_include h = Line ("#include \"" ^ h ^ "\"")
let define m = Line ("#define " ^ m)

let is_identifier_start = function
  | 'a' .. 'z' | 'A' .. 'Z' | '_' -> true
  | _ -> false

let is_identifier_char = function
  | '0' .. '9' -> true
  | c -> is_identifier_start c

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
