(* Unit tests of [Skeleton]: unification, decoration and expansion, at the
   identity grade system over the first grade of [Grade.grade_modules]. *)

module Ast = Language.Ast
module Const = Language.Const
module Grade = Language.Grade
module GradeSystem = Language.GradeSystem
module GradeExp = Inference.GradeExp
module Skeleton = Inference.Skeleton

type check = { name : string; passed : bool; detail : string }

let check name passed detail = { name; passed; detail }

module G = (val snd (List.hd Grade.grade_modules) : Grade.S)
module GS = GradeSystem.Identity (G)
module X = GradeExp.Make (GS)
module K = Skeleton.Make (X)

(* Skeletons *)

let fresh_var name = Ast.TyParamModule.fresh name
let a_var, b_var, c_var = (fresh_var "a", fresh_var "b", fresh_var "c")
let a, b, c = Skeleton.(Var a_var, Var b_var, Var c_var)
let int = Skeleton.Const Const.IntegerTy
let bool = Skeleton.Const Const.BooleanTy
let ( @-> ) t u = Skeleton.Arrow (t, u)
let list_name = Ast.list_ty_name
let option_name = Ast.TyName.fresh "option"
let pair_name = Ast.TyName.fresh "pair"
let phantom_name = Ast.TyName.fresh "phantom"
let apply name ts = Skeleton.Apply (name, ts)

(* The aliases [pair] ['a pair = 'a * 'a] and ['a phantom = int]. *)
let unfold name args =
  match args with
  | [ t ] when Ast.TyName.compare name pair_name = 0 ->
      Some (Skeleton.Tuple [ t; t ])
  | [ _ ] when Ast.TyName.compare name phantom_name = 0 -> Some int
  | _ -> None

let eq ?(info = "") lhs rhs = { Skeleton.lhs; rhs; info }
let show_skeleton = Skeleton.to_string

let show_subst sigma =
  Ast.TyParamMap.bindings sigma
  |> List.map (fun (a, t) ->
      Ast.TyParamModule.string_of a ^ " := " ^ show_skeleton t)
  |> String.concat ", "

let show_step = function
  | Ast.Argument -> "Argument"
  | Ast.Result -> "Result"
  | Ast.Component i -> "Component " ^ string_of_int i
  | Ast.TypeArgument i -> "TypeArgument " ^ string_of_int i
  | Ast.BoxContent -> "BoxContent"
  | Ast.HandlerInput -> "HandlerInput"
  | Ast.HandlerOutput -> "HandlerOutput"

let show_failure (failure : string Skeleton.failure) =
  Printf.sprintf "%s: %s vs %s at [%s] (%s)" failure.info
    (show_skeleton failure.lhs)
    (show_skeleton failure.rhs)
    (String.concat "; " (List.map show_step failure.path))
    (match failure.mismatch with
    | Skeleton.Clash -> "clash"
    | Skeleton.Occurs a -> "occurs " ^ Ast.TyParamModule.string_of a)

let show_result show = function
  | Ok v -> "Ok " ^ show v
  | Error failure -> "Error " ^ show_failure failure

(* [binds name sigma expected] passes when [sigma] is exactly [expected]. *)
let binds name result expected =
  let expected = Ast.TyParamMap.of_seq (List.to_seq expected) in
  let passed =
    match result with
    | Ok sigma -> Ast.TyParamMap.equal Skeleton.equal sigma expected
    | Error _ -> false
  in
  check name passed
    ("expected Ok " ^ show_subst expected ^ ", got "
    ^ show_result show_subst result)

(* [fails name result ~info ~mismatch ~lhs ~rhs ~path] passes when [result]
   is the failure described. *)
let fails name result ~info ~mismatch ~lhs ~rhs ~path =
  let passed =
    match result with
    | Ok _ -> false
    | Error (failure : string Skeleton.failure) ->
        failure.info = info
        && failure.mismatch = mismatch
        && Skeleton.equal failure.lhs lhs
        && Skeleton.equal failure.rhs rhs
        && failure.path = path
  in
  let expected = show_failure { info; mismatch; lhs; rhs; path } in
  check name passed
    ("expected Error " ^ expected ^ ", got " ^ show_result show_subst result)

