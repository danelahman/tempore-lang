(** Grade literals: the literal syntax shared by all grade positions of the
    source. Each grade interprets the literals it understands
    ({!Grade.S.of_lit}) and rejects the others with {!Invalid_literal}; delays
    read the numeric ones ({!Delay.S.read}). *)

(** An endpoint of an interval. *)
type 'a bound =
  | Closed of 'a  (** A finite endpoint the interval contains *)
  | Open of 'a  (** A finite endpoint the interval excludes *)
  | Unbounded  (** An infinite endpoint *)

(** [show_interval show lo hi] prints the interval from [lo] to [hi], its finite
    endpoints printed by [show], e.g. [\[1, 2)] or [(1/2, ∞)]. *)
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

(** Regular expressions over operation names and delays, the contents of a brace
    literal [{...}]. *)
type regex =
  | Letter of string  (** An operation name, e.g. [Send] *)
  | Tick of int  (** A delay of [n] time steps, e.g. [3] *)
  | Frac of Rational.t  (** A delay that is not an [int], e.g. [1/2] or [1.5] *)
  | Delays of Rational.t bound * Rational.t bound
      (** The delays in an interval with a finite lower endpoint, e.g. [\[0, 1)]
          or [(1/2, ∞)] *)
  | Any
      (** Any single operation or time step, [_]; over rational delays, any
          single operation or positive delay *)
  | Seq of regex * regex  (** Concatenation, [r; s] *)
  | Union of regex * regex  (** Union, [r | s] *)
  | Star of regex  (** Repetition, [r*] *)
  | Inter of regex * regex  (** Intersection, [r & s] *)
  | Compl of regex  (** Complement, [~r] *)

(** [regex_names r] is the list of the operation names [r] mentions, in
    increasing order. *)
let regex_names r =
  let rec go = function
    | Letter name -> [ name ]
    | Tick _ | Frac _ | Delays _ | Any -> []
    | Seq (r, s) | Union (r, s) | Inter (r, s) -> go r @ go s
    | Star r | Compl r -> go r
  in
  List.sort_uniq String.compare (go r)

(** [show_regex r] prints [r] as the contents of a brace literal, with the
    parentheses the precedences require: union [|], intersection [&],
    concatenation [;], complement [~] and repetition [*], by increasing
    precedence. The three binary operators are printed as associative, and a
    fraction under a repetition is parenthesised. *)
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

(** Grade literals as they appear in source. *)
type lit =
  | Int of int  (** An integer, e.g. [42] or [-1] *)
  | Rat of Rational.t
      (** A rational that is not an [int], e.g. [3/2] or [1.5] *)
  | Name of string  (** A capitalised name, e.g. [High], or [_] *)
  | Top  (** The greatest grade, [⊤] or [top] *)
  | Inf  (** Infinity, [∞] or [inf] *)
  | Tuple of lit list
      (** A parenthesised tuple of at least two literals, e.g. [(3, High)] *)
  | Interval of lit bound * lit bound
      (** An interval with bracketed endpoints: [[1, 4]], [\[1/2, 3)],
          [(1, 4\]], [\[1/2, ∞)], [(-∞, 3\]], [(-∞, ∞)] or [[{A}, {A; B}]]. A
          pair of numbers [(1, 4)] is a {!Tuple}, which the grades that read
          intervals of numbers read as an open interval ({!open_pair}). *)
  | Braces of regex  (** A brace literal, e.g. [{Read; 3; Send | Send}] *)

exception Invalid_literal of lit * string
(** [Invalid_literal (lit, reason)] is raised by [of_lit] on a literal [lit] the
    grade does not understand, [reason] saying why. *)

(** [invalid_lit lit fmt] raises {!Invalid_literal} on [lit] with the reason
    formatted by [fmt]. *)
let invalid_lit lit fmt =
  Printf.ksprintf (fun reason -> raise (Invalid_literal (lit, reason))) fmt

(** [component_of_lit lit ~context of_lit component] is [of_lit component], a
    rejection being reported against the enclosing literal [lit], its reason
    prefixed by [context]. *)
let component_of_lit lit ~context of_lit component =
  try of_lit component
  with Invalid_literal (_, reason) -> invalid_lit lit "%s%s" context reason

