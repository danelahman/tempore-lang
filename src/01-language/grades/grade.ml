(** Grades: partially ordered monoids with a greatest element and binary joins.

    The instances the prototype offers are defined in {!TimeGrades},
    {!TimedTraceGrades}, {!RegularTraceGrade}, {!RegularTraceGradeDerivative},
    {!RegularTraceGradePlain}, {!RegularCostTraceGrades}, {!LevelGrades} and
    {!PeakGrades}, built with the constructions of {!GradeConstructions}, and
    listed in {!GradeRegistry}; the regular trace grades are implementations of
    the same grade.

    {2 Laws}

    Under every cost model, an instance satisfies, [=] being {!S.equal}:
    - [mul] is associative, with unit [one];
    - [leq] is a preorder, whose equivalence is [equal];
    - [mul] is monotone in both arguments;
    - [join] is a least upper bound and [top] a greatest element;
    - [mul] distributes over [join] on both sides: [c · (d ⊔ e) = c · d ⊔ c · e]
      and [(d ⊔ e) · c = d · c ⊔ e · c];
    - [of_nat] is a monoid morphism from [(ℕ, +, 0)].

    {2 Cost model}

    The orders of the timed-trace grades read the runtime bounds
    [within (lo, hi)] that operations declare, and those of the cost-model
    regular trace grades also the set of the operations the program declares,
    over which their catch-all letter ranges: all of them, before or after the
    grade, so that a grade means the same throughout a program. The operations
    that depend on the order, [leq], [equal], [counterexample], [implied_bounds]
    and [inhabited], take both as an argument of type {!bounds}; the other
    grades ignore it.

    {2 Literals}

    All grade positions of the source share one literal syntax, {!lit}; each
    grade interprets the literals it understands with [of_lit] and rejects the
    others with {!Invalid_literal}. *)

(** Regular expressions over operation names and delays, the contents of a brace
    literal [{...}]. *)
type regex =
  | Letter of string  (** An operation name, e.g. [Send] *)
  | Tick of int  (** A delay of [n] time steps, e.g. [3] *)
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
    | Tick _ | Any -> []
    | Seq (r, s) | Union (r, s) | Inter (r, s) -> go r @ go s
    | Star r | Compl r -> go r
  in
  List.sort_uniq String.compare (go r)

(** Grade literals as they appear in source. *)
type lit =
  | Int of int  (** An integer, e.g. [42] or [-1] *)
  | Name of string  (** A capitalised name, e.g. [High] *)
  | Top  (** The greatest grade, [⊤] or [top] *)
  | Inf  (** Infinity, [∞] or [inf] *)
  | Tuple of lit list
      (** A parenthesised tuple of at least two literals, e.g. [(3, High)] *)
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

(** [describe_lit lit] names the form of [lit] in the plural, for messages such
    as "grades are plain integers, not pairs". *)
let describe_lit = function
  | Int _ -> "plain integers"
  | Name name -> "names such as '" ^ name ^ "'"
  | Top -> "'⊤'"
  | Inf -> "'∞'"
  | Tuple [ _; _ ] -> "pairs"
  | Tuple _ -> "tuples"
  | Braces _ -> "brace literals '{...}'"

type bounds = {
  cost : string -> int * int;
      (** The runtime bounds [(lo, hi)] declared by each operation, by name. *)
  operations : string list;
      (** The names of the operations the program declares with runtime bounds.
      *)
}
(** A cost model. *)

(** Whether a list of witnesses decides the conditions it is given for
    ({!S.witnesses}). *)
type completeness =
  | Complete
      (** a condition in one rigid that holds at every witness holds at every
          grade *)
  | Partial  (** a condition may hold at every witness and fail elsewhere *)

