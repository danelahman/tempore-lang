(* The sets of delays kept as sorted lists of intervals with rational ends: an
   implementation of the interface of [DelaySet] independent of its
   representation, and the oracle of the tests that compare the two. *)

module Grade = Grades.Grade
module GradeLiteral = Grades.GradeLiteral
module Rational = Grades.Rational

(* Rationals. *)

let rat = Rational.of_int
let rzero = Rational.zero
let add = Rational.add
let sub = Rational.sub
let mul = Rational.mul
let div = Rational.div
let cmp = Rational.compare
let lt a b = cmp a b < 0
let le a b = cmp a b <= 0
let qmax a b = if lt a b then b else a
let of_z = Rational.of_z
let one = Rational.of_int 1
let floor x = Z.fdiv (Rational.num x) (Rational.den x)
let ceil x = Z.cdiv (Rational.num x) (Rational.den x)

module IntMap = Map.Make (Int)

(* The least common multiple and the greatest common divisor of positive
   rationals in lowest terms: [lcm (a/b) (c/d) = lcm a c / gcd b d] and
   [gcd (a/b) (c/d) = gcd a c / lcm b d]. *)
let lcm p q =
  Rational.make_z
    (Z.lcm (Rational.num p) (Rational.num q))
    (Z.gcd (Rational.den p) (Rational.den q))

(* {1 Intervals} *)

type interval = {
  lo : Rational.t;
  lo_closed : bool;
  hi : Rational.t;
  hi_closed : bool;
}

let closed lo hi = { lo; lo_closed = true; hi; hi_closed = true }
let singleton x = closed x x

let nonempty i =
  match cmp i.lo i.hi with 0 -> i.lo_closed && i.hi_closed | c -> c < 0

(* Lower ends ordered by value, a closed end first; upper ends by value, an
   open end first. *)
let compare_lo i j =
  match cmp i.lo j.lo with 0 -> Bool.compare j.lo_closed i.lo_closed | c -> c

let compare_hi i j =
  match cmp i.hi j.hi with 0 -> Bool.compare i.hi_closed j.hi_closed | c -> c

let compare_interval i j =
  match compare_lo i j with 0 -> compare_hi i j | c -> c

let equal_intervals = List.equal (fun i j -> compare_interval i j = 0)
let shift d i = { i with lo = add i.lo d; hi = add i.hi d }

let mem_interval x i =
  (lt i.lo x || (i.lo_closed && Rational.equal i.lo x))
  && (lt x i.hi || (i.hi_closed && Rational.equal x i.hi))

(* {2 Interval lists}

   A list is sorted by [compare_lo], its intervals non-empty, disjoint and not
   touching: two intervals meeting at a point that one of them contains are
   one. *)

(* [touches last i] is whether the interval [i], whose lower end is not below
   that of [last], meets or touches [last], and [join last i] is then their
   union. *)
let touches last i =
  match cmp i.lo last.hi with 0 -> last.hi_closed || i.lo_closed | c -> c < 0

let join last i =
  if compare_hi i last > 0 then { last with hi = i.hi; hi_closed = i.hi_closed }
  else last

(* [push acc i] adds the interval [i], whose lower end is not below those of
   the intervals of the reversed list [acc], to it. *)
let push acc i =
  match acc with
  | last :: acc' when touches last i -> join last i :: acc'
  | _ -> i :: acc

(* [drain acc ivs] is the reversed list [acc] followed by the list [ivs],
   whose lower ends are not below those of [acc]: the intervals of [ivs] are
   pushed while they touch the last one, and the others shared. *)
let rec drain acc ivs =
  match (acc, ivs) with
  | last :: _, i :: rest when touches last i -> drain (push acc i) rest
  | _ -> List.rev_append acc ivs

(* [coalesce ivs] merges the overlapping and touching intervals of [ivs],
   sorted by [compare_lo] and non-empty. *)
let coalesce ivs = List.rev (List.fold_left push [] ivs)

(* [append xs ys] is the list of the union of the lists [xs] and [ys], every
   interval of [ys] lying above those of [xs]. *)
let append xs ys = if ys = [] then xs else drain (List.rev xs) ys

let normalize ivs =
  coalesce (List.stable_sort compare_lo (List.filter nonempty ivs))

(* [merge xs ys] merges two lists sorted by [compare_lo], tail-recursively. *)
let merge xs ys =
  let rec go acc xs ys =
    match (xs, ys) with
    | [], rest | rest, [] -> List.rev_append acc rest
    | x :: xs', y :: ys' ->
        if compare_lo x y <= 0 then go (x :: acc) xs' ys
        else go (y :: acc) xs ys'
  in
  go [] xs ys

