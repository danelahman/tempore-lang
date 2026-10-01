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
    [Wait]s, and a set of traces is sorted by {!compare} and duplicate-free.
    Anything building a value of these types outside this module must go through
    {!normalise} and {!of_list}. *)

(** The traces over the delays [D], their product, union, inclusion and
    literals. *)
module Base (D : Delay.S) = struct
  type event =
    | Ev of string  (** an operation event, named by its surface name *)
    | Wait of D.t  (** a delay; in normal form its duration is not [zero] *)

  type trace = event list
  (** One trace. Normal form: no [Wait zero], no two adjacent [Wait]s. *)

  type traces = trace list
  (** A non-empty finite set of traces. Normal form: sorted and duplicate-free,
      as produced by [List.sort_uniq compare_trace]. *)

  (** [compare_event e e'] orders the events, operations before delays, the
      operations by name and the delays by duration. *)
  let compare_event e e' =
    match (e, e') with
    | Ev o, Ev o' -> String.compare o o'
    | Ev _, Wait _ -> -1
    | Wait _, Ev _ -> 1
    | Wait n, Wait n' -> D.compare n n'

  (** [compare_trace s t] orders the traces lexicographically by
      {!compare_event}. *)
  let compare_trace = List.compare compare_event

  (** [compare p q] orders the sets of traces lexicographically by
      {!compare_trace}. *)
  let compare = List.compare compare_trace

  let equal p q = compare p q = 0
  let hash_event = function Ev o -> String.hash o | Wait n -> D.hash n
  let hash_trace = Grade.hash_list hash_event

  (** [hash p] is a hash of [p] compatible with {!compare}. *)
  let hash = Grade.hash_list hash_trace

  (** [normalise evs] is the trace denoted by the raw event sequence [evs]: zero
      delays are dropped and adjacent delays are merged. This invariant is what
      makes [of_delay (add m n)] equal to the product of [of_delay m] and
      [of_delay n] on the nose. *)
  let normalise evs =
    let rec go acc = function
      | [] -> List.rev acc
      | Wait n :: rest when D.equal n D.zero -> go acc rest
      | Wait n :: rest -> (
          match acc with
          | Wait m :: acc' -> go (Wait (D.add m n) :: acc') rest
          | _ -> go (Wait n :: acc) rest)
      | (Ev _ as e) :: rest -> go (e :: acc) rest
    in
    go [] evs

  (** [concat s t] is the trace monoid [_∙_]: the trailing delay of [s] is
      merged with the leading delay of [t]. *)
  let concat s t = normalise (s @ t)

  (** [of_list ts] is the canonical set of traces denoted by the raw list [ts].
  *)
  let of_list ts = List.sort_uniq compare_trace (List.map normalise ts)

  (** [product p q] is the language product: every trace of [p] sequenced with
      every trace of [q]. *)
  let product p q =
    List.sort_uniq compare_trace
      (List.concat_map (fun s -> List.map (fun t -> concat s t) q) p)

  (** [union p q] is the set of the traces of [p] and of [q]. *)
  let union p q = List.sort_uniq compare_trace (p @ q)

  (** [of_delay n] is the singleton set containing the pure delay of duration
      [n]; [of_delay zero] is the unit [{ε}]. *)
  let of_delay n = [ normalise [ Wait n ] ]

  (** [missing p q] is the least trace of [p] that [q] does not list, if any,
      found by a merge of the two sorted sets. *)
  let rec missing p q =
    match (p, q) with
    | [], _ -> None
    | s :: _, [] -> Some s
    | s :: p', t :: q' -> (
        match compare_trace s t with
        | 0 -> missing p' q'
        | c when c > 0 -> missing p q'
        | _ -> Some s)

  (** [subset p q] decides the inclusion of the set of traces [p] in [q]. *)
  let subset p q = Option.is_none (missing p q)

  (** [events p] lists, sorted and without repetitions, the operation names
      mentioned anywhere in [p]. *)
  let events p =
    List.sort_uniq String.compare
      (List.concat_map
         (List.filter_map (function Ev o -> Some o | Wait _ -> None))
         p)

  let show_event = function Ev o -> o | Wait n -> D.show n

  (** [show_trace t] prints a trace as [Read; 3; Send]; the empty trace prints
      as [0], the delay [zero] it denotes. *)
  let show_trace = function
    | [] -> D.show D.zero
    | t -> String.concat "; " (List.map show_event t)

  (** [show p] prints a set of traces as [{Read; 3; Send | Send; Send}]. *)
  let show p = "{" ^ String.concat " | " (List.map show_trace p) ^ "}"

  (** {2 Literals} *)

  open GradeLiteral

  (** [delay_of_lit lit tick] is the delay the numeric literal [tick], part of
      the literal [lit], denotes. *)
  let delay_of_lit lit tick =
    match D.read tick with
    | Some d -> d
    | None -> invalid_lit lit "%s" (D.rejection tick)

  (** [of_regex lit r] is the set of traces the star-free regular expression
      [r], without [&], [~] or [_], denotes; [lit] is the literal it is part of.
  *)
  let rec of_regex lit = function
    | Letter name -> [ [ Ev name ] ]
    | Tick n -> of_delay (delay_of_lit lit (Int n))
    | Frac q -> of_delay (delay_of_lit lit (Rat q))
    | Seq (r, s) -> binary lit product r s
    | Union (r, s) -> binary lit union r s
    | Star _ -> unsupported lit "repetition '*'"
    | Inter _ -> unsupported lit "intersection '&'"
    | Compl _ -> unsupported lit "complement '~'"
    | Any -> unsupported lit "the wildcard '_'"
    | Delays (lo, hi) ->
        unsupported lit
          ("the interval of delays '" ^ show_interval Rational.show lo hi ^ "'")

  (* The operands are read left to right, so the leftmost unsupported form is
     the one reported. *)
  and binary lit combine r s =
    let p = of_regex lit r in
    let q = of_regex lit s in
    combine p q

  and unsupported lit form =
    invalid_lit lit
      "sets of traces are built from operation names and delays with ';' and \
       '|' only, without %s"
      form

  (** [number lit] is the value of the numeric literal [lit] if it or its
      negation is a delay. *)
  let number lit =
    let value = function
      | Int n -> Some (Rational.of_int n)
      | Rat q -> Some q
      | _ -> None
    in
    let delay q = Option.is_some (D.read (rational_lit q)) in
    Option.bind (value lit) (fun q ->
        if delay q || delay (Rational.neg q) then Some q else None)

  (** [of_lit ~number:n lit] is the set of traces the one-sided literal [lit]
      denotes, [n] naming the literals of the delays in the singular. A negative
      number is rejected as such where its absolute value is a delay. *)
  let of_lit ~number:n = function
    | Braces r as lit -> of_regex lit r
    | lit -> (
        match D.read lit with
        | Some d -> of_delay d
        | None when Option.is_some (number lit) ->
            invalid_lit lit "grades must be non-negative"
        | None ->
            invalid_lit lit
              "grades are a single set of traces '{...}' or a plain %s, not %s"
              n (describe_lit lit))
end

(** The traces over the delays [D] with the orders of timed operations. *)
module Make (D : Delay.MONUS) = struct
  include Base (D)

  (** [allowance running_time k s t] decides the allowance order at budget [k]:
      the bound [t] permits the trace [s], given [k] units of budget already
      banked. Budget comes from the bound's delays and is spent on the trace's
      delays and on operations the bound does not name, at their [running_time];
      a matched operation resets the budget, so slack the bound offers before an
      operation it names is spent before that operation or not at all.

      Each rule shrinks [s] or [t], so the plain backtracking search terminates.
      The [when] guards are the backtracking: a failing guard falls through to
      the next rule. *)
  let rec allowance running_time k s t =
    match (s, t) with
    | [], _ -> true (* nil *)
    | Ev o :: s', Ev o' :: t' when o = o' && allowance running_time D.zero s' t'
      ->
        true (* keep: the budget does not cross a match *)
    | _, Ev _ :: t' when allowance running_time k s t' -> true (* skip-op *)
    | _, Wait e :: t' when allowance running_time (D.add k e) s t' ->
        true (* bank-delay *)
    | Wait d :: s', _
      when D.leq d k && allowance running_time (D.monus k d) s' t ->
        true (* use-delay *)
    | Ev o :: s', _
      when D.leq (running_time o) k
           && allowance running_time (D.monus k (running_time o)) s' t ->
        true (* use-op *)
    | _ -> false

  (** [coverage running_time k s t] decides the coverage order at budget [k]:
      the trace [t] covers the guarantee [s], given [k] units of slack already
      banked. Slack comes from whatever [t] did that [s] did not demand — its
      unmatched operations at their [running_time] and its delays at their
      length — and is spent only on delays [s] demands. Nothing but the
      operation itself discharges a demand for an operation, which is what a
      guarantee wants and what makes this order not the converse of
      {!allowance}. *)
  let rec coverage running_time k s t =
    match (s, t) with
    | [], _ -> true (* nil *)
    | Ev o :: s', Ev o' :: t' when o = o' && coverage running_time D.zero s' t'
      ->
        true (* keep: the slack does not cross a match *)
    | _, Ev o :: t' when coverage running_time (D.add k (running_time o)) s t'
      ->
        true (* pay-op *)
    | _, Wait e :: t' when coverage running_time (D.add k e) s t' ->
        true (* del-delay *)
    | Wait d :: s', _ when D.leq d k && coverage running_time (D.monus k d) s' t
      ->
        true (* use-delay *)
    | _ -> false

  (** [upper_bound_le running_time p q] is the Hoare lift of the allowance
      order, the order of the lower powerdomain: every bound listed by [p] stays
      within some bound listed by [q]. This is the sub-grade order of the
      upper-bound (right-sided) grade. *)
  let upper_bound_le running_time p q =
    List.for_all
      (fun s -> List.exists (fun t -> allowance running_time D.zero s t) q)
      p

  (** [lower_bound_le running_time p q] is the Smyth lift of the coverage order,
      the order of the upper powerdomain (Smyth, JCSS 1978): every guarantee
      listed by [p] has an easier one listed by [q]. Note the direction: the
      universal quantifier ranges over [p], but each witness [t] is compared
      against [s] the other way round, as an argument to {!coverage} with [t]
      and [s] swapped. This is the sub-grade order of the lower-bound
      (left-sided) grade. *)
  let lower_bound_le running_time p q =
    List.for_all
      (fun s -> List.exists (fun t -> coverage running_time D.zero t s) q)
      p
end
