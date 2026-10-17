let combine_ids id tag rs =
  List.fold_left (fun h r -> Hashing.combine h (id r)) tag rs

module HashCons
    (View : Hashtbl.HashedType)
    (Form : sig
      type t

      val build : int -> View.t -> t
    end) =
struct
  module Forms = Hashtbl.Make (View)

  let forms = Forms.create 4096

  (* A view is built into a form on its first request, numbered by the number of
     forms built before it. *)
  let make view =
    match Forms.find_opt forms view with
    | Some r -> r
    | None ->
        let r = Form.build (Forms.length forms) view in
        Forms.add forms view r;
        r
end

module type FORM = sig
  type t

  val id : t -> int
  val nullable : t -> bool
  val eps : t
  val compl_operand : t -> t option
  val star_operand : t -> t option
end

module Boolean (E : FORM) = struct
  let equal_form r s = Int.equal (E.id r) (E.id s)
  let mem_form r rs = List.exists (equal_form r) rs

  let flatten split rs =
    List.concat_map (fun r -> Option.value (split r) ~default:[ r ]) rs

  let merge part combine build rs =
    let parts, others =
      List.partition_map
        (fun r -> match part r with Some p -> Left p | None -> Right r)
        rs
    in
    match parts with
    | [] -> others
    | p :: ps -> build (List.fold_left combine p ps) :: others

  let complementary split rs =
    let among s =
      match split s with
      | Some ss -> List.for_all (fun s' -> mem_form s' rs) ss
      | None -> mem_form s rs
    in
    List.exists
      (fun r ->
        match E.compl_operand r with Some s -> among s | None -> false)
      rs

  (* The operands of repetitions are collected by their numbers in one pass,
     so that the filter is linear in the number of operands. *)
  let unsubsumed rs =
    let stars = Hashtbl.create 16 in
    List.iter
      (fun s ->
        Option.iter
          (fun s' -> Hashtbl.replace stars (E.id s') ())
          (E.star_operand s))
      rs;
    let nullable_other =
      List.exists
        (fun s ->
          Option.is_none (E.star_operand s)
          && E.nullable s
          && not (equal_form s E.eps))
        rs
    in
    List.filter
      (fun r ->
        not
          (Hashtbl.mem stars (E.id r) || (nullable_other && equal_form r E.eps)))
      rs

  (* [sweep cs] is the counts [cs] swept in increasing order of their least
     numbers, each merged into the last interval it overlaps or touches. *)
  let sweep cs =
    List.fold_left
      (fun acc c ->
        match acc with
        | c' :: rest -> (
            match Count.union c' c with Some u -> u :: rest | None -> c :: acc)
        | [] -> [ c ])
      []
      (List.sort Count.compare cs)

  let repetitions repetition repeat rs =
    if not (List.exists (fun r -> Option.is_some (repetition r)) rs) then rs
    else
      let power r = Option.value (repetition r) ~default:(r, Count.point 1) in
      let bases = Hashtbl.create 8 in
      List.iter
        (fun r ->
          let x, c = power r in
          let counts =
            match Hashtbl.find_opt bases (E.id x) with
            | Some (_, cs) -> cs
            | None -> []
          in
          Hashtbl.replace bases (E.id x) (x, c :: counts))
        rs;
      if Hashtbl.length bases = List.length rs then rs
      else
        Hashtbl.fold
          (fun _ (x, cs) acc -> List.map (repeat x) (sweep cs) @ acc)
          bases []

  (* The operands are read as sequences of factors. A group is the factors
     of the operands at one position with equal preceding factors, base and
     remainder; a group whose counts sweep into fewer intervals is replaced by
     its swept operands, groups taken in order of their first operand, each
     operand merged at most once a pass, and the passes repeated until no
     group merges. *)
  let repetitions_in_context chain repetition repeat concat rs =
    let power r = Option.value (repetition r) ~default:(r, Count.point 1) in
    (* The factors of a concatenation, each with the factors before it in
       reverse order and the concatenation after it, if any. *)
    let positions r =
      let rec go prefix r acc =
        match chain r with
        | Some (h, t) -> go (h :: prefix) t ((prefix, h, Some t) :: acc)
        | None -> (prefix, r, None) :: acc
      in
      match chain r with Some _ -> go [] r [] | None -> []
    in
    let bases = Hashtbl.create 8 in
    let operands = List.map (fun r -> (r, positions r)) rs in
    List.iter
      (fun (_, ps) ->
        List.iter
          (fun (_, f, _) ->
            Option.iter
              (fun (x, _) -> Hashtbl.replace bases (E.id x) ())
              (repetition f))
          ps)
      operands;
    if Hashtbl.length bases = 0 then rs
    else
      let rebuild prefix x tail c =
        let r = repeat x c in
        List.fold_left
          (fun acc f -> concat f acc)
          (match tail with None -> r | Some t -> concat r t)
          prefix
      in
      let rec pass operands =
        let operands = Array.of_list operands in
        let groups = Hashtbl.create 16 and order = ref [] in
        Array.iteri
          (fun i (_, ps) ->
            List.iter
              (fun (prefix, f, tail) ->
                let x, c = power f in
                if Hashtbl.mem bases (E.id x) then begin
                  let key =
                    ( List.map E.id prefix,
                      E.id x,
                      match tail with Some t -> E.id t | None -> -1 )
                  in
                  match Hashtbl.find_opt groups key with
                  | Some members ->
                      Hashtbl.replace groups key ((i, c) :: members)
                  | None ->
                      Hashtbl.add groups key [ (i, c) ];
                      order := (key, (prefix, x, tail)) :: !order
                end)
              ps)
          operands;
        let merged = Array.make (Array.length operands) false in
        let built =
          List.concat_map
            (fun (key, (prefix, x, tail)) ->
              let members =
                List.filter
                  (fun (i, _) -> not merged.(i))
                  (Hashtbl.find groups key)
              in
              let swept = sweep (List.map snd members) in
              if List.compare_lengths swept members >= 0 then []
              else begin
                List.iter (fun (i, _) -> merged.(i) <- true) members;
                List.map (rebuild prefix x tail) swept
              end)
            (List.rev !order)
        in
        match built with
        | [] -> Array.to_list (Array.map fst operands)
        | built ->
            pass
              (List.map (fun r -> (r, positions r)) built
              @ List.filteri
                  (fun i _ -> not merged.(i))
                  (Array.to_list operands))
      in
      pass operands

  let collect children leaves roots =
    let seen = Hashtbl.create 64 in
    let rec visit acc r =
      if Hashtbl.mem seen (E.id r) then acc
      else begin
        Hashtbl.add seen (E.id r) ();
        List.fold_left visit (leaves r @ acc) (children r)
      end
    in
    List.fold_left visit [] roots
