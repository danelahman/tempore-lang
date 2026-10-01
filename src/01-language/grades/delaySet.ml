(* Rationals. *)

let rzero = Rational.zero
let add = Rational.add
let sub = Rational.sub
let div = Rational.div
let cmp = Rational.compare
let lt a b = cmp a b < 0
let rat = Rational.of_int
let of_z = Rational.of_z
let floor x = Z.fdiv (Rational.num x) (Rational.den x)

module IntMap = Map.Make (Int)

(* {1 Runs of atoms}

   For a positive integer [g], the grid [1/g] partitions [ℚ≥0] into atoms: the
   point [k/g], atom [2k], and the open cell [(k/g, (k + 1)/g)], atom [2k + 1].
   A run [[s, e)], [s < e], is the union of the atoms [a] with [s ≤ a < e]: the
   interval from [⌊s/2⌋/g] to [⌊e/2⌋/g], closed below iff [s] is even and
   closed above iff [e] is odd. Two runs [[s, e)] and [[s', e')] with [s ≤ s']
   meet or touch iff [s' ≤ e]. A list of intervals whose ends are multiples of
   [1/g], sorted, disjoint and no two of which touch, is the array
   [[|s₀; e₀; s₁; e₁; …|]] of the bounds of its runs, [sᵢ < eᵢ < sᵢ₊₁]; the
   order of intervals by their lower ends, then by their upper ends, is that
   of the pairs [(sᵢ, eᵢ)]. Bounds are integers of arbitrary precision, which
   are immediate values when small. *)

type runs = Z.t array

let twice k = Z.shift_left k 1
let half a = Z.shift_right a 1
let count (r : runs) = Array.length r / 2
let last (r : runs) = r.(Array.length r - 1)
let point_run k : runs = [| twice k; Z.succ (twice k) |]

(* [full p] is the run of the interval [(0, p]]. *)
let full p : runs = [| Z.one; Z.succ (twice p) |]

let is_full p (r : runs) =
  Array.length r = 2 && Z.equal r.(0) Z.one && Z.equal r.(1) (Z.succ (twice p))

(* [translate d r] is [r] shifted by [d] atoms. *)
let translate d (r : runs) =
  if Z.equal d Z.zero then r else Array.map (Z.add d) r

(* [fold_runs f acc r] folds [f] over the runs [[s, e)] of [r] in increasing
   order. *)
let fold_runs f acc (r : runs) =
  let rec go acc i =
    if i >= Array.length r then acc else go (f acc r.(i) r.(i + 1)) (i + 2)
  in
  go acc 0

let of_pairs pairs : runs =
  Array.of_list (List.concat_map (fun (s, e) -> [ s; e ]) pairs)

(* [search_from lo hi p] is the least [k] with [lo ≤ k < hi] and [p k], and
   [hi] if there is none, for a predicate [p] false and then true on
   [lo, …, hi - 1]: a binary search. *)
let search_from lo hi p =
  let rec go lo hi =
    if lo >= hi then lo
    else
      let mid = (lo + hi) / 2 in
      if p mid then go lo mid else go (mid + 1) hi
  in
  go lo hi

let search n p = search_from 0 n p

(* [gallop n p i] is [search_from i n p], found by an exponential search from
   [i] (Bentley and Yao, "An almost optimal algorithm for unbounded
   searching", Inform. Process. Lett. 5, 1976), in a time logarithmic in the
   distance to the result. *)
let gallop n p i =
  let rec expand lo step =
    let hi = lo + step in
    if hi >= n then search_from (lo + 1) n p
    else if p hi then search_from (lo + 1) hi p
    else expand hi (2 * step)
  in
  if i >= n || p i then i else expand i 1

(* [member r a] is whether the atom [a] lies in a run of [r]. *)
let member r a =
  let k = search (count r) (fun k -> Z.gt r.(2 * k) a) in
  k > 0 && Z.lt a r.((2 * k) - 1)

(* {2 Building arrays of runs}

   An array of runs is written into a fresh array long enough for it, the
   number of bounds written threaded through, and then cut to that number. *)

let fresh n : runs = Array.make n Z.zero

(* [emit out n s e] writes the run [[s, e)], whose lower bound is not below
   those of the runs written, after the first [n] bounds of [out], joined with
   the last run if the two meet or touch, and is the new number of bounds. *)
let emit out n s e =
  if n > 0 && Z.leq s out.(n - 1) then (
    if Z.gt e out.(n - 1) then out.(n - 1) <- e;
    n)
  else (
    out.(n) <- s;
    out.(n + 1) <- e;
    n + 2)

(* [write out n s e] writes the run [[s, e)], if non-empty, after the first [n]
   bounds of [out], above them and not touching them. *)
let write out n s e =
  if Z.lt s e then (
    out.(n) <- s;
    out.(n + 1) <- e;
    n + 2)
  else n

let finish out n = if n = Array.length out then out else Array.sub out 0 n

(* [coalesce r] joins the runs of [r], sorted by their lower bounds, that meet
   or touch. *)
let coalesce r =
  let out = fresh (Array.length r) in
  finish out (fold_runs (emit out) 0 r)

(* [append xs ys] is the union of [xs] and [ys], every run of [ys] beginning at
   or above the upper bound of the last run of [xs]. *)
let append xs ys =
  let n = Array.length xs and m = Array.length ys in
  if n = 0 then ys
  else if m = 0 then xs
  else if Z.equal ys.(0) xs.(n - 1) then
    Array.concat [ Array.sub xs 0 (n - 1); Array.sub ys 1 (m - 1) ]
  else Array.append xs ys

(* [clip lo hi r] is the intersection of [r] with the run [[lo, hi)], found by
   binary search; [r] itself if it lies within. *)
let clip lo hi r =
  let n = count r in
  let i = search n (fun k -> Z.gt r.((2 * k) + 1) lo)
  and j = search n (fun k -> Z.geq r.(2 * k) hi) in
  if i >= j then [||]
  else if i = 0 && j = n && Z.geq r.(0) lo && Z.leq (last r) hi then r
  else
    let out = Array.sub r (2 * i) (2 * (j - i)) in
    out.(0) <- Z.max out.(0) lo;
    out.(Array.length out - 1) <- Z.min (last out) hi;
    out

(* [blit_runs r i i' out k] copies the runs [i, …, i' - 1] of [r] after the
   first [k] bounds of [out], and is the new number of bounds. *)
let blit_runs (r : runs) i i' out k =
  if i' <= i then k
  else
    let n = 2 * (i' - i) in
    Array.blit r (2 * i) out k n;
    k + n

(* [ends_below r a b] is whether the run [a] of [r] ends below [b]. *)
let ends_below (r : runs) a b = Z.lt r.((2 * a) + 1) b

(* [clear_of r i nr other j no out k] is the index past the successors of the
   run [i] of [r], the last written of the [k] bounds of [out], that neither
   meet the output nor touch the run [j] of [other], of which there are
   [no]. *)
let clear_of r i nr other j no out k =
  let free a = j >= no || ends_below r a other.(2 * j) in
  if i + 1 < nr && free (i + 1) && Z.gt r.(2 * (i + 1)) out.(k - 1) then
    gallop nr (fun a -> not (free a)) (i + 2)
  else i + 1

(* The union by a merge sweep over both arrays, adaptive: when a run is taken
   from the same array as the one before, the runs following it that begin
   above the output and end below the next run of the other array are found
   by an exponential search and copied at once. *)
let union_runs xs ys =
  let n = Array.length xs and m = Array.length ys in
  if n = 0 then ys
  else if m = 0 then xs
  else
    let out = fresh (n + m) and nx = n / 2 and ny = m / 2 in
    let rec go i j k from_x =
      if i < nx && (j >= ny || Z.leq xs.(2 * i) ys.(2 * j)) then
        let k = emit out k xs.(2 * i) xs.((2 * i) + 1) in
        if from_x then
          let i' = clear_of xs i nx ys j ny out k in
          go i' j (blit_runs xs (i + 1) i' out k) true
        else go (i + 1) j k true
      else if j < ny then
        let k = emit out k ys.(2 * j) ys.((2 * j) + 1) in
        if from_x then go i (j + 1) k false
        else
          let j' = clear_of ys j ny xs i nx out k in
          go i j' (blit_runs ys (j + 1) j' out k) false
      else k
    in
    finish out (go 0 0 0 false)

(* [within_run r i nr e] is the index past the successors of the run [i] of
   [r] that end at most at [e]. *)
let within_run r i nr e =
  if
    i + 1 < nr && not (ends_below r (i + 1) e || Z.equal r.((2 * (i + 1)) + 1) e)
  then i + 1
  else gallop nr (fun a -> Z.gt r.((2 * a) + 1) e) (i + 1)

(* [skip r i nr x] is the index of the first run of [r] from [i] ending above
   [x]. *)
let skip r i nr x =
  if i >= nr || Z.gt r.((2 * i) + 1) x then i
  else gallop nr (fun a -> Z.gt r.((2 * a) + 1) x) (i + 1)

(* The intersection by a sweep over both arrays: the meet of two runs, then
   the one ending first left behind; adaptive, the runs of one array lying
   before the current run of the other skipped, and those lying within it
   copied at once, both found by an exponential search. *)
let inter_runs xs ys =
  let nx = count xs and ny = count ys in
  let out = fresh (Array.length xs + Array.length ys) in
  let rec go i j k =
    if i >= nx || j >= ny then k
    else
      let a = xs.(2 * i)
      and b = xs.((2 * i) + 1)
      and c = ys.(2 * j)
      and d = ys.((2 * j) + 1) in
      if Z.leq b c then go (skip xs (i + 1) nx c) j k
      else if Z.leq d a then go i (skip ys (j + 1) ny a) k
      else if Z.leq b d then
        let k = write out k (Z.max a c) b in
        let i' = within_run xs i nx d in
        go i' j (blit_runs xs (i + 1) i' out k)
      else
        let k = write out k (Z.max a c) d in
        let j' = within_run ys j ny b in
        go i j' (blit_runs ys (j + 1) j' out k)
  in
  finish out (go 0 0 0)