let unify = Skeleton.unify unfold

let unification =
  [
    binds "unify: solved left to right, idempotent"
      (unify [ eq a (int @-> b); eq b bool ])
      [ (a_var, int @-> bool); (b_var, bool) ];
    binds "unify: two unknowns" (unify [ eq a b ]) [ (a_var, b) ];
    binds "unify: an unknown with itself" (unify [ eq (a @-> a) (a @-> a) ]) [];
    binds "unify: tuples componentwise"
      (unify [ eq (Skeleton.Tuple [ a; int ]) (Skeleton.Tuple [ bool; b ]) ])
      [ (a_var, bool); (b_var, int) ];
    binds "unify: boxes and handlers"
      (unify
         [
           eq
             (Skeleton.Box (Skeleton.Handler (a, int)))
             (Skeleton.Box (Skeleton.Handler (bool, b)));
         ])
      [ (a_var, bool); (b_var, int) ];
    fails "unify: occurs check"
      (unify [ eq ~info:"loop" a (a @-> int) ])
      ~info:"loop" ~mismatch:(Skeleton.Occurs a_var) ~lhs:a ~rhs:(a @-> int)
      ~path:[];
    fails "unify: occurs check through a binding"
      (unify
         [
           eq a (b @-> int);
           eq ~info:"loop" (Skeleton.Tuple [ b ]) (Skeleton.Tuple [ a ]);
         ])
      ~info:"loop" ~mismatch:(Skeleton.Occurs b_var) ~lhs:b ~rhs:(b @-> int)
      ~path:[ Ast.Component 1 ];
    fails "unify: head mismatch"
      (unify
         [ eq ~info:"heads" (apply list_name [ a ]) (apply option_name [ a ]) ])
      ~info:"heads" ~mismatch:Skeleton.Clash ~lhs:(apply list_name [ a ])
      ~rhs:(apply option_name [ a ]) ~path:[];
    fails "unify: arity mismatch"
      (unify
         [ eq ~info:"arity" (Skeleton.Tuple [ a; b ]) (Skeleton.Tuple [ a ]) ])
      ~info:"arity" ~mismatch:Skeleton.Clash
      ~lhs:(Skeleton.Tuple [ a; b ])
      ~rhs:(Skeleton.Tuple [ a ]) ~path:[];
    fails "unify: constructor arguments"
      (unify
         [
           eq ~info:"args" (apply list_name [ int ]) (apply list_name [ bool ]);
         ])
      ~info:"args" ~mismatch:Skeleton.Clash ~lhs:int ~rhs:bool
      ~path:[ Ast.TypeArgument 1 ];
    binds "unify: an alias unfolded against a tuple"
      (unify [ eq (apply pair_name [ a ]) (Skeleton.Tuple [ int; b ]) ])
      [ (a_var, int); (b_var, int) ];
    binds "unify: an alias unfolded on the right"
      (unify
         [
           eq
             (Skeleton.Tuple [ bool; bool ] @-> int)
             (apply pair_name [ a ] @-> apply phantom_name [ b ]);
         ])
      [ (a_var, bool) ];
    fails "unify: an alias that mismatches after unfolding"
      (unify
         [ eq ~info:"alias" (bool @-> int) (apply pair_name [ a ] @-> int) ])
      ~info:"alias" ~mismatch:Skeleton.Clash ~lhs:bool
      ~rhs:(Skeleton.Tuple [ a; a ])
      ~path:[ Ast.Argument ];
    binds "unify: an alias of one head ignoring its arguments"
      (unify [ eq (apply phantom_name [ a ]) (apply phantom_name [ bool ]) ])
      [];
    binds "unify: an unknown bound to an alias unfolded"
      (unify [ eq a (apply pair_name [ int ]) ])
      [ (a_var, apply pair_name [ int ]) ];
    fails "unify: the payload of the failing equation"
      (unify
         [
           eq ~info:"first" b bool;
           eq ~info:"second" (int @-> b) (int @-> int);
           eq ~info:"third" c c;
         ])
      ~info:"second" ~mismatch:Skeleton.Clash ~lhs:bool ~rhs:int
      ~path:[ Ast.Result ];
    fails "unify: a path through a handler"
      (unify
         [
           eq ~info:"handler"
             (Skeleton.Handler (int, Skeleton.Tuple [ a; int ]))
             (Skeleton.Handler (int, Skeleton.Tuple [ a; bool ]));
         ])
      ~info:"handler" ~mismatch:Skeleton.Clash ~lhs:int ~rhs:bool
      ~path:[ Ast.HandlerOutput; Ast.Component 2 ];
  ]

