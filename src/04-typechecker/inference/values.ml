(* Values for one grade unknown, read off the orderings of its sort. *)

type 'e shape = Square | Left of 'e | Right of 'e | Other

type 'e cycles = {
  replace : 'e -> 'e -> 'e;
  shape : 'e -> 'e shape;
  closure : 'e -> 'e option;
  mul : 'e -> 'e -> 'e;
}

type 'e sort = {
  self : 'e;
  is_unknown : 'e -> bool;
  earlier : 'e -> bool option;
  occurs : 'e -> bool;
  equal : 'e -> 'e -> bool;
  valid : 'e -> 'e -> bool;
  join : 'e -> 'e -> 'e;
  canon : 'e -> 'e;
  below_unit : 'e -> bool;
  unit : 'e;
  top : 'e;
  unit_least : bool;
  cycles : 'e cycles option;
}

type ('e, 'a) oracle = {
  may_lower : ('e, 'a) GradeNormal.ordering list -> bool;
  may_raise : ('e, 'a) GradeNormal.ordering list -> bool;
}

type ('e, 'a) value = {
  value : 'e;
  discharged : ('e, 'a) GradeNormal.ordering list;
}

let reflexive sort (o : _ GradeNormal.ordering) = sort.equal o.lhs o.rhs
let valid sort (o : _ GradeNormal.ordering) = sort.valid o.lhs o.rhs

(* The orderings [x ≾ v] with [x] free of [v], and the cycles [p ≾ v] with
   [v] in [p] where the sort reads cycles, when every other ordering with [v]
   on its right side is valid. *)
let lows sort orderings =
  List.fold_right
    (fun (o : _ GradeNormal.ordering) acc ->
      Option.bind acc (fun (lower, cycles) ->
          if sort.is_unknown o.rhs && not (sort.occurs o.lhs) then
            Some (o :: lower, cycles)
          else if (not (sort.occurs o.rhs)) || valid sort o then
            Some (lower, cycles)
          else if sort.is_unknown o.rhs && Option.is_some sort.cycles then
            Some (lower, o :: cycles)
          else None))
    orderings
    (Some ([], []))

(* The least value of [v] at or above [base] at which every cycle holds:
   [V = B* · base · C*], and its closure [V⁺] where a cycle is [v · v ≾ v],
   [B] and [C] the joins of the multipliers of the cycles [b · v ≾ v] and
   [v · c ≾ v]. [X* · y] is [y] where each multiplier leaves [y], decided,
   and otherwise [y ⊔ X⁺ · y], likewise [y · X*]; the closure [x⁺] of an
   expression is [x] where [x · x ≾ x] is decided, and otherwise that of its
   value. The value is taken where every cycle holds at it. *)
let settle sort cycles base =
  match (cycles, sort.cycles) with
  | [], _ -> Some base
  | _ :: _, None -> None
  | _ :: _, Some c ->
      let open Option.Syntax in
      let closure x =
        if sort.valid (c.mul x x) x then Some x else c.closure x
      in
      let shapes =
        List.map (fun (o : _ GradeNormal.ordering) -> c.shape o.lhs) cycles
      in
      let star ~left multipliers y =
        let times x = if left then c.mul x y else c.mul y x in
        match multipliers with
        | [] -> Some y
        | _ when List.for_all (fun m -> sort.valid (times m) y) multipliers ->
            Some y
        | m :: ms ->
            Option.map
              (fun plus -> sort.join y (times plus))
              (closure (List.fold_left sort.join m ms))
      in
      let* y =
        star ~left:true
          (List.filter_map (function Left b -> Some b | _ -> None) shapes)
          base
      in
      let* z =
        star ~left:false
          (List.filter_map (function Right b -> Some b | _ -> None) shapes)
          y
      in
      let* value =
        if List.exists (function Square -> true | _ -> false) shapes then
          closure z
        else Some z
      in
      let value = sort.canon value in
      if
        List.for_all
          (fun (o : _ GradeNormal.ordering) ->
            sort.valid (c.replace value o.lhs) value)
          cycles
      then Some value
      else None

(* The orderings [cap] caps, when every ordering with [v] on its left side is
   reflexive, capped or valid. *)
let capped sort orderings cap =
  List.fold_right
    (fun (o : _ GradeNormal.ordering) acc ->
      Option.bind acc (fun capped ->
          if reflexive sort o || not (sort.occurs o.lhs) then Some capped
          else if sort.is_unknown o.lhs && sort.valid cap o.rhs then
            Some (o :: capped)
          else if valid sort o then Some capped
          else None))
    orderings (Some [])

let lower sort oracle orderings =
  match lows sort orderings with
  | Some (((first : _ GradeNormal.ordering) :: rest as lower), cycles)
    when oracle.may_lower (lower @ cycles) ->
      Option.map
        (fun value -> { value; discharged = lower @ cycles })
        (settle sort cycles
           (List.fold_left
              (fun x (o : _ GradeNormal.ordering) -> sort.join x o.lhs)
              first.lhs rest))
  | Some _ | None -> None

let raise sort oracle orderings =
  let cap (o : _ GradeNormal.ordering) =
    if sort.is_unknown o.lhs && not (sort.occurs o.rhs) then
      Option.map
        (fun discharged -> { value = o.rhs; discharged })
        (capped sort orderings o.rhs)
    else None
  in
  match List.find_map cap orderings with
  | Some v when oracle.may_raise v.discharged -> Some v
  | Some _ | None -> None

let least sort oracle orderings =
  match lows sort orderings with
  | Some ([], cycles) when sort.unit_least && oracle.may_lower cycles ->
      Option.map
        (fun value -> { value; discharged = cycles })
        (settle sort cycles sort.unit)
  | Some _ | None -> None