module type S = sig
  type t
  (** The carrier. *)

  val name : string
  (** The name of the grade, e.g. ["time-interval"]. *)

  val one : t
  (** The unit [u] of {!mul}. *)

  val mul : t -> t -> t
  (** The monoid product [_·_]. *)

  val leq : bounds -> t -> t -> bool
  (** [leq bounds c d] decides the partial order [c ≾ d] under the cost model
      [bounds]. *)

  val leq_symbol : string
  (** The notation for {!leq} in printed inequalities. *)

  val top : t
  (** The greatest grade [⊤]. *)

  val join : t -> t -> t
  (** The binary join [_⊔_]. *)

  val of_nat : int -> t
  (** [of_nat n] is the grade of [n] time steps; [of_nat 0] is {!one}. *)

  val equal : bounds -> t -> t -> bool
  (** [equal bounds c d] decides [c = d] under the cost model [bounds]. *)

  val is_top : bounds -> t -> bool
  (** [is_top bounds c] decides [⊤ ≾ c], equivalently [equal bounds c top],
      under the cost model [bounds]: from the representation of [c] where that
      decides it, and otherwise by the order once the representation is found
      not to be that of the top. *)

  val compare : t -> t -> int
  (** A total order on the representations of the grades: [compare c d = 0]
      implies [equal bounds c d] under every cost model [bounds], and the
      converse holds where the representation is canonical. *)

  val hash : t -> int
  (** A hash of the representation of a grade, compatible with {!compare}. *)

  val counterexample : bounds -> t -> t -> t option
  (** [counterexample bounds c d] is [None] if [c ≾ d] under the cost model
      [bounds], and otherwise either a grade [e] such that [e ≾ c] but not
      [e ≾ d], a witness of the failure, or [None] for grades that offer no
      witness. *)

  val unit_least : bool
  (** Whether {!one} is the least grade. *)

  val commutative : bool
  (** Whether {!mul} is commutative. *)

  val needs_op_bounds : bool
  (** Whether operation signatures must carry their runtime bounds
      [within (lo, hi)]. *)

  val implied_bounds : bounds -> t -> (int * int) option
  (** [implied_bounds bounds rho] is the pair of runtime bounds the grade [rho]
      itself implies: the duration of its fastest run, each event counted at the
      lower end of its [bounds], and the duration of its slowest run, each event
      counted at the upper end. The fastest run is taken over the lower-bound
      component of the grade and the slowest over its upper-bound component,
      which coincide for the one-sided trace grades. The time grades imply
      nothing, since there the grade of an operation already is its runtime
      bound, and return [None]; so does an unbounded upper-bound component. *)

  val inhabited : bounds -> t -> bool
  (** [inhabited bounds rho] is whether the grade [rho] denotes at least one run
      of the operations of the cost model [bounds]; the typechecker rejects the
      grades of a program that do not. It holds of every grade whose meaning
      does not depend on the declared operations. *)

  val events : t -> string list
  (** The operation names mentioned by a grade; empty for the time grades. *)

  val of_lit : lit -> t
  (** [of_lit lit] is the grade the literal [lit] denotes.

      @raise Invalid_literal if the grade does not understand [lit]. *)

  val of_bounds : int * int -> t
  (** [of_bounds (lo, hi)] is the "time shadow" of an operation declaring the
      runtime bounds [within (lo, hi)]: the grade that records nothing but the
      time such a call may take. It is the grade a default implementation of the
      operation is checked against, since the operation's own grade can only be
      realised by performing the operation itself. Each grade reads the end of
      the bounds its order uses, the two-sided ones both. *)

  val is_atomic : string -> t -> bool
  (** [is_atomic name rho] is whether [rho] is the grade of an atomic operation
      named [name], i.e. the single run consisting of [name] alone. The time
      grades name no operations and are all atomic. *)

  val show : t -> string
  (** [show rho] prints [rho] in the literal syntax, the greatest grade as [⊤]
      and infinity as [∞] where they have no other literal. *)

  val witnesses : bounds -> t list -> t list * completeness
  (** [witnesses bounds cs] is a finite list of grades at which a closed
      condition [∀j. O] whose constants are [cs] is evaluated, the rigid [j]
      ranging over the list, and its completeness: [Complete] when [O] holding
      at every witness implies [∀j. O]. A condition is an ordering between
      expressions built from the constants, [j], products and joins. The solver
      adds {!one}, {!top} and [of_nat 1] to the list. *)
end

(** [sampled mul cs] is the [Partial] list of the constants [cs] and their
    pairwise products by [mul]. *)
let sampled mul cs =
  (cs @ List.concat_map (fun c -> List.map (mul c) cs) cs, Partial)

(** [compare_array compare a b] orders arrays by length, then lexicographically
    by [compare]. *)
let compare_array compare a b =
  let n = Array.length a in
  let rec from i =
    if i = n then 0
    else match compare a.(i) b.(i) with 0 -> from (i + 1) | c -> c
  in
  match Int.compare n (Array.length b) with 0 -> from 0 | c -> c

(** [combine h h'] is a hash of a pair whose components hash to [h] and [h']. *)
let combine h h' = (h * 65599) + h'

(** [hash_list hash xs] is a hash of the list [xs] whose elements hash by
    [hash]. *)
let hash_list hash xs = List.fold_left (fun h x -> combine h (hash x)) 0 xs

(** [check_nat who n] is [n] if it is non-negative.

    @raise Invalid_argument otherwise, naming the function [who]. *)
let check_nat who n =
  if n < 0 then invalid_arg (who ^ ".of_nat: expected non-negative integer")
  else n