(* [within lo hi r] is the complement of [r], an array within the run
   [[lo, hi)], relative to [[lo, hi)]: the gaps between its runs. *)
let within lo hi r =
  let n = Array.length r in
  let out = fresh (n + 2) in
  let rec go i s k =
    if i >= n then write out k s hi
    else go (i + 2) r.(i + 1) (write out k s r.(i))
  in
  finish out (go 0 lo 0)

(* [merge xs ys] merges two arrays of runs sorted by their lower bounds, the
   runs not joined. *)
let merge xs ys =
  let n = Array.length xs and m = Array.length ys in
  if n = 0 then ys
  else if m = 0 then xs
  else
    let out = fresh (n + m) in
    let copy (r : runs) i k =
      out.(k) <- r.(i);
      out.(k + 1) <- r.(i + 1)
    in
    let rec go i j k =
      if i < n && (j >= m || Z.leq xs.(i) ys.(j)) then (
        copy xs i k;
        go (i + 2) j (k + 2))
      else if j < m then (
        copy ys j k;
        go i (j + 2) (k + 2))
      else out
    in
    go 0 0 0

(* [merge_all arrays] merges the arrays sorted by their lower bounds in
   [arrays], by balanced pairwise merges. *)
let rec merge_all = function
  | [] -> [||]
  | [ xs ] -> xs
  | arrays ->
      let rec pairs acc = function
        | xs :: ys :: rest -> pairs (merge xs ys :: acc) rest
        | [ xs ] -> List.rev (xs :: acc)
        | [] -> List.rev acc
      in
      merge_all (pairs [] arrays)

(* The Minkowski sum: [⟨a, b⟩ + ⟨c, d⟩ = ⟨a + c, b + d⟩], an end closed iff
   both are, which for runs [[s, e)] and [[s', e')] is the run from
   [s + s' - 1] if [s] and [s'] are odd, and [s + s'] otherwise, to
   [e + e' - 1] if [e] or [e'] is odd, and [e + e'] otherwise. The translates
   of the longer array by each run of the shorter are sorted, since its lower
   bounds increase, and are merged. *)
let sum_runs xs ys =
  let xs, ys =
    if Array.length xs >= Array.length ys then (xs, ys) else (ys, xs)
  in
  let lower s s' =
    if Z.is_odd s && Z.is_odd s' then Z.pred (Z.add s s') else Z.add s s'
  and upper e e' =
    if Z.is_odd e || Z.is_odd e' then Z.pred (Z.add e e') else Z.add e e'
  in
  coalesce
    (merge_all
       (List.rev
          (fold_runs
             (fun acc s' e' ->
               Array.mapi
                 (fun i a -> if i land 1 = 0 then lower a s' else upper a e')
                 xs
               :: acc)
             [] ys)))

