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

(* [coalesce ivs] merges the overlapping and touching intervals of [ivs],
   sorted by [compare_lo] and non-empty. *)
let coalesce ivs =
  let touches last i =
    match cmp i.lo last.hi with
    | 0 -> last.hi_closed || i.lo_closed
    | c -> c < 0
  in
  let rec go acc = function
    | [] -> List.rev acc
    | i :: rest -> (
        match acc with
        | last :: acc' when touches last i ->
            let last =
              if compare_hi i last > 0 then
                { last with hi = i.hi; hi_closed = i.hi_closed }
              else last
            in
            go (last :: acc') rest
        | _ -> go (i :: acc) rest)
  in
  go [] ivs

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

let union_list xs ys = coalesce (merge xs ys)

(* The intersection by a sweep over both lists. *)
let inter_list xs ys =
  let rec go acc xs ys =
    match (xs, ys) with
    | [], _ | _, [] -> List.rev acc
    | x :: xs', y :: ys' ->
        let l = if compare_lo x y >= 0 then x else y in
        let h, first = if compare_hi x y <= 0 then (x, true) else (y, false) in
        let i =
          {
            lo = l.lo;
            lo_closed = l.lo_closed;
            hi = h.hi;
            hi_closed = h.hi_closed;
          }
        in
        let acc = if nonempty i then i :: acc else acc in
        if first then go acc xs' ys else go acc xs ys'
  in
  go [] xs ys

(* [within w ivs] is the complement of [ivs], a list included in the
   interval [w], relative to [w]. *)
let within w ivs =
  let rec go acc lo lo_closed = function
    | [] ->
        List.rev ({ lo; lo_closed; hi = w.hi; hi_closed = w.hi_closed } :: acc)
    | i :: rest ->
        go
          ({ lo; lo_closed; hi = i.lo; hi_closed = not i.lo_closed } :: acc)
          i.hi (not i.hi_closed) rest
  in
  List.filter nonempty (go [] w.lo w.lo_closed ivs)

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
}
(* [S = base ∪ ⋃ₙ (threshold + n·period + tail)], with [base ⊆ [0, threshold]]
   and [tail ⊆ (0, period]]. *)

(* The window [(0, p]] of a tail and the window [(o, o + p]] of a copy. *)
let period_window o p =
  { lo = o; lo_closed = false; hi = add o p; hi_closed = true }

let full p = [ period_window rzero p ]
let is_full p tail = equal_intervals tail (full p)

(* [copies ~origin ~period ~from tail w] is the union of the copies
   [origin + n·period + tail], [n ≥ from] an integer, intersected with the
   interval [w]. *)
let copies ~origin ~period ~from tail w =
  if tail = [] then []
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
  coalesce
    (base @ copies ~origin:s.threshold ~period:s.period ~from:Z.zero s.tail w)

let upto t = closed rzero t

(* [rotate p q tail] is the tail [tail ⊆ (0, p]] rotated by [q ∈ (0, p)] on
   the circle of length [p]. *)
let rotate p q tail =
  let d = sub p q in
  coalesce
    (List.map (shift (sub q p)) (clip (period_window d q) tail)
    @ List.map (shift q) (clip (period_window rzero d) tail))

(* [components p tail] is the number of the connected components of the tail
   [tail ⊆ (0, p]] on the circle of length [p]. *)
let components p tail =
  let n = List.length tail in
  match (tail, last_hi tail) with
  | first :: _, Some last
    when n > 1
         && Rational.sign first.lo = 0
         && last.hi_closed && Rational.equal last.hi p ->
      n - 1
  | _ -> n

(* [least_period p tail] is the least period of the periodic extension of the
   tail [tail ⊆ (0, p]], neither empty nor full: [p/j] for the greatest
   divisor [j] of its number of components under whose rotation it is
   invariant, the translations permuting the components. *)
let least_period p tail =
  let k = components p tail in
  let rec find j =
    if j <= 1 then p
    else if k mod j = 0 then
      let q = div p (rat j) in
      if equal_intervals (rotate p q tail) tail then q else find (j - 1)
    else find (j - 1)
  in
  find k

(* [least_threshold t p base tail] is the least threshold of the set of
   threshold [t], least period [p], base [base] and tail [tail ⊆ (0, p]]: the
   supremum of the points of [[0, t]] where the set differs from the
   [p]-periodic extension [U] of its tail, found by comparing both over the
   windows [(t - (k+1)p, t - kp]], the last one closed at [0], for
   [k = 0, 1, …] in turn. *)
let least_threshold t p base tail =
  let rec scan b rev =
    let a = sub b p in
    let last = Rational.sign a <= 0 in
    let w = if last then upto b else period_window a p in
    let rev = List.drop_while (fun i -> lt b i.lo) rev in
    let s = clip w (List.rev (List.take_while (fun i -> le a i.hi) rev)) in
    let u = copies ~origin:a ~period:p ~from:Z.minus_one tail w in
    if not (equal_intervals s u) then
      let d =
        union_list (inter_list s (within w u)) (inter_list u (within w s))
      in
      match last_hi d with Some i -> i.hi | None -> b
    else if last then rzero
    else scan a rev
  in
  scan t (List.rev base)

