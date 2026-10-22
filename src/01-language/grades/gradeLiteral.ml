type 'a bound = Closed of 'a | Open of 'a | Unbounded

let show_interval show lo hi =
  (match lo with
    | Closed a -> "[" ^ show a
    | Open a -> "(" ^ show a
    | Unbounded -> "(-∞")
  ^ ", "
  ^
  match hi with
  | Closed b -> show b ^ "]"
  | Open b -> show b ^ ")"
  | Unbounded -> "∞)"

type regex =
  | Letter of string
  | Tick of int
  | Frac of Rational.t
  | Delays of Rational.t bound * Rational.t bound
  | Below of Rational.t bound
  | Above of Rational.t bound
  | Any
  | Seq of regex * regex
  | Union of regex * regex
  | Star of regex
  | Repeat of regex * Count.t
  | Inter of regex * regex
  | Compl of regex
  | Strict of regex

let rec delays_only = function
  | Tick _ | Frac _ | Delays _ | Below _ | Above _ -> true
  | Seq (r, s) | Union (r, s) | Inter (r, s) -> delays_only r && delays_only s
  | Star r | Repeat (r, _) -> delays_only r
  | Letter _ | Any | Compl _ | Strict _ -> false

(* [r^[m, n]] is [r; …; r; (0 | r; (0 | r; …))], [m] factors and [n - m]
   optional ones nested, and [r^[m, ∞)] is [r; …; r; r*]. *)
let unrolled r (c : Count.t) =
  let seq a b = match b with Tick 0 -> a | b -> Seq (a, b) in
  let rest =
    match c.most with
    | None -> Star r
    | Some n ->
        List.fold_left
          (fun acc _ -> Union (Tick 0, seq r acc))
          (Tick 0)
          (List.init (n - c.least) Fun.id)
  in
  List.fold_left (fun acc _ -> seq r acc) rest (List.init c.least Fun.id)

