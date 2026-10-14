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
  | Any
  | Seq of regex * regex
  | Union of regex * regex
  | Star of regex
  | Inter of regex * regex
  | Compl of regex

let regex_names r =
  let rec go = function
    | Letter name -> [ name ]
    | Tick _ | Frac _ | Delays _ | Any -> []
    | Seq (r, s) | Union (r, s) | Inter (r, s) -> go r @ go s
    | Star r | Compl r -> go r
  in
  List.sort_uniq String.compare (go r)

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
    | Star r ->
        wrap ctx 4 (fun () ->
            go 5 r;
            add "*")
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

let component_of_lit lit ~context of_lit component =
  try of_lit component
  with Invalid_literal (_, reason) -> invalid_lit lit "%s%s" context reason

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