(* [make ~threshold ~period ~base ~tail] is the canonical form of the set
   [base ∪ ⋃ₙ (threshold + n·period + tail)], [base] a list within
   [[0, threshold]] and [tail] one within [(0, period]]. *)
let make ~threshold ~period ~base ~tail =
  let sup_or_zero ivs =
    match last_hi ivs with Some i -> i.hi | None -> rzero
  in
  if tail = [] then { threshold = sup_or_zero base; period = one; base; tail }
  else if is_full period tail then
    let t = sup_or_zero (within (upto threshold) base) in
    { threshold = t; period = one; base = clip (upto t) base; tail = full one }
  else
    let p = least_period period tail in
    let pattern = clip (period_window rzero p) tail in
    let t = least_threshold threshold p base pattern in
    {
      threshold = t;
      period = p;
      base = clip (upto t) base;
      tail =
        List.map
          (shift (Rational.neg t))
          (copies ~origin:threshold ~period:p
             ~from:(Z.pred (floor (div (sub t threshold) p)))
             pattern (period_window t p));
    }

let empty = { threshold = rzero; period = one; base = []; tail = [] }
let zero = { empty with base = [ singleton rzero ] }
let all = { empty with base = [ singleton rzero ]; tail = full one }
let positive = { empty with tail = full one }

(* [from lo lo_closed] is the unbounded interval from [lo]. *)
let from lo lo_closed =
  make ~threshold:lo ~period:one
    ~base:(if lo_closed then [ singleton lo ] else [])
    ~tail:(full one)

let of_intervals ivs =
  let ivs = normalize ivs in
  make ~threshold:rzero ~period:one ~base:ivs ~tail:[]

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

let compare_with (c : GradeLiteral.comparison) q =
  match c with
  | Lt -> interval ~lo:rzero ~lo_closed:true ~hi:(Some q) ~hi_closed:false
  | Le -> interval ~lo:rzero ~lo_closed:true ~hi:(Some q) ~hi_closed:true
  | Gt -> interval ~lo:q ~lo_closed:false ~hi:None ~hi_closed:false
  | Ge -> interval ~lo:q ~lo_closed:true ~hi:None ~hi_closed:false

(* {2 Alignment} *)

let constant s = s.tail = [] || is_full s.period s.tail

(* [align s t p] is the representation of [s] with threshold [t ≥ s.threshold]
   and period [p], a multiple of [s.period] unless the tail of [s] is empty or
   full. *)
let align s t p =
  if constant s then
    {
      threshold = t;
      period = p;
      base = window s (upto t);
      tail = (if s.tail = [] then [] else full p);
    }
  else
    {
      threshold = t;
      period = p;
      base = window s (upto t);
      tail = List.map (shift (Rational.neg t)) (window s (period_window t p));
    }

(* [common_period s r] is a period both [s] and [r] may be aligned to. *)
let common_period s r =
  match (constant s, constant r) with
  | true, true -> one
  | true, false -> r.period
  | false, true -> s.period
  | false, false -> lcm s.period r.period

let compare_list = List.compare compare_interval

let compare s r =
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

let hash s =
  let h i =
    Grade.combine
      (Grade.combine (Rational.hash i.lo) (Bool.to_int i.lo_closed))
      (Grade.combine (Rational.hash i.hi) (Bool.to_int i.hi_closed))
  in
  Grade.combine
    (Grade.combine (Rational.hash s.threshold) (Rational.hash s.period))
    (Grade.combine (Grade.hash_list h s.base) (Grade.hash_list h s.tail))

let binary op s r =
  let t = qmax s.threshold r.threshold and p = common_period s r in
  let s = align s t p and r = align r t p in
  make ~threshold:t ~period:p ~base:(op s.base r.base) ~tail:(op s.tail r.tail)

let is_empty s = s.base = [] && s.tail = []

(* The operations below return an operand where the laws of the Boolean
   algebra and of the sum determine the result from it. *)

let union s r =
  if is_empty s || equal r all then r
  else if is_empty r || equal s all || equal s r then s
  else binary union_list s r

let inter s r =
  if is_empty s || equal r all || equal s r then s
  else if is_empty r || equal s all then r
  else binary inter_list s r

let compl s =
  make ~threshold:s.threshold ~period:s.period
    ~base:(within (upto s.threshold) s.base)
    ~tail:(within (period_window rzero s.period) s.tail)

let diff s r = inter s (compl r)
let intervals_upto x s = window s (upto x)
let subset s r = is_empty (diff s r)

