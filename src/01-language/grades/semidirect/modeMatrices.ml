module type ENTRY = sig
  type t

  val zero : t
  val one : t
  val is_zero : t -> bool
  val add : t -> t -> t
  val mul : t -> t -> t
  val leq : t -> t -> bool
  val equal : t -> t -> bool
  val compare : t -> t -> int
  val hash : t -> int
  val rename : (string -> string) -> t -> t
  val project : string list -> t -> t
end

let stuck = "Stuck"

(* The names standing for modes that no matrix at hand names; the modes of the
   literals are capitalised, so that these differ from them. *)
let other = "_x"
let another = "_y"
let yet_another = "_z"

module Make (E : ENTRY) = struct
  type t = {
    modes : string list;
    within : ((string * string) * E.t) list;
    leaving : (string * E.t) list;
    entering : (string * E.t) list;
    staying : E.t;
    moving : E.t;
    to_stuck : (string * E.t) list;
    other_to_stuck : E.t;
  }

  (* [renaming p q] renames [other] to [p] and [another] to [q]. *)
  let renaming p q r =
    if String.equal r other then p else if String.equal r another then q else r

  let entry m p q =
    let named p = List.mem p m.modes in
    let find key entries =
      Option.value (List.assoc_opt key entries) ~default:E.zero
    in
    let at p q = E.rename (renaming p q) in
    if String.equal p stuck then if String.equal q stuck then E.one else E.zero
    else if String.equal q stuck then
      if named p then find p m.to_stuck else at p q m.other_to_stuck
    else
      match (named p, named q) with
      | true, true -> find (p, q) m.within
      | true, false -> at q q (find p m.leaving)
      | false, true -> at p p (find q m.entering)
      | false, false ->
          if String.equal p q then at p p m.staying else at p q m.moving

  (* The pairs of modes covering every case of the matrices over [modes]: pairs
     of those modes or of one mode not named, one pair of two distinct modes not
     named, and each of these modes paired with [stuck]. *)
  let cases modes =
    let with_other = modes @ [ other ] in
    (other, another)
    :: List.concat_map
         (fun p -> (p, stuck) :: List.map (fun q -> (p, q)) with_other)
         with_other

  (* [restrict modes m] is [m] over the modes named [modes], a subset of those
     of [m], the entries naming exactly these and the representatives of their
     positions. *)
  let restrict modes m =
    let keep (p, q) = List.mem p modes && List.mem q modes in
    let named = List.filter (fun (p, _) -> List.mem p modes) in
    let generic = E.project (modes @ [ other ]) in
    let project = E.project modes in
    {
      modes;
      within =
        List.filter_map
          (fun (key, e) -> if keep key then Some (key, project e) else None)
          m.within;
      leaving = List.map (fun (p, e) -> (p, generic e)) (named m.leaving);
      entering = List.map (fun (q, e) -> (q, generic e)) (named m.entering);
      staying = generic m.staying;
      moving = E.project (modes @ [ other; another ]) m.moving;
      to_stuck = List.map (fun (p, e) -> (p, project e)) (named m.to_stuck);
      other_to_stuck = generic m.other_to_stuck;
    }

  (* A mode is dropped whose entries are those of the modes not named: the
     matrix is invariant under exchanging it with a mode not named. *)
  let trim m =
    let alike q =
      let swap r =
        if String.equal r q then yet_another
        else if String.equal r yet_another then q
        else r
      in
      List.for_all
        (fun (p, p') ->
          E.equal (entry m (swap p) (swap p')) (E.rename swap (entry m p p')))
        (cases m.modes)
    in
    restrict (List.filter (fun q -> not (alike q)) m.modes) m

  let make modes f =
    let modes = List.sort_uniq String.compare modes in
    let entries pairs =
      List.filter_map
        (fun (key, e) -> if E.is_zero e then None else Some (key, e))
        pairs
    in
    trim
      (restrict modes
         {
           modes;
           within =
             entries
               (List.concat_map
                  (fun p -> List.map (fun q -> ((p, q), f p q)) modes)
                  modes);
           leaving = entries (List.map (fun p -> (p, f p other)) modes);
           entering = entries (List.map (fun q -> (q, f other q)) modes);
           staying = f other other;
           moving = f other another;
           to_stuck = entries (List.map (fun p -> (p, f p stuck)) modes);
           other_to_stuck = f other stuck;
         })

  let modes_of m m' = List.sort_uniq String.compare (m.modes @ m'.modes)

  (* A trace from [p] to [r] passes through a mode named, [p], [r], [stuck] or
     another mode, the modes not named all alike. *)
  let mul m m' =
    let modes = modes_of m m' in
    make modes (fun p r ->
        let fresh =
          List.find
            (fun q -> not (String.equal q p || String.equal q r))
            [ other; another; yet_another ]
        in
        List.fold_left
          (fun e q -> E.add e (E.mul (entry m p q) (entry m' q r)))
          E.zero
          (fresh :: p :: r :: stuck :: modes))

  let join m m' =
    make (modes_of m m') (fun p q -> E.add (entry m p q) (entry m' p q))

  let leq m m' =
    List.for_all
      (fun (p, q) -> E.leq (entry m p q) (entry m' p q))
      (cases (modes_of m m'))

  let equal m m' = leq m m' && leq m' m

  let compare m m' =
    let entries compare_key =
      List.compare (fun (k, e) (k', e') ->
          match compare_key k k' with 0 -> E.compare e e' | k -> k)
    in
    let pair (p, q) (p', q') =
      match String.compare p p' with 0 -> String.compare q q' | k -> k
    in
    List.fold_left
      (fun acc c -> if Int.equal acc 0 then c else acc)
      0
      [
        List.compare String.compare m.modes m'.modes;
        entries pair m.within m'.within;
        entries String.compare m.leaving m'.leaving;
        entries String.compare m.entering m'.entering;
        E.compare m.staying m'.staying;
        E.compare m.moving m'.moving;
        entries String.compare m.to_stuck m'.to_stuck;
        E.compare m.other_to_stuck m'.other_to_stuck;
      ]

  let hash m =
    let entries hash_key =
      Hashing.list (fun (k, e) -> Hashing.combine (hash_key k) (E.hash e))
    in
    List.fold_left Hashing.combine
      (Hashing.list String.hash m.modes)
      [
        entries
          (fun (p, q) -> Hashing.combine (String.hash p) (String.hash q))
          m.within;
        entries String.hash m.leaving;
        entries String.hash m.entering;
        E.hash m.staying;
        E.hash m.moving;
        entries String.hash m.to_stuck;
        E.hash m.other_to_stuck;
      ]
end