(* {1 Sets} *)

type t = {
  grid : Z.t;
  threshold : Z.t;
  period : Z.t;
  base : runs;
  tail : runs;
  hash : int Lazy.t;
}
(* [S = base ∪ ⋃ₙ (threshold + n·period + tail)] on the grid [1/grid], its
   threshold and period counted in steps of the grid: [base] within the atoms
   [[0, 2·threshold]], and [tail], relative to the atom [2·threshold], within
   [[1, 2·period]]. The grid of a canonical form is the least common
   denominator of its threshold, its period and the ends of its intervals, so
   that the representation of a set is unique; within an operation a set may
   be refined to a finer grid. [hash] is the hash of the canonical form,
   computed once, when first needed. *)

let rational g k =
  if Z.equal g Z.one then Rational.of_z k else Rational.make_z k g

(* [hash_runs g r] is the hash of the list of the intervals of [r] on the grid
   [1/g], each by its ends and their closures. *)
let hash_runs g r =
  let hash k = Rational.hash_fraction k g in
  fold_runs
    (fun h s e ->
      Grade.combine h
        (Grade.combine
           (Grade.combine (hash (half s)) (Bool.to_int (Z.is_even s)))
           (Grade.combine (hash (half e)) (Bool.to_int (Z.is_odd e)))))
    0 r

let form ~grid ~threshold ~period ~base ~tail =
  let hash =
    lazy
      (Grade.combine
         (Grade.combine
            (Rational.hash_fraction threshold grid)
            (Rational.hash_fraction period grid))
         (Grade.combine (hash_runs grid base) (hash_runs grid tail)))
  in
  { grid; threshold; period; base; tail; hash }

(* [coarsest ~grid ~threshold ~period ~base ~tail] is the set on the coarsest
   grid its bounds lie on, [1/(grid/d)] for [d] the greatest common divisor of
   [grid], [threshold], [period] and the values of the bounds, computed until it
   is [1]. *)
let coarsest ~grid ~threshold ~period ~base ~tail =
  let rec divisor d r i =
    if Z.equal d Z.one || i >= Array.length r then d
    else divisor (Z.gcd d (half r.(i))) r (i + 1)
  in
  let d =
    divisor (divisor (Z.gcd grid (Z.gcd threshold period)) base 0) tail 0
  in
  if Z.equal d Z.one then form ~grid ~threshold ~period ~base ~tail
  else
    let coarse a =
      let k = twice (Z.divexact (half a) d) in
      if Z.is_odd a then Z.succ k else k
    in
    form ~grid:(Z.divexact grid d) ~threshold:(Z.divexact threshold d)
      ~period:(Z.divexact period d) ~base:(Array.map coarse base)
      ~tail:(Array.map coarse tail)

(* [refine g s] is [s] on the grid [1/g], [g] a multiple of its grid [h]: the
   point [k/h] is the point [km/g] and the cell after it the atoms up to the
   point [(k + 1)m/g], [m = g/h], so that a bound [a] becomes [ma] if even and
   [m(a - 1) + 1] if odd. *)
let refine_bound m a =
  if Z.equal m Z.one then a
  else if Z.is_odd a then Z.succ (Z.mul m (Z.pred a))
  else Z.mul m a

let refine g s =
  if Z.equal g s.grid then s
  else
    let m = Z.divexact g s.grid in
    {
      s with
      grid = g;
      threshold = Z.mul m s.threshold;
      period = Z.mul m s.period;
      base = Array.map (refine_bound m) s.base;
      tail = Array.map (refine_bound m) s.tail;
    }

let common_grid s r =
  if Z.equal s.grid r.grid then s.grid else Z.lcm s.grid r.grid

(* [copies ~origin ~step ~from tail ~lo ~hi] is the union of the copies
   [origin + n·step + tail], [n ≥ from] an integer, intersected with the run
   [[lo, hi)]: that of a full tail is the run from [origin + from·step + 1]. *)
let copies ~origin ~step ~from tail ~lo ~hi =
  if Array.length tail = 0 then [||]
  else if is_full (half step) tail then
    let s = Z.max lo (Z.succ (Z.add origin (Z.mul from step))) in
    if Z.lt s hi then [| s; hi |] else [||]
  else
    (* The copies from the one before that containing [lo], to the last one
       beginning below [hi], [origin + n·step + 1 < hi]. *)
    let first = Z.max from (Z.pred (Z.fdiv (Z.sub lo origin) step)) in
    let n =
      Int.max 0
        (Z.to_int (Z.sub (Z.cdiv (Z.sub (Z.pred hi) origin) step) first))
    in
    let out = fresh (n * Array.length tail) in
    let rec go o c i k =
      if c >= n then k
      else if i >= Array.length tail then go (Z.add o step) (c + 1) 0 k
      else
        let s = Z.max lo (Z.add o tail.(i))
        and e = Z.min hi (Z.add o tail.(i + 1)) in
        go o c (i + 2) (if Z.lt s e then emit out k s e else k)
    in
    finish out (go (Z.add origin (Z.mul first step)) 0 0 0)

(* [window s ~lo ~hi] is [s ∩ [lo, hi)]. *)
let window s ~lo ~hi =
  let origin = twice s.threshold in
  append
    (if Z.gt lo origin then [||] else clip lo hi s.base)
    (copies ~origin ~step:(twice s.period) ~from:Z.zero s.tail ~lo ~hi)

(* [border equal k] is the length of the longest proper border of the word of
   the letters [0, …, k - 1], [k > 0], compared by [equal]: its longest proper
   prefix that is also a suffix, by the failure function of Knuth, Morris and
   Pratt ("Fast pattern matching in strings", SIAM J. Comput. 6, 1977), entry
   [i] of which is the longest proper border of the prefix of length
   [i + 1]. *)