(* Open types *)

let ty_int : K.ty = Ast.TyConst Const.IntegerTy
let ty_bool : K.ty = Ast.TyConst Const.BooleanTy
let ty_a, ty_b, ty_c = Ast.(TyParam a_var, TyParam b_var, TyParam c_var)
let pure = X.Eps.unit
let ( --> ) ty ty' : K.ty = Ast.TyArrow (ty, Ast.CompTy (ty', pure))
let demand ?(info = "") lhs rhs = { Inference.GradeNormal.lhs; rhs; info }

(* The shape of skeleton [t]: [t] with every unknown identified. *)
let identify =
  let one = Skeleton.Var (Ast.TyParamModule.fresh "shape") in
  fun t ->
    let sigma =
      Ast.TyParamSet.fold
        (fun a -> Ast.TyParamMap.add a one)
        (Skeleton.free_vars t) Ast.TyParamMap.empty
    in
    Skeleton.apply sigma t

let shape ty = identify (Skeleton.of_ty ty)

(* The grades and unknowns of [ty], left to right. *)
let contents ty =
  let rhos, epss, params =
    Ast.fold_ty
      ~on_param:(fun a (rhos, epss, params) -> (rhos, epss, a :: params))
      ~on_rho:(fun rho (rhos, epss, params) -> (rho :: rhos, epss, params))
      ~on_eps:(fun eps (rhos, epss, params) -> (rhos, eps :: epss, params))
      ty ([], [], [])
  in
  (List.rev rhos, List.rev epss, List.rev params)

let rho_vars rhos =
  List.filter_map (function X.Rho_var v -> Some v | _ -> None) rhos

let eps_vars epss =
  List.filter_map (function X.Eps_var v -> Some v | _ -> None) epss

let distinct compare xs =
  List.compare_lengths (List.sort_uniq compare xs) xs = 0

(* [fresh_grades ty] is whether every grade of [ty] is a variable, all
   distinct. *)
let fresh_grades ty =
  let rhos, epss, _ = contents ty in
  let rho_vars = rho_vars rhos and eps_vars = eps_vars epss in
  List.compare_lengths rho_vars rhos = 0
  && List.compare_lengths eps_vars epss = 0
  && distinct GradeExp.Rho_var.compare rho_vars
  && distinct GradeExp.Eps_var.compare eps_vars

let show_ty ty = Skeleton.to_string (Skeleton.of_ty ty)

let decoration =
  let skeleton =
    Skeleton.Box (Skeleton.Tuple [ a @-> a; Skeleton.Handler (int, a) ])
  in
  let ty = K.decorate skeleton in
  let rhos, epss, params = contents ty in
  [
    check "decorate: the shape"
      (Skeleton.equal (shape ty) (identify skeleton))
      (show_ty ty);
    check "decorate: one fresh grade variable per position"
      (fresh_grades ty && List.length rhos = 1 && List.length epss = 3)
      (show_ty ty);
    check "decorate: a fresh unknown per occurrence"
      (List.length params = 3
      && distinct Ast.TyParamModule.compare (a_var :: params))
      (show_ty ty);
    check "decorate: fresh on every call"
      (fresh_grades (Ast.TyTuple [ ty; K.decorate skeleton ]))
      (show_ty ty);
  ]

let expand = K.expand unfold

let show_theta theta =
  Ast.TyParamMap.bindings theta
  |> List.map (fun (a, ty) ->
      Ast.TyParamModule.string_of a ^ " := " ^ show_ty ty)
  |> String.concat ", "

(* [expands name demands expected] passes when [expand demands] instantiates
   exactly the unknowns of [expected], each by a type of the skeleton given
   up to the naming of unknowns and with fresh grades, and leaves the two sides
   of every demand of the same shape. *)
