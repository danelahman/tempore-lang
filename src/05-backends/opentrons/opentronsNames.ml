module Ast = Language.Ast
module LabelMap = Map.Make (Ast.Label)

type t = string Ast.VariableMap.t

let is_identifier_start = function
  | 'a' .. 'z' | 'A' .. 'Z' | '_' -> true
  | _ -> false

let is_identifier_char = function
  | '0' .. '9' -> true
  | c -> is_identifier_start c

(* The escape of the Unicode scalar value [u]: a prime as [_p], any other
   character that is not kept as [_u] followed by its code point in hex. *)
let escape u =
  let code = Uchar.to_int u in
  if code < 128 && is_identifier_char (Char.chr code) then
    String.make 1 (Char.chr code)
  else if code = Char.code '\'' then "_p"
  else Printf.sprintf "_u%x" code

(* [name] with its characters escaped. *)
let escaped_name name =
  let rec escaped i acc =
    if i >= String.length name then String.concat "" (List.rev acc)
    else
      let d = String.get_utf_8_uchar name i in
      escaped
        (i + Uchar.utf_decode_length d)
        (escape (Uchar.utf_decode_uchar d) :: acc)
  in
  escaped 0 []

let base name =
  match escaped_name name with
  | "" -> "v"
  | s when not (is_identifier_start s.[0]) -> "v" ^ s
  | s -> s

let identifier name index = Printf.sprintf "%s_%d" (base name) index

(* Whether [name] consists of ASCII letters and digits with single underscores
   between them. *)
let is_plain name =
  name <> ""
  && List.for_all
       (fun part -> part <> "" && String.for_all is_identifier_char part)
       (String.split_on_char '_' name)

(* The bytes of [name] in hexadecimal, two lowercase digits each. *)
let hexadecimal name =
  String.concat ""
    (List.map
       (fun c -> Printf.sprintf "%02x" (Char.code c))
       (List.of_seq (String.to_seq name)))

(* [name] if it is plain, and otherwise its escape with runs of underscores
   reduced to one, followed by its bytes in hexadecimal between underscores. *)
let symbol name =
  if is_plain name then name
  else
    let words =
      List.filter (( <> ) "") (String.split_on_char '_' (escaped_name name))
    in
    String.concat "_" (words @ [ hexadecimal name ]) ^ "_"

let operation op = "tempore_op_" ^ symbol (Ast.OpName.string_of op)

let constructor l =
  if Ast.Label.equal l Ast.nil_label then "tempore_con_nil"
  else if Ast.Label.equal l Ast.cons_label then "tempore_con_cons"
  else "tempore_con_" ^ symbol (Ast.Label.string_of l)

(* The variables bound by [p], prepended to [acc] in reverse order. *)
let rec pattern_binders acc (p : _ Ast.pattern) =
  match p.it with
  | Ast.PVar x -> x :: acc
  | Ast.PAs (p, x) -> pattern_binders (x :: acc) p
  | Ast.PAnnotated (p, _) | Ast.PVariant (_, Some p) | Ast.PSucc (p, _) ->
      pattern_binders acc p
  | Ast.PTuple ps -> List.fold_left pattern_binders acc ps
  | Ast.PVariant (_, None) | Ast.PConst _ | Ast.PNonbinding -> acc

(* The labels of [p], prepended to [acc]. *)
let rec pattern_labels acc (p : _ Ast.pattern) =
  match p.it with
  | Ast.PVariant (l, p) ->
      Option.fold ~none:(l :: acc) ~some:(pattern_labels (l :: acc)) p
  | Ast.PAs (p, _) | Ast.PAnnotated (p, _) | Ast.PSucc (p, _) ->
      pattern_labels acc p
  | Ast.PTuple ps -> List.fold_left pattern_labels acc ps
  | Ast.PVar _ | Ast.PConst _ | Ast.PNonbinding -> acc

(* The binders and labels of a term, each prepended to its list in [acc] in
   reverse order of occurrence. *)
let rec expression ((binders, labels) as acc) (e : _ Ast.expression) =
  match e.it with
  | Ast.Var _ | Ast.Const _ -> acc
  | Ast.Annotated (e, _) -> expression acc e
  | Ast.Tuple es -> List.fold_left expression acc es
  | Ast.Variant (l, e) ->
      Option.fold
        ~none:(binders, l :: labels)
        ~some:(expression (binders, l :: labels))
        e
  | Ast.Lambda abs | Ast.PureLambda abs -> abstraction acc abs
  | Ast.RecLambda (f, _, abs) -> abstraction (f :: binders, labels) abs
  | Ast.Handler (ret, ops) ->
      Ast.OpNameMap.fold
        (fun _ abs acc -> abstraction acc abs)
        ops (abstraction acc ret)

and computation acc (c : _ Ast.computation) =
  match c.it with
  | Ast.Return e -> expression acc e
  | Ast.Do (c, abs) -> abstraction (computation acc c) abs
  | Ast.Match (e, cases) -> List.fold_left abstraction (expression acc e) cases
  | Ast.Apply (e1, e2) -> expression (expression acc e1) e2
  | Ast.Delay (_, c) -> computation acc c
  | Ast.Box (_, e, abs) | Ast.Unbox (e, abs) | Ast.Perform (_, e, abs) ->
      abstraction (expression acc e) abs
  | Ast.Handle (c, e) -> expression (computation acc c) e

and abstraction (binders, labels) (p, c) =
  computation (pattern_binders binders p, pattern_labels labels p) c

let ty_def_labels labels (_, _, ty_def) =
  match ty_def with
  | Ast.TySum cases -> List.fold_left (fun acc (l, _) -> l :: acc) labels cases
  | Ast.TyInline _ -> labels

let command ((binders, labels) as acc) (cmd : _ Ast.command) =
  match cmd.it with
  | Ast.TyDef (_, defs) -> (binders, List.fold_left ty_def_labels labels defs)
  | Ast.OpSig _ -> acc
  | Ast.OpDefault (_, abs) -> abstraction acc abs
  | Ast.TopLet (x, e) -> expression (x :: binders, labels) e
  | Ast.TopDo c -> computation acc c

let collect commands =
  let binders, labels = List.fold_left command ([], []) commands in
  (List.rev binders, labels)

let of_commands commands =
  let binders, _ = collect commands in
  let names, _ =
    List.fold_left
      (fun (names, index) x ->
        if Ast.VariableMap.mem x names then (names, index)
        else
          ( Ast.VariableMap.add x
              (identifier (Ast.Variable.string_of x) index)
              names,
            index + 1 ))
      (Ast.VariableMap.empty, 0) binders
  in
  names

let variable names x = Ast.VariableMap.find_opt x names

type labels = { ranks : int LabelMap.t; sorted : Ast.label list }

let labels_of_commands commands =
  let _, labels = collect commands in
  let sorted =
    List.sort_uniq Ast.Label.compare (Ast.nil_label :: Ast.cons_label :: labels)
  in
  {
    ranks =
      List.fold_left
        (fun ranks (i, l) -> LabelMap.add l i ranks)
        LabelMap.empty
        (List.mapi (fun i l -> (i, l)) sorted);
    sorted;
  }

let label_rank labels l = LabelMap.find l labels.ranks
let label_list labels = labels.sorted
