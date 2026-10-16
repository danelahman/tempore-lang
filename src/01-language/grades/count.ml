type t = { least : int; most : int option }

let make least most =
  if least < 0 then invalid_arg "Count.make: a negative count"
  else
    match most with
    | Some n when n < least -> invalid_arg "Count.make: an empty interval"
    | _ -> { least; most }

let point n = make n (Some n)
let unbounded = { least = 0; most = None }

let mem k c =
  c.least <= k && match c.most with Some n -> k <= n | None -> true

let is_point n c = c.least = n && c.most = Some n

(* The sum of two optional ends, [None] being infinite. *)
let both f a b = match (a, b) with Some a, Some b -> Some (f a b) | _ -> None
let add c c' = { least = c.least + c'.least; most = both ( + ) c.most c'.most }

let shift c j =
  match c.most with
  | Some n when n < j -> None
  | most ->
      Some
        { least = max 0 (c.least - j); most = Option.map (fun n -> n - j) most }

let below c = { c with least = 0 }
let hull c c' = { least = min c.least c'.least; most = both max c.most c'.most }

(* [reaches c k] is whether [c] reaches [k], [k] included. *)
let reaches c k = match c.most with Some n -> k <= n | None -> true

let union c c' =
  let lo, hi = if c.least <= c'.least then (c, c') else (c', c) in
  if reaches lo (hi.least - 1) then Some (hull c c') else None

let nest c c' =
  let times k = function Some n -> Some (k * n) | None -> None in
  match c'.most with
  | Some k when k = c'.least ->
      Some
        {
          least = k * c.least;
          most = (if k = 0 then Some 0 else times k c.most);
        }
  | most' ->
      (* The sums of [k] and [k + 1] numbers of [c] touch iff
         [m - 1 ≤ k·(n - m)], hardest at the least [k]. *)
      let touching =
        match c.most with
        | Some n -> c.least - 1 <= c'.least * (n - c.least)
        | None -> c.least <= 1 || c'.least >= 1
      in
      if not touching then None
      else
        Some
          {
            least = c'.least * c.least;
            most =
              (match (c.most, most') with
              | Some 0, _ -> Some 0
              | Some n, Some k -> Some (k * n)
              | _ -> None);
          }

let subset c c' =
  c'.least <= c.least
  &&
  match (c.most, c'.most) with
  | _, None -> true
  | None, Some _ -> false
  | Some n, Some n' -> n <= n'

let compare c c' =
  match Int.compare c.least c'.least with
  | 0 -> Option.compare Int.compare c.most c'.most
  | d -> d

let equal c c' = compare c c' = 0

let hash c =
  Hashing.combine c.least
    (match c.most with None -> 0 | Some n -> Hashing.combine 1 n)

let show c =
  match c.most with
  | Some n when n = c.least -> string_of_int n
  | Some n -> Printf.sprintf "[%d, %d]" c.least n
  | None -> Printf.sprintf "[%d, ∞)" c.least