let border equal k =
  let f = Array.make k 0 in
  let rec extend b i =
    if equal i b then b + 1 else if b = 0 then 0 else extend f.(b - 1) i
  in
  for i = 1 to k - 1 do
    f.(i) <- extend f.(i - 1) i
  done;
  f.(k - 1)

(* [least_period p tail] is the least period of the periodic extension of the
   tail [tail] of period [p], neither empty nor full. Its [k] components on the
   circle of [2p] atoms, the last and the first joined if they meet across [p],
   each read as the parity of its lower bound, its length and the gap to the
   next, form a circular word whose rotations are the translations leaving the
   tail invariant: the least period is [p·m/k], [m] the length of the
   primitive root of the word, which is [k - f] if that divides [k] and [k]
   otherwise, [f] the length of its longest proper border. *)
let least_period p tail =
  let n = count tail and wrap = twice p in
  let joined =
    n >= 2 && Z.equal tail.(0) Z.one && Z.equal (last tail) (Z.succ wrap)
  in
  let k = if joined then n - 1 else n and first = if joined then 1 else 0 in
  let lo i = tail.(2 * (first + i)) in
  let hi i =
    if joined && i = k - 1 then Z.add wrap tail.(1)
    else tail.((2 * (first + i)) + 1)
  in
  let next i = if i = k - 1 then Z.add wrap (lo 0) else lo (i + 1) in
  let odd = Array.init k (fun i -> Z.is_odd (lo i))
  and length = Array.init k (fun i -> Z.sub (hi i) (lo i))
  and gap = Array.init k (fun i -> Z.sub (next i) (hi i)) in
  let equal i j =
    Bool.equal odd.(i) odd.(j)
    && Z.equal length.(i) length.(j)
    && Z.equal gap.(i) gap.(j)
  in
  let m = k - border equal k in
  Z.divexact p (Z.of_int (if k mod m = 0 then k / m else 1))

(* [least_threshold t p base tail] is the least threshold of the set [S] of
   threshold [t], least period [p], base [base] and tail [tail]: the supremum
   of the points [x ∈ [0, t]] with [x ∈ S ⇎ x + p ∈ S], [0] if there are none.
   The runs of [S ∩ [0, t]] and of [(S - p) ∩ [0, t]] are compared downwards
   from [t], and the supremum is that of the highest atom in one and not the
   other, read off the first two runs that differ. *)
let least_threshold t p base tail =
  let step = twice p and o = twice t in
  let nb = count base and nt = count tail in
  (* The runs of [S ∩ [0, t + p]]: those of the base, then those of the tail
     from [t], the last of the one and the first of the other joined if they
     touch. *)
  let joined =
    nb > 0 && Z.equal (last base) (Z.succ o) && Z.equal tail.(0) Z.one
  in
  let na = nb + nt - if joined then 1 else 0 in
  let first_tail = na - nt in
  let lower j =
    if j < nb then base.(2 * j) else Z.add o tail.(2 * (j - first_tail))
  and upper j =
    if j < first_tail then base.((2 * j) + 1)
    else Z.add o tail.((2 * (j - first_tail)) + 1)
  in
  let rec down i j =
    let x = i >= 0 and y = j >= 0 && Z.gt (upper j) step in
    if not (x || y) then Z.zero
    else if not y then half base.((2 * i) + 1)
    else
      let e' = Z.sub (upper j) step in
      if not x then half e'
      else
        let e = base.((2 * i) + 1) in
        if not (Z.equal e e') then half (Z.max e e')
        else
          let s = base.(2 * i) and s' = Z.max Z.zero (Z.sub (lower j) step) in
          if not (Z.equal s s') then half (Z.max s s') else down (i - 1) (j - 1)
  in
  down (nb - 1) (na - 1)

(* [make ~grid ~threshold ~period ~base ~tail] is the canonical form of the set
   [base ∪ ⋃ₙ (threshold + n·period + tail)] on the grid [1/grid], [base] an
   array within [[0, threshold]] and [tail] one within [(0, period]]. *)
let make ~grid ~threshold ~period ~base ~tail =
  if Array.length tail = 0 then
    coarsest ~grid
      ~threshold:(if Array.length base = 0 then Z.zero else half (last base))
      ~period:grid ~base ~tail
  else if is_full period tail then
    (* The least threshold is the supremum of [[0, threshold] ∖ base]: the
       lower end of the last interval of [base] if that contains [threshold],
       and [threshold] otherwise. *)
    let n = Array.length base in
    if n > 0 && Z.equal (last base) (Z.succ (twice threshold)) then
      let s = base.(n - 2) in
      coarsest ~grid ~threshold:(half s) ~period:grid
        ~base:
          (Array.append
             (Array.sub base 0 (n - 2))
             (if Z.is_even s then [| s; Z.succ s |] else [||]))
        ~tail:(full grid)
    else coarsest ~grid ~threshold ~period:grid ~base ~tail:(full grid)
  else
    let p = least_period period tail in
    let pattern =
      if Z.equal p period then tail else clip Z.one (Z.succ (twice p)) tail
    in
    let t = least_threshold threshold p base pattern in
    if Z.equal t threshold then
      coarsest ~grid ~threshold ~period:p ~base ~tail:pattern
    else
      let o = twice t and origin = twice threshold and step = twice p in
      coarsest ~grid ~threshold:t ~period:p
        ~base:(clip Z.zero (Z.succ o) base)
        ~tail:
          (translate (Z.neg o)
             (copies ~origin ~step
                ~from:(Z.pred (Z.fdiv (Z.sub o origin) step))
                pattern ~lo:(Z.succ o)
                ~hi:(Z.succ (Z.add o step))))

let empty =
  form ~grid:Z.one ~threshold:Z.zero ~period:Z.one ~base:[||] ~tail:[||]

let zero =
  form ~grid:Z.one ~threshold:Z.zero ~period:Z.one ~base:(point_run Z.zero)
    ~tail:[||]

let all =
  form ~grid:Z.one ~threshold:Z.zero ~period:Z.one ~base:(point_run Z.zero)
    ~tail:(full Z.one)

