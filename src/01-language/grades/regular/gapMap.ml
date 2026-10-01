type 'e t = (DelaySet.t * 'e) list

let support f =
  List.fold_left (fun acc (n, _) -> DelaySet.union acc n) DelaySet.empty f

let targets ~absent f g =
  let sf = support f and sg = support g in
  let alone sg (n, e) =
    if DelaySet.subset n sg then None else Some (e, absent)
  in
  List.concat_map
    (fun (n, e) ->
      List.filter_map
        (fun (n', e') ->
          if DelaySet.intersects n n' then Some (e, e') else None)
        g)
    f
  @ List.filter_map (alone sg) f
  @ List.filter_map
      (fun entry -> Option.map (fun (e, e') -> (e', e)) (alone sf entry))
      g

module type EXPRESSION = sig
  type t

  val universe : DelaySet.t
  val empty : t
  val top : t
  val union : t list -> t
  val inter : t list -> t
  val compl : t -> t
  val compare_form : t -> t -> int
end

module Make (E : EXPRESSION) = struct
  let equal_form e e' = E.compare_form e e' = 0

  let normalise entries =
    let entries =
      List.filter
        (fun (n, e) -> not (DelaySet.is_empty n || equal_form e E.empty))
        entries
    in
    let merge acc (n, e) =
      match acc with
      | (n', e') :: rest when equal_form e e' ->
          (DelaySet.union n' n, e) :: rest
      | _ -> (n, e) :: acc
    in
    List.rev
      (List.fold_left merge []
         (List.stable_sort (fun (_, e) (_, e') -> E.compare_form e e') entries))

  let full = [ (E.universe, E.top) ]

  let join f g =
    let sf = support f and sg = support g in
    normalise
      (List.concat_map
         (fun (n, e) ->
           List.map (fun (n', e') -> (DelaySet.inter n n', E.union [ e; e' ])) g)
         f
      @ List.map (fun (n, e) -> (DelaySet.diff n sg, e)) f
      @ List.map (fun (n, e) -> (DelaySet.diff n sf, e)) g)

  let meet f g =
    normalise
      (List.concat_map
         (fun (n, e) ->
           List.map (fun (n', e') -> (DelaySet.inter n n', E.inter [ e; e' ])) g)
         f)

  let complement f =
    normalise
      ((DelaySet.diff E.universe (support f), E.top)
      :: List.map (fun (n, e) -> (n, E.compl e)) f)

  let shift n f =
    List.fold_left
      (fun acc (n', e) -> join acc (normalise [ (DelaySet.sum n n', e) ]))
      [] f
end
