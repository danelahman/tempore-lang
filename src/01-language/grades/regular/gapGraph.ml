module type EXPRESSION = sig
  type t

  val hash : t -> int
  val delays : t -> DelaySet.t
  val gap_derivative : string -> t -> t GapMap.t
end

module Make (R : EXPRESSION) = struct
  (** [transitions names r] is the gap derivatives of [r] by each of [names], in
      their order: triples of a set of delays, a name and an expression. *)
  let transitions names r =
    List.concat_map
      (fun name ->
        List.map (fun (s, e) -> (s, name, e)) (R.gap_derivative name r))
      names

  (* The expressions are numbered in the order of their discovery, breadth-first
     from the start, and explored in that order, so that the rows of the gap
     states are those of their numbers. *)
  let graph names rho =
    let index = Hashtbl.create 64 and queue = Queue.create () in
    let number r =
      match Hashtbl.find_opt index (R.hash r) with
      | Some g -> g
      | None ->
          let g = Hashtbl.length index in
          Hashtbl.add index (R.hash r) g;
          Queue.push r queue;
          g
    in
    (* The rows of the gap states explored and those of the operation states,
       both reversed, and the number of the operation states. *)
    let rec explore gaps ops n =
      match Queue.take_opt queue with
      | None -> (gaps, ops)
      | Some r ->
          let row, ops, n =
            List.fold_left
              (fun (row, ops, n) (s, name, e) ->
                ((s, n) :: row, ([ (name, number e) ], false) :: ops, n + 1))
              ([], ops, n) (transitions names r)
          in
          let finals = R.delays r in
          let row, ops, n =
            if DelaySet.is_empty finals then (row, ops, n)
            else ((finals, n) :: row, ([], true) :: ops, n + 1)
          in
          explore (List.rev row :: gaps) ops n
    in
    ignore (number rho);
    let gaps, ops = explore [] [] 0 in
    DelayTimedClosure.graph
      ~gaps:(Array.of_list (List.rev gaps))
      ~ops:(Array.of_list (List.rev_map fst ops))
      ~final:(Array.of_list (List.rev_map snd ops))
end

include Make (struct
  type t = SymbolicRegex.t

  let hash = SymbolicRegex.hash
  let delays = SymbolicRegex.delays

  let gap_derivative name =
    SymbolicRegex.gap_derivative (SymbolicRegex.Letters.name name)
end)