let mem x s =
  if Rational.sign x < 0 then false
  else if le x s.threshold then List.exists (mem_interval x) s.base
  else
    let y = sub x s.threshold in
    let r = sub y (mul (of_z (Z.pred (ceil (div y s.period)))) s.period) in
    List.exists (mem_interval r) s.tail

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
      union
        (of_intervals (clip (upto i.lo) (unroll i.lo)))
        (from i.lo i.lo_closed)
  | [] ->
      let t = match last_hi xs with Some i -> i.hi | None -> rzero in
      let ivs = unroll (add t p) in
      make ~threshold:t ~period:p
        ~base:(clip (upto t) ivs)
        ~tail:(List.map (shift (Rational.neg t)) (clip (period_window t p) ivs))

(* The sum distributes over union, and [pℕ + pℕ = pℕ]: with
   [S = B ∪ (Q + pℕ)] and [S' = B' ∪ (Q' + pℕ)],
   [S + S' = (B + B') ∪ (B + Q' + pℕ) ∪ (Q + B' + pℕ) ∪ (Q + Q' + pℕ)]. *)
let minkowski s r =
  if is_empty s || is_empty r then empty
  else if equal s zero then r
  else if equal r zero then s
  else
    let p = common_period s r in
    let s = align s s.threshold p and r = align r r.threshold p in
    let q = List.map (shift s.threshold) s.tail
    and q' = List.map (shift r.threshold) r.tail in
    let periodic xs = if xs = [] then empty else plus_multiples xs p in
    List.fold_left union
      (of_intervals (sum_list s.base r.base))
      [
        periodic (sum_list s.base q');
        periodic (sum_list q r.base);
        periodic (sum_list q q');
      ]

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

let sum =
  let table = Pairs.create 64 in
  fun s r ->
    match Pairs.find_opt table (s, r) with
    | Some u -> u
    | None ->
        let u = minkowski s r in
        Pairs.add table (s, r) u;
        u

(* {2 Repetition} *)

(* [components_of s] is the intervals of [s] below its threshold and in its
   first period above it. *)
let components_of s = s.base @ List.map (shift s.threshold) s.tail

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
   elements it added last with [s_c]. *)
let star_dense s c =
  let w = upto c in
  let sc =
    window s { lo = rzero; lo_closed = false; hi = c; hi_closed = true }
  in
  let rec go r delta =
    let fresh = inter_list (clip w (sum_list delta sc)) (within w r) in
    if fresh = [] then r else go (union_list r fresh) fresh
  in
  let r = go [ singleton rzero ] [ singleton rzero ] in
  union (of_intervals r) (from c false)

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
  match components_of s with
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

(* {1 Queries} *)

type extremum = Finite of Rational.t * bool | Infinite

let inf s =
  match components_of s with
  | i :: _ -> Some (Finite (i.lo, i.lo_closed))
  | [] -> None

let sup s =
  if s.tail <> [] then Some Infinite
  else Option.map (fun i -> Finite (i.hi, i.hi_closed)) (last_hi s.base)

(* [simplest i] is the simplest rational of the non-empty interval [i], its
   upper end [None] if unbounded, by the Stern–Brocot search: the least integer
   of [i] if there is one, and otherwise [f + 1/y] for [f] the integer part of
   the lower end and [y] the simplest rational of the reciprocal interval. *)
let rec simplest lo lo_closed hi =
  let n =
    if lo_closed && Rational.is_integer lo then lo else of_z (Z.succ (floor lo))
  in
  let below = function
    | None -> true
    | Some (h, h_closed) -> lt n h || (h_closed && Rational.equal n h)
  in
  if below hi then n
  else
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

let choose s =
  let candidates =
    List.map
      (fun i -> simplest i.lo i.lo_closed (Some (i.hi, i.hi_closed)))
      (components_of s)
  in
  let simpler x y =
    match Z.compare (Rational.den x) (Rational.den y) with
    | 0 -> lt x y
    | c -> c < 0
  in
  List.fold_left
    (fun best x ->
      match best with Some b when not (simpler x b) -> best | _ -> Some x)
    None candidates

let minterms sets =
  let split block s =
    List.filter (fun b -> not (is_empty b)) [ inter block s; diff block s ]
  in
  List.fold_left
    (fun blocks s -> List.concat_map (fun b -> split b s) blocks)
    [ all ] sets

(* {1 Printing} *)

(* [interval_regex (lo, lo_closed, hi)] is the expression of the interval from
   [lo] to [hi], [None] if unbounded. *)
let interval_regex (lo, lo_closed, hi) : GradeLiteral.regex =
  let lower = if lo_closed then GradeLiteral.Ge else Gt in
  match hi with
  | Some (h, _) when Rational.equal lo h -> GradeLiteral.rational_tick lo
  | None -> Compare (lower, lo)
  | Some (h, h_closed) ->
      let upper = if h_closed then GradeLiteral.Le else Lt in
      if Rational.sign lo = 0 && lo_closed then Compare (upper, h)
      else Inter (Compare (lower, lo), Compare (upper, h))

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
