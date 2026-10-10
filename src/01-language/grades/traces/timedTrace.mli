(** Traces and non-empty finite sets of them, the carrier of the trace grading
    monoids.

    A trace is one run of a computation as it is observed from outside: an
    alternation of operation events and positive delays. A grade is a set of
    such traces, read disjunctively, multiplied by the language product. The
    sets over a monoid of delays ({!Delay.S}) are ordered by inclusion
    ({!Base}). The two orders of timed operations ({!Make}) are allowance (an
    upper bound: "every trace fits inside the bound") and coverage (a lower
    bound: "the trace covers the guarantee"), each defined on single traces and
    then lifted to sets.

    The delays of the orders of timed operations are those of an ordered monoid
    with monus ({!Delay.MONUS}): the orders bank delays in a budget with [add]
    and spend them with [monus].

    {2 Canonical representation}

    Every function here that produces a [trace] or a [traces] returns the
    canonical normal form: a trace contains no [Wait zero] and no two adjacent
    [Wait]s, and a set of traces is sorted by [compare] and duplicate-free.
    Anything building a value of these types outside this module must go through
    [normalise] and [of_list]. *)

(** The traces over the delays [D], their product, union, inclusion and
    literals. *)
module Base (D : Delay.S) : sig
  type event =
    | Ev of string  (** an operation event, named by its surface name *)
    | Wait of D.t  (** a delay; in normal form its duration is not [zero] *)

  type trace = event list
  (** One trace. Normal form: no [Wait zero], no two adjacent [Wait]s. *)

  type traces = trace list
  (** A non-empty finite set of traces. Normal form: sorted and duplicate-free.
  *)

  val compare : traces -> traces -> int
  (** [compare p q] orders the sets of traces lexicographically. *)

  val equal : traces -> traces -> bool
  (** [equal p q] decides [compare p q = 0]. *)

  val hash : traces -> int
  (** [hash p] is a hash of [p] compatible with {!compare}. *)

  val normalise : event list -> trace
  (** [normalise evs] is the trace denoted by the raw event sequence [evs]: zero
      delays are dropped and adjacent delays are merged. This invariant is what
      makes [of_delay (add m n)] equal to the product of [of_delay m] and
      [of_delay n] on the nose. *)

  val concat : trace -> trace -> trace
  (** [concat s t] is the trace monoid [_∙_]: the trailing delay of [s] is
      merged with the leading delay of [t]. *)

  val of_list : event list list -> traces
  (** [of_list ts] is the canonical set of traces denoted by the raw list [ts].
  *)

  val product : traces -> traces -> traces
  (** [product p q] is the language product: every trace of [p] sequenced with
      every trace of [q]. *)

  val union : traces -> traces -> traces
  (** [union p q] is the set of the traces of [p] and of [q]. *)

  val of_delay : D.t -> traces
  (** [of_delay n] is the singleton set containing the pure delay of duration
      [n]; [of_delay zero] is the unit [{ε}]. *)

  val missing : traces -> traces -> trace option
  (** [missing p q] is the least trace of [p] that [q] does not list, if any,
      found by a merge of the two sorted sets. *)

  val subset : traces -> traces -> bool
  (** [subset p q] decides the inclusion of the set of traces [p] in [q]. *)

  val events : traces -> string list
  (** [events p] lists, sorted and without repetitions, the operation names
      mentioned anywhere in [p]. *)

  val show : traces -> string
  (** [show p] prints a set of traces as [{Read; 3; Send | Send; Send}]; the
      empty trace prints as [0], the delay [zero] it denotes. *)

  val number : GradeLiteral.lit -> Rational.t option
  (** [number lit] is the value of the numeric literal [lit] if it or its
      negation is a delay. *)

  val of_lit : number:string -> GradeLiteral.lit -> traces
  (** [of_lit ~number:n lit] is the set of traces the one-sided literal [lit]
      denotes, [n] naming the literals of the delays in the singular. A negative
      number is rejected as such where its absolute value is a delay. *)
end

(** The traces over the delays [D] with the orders of timed operations. *)
module Make (D : Delay.MONUS) : sig
  include module type of struct
    include Base (D)
  end

  val allowance : (string -> D.t) -> D.t -> trace -> trace -> bool
  (** [allowance running_time k s t] decides the allowance order at budget [k]:
      the bound [t] permits the trace [s], given [k] units of budget already
      banked. Budget comes from the bound's delays and is spent on the trace's
      delays and on operations the bound does not name, at their [running_time];
      a matched operation resets the budget, so slack the bound offers before an
      operation it names is spent before that operation or not at all. *)

  val coverage : (string -> D.t) -> D.t -> trace -> trace -> bool
  (** [coverage running_time k s t] decides the coverage order at budget [k]:
      the trace [t] covers the guarantee [s], given [k] units of slack already
      banked. Slack comes from whatever [t] did that [s] did not demand, its
      unmatched operations at their [running_time] and its delays at their
      length, and is spent only on delays [s] demands. Nothing but the operation
      itself discharges a demand for an operation, which is what a guarantee
      wants and what makes this order not the converse of {!allowance}. *)

  val upper_bound_le : (string -> D.t) -> traces -> traces -> bool
  (** [upper_bound_le running_time p q] is the Hoare lift of the allowance
      order, the order of the lower powerdomain: every bound listed by [p] stays
      within some bound listed by [q]. This is the sub-grade order of the
      upper-bound (right-sided) grade. *)

  val lower_bound_le : (string -> D.t) -> traces -> traces -> bool
  (** [lower_bound_le running_time p q] is the Smyth lift of the coverage order,
      the order of the upper powerdomain: every guarantee listed by [p] has an
      easier one listed by [q]. Note the direction: the universal quantifier
      ranges over [p], but each witness [t] is compared against [s] the other
      way round, as an argument to {!coverage} with [t] and [s] swapped. This is
      the sub-grade order of the lower-bound (left-sided) grade. *)
end
