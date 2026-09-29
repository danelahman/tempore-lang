(* Values for one grade unknown, read off the orderings of its sort. *)

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

(* The orderings [x ≾ v] with [x] free of [v], when every other ordering with [v] on its right side
   is valid. *)
let lows sort orderings =
  List.fold_right
    (fun (o : _ GradeNormal.ordering) acc ->
      Option.bind acc (fun lower ->
          if sort.is_unknown o.rhs && not (sort.occurs o.lhs) then
            Some (o :: lower)
          else if (not (sort.occurs o.rhs)) || valid sort o then Some lower
          else None))
    orderings (Some [])

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
  | Some ((first : _ GradeNormal.ordering) :: rest as discharged)
    when oracle.may_lower discharged ->
      Some
        {
          value =
            List.fold_left
              (fun x (o : _ GradeNormal.ordering) -> sort.join x o.lhs)
              first.lhs rest;
          discharged;
        }
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
  | Some [] when sort.unit_least && oracle.may_lower [] ->
      Some { value = sort.unit; discharged = [] }
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
    }
end
