type runs = Z.t array

let twice k = Z.shift_left k 1
let half a = Z.shift_right a 1
let count (r : runs) = Array.length r / 2
let last (r : runs) = r.(Array.length r - 1)
let point_run k : runs = [| twice k; Z.succ (twice k) |]
let full p : runs = [| Z.one; Z.succ (twice p) |]

let is_full p (r : runs) =
  Array.length r = 2 && Z.equal r.(0) Z.one && Z.equal r.(1) (Z.succ (twice p))

let translate d (r : runs) =
  if Z.equal d Z.zero then r else Array.map (Z.add d) r

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

let member r a =
  let k = search (count r) (fun k -> Z.gt r.(2 * k) a) in
  k > 0 && Z.lt a r.((2 * k) - 1)

(* {2 Building arrays of runs}

   An array of runs is written into a fresh array long enough for it, the
   number of bounds written threaded through, and then cut to that number. *)

let fresh n : runs =
  if n > Sys.max_array_length then Delay.out_of_range "delay set"
  else Array.make n Z.zero

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

let coalesce r =
  let out = fresh (Array.length r) in
  finish out (fold_runs (emit out) 0 r)

let append xs ys =
  let n = Array.length xs and m = Array.length ys in
  if n = 0 then ys
  else if m = 0 then xs
  else if Z.equal ys.(0) xs.(n - 1) then
    Array.concat [ Array.sub xs 0 (n - 1); Array.sub ys 1 (m - 1) ]
  else Array.append xs ys

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
