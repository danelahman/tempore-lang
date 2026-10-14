module type EXPRESSION = sig
  type t
  type block

  val id : t -> int
  val empty : t
  val is_top : t -> bool
  val inter : t list -> t
  val compl : t -> t
  val nullable : t -> bool
  val delays : t -> DelaySet.t
  val gap : block -> t -> t GapMap.t
  val blocks : t list -> block list
end

module Make (E : EXPRESSION) = struct
  let edges ms r =
    List.concat_map (fun m -> List.map (fun (n, e) -> (n, m, e)) (E.gap m r)) ms

  include LanguageDecisions.Make (struct
    include E

    let final r = E.nullable r || not (DelaySet.is_empty (E.delays r))

    let agree r s =
      Bool.equal (E.nullable r) (E.nullable s)
      && DelaySet.equal (E.delays r) (E.delays s)

    let successors ms r = List.map (fun (_, _, e) -> e) (edges ms r)

    let pairs ms r s =
      List.concat_map
        (fun m -> GapMap.targets ~absent:E.empty (E.gap m r) (E.gap m s))
        ms
  end)

  let fewest_operations r =
    let ms = E.blocks [ r ] in
    let parent = Hashtbl.create 64 and queue = Queue.create () in
    let rec path e acc =
      match Hashtbl.find parent (E.id e) with
      | None -> acc
      | Some (n, m, d) -> path d ((n, m) :: acc)
    in
    let rec go () =
      match Queue.take_opt queue with
      | None -> None
      | Some e ->
          let finals = E.delays e in
          if not (DelaySet.is_empty finals) then Some (path e [], finals)
          else begin
            List.iter
              (fun (n, m, e') ->
                if not (Hashtbl.mem parent (E.id e') || known_empty e') then begin
                  Hashtbl.add parent (E.id e') (Some (n, m, e));
                  Queue.push e' queue
                end)
              (edges ms e);
            go ()
          end
    in
    Hashtbl.add parent (E.id r) None;
    Queue.push r queue;
    go ()
end
