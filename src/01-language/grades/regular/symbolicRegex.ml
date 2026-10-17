module Letters = Letters

type letters = Sets | Atoms

module type S = sig
  type t

  type view =
    | Empty
    | Eps
    | Letters of Letters.t
    | Ticks of int
    | Concat of t * t
    | Union of t list
    | Inter of t list
    | Compl of t
    | Star of t
    | Repeat of t * Count.t

  val view : t -> view
  val equal_form : t -> t -> bool
  val compare_form : t -> t -> int
  val hash : t -> int
  val id : t -> int
  val empty : t
  val eps : t
  val top : t
  val letters : Letters.t -> t
  val ticks : int -> t
  val runs : int -> int -> t
  val concat : t -> t -> t
  val union : t list -> t
  val inter : t list -> t
  val compl : t -> t
  val star : t -> t
  val repeat : t -> Count.t -> t
  val names : t -> string list
  val nullable : t -> bool
  val minterms : t -> Letters.t list
  val derivative : Letters.t -> t -> t
  val lead : t -> int
  val leap : int -> t -> t
  val delays : t -> DelaySet.t

  type gaps = (DelaySet.t * t) list

  val gap_derivative : Letters.t -> t -> gaps
  val gaps : t -> (Letters.t * gaps) list

  module type ALPHABET = sig
    val blocks : t list -> Letters.t list
  end

  module Minterms : ALPHABET
  module Concrete : ALPHABET

  module type DECISIONS = sig
    val is_empty : t -> bool
    val shortest : t -> Letters.t list option
    val subset : t -> t -> bool
    val equal : t -> t -> bool
  end

  module Decide (_ : ALPHABET) : DECISIONS

  type gap_word = (int * Letters.t) list * int

  module type GAP_DECISIONS = sig
    val is_empty : t -> bool
    val shortest : t -> gap_word option
    val subset : t -> t -> bool
    val equal : t -> t -> bool
  end

  module GapDecide (_ : ALPHABET) : GAP_DECISIONS
end

