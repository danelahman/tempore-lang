module Location = Utils.Location
module Error = Utils.Error

type t = { value : value; at : Location.t }

and value =
  | Null
  | Bool of bool
  | Number of string
  | String of string
  | Array of t list
  | Object of (string Location.located * t) list

let kind v =
  match v.value with
  | Null -> "null"
  | Bool _ -> "a boolean"
  | Number _ -> "a number"
  | String _ -> "a string"
  | Array _ -> "an array"
  | Object _ -> "an object"

(* A recursive-descent parser over the bytes of the source. Each function takes
   the offset at which it starts and returns what it read with the offset after
   it. *)

type source = { filename : string; text : string; line_starts : int array }

(* The position of the offset [i]: its line is found by binary search among the
   offsets at which the lines start. *)
let position src i =
  let rec search lo hi =
    if hi - lo <= 1 then lo
    else
      let mid = (lo + hi) / 2 in
      if src.line_starts.(mid) <= i then search mid hi else search lo mid
  in
  let line = search 0 (Array.length src.line_starts) in
  {
    Location.line = line + 1;
    column = i - src.line_starts.(line) + 1;
    offset = i;
  }

let span src i j =
  {
    Location.filename = src.filename;
    start = position src i;
    stop = position src j;
  }

let fail src i fmt =
  let stop = if i < String.length src.text then i + 1 else i in
  Error.syntax ~loc:(span src i stop) fmt

let peek src i = if i < String.length src.text then Some src.text.[i] else None

let rec skip_space src i =
  match peek src i with
  | Some (' ' | '\t' | '\n' | '\r') -> skip_space src (i + 1)
  | _ -> i

let expect src i c =
  match peek src i with
  | Some c' when c' = c -> i + 1
  | _ -> fail src i "Expected '%c'" c

let literal src i word value =
  let n = String.length word in
  if i + n <= String.length src.text && String.sub src.text i n = word then
    (value, i + n)
  else fail src i "Unexpected character in a JSON value"

let is_digit c = c >= '0' && c <= '9'

let rec digits src i =
  match peek src i with Some c when is_digit c -> digits src (i + 1) | _ -> i

let at_least_one_digit src i =
  match peek src i with
  | Some c when is_digit c -> digits src (i + 1)
  | _ -> fail src i "Expected a digit"

(* A number: an optional minus, an integer part without leading zeros, an
   optional fraction and an optional exponent. *)
let number src i =
  let j = match peek src i with Some '-' -> i + 1 | _ -> i in
  let j =
    match peek src j with
    | Some '0' -> j + 1
    | Some c when is_digit c -> digits src (j + 1)
    | _ -> fail src j "Expected a digit"
  in
  let j =
    match peek src j with Some '.' -> at_least_one_digit src (j + 1) | _ -> j
  in
  let j =
    match peek src j with
    | Some ('e' | 'E') ->
        let k =
          match peek src (j + 1) with Some ('+' | '-') -> j + 2 | _ -> j + 1
        in
        at_least_one_digit src k
    | _ -> j
  in
  (String.sub src.text i (j - i), j)

let hex_digit = function
  | '0' .. '9' | 'a' .. 'f' | 'A' .. 'F' -> true
  | _ -> false

let hex4 src i =
  if
    i + 4 > String.length src.text
    || not (String.for_all hex_digit (String.sub src.text i 4))
  then fail src i "Expected four hexadecimal digits"
  else int_of_string ("0x" ^ String.sub src.text i 4)

(* A string, its first character after the opening quotation mark at [i]. *)
let string_body src i =
  let rec go buf i =
    match peek src i with
    | None -> fail src i "Unterminated string"
    | Some '"' -> (Buffer.contents buf, i + 1)
    | Some '\\' -> (
        let simple c =
          Buffer.add_char buf c;
          go buf (i + 2)
        in
        match peek src (i + 1) with
        | Some '"' -> simple '"'
        | Some '\\' -> simple '\\'
        | Some '/' -> simple '/'
        | Some 'b' -> simple '\b'
        | Some 'f' -> simple '\012'
        | Some 'n' -> simple '\n'
        | Some 'r' -> simple '\r'
        | Some 't' -> simple '\t'
        | Some 'u' ->
            let u = hex4 src (i + 2) in
            let u, next =
              if
                u >= 0xD800 && u <= 0xDBFF
                && peek src (i + 6) = Some '\\'
                && peek src (i + 7) = Some 'u'
              then
                let low = hex4 src (i + 8) in
                if low >= 0xDC00 && low <= 0xDFFF then
                  (0x10000 + ((u - 0xD800) lsl 10) + (low - 0xDC00), i + 12)
                else (0xFFFD, i + 6)
              else if u >= 0xD800 && u <= 0xDFFF then (0xFFFD, i + 6)
              else (u, i + 6)
            in
            Buffer.add_utf_8_uchar buf (Uchar.of_int u);
            go buf next
        | _ -> fail src (i + 1) "Invalid escape in a string")
    | Some c when Char.code c < 0x20 ->
        fail src i "Control character in a string"
    | Some c ->
        Buffer.add_char buf c;
        go buf (i + 1)
  in
  go (Buffer.create 16) i