(** [rational_lit q] is the literal of the rational [q]: [Int n] if [q] is an
    [int] [n], and [Rat q] otherwise. *)
let rational_lit q =
  match Rational.to_int q with Some n -> Int n | None -> Rat q

(** [rational_tick q] is the delay [q] of a brace literal: [Tick n] if [q] is an
    [int] [n], and [Frac q] otherwise. *)
let rational_tick q =
  match Rational.to_int q with Some n -> Tick n | None -> Frac q

(** [describe_lit lit] names the form of [lit] in the plural, for messages such
    as "grades are plain integers, not pairs". *)
let describe_lit = function
  | Int _ -> "plain integers"
  | Rat _ -> "fractions such as '3/2'"
  | Name name -> "names such as '" ^ name ^ "'"
  | Top -> "'⊤'"
  | Inf -> "'∞'"
  | Tuple [ _; _ ] -> "pairs"
  | Tuple _ -> "tuples"
  | Interval _ -> "intervals '[...]'"
  | Braces _ -> "brace literals '{...}'"

(** The interval literals of the grades whose intervals are bounded below. *)
let interval_forms =
  "'[n, m]', '(n, m)', '[n, m)', '(n, m]', '[n, ∞)' or '(n, ∞)'"

(** [numeric lit] is the value of the numeric literal [lit]. *)
let numeric = function
  | Int n -> Some (Rational.of_int n)
  | Rat q -> Some q
  | _ -> None

(** [open_pair lit] is the open interval [(a, b)] if [lit] is a pair of numbers
    [a] and [b], [b] possibly [∞], and [lit] otherwise. *)
let open_pair = function
  | Tuple [ ((Int _ | Rat _) as a); ((Int _ | Rat _) as b) ] ->
      Interval (Open a, Open b)
  | Tuple [ ((Int _ | Rat _) as a); Inf ] -> Interval (Open a, Unbounded)
  | lit -> lit

(** [emptiness lo hi] is the reason the interval of the rational endpoints [lo]
    and [hi] is empty, if it is. *)
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

(** [check_nonempty ~number lit lo hi] rejects the interval literal [lit] with
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

(** [close_integer ~lower lit] is the closed endpoint that abbreviates the open
    endpoint [lit] over the integers: [n + 1] for a lower and [n - 1] for an
    upper endpoint [n], and [lit] itself if it is no integer. *)
let close_integer ~lower = function
  | Int n -> Int (if lower then n + 1 else n - 1)
  | lit -> lit

(** [integer_ends lit lo hi] is the pair of the endpoints [lo] and [hi] of the
    interval literal [lit] over the integers, closed at its finite endpoints by
    {!close_integer}.

    @raise Invalid_literal if the interval is empty, or contains no integer. *)
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

(** The interval literals of the grades whose intervals are bounded below by a
    grade and above by a grade or [∞]. *)
let bound_forms = "'[L, U]' or '[L, ∞)'"

(** [bounds_of_lit lit ~number ~close ~lower ~upper ~unbounded ~bounds] is the
    pair of the lower bound [lower l] and the upper bound [upper u] the interval
    literal [lit] = [[l, u]] denotes, the upper bound being [unbounded] in
    [\[l, ∞)]. A pair of numbers is the open interval ({!open_pair}), and an
    open numeric endpoint [a] is the closed one [close ~lower a], [lower] being
    whether it is the lower endpoint. Endpoints that both have a numeric value
    by [number] must denote a non-empty interval. [bounds] names the bounds in
    the rejection of a literal of another form. *)
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
      invalid_lit lit "intervals are written %s, not as pairs '(L, U)'"
        bound_forms
  | _ ->
      invalid_lit lit
        "grades are intervals '[{...}, {...}]' of %s, or abbreviations of \
         them, not %s"
        bounds (describe_lit lit)

(** [show_bounds lo hi] prints the interval of the printed lower bound [lo] and
    the printed upper bound [hi], [None] being unbounded. *)
let show_bounds lo = function
  | Some hi -> "[" ^ lo ^ ", " ^ hi ^ "]"
  | None -> "[" ^ lo ^ ", ∞)"
