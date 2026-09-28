(* A structural recursion guard in the style of structural termination
   checkers (Giménez, TYPES 1994; Abel's foetus, Abel and Altenkirch, JFP
   2002), with a single parameter fixed for all recursive calls: an abstract
   interpretation of the body tracks which variables are structural parts of
   which parameters, and every occurrence of the function must pass a strict
   part of the chosen parameter. *)

module Ast = Language.Ast
module Location = Utils.Location
module Error = Utils.Error
module Diagnostic = Utils.Diagnostic
module IntSet = Set.Make (Int)
module VariableMap = Ast.VariableMap

(* The positions [i] of the parameters [pᵢ] a value is at most ([le]) and
   strictly below ([lt]) in the structural order; [lt] is included in [le]. *)
type size = { le : IntSet.t; lt : IntSet.t }

type value =
  | Size of size
  | Tuple of value list
  | Partial of use
      (** the function applied to fewer arguments than its arity *)
  | Opaque

(* The function applied to [args] at [at]: a call when there are as many
   arguments as parameters, else an escape or a partial application. *)
and use = { args : argument list; at : Location.t }
and argument = { value : value; given_at : Location.t }

type env = { self : Ast.variable; arity : int; values : value VariableMap.t }

let parameter i = Size { le = IntSet.singleton i; lt = IntSet.empty }

let strict = function
  | Size { le; _ } -> Size { le; lt = le }
  | Tuple _ | Partial _ | Opaque -> Opaque

(* The variables of pattern [p] matched against value [v]. *)
let rec bind values (p : ('rho, 'eps) Ast.pattern) v =
  match p.it with
  | Ast.PVar x -> VariableMap.add x v values
  | Ast.PAnnotated (p, _) -> bind values p v
  | Ast.PAs (p, x) -> VariableMap.add x v (bind values p v)
  | Ast.PTuple ps -> (
      match v with
      | Tuple vs when List.compare_lengths ps vs = 0 ->
          List.fold_left2 bind values ps vs
      | Size _ -> List.fold_left (fun values p -> bind values p v) values ps
      | Tuple _ | Partial _ | Opaque ->
          List.fold_left (fun values p -> bind values p Opaque) values ps)
  | Ast.PVariant (_, Some p) | Ast.PSucc (p, _) -> bind values p (strict v)
  | Ast.PVariant (_, None) | Ast.PConst _ | Ast.PNonbinding -> values

let bind_env env p v = { env with values = bind env.values p v }

(* The partial applications within [v], added to the escapes [acc]. *)
let rec escapes v acc =
  match v with
  | Partial use -> use :: acc
  | Tuple vs -> List.fold_left (fun acc v -> escapes v acc) acc vs
  | Size _ | Opaque -> acc

let rec without_partials = function
  | Partial _ -> Opaque
  | Tuple vs -> Tuple (List.map without_partials vs)
  | (Size _ | Opaque) as v -> v

(* The value of expression [e] and the uses [acc] of the function extended by
   those of [e], newest first. The value may hold partial applications, which
   the caller either tracks or records as escaping. *)
let rec expression env (e : ('rho, 'eps) Ast.expression) acc =
  match e.it with
  | Ast.Var x when Ast.Variable.compare x env.self = 0 ->
      (Partial { args = []; at = e.at }, acc)
  | Ast.Var x -> (
      match VariableMap.find_opt x env.values with
      | Some (Partial use) -> (Partial { use with at = e.at }, acc)
      | Some v -> (v, acc)
      | None -> (Opaque, acc))
  | Ast.Const _ | Ast.Variant (_, None) -> (Opaque, acc)
  | Ast.Annotated (e, _) -> expression env e acc
  | Ast.Tuple es ->
      let acc, vs =
        List.fold_left_map
          (fun acc e ->
            let v, acc = expression env e acc in
            (acc, v))
          acc es
      in
      (Tuple vs, acc)
  | Ast.Variant (_, Some e) -> (Opaque, snd (consumed env e acc))
  | Ast.Lambda abs | Ast.PureLambda abs -> (Opaque, opaque env abs acc)
  | Ast.RecLambda (_, abs) ->
      let params, body = Ast.curried_layers abs in
      let env =
        List.fold_left (fun env p -> bind_env env p Opaque) env params
      in
      (Opaque, tail env body acc)
  | Ast.Handler (ret, ops) ->
      ( Opaque,
        Ast.OpNameMap.fold
          (fun _ abs acc -> opaque env abs acc)
          ops (opaque env ret acc) )

(* Expression [e] in a position its value escapes from. *)
and consumed env e acc =
  let v, acc = expression env e acc in
  (without_partials v, escapes v acc)

(* An abstraction whose parameter is unknown. *)
and opaque env (p, c) acc = tail (bind_env env p Opaque) c acc

(* The result of computation [c] and the uses of the function in it; the
   result is only tracked when [c] passes on the value of a subterm. *)