let expands name demands expected =
  let result = expand demands in
  let passed =
    match result with
    | Error _ -> false
    | Ok theta ->
        let instantiates (a, skeleton) =
          match Ast.TyParamMap.find_opt a theta with
          | Some ty ->
              fresh_grades ty && Skeleton.equal (shape ty) (identify skeleton)
          | None -> false
        in
        let same_shape ({ lhs; rhs; _ } : _ Inference.GradeNormal.ordering) =
          Skeleton.equal
            (shape (K.substitute theta lhs))
            (shape (K.substitute theta rhs))
        in
        Ast.TyParamMap.cardinal theta = List.length expected
        && List.for_all instantiates expected
        && List.for_all same_shape demands
        && fresh_grades
             (Ast.TyTuple (List.map snd (Ast.TyParamMap.bindings theta)))
  in
  check name passed ("got " ^ show_result show_theta result)

let expand_fails name demands ~info ~mismatch ~lhs ~rhs ~path =
  fails name
    (expand demands |> Result.map (fun _ -> Ast.TyParamMap.empty))
    ~info ~mismatch ~lhs ~rhs ~path

let box ty : K.ty = Ast.TyBox (X.Rho.unit, ty)

let handler ty ty' : K.ty =
  Ast.TyHandler (Ast.CompTy (ty, pure), Ast.CompTy (ty', pure))

let expansion =
  [
    expands "expand: an unknown against an arrow"
      [ demand ty_a (ty_int --> ty_int) ]
      [ (a_var, int @-> int) ];
    expands "expand: a box against an unknown"
      [ demand (box ty_int) ty_a ]
      [ (a_var, Skeleton.Box int) ];
    expands "expand: an unknown against a tuple with an unknown"
      [ demand ty_a (Ast.TyTuple [ ty_int; ty_b ]) ]
      [ (a_var, Skeleton.Tuple [ int; b ]) ];
    expands "expand: an unknown against a handler"
      [ demand (handler ty_b ty_int) ty_a ]
      [ (a_var, Skeleton.Handler (b, int)) ];
    expands "expand: demands chained through unknowns"
      [ demand ty_a ty_b; demand ty_b (ty_int --> ty_bool); demand ty_c ty_a ]
      [ (a_var, int @-> bool); (b_var, int @-> bool); (c_var, int @-> bool) ];
    expands "expand: an unknown under a former"
      [ demand (ty_a --> ty_int) (box ty_bool --> ty_b) ]
      [ (a_var, Skeleton.Box bool); (b_var, int) ];
    expands "expand: unknowns only" [ demand ty_a ty_b; demand ty_b ty_c ] [];
    expands "expand: invariant constructor arguments"
      [
        demand
          (Ast.TyApply (list_name, [ ty_a ]))
          (Ast.TyApply (list_name, [ ty_int --> ty_b ]));
      ]
      [ (a_var, int @-> b) ];
    expands "expand: an unknown against an alias"
      [ demand ty_a (Ast.TyApply (pair_name, [ box ty_int ])) ]
      [ (a_var, apply pair_name [ Skeleton.Box int ]) ];
    expand_fails "expand: incompatible shapes"
      [
        demand ~info:"arrow" ty_a (ty_int --> ty_int);
        demand ~info:"base" ty_bool ty_a;
      ]
      ~info:"base" ~mismatch:Skeleton.Clash ~lhs:bool ~rhs:(int @-> int)
      ~path:[];
    expand_fails "expand: a cyclic shape"
      [ demand ~info:"cycle" (ty_b --> ty_a) (ty_int --> box ty_a) ]
      ~info:"cycle" ~mismatch:(Skeleton.Occurs a_var) ~lhs:a
      ~rhs:(Skeleton.Box a) ~path:[ Ast.Result ];
  ]

let () =
  let checks = unification @ decoration @ expansion in
  let failures = List.filter (fun c -> not c.passed) checks in
  List.iter (fun c -> Printf.printf "FAIL %s: %s\n" c.name c.detail) failures;
  Printf.printf "%d of %d checks passed\n"
    (List.length checks - List.length failures)
    (List.length checks);
  if failures <> [] then exit 1