let rec value src i =
  let i = skip_space src i in
  let node, j =
    match peek src i with
    | Some '{' -> members src (i + 1)
    | Some '[' -> elements src (i + 1)
    | Some '"' ->
        let s, j = string_body src (i + 1) in
        (String s, j)
    | Some 't' -> literal src i "true" (Bool true)
    | Some 'f' -> literal src i "false" (Bool false)
    | Some 'n' -> literal src i "null" Null
    | Some ('-' | '0' .. '9') ->
        let n, j = number src i in
        (Number n, j)
    | None -> fail src i "Unexpected end of the JSON document"
    | Some _ -> fail src i "Unexpected character in a JSON value"
  in
  ({ value = node; at = span src i j }, j)

and elements src i =
  let i = skip_space src i in
  match peek src i with
  | Some ']' -> (Array [], i + 1)
  | _ ->
      let rec go acc i =
        let v, i = value src i in
        let i = skip_space src i in
        match peek src i with
        | Some ',' -> go (v :: acc) (i + 1)
        | Some ']' -> (Array (List.rev (v :: acc)), i + 1)
        | _ -> fail src i "Expected ',' or ']'"
      in
      go [] i

and members src i =
  let i = skip_space src i in
  match peek src i with
  | Some '}' -> (Object [], i + 1)
  | _ ->
      let rec go acc i =
        let i = skip_space src i in
        let name, j =
          match peek src i with
          | Some '"' -> string_body src (i + 1)
          | _ -> fail src i "Expected the name of a member"
        in
        let name = { Location.it = name; at = span src i j } in
        let j = expect src (skip_space src j) ':' in
        let v, j = value src j in
        let j = skip_space src j in
        match peek src j with
        | Some ',' -> go ((name, v) :: acc) (j + 1)
        | Some '}' -> (Object (List.rev ((name, v) :: acc)), j + 1)
        | _ -> fail src j "Expected ',' or '}'"
      in
      go [] i

let parse ~filename text =
  let line_starts =
    Array.of_list
      (0
      :: List.filter_map
           (fun i -> if text.[i] = '\n' then Some (i + 1) else None)
           (List.init (String.length text) Fun.id))
  in
  let src = { filename; text; line_starts } in
  let v, i = value src 0 in
  let i = skip_space src i in
  if i < String.length text then
    fail src i "Unexpected text after the JSON document"
  else v

(* Decoding. *)

type fields = {
  what : string;
  at : Location.t;
  members : (string Location.located * t) list;
}

let wrong ~what (v : t) expected =
  Error.compilation ~loc:v.at "%s is %s, not %s"
    (String.capitalize_ascii what)
    (kind v) expected

let fields ~what ~accepted (v : t) =
  match v.value with
  | Object members ->
      List.iteri
        (fun i ((name : string Location.located), _) ->
          if not (List.mem name.it accepted) then
            Error.compilation ~loc:name.at
              "Unknown member '%s' of %s; accepted: %s" name.it what
              (String.concat ", " accepted);
          if
            List.exists
              (fun ((other : string Location.located), _) -> other.it = name.it)
              (List.filteri (fun j _ -> j < i) members)
          then
            Error.compilation ~loc:name.at "Member '%s' of %s given twice"
              name.it what)
        members;
      { what; at = v.at; members }
  | _ -> wrong ~what v "an object"

let find fields name =
  List.find_map
    (fun ((n : string Location.located), v) ->
      if n.it = name then Some v else None)
    fields.members

let member_what fields name =
  Printf.sprintf "the member '%s' of %s" name fields.what

let optional fields name decode =
  Option.map (decode ~what:(member_what fields name)) (find fields name)

let required fields name decode =
  match find fields name with
  | Some v -> decode ~what:(member_what fields name) v
  | None ->
      Error.compilation ~loc:fields.at "The member '%s' of %s is missing" name
        fields.what

let location fields name =
  match find fields name with Some v -> v.at | None -> fields.at

let string ~what (v : t) =
  match v.value with String s -> s | _ -> wrong ~what v "a string"

let bool ~what (v : t) =
  match v.value with Bool b -> b | _ -> wrong ~what v "a boolean"

let rational ~what (v : t) =
  match v.value with
  | Number n when not (String.exists (fun c -> c = 'e' || c = 'E' || c = '-') n)
    ->
      Grades.Rational.of_decimal n
  | _ -> wrong ~what v "a non-negative number without exponent"

let int ~what (v : t) =
  match v.value with
  | Number n when String.for_all is_digit n -> (
      match int_of_string_opt n with
      | Some i when i <= 0x7FFF_FFFF -> i
      | _ -> wrong ~what v "an integer below 2^31")
  | _ -> wrong ~what v "a non-negative integer"

let list decode ~what (v : t) =
  match v.value with
  | Array vs ->
      List.mapi
        (fun i v ->
          decode ~what:(Printf.sprintf "element %d of %s" (i + 1) what) v)
        vs
  | _ -> wrong ~what v "an array"