let positive =
  form ~grid:Z.one ~threshold:Z.zero ~period:Z.one ~base:[||] ~tail:(full Z.one)

(* [of_runs grid runs] is the bounded set of the array [runs] on the grid
   [1/grid]. *)
let of_runs grid runs =
  make ~grid ~threshold:Z.zero ~period:grid ~base:runs ~tail:[||]

(* [from ~grid lo lo_closed] is the unbounded interval from [lo/grid]. *)
let from ~grid lo lo_closed =
  make ~grid ~threshold:lo ~period:grid
    ~base:(if lo_closed then point_run lo else [||])
    ~tail:(full grid)

(* {2 Intervals of rationals} *)

type interval = {
  lo : Rational.t;
  lo_closed : bool;
  hi : Rational.t;
  hi_closed : bool;
}

(* [units g q] is [q·g], for [q] of denominator dividing [g]. *)
let units g q = Z.mul (Rational.num q) (Z.divexact g (Rational.den q))

(* [atom g x] is the atom of the grid [1/g] containing [x ≥ 0]. *)
let atom g x =
  let y = Rational.mul x (Rational.of_z g) in
  let k = twice (floor y) in
  if Rational.is_integer y then k else Z.succ k

let interval_of g s e =
  {
    lo = rational g (half s);
    lo_closed = Z.is_even s;
    hi = rational g (half e);
    hi_closed = Z.is_odd e;
  }

let intervals_of g r =
  List.rev (fold_runs (fun acc s e -> interval_of g s e :: acc) [] r)

(* [of_intervals ivs] is the bounded set of the intervals [ivs], on the grid of
   the least common denominator of their ends. *)
