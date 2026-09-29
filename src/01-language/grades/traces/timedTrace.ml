(** Traces and non-empty finite sets of them, the carrier of the trace grading
    monoids.

    A trace is one run of a computation as it is observed from outside: an
    alternation of operation events and positive delays. A grade is a set of
    such runs, read disjunctively, multiplied by the language product. The two
    orders below are allowance (an upper bound: "every run fits inside the
    bound") and coverage (a lower bound: "the run covers the guarantee"), each
    defined on single runs and then lifted to sets.

    {2 Canonical representation}

    Every function here that produces a [trace] or a [traces] returns the
    canonical normal form: a trace contains no [Wait 0] and no two adjacent
    [Wait]s, and a set of traces is sorted by {!compare} and duplicate-free.
    Anything building a value of these types outside this module must go through
    {!normalise} and {!of_list}. *)

type event =
  | Ev of string  (** an operation event, named by its surface name *)
  | Wait of int  (** a delay; in normal form its duration is at least 1 *)

type trace = event list
(** One run. Normal form: no [Wait 0], no two adjacent [Wait]s. *)

type traces = trace list
(** A non-empty finite set of runs. Normal form: sorted and duplicate-free, as
    produced by [List.sort_uniq compare_trace]. *)

(** [compare_event e e'] orders the events, operations before delays, the
    operations by name and the delays by duration. *)
let compare_event e e' =
  match (e, e') with
  | Ev o, Ev o' -> String.compare o o'
  | Ev _, Wait _ -> -1
  | Wait _, Ev _ -> 1
  | Wait n, Wait n' -> Int.compare n n'

(** [compare_trace s t] orders the runs lexicographically by {!compare_event}.
*)
let compare_trace = List.compare compare_event

(** [compare p q] orders the sets of runs lexicographically by {!compare_trace}.
*)
let compare = List.compare compare_trace

let equal p q = compare p q = 0
let hash_event = function Ev o -> String.hash o | Wait n -> Int.hash n
let hash_trace = Grade.hash_list hash_event

(** [hash p] is a hash of [p] compatible with {!compare}. *)
let hash = Grade.hash_list hash_trace

(** [normalise evs] is the trace denoted by the raw event sequence [evs]: zero
    delays are dropped and adjacent delays are merged. This invariant is what
    makes [of_delay (m + n)] equal to the product of [of_delay m] and
    [of_delay n] on the nose. *)
let normalise evs =
  let rec go acc = function
    | [] -> List.rev acc
    | Wait n :: rest when n <= 0 -> go acc rest
    | Wait n :: rest -> (
        match acc with
        | Wait m :: acc' -> go (Wait (m + n) :: acc') rest
        | _ -> go (Wait n :: acc) rest)
    | (Ev _ as e) :: rest -> go (e :: acc) rest
  in
  go [] evs

(** [concat s t] is the trace monoid [_∙_]: the trailing delay of [s] is merged
    with the leading delay of [t]. *)
let concat s t = normalise (s @ t)

(** [of_list ts] is the canonical set of traces denoted by the raw list [ts]. *)
let of_list ts = List.sort_uniq compare_trace (List.map normalise ts)

(** [product p q] is the language product: every run of [p] sequenced with every
    run of [q]. *)
let product p q =
  List.sort_uniq compare_trace
    (List.concat_map (fun s -> List.map (fun t -> concat s t) q) p)

(** [union p q] is the set of the runs of [p] and of [q]. *)
let union p q = List.sort_uniq compare_trace (p @ q)

(** [of_delay n] is the singleton set containing the pure delay of duration [n];
    [of_delay 0] is the unit [{ε}]. *)
let of_delay n = [ normalise [ Wait n ] ]

(** [allowance cost k s t] decides the allowance order at budget [k]: the bound
    [t] permits the run [s], given [k] units of budget already banked. Budget
    comes from the bound's delays and is spent on the run's delays and on
    operations the bound does not name, at their [cost]; a matched operation
    resets the budget, so slack the bound offers before an operation it names is
    spent before that operation or not at all.

    Each rule shrinks [s] or [t], so the plain backtracking search terminates.
    The [when] guards are the backtracking: a failing guard falls through to the
    next rule. *)
let rec allowance cost k s t =
  match (s, t) with
  | [], _ -> true (* nil *)
  | Ev o :: s', Ev o' :: t' when o = o' && allowance cost 0 s' t' ->
      true (* keep: the budget does not cross a match *)
  | _, Ev _ :: t' when allowance cost k s t' -> true (* skip-op *)
  | _, Wait e :: t' when allowance cost (k + e) s t' -> true (* bank-delay *)
  | Wait d :: s', _ when d <= k && allowance cost (k - d) s' t ->
      true (* use-delay *)
  | Ev o :: s', _ when cost o <= k && allowance cost (k - cost o) s' t ->
      true (* use-op *)
  | _ -> false

(** [coverage cost k s t] decides the coverage order at budget [k]: the run [t]
    covers the guarantee [s], given [k] units of slack already banked. Slack
    comes from whatever [t] did that [s] did not demand — its unmatched
    operations at their [cost] and its delays at their length — and is spent
    only on delays [s] demands. Nothing but the operation itself discharges a
    demand for an operation, which is what a guarantee wants and what makes this
    order not the converse of {!allowance}. *)
let rec coverage cost k s t =
  match (s, t) with
  | [], _ -> true (* nil *)
  | Ev o :: s', Ev o' :: t' when o = o' && coverage cost 0 s' t' ->
      true (* keep: the slack does not cross a match *)
  | _, Ev o :: t' when coverage cost (k + cost o) s t' -> true (* pay-op *)
  | _, Wait e :: t' when coverage cost (k + e) s t' -> true (* del-delay *)
  | Wait d :: s', _ when d <= k && coverage cost (k - d) s' t ->
      true (* use-delay *)
  | _ -> false

(** [upper_bound_le cost p q] is the Hoare lift of the allowance order, the
    order of the lower powerdomain: every bound listed by [p] stays within some
    bound listed by [q]. This is the sub-grade order of the upper-bound
    (right-sided) grade. *)
let upper_bound_le cost p q =
  List.for_all (fun s -> List.exists (fun t -> allowance cost 0 s t) q) p

(** [lower_bound_le cost p q] is the Smyth lift of the coverage order, the order
    of the upper powerdomain (Smyth, JCSS 1978): every guarantee listed by [p]
    has an easier one listed by [q]. Note the direction: the universal
    quantifier runs over [p], but each witness [t] is compared against [s] the
    other way round, as an argument to {!coverage} with [t] and [s] swapped.
    This is the sub-grade order of the lower-bound (left-sided) grade. *)
let lower_bound_le cost p q =
  List.for_all (fun s -> List.exists (fun t -> coverage cost 0 t s) q) p

(** [duration cost t] is the time the run [t] takes: every delay counts its
    length and every operation event counts [cost]. Reading [cost] as the lower
    end of the runtime bounds gives the fastest the run can be, and as the upper
    end the slowest. *)
let duration cost =
  List.fold_left (fun d -> function Ev o -> d + cost o | Wait n -> d + n) 0

(** [min_duration cost p] is the duration of the fastest run of the (non-empty)
    set [p]. *)
let min_duration cost = function
  | [] -> invalid_arg "TimedTrace.min_duration: empty set of traces"
  | t :: p ->
      List.fold_left (fun d t -> min d (duration cost t)) (duration cost t) p

(** [max_duration cost p] is the duration of the slowest run of the (non-empty)
    set [p]. *)
let max_duration cost = function
  | [] -> invalid_arg "TimedTrace.max_duration: empty set of traces"
  | t :: p ->
      List.fold_left (fun d t -> max d (duration cost t)) (duration cost t) p

(** [events p] lists, sorted and without repetitions, the operation names
    mentioned anywhere in [p]. *)
let events p =
  List.sort_uniq String.compare
    (List.concat_map
       (List.filter_map (function Ev o -> Some o | Wait _ -> None))
       p)

let show_event = function Ev o -> o | Wait n -> string_of_int n

(** [show_trace t] prints a run as [Read; 3; Send]; the empty run prints as [0],
    the delay of duration zero it denotes. *)
let show_trace = function
  | [] -> "0"
  | t -> String.concat "; " (List.map show_event t)

(** [show p] prints a set of runs as [{Read; 3; Send | Send; Send}]. *)
let show p = "{" ^ String.concat " | " (List.map show_trace p) ^ "}"
