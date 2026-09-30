(** Grade literals: the literal syntax shared by all grade positions of the
    source. Each grade interprets the literals it understands
    ({!Grade.S.of_lit}) and rejects the others with {!Invalid_literal}; delays
    read the numeric ones ({!Delay.S.read}). *)

(** Regular expressions over operation names and delays, the contents of a brace
    literal [{...}]. *)
type regex =
  | Letter of string  (** An operation name, e.g. [Send] *)
  | Tick of int  (** A delay of [n] time steps, e.g. [3] *)
  | Frac of Rational.t  (** A delay that is not an [int], e.g. [1/2] or [1.5] *)
  | Any  (** Any single operation or time step, [_] *)
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
    | Tick _ | Frac _ | Any -> []
    | Seq (r, s) | Union (r, s) | Inter (r, s) -> go r @ go s
    | Star r | Compl r -> go r
  in
  List.sort_uniq String.compare (go r)

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
  | Interval of lit option * lit option
      (** An interval of numbers, closed at its finite endpoints, [None] being
          an infinite one: [[1, 4]], [\[1/2, ∞)], [(-∞, 3\]] or [(-∞, ∞)] *)
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
let interval_forms = "'[n, m]' or '[n, ∞)'"

(** [is_pair_interval lit] holds iff [lit] is a pair of numbers, the second
    possibly [∞], which denotes no interval. *)
let is_pair_interval = function
  | Tuple [ (Int _ | Rat _); (Int _ | Rat _ | Inf) ] -> true
  | _ -> false

(** [reject_pair_interval lit] rejects the pair [lit] of numbers in place of an
    interval, naming the interval literals. *)
let reject_pair_interval lit =
  invalid_lit lit "intervals are written %s, not as pairs '(n, m)'"
    interval_forms
