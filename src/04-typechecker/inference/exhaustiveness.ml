(* Maranget's usefulness algorithm (L. Maranget, "Warnings for pattern
   matching", JFP 17(3), 2007): the rows of a clause matrix are exhaustive
   exactly when a row of wildcards is not useful with respect to them, and the
   search for a use builds a value that no row matches. *)

module Ast = Language.Ast
module Const = Language.Const
module Error = Utils.Error

type constructors = Ast.label -> (Ast.label * bool) list

(* Patterns up to their variables and annotations. A natural number is zero or
   a successor: [Nat n] is [succⁿ zero] and [Succ (p, k)] is [succᵏ p], with
   [k ≥ 1]. Booleans, strings and floats are [Literal]s. *)
type pattern =
  | Any
  | Variant of Ast.label * pattern option
  | Tuple of pattern list
  | Nat of Z.t
  | Succ of pattern * Z.t
  | Literal of Const.t

(* The constructor at the head of a pattern: a [Variant] with whether it takes
   an argument, a [Tuple] with its number of components, zero, successor or a
   literal. *)
type head =
  | Constructor of Ast.label * bool
  | Components of int
  | Zero
  | Successor
  | Constant of Const.t

let rec simplify (p : ('rho, 'eps) Ast.pattern) =
  match p.it with
  | Ast.PVar _ | Ast.PNonbinding -> Any
  | Ast.PAnnotated (p, _) | Ast.PAs (p, _) -> simplify p
  | Ast.PTuple ps -> Tuple (List.map simplify ps)
  | Ast.PVariant (lbl, arg) -> Variant (lbl, Option.map simplify arg)
  | Ast.PConst (Const.Nat n) -> Nat n
  | Ast.PConst c -> Literal c
  | Ast.PSucc (p, k) -> Succ (simplify p, k)

let head = function
  | Any -> None
  | Variant (lbl, arg) -> Some (Constructor (lbl, Option.is_some arg))
  | Tuple ps -> Some (Components (List.length ps))
  | Nat n when Z.equal n Z.zero -> Some Zero
  | Nat _ | Succ _ -> Some Successor
  | Literal c -> Some (Constant c)