(* The union by a merge sweep over both lists. *)
let union_list xs ys =
  let rec go acc xs ys =
    match (xs, ys) with
    | [], rest | rest, [] -> drain acc rest
    | x :: xs', y :: ys' ->
        if compare_lo x y <= 0 then go (push acc x) xs' ys
        else go (push acc y) xs ys'
  in
  go [] xs ys

(* [meet i j] is the intersection of the intervals [i] and [j], empty unless
   [nonempty] holds of it: one of them if it has the greater lower end and the
   lesser upper end. *)
let meet i j =
  let l = if compare_lo i j >= 0 then i else j
  and h = if compare_hi i j <= 0 then i else j in
  if l == h then l
  else
    { lo = l.lo; lo_closed = l.lo_closed; hi = h.hi; hi_closed = h.hi_closed }

(* The intersection by a sweep over both lists. *)
let inter_list xs ys =
  let rec go acc xs ys =
    match (xs, ys) with
    | [], _ | _, [] -> List.rev acc
    | x :: xs', y :: ys' ->
        let i = meet x y in
        let acc = if nonempty i then i :: acc else acc in
        if compare_hi x y <= 0 then go acc xs' ys else go acc xs ys'
  in
  go [] xs ys

(* [within w ivs] is the complement of [ivs], a list included in the
   interval [w], relative to [w]. *)
let within w ivs =
  let gap acc lo lo_closed hi hi_closed =
    let g = { lo; lo_closed; hi; hi_closed } in
    if nonempty g then g :: acc else acc
  in
  let rec go acc lo lo_closed = function
    | [] -> List.rev (gap acc lo lo_closed w.hi w.hi_closed)
    | i :: rest ->
        go
          (gap acc lo lo_closed i.lo (not i.lo_closed))
          i.hi (not i.hi_closed) rest
  in
  go [] w.lo w.lo_closed ivs

let clip w ivs = inter_list ivs [ w ]

(* [merge_all lists] merges the lists sorted by [compare_lo] in [lists], by
   balanced pairwise merges. *)
let rec merge_all = function
  | [] -> []
  | [ xs ] -> xs
  | lists ->
      let rec pairs acc = function
        | xs :: ys :: rest -> pairs (merge xs ys :: acc) rest
        | [ xs ] -> List.rev (xs :: acc)
        | [] -> List.rev acc
      in
      merge_all (pairs [] lists)

(* The Minkowski sum: [⟨a, b⟩ + ⟨c, d⟩ = ⟨a + c, b + d⟩], an end closed iff
   both are. The translates of the longer list by each interval of the shorter
   are sorted, since the lower ends of a list increase strictly, and are
   merged. *)
let sum_list xs ys =
  let xs, ys =
    if List.length xs >= List.length ys then (xs, ys) else (ys, xs)
  in
  coalesce
    (merge_all
       (List.map
          (fun y ->
            List.map
              (fun x ->
                {
                  lo = add x.lo y.lo;
                  lo_closed = x.lo_closed && y.lo_closed;
                  hi = add x.hi y.hi;
                  hi_closed = x.hi_closed && y.hi_closed;
                })
              xs)
          ys))

let last_hi ivs = List.fold_left (fun _ i -> Some i) None ivs

(* {1 Sets} *)

type t = {
  threshold : Rational.t;
  period : Rational.t;
  base : interval list;
  tail : interval list;
  hash : int;
}
(* [S = base ∪ ⋃ₙ (threshold + n·period + tail)], with [base ⊆ [0, threshold]]
   and [tail ⊆ (0, period]]; [hash] is the hash of the other fields, computed
   once, when the set is formed. *)

let form ~threshold ~period ~base ~tail =
  let h i =
    Grade.combine
      (Grade.combine (Rational.hash i.lo) (Bool.to_int i.lo_closed))
      (Grade.combine (Rational.hash i.hi) (Bool.to_int i.hi_closed))
  in
  let hash =
    Grade.combine
      (Grade.combine (Rational.hash threshold) (Rational.hash period))
      (Grade.combine (Grade.hash_list h base) (Grade.hash_list h tail))
  in
  { threshold; period; base; tail; hash }

(* The window [(0, p]] of a tail and the window [(o, o + p]] of a copy. *)
let period_window o p =
  { lo = o; lo_closed = false; hi = add o p; hi_closed = true }

let full p = [ period_window rzero p ]
let is_full p tail = equal_intervals tail (full p)

(* [copies ~origin ~period ~from tail w] is the union of the copies
   [origin + n·period + tail], [n ≥ from] an integer, intersected with the
   interval [w]: that of a full tail is [(origin + from·period, ∞) ∩ w]. *)
let copies ~origin ~period ~from tail w =
  if tail = [] then []
  else if is_full period tail then
    clip w
      [
        {
          lo = add origin (mul (of_z from) period);
          lo_closed = false;
          hi = w.hi;
          hi_closed = w.hi_closed;
        };
      ]
  else
    let first = Z.max from (Z.pred (floor (div (sub w.lo origin) period))) in
    let rec go acc n =
      let o = add origin (mul (of_z n) period) in
      if le w.hi o then List.rev acc
      else
        go (List.rev_append (clip w (List.map (shift o) tail)) acc) (Z.succ n)
    in
    coalesce (go [] first)

