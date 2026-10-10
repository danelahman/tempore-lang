module Pairs = Hashtbl.Make (struct
  type t = int * int

  let equal (i, j) (i', j') = Int.equal i i' && Int.equal j j'
  let hash (i, j) = Grade.combine i j
end)

let combine_ids id tag rs =
  List.fold_left (fun h r -> (h * 65599) + id r) tag rs

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

  let subsumed rs r =
    let contains s =
      match E.star_operand s with
      | Some s' -> equal_form r s'
      | None -> E.nullable s && equal_form r E.eps && not (equal_form s E.eps)
    in
    List.exists contains rs

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
  let delay_sets : (int, DelaySet.t) Hashtbl.t = Hashtbl.create 1024

  let rec delays r =
    match Hashtbl.find_opt delay_sets (E.id r) with
    | Some n -> n
    | None ->
        let n = delays_node r in
        Hashtbl.add delay_sets (E.id r) n;
        n

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
end

module Gaps (E : sig
  include STRUCTURE
  include GapMap.EXPRESSION with type t := t

  type block

  val key : block -> int
  val meets : block -> t -> bool
  val eps : t
  val concat : t -> t -> t
  val delays : t -> DelaySet.t
end) =
struct
  include GapMap.Make (struct
    include E

    type nonrec t = t
  end)

  (* The gap derivatives computed, by the key of the block and the number of
     the expression. *)
  let gap_derivatives : E.t GapMap.t Pairs.t = Pairs.create 1024

  let rec gap m r =
    let key = (E.key m, E.id r) in
    match Pairs.find_opt gap_derivatives key with
    | Some f -> f
    | None ->
        let f = gap_node m r in
        Pairs.add gap_derivatives key f;
        f

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
end
