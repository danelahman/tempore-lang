module type GRAPH = sig
  type t
  type block

  val id : t -> int
  val empty : t
  val is_top : t -> bool
  val inter : t list -> t
  val compl : t -> t
  val nullable : t -> bool
  val final : t -> bool
  val agree : t -> t -> bool
  val blocks : t list -> block list
  val successors : block list -> t -> t list
  val pairs : block list -> t -> t -> (t * t) list
end

module Pairs = NormalForms.Pairs

module Make (G : GRAPH) = struct
  let equal_form r s = Int.equal (G.id r) (G.id s)

  (* The emptiness of the expressions explored, by their numbers. *)
  let emptiness : (int, bool) Hashtbl.t = Hashtbl.create 4096
  let known_empty r = Hashtbl.find_opt emptiness (G.id r) = Some true

  let record r seen found =
    if found then Hashtbl.replace emptiness (G.id r) false
    else Hashtbl.iter (fun id _ -> Hashtbl.replace emptiness id true) seen

  (* Depth-first exploration, the first successor of an expression explored
     first. *)
  let inhabited r =
    let ms = G.blocks [ r ] in
    let seen = Hashtbl.create 64 in
    let fresh next d =
      if Hashtbl.mem seen (G.id d) || known_empty d || equal_form d G.empty then
        next
      else begin
        Hashtbl.add seen (G.id d) ();
        d :: next
      end
    in
    let rec go = function
      | [] -> false
      | d :: stack ->
          G.final d
          || go
               (List.rev_append
                  (List.fold_left fresh [] (G.successors ms d))
                  stack)
    in
    Hashtbl.add seen (G.id r) ();
    let found = (not (equal_form r G.empty)) && go [ r ] in
    record r seen found;
    found

  let is_empty r =
    match Hashtbl.find_opt emptiness (G.id r) with
    | Some e -> e
    | None -> not (inhabited r)

  let subset r s =
    equal_form r s || G.is_top s || is_empty (G.inter [ r; G.compl s ])

  (* The pairs of expressions compared, by their numbers, the lesser first. *)
  let equalities : bool Pairs.t = Pairs.create 1024

  let bisimilar r s =
    let ms = G.blocks [ r; s ] in
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
          let x = find (G.id r) and y = find (G.id s) in
          if x = y then go ()
          else if not (G.agree r s) then false
          else begin
            Hashtbl.replace parent x y;
            List.iter (fun pair -> Queue.push pair queue) (G.pairs ms r s);
            go ()
          end
    in
    go ()

  let equal r s =
    equal_form r s
    || G.nullable r = G.nullable s
       &&
       let i = G.id r and j = G.id s in
       let key = if i < j then (i, j) else (j, i) in
       match Pairs.find_opt equalities key with
       | Some e -> e
       | None ->
           let e = bisimilar r s in
           Pairs.add equalities key e;
           e
end