(* [window s w] is [s ∩ w], a list. *)
let window s w =
  let base = if lt s.threshold w.lo then [] else clip w s.base in
  append base
    (copies ~origin:s.threshold ~period:s.period ~from:Z.zero s.tail w)

let upto t = closed rzero t

(* [arcs p tail] is the array of the connected components of the tail
   [tail ⊆ (0, p]] on the circle of length [p], in increasing order: its
   intervals, the last and the first joined across [p] if they meet there, the
   joined one then ending beyond [p]. *)
let arcs p tail =
  match tail with
  | first :: (_ :: _ as rest) when Rational.sign first.lo = 0 -> (
      match List.rev rest with
      | last :: middle when last.hi_closed && Rational.equal last.hi p ->
          Array.of_list
            (List.rev_append middle
               [
                 { last with hi = add first.hi p; hi_closed = first.hi_closed };
               ])
      | _ -> Array.of_list tail)
  | _ -> Array.of_list tail

(* [border equal w] is the length of the longest proper border of the
   non-empty array [w], its longest proper prefix that is also a suffix, by
   the failure function of Knuth, Morris and Pratt ("Fast pattern matching in
   strings", SIAM J. Comput. 6, 1977): entry [i] is the longest proper border
   of the prefix of length [i + 1]. *)
let border equal w =
  let k = Array.length w in
  let f = Array.make k 0 in
  let rec extend b i =
    if equal w.(i) w.(b) then b + 1 else if b = 0 then 0 else extend f.(b - 1) i
  in
  for i = 1 to k - 1 do
    f.(i) <- extend f.(i - 1) i
  done;
  f.(k - 1)

(* [least_period p tail] is the least period of the periodic extension of the
   tail [tail ⊆ (0, p]], neither empty nor full. Its [k] components on the
   circle of length [p], each read as its ends, its length and the gap to the
   next, form a circular word whose rotations are the translations leaving the
   tail invariant: the least period is [p·m/k], [m] the length of the
   primitive root of the word, which is [k - f] if that divides [k] and [k]
   otherwise, [f] the length of its longest proper border. *)
let least_period p tail =
  let arcs = arcs p tail in
  let k = Array.length arcs in
  let letter i =
    let a = arcs.(i) in
    let next = if i = k - 1 then add arcs.(0).lo p else arcs.(i + 1).lo in
    (a.lo_closed, sub a.hi a.lo, a.hi_closed, sub next a.hi)
  in
  let equal_letter (c, l, c', g) (d, m, d', h) =
    Bool.equal c d && Rational.equal l m && Bool.equal c' d'
    && Rational.equal g h
  in
  let m = k - border equal_letter (Array.init k letter) in
  div p (rat (if k mod m = 0 then k / m else 1))

(* [least_threshold t p base tail] is the least threshold of the set [S] of
   threshold [t], least period [p], base [base] and tail [tail ⊆ (0, p]]: the
   supremum of the points [x ∈ [0, t]] with [x ∈ S ⇎ x + p ∈ S], [0] if there
   are none. The maximal intervals of [S ∩ [0, t]] and of [(S - p) ∩ [0, t]]
   are compared downwards from [t], and the supremum is read off the first two
   that differ. *)
let least_threshold t p base tail =
  let down =
    (* The maximal intervals of [S ∩ [0, t + p]] in decreasing order. *)
    match (List.rev base, List.map (shift t) tail) with
    | b :: bs, u :: us when touches b u -> List.rev_append (join b u :: us) bs
    | bs, us -> List.rev_append us bs
  in
  let upto_threshold ivs =
    Seq.filter_map
      (fun i ->
        let j = meet i (upto t) in
        if nonempty j then Some j else None)
      ivs
  in
  let rec first_difference xs ys =
    match (xs (), ys ()) with
    | Seq.Nil, Seq.Nil -> rzero
    | Seq.Cons (x, _), Seq.Nil | Seq.Nil, Seq.Cons (x, _) -> x.hi
    | Seq.Cons (x, xs), Seq.Cons (y, ys) ->
        if compare_interval x y = 0 then first_difference xs ys
        else if compare_hi x y <> 0 then qmax x.hi y.hi
        else qmax x.lo y.lo
  in
  first_difference
    (upto_threshold (List.to_seq down))
    (upto_threshold (Seq.map (shift (Rational.neg p)) (List.to_seq down)))

(* [make ~threshold ~period ~base ~tail] is the canonical form of the set
   [base ∪ ⋃ₙ (threshold + n·period + tail)], [base] a list within
   [[0, threshold]] and [tail] one within [(0, period]]. *)
let make ~threshold ~period ~base ~tail =
  if tail = [] then
    form
      ~threshold:(match last_hi base with Some i -> i.hi | None -> rzero)
      ~period:one ~base ~tail
  else if is_full period tail then
    (* The least threshold is the supremum of [[0, threshold] ∖ base]: the
       lower end of the last interval of [base] if that contains [threshold],
       and [threshold] otherwise. *)
    match last_hi base with
    | Some i when i.hi_closed && Rational.equal i.hi threshold ->
        form ~threshold:i.lo ~period:one
          ~base:(clip (upto i.lo) base)
          ~tail:(full one)
    | _ -> form ~threshold ~period:one ~base ~tail:(full one)
  else
    let p = least_period period tail in
    let pattern =
      if Rational.equal p period then tail
      else clip (period_window rzero p) tail
    in
    let t = least_threshold threshold p base pattern in
    if Rational.equal t threshold then
      form ~threshold ~period:p ~base ~tail:pattern
    else
      form ~threshold:t ~period:p
        ~base:(clip (upto t) base)
        ~tail:
          (List.map
             (shift (Rational.neg t))
             (copies ~origin:threshold ~period:p
                ~from:(Z.pred (floor (div (sub t threshold) p)))
                pattern (period_window t p)))

let empty = form ~threshold:rzero ~period:one ~base:[] ~tail:[]
let zero = form ~threshold:rzero ~period:one ~base:[ singleton rzero ] ~tail:[]

let all =
  form ~threshold:rzero ~period:one ~base:[ singleton rzero ] ~tail:(full one)

let positive = form ~threshold:rzero ~period:one ~base:[] ~tail:(full one)

(* [from lo lo_closed] is the unbounded interval from [lo]. *)
let from lo lo_closed =
  make ~threshold:lo ~period:one
    ~base:(if lo_closed then [ singleton lo ] else [])
    ~tail:(full one)

(* [of_list ivs] is the bounded set of the list [ivs]. *)
let of_list ivs = make ~threshold:rzero ~period:one ~base:ivs ~tail:[]
let of_intervals ivs = of_list (normalize ivs)

let point q =
  if Rational.sign q < 0 then invalid_arg "DelaySet.point"
  else of_intervals [ singleton q ]

let interval ~lo ~lo_closed ~hi ~hi_closed =
  let lo, lo_closed =
    if Rational.sign lo < 0 then (rzero, true) else (lo, lo_closed)
  in
  match hi with
  | Some hi ->
      of_intervals
        (clip (upto (qmax hi rzero)) [ { lo; lo_closed; hi; hi_closed } ])
  | None -> from lo lo_closed

let between (lo : Rational.t GradeLiteral.bound)
    (hi : Rational.t GradeLiteral.bound) =
  let lo, lo_closed =
    match lo with
    | Closed a -> (a, true)
    | Open a -> (a, false)
    | Unbounded -> (rzero, true)
  in
  let hi, hi_closed =
    match hi with
    | Closed b -> (Some b, true)
    | Open b -> (Some b, false)
    | Unbounded -> (None, false)
  in
  interval ~lo ~lo_closed ~hi ~hi_closed

(* {2 Alignment} *)

let constant s = s.tail = [] || is_full s.period s.tail

(* [align s t p] is the base and the tail of the representation of [s] with
   threshold [t ≥ s.threshold] and period [p], a multiple of [s.period] unless
   the tail of [s] is empty or full: those of [s] if [t] and [p] are its
   own. *)
let align s t p =
  if Rational.equal t s.threshold && Rational.equal p s.period then
    (s.base, s.tail)
  else
    ( window s (upto t),
      if s.tail = [] then []
      else if constant s then full p
      else List.map (shift (Rational.neg t)) (window s (period_window t p)) )

(* [common_period s r] is a period both [s] and [r] may be aligned to. *)
let common_period s r =
  match (constant s, constant r) with
  | true, true -> one
  | true, false -> r.period
  | false, true -> s.period
  | false, false -> lcm s.period r.period

let compare_list = List.compare compare_interval

let compare s r =
  if s == r then 0
  else
    match cmp s.threshold r.threshold with
    | 0 -> (
        match cmp s.period r.period with
        | 0 -> (
            match compare_list s.base r.base with
            | 0 -> compare_list s.tail r.tail
            | c -> c)
        | c -> c)
    | c -> c

let equal s r = compare s r = 0
let hash s = s.hash

let binary op s r =
  let t = qmax s.threshold r.threshold and p = common_period s r in
  let base, tail = align s t p and base', tail' = align r t p in
  make ~threshold:t ~period:p ~base:(op base base') ~tail:(op tail tail')

let is_empty s = s.base = [] && s.tail = []

(* The operations below return an operand where the laws of the Boolean
   algebra and of the sum determine the result from it. *)

let union s r =
  if is_empty s || equal r all then r
  else if is_empty r || equal s all || equal s r then s
  else binary union_list s r

(* [inter_bounded s r] is [s ∩ r] for a bounded [r], whose threshold is its
   supremum: [(s ∩ [0, sup r]) ∩ r], which reads [s] only up to [sup r]. *)
let inter_bounded s r =
  of_list (inter_list (window s (upto r.threshold)) r.base)

let inter s r =
  if is_empty s || equal r all || equal s r then s
  else if is_empty r || equal s all then r
  else if r.tail = [] then inter_bounded s r
  else if s.tail = [] then inter_bounded r s
  else binary inter_list s r

(* The complement of a canonical form is canonical: [x ∈ S ⇎ x + p ∈ S] holds
   of the same points for [S] and its complement, and the tail of one is empty
   iff that of the other is full. *)
let compl s =
  form ~threshold:s.threshold ~period:s.period
    ~base:(within (upto s.threshold) s.base)
    ~tail:(within (period_window rzero s.period) s.tail)

let diff s r = inter s (compl r)
let threshold s = s.threshold
let period s = s.period
let intervals_upto x s = window s (upto x)

(* [pieces s] is the sequence of the intervals of [s] in increasing order:
   those of its base, then the copies of its tail, one period after another,
   not joined where they touch. *)
let pieces s =
  let copy n =
    Seq.map
      (shift (add s.threshold (mul (of_z n) s.period)))
      (List.to_seq s.tail)
  in
  Seq.append (List.to_seq s.base)
    (if s.tail = [] then Seq.empty
     else Seq.flat_map copy (Seq.iterate Z.succ Z.zero))

(* [intersects s r] sweeps the pieces of [s] and of [r] in increasing order
   until two of them meet, or until one lies above the greater threshold plus
   a common period: both sets are periodic with that period above the greater
   threshold, so a common element above it has a translate below. *)
let intersects s r =
  let bound = add (qmax s.threshold r.threshold) (common_period s r) in
  let rec sweep xs ys =
    match (xs, ys) with
    | Seq.Nil, _ | _, Seq.Nil -> false
    | Seq.Cons (x, xs'), Seq.Cons (y, ys') ->
        nonempty (meet x y)
        || le x.lo bound && le y.lo bound
           &&
           if compare_hi x y <= 0 then sweep (xs' ()) ys else sweep xs (ys' ())
  in
  sweep (pieces s ()) (pieces r ())

let subset s r = not (intersects s (compl r))

let mem x s =
  if Rational.sign x < 0 then false
  else if le x s.threshold then List.exists (mem_interval x) s.base
  else
    let y = sub x s.threshold in
    let r = sub y (mul (of_z (Z.pred (ceil (div y s.period)))) s.period) in
    List.exists (mem_interval r) s.tail

(* {2 Repetition} *)

(* The sums and repetitions computed, recorded in module-level tables by their
   arguments, which only ever grow: they are the costliest operations, and the
   gap closures of automata take them of the same sets repeatedly. *)
module Sets = Hashtbl.Make (struct
  type nonrec t = t

  let equal = equal
  let hash = hash
end)

module Pairs = Hashtbl.Make (struct
  type nonrec t = t * t

  let equal (s, r) (s', r') = equal s s' && equal r r'
  let hash (s, r) = Grade.combine (hash s) (hash r)
end)

(* [components_of s] is the sequence of the intervals of [s] below its
   threshold and in its first period above it, in increasing order. *)
let components_of s =
  Seq.append (List.to_seq s.base)
    (Seq.map (shift s.threshold) (List.to_seq s.tail))

(* [multiples_from i] is the least [c = n₀a] such that the multiples
   [n⟨a, b⟩], [n ≥ n₀], cover [(c, ∞)]: [n₀] is the least [n ≥ 1] with
   [n(b - a) > a], or [n(b - a) ≥ a] if both ends are closed, so that
   [n⟨a, b⟩] and [(n+1)⟨a, b⟩] meet. *)
let multiples_from i =
  let w = sub i.hi i.lo in
  let ratio = div i.lo w in
  let n =
    if i.lo_closed && i.hi_closed && Rational.is_integer ratio then
      Z.max Z.one (floor ratio)
    else Z.succ (floor ratio)
  in
  mul (of_z n) i.lo

(* [star_dense s c] is [s* = R ∪ (c, ∞)], [R] the least fixpoint of
   [R = {0} ∪ (R + s_c) ∩ [0, c]] for [s_c = s ∩ (0, c]], all of whose elements
   are positive, by semi-naive iteration: each round adds to [R] the sums of the
   elements it added last with [s_c]. [R] is kept as a balanced search tree of
   its intervals, so that a round costs a logarithmic time in [|R|] for each
   interval of those sums. *)
let star_dense s c =
  let module R = Set.Make (struct
    type t = interval

    let compare = compare_lo
  end) in
  let w = upto c in
  let sc =
    window s { lo = rzero; lo_closed = false; hi = c; hi_closed = true }
  in
  (* The intervals of [r] that meet or touch the closure of [i]: from the last
     one starting below [i], up to the last one starting at most at its upper
     end. *)
  let near r i =
    let start =
      match R.find_last_opt (fun k -> lt k.lo i.lo) r with
      | Some k -> k
      | None -> { i with lo_closed = true }
    in
    List.of_seq
      (Seq.filter
         (fun k -> le i.lo k.hi)
         (Seq.take_while (fun k -> le k.lo i.hi) (R.to_seq_from start r)))
  in
  (* [add (r, fresh) i] adds to [r] the part of [i] outside it, and to the
     reversed list [fresh] its intervals. *)
  let add (r, fresh) i =
    let ks = near r i in
    match within i (clip i ks) with
    | [] -> (r, fresh)
    | gaps ->
        ( List.fold_left
            (fun r k -> R.add k r)
            (List.fold_left (fun r k -> R.remove k r) r ks)
            (union_list ks gaps),
          List.rev_append gaps fresh )
  in
  let rec go r delta =
    match List.fold_left add (r, []) (clip w (sum_list delta sc)) with
    | r, [] -> r
    | r, fresh -> go r (List.rev fresh)
  in
  let z = singleton rzero in
  union (of_list (R.elements (go (R.singleton z) [ z ]))) (from c false)

(* [star_discrete s] is [s*] for a set [s] of positive points [F ∪ (G + pℕ)]:
   scaled by a common denominator [D], its multiples form the numerical
   semigroup [A] generated by [DF ∪ (DG + Dpℕ)]. With [μ = D·min s ∈ A],
   [x ∈ A] iff [x ≥ w(x mod μ)], [w(r)] the least element of [A] congruent to
   [r], the Apéry set, which is the shortest-path distance from [0] over the
   residues modulo [μ], each residue class of generators contributing an edge
   weighted by its least generator (Nijenhuis 1979). The least generator of a
   class is among [DF] and [Dg + jDp] for [j < μ / gcd(μ, Dp)]. *)
let star_discrete s =
  let points = List.map (fun i -> i.lo) s.base in
  let families = List.map (fun i -> add s.threshold i.lo) s.tail in
  let d =
    List.fold_left
      (fun d x -> Z.lcm d (Rational.den x))
      (Rational.den s.period) (points @ families)
  in
  let scale x = Z.to_int (Rational.num (mul x (of_z d))) in
  let mu = List.fold_left min max_int (List.map scale (points @ families)) in
  let dp = scale s.period in
  let span = mu / Z.to_int (Z.gcd (Z.of_int mu) (Z.of_int dp)) in
  let generators =
    List.map scale points
    @ List.concat_map
        (fun g -> List.init span (fun j -> scale g + (j * dp)))
        families
  in
  (* The least generator of each residue class modulo [μ]. *)
  let edges =
    IntMap.bindings
      (List.fold_left
         (fun least x ->
           IntMap.update (x mod mu)
             (function Some y when y <= x -> Some y | _ -> Some x)
             least)
         IntMap.empty generators)
  in
  let module Queue = Set.Make (struct
    type t = int * int

    let compare (d, u) (d', u') =
      match Int.compare d d' with 0 -> Int.compare u u' | c -> c
  end) in
  let rec dijkstra dist queue =
    match Queue.min_elt_opt queue with
    | None -> dist
    | Some ((du, u) as top) ->
        let queue = Queue.remove top queue in
        if du > IntMap.find u dist then dijkstra dist queue
        else
          let dist, queue =
            List.fold_left
              (fun (dist, queue) (r, g) ->
                let v = (u + r) mod mu and dv = du + g in
                match IntMap.find_opt v dist with
                | Some dv' when dv' <= dv -> (dist, queue)
                | _ -> (IntMap.add v dv dist, Queue.add (dv, v) queue))
              (dist, queue) edges
          in
          dijkstra dist queue
  in
  let dist = dijkstra (IntMap.singleton 0 0) (Queue.singleton (0, 0)) in
  let w = IntMap.fold (fun _ d w -> max d w) dist 0 in
  let at x = Rational.make_z (Z.of_int x) d in
  let member x =
    match IntMap.find_opt (x mod mu) dist with
    | Some least -> least <= x
    | None -> false
  in
  let points_among xs =
    List.filter_map (fun x -> if member x then Some x else None) xs
  in
  make ~threshold:(at w) ~period:(at mu)
    ~base:
      (List.map
         (fun x -> singleton (at x))
         (points_among (List.init (w + 1) Fun.id)))
    ~tail:
      (List.map
         (fun x -> singleton (at (x - w)))
         (points_among (List.init mu (fun k -> w + k + 1))))

let repetition s =
  let s = diff s zero in
  match List.of_seq (components_of s) with
  | [] -> zero
  | first :: _ when Rational.sign first.lo = 0 -> all
  | ivs -> (
      match List.filter (fun i -> lt i.lo i.hi) ivs with
      | [] -> star_discrete s
      | i :: rest ->
          star_dense s
            (List.fold_left
               (fun c i ->
                 let c' = multiples_from i in
                 if lt c' c then c' else c)
               (multiples_from i) rest))

let star =
  let table = Sets.create 16 in
  fun s ->
    match Sets.find_opt table s with
    | Some r -> r
    | None ->
        let r = repetition s in
        Sets.add table s r;
        r

(* {2 Sums} *)

(* [plus_multiples xs p] is the set [X + pℕ] for the non-empty list [X]:
   eventually full from the least lower end [a] of an interval [⟨a, b⟩] of [X]
   whose consecutive translates meet, and otherwise of threshold [sup X] and
   period [p], since for [x ≥ sup X], [x + p ∈ X + pℕ] iff [x ∈ X + pℕ]. *)
let plus_multiples xs p =
  let covering i =
    let a' = add i.lo p in
    match cmp a' i.hi with 0 -> i.hi_closed || i.lo_closed | c -> c < 0
  in
  let unroll limit =
    let low = (List.hd xs).lo in
    let rec go acc n =
      let o = mul (rat n) p in
      if lt limit (add low o) then acc
      else go (List.rev_append (List.map (shift o) xs) acc) (n + 1)
    in
    normalize (go [] 0)
  in
  match List.filter covering xs with
  | i :: _ ->
      union (of_list (clip (upto i.lo) (unroll i.lo))) (from i.lo i.lo_closed)
  | [] ->
      let t = match last_hi xs with Some i -> i.hi | None -> rzero in
      let ivs = unroll (add t p) in
      make ~threshold:t ~period:p
        ~base:(clip (upto t) ivs)
        ~tail:(List.map (shift (Rational.neg t)) (clip (period_window t p) ivs))

(* [progression s] is [Some p] if [s] is [pℕ], of canonical form
   [(0, p, {0}, {p})], and [None] otherwise. *)
let progression s =
  match (s.base, s.tail) with
  | [ _ ], [ i ]
    when Rational.sign s.threshold = 0
         && Rational.equal i.lo s.period
         && Rational.equal i.hi s.period ->
      Some s.period
  | _ -> None

(* The sum of two progressions is the numerical semigroup
   [pℕ + qℕ = {p, q}*], by its Apéry set. Otherwise the sum distributes over
   union, and [pℕ + pℕ = pℕ]: with [S = B ∪ (Q + pℕ)] and [S' = B' ∪ (Q' + pℕ)],
   [S + S' = (B + B') ∪ (B + Q' + pℕ) ∪ (Q + B' + pℕ) ∪ (Q + Q' + pℕ)]. *)
let minkowski s r =
  if is_empty s || is_empty r then empty
  else if equal s zero then r
  else if equal r zero then s
  else
    match (progression s, progression r) with
    | Some p, Some q -> star (union (point p) (point q))
    | _ ->
        let p = common_period s r in
        let base, tail = align s s.threshold p
        and base', tail' = align r r.threshold p in
        let q = List.map (shift s.threshold) tail
        and q' = List.map (shift r.threshold) tail' in
        let periodic xs = if xs = [] then empty else plus_multiples xs p in
        List.fold_left union
          (of_list (sum_list base base'))
          [
            periodic (sum_list base q');
            periodic (sum_list q base');
            periodic (sum_list q q');
          ]

let sum =
  let table = Pairs.create 64 in
  fun s r ->
    match Pairs.find_opt table (s, r) with
    | Some u -> u
    | None ->
        let u = minkowski s r in
        Pairs.add table (s, r) u;
        u

(* {1 Queries} *)

type extremum = Finite of Rational.t * bool | Infinite

let equal_extremum x y =
  match (x, y) with
  | Finite (a, f), Finite (b, g) -> Rational.equal a b && Bool.equal f g
  | Infinite, Infinite -> true
  | Finite _, Infinite | Infinite, Finite _ -> false

let hash_extremum = function
  | Finite (a, f) -> Grade.combine (Rational.hash a) (Bool.to_int f)
  | Infinite -> -1

let inf s =
  match components_of s () with
  | Seq.Cons (i, _) -> Some (Finite (i.lo, i.lo_closed))
  | Seq.Nil -> None

let sup s =
  if s.tail <> [] then Some Infinite
  else Option.map (fun i -> Finite (i.hi, i.hi_closed)) (last_hi s.base)

(* [least_integer lo lo_closed hi] is the least integer of the interval from
   [lo] to [hi], unbounded if [hi] is [None], if it has one. *)
let least_integer lo lo_closed hi =
  let n =
    if lo_closed && Rational.is_integer lo then lo else of_z (Z.succ (floor lo))
  in
  match hi with
  | Some (h, h_closed) when not (lt n h || (h_closed && Rational.equal n h)) ->
      None
  | _ -> Some n

(* [simplest i] is the simplest rational of the non-empty interval [i], its
   upper end [None] if unbounded, by the Stern–Brocot search: the least integer
   of [i] if there is one, and otherwise [f + 1/y] for [f] the integer part of
   the lower end and [y] the simplest rational of the reciprocal interval. *)
let rec simplest lo lo_closed hi =
  match least_integer lo lo_closed hi with
  | Some n -> n
  | None ->
      let f = of_z (floor lo) in
      let h, h_closed = Option.get hi in
      let inv x = div (rat 1) x in
      let y =
        simplest
          (inv (sub h f))
          h_closed
          (if Rational.equal lo f then None else Some (inv (sub lo f), lo_closed))
      in
      add f (inv y)

(* An integer has the least denominator, and the components increase: the
   least integer of the first component having one is the simplest element. *)
let choose s =
  let hi i = Some (i.hi, i.hi_closed) in
  match
    Seq.find_map
      (fun i -> least_integer i.lo i.lo_closed (hi i))
      (components_of s)
  with
  | Some n -> Some n
  | None ->
      let simpler x y =
        match Z.compare (Rational.den x) (Rational.den y) with
        | 0 -> lt x y
        | c -> c < 0
      in
      Seq.fold_left
        (fun best i ->
          let x = simplest i.lo i.lo_closed (hi i) in
          match best with Some b when not (simpler x b) -> best | _ -> Some x)
        None (components_of s)

let minterms sets =
  let split block s =
    List.filter (fun b -> not (is_empty b)) [ inter block s; diff block s ]
  in
  List.fold_left
    (fun blocks s -> List.concat_map (fun b -> split b s) blocks)
    [ all ] sets

(* {1 Printing} *)

(* [interval_regex (lo, lo_closed, hi)] is the expression of the interval from
   [lo] to [hi], [None] if unbounded: a delay if it is a single point, and an
   interval atom otherwise. *)
let interval_regex (lo, lo_closed, hi) : GradeLiteral.regex =
  match hi with
  | Some (h, _) when Rational.equal lo h -> GradeLiteral.rational_tick lo
  | _ ->
      Delays
        ( (if lo_closed then Closed lo else Open lo),
          match hi with
          | None -> Unbounded
          | Some (h, true) -> Closed h
          | Some (h, false) -> Open h )

let union_regex = function
  | [] -> None
  | r :: rs -> Some (List.fold_left (fun r s -> GradeLiteral.Union (r, s)) r rs)

let to_regex s =
  let bounded =
    List.map (fun i ->
        interval_regex (i.lo, i.lo_closed, Some (i.hi, i.hi_closed)))
  in
  let parts =
    if s.tail = [] then bounded s.base
    else if is_full s.period s.tail then
      let ivs = coalesce (s.base @ [ period_window s.threshold one ]) in
      let n = List.length ivs in
      List.mapi
        (fun k i ->
          interval_regex
            ( i.lo,
              i.lo_closed,
              if k = n - 1 then None else Some (i.hi, i.hi_closed) ))
        ivs
    else
      (* The periodic part [Q + pℕ], [Q] the first period above the
         threshold, shifted down by [p] while it stays within the base. *)
      let base = Array.of_list s.base in
      let contained i =
        (* The interval of the base containing [i], if any, is the last one
           whose lower end is not above that of [i]. *)
        let rec search lo hi =
          if hi - lo <= 1 then lo
          else
            let mid = (lo + hi) / 2 in
            if compare_lo base.(mid) i <= 0 then search mid hi
            else search lo mid
        in
        Array.length base > 0
        && compare_lo base.(0) i <= 0
        &&
        let k = search 0 (Array.length base) in
        compare_hi i base.(k) <= 0
      in
      let rec lower q =
        let q' = List.map (shift (Rational.neg s.period)) q in
        match q' with
        | i :: _ when Rational.sign i.lo >= 0 && List.for_all contained q' ->
            lower q'
        | _ -> q
      in
      let q = lower (List.map (shift s.threshold) s.tail) in
      let rest = diff (of_intervals s.base) (plus_multiples q s.period) in
      let multiples = GradeLiteral.Star (GradeLiteral.rational_tick s.period) in
      bounded rest.base
      @ [
          (match q with
          | [ i ] when Rational.sign i.hi = 0 -> multiples
          | _ -> Seq (Option.get (union_regex (bounded q)), multiples));
        ]
  in
  Option.value (union_regex parts) ~default:(GradeLiteral.Compl (Star Any))

let show s = GradeLiteral.show_regex (to_regex s)