and computation env (c : ('rho, 'eps) Ast.computation) acc =
  match c.it with
  | Ast.Return e -> expression env e acc
  | Ast.Do (c1, (p, c2)) ->
      let v, acc = computation env c1 acc in
      computation (bind_env env p v) c2 acc
  | Ast.Apply (e1, e2) -> (
      let v1, acc = expression env e1 acc in
      let v2, acc = consumed env e2 acc in
      match v1 with
      | Partial { args; _ } ->
          let use =
            { args = args @ [ { value = v2; given_at = e2.at } ]; at = c.at }
          in
          if List.length use.args >= env.arity then (Opaque, use :: acc)
          else (Partial use, acc)
      | Size _ | Tuple _ | Opaque -> (Opaque, acc))
  | Ast.Match (e, cases) ->
      let v, acc = expression env e acc in
      ( Opaque,
        List.fold_left
          (fun acc (p, c) -> tail (bind_env env p v) c acc)
          acc cases )
  | Ast.Delay (_, c) -> (Opaque, tail env c acc)
  | Ast.Box (_, e, (p, c)) | Ast.Unbox (e, (p, c)) ->
      let v, acc = expression env e acc in
      computation (bind_env env p v) c acc
  | Ast.Perform (_, e, abs) ->
      let _, acc = consumed env e acc in
      (Opaque, opaque env abs acc)
  | Ast.Handle (c, e) ->
      let acc = tail env c acc in
      (Opaque, snd (consumed env e acc))

(* Computation [c] in a position its result escapes from. *)
and tail env c acc =
  let v, acc = computation env c acc in
  escapes v acc

(* Why a use of the function fails the guard at position [d]. *)
type failure = Missing of use | Not_smaller of use * argument

let failure d use =
  match List.nth_opt use.args d with
  | None -> Some (Missing use)
  | Some { value = Size { lt; _ }; _ } when IntSet.mem d lt -> None
  | Some arg -> Some (Not_smaller (use, arg))

let reject ~defined_at f d failure =
  let name = Ast.Variable.string_of f in
  let here = Diagnostic.place in
  let use, label =
    match failure with
    | Missing use ->
        ( use,
          {
            Diagnostic.span = use.at;
            text =
              Printf.sprintf "`%s` is used %s without its argument %d" name here
                (d + 1);
          } )
    | Not_smaller (use, arg) ->
        ( use,
          {
            Diagnostic.span = arg.given_at;
            text =
              Printf.sprintf
                "argument %d %s is not a structural part of parameter %d"
                (d + 1) here (d + 1);
          } )
  in
  Error.typing ~loc:use.at
    ~labels:
      [
        {
          Diagnostic.span = defined_at;
          text = Printf.sprintf "`%s` is defined %s" name here;
        };
        label;
      ]
    ~notes:
      [
        "match the parameter against a constructor, a list `x :: xs` or a \
         successor `m + 1`, and pass the part in the recursive call";
      ]
    "The recursive function `%s` might not terminate: no argument decreases \
     structurally in every recursive call"
    name

(* The guard on the recursive function [f] of abstraction [abs]: some position
   [d] at which every use of [f] passes a strict part of parameter [d]. *)
let guard ~defined_at f abs =
  let params, body = Ast.curried_layers abs in
  let values =
    List.fold_left
      (fun values (i, p) -> bind values p (parameter i))
      VariableMap.empty
      (List.mapi (fun i p -> (i, p)) params)
  in
  let arity = List.length params in
  let uses = List.rev (tail { self = f; arity; values } body []) in
  let failures =
    List.init arity (fun d -> (d, List.filter_map (failure d) uses))
  in
  let fewer candidate best =
    if List.compare_lengths (snd candidate) (snd best) < 0 then candidate
    else best
  in
  match failures with
  | _ when List.exists (fun (_, fs) -> fs = []) failures -> ()
  | [] -> ()
  | first :: rest -> (
      match List.fold_left (fun best c -> fewer c best) first rest with
      | d, failure :: _ -> reject ~defined_at f d failure
      | _, [] -> ())

let rec check_expression (e : ('rho, 'eps) Ast.expression) =
  match e.it with
  | Ast.Var _ | Ast.Const _ | Ast.Variant (_, None) -> ()
  | Ast.Annotated (e, _) | Ast.Variant (_, Some e) -> check_expression e
  | Ast.Tuple es -> List.iter check_expression es
  | Ast.Lambda abs | Ast.PureLambda abs -> check_abstraction abs
  | Ast.RecLambda (f, abs) ->
      guard ~defined_at:e.at f abs;
      check_abstraction abs
  | Ast.Handler (ret, ops) ->
      check_abstraction ret;
      Ast.OpNameMap.iter (fun _ abs -> check_abstraction abs) ops

and check_computation (c : ('rho, 'eps) Ast.computation) =
  match c.it with
  | Ast.Return e -> check_expression e
  | Ast.Do (c1, abs) ->
      check_computation c1;
      check_abstraction abs
  | Ast.Match (e, cases) ->
      check_expression e;
      List.iter check_abstraction cases
  | Ast.Apply (e1, e2) ->
      check_expression e1;
      check_expression e2
  | Ast.Delay (_, c) -> check_computation c
  | Ast.Box (_, e, abs) | Ast.Unbox (e, abs) | Ast.Perform (_, e, abs) ->
      check_expression e;
      check_abstraction abs
  | Ast.Handle (c, e) ->
      check_computation c;
      check_expression e

and check_abstraction ((_, c) : ('rho, 'eps) Ast.abstraction) =
  check_computation c
