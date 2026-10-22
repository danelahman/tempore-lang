(** Grade literals: the literal syntax shared by all grade positions of the
    source. Each grade interprets the literals it understands
    ({!Grade.S.of_lit}) and rejects the others with {!Invalid_literal}; delays
    read the numeric ones ({!Delay.S.read}). *)

(** An endpoint of an interval. *)
type 'a bound =
  | Closed of 'a  (** A finite endpoint the interval contains *)
  | Open of 'a  (** A finite endpoint the interval excludes *)
  | Unbounded  (** An infinite endpoint *)

val show_interval : ('a -> string) -> 'a bound -> 'a bound -> string
(** [show_interval show lo hi] prints the interval from [lo] to [hi], its finite
    endpoints printed by [show], e.g. [\[1, 2)] or [(1/2, ∞)]. *)

(** Regular expressions over operation names and delays, the contents of a brace
    literal [{...}]. *)
type regex =
  | Letter of string  (** An operation name, e.g. [Send] *)
  | Tick of int  (** A delay of [n] time steps, e.g. [3] *)
  | Frac of Rational.t  (** A delay that is not an [int], e.g. [1/2] or [1.5] *)
  | Delays of Rational.t bound * Rational.t bound
      (** The delays in an interval with a finite lower endpoint, e.g. [\[0, 1)]
          or [(1/2, ∞)] *)
  | Below of Rational.t bound
      (** The lengths up to an upper end, [≤d] ([Closed d]), [<d] ([Open d]) or
          [≤∞] ([Unbounded]), ASCII [<=d] *)
  | Above of Rational.t bound
      (** The lengths from a lower end, [≥d] ([Closed d]) or [>d] ([Open d]),
          ASCII [>=d] *)
  | Any
      (** Any single operation or time step, [_]; over rational delays, any
          single operation or positive delay *)
  | Seq of regex * regex  (** Concatenation, [r; s] *)
  | Union of regex * regex  (** Union, [r | s] *)
  | Star of regex  (** Repetition, [r*] *)
  | Repeat of regex * Count.t
      (** Bounded repetition, [r^n], [r^[m, n]] or [r^\[m, ∞)]: the
          concatenations of [k] words of [r], [k] in the count *)
  | Inter of regex * regex  (** Intersection, [r & s] *)
  | Compl of regex  (** Complement, [~r] *)
  | Strict of regex
      (** A strict delay, [idle r], [r] the wildcard [_] or an expression of
          delays only ({!delays_only}): [idle 3], [idle [2, 3]], [idle _] *)

val delays_only : regex -> bool
(** [delays_only r] is whether [r] is built from delays and intervals of delays
    by [;], [|], [&] and [*] alone, so that its words are delays. *)

val show_below : Rational.t bound -> string
(** [show_below b] prints the letter [Below b], e.g. [≤3] or [<1/2]. *)

val show_above : Rational.t bound -> string
(** [show_above b] prints the letter [Above b], e.g. [≥3] or [>1/2]. *)

val unrolled : regex -> Count.t -> regex
(** [unrolled r c] is an expression of [r^c] without bounded repetition:
    [r; …; r; (0 | r; (0 | r; …))] for [c = [m, n]], with [m] factors [r] and
    [n - m] optional ones, and [r; …; r; r*] for [c = \[m, ∞)]. *)

val equal_regex : regex -> regex -> bool
(** [equal_regex r s] is whether [r] and [s] are the same expression. *)

val sequence : regex list -> regex
(** [sequence factors] is the concatenation of [factors], [0] if there are none,
    every run of two or more adjacent factors of the same base joined into one
    bounded repetition: [x; x; x] is [x^3], and [x^c; x] is [x^(c + 1)]. The
    factors are not split into further factors. *)

val regex_names : regex -> string list
(** [regex_names r] is the list of the operation names [r] mentions, in
    increasing order. *)

val show_regex : regex -> string
(** [show_regex r] prints [r] as the contents of a brace literal, with the
    parentheses the precedences require: union [|], intersection [&],
    concatenation [;], complement [~] and repetition [*] and [^], by increasing
    precedence, a strict delay [idle r] as an atom, parenthesised under a
    bounded repetition. The three binary operators are printed as associative,
    and a fraction under a repetition is parenthesised. *)

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

val invalid_lit : lit -> ('a, unit, string, 'b) format4 -> 'a
(** [invalid_lit lit fmt] raises {!Invalid_literal} on [lit] with the reason
    formatted by [fmt]. *)

val read_lit : (lit -> 'a) -> lit -> ('a, lit * string) result
(** [read_lit of_lit lit] is [Ok (of_lit lit)], and [Error (lit', reason)] if
    [of_lit] rejects [lit'] with [reason] instead. *)

val reads_lit : (lit -> 'a) -> lit -> bool
(** [reads_lit of_lit lit] is whether [of_lit] reads [lit] without rejecting it,
    [Result.is_ok (read_lit of_lit lit)]. *)

val require : (lit -> bool) -> lit -> unit
(** [require accepts lit] is [()] if [accepts lit]: a reader that builds
    nothing, in place of a reader of grades whose acceptance [accepts] decides,
    within a reader of composite literals.

    @raise Invalid_literal on [lit] if [accepts lit] does not hold. *)

val component_of_lit : lit -> context:string -> ('a -> 'b) -> 'a -> 'b
(** [component_of_lit lit ~context of_lit component] is [of_lit component], a
    rejection being reported against the enclosing literal [lit], its reason
    prefixed by [context]. *)

val distinct_entries :
  lit ->
  compare:('k -> 'k -> int) ->
  twice:('k -> string) ->
  ('k * 'a) list ->
  ('k * 'a) list
(** [distinct_entries lit ~compare ~twice entries] is [entries] sorted by their
    keys in the order [compare].

    @raise Invalid_literal
      on [lit] with the reason [twice k] if two entries have the same key [k].
*)

val strict_unsupported : regex -> 'a
(** [strict_unsupported r] rejects the strict delay [r], [idle d], under a grade
    other than the rigid grades of timed operations.

    @raise Invalid_literal on the brace literal of [r]. *)

val one_sided_unsupported : regex -> 'a
(** [one_sided_unsupported r] rejects the one-sided letter [r], [≤d] or [≥d],
    under a grade other than the rigid grades of timed operations.

    @raise Invalid_literal on the brace literal of [r]. *)

val rational_lit : Rational.t -> lit
(** [rational_lit q] is the literal of the rational [q]: [Int n] if [q] is an
    [int] [n], and [Rat q] otherwise. *)

val rational_tick : Rational.t -> regex
(** [rational_tick q] is the delay [q] of a brace literal: [Tick n] if [q] is an
    [int] [n], and [Frac q] otherwise. *)

val describe_lit : lit -> string
(** [describe_lit lit] names the form of [lit] in the plural, for messages such
    as "grades are plain integers, not pairs". *)

val interval_forms : string
(** The interval literals of the grades whose intervals are bounded below. *)

val open_pair : lit -> lit
(** [open_pair lit] is the open interval [(a, b)] if [lit] is a pair of numbers
    [a] and [b], [b] possibly [∞], and [lit] otherwise. *)

val emptiness : Rational.t bound -> Rational.t bound -> string option
(** [emptiness lo hi] is the reason the interval of the rational endpoints [lo]
    and [hi] is empty, if it is. *)

val close_integer : lower:bool -> lit -> lit
(** [close_integer ~lower lit] is the closed endpoint that abbreviates the open
    endpoint [lit] over the integers: [n + 1] for a lower and [n - 1] for an
    upper endpoint [n], and [lit] itself if it is no integer. *)

val integer_ends : lit -> lit bound -> lit bound -> lit bound * lit bound
(** [integer_ends lit lo hi] is the pair of the endpoints [lo] and [hi] of the
    interval literal [lit] over the integers, closed at its finite endpoints by
    {!close_integer}.

    @raise Invalid_literal if the interval is empty, or contains no integer. *)

val bounds_of_lit :
  lit ->
  number:(lit -> Rational.t option) ->
  close:(lower:bool -> lit -> lit) ->
  lower:(lit -> 'a) ->
  upper:(lit -> 'b) ->
  unbounded:'b ->
  bounds:string ->
  'a * 'b
(** [bounds_of_lit lit ~number ~close ~lower ~upper ~unbounded ~bounds] is the
    pair of the lower bound [lower l] and the upper bound [upper u] the interval
    literal [lit] = [[l, u]] denotes, the upper bound being [unbounded] in
    [\[l, ∞)]. A pair of numbers is the open interval ({!open_pair}), and an
    open numeric endpoint [a] is the closed one [close ~lower a], [lower] being
    whether it is the lower endpoint. Endpoints that both have a numeric value
    by [number] must denote a non-empty interval. [bounds] names the bounds in
    the rejection of a literal of another form. *)

val show_bounds : string -> string option -> string
(** [show_bounds lo hi] prints the interval of the printed lower bound [lo] and
    the printed upper bound [hi], [None] being unbounded. *)