end

type 't node =
  | Atom of 't
  | Empty
  | Eps
  | Concat of 't * 't
  | Union of 't list
  | Inter of 't list
  | Compl of 't
  | Star of 't
  | Repeat of 't * Count.t

module type STRUCTURE = sig
  type t

  val id : t -> int
  val node : t -> t node
end

module Delays (E : sig
  include STRUCTURE

  val atom_delays : t -> DelaySet.t
  val complement : DelaySet.t -> DelaySet.t
end) =
struct
  (* The sets of delays of the expressions computed, by their numbers. *)
  let delay_sets : DelaySet.t Memo.Ints.t = Memo.Ints.create 1024

  let rec delays r =
    Memo.Ints.find_or_add delay_sets (E.id r) (fun () -> delays_node r)

  and delays_node r =
    let fold op rs =
      match List.map delays rs with
      | n :: ns -> List.fold_left op n ns
      | [] -> DelaySet.empty
    in
    match E.node r with
    | Empty -> DelaySet.empty
    | Eps -> DelaySet.zero
    | Atom a -> E.atom_delays a
    | Concat (r1, r2) -> DelaySet.sum (delays r1) (delays r2)
    | Union rs -> fold DelaySet.union rs
    | Inter rs -> (
        (* [N(r & ~s) = N(r) ∖ N(s)], a difference from a bounded set reading
           [N(s)] only up to its supremum where that set is bounded. *)
        let complemented, others =
          List.partition_map
            (fun r -> match E.node r with Compl s -> Left s | _ -> Right r)
            rs
        in
        match others with
        | [] -> E.complement (fold DelaySet.union complemented)
        | others ->
            List.fold_left
              (fun n s -> DelaySet.diff n (delays s))
              (fold DelaySet.inter others)
              complemented)
    | Compl r -> E.complement (delays r)
    | Star r -> DelaySet.star (delays r)
    | Repeat (r, c) -> DelaySet.repeat (delays r) c
