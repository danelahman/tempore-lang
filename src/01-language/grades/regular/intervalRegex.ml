open Grade

(* {1 Operation sets} *)

module Ops = struct
  type t = Only of string list | Except of string list

  let empty = Only []
  let all = Except []
  let name n = Only [ n ]

  (* Sorted lists of names without duplicates. *)
  let rec merge xs ys =
    match (xs, ys) with
    | [], l | l, [] -> l
    | x :: xs', y :: ys' -> (
        match String.compare x y with
        | 0 -> x :: merge xs' ys'
        | c when c < 0 -> x :: merge xs' ys
        | _ -> y :: merge xs ys')

  let rec common xs ys =
    match (xs, ys) with
    | [], _ | _, [] -> []
    | x :: xs', y :: ys' -> (
        match String.compare x y with
        | 0 -> x :: common xs' ys'
        | c when c < 0 -> common xs' ys
        | _ -> common xs ys')

  let rec minus xs ys =
    match (xs, ys) with
    | [], _ -> []
    | l, [] -> l
    | x :: xs', y :: ys' -> (
        match String.compare x y with
        | 0 -> minus xs' ys'
        | c when c < 0 -> x :: minus xs' ys
        | _ -> minus xs ys')

  let union s s' =
    match (s, s') with
    | Only a, Only b -> Only (merge a b)
    | Only a, Except b | Except b, Only a -> Except (minus b a)
    | Except a, Except b -> Except (common a b)

  let inter s s' =
    match (s, s') with
    | Only a, Only b -> Only (common a b)
    | Only a, Except b | Except b, Only a -> Only (minus a b)
    | Except a, Except b -> Except (merge a b)

  let compl = function Only a -> Except a | Except a -> Only a
  let mem n = function Only a -> List.mem n a | Except a -> not (List.mem n a)
  let is_empty = function Only [] -> true | _ -> false
  let subset s s' = is_empty (inter s (compl s'))
  let equal s s' = s = s'
  let compare (s : t) s' = Stdlib.compare s s'

  let hash = function
    | Only a -> Hashing.combine 1 (Hashing.list String.hash a)
    | Except a -> Hashing.combine 2 (Hashing.list String.hash a)

  let mentioned = function Only a | Except a -> a
  let of_list names = Only (List.sort_uniq String.compare names)
end

(* {1 Lengths} *)

type cut = DelaySet.extremum = Finite of Rational.t * bool | Infinite
type side = Upper | Lower

let add_cuts c c' =
  match (c, c') with
  | Finite (a, f), Finite (b, g) -> Finite (Rational.add a b, f && g)
  | Infinite, _ | _, Infinite -> Infinite

let times n = function
  | Finite (a, f) -> Finite (Rational.mul (Rational.of_int n) a, f)
  | Infinite -> Infinite

(* [wider side c c'] is whether the lengths of the cut [c] include those of
   [c'] on [side]. *)
let wider side c c' =
  match (side, c, c') with
  | Upper, Infinite, _ -> true
  | Upper, Finite _, Infinite -> false
  | Lower, Infinite, _ -> false
  | Lower, Finite _, Infinite -> true
  | _, Finite (a, f), Finite (b, g) -> (
      match Rational.compare a b with
      | 0 -> f || not g
      | k -> if side = Upper then k > 0 else k < 0)

let zero_cut = Finite (Rational.zero, true)
let is_zero = function Finite (a, true) -> Rational.sign a = 0 | _ -> false

(* {1 Printing} *)

module Printed = struct
  type tree =
    | Empty
    | Eps
    | Ops of Ops.t
    | Length of Ops.t * string
    | Seq of tree list
    | Alt of tree list
    | Opt of tree
    | Star of tree
    | Repeat of tree * Count.t

  type printed = { text : string; level : int }
  (* The level of the outermost operator of [text]: [0] union, [1]
     intersection, [2] concatenation, [4] repetition and [5] an atom. *)

  let atom text = { text; level = 5 }
  let at level p = if p.level >= level then p.text else "(" ^ p.text ^ ")"

  let alternatives = function
    | [ n ] -> atom n
    | names -> { text = String.concat " | " names; level = 0 }

  let ops = function
    | Ops.Only names -> alternatives names
    | Ops.Except [] -> atom "_"
    | Ops.Except names ->
        { text = "_ & ~" ^ at 3 (alternatives names); level = 1 }

  let rec print = function
    | Empty -> { text = "_ & ~_"; level = 1 }
    | Eps -> atom "0"
    | Ops s -> ops s
    | Length (s, text) when Ops.is_empty s -> atom ("!" ^ text)
    | Length (Ops.Except [], text) -> atom text
    | Length (s, text) ->
        let set =
          match s with
          | Ops.Only _ -> at 2 (ops s)
          | Ops.Except names -> "~" ^ at 5 (alternatives names)
        in
        { text = text ^ " & " ^ set; level = 1 }
    | Seq ts ->
        {
          text = String.concat "; " (List.map (fun t -> at 3 (print t)) ts);
          level = 2;
        }
    | Alt ts ->
        {
          text =
            String.concat " | "
              (List.sort String.compare (List.map (fun t -> at 0 (print t)) ts));
          level = 0;
        }
    | Opt t -> { text = operand t ^ "?"; level = 4 }
    | Star t -> { text = operand t ^ "*"; level = 4 }
    | Repeat (t, c) -> { text = operand t ^ "^" ^ Count.show c; level = 4 }

  (* The operand of a postfix operator, a strict stretch parenthesised. *)
  and operand = function
    | (Star _ | Repeat _ | Opt _) as t -> (print t).text
    | Length (s, _) as t when Ops.is_empty s -> "(" ^ (print t).text ^ ")"
    | t -> at 5 (print t)

  let text t = (print t).text
end

(* [letter side c] prints the one-sided length of cut [c] on [side]. *)
let letter side c =
  match (side, c) with
  | _, Infinite -> "≥0"
  | Upper, Finite (q, true) -> "≤" ^ Rational.show q
  | Upper, Finite (q, false) -> "<" ^ Rational.show q
  | Lower, Finite (q, true) -> "≥" ^ Rational.show q
  | Lower, Finite (q, false) -> ">" ^ Rational.show q

(* [two_sided lo hi] prints the interval of the lower cut [lo] and the upper
   cut [hi], if it is not empty. *)
let two_sided lo hi =
  match (lo, hi) with
  | Finite (a, true), Infinite when Rational.sign a = 0 -> Some "≥0"
  | Finite (a, f), Infinite ->
      Some ((if f then "[" else "(") ^ Rational.show a ^ ", ∞)")
  | Finite (a, f), Finite (b, g) -> (
      match Rational.compare a b with
      | 0 when f && g -> Some (Rational.show a)
      | k when k < 0 ->
          Some
            ((if f then "[" else "(")
            ^ Rational.show a ^ ", " ^ Rational.show b
            ^ if g then "]" else ")")
      | _ -> None)
  | Infinite, _ -> None

(* {1 Expressions} *)

module type S = sig
  val side : side

  type t

  type view =
    | Empty
    | Eps
    | Op of Ops.t
    | Stretch of Ops.t * cut
    | Concat of t * t
    | Union of t list
    | Star of t
    | Repeat of t * Count.t

  val view : t -> view
  val id : t -> int
  val hash : t -> int
  val equal : t -> t -> bool
  val compare : t -> t -> int
  val empty : t
  val eps : t
  val op : Ops.t -> t
  val stretch : Ops.t -> cut -> t
  val concat : t -> t -> t
  val union : t list -> t
  val star : t -> t
  val repeat : t -> Count.t -> t
  val nullable : t -> bool
  val factors : t -> t list
  val names : t -> string list
  val of_regex : whole:bool -> finite:bool -> lit -> regex -> t
  val show : t -> string
end

module Make (Side : sig
  val side : side
end) =
struct
  let side = Side.side

  type t = { view : view; id : int; nullable : bool }

  and view =
    | Empty
    | Eps
    | Op of Ops.t
    | Stretch of Ops.t * cut
    | Concat of t * t
    | Union of t list
    | Star of t
    | Repeat of t * Count.t

  let view r = r.view
  let id r = r.id
  let hash r = r.id
  let equal r s = r.id = s.id
  let compare r s = Int.compare r.id s.id

  let nullable_view = function
    | Empty | Op _ -> false
    | Eps | Star _ -> true
    | Stretch (_, c) -> side = Upper || is_zero c
    | Concat (r, s) -> r.nullable && s.nullable
    | Union rs -> List.exists (fun r -> r.nullable) rs
    | Repeat (r, c) -> c.least = 0 || r.nullable

  module Table =
    NormalForms.HashCons
      (struct
        type t = view

        let equal v v' =
          match (v, v') with
          | Empty, Empty | Eps, Eps -> true
          | Op s, Op s' -> Ops.equal s s'
          | Stretch (s, c), Stretch (s', c') ->
              Ops.equal s s' && DelaySet.equal_extremum c c'
          | Concat (r, s), Concat (r', s') -> r.id = r'.id && s.id = s'.id
          | Union rs, Union rs' -> List.equal (fun r r' -> r.id = r'.id) rs rs'
          | Star r, Star r' -> r.id = r'.id
          | Repeat (r, c), Repeat (r', c') -> r.id = r'.id && Count.equal c c'
          | _ -> false

        let hash = function
          | Empty -> 0
          | Eps -> 1
          | Op s -> Hashing.combine 2 (Ops.hash s)
          | Stretch (s, c) ->
              Hashing.combine 3
                (Hashing.combine (Ops.hash s) (DelaySet.hash_extremum c))
          | Concat (r, s) -> Hashing.combine 4 (Hashing.combine r.id s.id)
          | Union rs -> Hashing.combine 5 (Hashing.list (fun r -> r.id) rs)
          | Star r -> Hashing.combine 6 r.id
          | Repeat (r, c) ->
              Hashing.combine 7 (Hashing.combine r.id (Count.hash c))
      end)
      (struct
        type nonrec t = t

        let build id view = { view; id; nullable = nullable_view view }
      end)

  let make = Table.make
  let empty = make Empty
  let eps = make Eps
  let nullable r = r.nullable
  let op s = if Ops.is_empty s then empty else make (Op s)

  (* A stretch of length [0] is the empty word, and one of no length the
     empty language. *)
  let stretch s c =
    match (side, c) with
    | Upper, Finite (a, f) when Rational.sign a = 0 -> if f then eps else empty
    | Lower, Infinite -> empty
    | _ -> make (Stretch (s, c))

  (* [power r] is the base and the count of the factor [r]: [x^c] is [x] to
     the [c], any other factor its own base to the [1]. *)
  let power r =
    match r.view with Repeat (x, c) -> (x, c) | _ -> (r, Count.point 1)

  let joinable r = match r.view with Stretch _ | Eps -> false | _ -> true

  let rec concat r s =
    match (r.view, s.view) with
    | Empty, _ | _, Empty -> empty
    | Eps, _ -> s
    | _, Eps -> r
    | Concat (a, b), _ -> concat a (concat b s)
    | Stretch (p, c), Stretch (p', c') when Ops.equal p p' ->
        stretch p (add_cuts c c')
    | Stretch (p, c), Concat ({ view = Stretch (p', c'); _ }, t)
      when Ops.equal p p' ->
        concat (stretch p (add_cuts c c')) t
    | _ -> (
        let x, c = power r in
        let joined y c' rest =
          if joinable x && equal x y then Some (repeat x (Count.add c c'), rest)
          else None
        in
        let optional =
          match s.view with
          | Union [ a; b ] when joinable x -> (
              let other =
                if a.view = Eps then Some b
                else if b.view = Eps then Some a
                else None
              in
              match other with
              | Some t when joinable t ->
                  let y, c' = power t in
                  if equal x y then
                    Some (union [ r; repeat x (Count.add c c') ])
                  else None
              | _ -> None)
          | _ -> None
        in
        let candidate =
          match s.view with
          | Concat (h, t) ->
              let y, c' = power h in
              joined y c' (Some t)
          | _ ->
              let y, c' = power s in
              joined y c' None
        in
        match (optional, candidate) with
        | Some u, _ -> u
        | None, Some (x', Some t) -> concat x' t
        | None, Some (x', None) -> x'
        | None, None -> make (Concat (r, s)))

  and union rs =
    let rec flatten acc r =
      match r.view with
      | Union rs -> List.fold_left flatten acc rs
      | Empty -> acc
      | _ -> r :: acc
    in
    let rs = List.fold_left flatten [] rs in
    let ops, rest =
      List.partition_map
        (fun r -> match r.view with Op s -> Left s | _ -> Right r)
        rs
    in
    let rest =
      match ops with
      | [] -> rest
      | s :: ss -> op (List.fold_left Ops.union s ss) :: rest
    in
    (* Stretches of one set merge into the widest. *)
    let rest =
      List.fold_left
        (fun acc r ->
          match r.view with
          | Stretch (p, c) -> (
              match
                List.partition
                  (fun r' ->
                    match r'.view with
                    | Stretch (p', _) -> Ops.equal p p'
                    | _ -> false)
                  acc
              with
              | [ { view = Stretch (_, c'); _ } ], others ->
                  stretch p (if wider side c c' then c else c') :: others
              | _ -> r :: acc)
          | _ -> r :: acc)
        [] rest
    in
    let stars =
      List.filter_map
        (fun r -> match r.view with Star x -> Some x.id | _ -> None)
        rest
    in
    let rest = List.filter (fun r -> not (List.mem r.id stars)) rest in
    (* Repetitions of one base merge where their counts overlap or touch:
       [x^c | x^c'] is [x^(c ∪ c')], a factor [x] counting as [x^1]. *)
    let rest =
      List.fold_left
        (fun acc r ->
          if not (joinable r) then r :: acc
          else
            let x, c = power r in
            let rec merge = function
              | [] -> None
              | s :: others -> (
                  let merged =
                    if joinable s then
                      let y, c' = power s in
                      if equal x y then Count.union c c' else None
                    else None
                  in
                  match merged with
                  | Some c'' -> Some (repeat x c'' :: others)
                  | None ->
                      Option.map (fun others -> s :: others) (merge others))
            in
            match merge acc with Some acc -> acc | None -> r :: acc)
        [] rest
    in
    let rest =
      if List.exists (fun r -> r.nullable && r.view <> Eps) rest then
        List.filter (fun r -> r.view <> Eps) rest
      else rest
    in
    match List.sort_uniq compare rest with
    | [] -> empty
    | [ r ] -> r
    | rs -> make (Union rs)

  and star r =
    match r.view with
    | Empty | Eps -> eps
    | Star _ -> r
    | Union rs when List.exists (fun r -> r.view = Eps) rs ->
        star (union (List.filter (fun r -> r.view <> Eps) rs))
    | Stretch (p, _) ->
        let base = match side with Upper -> stretch p Infinite | Lower -> r in
        if base.nullable then base else union [ eps; base ]
    | _ -> make (Star r)

  and repeat r (c : Count.t) =
    match (r.view, c) with
    | _, { least = 0; most = Some 0 } -> eps
    | _, { least = 1; most = Some 1 } -> r
    | _, { least = 0; most = None } -> star r
    | Empty, _ -> if c.least = 0 then eps else empty
    | Eps, _ -> eps
    | Star _, _ -> r
    | Stretch (p, cut), _ ->
        let base =
          match (side, c.most) with
          | Upper, None -> stretch p Infinite
          | Upper, Some n -> stretch p (times n cut)
          | Lower, _ -> stretch p (times (max c.least 1) cut)
        in
        if c.least = 0 && not base.nullable then union [ eps; base ] else base
    | Repeat (x, c'), _ -> (
        match Count.nest c' c with
        | Some c'' -> repeat x c''
        | None -> make (Repeat (r, c)))
    | _ when r.nullable -> (
        match c.most with
        | None -> star r
        | Some n when c.least = n -> make (Repeat (r, c))
        | Some n -> repeat r (Count.point n))
    | _ -> make (Repeat (r, c))

  let names =
    let table = Memo.Ints.create 64 in
    let rec go r =
      Memo.Ints.find_or_add table r.id (fun () ->
          match r.view with
          | Empty | Eps -> []
          | Op s | Stretch (s, _) -> Ops.mentioned s
          | Concat (a, b) -> Ops.merge (go a) (go b)
          | Union rs -> List.fold_left (fun acc r -> Ops.merge acc (go r)) [] rs
          | Star r | Repeat (r, _) -> go r)
    in
    go

  (* {2 Literals} *)

  let wrong_side letter =
    match side with
    | Upper ->
        Printf.sprintf
          "upper bounds have letters bounded above only, such as `≤3` or \
           `!≤3`, not `%s`"
          letter
    | Lower ->
        Printf.sprintf
          "lower bounds have letters bounded below only, such as `≥3` or \
           `!≥3`, not `%s`"
          letter

  (* [ops_of r] is the operation set of the expression [r] of operation sets
     built with [|], [&] and [~], if it is one. *)
  let rec ops_of = function
    | Letter n -> Some (Ops.name n)
    | Any -> Some Ops.all
    | Union (a, b) -> both Ops.union a b
    | Inter (a, b) -> both Ops.inter a b
    | Compl a -> Option.map Ops.compl (ops_of a)
    | _ -> None

  and both f a b =
    match (ops_of a, ops_of b) with
    | Some s, Some s' -> Some (f s s')
    | _ -> None

  let rec has_compl = function
    | Compl _ -> true
    | Seq (a, b) | Union (a, b) | Inter (a, b) -> has_compl a || has_compl b
    | Star a | Repeat (a, _) | Strict a -> has_compl a
    | _ -> false

  (* [as_interval r] is the expression of intervals of [r], a one-sided
     interval [≤d] or [≥d] read as the interval it denotes. *)
  let rec as_interval = function
    | Below b -> Delays (Closed Rational.zero, b)
    | Above b -> Delays (b, Unbounded)
    | Seq (a, b) -> Seq (as_interval a, as_interval b)
    | Union (a, b) -> Union (as_interval a, as_interval b)
    | Inter (a, b) -> Inter (as_interval a, as_interval b)
    | Star a -> Star (as_interval a)
    | Repeat (a, c) -> Repeat (as_interval a, c)
    | r -> r

  let last = function Seq (_, b) -> Some b | _ -> None
  let rec first = function Seq (a, _) -> first a | r -> r

  let of_regex ~whole ~finite lit r =
    let fail fmt = invalid_lit lit fmt in
    let unsupported form =
      fail
        "sets of traces are built from operation names, finite sets of them \
         and lengths with `;`, `|` and finite counts `^n`, `^[m, n]` only, \
         without %s"
        form
    in
    let number q =
      if whole && not (Rational.is_integer q) then
        component_of_lit lit ~context:"" fractional_tick q
      else q
    in
    (* The cut of the end [b] of an interval on this side, an open end over
       whole time steps closed at the next integer inward. *)
    let upper_cut = function
      | Closed q -> Finite (number q, true)
      | Open q ->
          let q = number q in
          if whole then Finite (Rational.sub q (Rational.of_int 1), true)
          else Finite (q, false)
      | Unbounded -> Infinite
    and lower_cut = function
      | Closed q -> Finite (number q, true)
      | Open q ->
          let q = number q in
          if whole then Finite (Rational.add q (Rational.of_int 1), true)
          else Finite (q, false)
      | Unbounded -> Infinite
    in
    let hull set lo hi =
      match side with
      | Upper -> stretch set (upper_cut hi)
      | Lower -> stretch set (lower_cut lo)
    in
    let point set q =
      let q = number q in
      if Rational.sign q = 0 then eps else stretch set (Finite (q, true))
    in
    let prefix set = if Ops.is_empty set then "!" else "" in
    let rec go set r =
      match ops_of r with
      | Some s -> (
          match s with
          | Ops.Except _ when finite ->
              unsupported ("the operation set `" ^ show_regex r ^ "`")
          | _ -> op s)
      | None -> (
          match r with
          | Tick n -> point set (Rational.of_int n)
          | Frac q -> point set q
          | Delays (lo, hi) ->
              if whole then
                match
                  component_of_lit lit ~context:""
                    (fun (lo, hi) -> tick_interval lo hi)
                    (lo, hi)
                with
                | a, b ->
                    hull set
                      (Closed (Rational.of_int a))
                      (match b with
                      | Some b -> Closed (Rational.of_int b)
                      | None -> Unbounded)
              else hull set lo hi
          | Below b -> (
              match (side, b) with
              | Upper, _ -> stretch set (upper_cut b)
              | Lower, Unbounded -> stretch set zero_cut
              | Lower, _ -> fail "%s" (wrong_side (prefix set ^ show_below b)))
          | Above b -> (
              match (side, b) with
              | Lower, _ -> stretch set (lower_cut b)
              | Upper, Closed q when Rational.sign q = 0 -> stretch set Infinite
              | Upper, _ -> fail "%s" (wrong_side (prefix set ^ show_above b)))
          | Strict Any ->
              fail
                "`!_` is no letter of these grades: `_` is one operation, \
                 `!≥0` a wait of any length, and `(≥0 & S)` a stretch with \
                 operations of S"
          | Strict a when has_compl a -> interval_complement ()
          | Strict a -> go Ops.empty a
          | Seq (a, b) -> concat (go set a) (go set b)
          | Union (a, b) -> union [ go set a; go set b ]
          | Star _ when finite -> unsupported "repetition `*`"
          | Star a -> star (go set a)
          | Repeat (_, ({ most = None; _ } as c)) when finite ->
              unsupported ("the unbounded repetition `^" ^ Count.show c ^ "`")
          | Repeat (a, c) -> repeat (go set a) c
          | Inter (a, b) when delays_only a && delays_only b ->
              if has_compl r then interval_complement ()
              else
                let s =
                  DelayRegex.delays (as_interval (Inter (a, b))) |> fun s ->
                  if whole then DelaySet.inter s DelaySet.naturals else s
                in
                let extremum =
                  match side with
                  | Upper -> DelaySet.sup
                  | Lower -> DelaySet.inf
                in
                Option.fold ~none:empty
                  ~some:(fun c ->
                    match (side, c) with
                    | Lower, Finite (q, _) when Rational.sign q = 0 ->
                        stretch set
                          (if DelaySet.mem Rational.zero s then zero_cut else c)
                    | _ -> stretch set c)
                  (extremum s)
          | Inter (a, b) when delays_only a && Option.is_some (ops_of b) ->
              go (Ops.inter set (Option.get (ops_of b))) a
          | Inter (a, b) when delays_only b && Option.is_some (ops_of a) ->
              go (Ops.inter set (Option.get (ops_of a))) b
          | Inter (a, b) ->
              let hint =
                match (last a, first b) with
                | Some l, f when delays_only l && Option.is_some (ops_of f) ->
                    "; a restricted budget in a sequence is written in \
                     parentheses, as in `A; (≥0 & ~B); C`"
                | _ -> ""
              in
              fail
                "the intersection `&` applies to operation sets, intervals and \
                 a budget with an operation set only, such as `_ & ~Read` or \
                 `(≥0 & ~Read)`, not to `%s` and `%s`%s"
                (show_regex a) (show_regex b) hint
          | Compl a when delays_only a -> interval_complement ()
          | Compl a ->
              fail
                "the complement `~` applies to operation sets and intervals \
                 only, such as `~Read` or `_ & ~Read`, not to `%s`; a stretch \
                 without an operation is written as a budget restricted to an \
                 operation set, such as `(≥0 & ~Read)`"
                (show_regex a)
          | Letter _ | Any -> assert false)
    and interval_complement () =
      fail
        "the complement of an interval is not one-sided; these grades read \
         lengths bounded on one side"
    in
    go Ops.all r

  (* {2 Printing} *)

  (* [factors r] is the factors of the concatenation [r]. *)
  let rec factors r =
    match r.view with Concat (a, b) -> a :: factors b | _ -> [ r ]

  (* [tree length r] is the printed form of [r], its stretches printed by
     [length]. *)
  let rec tree length r =
    match r.view with
    | Empty -> Printed.Empty
    | Eps -> Printed.Eps
    | Op s -> Printed.Ops s
    | Stretch (s, c) -> Printed.Length (s, length c)
    | Concat _ -> Printed.Seq (List.map (tree length) (factors r))
    | Union rs -> (
        match List.partition (fun r -> r.view = Eps) rs with
        | [], _ -> Printed.Alt (List.map (tree length) rs)
        | _, [ r ] -> Printed.Opt (tree length r)
        | _, rs -> Printed.Opt (Printed.Alt (List.map (tree length) rs)))
    | Star r -> Printed.Star (tree length r)
    | Repeat (r, c) -> Printed.Repeat (tree length r, c)

  let show r = Printed.text (tree (letter side) r)
end

module Upper = Make (struct
  let side = Upper
end)

module Lower = Make (struct
  let side = Lower
end)

(* {1 Zipped intervals} *)

(* [zipped lo hi] is the printed form of the expressions [lo] and [hi] that
   differ only in the cuts of their stretches, each stretch printed as its
   two-sided interval, if they do; the operands of unions are matched in
   order of their first match. *)
let rec zipped lo hi =
  let all f xs ys =
    if List.length xs <> List.length ys then None
    else
      List.fold_right2
        (fun x y acc ->
          match (acc, f x y) with
          | Some ts, Some t -> Some (t :: ts)
          | _ -> None)
        xs ys (Some [])
  in
  let rec matching xs ys =
    match xs with
    | [] -> if ys = [] then Some [] else None
    | x :: xs' ->
        let rec pick before = function
          | [] -> None
          | y :: after -> (
              match zipped x y with
              | Some t -> (
                  match matching xs' (List.rev_append before after) with
                  | Some ts -> Some (t :: ts)
                  | None -> pick (y :: before) after)
              | None -> pick (y :: before) after)
        in
        pick [] ys
  in
  match (Lower.view lo, Upper.view hi) with
  | Lower.Empty, Upper.Empty -> Some Printed.Empty
  | Lower.Eps, Upper.Eps -> Some Printed.Eps
  | Lower.Op s, Upper.Op s' when Ops.equal s s' -> Some (Printed.Ops s)
  | Lower.Stretch (s, c), Upper.Stretch (s', c') when Ops.equal s s' ->
      Option.map (fun text -> Printed.Length (s, text)) (two_sided c c')
  | Lower.Concat _, Upper.Concat _ ->
      Option.map
        (fun ts -> Printed.Seq ts)
        (all zipped (Lower.factors lo) (Upper.factors hi))
  | Lower.Union rs, Upper.Union rs' -> (
      let eps r = Lower.view r = Lower.Eps
      and eps' r = Upper.view r = Upper.Eps in
      let rs1 = List.filter (fun r -> not (eps r)) rs
      and rs1' = List.filter (fun r -> not (eps' r)) rs' in
      match
        ( List.length rs1 < List.length rs,
          List.length rs1' < List.length rs',
          matching rs1 rs1' )
      with
      | false, false, Some ts -> Some (Printed.Alt ts)
      | true, true, Some [ t ] -> Some (Printed.Opt t)
      | true, true, Some ts -> Some (Printed.Opt (Printed.Alt ts))
      | _ -> None)
  | Lower.Star r, Upper.Star r' ->
      Option.map (fun t -> Printed.Star t) (zipped r r')
  | Lower.Repeat (r, c), Upper.Repeat (r', c') when Count.equal c c' ->
      Option.map (fun t -> Printed.Repeat (t, c)) (zipped r r')
  | _ -> None

let zip lo hi = Option.map Printed.text (zipped lo hi)
