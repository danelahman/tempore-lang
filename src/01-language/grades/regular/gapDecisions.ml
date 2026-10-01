module type EXPRESSION = sig
  type t
  type block

  val hash : t -> int
  val empty : t
  val is_top : t -> bool
  val inter : t list -> t
  val compl : t -> t
  val nullable : t -> bool
  val delays : t -> DelaySet.t
  val gap : block -> t -> t GapMap.t
  val blocks : t list -> block list
end

(** Tables by pairs of numbers. *)
module Pairs = Hashtbl.Make (struct
  type t = int * int

  let equal (i, j) (i', j') = Int.equal i i' && Int.equal j j'
  let hash (i, j) = Grade.combine i j
end)

module Make (E : EXPRESSION) = struct
  let equal_form r s = E.hash r = E.hash s

  let edges ms r =
    List.concat_map (fun m -> List.map (fun (n, e) -> (n, m, e)) (E.gap m r)) ms

  (* The emptiness of the expressions explored, by their numbers. *)
  let emptiness : (int, bool) Hashtbl.t = Hashtbl.create 4096
  let known_empty r = Hashtbl.find_opt emptiness (E.hash r) = Some true

  let record r seen found =
    if found then Hashtbl.replace emptiness (E.hash r) false
    else Hashtbl.iter (fun id _ -> Hashtbl.replace emptiness id true) seen

  (** [inhabited r] is whether some gap derivative of [r] has a delay, found by
      depth-first exploration; the expressions known to be empty are not
      explored. *)
  let inhabited r =
    let ms = E.blocks [ r ] in
    let seen = Hashtbl.create 64 in
    let push stack (_, _, e) =
      if Hashtbl.mem seen (E.hash e) || known_empty e then stack
      else begin
        Hashtbl.add seen (E.hash e) ();
        e :: stack
      end
    in
    let rec go = function
      | [] -> false
      | d :: stack ->
          E.nullable d
          || (not (DelaySet.is_empty (E.delays d)))
          || go (List.fold_left push stack (edges ms d))
    in
    Hashtbl.add seen (E.hash r) ();
    let found = (not (equal_form r E.empty)) && go [ r ] in
    record r seen found;
    found

  let is_empty r =
    match Hashtbl.find_opt emptiness (E.hash r) with
    | Some e -> e
    | None -> not (inhabited r)

  let subset r s =
    equal_form r s || E.is_top s || is_empty (E.inter [ r; E.compl s ])

  let fewest_operations r =
    let ms = E.blocks [ r ] in
    let parent = Hashtbl.create 64 and queue = Queue.create () in
    let rec path e acc =
      match Hashtbl.find parent (E.hash e) with
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
                if not (Hashtbl.mem parent (E.hash e') || known_empty e') then begin
                  Hashtbl.add parent (E.hash e') (Some (n, m, e));
                  Queue.push e' queue
                end)
              (edges ms e);
            go ()
          end
    in
    Hashtbl.add parent (E.hash r) None;
    Queue.push r queue;
    go ()

  (* The pairs of expressions compared, by their numbers, the lesser first. *)
  let equalities : bool Pairs.t = Pairs.create 1024

  let bisimilar r s =
    let ms = E.blocks [ r; s ] in
    let parent = Hashtbl.create 64 in
    let rec find x =
      match Hashtbl.find_opt parent x with
      | Some p ->
          let root = find p in
          Hashtbl.replace parent x root;
          root
      | None -> x
    in
    let queue = Queue.create () in
    Queue.push (r, s) queue;
    let rec go () =
      match Queue.take_opt queue with
      | None -> true
      | Some (r, s) ->
          let x = find (E.hash r) and y = find (E.hash s) in
          if x = y then go ()
          else if
            E.nullable r <> E.nullable s
            || not (DelaySet.equal (E.delays r) (E.delays s))
          then false
          else begin
            Hashtbl.replace parent x y;
            List.iter
              (fun m ->
                List.iter
                  (fun pair -> Queue.push pair queue)
                  (GapMap.targets ~absent:E.empty (E.gap m r) (E.gap m s)))
              ms;
            go ()
          end
    in
    go ()

  let equal r s =
    equal_form r s
    || E.nullable r = E.nullable s
       &&
       let i = E.hash r and j = E.hash s in
       let key = if i < j then (i, j) else (j, i) in
       match Pairs.find_opt equalities key with
       | Some e -> e
       | None ->
           let e = bisimilar r s in
           Pairs.add equalities key e;
           e
end
