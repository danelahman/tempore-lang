type t = {
  example : string option;
  grades : string option;
  backend : string option;
  line : int option;
}

let empty = { example = None; grades = None; backend = None; line = None }

type parameter = Example | Grades | Backend | Line

let name = function
  | Example -> "example"
  | Grades -> "grades"
  | Backend -> "backend"
  | Line -> "line"

let parameters = [ Example; Grades; Backend; Line ]

(* A positive number in decimal digits, leading zeros allowed, within the range
   of [int]. *)
let line_number v =
  if String.for_all (fun c -> '0' <= c && c <= '9') v then
    Option.bind (int_of_string_opt v) (fun n -> if n > 0 then Some n else None)
  else None

(* Percent-decoding of a component of a query, [+] standing for a space; [None]
   on a [%] not followed by two hexadecimal digits. *)
let decode s =
  let n = String.length s in
  let hex c =
    match c with
    | '0' .. '9' -> Some (Char.code c - Char.code '0')
    | 'a' .. 'f' -> Some (Char.code c - Char.code 'a' + 10)
    | 'A' .. 'F' -> Some (Char.code c - Char.code 'A' + 10)
    | _ -> None
  in
  let buffer = Buffer.create n in
  let rec go i =
    if i = n then Some (Buffer.contents buffer)
    else
      match s.[i] with
      | '%' -> (
          if i + 2 >= n then None
          else
            match (hex s.[i + 1], hex s.[i + 2]) with
            | Some h, Some l ->
                Buffer.add_char buffer (Char.chr ((16 * h) + l));
                go (i + 3)
            | _ -> None)
      | '+' ->
          Buffer.add_char buffer ' ';
          go (i + 1)
      | c ->
          Buffer.add_char buffer c;
          go (i + 1)
  in
  go 0

let unreserved = function
  | 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '-' | '.' | '_' | '~' | '/' -> true
  | _ -> false

let encode s =
  String.concat ""
    (List.map
       (fun c ->
         if unreserved c then String.make 1 c
         else Printf.sprintf "%%%02X" (Char.code c))
       (List.of_seq (String.to_seq s)))

let parse query =
  let query =
    if String.starts_with ~prefix:"?" query then
      String.sub query 1 (String.length query - 1)
    else query
  in
  (* the pairs of the query, in order, a pair without [=] of an empty value *)
  let pairs =
    List.filter_map
      (fun field ->
        if field = "" then None
        else
          match String.index_opt field '=' with
          | Some i ->
              Some
                ( decode (String.sub field 0 i),
                  String.sub field (i + 1) (String.length field - i - 1) )
          | None -> Some (decode field, ""))
      (String.split_on_char '&' query)
  in
  let value p =
    match List.assoc_opt (Some (name p)) pairs with
    | None -> `Absent
    | Some v -> (
        match decode v with
        | Some v when v <> "" && (p <> Line || line_number v <> None) ->
            `Value v
        | _ -> `Malformed)
  in
  let values = List.map (fun p -> (p, value p)) parameters in
  let get p = match List.assoc p values with `Value v -> Some v | _ -> None in
  ( {
      example = get Example;
      grades = get Grades;
      backend = get Backend;
      line = Option.bind (get Line) line_number;
    },
    List.filter_map
      (fun (p, v) -> match v with `Malformed -> Some p | _ -> None)
      values )

let serialise link =
  match
    List.filter_map
      (fun (p, v) -> Option.map (fun v -> name p ^ "=" ^ encode v) v)
      [
        (Example, link.example);
        (Grades, link.grades);
        (Backend, link.backend);
        (Line, Option.map string_of_int link.line);
      ]
  with
  | [] -> ""
  | fields -> "?" ^ String.concat "&" fields

type entry = { example : WebChoices.example; grade : string; backend : string }

type catalogue = {
  find : string -> entry option;
  default_of : string -> entry option;
}

let directory = "examples/"

(* The example at [path], relative to [examples] or to the project root. *)
let find_example catalogue path =
  match catalogue.find (directory ^ path) with
  | Some entry -> Some entry
  | None -> catalogue.find path

let known_grades g = List.mem_assoc g Grades.GradeRegistry.grade_modules
let known_backend b = Option.is_some (BackendRegistry.find b)

(* [first a b] is [a] if it has a value, and [b] otherwise. *)
let first a b = match a with Some _ -> a | None -> b

let resolve catalogue ~defaults remembered (link : t) =
  let base : WebChoices.t = Option.value ~default:defaults remembered in
  (* the value, if it names something known, or else the parameter ignored *)
  let checked p known v =
    match v with
    | Some v when known v -> (Some v, [])
    | Some _ -> (None, [ p ])
    | None -> (None, [])
  in
  let entry, ignored_example =
    match link.example with
    | Some path -> (
        match find_example catalogue path with
        | Some entry -> (Some entry, [])
        | None -> (None, [ Example ]))
    | None -> (None, [])
  in
  let grades, ignored_grades = checked Grades known_grades link.grades in
  let backend, ignored_backend = checked Backend known_backend link.backend in
  let ignored_line =
    if Option.is_some link.line && Option.is_none entry then [ Line ] else []
  in
  (* the example the choices name, besides the remembered one *)
  let entry =
    match (entry, backend) with
    | Some entry, _ -> Some entry
    | None, Some b -> (
        let remembered =
          Option.bind base.example (fun (e : WebChoices.example) ->
              catalogue.find e.path)
        in
        match remembered with
        | Some entry when entry.backend = b -> None
        | _ -> catalogue.default_of b)
    | None, None -> None
  in
  let choices =
    match entry with
    | Some entry ->
        {
          base with
          example = Some entry.example;
          grade = Some (Option.value ~default:entry.grade grades);
          backend = Some (Option.value ~default:entry.backend backend);
          settings = List.remove_assoc entry.backend base.settings;
        }
    | None ->
        {
          base with
          grade = first grades base.grade;
          backend = first backend base.backend;
        }
  in
  (choices, ignored_example @ ignored_grades @ ignored_backend @ ignored_line)

let of_choices catalogue (choices : WebChoices.t) =
  let relative path =
    if String.starts_with ~prefix:directory path then
      String.sub path (String.length directory)
        (String.length path - String.length directory)
    else path
  in
  match
    Option.bind choices.example (fun (e : WebChoices.example) ->
        catalogue.find e.path)
  with
  | Some entry ->
      let differing own = function
        | Some v when v <> own -> Some v
        | _ -> None
      in
      {
        example = Some (relative entry.example.path);
        grades = differing entry.grade choices.grade;
        backend = differing entry.backend choices.backend;
        line = None;
      }
  | None ->
      {
        example = None;
        grades = choices.grade;
        backend = choices.backend;
        line = None;
      }

let line_bytes source n =
  (* the bytes the lines start at, in order *)
  let starts =
    String.fold_left
      (fun (i, starts) c ->
        (i + 1, if c = '\n' then (i + 1) :: starts else starts))
      (0, [ 0 ]) source
    |> snd |> List.rev
  in
  Option.map
    (fun start ->
      let stop =
        Option.value ~default:(String.length source)
          (String.index_from_opt source start '\n')
      in
      let rec first i =
        if i < stop && (source.[i] = ' ' || source.[i] = '\t') then first (i + 1)
        else i
      in
      (first start, stop))
    (if n > 0 then List.nth_opt starts (n - 1) else None)