let free_right sort orderings =
  List.for_all
    (fun (o : _ GradeNormal.ordering) ->
      (not (sort.occurs o.rhs)) || valid sort o)
    orderings

let free_left sort orderings =
  List.for_all
    (fun (o : _ GradeNormal.ordering) ->
      (not (sort.occurs o.lhs)) || valid sort o)
    orderings

let top sort oracle orderings =
  if free_left sort orderings && oracle.may_raise [] then
    Some { value = sort.top; discharged = [] }
  else None

let forces_unit sort (o : _ GradeNormal.ordering) =
  sort.unit_least && sort.is_unknown (sort.canon o.lhs) && sort.below_unit o.rhs

let equate sort ~entails orderings =
  List.find_map
    (fun (o : _ GradeNormal.ordering) ->
      let facing =
        if sort.is_unknown o.lhs then Some o.rhs
        else if sort.is_unknown o.rhs then Some o.lhs
        else None
      in
      Option.bind facing (fun b ->
          if
            (match sort.earlier b with
              | Some earlier -> earlier
              | None -> not (sort.occurs b))
            && entails sort.self b && entails b sort.self
          then Some b
          else None))
    orderings

module Make (X : GradeExp.S) = struct
  module N = GradeNormal.Make (X)
  module E = Entail.Make (X)

  (* The shape of a cycle's left side from its normal form, [is_v] telling
     the atoms of [v] and [read_back] reading a product back. *)
  let shape ~normal ~is_v ~read_back e =
    let free atoms =
      atoms <> []
      && List.for_all
           (function
             | GradeNormal.Var a -> not (is_v a) | GradeNormal.Const _ -> true)
           atoms
    in
    match normal e with
    | [ [ GradeNormal.Var a; GradeNormal.Var b ] ] when is_v a && is_v b ->
        Square
    | [ GradeNormal.Var a :: rest ] when is_v a && free rest ->
        Right (read_back rest)
    | [ atoms ] -> (
        match List.rev atoms with
        | GradeNormal.Var a :: rest when is_v a && free rest ->
            Left (read_back (List.rev rest))
        | _ -> Other)
    | _ -> Other

  let eps bounds k =
    {
      self = X.Eps.var k;
      is_unknown =
        (function X.Eps_var k' -> X.Eps_var.equal k k' | _ -> false);
      earlier =
        (function X.Eps_var j -> Some (X.Eps_var.compare j k < 0) | _ -> None);
      occurs = X.Eps.mem_var k;
      equal = X.Eps.equal bounds;
      valid = E.Eps.valid bounds;
      join = X.Eps.join;
      canon = N.Eps.canon bounds;
      below_unit = (fun e -> E.Eps.decided bounds e X.Eps.unit);
      unit = X.Eps.unit;
      top = X.Eps.top;
      unit_least = X.GS.E.unit_least;
      cycles =
        Some
          {
            replace =
              (fun x ->
                X.Eps.subst
                  { X.empty_subst with eps_subst = X.Eps_var.Map.singleton k x });
            shape =
              shape ~normal:(N.Eps.normal bounds) ~is_v:(X.Eps_var.equal k)
                ~read_back:N.Eps.read_back_product;
            closure =
              (fun e ->
                Option.bind (X.Eps.value e) (fun c ->
                    Option.map X.Eps.const (X.GS.E.plus c)));
            mul = X.Eps.mul;
          };
    }

  let rho bounds k =
    {
      self = X.Rho.var k;
      is_unknown =
        (function X.Rho_var k' -> X.Rho_var.equal k k' | _ -> false);
      earlier =
        (function X.Rho_var j -> Some (X.Rho_var.compare j k < 0) | _ -> None);
      occurs = X.Rho.mem_rho_var k;
      equal = X.Rho.equal bounds;
      valid = E.Rho.valid bounds;
      join = X.Rho.join;
      canon = N.Rho.canon bounds;
      below_unit = (fun e -> E.Rho.decided bounds e X.Rho.unit);
      unit = X.Rho.unit;
      top = X.Rho.top;
      unit_least = X.GS.R.unit_least;
      cycles =
        Some
          {
            replace =
              (fun x ->
                X.Rho.subst
                  { X.empty_subst with rho_subst = X.Rho_var.Map.singleton k x });
            shape =
              shape ~normal:(N.Rho.normal bounds)
                ~is_v:(function
                  | N.Resource k' -> X.Rho_var.equal k k' | N.Image _ -> false)
                ~read_back:N.Rho.read_back_product;
            closure =
              (fun e ->
                Option.bind (X.Rho.value e) (fun c ->
                    Option.map X.Rho.const (X.GS.R.plus c)));
            mul = X.Rho.mul;
          };
    }

  let image bounds k =
    {
      self = X.Rho.map (X.Eps.var k);
      is_unknown =
        (function
        | X.Rho_map (X.Eps_var k') -> X.Eps_var.equal k k'
        | _ -> false);
      earlier =
        (function
        | X.Rho_map (X.Eps_var j) -> Some (X.Eps_var.compare j k < 0)
        | _ -> None);
      occurs = X.Rho.mem_eps_var k;
      equal = X.Rho.equal bounds;
      valid = E.Rho.valid bounds;
      join = X.Rho.join;
      canon = N.Rho.canon bounds;
      below_unit = (fun e -> E.Rho.decided bounds e X.Rho.unit);
      unit = X.Rho.unit;
      top = X.Rho.top;
      unit_least = X.GS.E.unit_least && X.GS.unit_reflecting;
      cycles = None;
    }
end