let rec equal_regex r s =
  match (r, s) with
  | Letter a, Letter b -> String.equal a b
  | Tick m, Tick n -> Int.equal m n
  | Frac p, Frac q -> Rational.equal p q
  | Delays (lo, hi), Delays (lo', hi') ->
      let equal_bound b b' =
        match (b, b') with
        | Closed p, Closed q | Open p, Open q -> Rational.equal p q
        | Unbounded, Unbounded -> true
        | _ -> false
      in
      equal_bound lo lo' && equal_bound hi hi'
  | Below b, Below b' | Above b, Above b' -> (
      match (b, b') with
      | Closed p, Closed q | Open p, Open q -> Rational.equal p q
      | Unbounded, Unbounded -> true
      | _ -> false)
  | Any, Any -> true
  | Seq (r, s), Seq (r', s')
  | Union (r, s), Union (r', s')
  | Inter (r, s), Inter (r', s') ->
      equal_regex r r' && equal_regex s s'
  | Star r, Star r' | Compl r, Compl r' | Strict r, Strict r' ->
      equal_regex r r'
  | Repeat (r, c), Repeat (r', c') -> equal_regex r r' && Count.equal c c'
  | _ -> false

(* A factor [x^c] has the base [x] and the count [c], any other factor [x]
   the base [x] and the count [1]; adjacent factors of equal bases are joined
   from the right. *)
let sequence factors =
  let power = function Repeat (x, c) -> (x, c) | x -> (x, Count.point 1) in
  let join r acc =
    match acc with
    | s :: rest ->
        let x, c = power r and y, c' = power s in
        if equal_regex x y then Repeat (x, Count.add c c') :: rest else r :: acc
    | [] -> [ r ]
  in
  match List.fold_right join factors [] with
  | [] -> Tick 0
  | r :: rs -> List.fold_left (fun r s -> Seq (r, s)) r rs

let regex_names r =
  let rec go = function
    | Letter name -> [ name ]
    | Tick _ | Frac _ | Delays _ | Below _ | Above _ | Any -> []
    | Seq (r, s) | Union (r, s) | Inter (r, s) -> go r @ go s
    | Star r | Repeat (r, _) | Compl r | Strict r -> go r
  in
  List.sort_uniq String.compare (go r)

let show_below = function
  | Closed d -> "≤" ^ Rational.show d
  | Open d -> "<" ^ Rational.show d
  | Unbounded -> "≤∞"

let show_above = function
  | Closed d -> "≥" ^ Rational.show d
  | Open d -> ">" ^ Rational.show d
  | Unbounded -> "≥∞"

let show_regex r =
  let buffer = Buffer.create 64 in
  let add = Buffer.add_string buffer in
  let wrap ctx prec print =
    if prec < ctx then (
      add "(";
      print ();
      add ")")
    else print ()
  in
  (* The operands of the chain [r] of an associative binary operator, read off
     by [split], nested on either side. *)
  let rec operands split r acc =
    match split r with
    | Some (l, x) -> operands split l (operands split x acc)
    | None -> r :: acc
  in
  let rec go ctx = function
    | Letter name -> add name
    | Tick n -> add (string_of_int n)
    | Frac q -> wrap ctx 4 (fun () -> add (Rational.show q))
    | Delays (lo, hi) -> add (show_interval Rational.show lo hi)
    | Below b -> add (show_below b)
    | Above b -> add (show_above b)
    | Any -> add "_"
    | Union _ as r ->
        chain ctx 0 " | " (function Union (l, x) -> Some (l, x) | _ -> None) r
    | Inter _ as r ->
        chain ctx 1 " & " (function Inter (l, x) -> Some (l, x) | _ -> None) r
    | Seq _ as r ->
        chain ctx 2 "; " (function Seq (l, x) -> Some (l, x) | _ -> None) r
    | Compl r ->
        wrap ctx 3 (fun () ->
            add "~";
            go 3 r)
    | Strict r ->
        add "idle ";
        go 4 r
    | Star r ->
        wrap ctx 4 (fun () ->
            operand r;
            add "*")
    | Repeat (r, c) ->
        wrap ctx 4 (fun () ->
            operand ~bounded:true r;
            add "^";
            add (Count.show c))
  (* The operand of a repetition, itself a repetition unparenthesised and a
     strict delay parenthesised under a bounded repetition, which [idle] does
     not enter. *)
  and operand ?(bounded = false) r =
    match r with
    | Star _ | Repeat _ -> go 4 r
    | Strict _ when bounded -> wrap 5 4 (fun () -> go 4 r)
    | r -> go 5 r
  and chain ctx prec separator split r =
    wrap ctx prec (fun () ->
        List.iteri
          (fun i x ->
            if i > 0 then add separator;
            go (if i = 0 then prec else prec + 1) x)
          (operands split r []))
  in
  go 0 r;
  Buffer.contents buffer

type lit =
  | Int of int
  | Rat of Rational.t
  | Name of string
  | Top
  | Inf
  | Tuple of lit list
  | Interval of lit bound * lit bound
  | Braces of regex

exception Invalid_literal of lit * string

let invalid_lit lit fmt =
  Printf.ksprintf (fun reason -> raise (Invalid_literal (lit, reason))) fmt

let read_lit of_lit lit =
  match of_lit lit with
  | v -> Ok v
  | exception Invalid_literal (lit', reason) -> Error (lit', reason)

let reads_lit of_lit lit = Result.is_ok (read_lit of_lit lit)
let require accepts lit = if not (accepts lit) then invalid_lit lit "rejected"

let component_of_lit lit ~context of_lit component =
  try of_lit component
  with Invalid_literal (_, reason) -> invalid_lit lit "%s%s" context reason

let distinct_entries lit ~compare ~twice entries =
  let sorted = List.sort (fun (k, _) (k', _) -> compare k k') entries in
  let rec check = function
    | (k, _) :: ((k', _) :: _ as rest) ->
        if compare k k' = 0 then invalid_lit lit "%s" (twice k) else check rest
    | [ _ ] | [] -> sorted
  in
  check sorted

let strict_unsupported r =
  invalid_lit (Braces r)
    "strict delays `%s` are read by the rigid grades of timed operations only, \
     `regex-timed-rigid-…` and `traces-timed-rigid-…`"
    (show_regex r)

let one_sided_unsupported r =
  invalid_lit (Braces r)
    "one-sided lengths `%s` are read by the rigid grades of timed operations \
     only, `regex-timed-rigid-…` and `traces-timed-rigid-…`"
    (show_regex r)

let rational_lit q =
  match Rational.to_int q with Some n -> Int n | None -> Rat q

let rational_tick q =
  match Rational.to_int q with Some n -> Tick n | None -> Frac q

let describe_lit = function
  | Int _ -> "plain integers"
  | Rat _ -> "fractions such as `3/2`"
  | Name name -> "names such as `" ^ name ^ "`"
  | Top -> "`⊤`"
  | Inf -> "`∞`"
  | Tuple [ _; _ ] -> "pairs"
  | Tuple _ -> "tuples"
  | Interval _ -> "intervals `[...]`"
  | Braces _ -> "brace literals `{...}`"

let interval_forms =
  "`[n, m]`, `(n, m)`, `[n, m)`, `(n, m]`, `[n, ∞)` or `(n, ∞)`"

(* [numeric lit] is the value of the numeric literal [lit]. *)
let numeric = function
  | Int n -> Some (Rational.of_int n)
  | Rat q -> Some q
  | _ -> None

let open_pair = function
  | Tuple [ ((Int _ | Rat _) as a); ((Int _ | Rat _) as b) ] ->
      Interval (Open a, Open b)
  | Tuple [ ((Int _ | Rat _) as a); Inf ] -> Interval (Open a, Unbounded)
  | lit -> lit

let emptiness lo hi =
  let value = function
    | Closed a -> Some (a, true)
    | Open a -> Some (a, false)
    | Unbounded -> None
  in
  match (value lo, value hi) with
  | Some (a, a_closed), Some (b, b_closed) ->
      let c = Rational.compare a b in
      if c > 0 then Some "interval endpoints must satisfy n <= m"
      else if c = 0 && not (a_closed && b_closed) then
        Some "interval endpoints must satisfy n < m at an open endpoint"
      else None
  | _ -> None

(* [check_nonempty ~number lit lo hi] rejects the interval literal [lit] with
   the endpoints [lo] and [hi] if their values by [number] denote an empty
   interval; endpoints without a value are not compared. *)
let check_nonempty ~number lit lo hi =
  let value = function
    | Closed a -> Option.map (fun q -> Closed q) (number a)
    | Open a -> Option.map (fun q -> Open q) (number a)
    | Unbounded -> Some Unbounded
  in
  match (value lo, value hi) with
  | Some lo, Some hi ->
      Option.iter (fun reason -> invalid_lit lit "%s" reason) (emptiness lo hi)
  | _ -> ()

let close_integer ~lower = function
  | Int n -> Int (if lower then n + 1 else n - 1)
  | lit -> lit

let integer_ends lit lo hi =
  check_nonempty ~number:numeric lit lo hi;
  let close ~lower = function
    | Open a -> Closed (close_integer ~lower a)
    | b -> b
  in
  let lo = close ~lower:true lo and hi = close ~lower:false hi in
  (match (lo, hi) with
  | Closed (Int n), Closed (Int m) when m < n ->
      invalid_lit lit "the interval contains no integer"
  | _ -> ());
  (lo, hi)

(* The interval literals of the grades whose intervals are bounded below by a
   grade and above by a grade or [∞]. *)
let bound_forms = "`[L, U]` or `[L, ∞)`"

let bounds_of_lit lit ~number ~close ~lower ~upper ~unbounded ~bounds =
  match open_pair lit with
  | Interval (Unbounded, _) ->
      invalid_lit lit "intervals are bounded below, written %s" bound_forms
  | Interval (((Closed l | Open l) as lo), hi) ->
      check_nonempty ~number lit lo hi;
      let close_end ~lower a = function
        | Closed _ -> a
        | Open _ when Option.is_some (numeric a) ->
            component_of_lit lit ~context:"" (close ~lower) a
        | Open _ | Unbounded ->
            invalid_lit lit
              "an endpoint that is not a number is closed, as in %s" bound_forms
      in
      let l = close_end ~lower:true l lo in
      let u =
        match hi with
        | Closed u | Open u -> Some (close_end ~lower:false u hi)
        | Unbounded -> None
      in
      (match (number l, Option.bind u number) with
      | Some n, Some m when Rational.compare n m > 0 ->
          invalid_lit lit "the interval contains no integer"
      | _ -> ());
      let lo = component_of_lit lit ~context:"" lower l in
      let hi =
        match u with
        | None -> unbounded
        | Some u -> component_of_lit lit ~context:"" upper u
      in
      (lo, hi)
  | Tuple [ _; _ ] ->
      invalid_lit lit "intervals are written %s, not as pairs `(L, U)`"
        bound_forms
  | _ ->
      invalid_lit lit
        "grades are intervals `[{...}, {...}]` of %s, or abbreviations of \
         them, not %s"
        bounds (describe_lit lit)

let show_bounds lo = function
  | Some hi -> "[" ^ lo ^ ", " ^ hi ^ "]"
  | None -> "[" ^ lo ^ ", ∞)"