end

module Gaps (E : sig
  include STRUCTURE

  val universe : DelaySet.t
  val empty : t
  val top : t
  val union : t list -> t
  val inter : t list -> t
  val compl : t -> t
  val compare_form : t -> t -> int

  type block

  val key : block -> int
  val meets : block -> t -> bool
  val eps : t
  val concat : t -> t -> t
  val repeat : t -> Count.t -> t
  val delays : t -> DelaySet.t
end) =
struct
  (* The unions and intersections of two expressions, memoised by their
     numbers, in increasing order: both operations are commutative on normal
     forms. *)
  let binary operation =
    let table : E.t Memo.Pairs.t = Memo.Pairs.create 1024 in
    fun e e' ->
      let i = E.id e and i' = E.id e' in
      Memo.Pairs.find_or_add table
        (min i i', max i i')
        (fun () -> operation [ e; e' ])

  include GapMap.Make (struct
    type t = E.t

    let universe = E.universe
    let empty = E.empty
    let top = E.top
    let union = binary E.union
    let inter = binary E.inter
    let compl = E.compl
    let compare_form = E.compare_form
  end)

  (* The gap derivatives computed, by the key of the block and the number of
     the expression. *)
  let gap_derivatives : E.t GapMap.t Memo.Pairs.t = Memo.Pairs.create 1024

  let rec gap m r =
    Memo.Pairs.find_or_add gap_derivatives
      (E.key m, E.id r)
      (fun () -> gap_node m r)

  and gap_node m r =
    match E.node r with
    | Empty | Eps -> []
    | Atom a -> if E.meets m a then [ (DelaySet.zero, E.eps) ] else []
    | Concat (r1, r2) ->
        join
          (normalise (List.map (fun (n, e) -> (n, E.concat e r2)) (gap m r1)))
          (shift (E.delays r1) (gap m r2))
    | Union rs -> List.fold_left (fun f r -> join f (gap m r)) [] rs
    | Inter rs -> List.fold_left (fun f r -> meet f (gap m r)) full rs
    | Compl r -> complement (gap m r)
    | Star r' ->
        shift
          (DelaySet.star (E.delays r'))
          (List.map (fun (n, e) -> (n, E.concat e r)) (gap m r'))
    | Repeat (r', c) ->
        (* [r'^c] is [r'; r'^(c ⊖ 1)] but for the empty word: the derivative
           of a concatenation. Where the delays of [r'] are at most [{0}], the
           derivative of [r'^(c ⊖ 1)] is contained in the first part, [r'] being
           nullable and its count a single number if they are [{0}]. *)
        let rest =
          match Count.shift c 1 with
          | Some c' -> E.repeat r' c'
          | None -> E.empty
        in
        let first =
          normalise (List.map (fun (n, e) -> (n, E.concat e rest)) (gap m r'))
        in
        let n = E.delays r' in
        if DelaySet.subset n DelaySet.zero then first
        else join first (shift n (gap m rest))
end
