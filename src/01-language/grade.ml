(** Grades: partially ordered monoids with a greatest element and binary joins.

    The instances the prototype offers are defined in {!TimeGrades},
    {!TimedTraceGrades}, {!RegularTraceGrade}, {!RegularTraceGradeDerivative}
    and {!LevelGrades}, built with the constructions of {!GradeConstructions},
    and listed in {!GradeRegistry}; the two regular trace grades are two
    implementations of the same grade.

    {2 Cost model}

    The orders of the timed-trace grades read the runtime bounds
    [within (lo, hi)] that operations declare. The operations that depend on the
    order, [leq] and [equal], take them as an argument of type {!bounds}; the
    other grades ignore it.

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

(** Grade literals as they appear in source. *)
type lit =
  | Int of int  (** A non-negative integer, e.g. [42] *)
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

type bounds = string -> int * int
(** A cost model: the runtime bounds [(lo, hi)] declared by each operation,
    given by name. *)

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
end

(** [check_nat who n] is [n] if it is non-negative.

    @raise Invalid_argument otherwise, naming the function [who]. *)
let check_nat who n =
  if n < 0 then invalid_arg (who ^ ".of_nat: expected non-negative integer")
  else n