module Make (L : sig
  val letters : letters
end) =
struct
  type t = { id : int; view : view; nullable : bool; lead : int }
  (* [id] numbers the normal forms in the order of their construction, and
     [lead] is the lead of the expression, {!unbounded} for the empty
     language. *)

  and view =
    | Empty
    | Eps
    | Letters of Letters.t
    | Ticks of int
    | Concat of t * t
    | Union of t list
    | Inter of t list
    | Compl of t
    | Star of t
    | Repeat of t * Count.t

  let view r = r.view
  let equal_form r s = r.id = s.id
  let compare_form r s = Int.compare r.id s.id
  let hash r = r.id
  let id r = r.id
  let by_id r s = Int.compare r.id s.id

  let nullable_view = function
    | Empty | Letters _ | Ticks _ -> false
    | Eps | Star _ -> true
    | Concat (r, s) -> r.nullable && s.nullable
    | Union rs -> List.exists (fun r -> r.nullable) rs
    | Inter rs -> List.for_all (fun r -> r.nullable) rs
    | Compl r -> not r.nullable
    | Repeat (r, c) -> r.nullable || Count.mem 0 c

  (** [run_view view] is [Some n] if [view] is the word [tickⁿ], [n ≥ 1]: the
      letter set [{tick}] or a run of ticks. *)
  let run_view = function
    | Letters p when Letters.equal p Letters.tick -> Some 1
    | Ticks n -> Some n
    | _ -> None

  let run r = run_view r.view

  (** The lead of the empty language, of which every word begins with any number
      of ticks. *)
  let unbounded = Int.max_int

  (** [lead_view view] is the lead of [view], read off its form: a number [k]
      such that every word of [view] begins with [tickᵏ]. *)
  let lead_view view =
    match (view, run_view view) with
    | _, Some n -> n
    | Empty, _ -> unbounded
    | (Eps | Letters _ | Ticks _ | Star _ | Compl _), None -> 0
    | Concat (r, s), None -> (
        match run r with
        | Some n when s.lead < unbounded ->
            Delay.checked_add ~quantity:"duration" n s.lead
        | Some _ -> unbounded
        | None -> r.lead)
    | Union rs, None -> List.fold_left (fun k r -> min k r.lead) unbounded rs
    | Inter rs, None -> List.fold_left (fun k r -> max k r.lead) 0 rs
    | Repeat (r, c), None -> if c.least >= 1 then r.lead else 0

  (** The table of normal forms, each view built of normal forms identified by
      their numbers. *)
  module Forms =
    NormalForms.HashCons
      (struct
        type t = view

        let equal v w =
          match (v, w) with
          | Empty, Empty | Eps, Eps -> true
          | Letters p, Letters q -> Letters.equal p q
          | Ticks n, Ticks n' -> Int.equal n n'
          | Concat (r, s), Concat (r', s') -> equal_form r r' && equal_form s s'
          | Union rs, Union rs' | Inter rs, Inter rs' ->
              List.equal equal_form rs rs'
          | Compl r, Compl r' | Star r, Star r' -> equal_form r r'
          | Repeat (r, c), Repeat (r', c') ->
              equal_form r r' && Count.equal c c'
          | _ -> false

        let combine = NormalForms.combine_ids id

        let hash = function
          | Empty -> 0
          | Eps -> 1
          | Letters p -> Letters.hash p
          | Ticks n -> Hashing.combine 7 n
          | Concat (r, s) -> combine 2 [ r; s ]
          | Union rs -> combine 3 rs
          | Inter rs -> combine 4 rs
          | Compl r -> combine 5 [ r ]
          | Star r -> combine 6 [ r ]
          | Repeat (r, c) -> Hashing.combine (combine 8 [ r ]) (Count.hash c)
      end)
      (struct
        type nonrec t = t

        let build id view =
          { id; view; nullable = nullable_view view; lead = lead_view view }
      end)

  (** [make view] is the normal form of [view]: the expressions are hash-consed
      ({!NormalForms.HashCons}). *)
  let make = Forms.make

  let nullable r = r.nullable
  let lead r = r.lead

  (** {1 Constructions}

      The smart constructors keep the normal form, which includes the similarity
      rules of Brzozowski (JACM 1964) extended to intersection and complement,
      as in Owens, Reppy and Turon (JFP 2009), so that every expression has
      finitely many derivatives up to its normal form. Symbolic derivatives over
      an effective Boolean algebra are likewise finite up to similarity
      (Zhuchko, Maarand, Veanes and Ebner, ITP 2025). *)

  let empty = make Empty
  let eps = make Eps

  include NormalForms.Boolean (struct
    type nonrec t = t

    let id = id
    let nullable r = r.nullable
    let eps = eps
    let compl_operand r = match r.view with Compl s -> Some s | _ -> None
    let star_operand r = match r.view with Star s -> Some s | _ -> None
  end)

  let letters p = if Letters.is_empty p then empty else make (Letters p)

  let ticks n =
    match n with 0 -> eps | 1 -> letters Letters.tick | n -> make (Ticks n)

  let top =
    match L.letters with
    | Sets -> make (Star (letters Letters.any))
    | Atoms -> make (Compl empty)

  (** [split_run r] is [(n, s)] such that [r] is [tickⁿ; s], [n] the length of
      the run of ticks [r] begins with, [0] if none. *)
  let split_run r =
    match (run r, r.view) with
    | Some n, _ -> (n, eps)
    | None, Concat (r1, r2) -> (
        match run r1 with Some n -> (n, r2) | None -> (0, r))
    | None, _ -> (0, r)

  let letter_set r = match r.view with Letters p -> Some p | _ -> None

  (** [one_letter_part r] is the set of the letters of the one-letter words of
      [r], when [r] is a letter set, the complement of one or the repetition of
      one. *)
  let one_letter_part r =
    match r.view with
    | Letters p -> Some p
    | Compl { view = Letters p; _ } -> Some (Letters.compl p)
    | Star { view = Letters p; _ } -> Some p
    | _ -> None

  let is_top r = equal_form r top
  let is_empty_form r = equal_form r empty

  (** [merge_union rs] merges the letter sets among the operands [rs] of a union
      into their union; single letters are not merged. *)
  let merge_union rs =
    match L.letters with
    | Sets -> merge letter_set Letters.union letters rs
    | Atoms -> rs

  (** [all_letters r] is whether [r] is a letter set, or a union of letters,
      that holds every letter: the one-letter words [Σ], whose repetition is
      [Σ*]. *)
  let all_letters r =
    let sets =
      match r.view with
      | Letters p -> Some [ p ]
      | Union rs ->
          List.fold_left
            (fun acc r ->
              Option.bind acc (fun ps ->
                  Option.map (fun p -> p :: ps) (letter_set r)))
            (Some []) rs
      | _ -> None
    in
    match sets with
    | Some (p :: ps) ->
        Letters.equal (List.fold_left Letters.union p ps) Letters.any
    | Some [] | None -> false

  (** [repetition r] is [Some (x, c)] if [r] is the repetition [x^c]. *)
  let repetition r =
    match r.view with Repeat (x, c) -> Some (x, c) | _ -> None

  (** [chain r] is [Some (h, t)] if [r] is the concatenation [h; t]. *)
  let chain r = match r.view with Concat (h, t) -> Some (h, t) | _ -> None

  (** [power r] is [(x, c)] if [r] is the repetition [x^c], and [(r, 1)]
      otherwise. *)
  let power r = Option.value (repetition r) ~default:(r, Count.point 1)

  (* The repetitions of a base in a union are merged where their counts
     overlap or touch: [x^c | x^c' = x^(c ∪ c')], also as factors of
     concatenations equal but for their counts. *)
  let rec union rs =
    let split r =
      match r.view with Union rs -> Some rs | Empty -> Some [] | _ -> None
    in
    let rs = flatten split rs in
    if List.exists is_top rs then top
    else
      let rs =
        List.sort_uniq by_id (repetitions repetition repeat (merge_union rs))
      in
      let rs =
        List.sort_uniq by_id
          (repetitions_in_context chain repetition repeat concat rs)
      in
      let rs = unsubsumed rs in
      if complementary split rs then top
      else match rs with [] -> empty | [ r ] -> r | rs -> make (Union rs)

  (* [(r^c)* = r*] where [1 ∈ c]. *)
  and star r =
    match r.view with
    | Empty | Eps -> eps
    | Star _ -> r
    | Repeat (s, c) when Count.mem 1 c -> star s
    | Union rs when mem_form eps rs ->
        star (union (List.filter (fun r -> not (equal_form r eps)) rs))
    | _ when all_letters r -> top
    | _ -> make (Star r)

  (* The laws of bounded repetition over intervals of counts: [r^0 = 0],
     [r^1 = r], [r^[0, ∞) = r*], [0^c] and [∅^c] are the empty word or
     language, [(s* )^c = s*] for [c ≠ {0}], [(s^c)^c' = s^(c ⊛ c')] where
     [c ⊛ c'] is an interval ({!Count.nest}), a nullable [r] has [r^c = r^n]
     for [c = [m, n]] and [r^c = r*] for [c = [m, ∞)], every word of [r^k]
     being one of [r^(k + 1)], and a run of [k] ticks repeated [n] times is a
     run of [k·n] ticks. *)
  and repeat r (c : Count.t) =
    if Count.is_point 0 c then eps
    else if Count.is_point 1 c then r
    else
      match (r.view, c.most) with
      | Empty, _ -> if Count.mem 0 c then eps else empty
      | (Eps | Star _), _ -> r
      | _, None when r.nullable || c.least = 0 -> star r
      | _, Some n when r.nullable && c.least < n -> repeat r (Count.point n)
      | Repeat (s, c0), _ -> (
          match Count.nest c0 c with
          | Some d -> repeat s d
          | None -> make (Repeat (r, c)))
      | _, Some n when n = c.least -> (
          match run r with
          | Some k ->
              ticks
                (Delay.checked_to_int ~quantity:"duration"
                   (Z.mul (Z.of_int k) (Z.of_int n)))
          | None -> make (Repeat (r, c)))
      | _ -> make (Repeat (r, c))

  (* A run of ticks followed by a run of ticks, alone or leading a
     concatenation, is joined with it: [tickᵐ; tickⁿ = tickᵐ⁺ⁿ]; and a
     repetition followed by one of the same base, alone or leading a
     concatenation, is joined with it: [x^c; x^c' = x^(c + c')], a factor [x]
     counting as [x^1]. *)
  and concat r s =
    match (r.view, s.view) with
    | Empty, _ | _, Empty -> empty
    | Eps, _ -> s
    | _, Eps -> r
    | Concat (r1, r2), _ -> concat r1 (concat r2 s)
    | Star _, Star _ when equal_form r s -> r
    | Star _, Concat (s1, _) when equal_form r s1 -> s
    | _ -> (
        match (run r, split_run s) with
        | Some m, (n, s') when n > 0 ->
            concat (ticks (Delay.checked_add ~quantity:"duration" m n)) s'
        | _ -> (
            let x, c = power r in
            let head, rest =
              match s.view with
              | Concat (s1, s2) -> (s1, Some s2)
              | _ -> (s, None)
            in
            let y, c' = power head in
            if not (equal_form x y) then make (Concat (r, s))
            else
              let joined = repeat x (Count.add c c') in
              match rest with None -> joined | Some rest -> concat joined rest))

  let inter rs =
    let split r =
      match r.view with
      | Inter rs -> Some rs
      | _ when is_top r -> Some []
      | _ -> None
    in
    let rs = flatten split rs in
    (* The one-letter words of an operand are all it contributes to an
       intersection with a letter set. *)
    let rs =
      if List.exists (fun r -> Option.is_some (letter_set r)) rs then
        merge one_letter_part Letters.inter letters rs
      else rs
    in
    if List.exists is_empty_form rs then empty
    else if mem_form eps rs then
      if List.for_all (fun r -> r.nullable) rs then eps else empty
    else
      let rs = List.sort_uniq by_id rs in
      if complementary split rs then empty
      else match rs with [] -> top | [ r ] -> r | rs -> make (Inter rs)

  let compl r =
    match r.view with
    | Compl s -> s
    | Empty -> top
    | _ when is_top r -> empty
    | _ -> make (Compl r)

  let runs lo hi =
    union (List.init (max 1 (hi - lo + 1)) (fun k -> ticks (lo + k)))

  (** {1 Traversals} *)

  let children r =
    match r.view with
    | Empty | Eps | Letters _ | Ticks _ -> []
    | Concat (r, s) -> [ r; s ]
    | Union rs | Inter rs -> rs
    | Compl r | Star r | Repeat (r, _) -> [ r ]

  (** [letter_sets roots] is the list of the letter sets occurring in [roots],
      each once, a run of ticks being made of the letter set [{tick}]. *)
  let letter_sets roots =
    List.sort_uniq Letters.compare
      (collect children
         (fun r ->
           match r.view with
           | Letters p -> [ p ]
           | Ticks _ -> [ Letters.tick ]
           | _ -> [])
         roots)

  (** [mentioned roots] is the list of the names the letter sets of [roots]
      mention, in increasing order. *)
  let mentioned roots =
    List.sort_uniq String.compare
      (List.concat_map Letters.mentioned (letter_sets roots))

  let names =
    let table = Memo.Ints.create 1024 in
    fun r -> Memo.Ints.find_or_add table r.id (fun () -> mentioned [ r ])

  (** {1 Derivatives} *)

  let minterms r = Letters.partition (letter_sets [ r ])

  type minterm = { set : Letters.t; key : int }
  (** A block of a partition, with the number of its normal form as a key. *)

  let minterm set = { set; key = (letters set).id }

  (* The derivatives computed, by the key of the block and the number of the
     expression. *)
  let derivatives : t Memo.Pairs.t = Memo.Pairs.create 4096

  (* The derivative (Brzozowski, JACM 1964) of an extended regular expression
     by a block of letters rather than a letter, as in RE# (Varatalu, Veanes
     and Ernits, POPL 2025), memoised by block and expression. *)
  let rec derive m r =
    Memo.Pairs.find_or_add derivatives (m.key, r.id) (fun () -> derive_view m r)

  and derive_view m r =
    match r.view with
    | Empty | Eps -> empty
    | Letters p ->
        if Letters.is_empty (Letters.inter m.set p) then empty else eps
    | Ticks n -> if m.set.tick then ticks (n - 1) else empty
    | Concat (r1, r2) ->
        let d = concat (derive m r1) r2 in
        if r1.nullable then union [ d; derive m r2 ] else d
    | Union rs -> union (List.map (derive m) rs)
    | Inter rs -> inter (List.map (derive m) rs)
    | Compl r -> compl (derive m r)
    | Star r' -> concat (derive m r') r
    | Repeat (r', c) -> concat (derive m r') (repeat_rest r' c)

  (** [repeat_rest r c] is [r^(c ⊖ 1)], the repetition after the first iteration
      of [r^c], [c ≠ {0}]: every word of [r^c] beginning with a letter is the
      word of a first iteration beginning with it followed by one of
      [r^(c ⊖ 1)], the count of a nullable [r] being a single number. *)
  and repeat_rest r c =
    match Count.shift c 1 with Some c' -> repeat r c' | None -> empty

  let derivative set r = derive (minterm set) r

  (* The leaps computed, by the key of the block, the number of ticks and the
     number of the expression. *)
  let leaps : t Memo.Triples.t = Memo.Triples.create 1024

  module Positions = Map.Make (Int)
  (** Maps by positions in an orbit, or by numbers of expressions. *)

  type orbit = {
    anchors : t Positions.t;
    index : int Positions.t;
    last : int * t;
    cycle : (int * int) option;
  }
  (** The {e orbit} of an expression [r] under the derivative by a block [m],
      the sequence of its derivatives by [mᵏ], [k ≥ 0], explored up to [last]: a
      lasso, eventually periodic as the derivatives are finitely many up to
      their normal form. It is recorded at its {e anchors}, by position: [r] at
      [0], and after the anchor [e] at [p] the anchor at [p + j], its leap by
      [j], [j] the lead of [e] if positive and finite, and its derivative by [m]
      at [p + 1] otherwise. The anchors depend on [r] alone, so that the first
      anchor reached again closes the [cycle] [(μ, λ)]: the derivatives by [mᵏ]
      and by [mᵏ⁺λ] denote the same language for [k ≥ μ]. [index] maps the
      number of each anchor to its position. *)

  (* The orbits explored, by the key of the block and the number of the
     expression. *)
  let orbits : orbit Memo.Pairs.t = Memo.Pairs.create 64

  (* The derivative by [mᵏ], [m] the block of [tick], taken at once where the
     form of the expression tells it and off the orbit of the expression
     otherwise: the derivative by a word is that by its letters in turn
     (Brzozowski, JACM 1964), and a run of ticks is a word of a unary alphabet,
     whose derivatives are its shorter runs, as the derivatives of the counted
     repetitions [r{n,m}] are (Moseley et al., PLDI 2023), and whose orbit is
     eventually periodic. Memoised by block, number and expression. *)
  let rec leap_by m k r =
    if k = 0 then r
    else
      Memo.Triples.find_or_add leaps (m.key, k, r.id) (fun () ->
          leap_view m k r)

  and leap_view m k r =
    match r.view with
    | Empty | Eps -> empty
    | Letters _ -> if k = 1 then derive m r else empty
    | Ticks n -> if k <= n then ticks (n - k) else empty
    | Concat (r1, r2) -> (
        match split_run r with
        | n, s when n > 0 ->
            if k <= n then concat (ticks (n - k)) s else leap_by m (k - n) s
        | _ when k <= r1.lead -> concat (leap_by m k r1) r2
        | _ -> steps m k r)
    | Union rs -> union (List.map (leap_by m k) rs)
    | Inter rs -> inter (List.map (leap_by m k) rs)
    | Compl r -> compl (leap_by m k r)
    | Star s -> (
        match run s with
        | Some c when k mod c = 0 -> r
        | Some c -> concat (ticks (c - (k mod c))) r
        | None -> steps m k r)
    | Repeat (r', c) when c.least >= 1 && k <= r'.lead ->
        concat (leap_by m k r') (repeat_rest r' c)
    | Repeat _ -> steps m k r

  (** [steps m k r] is the derivative of [r] by [mᵏ] read off the orbit of [r]
      ({!orbit}), [k] reduced modulo its period once its cycle is found. [k]
      exceeds the lead of [r], so that every leap it takes is by fewer than [k]
      ticks. *)
  and steps m k r =
    let key = (m.key, r.id) in
    let o =
      match Memo.Pairs.find_opt orbits key with
      | Some o -> o
      | None ->
          {
            anchors = Positions.singleton 0 r;
            index = Positions.singleton r.id 0;
            last = (0, r);
            cycle = None;
          }
    in
    let o, d = along m k o in
    Memo.Pairs.replace orbits key o;
    d

  (** [along m k o] is the orbit [o] extended as far as the derivative by [mᵏ]
      needs, with that derivative: from the anchor at the greatest position [p]
      up to [k], its leap by [k - p]. *)
  and along m k o =
    let read k =
      match Positions.find_last_opt (fun p -> p <= k) o.anchors with
      | Some (p, e) -> leap_by m (k - p) e
      | None -> invalid_arg "SymbolicRegex.steps: an orbit without its start"
    in
    match o.cycle with
    | Some (mu, lambda) when k >= mu -> (o, read (mu + ((k - mu) mod lambda)))
    | Some _ -> (o, read k)
    | None ->
        let p, e = o.last in
        let j = if e.lead >= 1 && e.lead < unbounded then e.lead else 1 in
        if p + j > k then (o, read k)
        else
          let e' = if j = 1 then derive m e else leap_by m j e in
          let o =
            match Positions.find_opt e'.id o.index with
            | Some p' -> { o with cycle = Some (p', p + j - p') }
            | None ->
                {
                  anchors = Positions.add (p + j) e' o.anchors;
                  index = Positions.add e'.id (p + j) o.index;
                  last = (p + j, e');
                  cycle = None;
                }
          in
          along m k o

  let tick = minterm Letters.tick
  let leap k r = leap_by tick k r

  (** {1 Gap derivatives} *)

  (** [node r] is the top operation of [r], its atoms being its letter sets and
      runs of ticks. *)
  let node r : t NormalForms.node =
    match r.view with
    | Letters _ | Ticks _ -> Atom r
    | Empty -> Empty
    | Eps -> Eps
    | Concat (r, s) -> Concat (r, s)
    | Union rs -> Union rs
    | Inter rs -> Inter rs
    | Compl r -> Compl r
    | Star r -> Star r
    | Repeat (r, c) -> Repeat (r, c)

  (* The set of the [n] such that [tickⁿ] is in the expression, the complement
     taken in the natural numbers. *)
  include NormalForms.Delays (struct
    type nonrec t = t

    let id = id
    let node = node

    let atom_delays r =
      match r.view with
      | Letters p ->
          if p.tick then DelaySet.point (Rational.of_int 1) else DelaySet.empty
      | Ticks n -> DelaySet.point (Rational.of_int n)
      | _ -> DelaySet.empty

    let complement = DelaySet.diff DelaySet.naturals
  end)

  type gaps = (DelaySet.t * t) list

  (* The derivative by the words [tickⁿ a], [a] a name of the block, symbolic
     in [n] ({!NormalForms.Gaps}), the runs of ticks before the name read by
     [delays]. *)
  include NormalForms.Gaps (struct
    type nonrec t = t
    type block = minterm

    let id = id
    let node = node
    let universe = DelaySet.naturals
    let empty = empty
    let top = top
    let union = union
    let inter = inter
    let compl = compl
    let compare_form = compare_form
    let key m = m.key

    let meets m r =
      match r.view with
      | Letters p -> not (Letters.is_empty (Letters.inter m.set p))
      | _ -> false

    let eps = eps
    let concat = concat
    let repeat = repeat
    let delays = delays
  end)

  let gap_derivative set r =
    if set.Letters.tick then
      invalid_arg "SymbolicRegex.gap_derivative: a block containing tick"
    else gap (minterm set) r

  (** [name_blocks blocks] is the blocks of names of the partition [blocks]: its
      blocks without [tick], those left non-empty, listed by {!Letters.order}.
  *)
  let name_blocks blocks =
    List.filter_map
      (fun b ->
        let names = Letters.inter b (Letters.compl Letters.tick) in
        if Letters.is_empty names then None else Some names)
      blocks
    |> List.sort Letters.order

  let gaps r =
    List.map
      (fun names -> (names, gap (minterm names) r))
      (name_blocks (minterms r))

  (** {1 Alphabets} *)

  module type ALPHABET = sig
    val blocks : t list -> Letters.t list
  end

  module Minterms = struct
    let blocks roots = Letters.partition (letter_sets roots)
  end

  module Concrete = struct
    let blocks roots =
      let names = mentioned roots in
      (Letters.tick :: List.map Letters.name names) @ [ Letters.others names ]
  end

  (** {1 Decisions} *)

  module type DECISIONS = sig
    val is_empty : t -> bool
    val shortest : t -> Letters.t list option
    val subset : t -> t -> bool
    val equal : t -> t -> bool
  end

  module Decide (A : ALPHABET) = struct
    let blocks roots = List.map minterm (A.blocks roots)

    (** [tick_block ms] is the block of the partition [ms] that contains [tick].
    *)
    let tick_block ms =
      match List.find_opt (fun m -> m.set.Letters.tick) ms with
      | Some m -> m
      | None ->
          invalid_arg
            "SymbolicRegex.Decide.tick_block: a partition without a block \
             holding tick"

    (** [moves ms k d] is the derivatives of [d] a search explores, each with
        the blocks of [ms] of the word it is taken by, reversed: by the word
        [tickᵏ] alone if [k ≥ 1] is at most the lead of [d], the derivatives of
        [d] by the words of that length being otherwise empty, and by each block
        if [k] is [0]. *)
    let moves ms k d =
      if k = 0 then List.map (fun m -> (derive m d, [ m.set ])) ms
      else
        let tick = tick_block ms in
        [ (leap_by tick k d, List.init k (Fun.const tick.set)) ]

    (** [successors ms k d] is the derivatives of {!moves} [ms k d], without
        their words. *)
    let successors ms k d =
      if k = 0 then List.map (fun m -> derive m d) ms
      else [ leap_by (tick_block ms) k d ]

    (* The emptiness by depth-first exploration, an expression of lead
       [k ≥ 1] followed by its derivative by [tickᵏ] alone; the equivalence by
       Hopcroft and Karp's algorithm, a pair whose expressions both have a lead
       of at least [k ≥ 1] followed by their derivatives by [tickᵏ] alone: they
       denote the same language iff these do. *)
    include LanguageDecisions.Make (struct
      type nonrec t = t
      type block = minterm

      let id r = r.id
      let empty = empty
      let is_top = is_top
      let inter = inter
      let compl = compl
      let nullable = nullable
      let final = nullable
      let agree r s = Bool.equal r.nullable s.nullable
      let blocks = blocks

      let pairs ms r s =
        let k = min r.lead s.lead in
        List.combine (successors ms k r) (successors ms k s)

      let successors ms d = successors ms d.lead d
    end)

    (** The outcome of the exploration of one depth of a breadth-first search: a
        word found, or the expressions of the next depth. *)
    type 'a depth = Found of Letters.t list | Next of 'a list

    (** [search r] is a shortest word of [r], found by breadth-first exploration
        of its derivatives, and [None] if there is none; the derivatives known
        to be empty are not explored, and if no word is found every expression
        explored is recorded as empty. [r] is not nullable.

        The exploration proceeds by depths, the expressions of each depth in the
        order of their words, and its first nullable expression gives the word,
        the least of the shortest ones in the order of the blocks. When all the
        expressions of a depth have a lead of at least [k ≥ 1], it moves on to
        the depth [k] further, by the derivatives by [tickᵏ]: the depths in
        between have no nullable expression, and their words are those of the
        depth extended by [tick] alike. *)
    let search r =
      let ms = blocks [ r ] in
      let seen = Hashtbl.create 64 in
      let fresh d =
        not (Hashtbl.mem seen d.id || known_empty d || equal_form d empty)
      in
      let rec visit next = function
        | [] -> Next next
        | (d, rev_word) :: rest ->
            if not (fresh d) then visit next rest
            else begin
              Hashtbl.add seen d.id ();
              if d.nullable then Found (List.rev rev_word)
              else visit ((d, rev_word) :: next) rest
            end
      in
      let rec expand k next = function
        | [] -> Next (List.rev next)
        | (s, rev_word) :: level -> (
            let children =
              List.map (fun (d, w) -> (d, w @ rev_word)) (moves ms k s)
            in
            match visit next children with
            | Found word -> Found word
            | Next next -> expand k next level)
      in
      let rec go level =
        let k = List.fold_left (fun k (s, _) -> min k s.lead) unbounded level in
        if k = unbounded then None
        else
          match expand k [] level with
          | Found word -> Some word
          | Next level -> go level
      in
      Hashtbl.add seen r.id ();
      let found = go [ (r, []) ] in
      record r seen (Option.is_some found);
      found

    let shortest r =
      if r.nullable then Some [] else if known_empty r then None else search r
  end

  (** {1 Decisions in gap form} *)

  type gap_word = (int * Letters.t) list * int

  module type GAP_DECISIONS = sig
    val is_empty : t -> bool
    val shortest : t -> gap_word option
    val subset : t -> t -> bool
    val equal : t -> t -> bool
  end

  (** [least s] is the least element of the set of integers [s], [None] if [s]
      is empty. *)
  let least s =
    match DelaySet.inf s with
    | Some (DelaySet.Finite (q, _)) -> Rational.to_int q
    | Some DelaySet.Infinite | None -> None

  (** The frontiers of Dijkstra's algorithm: sets of pairs of a distance and the
      number of an expression. *)
  module Frontier = Set.Make (struct
    type t = int * int

    let compare (a, i) (b, j) =
      match Int.compare a b with 0 -> Int.compare i j | c -> c
  end)

  module GapDecide (A : ALPHABET) = struct
    let blocks roots = List.map minterm (name_blocks (A.blocks roots))

    include GapDecisions.Make (struct
      type nonrec t = t
      type block = minterm

      let id r = r.id
      let empty = empty
      let is_top = is_top
      let inter = inter
      let compl = compl
      let nullable = nullable
      let delays = delays
      let gap = gap
      let blocks = blocks
    end)

    (** [weight n] is the number of letters of the shortest words [tickᵈ a],
        [d ∈ n]. *)
    let weight n =
      match least n with
      | Some d -> d + 1
      | None ->
          invalid_arg "SymbolicRegex.GapDecide.weight: an empty set of delays"

    (** [forward ms r] explores the gap derivatives of [r] by Dijkstra's
        algorithm (Numer. Math. 1, 1959), a word [tickᵈ a] costing [d + 1]
        letters and a final delay [d] costing [d], until the least distance left
        is the length [L] of the shortest words of [r]. It returns [L]
        ([unbounded] if [r] is empty), the expressions reached within [L], by
        their numbers, and the gap derivatives of those within less than [L],
        which are all the expressions on the shortest words but their last. *)
    let forward ms r =
      let reached = Hashtbl.create 64 and expanded = Hashtbl.create 64 in
      let rec go frontier best =
        match Frontier.min_elt_opt frontier with
        | Some ((g, id) as next) when g < best ->
            let d =
              match Hashtbl.find_opt reached id with
              | Some (d, _) -> d
              | None ->
                  invalid_arg
                    "SymbolicRegex.GapDecide.forward: an expression of the \
                     frontier not reached"
            in
            let best =
              Option.fold ~none:best
                ~some:(fun k -> min best (g + k))
                (least (delays d))
            in
            let es = edges ms d in
            Hashtbl.replace expanded id es;
            let relax frontier (n, _, e) =
              let g' = g + weight n in
              match Hashtbl.find_opt reached e.id with
              | _ when g' > best || known_empty e -> frontier
              | Some (_, g0) when g0 <= g' -> frontier
              | found ->
                  Hashtbl.replace reached e.id (e, g');
                  Frontier.add (g', e.id)
                    (Option.fold ~none:frontier
                       ~some:(fun (_, g0) ->
                         Frontier.remove (g0, e.id) frontier)
                       found)
            in
            go (List.fold_left relax (Frontier.remove next frontier) es) best
        | _ -> best
      in
      Hashtbl.add reached r.id (r, 0);
      let best = go (Frontier.singleton (0, r.id)) unbounded in
      (best, reached, expanded)

    (** [backward reached expanded] is the length of the shortest words of each
        expression of [reached] within the gap derivatives [expanded], by
        Dijkstra's algorithm on the reversed edges from the expressions with a
        delay. *)
    let backward reached expanded =
      let into = Hashtbl.create 64 in
      Hashtbl.iter
        (fun id es ->
          List.iter
            (fun (n, _, e) ->
              if Hashtbl.mem reached e.id then
                Hashtbl.replace into e.id
                  ((id, weight n)
                  :: Option.value (Hashtbl.find_opt into e.id) ~default:[]))
            es)
        expanded;
      let delta = Hashtbl.create 64 in
      let rec go frontier =
        match Frontier.min_elt_opt frontier with
        | None -> ()
        | Some ((k, id) as next) ->
            let frontier = Frontier.remove next frontier in
            if Hashtbl.mem delta id then go frontier
            else begin
              Hashtbl.add delta id k;
              go
                (List.fold_left
                   (fun frontier (id', w) ->
                     if Hashtbl.mem delta id' then frontier
                     else Frontier.add (k + w, id') frontier)
                   frontier
                   (Option.value (Hashtbl.find_opt into id) ~default:[]))
            end
      in
      go
        (Hashtbl.fold
           (fun id (e, _) frontier ->
             Option.fold ~none:frontier
               ~some:(fun k -> Frontier.add (k, id) frontier)
               (least (delays e)))
           reached Frontier.empty);
      delta

    (** [build delta expanded r budget] is the least word of [r] of [budget]
        letters, [budget] the length of its shortest words, in the order of the
        blocks, built greedily: at each expression the final delay [budget] if
        it is one, and otherwise the word [tickᵈ a] of greatest [d], then least
        block, that leaves a shortest word of the rest. On words of equal
        length, with [tick] least, this order is the lexicographic order of the
        gap forms, the delays descending and the blocks ascending. *)
    let build delta expanded r budget =
      let rec go r budget acc =
        if DelaySet.mem (Rational.of_int budget) (delays r) then
          (List.rev acc, budget)
        else
          let option (n, m, e) =
            match Hashtbl.find_opt delta e.id with
            | Some k
              when budget - 1 - k >= 0
                   && DelaySet.mem (Rational.of_int (budget - 1 - k)) n ->
                Some (budget - 1 - k, m, e, k)
            | _ -> None
          in
          let better (d, m, _, _) (d', m', _, _) =
            d > d' || (d = d' && Letters.order m.set m'.set < 0)
          in
          let edges =
            match Hashtbl.find_opt expanded r.id with
            | Some es -> es
            | None ->
                invalid_arg
                  "SymbolicRegex.GapDecide.build: an expression on a shortest \
                   word not expanded"
          in
          match List.filter_map option edges with
          | [] ->
              invalid_arg
                "SymbolicRegex.GapDecide.build: no gap derivative leaves a \
                 shortest word"
          | o :: os ->
              let d, m, e, k =
                List.fold_left (fun o o' -> if better o' o then o' else o) o os
              in
              go e k ((d, m.set) :: acc)
      in
      go r budget []

    let search r =
      let best, reached, expanded = forward (blocks [ r ]) r in
      if best = unbounded then begin
        record r reached false;
        None
      end
      else begin
        record r reached true;
        Some (build (backward reached expanded) expanded r best)
      end

    let shortest r =
      if r.nullable then Some ([], 0)
      else if known_empty r then None
      else search r
  end
end

include Make (struct
  let letters = Sets
end)

include Decide (Minterms)
