open Grade
module R = SymbolicRegex
module Letters = SymbolicRegex.Letters

type t = R.t

let name = "regular-traces"
let tick = R.letters Letters.tick

let ticks n =
  List.fold_left (fun r _ -> R.concat tick r) R.eps (List.init n Fun.id)

let rec of_regex = function
  | Letter name -> R.letters (Letters.name name)
  | Tick n -> ticks n
  | Any -> R.letters Letters.any
  | Seq (r, s) -> R.concat (of_regex r) (of_regex s)
  | Union (r, s) -> R.union [ of_regex r; of_regex s ]
  | Inter (r, s) -> R.inter [ of_regex r; of_regex s ]
  | Star r -> R.star (of_regex r)
  | Compl r -> R.compl (of_regex r)

let one = R.eps
let mul = R.concat
let join rho rho' = R.union [ rho; rho' ]
let top = R.top
let leq _bounds = R.subset
let leq_symbol = "<="
let equal _bounds = R.equal
let of_nat n = ticks (check_nat "RegularTraceGradeDerivative" n)
let unit_least = false
let commutative = false
let needs_op_bounds = false
let implied_bounds _bounds _rho = None
let events = R.names

(* The delays of [lo] to [hi] time steps. *)
let of_bounds (lo, hi) =
  R.union (List.init (max 1 (hi - lo + 1)) (fun k -> ticks (lo + k)))

let is_atomic name rho = R.equal rho (R.letters (Letters.name name))

(** [representative m] is the least letter of the block [m] of minterms: [tick],
    else its least name, else the block itself, the names the grades compared do
    not mention. *)
let representative (m : Letters.t) =
  match m with
  | { tick = true; _ } -> Letters.tick
  | { names = Only (name :: _); _ } -> Letters.name name
  | m -> m

let counterexample rho rho' =
  Option.map
    (List.fold_left
       (fun r m -> R.concat r (R.letters (representative m)))
       R.eps)
    (R.shortest (R.inter [ rho; R.compl rho' ]))

let of_lit = function
  | Int n when n < 0 -> invalid_lit (Int n) "grades must be non-negative"
  | Int n -> of_nat n
  | Top -> top
  | Braces r as lit ->
      let rho = of_regex r in
      if R.is_empty rho then
        invalid_lit lit
          "this regular expression denotes the empty language, but grades are \
           non-empty"
      else rho
  | lit ->
      invalid_lit lit
        "grades are regular expressions '{...}', plain integers or '⊤', not %s"
        (describe_lit lit)

(** {1 Printing} *)

(** [rank r] orders the forms of expressions for printing. *)
let rank r =
  match R.view r with
  | Eps -> 0
  | Letters _ -> 1
  | Concat _ -> 2
  | Star _ -> 3
  | Compl _ -> 4
  | Inter _ -> 5
  | Union _ -> 6
  | Empty -> 7

(** [display_compare r s] is a total order on normal forms, independent of the
    order of their construction, in which the operands of unions and
    intersections are printed. *)
let rec display_compare r s =
  match (R.view r, R.view s) with
  | Letters p, Letters q -> Letters.order p q
  | Concat (r1, r2), Concat (s1, s2) ->
      let c = display_compare r1 s1 in
      if c <> 0 then c else display_compare r2 s2
  | Star r, Star s | Compl r, Compl s -> display_compare r s
  | Inter rs, Inter ss | Union rs, Union ss ->
      List.compare display_compare (sorted rs) (sorted ss)
  | _ -> Int.compare (rank r) (rank s)

and sorted rs = List.sort display_compare rs

type printed = { text : string; level : int }
(* The level of the outermost operator of [text]: [0] union, [1]
   intersection, [2] concatenation, [3] complement, [4] repetition and [5] an
   atom. *)

let atom text = { text; level = 5 }

(** [at level p] is [p] grouped if its operator binds more loosely than [level]:
    in braces if it ends with a repetition, so that no printed grade contains a
    star followed by a closing parenthesis, which would close a comment quoting
    it, and in parentheses otherwise. *)
let at level p =
  if p.level >= level then p.text
  else if String.ends_with ~suffix:"*" p.text then "{" ^ p.text ^ "}"
  else "(" ^ p.text ^ ")"

let alternatives = function
  | [ item ] -> atom item
  | items -> { text = String.concat " | " items; level = 0 }

let print_letters (p : Letters.t) =
  let ticks tick = if tick then [ "1" ] else [] in
  match p.names with
  | Only names -> alternatives (ticks p.tick @ names)
  | Except [] when p.tick -> atom "_"
  | Except names ->
      let excluded = alternatives (ticks (not p.tick) @ names) in
      { text = "_ & ~" ^ at 3 excluded; level = 1 }

(** [factors r] is the list of the factors of the concatenation [r]. *)
let rec factors r =
  match R.view r with Concat (r, s) -> r :: factors s | _ -> [ r ]

let is_tick r =
  match R.view r with Letters p -> Letters.equal p Letters.tick | _ -> false

type factor = Ticks of int | Factor of R.t

(** [group_ticks rs] joins the runs of ticks of the factors [rs] into their
    number. *)
let group_ticks rs =
  let add r acc =
    match acc with
    | Ticks n :: acc when is_tick r -> Ticks (n + 1) :: acc
    | acc when is_tick r -> Ticks 1 :: acc
    | acc -> Factor r :: acc
  in
  List.fold_right add rs []

let rec print r =
  match R.view r with
  | Empty -> { text = "~_*"; level = 3 }
  | Eps -> atom "0"
  | Letters p -> print_letters p
  | Concat _ -> print_concat r
  | Union rs -> nary " | " 0 rs
  | Inter rs -> nary " & " 1 rs
  | Compl r -> { text = "~" ^ at 3 (print r); level = 3 }
  | Star r -> { text = at 4 (print r) ^ "*"; level = 4 }

and nary separator level rs =
  {
    text =
      String.concat separator
        (List.map (fun r -> at level (print r)) (sorted rs));
    level;
  }

and print_concat r =
  let factor = function
    | Ticks n -> string_of_int n
    | Factor r -> at 3 (print r)
  in
  match group_ticks (factors r) with
  | [ Ticks n ] -> atom (string_of_int n)
  | parts -> { text = String.concat "; " (List.map factor parts); level = 2 }

let show rho =
  if R.equal_form rho top then "⊤" else "{" ^ (print rho).text ^ "}"
