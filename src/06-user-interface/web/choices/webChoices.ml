type example = { path : string; group : string; title : string }

type t = {
  use_stdlib : bool;
  example : example option;
  grade : string option;
  backend : string option;
  settings : (string * BackendRegistry.settings) list;
}

let key = "tempore.choices.1"

(* The choices as a sequence of tokens: an option is a count, 0 or 1, followed
   by its value, and a list its length followed by its elements. *)
let tokens c =
  let option f = function None -> [ "0" ] | Some x -> "1" :: f x in
  let list f xs = string_of_int (List.length xs) :: List.concat_map f xs in
  List.concat
    [
      [ string_of_bool c.use_stdlib ];
      option (fun e -> [ e.path; e.group; e.title ]) c.example;
      option (fun g -> [ g ]) c.grade;
      option (fun b -> [ b ]) c.backend;
      list
        (fun (backend, settings) ->
          backend :: list (fun (k, v) -> [ k; v ]) settings)
        c.settings;
    ]

let encode c =
  String.concat ""
    (List.map
       (fun token -> string_of_int (String.length token) ^ ":" ^ token)
       (tokens c))

exception Malformed

(* A count written in decimal, without sign or leading zeros. *)
let natural t =
  match int_of_string_opt t with
  | Some n when n >= 0 && String.equal t (string_of_int n) -> n
  | _ -> raise Malformed

(* The tokens of [s], in order. *)
let split s =
  let n = String.length s in
  let rec go i acc =
    if i = n then List.rev acc
    else
      match String.index_from_opt s i ':' with
      | None -> raise Malformed
      | Some colon ->
          let length = natural (String.sub s i (colon - i)) in
          if colon + 1 + length > n then raise Malformed
          else go (colon + 1 + length) (String.sub s (colon + 1) length :: acc)
  in
  go 0 []

(* Readers of a value from the front of a list of tokens, returning the rest
   with it, the inverse of [tokens]. *)
let token = function t :: rest -> (t, rest) | [] -> raise Malformed

let count ts =
  let t, rest = token ts in
  (natural t, rest)

let option read ts =
  match count ts with
  | 0, rest -> (None, rest)
  | 1, rest ->
      let x, rest = read rest in
      (Some x, rest)
  | _ -> raise Malformed

let list read ts =
  let n, rest = count ts in
  let rec go n acc ts =
    if n = 0 then (List.rev acc, ts)
    else
      let x, ts = read ts in
      go (n - 1) (x :: acc) ts
  in
  go n [] rest

let decode s =
  try
    let ts = split s in
    let use_stdlib, ts =
      match token ts with
      | "true", ts -> (true, ts)
      | "false", ts -> (false, ts)
      | _ -> raise Malformed
    in
    let example, ts =
      option
        (fun ts ->
          let path, ts = token ts in
          let group, ts = token ts in
          let title, ts = token ts in
          ({ path; group; title }, ts))
        ts
    in
    let grade, ts = option token ts in
    let backend, ts = option token ts in
    let settings, ts =
      list
        (fun ts ->
          let backend, ts = token ts in
          let settings, ts =
            list
              (fun ts ->
                let k, ts = token ts in
                let v, ts = token ts in
                ((k, v), ts))
              ts
          in
          ((backend, settings), ts))
        ts
    in
    if ts <> [] then None
    else Some { use_stdlib; example; grade; backend; settings }
  with Malformed -> None

(* [first pairs] is [pairs] with every repeated key but the first removed. *)
let first pairs =
  List.rev
    (List.fold_left
       (fun kept (k, v) ->
         if List.mem_assoc k kept then kept else (k, v) :: kept)
       [] pairs)

let sanitise c =
  let accepted (inputs : BackendRegistry.input list) (k, v) =
    List.exists
      (fun (input : BackendRegistry.input) ->
        input.key = k
        &&
        match input.kind with
        | Text -> true
        | Choice options -> List.mem v options)
      inputs
  in
  {
    c with
    grade =
      Option.bind c.grade (fun g ->
          if List.mem_assoc g Grades.GradeRegistry.grade_modules then Some g
          else None);
    backend =
      Option.bind c.backend (fun b ->
          Option.map
            (fun (entry : BackendRegistry.entry) -> entry.key)
            (BackendRegistry.find b));
    settings =
      List.filter_map
        (fun (b, settings) ->
          Option.map
            (fun (entry : BackendRegistry.entry) ->
              (b, List.filter (accepted entry.inputs) (first settings)))
            (BackendRegistry.find b))
        (first c.settings);
  }
