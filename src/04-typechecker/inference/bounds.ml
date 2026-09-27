(* Values for one grade unknown, read off the orderings of its sort. *)

type 'e sort = {
  equal : 'e -> 'e -> bool;
  occurs : 'e -> bool;
  is_unknown : 'e -> bool;
  leq : 'e -> 'e -> bool;
  join : 'e -> 'e -> 'e;
}

type ('e, 'a) lows = {
  lower : 'e list;
  lower_rest : ('e, 'a) GradeNormal.ordering list;
}

type ('e, 'a) ups = {
  cap : 'e;
  upper_rest : ('e, 'a) GradeNormal.ordering list;
}

let reflexive sort (o : _ GradeNormal.ordering) = sort.equal o.lhs o.rhs

let lows sort orderings =
  List.fold_right
    (fun (o : _ GradeNormal.ordering) acc ->
      Option.bind acc (fun acc ->
          if sort.is_unknown o.rhs && not (sort.occurs o.lhs) then
            Some { acc with lower = o.lhs :: acc.lower }
          else if reflexive sort o || not (sort.occurs o.rhs) then
            Some { acc with lower_rest = o :: acc.lower_rest }
          else None))
    orderings
    (Some { lower = []; lower_rest = [] })

(* The orderings other than those [cap] caps, when every ordering with [v] on
   its left side is reflexive or capped. *)
let capped sort orderings cap =
  List.fold_right
    (fun (o : _ GradeNormal.ordering) acc ->
      Option.bind acc (fun rest ->
          if reflexive sort o || not (sort.occurs o.lhs) then Some (o :: rest)
          else if
            sort.is_unknown o.lhs && (sort.equal o.rhs cap || sort.leq cap o.rhs)
          then Some rest
          else None))
    orderings (Some [])

let ups sort orderings =
  List.find_map
    (fun (o : _ GradeNormal.ordering) ->
      if sort.is_unknown o.lhs && not (sort.occurs o.rhs) then
        Option.map
          (fun upper_rest -> { cap = o.rhs; upper_rest })
          (capped sort orderings o.rhs)
      else None)
    orderings

let free_right sort orderings =
  List.for_all
    (fun (o : _ GradeNormal.ordering) ->
      reflexive sort o || not (sort.occurs o.rhs))
    orderings

let free_left sort orderings =
  List.for_all
    (fun (o : _ GradeNormal.ordering) ->
      reflexive sort o || not (sort.occurs o.lhs))
    orderings

let join_all sort x xs = List.fold_left sort.join x xs