let same_head h h' =
  match (h, h') with
  | Constructor (lbl, _), Constructor (lbl', _) ->
      Ast.Label.compare lbl lbl' = 0
  | Components n, Components n' -> n = n'
  | Zero, Zero | Successor, Successor -> true
  | Constant c, Constant c' -> Const.equal c c'
  | (Constructor _ | Components _ | Zero | Successor | Constant _), _ -> false

let arity = function
  | Constructor (_, true) | Successor -> 1
  | Constructor (_, false) | Zero | Constant _ -> 0
  | Components n -> n

(* Every head of the type of head [h], when there are finitely many. *)
let signature ~constructors = function
  | Constructor (lbl, _) ->
      Some
        (List.map (fun (lbl, arg) -> Constructor (lbl, arg)) (constructors lbl))
  | Components n -> Some [ Components n ]
  | Zero | Successor -> Some [ Zero; Successor ]
  | Constant (Const.Boolean _) ->
      Some [ Constant (Const.Boolean true); Constant (Const.Boolean false) ]
  | Constant (Const.Nat _ | Const.String _ | Const.Float _) -> None

(* The successor of pattern [p]. *)
let succ = function
  | Nat n -> Nat (Z.succ n)
  | Succ (p, k) -> Succ (p, Z.succ k)
  | p -> Succ (p, Z.one)

(* The pattern of head [h] with arguments [args]. *)
let rebuild h args =
  match (h, args) with
  | Constructor (lbl, false), [] -> Variant (lbl, None)
  | Constructor (lbl, true), [ arg ] -> Variant (lbl, Some arg)
  | Components _, args -> Tuple args
  | Zero, [] -> Nat Z.zero
  | Successor, [ arg ] -> succ arg
  | Constant c, [] -> Literal c
  | (Constructor _ | Zero | Successor | Constant _), _ ->
      invalid_arg "Exhaustiveness.rebuild"

(* The row [row] specialised to head [h]: the arguments of its first pattern
   followed by the rest, if the first pattern can have head [h]. *)
let specialise h row =
  match row with
  | [] -> None
  | p :: rest -> (
      match (p, h) with
      | Any, _ -> Some (List.init (arity h) (fun _ -> Any) @ rest)
      | Variant (lbl, arg), Constructor (lbl', _)
        when Ast.Label.compare lbl lbl' = 0 ->
          Some (Option.to_list arg @ rest)
      | Tuple ps, Components _ -> Some (ps @ rest)
      | Nat n, Zero when Z.equal n Z.zero -> Some rest
      | Nat n, Successor when Z.sign n > 0 -> Some (Nat (Z.pred n) :: rest)
      | Succ (p, k), Successor ->
          Some ((if Z.equal k Z.one then p else Succ (p, Z.pred k)) :: rest)
      | Literal c, Constant c' when Const.equal c c' -> Some rest
      | (Variant _ | Tuple _ | Nat _ | Succ _ | Literal _), _ -> None)

(* The row [row] without its first pattern, if that is a wildcard. *)
let default = function Any :: rest -> Some rest | _ :: _ | [] -> None

(* A literal of the type of the literals [cs] that is not among them. *)
let fresh_literal cs =
  let candidate i =
    match cs with
    | Const.Float _ :: _ -> Const.Float (float_of_int i)
    | _ -> Const.String (String.make i 'a')
  in
  let rec first i =
    let c = candidate i in
    if List.exists (Const.equal c) cs then first (i + 1) else c
  in
  first 0

(* A pattern whose head is none of the heads [hs] of a type that has more. *)
let outside ~constructors hs =
  match hs with
  | [] -> Any
  | h :: _ -> (
      match signature ~constructors h with
      | Some all -> (
          match
            List.find_opt (fun h -> not (List.exists (same_head h) hs)) all
          with
          | Some h -> rebuild h (List.init (arity h) (fun _ -> Any))
          | None -> Any)
      | None ->
          Literal
            (fresh_literal
               (List.filter_map
                  (function Constant c -> Some c | _ -> None)
                  hs)))

(* [missing ~constructors rows n] is a vector of [n] patterns, each standing
   for the values it matches, none of which the rows [rows] of length [n]
   match, if there is one. *)
let rec missing ~constructors rows n =
  match rows with
  | [] -> Some (List.init n (fun _ -> Any))
  | _ :: _ when n = 0 -> None
  | _ :: _ -> (
      let hs =
        List.rev
          (List.fold_left
             (fun hs row ->
               match Option.bind (List.nth_opt row 0) head with
               | Some h when not (List.exists (same_head h) hs) -> h :: hs
               | Some _ | None -> hs)
             [] rows)
      in
      let complete =
        match hs with
        | [] -> None
        | h :: _ ->
            Option.bind (signature ~constructors h) (fun all ->
                if List.for_all (fun h -> List.exists (same_head h) hs) all then
                  Some all
                else None)
      in
      match complete with
      | Some all ->
          List.find_map
            (fun h ->
              let k = arity h in
              Option.map
                (fun ps -> rebuild h (List.take k ps) :: List.drop k ps)
                (missing ~constructors
                   (List.filter_map (specialise h) rows)
                   (k + n - 1)))
            all
      | None ->
          Option.map
            (fun ps -> outside ~constructors hs :: ps)
            (missing ~constructors (List.filter_map default rows) (n - 1)))

(* Printing, in the surface syntax. *)

let is_label lbl lbl' = Ast.Label.compare lbl lbl' = 0

(* The head and the tail of the argument of [::]. *)
let cons_parts = function Tuple [ hd; tl ] -> (hd, tl) | _ -> (Any, Any)

let rec print_pattern p ppf =
  match p with
  | Variant (lbl, Some arg) when is_label lbl Ast.cons_label -> (
      let hd, tl = cons_parts arg in
      match list_elements p with
      | Some ps ->
          Format.fprintf ppf "[%t]" (fun ppf ->
              List.iteri
                (fun i p ->
                  if i > 0 then Format.pp_print_string ppf "; ";
                  print_pattern p ppf)
                ps)
      | None ->
          Format.fprintf ppf "%t :: %t" (print_cons_head hd) (print_pattern tl))
  | Variant (lbl, Some arg) ->
      Format.fprintf ppf "%s %t" (Ast.Label.string_of lbl) (print_atom arg)
  | Succ (p, k) -> Format.fprintf ppf "%t + %a" (print_atom p) Z.pp_print k
  | Any | Variant (_, None) | Tuple _ | Nat _ | Literal _ -> print_atom p ppf

(* The elements of a list pattern that ends in [[]]. *)
and list_elements = function
  | Variant (lbl, None) when is_label lbl Ast.nil_label -> Some []
  | Variant (lbl, Some arg) when is_label lbl Ast.cons_label ->
      let hd, tl = cons_parts arg in
      Option.map (fun ps -> hd :: ps) (list_elements tl)
  | Any | Variant _ | Tuple _ | Nat _ | Succ _ | Literal _ -> None

and print_cons_head p ppf =
  match p with
  | Variant (lbl, Some _) when not (is_label lbl Ast.cons_label) ->
      print_pattern p ppf
  | Any | Variant _ | Tuple _ | Nat _ | Succ _ | Literal _ -> print_atom p ppf

and print_atom p ppf =
  match p with
  | Any -> Format.pp_print_string ppf "_"
  | Variant (lbl, None) when is_label lbl Ast.nil_label ->
      Format.pp_print_string ppf "[]"
  | Variant (lbl, None) -> Format.pp_print_string ppf (Ast.Label.string_of lbl)
  | Tuple ps ->
      Format.fprintf ppf "(%t)" (fun ppf ->
          List.iteri
            (fun i p ->
              if i > 0 then Format.pp_print_string ppf ", ";
              print_pattern p ppf)
            ps)
  | Nat n -> Z.pp_print ppf n
  | Literal c -> Const.print c ppf
  | Variant (_, Some _) | Succ _ -> (
      match list_elements p with
      | Some _ -> print_pattern p ppf
      | None -> Format.fprintf ppf "(%t)" (print_pattern p))

(* Checking. *)

let reject ~at ~what ~note witness =
  Error.typing ~loc:at ~notes:[ note ]
    "This %s is not exhaustive: `%t` is not matched" what
    (print_pattern witness)

(* The cases [cases] of the match at [at]. A match without cases has a
   scrutinee of type [empty], which has no values. *)
let check_match ~constructors ~at cases =
  match cases with
  | [] -> ()
  | _ :: _ -> (
      let rows = List.map (fun (p, _) -> [ simplify p ]) cases in
      match missing ~constructors rows 1 with
      | Some (witness :: _) ->
          reject ~at ~what:"match"
            ~note:"a value that no case matches would stop the run" witness
      | Some [] | None -> ())

let check_pattern ~constructors (p : ('rho, 'eps) Ast.pattern) =
  match missing ~constructors [ [ simplify p ] ] 1 with
  | Some (witness :: _) ->
      reject ~at:p.at ~what:"pattern"
        ~note:"a value that the pattern does not match would stop the run"
        witness
  | Some [] | None -> ()

let rec check_expression ~constructors (e : ('rho, 'eps) Ast.expression) =
  match e.it with
  | Ast.Var _ | Ast.Const _ | Ast.Variant (_, None) -> ()
  | Ast.Annotated (e, _) | Ast.Variant (_, Some e) ->
      check_expression ~constructors e
  | Ast.Tuple es -> List.iter (check_expression ~constructors) es
  | Ast.Lambda abs | Ast.PureLambda abs | Ast.RecLambda (_, _, abs) ->
      check_abstraction ~constructors abs
  | Ast.Handler (ret, ops) ->
      check_abstraction ~constructors ret;
      Ast.OpNameMap.iter (fun _ abs -> check_abstraction ~constructors abs) ops

and check_computation ~constructors (c : ('rho, 'eps) Ast.computation) =
  match c.it with
  | Ast.Return e -> check_expression ~constructors e
  | Ast.Do (c1, abs) ->
      check_computation ~constructors c1;
      check_abstraction ~constructors abs
  | Ast.Match (e, cases) ->
      check_expression ~constructors e;
      check_match ~constructors ~at:c.at cases;
      List.iter (fun (_, c) -> check_computation ~constructors c) cases
  | Ast.Apply (e1, e2) ->
      check_expression ~constructors e1;
      check_expression ~constructors e2
  | Ast.Delay (_, c) -> check_computation ~constructors c
  | Ast.Box (_, e, abs) | Ast.Unbox (e, abs) | Ast.Perform (_, e, abs) ->
      check_expression ~constructors e;
      check_abstraction ~constructors abs
  | Ast.Handle (c, e) ->
      check_computation ~constructors c;
      check_expression ~constructors e

and check_abstraction ~constructors ((p, c) : ('rho, 'eps) Ast.abstraction) =
  check_pattern ~constructors p;
  check_computation ~constructors c
