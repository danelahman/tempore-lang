(** The strict delays of the rigid grades of timed operations, in the languages
    of timed words.

    A delay of a timed word is a budget, which the orders may fill with
    operations, or strict, a wait that admits nothing else. A strict delay [d]
    is encoded as the word [o d c], [o] and [c] the names
    {!GradeLiteral.strict_opening} and {!GradeLiteral.strict_closing}, which are
    no operation names: the delays between them are strict. The words of the
    rigid grades are the {e well-formed} words, built from budget delays,
    operations and such encoded strict delays, [(ℚ>0 | Σ | o ℚ>0 c)*], [Σ] the
    operation names. Adjacent strict delays of a word are not merged into one:
    the orders divide a strict delay of a word among the strict delays of a
    bound, so that a word and the one with merged strict delays have the same
    closures.

    The expressions of a brace literal are translated as by the grades without
    strict delays, except that a strict delay [!r] denotes the encoded strict
    delays of the delays of [r], and the delay [0] if [r] has it; [_] denotes
    every operation, every positive budget delay and every positive strict
    delay, over whole time steps a single budget step; [!_] every operation and
    every positive strict delay; and a complement is taken relative to the
    well-formed words. *)

(** The expressions of a kind of languages. *)
module type EXPRESSION = sig
  type t

  val eps : t
  (** The empty word. *)

  val name : string -> t
  (** [name n] is the one-operation word [n], for any name [n]. *)

  val operations : t
  (** The one-operation words of every operation name, the names
      {!GradeLiteral.strict_opening} and {!GradeLiteral.strict_closing} left
      out. *)

  val delay : t
  (** The budget delays of [_]: every positive delay, or a single time step. *)

  val positive : t
  (** Every positive delay. *)

  val of_delays : GradeLiteral.regex -> t
  (** [of_delays r] is the language of an expression of delays [r]
      ({!GradeLiteral.delays_only}). *)

  val nullable : t -> bool
  val concat : t -> t -> t
  val union : t list -> t
  val inter : t list -> t
  val compl : t -> t
  val star : t -> t
end

(** The strict delays in the expressions [E]. *)
module Make (E : EXPRESSION) : sig
  val strict : E.t -> E.t
  (** [strict s] is the language of the strict delays of the delays of [s], an
      expression of delays: their encodings, and the empty word if [s] has the
      delay [0]. *)

  val words : E.t
  (** The well-formed words. *)

  val of_regex : GradeLiteral.regex -> E.t
  (** [of_regex r] is the language of the brace literal [r] under the rigid
      grades. *)
end

(** The literals, the delays and the top of a grade under the rigid grades of
    timed operations: a brace literal is read by {!Make.of_regex}, a plain
    number is the budget delay it is, the grade of a delay [d] is the strict
    delay [!d], and the top is the language of the well-formed words. *)
module type GRADE = sig
  type grade
  type delay

  val of_lit : GradeLiteral.lit -> grade
  val accepts : GradeLiteral.lit -> bool
  val of_delay : delay -> grade
  val top : grade
end

(** The literals, delays and top of the grade [L] itself, for the rigid grades
    over a grade without strict delays. *)
module Without (L : Grade.S) :
  GRADE with type grade = L.t and type delay = L.Delay.t

val has_markers : string list -> bool
(** [has_markers names] is whether the names [names] include
    {!GradeLiteral.strict_opening} or {!GradeLiteral.strict_closing}. *)

val operations : string list -> string list
(** [operations names] is [names] without {!GradeLiteral.strict_opening} and
    {!GradeLiteral.strict_closing}. *)

val markers : string list
(** {!GradeLiteral.strict_opening} and {!GradeLiteral.strict_closing}, in
    increasing order. *)