let of_intervals ivs =
  let g =
    List.fold_left
      (fun g i -> Z.lcm g (Z.lcm (Rational.den i.lo) (Rational.den i.hi)))
      Z.one ivs
  in
  let run i =
    let s = twice (units g i.lo) and e = twice (units g i.hi) in
    ((if i.lo_closed then s else Z.succ s), if i.hi_closed then Z.succ e else e)
  in
  of_runs g
    (coalesce
       (of_pairs
          (List.stable_sort
             (fun (s, _) (s', _) -> Z.compare s s')
             (List.filter (fun (s, e) -> Z.lt s e) (List.map run ivs)))))

let point q =
  if Rational.sign q < 0 then invalid_arg "DelaySet.point"
  else of_intervals [ { lo = q; lo_closed = true; hi = q; hi_closed = true } ]

let interval ~lo ~lo_closed ~hi ~hi_closed =
  let lo, lo_closed =
    if Rational.sign lo < 0 then (rzero, true) else (lo, lo_closed)
  in
  match hi with
  | Some hi -> of_intervals [ { lo; lo_closed; hi; hi_closed } ]
  | None ->
      let g = Rational.den lo in
      from ~grid:g (units g lo) lo_closed

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

let constant s = Array.length s.tail = 0 || is_full s.period s.tail

(* [align s t p] is the base and the tail of the representation of [s] with
   threshold [t ≥ s.threshold] and period [p], a multiple of [s.period] unless
   the tail of [s] is empty or full, on the grid of [s]: those of [s] if [t]
   and [p] are its own. *)
let align s t p =
  if Z.equal t s.threshold && Z.equal p s.period then (s.base, s.tail)
  else
    let o = twice t in
    ( window s ~lo:Z.zero ~hi:(Z.succ o),
      if Array.length s.tail = 0 then [||]
      else if constant s then full p
      else
        translate (Z.neg o)
          (window s ~lo:(Z.succ o) ~hi:(Z.succ (Z.add o (twice p)))) )

(* [common_period s r] is a period both [s] and [r], on a common grid, may be
   aligned to. *)
let common_period s r =
  match (constant s, constant r) with
  | true, true -> s.grid
  | true, false -> r.period
  | false, true -> s.period
  | false, false -> Z.lcm s.period r.period

(* The order of two bounds on the grids [1/g] and [1/h]: by the values of
   their ends, then an even bound first. *)
let compare_bounds g h a b =
  match cmp (rational g (half a)) (rational h (half b)) with
  | 0 -> Bool.compare (Z.is_odd a) (Z.is_odd b)
  | c -> c

(* The lexicographic order of arrays, a proper prefix first. *)
let compare_runs compare_bound xs ys =
  let n = Array.length xs and m = Array.length ys in
  let rec go i =
    if i >= n || i >= m then Int.compare n m
    else match compare_bound xs.(i) ys.(i) with 0 -> go (i + 1) | c -> c
  in
  go 0

let compare s r =
  if s == r then 0
  else
    let same = Z.equal s.grid r.grid in
    let value a b =
      if same then Z.compare a b
      else cmp (rational s.grid a) (rational r.grid b)
    and bound = if same then Z.compare else compare_bounds s.grid r.grid in
    match value s.threshold r.threshold with
    | 0 -> (
        match value s.period r.period with
        | 0 -> (
            match compare_runs bound s.base r.base with
            | 0 -> compare_runs bound s.tail r.tail
            | c -> c)
        | c -> c)
    | c -> c

let equal_runs xs ys =
  Array.length xs = Array.length ys
  &&
  let rec go i = i < 0 || (Z.equal xs.(i) ys.(i) && go (i - 1)) in
  go (Array.length xs - 1)

let equal s r =
  s == r
  || Z.equal s.grid r.grid
     && Z.equal s.threshold r.threshold
     && Z.equal s.period r.period && equal_runs s.base r.base
     && equal_runs s.tail r.tail

let hash s = Lazy.force s.hash

(* [binary op s r] applies [op] to the bases and to the tails of [s] and [r]
   aligned to a common grid, the greater threshold and a common period. *)
let binary op s r =
  let g = common_grid s r in
  let s = refine g s and r = refine g r in
  let t = Z.max s.threshold r.threshold and p = common_period s r in
  let base, tail = align s t p and base', tail' = align r t p in
  make ~grid:g ~threshold:t ~period:p ~base:(op base base')
    ~tail:(op tail tail')

let is_empty s = Array.length s.base = 0 && Array.length s.tail = 0

(* The operations below return an operand where the laws of the Boolean
   algebra and of the sum determine the result from it. *)

let union s r =
  if is_empty s || equal r all then r
  else if is_empty r || equal s all || equal s r then s
  else binary union_runs s r

(* [inter_bounded s r] is [s ∩ r] for a bounded [r], whose threshold is its
   supremum: [(s ∩ [0, sup r]) ∩ r], which reads [s] only up to [sup r]. *)
let inter_bounded s r =
  let g = common_grid s r in
  let s = refine g s and r = refine g r in
  of_runs g
    (inter_runs (window s ~lo:Z.zero ~hi:(Z.succ (twice r.threshold))) r.base)

let inter s r =
  if is_empty s || equal r all || equal s r then s
  else if is_empty r || equal s all then r
  else if Array.length r.tail = 0 then inter_bounded s r
  else if Array.length s.tail = 0 then inter_bounded r s
  else binary inter_runs s r

(* The complement of a canonical form is canonical: [x ∈ S ⇎ x + p ∈ S] holds
   of the same points for [S] and its complement, the tail of one is empty iff
   that of the other is full, and both have the same ends. *)
let compl s =
  form ~grid:s.grid ~threshold:s.threshold ~period:s.period
    ~base:(within Z.zero (Z.succ (twice s.threshold)) s.base)
    ~tail:(within Z.one (Z.succ (twice s.period)) s.tail)

(* A difference from a bounded set reads the other operand only up to its
   supremum. *)
let diff s r =
  if Array.length s.tail = 0 && not (is_empty s || is_empty r) then
    let g = common_grid s r in
    let s = refine g s and r = refine g r in
    let top = Z.succ (twice s.threshold) in
    of_runs g
      (inter_runs s.base (within Z.zero top (window r ~lo:Z.zero ~hi:top)))
  else inter s (compl r)

let threshold s = rational s.grid s.threshold
let period s = rational s.grid s.period

let intervals_upto x s =
  if Rational.sign x < 0 then []
  else
    let a = atom s.grid x in
    let r = window s ~lo:Z.zero ~hi:(Z.succ a) in
    let ivs = intervals_of s.grid r in
    (* An end [x] off the grid lies in the cell [a]. *)
    if Z.is_odd a && Array.length r > 0 && Z.equal (last r) (Z.succ a) then
      match List.rev ivs with
      | i :: rest ->
          List.rev_append rest [ { i with hi = x; hi_closed = true } ]
      | [] -> ivs
    else ivs

(* [piece m s i] is the [i]-th interval of [s] in increasing order, refined by
   [m]: those of its base, then the copies of its tail, one period after
   another, not joined where they touch; [None] past the last one of a bounded
   set. *)
let piece m s i =
  let nb = count s.base in
  if i < nb then
    Some (refine_bound m s.base.(2 * i), refine_bound m s.base.((2 * i) + 1))
  else
    let nt = count s.tail in
    if nt = 0 then None
    else
      let c = (i - nb) / nt and j = (i - nb) mod nt in
      let o =
        Z.mul m (twice (Z.add s.threshold (Z.mul (Z.of_int c) s.period)))
      in
      Some
        ( Z.add o (refine_bound m s.tail.(2 * j)),
          Z.add o (refine_bound m s.tail.((2 * j) + 1)) )

(* [intersects s r] sweeps the pieces of [s] and of [r] on a common grid in
   increasing order until two of them meet, or until one lies above the greater
   threshold plus a common period: both sets are periodic with that period
   above the greater threshold, so a common element above it has a translate
   below. *)
let intersects s r =
  let g = common_grid s r in
  let ms = Z.divexact g s.grid and mr = Z.divexact g r.grid in
  let p =
    match (constant s, constant r) with
    | true, true -> g
    | true, false -> Z.mul mr r.period
    | false, true -> Z.mul ms s.period
    | false, false -> Z.lcm (Z.mul ms s.period) (Z.mul mr r.period)
  in
  let limit =
    Z.succ
      (twice (Z.add (Z.max (Z.mul ms s.threshold) (Z.mul mr r.threshold)) p))
  in
  let rec sweep i j =
    match (piece ms s i, piece mr r j) with
    | None, _ | _, None -> false
    | Some (a, b), Some (c, d) ->
        Z.lt (Z.max a c) (Z.min b d)
        || Z.leq a limit && Z.leq c limit
           && if Z.leq b d then sweep (i + 1) j else sweep i (j + 1)
  in
  sweep 0 0

let subset s r = not (intersects s (compl r))

let mem x s =
  if Rational.sign x < 0 then false
  else
    let a = atom s.grid x and o = twice s.threshold in
    if Z.leq a o then member s.base a
    else member s.tail (Z.succ (Z.erem (Z.sub a (Z.succ o)) (twice s.period)))

(* {2 Repetition} *)

(* The sums and repetitions computed, recorded in module-level tables by their
   arguments: they are the costliest operations, and the gap closures of
   automata take them of the same sets repeatedly. The tables hold their
   arguments weakly, an entry lasting while its arguments are reachable. *)
module Key = struct
  type nonrec t = t

  let equal = equal
  let hash = hash
end

module Sets = Ephemeron.K1.Make (Key)
module Pairs = Ephemeron.K2.Make (Key) (Key)

(* [multiples_from s e] is, for the interval [⟨a, b⟩] of the run [[s, e)], the
   least [c = n₀a] such that the multiples [n⟨a, b⟩], [n ≥ n₀], cover
   [(c, ∞)]: [n₀] is the least [n ≥ 1] with [n(b - a) > a], or
   [n(b - a) ≥ a] if both ends are closed, so that [n⟨a, b⟩] and
   [(n+1)⟨a, b⟩] meet. *)
let multiples_from s e =
  let a = half s and w = Z.sub (half e) (half s) in
  let n =
    if Z.is_even s && Z.is_odd e && Z.equal (Z.rem a w) Z.zero then
      Z.max Z.one (Z.divexact a w)
    else Z.succ (Z.fdiv a w)
  in
  Z.mul n a

(* [star_dense s c] is [s* = R ∪ (c, ∞)], [R] the least fixpoint of
   [R = {0} ∪ (R + s_c) ∩ [0, c]] for [s_c = s ∩ (0, c]], all of whose elements
   are positive, by semi-naive iteration: each round adds to [R] the sums of the
   elements it added last with [s_c]. [R] is kept as a balanced search tree of
   its runs, so that a round costs a logarithmic time in [|R|] for each run of
   those sums. *)
let star_dense s c =
  let module R = Set.Make (struct
    type t = Z.t * Z.t

    let compare (a, _) (b, _) = Z.compare a b
  end) in
  let top = Z.succ (twice c) in
  let sc = window s ~lo:Z.one ~hi:top in
  (* The runs of [r] that meet or touch the run [[a, b)]: the last one
     beginning below [a] if it reaches [a], and those beginning from [a] up to
     [b]. *)
  let near r a b =
    let below =
      match R.find_last_opt (fun (a', _) -> Z.lt a' a) r with
      | Some ((_, b') as k) when Z.geq b' a -> [ k ]
      | _ -> []
    in
    below
    @ List.of_seq
        (Seq.take_while (fun (a', _) -> Z.leq a' b) (R.to_seq_from (a, a) r))
  in
  (* [add (r, fresh) a b] adds to [r] the part of [[a, b)] outside it, and its
     runs to the reversed list [fresh]. *)
  let add (r, fresh) a b =
    let ks = near r a b in
    let covered = of_pairs ks in
    match within a b (clip a b covered) with
    | [||] -> (r, fresh)
    | gaps ->
        ( fold_runs
            (fun r s e -> R.add (s, e) r)
            (List.fold_left (fun r k -> R.remove k r) r ks)
            (union_runs covered gaps),
          fold_runs (fun fresh s e -> (s, e) :: fresh) fresh gaps )
  in
  let rec go r delta =
    match fold_runs add (r, []) (clip Z.zero top (sum_runs delta sc)) with
    | r, [] -> r
    | r, fresh -> go r (of_pairs (List.rev fresh))
  in
  let z = point_run Z.zero in
  union
    (of_runs s.grid (of_pairs (R.elements (go (R.singleton (z.(0), z.(1))) z))))
    (from ~grid:s.grid c false)

(* [star_discrete s] is [s*] for a set [s] of positive points [F ∪ (G + pℕ)] on
   the grid [1/D]: scaled by [D], its multiples form the numerical semigroup
   [A] generated by [DF ∪ (DG + Dpℕ)]. With [μ = D·min s ∈ A], [x ∈ A] iff
   [x ≥ w(x mod μ)], [w(r)] the least element of [A] congruent to [r], the
   Apéry set, which is the shortest-path distance from [0] over the residues
   modulo [μ], each residue class of generators contributing an edge weighted
   by its least generator (Nijenhuis, "A minimal-path algorithm for the money
   changing problem", Amer. Math. Monthly 86, 1979), by Dijkstra's algorithm.
   The least generator of a class is among [DF] and [Dg + jDp] for
   [j < μ / gcd(μ, Dp)]. *)
let star_discrete s =
  let scale a = Z.to_int (half a) and t = Z.to_int s.threshold in
  let points = List.rev (fold_runs (fun acc a _ -> scale a :: acc) [] s.base)
  and families =
    List.rev (fold_runs (fun acc a _ -> (t + scale a) :: acc) [] s.tail)
  in
  let mu = List.fold_left min max_int (points @ families) in
  let dp = Z.to_int s.period in
  let span = mu / Z.to_int (Z.gcd (Z.of_int mu) (Z.of_int dp)) in
  let generators =
    points
    @ List.concat_map (fun g -> List.init span (fun j -> g + (j * dp))) families
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
  (* The Apéry set indexed by residues, [max_int] for the residues outside
     the group generated. *)
  let apery =
    Array.init mu (fun r ->
        Option.value (IntMap.find_opt r dist) ~default:max_int)
  in
  let member x = apery.(x mod mu) <= x in
  (* [points_among ~origin lo hi] is the array of the runs of the points
     [x - origin] for the elements [x] of [A] with [lo ≤ x ≤ hi]. *)
  let points_among ~origin lo hi =
    let rec size x n =
      if x > hi then n else size (x + 1) (if member x then n + 1 else n)
    in
    let out = fresh (2 * size lo 0) in
    let rec fill x k =
      if x > hi then out
      else if member x then (
        let a = twice (Z.of_int (x - origin)) in
        out.(k) <- a;
        out.(k + 1) <- Z.succ a;
        fill (x + 1) (k + 2))
      else fill (x + 1) k
    in
    fill lo 0
  in
  make ~grid:s.grid ~threshold:(Z.of_int w) ~period:(Z.of_int mu)
    ~base:(points_among ~origin:0 0 w)
    ~tail:(points_among ~origin:w (w + 1) (w + mu))

let repetition s =
  let s = diff s zero in
  let components = Array.append s.base (translate (twice s.threshold) s.tail) in
  if Array.length components = 0 then zero
  else if Z.equal (half components.(0)) Z.zero then all
  else
    let least =
      fold_runs
        (fun c a b ->
          if Z.lt (half a) (half b) then
            let c' = multiples_from a b in
            match c with Some c when Z.leq c c' -> Some c | _ -> Some c'
          else c)
        None components
    in
    match least with None -> star_discrete s | Some c -> star_dense s c

let star =
  let table = Sets.create 16 in
  fun s ->
    match Sets.find_opt table s with
    | Some r -> r
    | None ->
        let r = repetition s in
        Sets.replace table s r;
        r

(* {2 Sums} *)

(* [plus_multiples g xs p] is the set [X + pℕ] for the non-empty array [X] on
   the grid [1/g]: eventually full from the least lower end [a] of an interval
   [⟨a, b⟩] of [X] whose consecutive translates meet, and otherwise of threshold
   [sup X] and period [p], since for [x ≥ sup X], [x + p ∈ X + pℕ] iff
   [x ∈ X + pℕ]. *)
let plus_multiples g xs p =
  let step = twice p in
  let unroll limit =
    (* The translates [X + np] with [inf X + np ≤ limit]. *)
    let low = half xs.(0) in
    let n =
      if Z.lt limit low then 0
      else Z.to_int (Z.succ (Z.fdiv (Z.sub limit low) p))
    in
    coalesce
      (merge_all
         (List.init n (fun k -> translate (Z.mul (Z.of_int k) step) xs)))
  in
  match
    List.find_opt
      (fun k -> Z.leq (Z.add xs.(2 * k) step) xs.((2 * k) + 1))
      (List.init (count xs) Fun.id)
  with
  | Some k ->
      let s = xs.(2 * k) in
      let lo = half s in
      union
        (of_runs g (clip Z.zero (Z.succ (twice lo)) (unroll lo)))
        (from ~grid:g lo (Z.is_even s))
  | None ->
      let t = half (last xs) in
      let ivs = unroll (Z.add t p) and o = twice t in
      make ~grid:g ~threshold:t ~period:p
        ~base:(clip Z.zero (Z.succ o) ivs)
        ~tail:
          (translate (Z.neg o) (clip (Z.succ o) (Z.succ (Z.add o step)) ivs))

(* [progression s] is [Some p] if [s] is [pℕ], of canonical form
   [(0, p, {0}, {p})], and [None] otherwise. *)
let progression s =
  let p = twice s.period in
  match (s.base, s.tail) with
  | [| _; _ |], [| a; b |]
    when Z.equal s.threshold Z.zero && Z.equal a p && Z.equal b (Z.succ p) ->
      Some (rational s.grid s.period)
  | _ -> None

(* The sum of two progressions is the numerical semigroup
   [pℕ + qℕ = {p, q}*], by its Apéry set. Otherwise the sum distributes over
   union, and [pℕ + pℕ = pℕ]: with [S = B ∪ (Q + pℕ)] and [S' = B' ∪ (Q' + pℕ)],
   [S + S' = (B + B') ∪ (B + Q' + pℕ) ∪ (Q + B' + pℕ) ∪ (Q + Q' + pℕ)], on a
   common grid. *)
let minkowski s r =
  if is_empty s || is_empty r then empty
  else if equal s zero then r
  else if equal r zero then s
  else
    match (progression s, progression r) with
    | Some p, Some q -> star (union (point p) (point q))
    | _ ->
        let g = common_grid s r in
        let s = refine g s and r = refine g r in
        let p = common_period s r in
        let base, tail = align s s.threshold p
        and base', tail' = align r r.threshold p in
        let q = translate (twice s.threshold) tail
        and q' = translate (twice r.threshold) tail' in
        let periodic xs =
          if Array.length xs = 0 then empty else plus_multiples g xs p
        in
        List.fold_left union
          (of_runs g (sum_runs base base'))
          [
            periodic (sum_runs base q');
            periodic (sum_runs q base');
            periodic (sum_runs q q');
          ]

let sum =
  let table = Pairs.create 64 in
  fun s r ->
    match Pairs.find_opt table (s, r) with
    | Some u -> u
    | None ->
        let u = minkowski s r in
        Pairs.replace table (s, r) u;
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

(* [components s] is the number of the intervals of [s] below its threshold
   and in its first period above it, and [component s i] the run of the [i]-th
   of them in increasing order. *)
let components s = count s.base + count s.tail

let component s i =
  let nb = count s.base in
  if i < nb then (s.base.(2 * i), s.base.((2 * i) + 1))
  else
    let o = twice s.threshold and j = i - nb in
    (Z.add o s.tail.(2 * j), Z.add o s.tail.((2 * j) + 1))

let inf s =
  if components s = 0 then None
  else
    let a, _ = component s 0 in
    Some (Finite (rational s.grid (half a), Z.is_even a))

let sup s =
  if Array.length s.tail > 0 then Some Infinite
  else if Array.length s.base = 0 then None
  else
    let e = last s.base in
    Some (Finite (rational s.grid (half e), Z.is_odd e))

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
   least integer of the first component having one is the simplest element,
   the least integer [n] with [2ng ≥ s] for a run [[s, e)] if [2ng < e]. *)
let choose s =
  let n = components s and step = twice s.grid in
  let rec first i =
    if i >= n then None
    else
      let a, e = component s i in
      let k = Z.cdiv a step in
      if Z.lt (Z.mul k step) e then Some (of_z k) else first (i + 1)
  in
  match first 0 with
  | Some x -> Some x
  | None ->
      let simpler x y =
        match Z.compare (Rational.den x) (Rational.den y) with
        | 0 -> lt x y
        | c -> c < 0
      in
      let rec best acc i =
        if i >= n then acc
        else
          let a, e = component s i in
          let i' = interval_of s.grid a e in
          let x = simplest i'.lo i'.lo_closed (Some (i'.hi, i'.hi_closed)) in
          best
            (match acc with
            | Some b when not (simpler x b) -> acc
            | _ -> Some x)
            (i + 1)
      in
      best None 0

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
  let bounded g r =
    List.map
      (fun i -> interval_regex (i.lo, i.lo_closed, Some (i.hi, i.hi_closed)))
      (intervals_of g r)
  in
  let g = s.grid and o = twice s.threshold in
  let parts =
    if Array.length s.tail = 0 then bounded g s.base
    else if is_full s.period s.tail then
      let ivs =
        intervals_of g
          (append s.base [| Z.succ o; Z.succ (Z.add o (twice g)) |])
      in
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
      let base = s.base and step = twice s.period in
      let contained a e =
        (* The run of the base containing [[a, e)], if any, is the last one
           whose lower bound is not above [a]. *)
        let k = search (count base) (fun k -> Z.gt base.(2 * k) a) in
        k > 0 && Z.leq e base.((2 * k) - 1)
      in
      let rec lower q =
        let q' = translate (Z.neg step) q in
        if
          Z.sign q'.(0) >= 0
          && fold_runs (fun inside a e -> inside && contained a e) true q'
        then lower q'
        else q
      in
      let q = lower (translate o s.tail) in
      let rest = diff (of_runs g base) (plus_multiples g q s.period) in
      let multiples =
        GradeLiteral.Star (GradeLiteral.rational_tick (period s))
      in
      bounded rest.grid rest.base
      @ [
          (match q with
          | [| _; e |] when Z.equal (half e) Z.zero -> multiples
          | _ -> Seq (Option.get (union_regex (bounded g q)), multiples));
        ]
  in
  Option.value (union_regex parts) ~default:(GradeLiteral.Compl (Star Any))

let show s = GradeLiteral.show_regex (to_regex s)
