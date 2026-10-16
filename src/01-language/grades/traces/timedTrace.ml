module Base (D : Delay.S) = struct
  type event = Ev of string | Wait of D.t | Strict of D.t
  type trace = event list
  type traces = trace list

  (** [compare_event e e'] orders the events, operations before delays before
      strict delays, the operations by name and the delays by duration. *)
  let compare_event e e' =
    match (e, e') with
    | Ev o, Ev o' -> String.compare o o'
    | Ev _, (Wait _ | Strict _) | Wait _, Strict _ -> -1
    | (Wait _ | Strict _), Ev _ | Strict _, Wait _ -> 1
    | Wait n, Wait n' | Strict n, Strict n' -> D.compare n n'

  (** [compare_trace s t] orders the traces lexicographically by
      {!compare_event}. *)
  let compare_trace = List.compare compare_event

  let compare = List.compare compare_trace
  let equal p q = compare p q = 0

  let hash_event = function
    | Ev o -> String.hash o
    | Wait n -> D.hash n
    | Strict n -> Hashing.combine 3 (D.hash n)

  let hash_trace = Hashing.list hash_event
  let hash = Hashing.list hash_trace

  let normalise evs =
    let rec go acc = function
      | [] -> List.rev acc
      | (Wait n | Strict n) :: rest when D.equal n D.zero -> go acc rest
      | Wait n :: rest -> (
          match acc with
          | Wait m :: acc' -> go (Wait (D.add m n) :: acc') rest
          | _ -> go (Wait n :: acc) rest)
      | Strict n :: rest -> (
          match acc with
          | Strict m :: acc' -> go (Strict (D.add m n) :: acc') rest
          | _ -> go (Strict n :: acc) rest)
      | (Ev _ as e) :: rest -> go (e :: acc) rest
    in
    go [] evs

  let concat s t = normalise (s @ t)
  let of_list ts = List.sort_uniq compare_trace (List.map normalise ts)

  let product p q =
    List.sort_uniq compare_trace
      (List.concat_map (fun s -> List.map (fun t -> concat s t) q) p)

  let union p q = List.sort_uniq compare_trace (p @ q)
  let of_delay n = [ normalise [ Wait n ] ]
  let of_strict_delay n = [ normalise [ Strict n ] ]
  let has_strict = List.exists (function Strict _ -> true | _ -> false)

  let rec missing p q =
    match (p, q) with
    | [], _ -> None
    | s :: _, [] -> Some s
    | s :: p', t :: q' -> (
        match compare_trace s t with
        | 0 -> missing p' q'
        | c when c > 0 -> missing p q'
        | _ -> Some s)

  let subset p q = Option.is_none (missing p q)

  let events p =
    List.sort_uniq String.compare
      (List.concat_map
         (List.filter_map (function
           | Ev o -> Some o
           | Wait _ | Strict _ -> None))
         p)

  let show_event = function
    | Ev o -> o
    | Wait n -> D.show n
    | Strict n -> "!" ^ D.show n

  (** [show_trace t] prints a trace as [Read; 3; Send]; the empty trace prints
      as [0], the delay [zero] it denotes. *)
  let show_trace = function
    | [] -> D.show D.zero
    | t -> String.concat "; " (List.map show_event t)

  let show p = "{" ^ String.concat " | " (List.map show_trace p) ^ "}"

  (** {2 Literals} *)

  open GradeLiteral

  (** [delay_of_lit lit tick] is the delay the numeric literal [tick], part of
      the literal [lit], denotes. *)
  let delay_of_lit lit tick =
    match D.read tick with
    | Some d -> d
    | None -> invalid_lit lit "%s" (D.rejection tick)

  (** [of_regex ~strict lit r] is the set of traces the star-free regular
      expression [r], without [&], [~] or [_], denotes, its bounded repetitions
      of finite counts unrolled; [lit] is the literal it is part of. Its strict
      delays [!d] are read if [strict]. *)
  let rec of_regex ~strict lit = function
    | Letter name -> [ [ Ev name ] ]
    | Tick n -> of_delay (delay_of_lit lit (Int n))
    | Frac q -> of_delay (delay_of_lit lit (Rat q))
    | Strict (Tick n) when strict -> of_strict_delay (delay_of_lit lit (Int n))
    | Strict (Frac q) when strict -> of_strict_delay (delay_of_lit lit (Rat q))
    | Strict r when strict ->
        unsupported lit ("the strict set of delays `" ^ show_regex r ^ "`")
    | Strict _ as r -> component_of_lit lit ~context:"" strict_unsupported r
    | Seq (r, s) -> binary ~strict lit product r s
    | Union (r, s) -> binary ~strict lit union r s
    | Star _ -> unsupported lit "repetition `*`"
    | Repeat (r, ({ most = Some _; _ } as c)) ->
        of_regex ~strict lit (unrolled r c)
    | Repeat (_, c) ->
        unsupported lit ("the unbounded repetition `^" ^ Count.show c ^ "`")
    | Inter _ -> unsupported lit "intersection `&`"
    | Compl _ -> unsupported lit "complement `~`"
    | Any -> unsupported lit "the wildcard `_`"
    | Delays (lo, hi) ->
        unsupported lit
          ("the interval of delays `" ^ show_interval Rational.show lo hi ^ "`")

  (* The operands are read left to right, so the leftmost unsupported form is
     the one reported. *)
  and binary ~strict lit combine r s =
    let p = of_regex ~strict lit r in
    let q = of_regex ~strict lit s in
    combine p q

  and unsupported lit form =
    invalid_lit lit
      "sets of traces are built from operation names and delays with `;`, `|` \
       and finite counts `^n`, `^[m, n]` only, without %s"
      form

  let number lit =
    let value = function
      | Int n -> Some (Rational.of_int n)
      | Rat q -> Some q
      | _ -> None
    in
    let delay q = Option.is_some (D.read (rational_lit q)) in
    Option.bind (value lit) (fun q ->
        if delay q || delay (Rational.neg q) then Some q else None)

  let of_lit ~strict ~number:n = function
    | Braces r as lit -> of_regex ~strict lit r
    | lit -> (
        match D.read lit with
        | Some d -> of_delay d
        | None when Option.is_some (number lit) ->
            invalid_lit lit "grades must be non-negative"
        | None ->
            invalid_lit lit
              "grades are a single set of traces `{...}` or a plain %s, not %s"
              n (describe_lit lit))
end

module Make (D : Delay.MONUS) = struct
  include Base (D)

  (** Tables by a budget and two positions. *)
  module Positions = Memo.Make (struct
    type t = D.t * int * int

    let equal (k, i, j) (k', i', j') =
      Int.equal i i' && Int.equal j j' && D.equal k k'

    let hash (k, i, j) = Hashing.combine (Hashing.combine (D.hash k) i) j
  end)

  (** [decide rules k s t] is [rules go k 0 0], where [rules go k i j] decides
      an order at budget [k] on the suffixes of the traces [s] and [t] from the
      positions [i] and [j], given their events if any, by [go] on the same
      traces at further positions. The search is memoised by budget and
      positions: dynamic programming over the positions in [s] and [t]. *)
  let decide rules k s t =
    let s = Array.of_list s and t = Array.of_list t in
    let at trace i = if i < Array.length trace then Some trace.(i) else None in
    let table = Positions.create 64 in
    let rec go k i j =
      Positions.find_or_add table (k, i, j) (fun () ->
          rules go k i j (at s i) (at t j))
    in
    go k 0 0

  (** Tables by a state of two budgets and a flag, and two positions. *)
  module States = Memo.Make (struct
    type t = (D.t * D.t * bool) * int * int

    let equal ((c, k, f), i, j) ((c', k', f'), i', j') =
      Int.equal i i' && Int.equal j j' && Bool.equal f f' && D.equal c c'
      && D.equal k k'

    let hash ((c, k, f), i, j) =
      Hashing.combine
        (Hashing.combine
           (Hashing.combine (D.hash c) (D.hash k))
           (Bool.to_int f))
        (Hashing.combine i j)
  end)

  (** [decide_from rules state s t] is as {!decide}, from the state [state] of
      two budgets and a flag. *)
  let decide_from rules state s t =
    let s = Array.of_list s and t = Array.of_list t in
    let at trace i = if i < Array.length trace then Some trace.(i) else None in
    let table = States.create 64 in
    let rec go state i j =
      States.find_or_add table (state, i, j) (fun () ->
          rules go state i j (at s i) (at t j))
    in
    go state 0 0

  (** [forget s] is the trace [s], its strict delays read as delays. *)
  let forget = List.map (function Strict d -> Wait d | e -> e)

  (* The rigid allowance order with strict delays. In a budget delay of the
     bound, the state [(c, k, false)] holds the budget [k] of the delay and the
     carry [c], what the earlier strict delays of the gap and the budget
     delays before them left unspent, which only strict delays of the trace
     spend, before [k], and which every other event of the trace forfeits; in a
     strict delay of the bound, [(c, 0, true)] holds what is left of it and the
     carry, which the strict delays of the trace alone spend. *)
  let strict_allowance running_time =
    decide_from
      (fun go (c, k, piece) i j s t ->
        let budget c k = (c, k, false) and strict c = (c, D.zero, true) in
        match (s, t) with
        | None, None -> true (* nil *)
        | Some (Ev o), Some (Ev o')
          when String.equal o o' && go (budget D.zero D.zero) (i + 1) (j + 1) ->
            true (* keep *)
        | _, Some (Wait e) when go (budget c (D.add k e)) i (j + 1) ->
            true (* bank-delay *)
        | _, Some (Strict e) when go (strict (D.add (D.add c k) e)) i (j + 1) ->
            true (* enter a strict delay, the carry and the budget kept *)
        | Some (Strict d), _ when D.leq d (D.add c k) ->
            let state =
              if piece then strict (D.monus c d)
              else if D.leq d c then budget (D.monus c d) k
              else budget D.zero (D.monus k (D.monus d c))
            in
            go state (i + 1) j (* use-strict *)
        | Some (Wait d), _
          when (not piece) && D.leq d k
               && go (budget D.zero (D.monus k d)) (i + 1) j ->
            true (* use-delay *)
        | Some (Ev o), _
          when (not piece)
               && D.leq (running_time o) k
               && go (budget D.zero (D.monus k (running_time o))) (i + 1) j ->
            true (* use-op *)
        | _ -> false)
      (D.zero, D.zero, false)

  (* Each rule advances in [s] or [t], so the search terminates. The [when]
     guards are the backtracking: a failing guard falls through to the next
     rule. The rigid order has no rule skip-op, and its rule nil requires [t]
     exhausted, the delays of [t] left being banked by bank-delay. A trace with
     strict delays is decided by {!strict_allowance} under the rigid order; the
     other orders do not tell the kinds of delays apart. *)
  let plain_allowance ~rigid running_time =
    decide (fun go k i j s t ->
        match (s, t) with
        | None, None -> true (* nil *)
        | None, _ when not rigid -> true (* nil *)
        | Some (Ev o), Some (Ev o')
          when String.equal o o' && go D.zero (i + 1) (j + 1) ->
            true (* keep: the budget does not cross a match *)
        | _, Some (Ev _) when (not rigid) && go k i (j + 1) ->
            true (* skip-op *)
        | _, Some (Wait e) when go (D.add k e) i (j + 1) ->
            true (* bank-delay *)
        | Some (Wait d), _ when D.leq d k && go (D.monus k d) (i + 1) j ->
            true (* use-delay *)
        | Some (Ev o), _
          when D.leq (running_time o) k
               && go (D.monus k (running_time o)) (i + 1) j ->
            true (* use-op *)
        | _ -> false)

  (* Coverage with strict delays. The state [(k, l, false)] holds the slack [k]
     and its part [l] that the latest strict delays of the trace make up, the
     only slack a strict delay of the guarantee may spend; what is left of the
     slack after a strict delay of the guarantee is what lies beyond it. *)
  let strict_coverage running_time =
    decide_from
      (fun go (k, l, _) i j s t ->
        let slack k l = (k, l, false) in
        match (s, t) with
        | None, _ -> true (* nil *)
        | Some (Ev o), Some (Ev o')
          when String.equal o o' && go (slack D.zero D.zero) (i + 1) (j + 1) ->
            true (* keep *)
        | _, Some (Ev o)
          when go (slack (D.add k (running_time o)) D.zero) i (j + 1) ->
            true (* pay-op *)
        | _, Some (Wait e) when go (slack (D.add k e) D.zero) i (j + 1) ->
            true (* del-delay *)
        | _, Some (Strict e) when go (slack (D.add k e) (D.add l e)) i (j + 1)
          ->
            true (* del-strict *)
        | Some (Wait d), _
          when D.leq d k
               &&
               let k' = D.monus k d in
               go (slack k' (if D.leq l k' then l else k')) (i + 1) j ->
            true (* use-delay *)
        | Some (Strict d), _ when D.leq d l ->
            let l' = D.monus l d in
            go (slack l' l') (i + 1) j (* use-strict *)
        | _ -> false)
      (D.zero, D.zero, false)

  let plain_coverage running_time =
    decide (fun go k i j s t ->
        match (s, t) with
        | None, _ -> true (* nil *)
        | Some (Ev o), Some (Ev o')
          when String.equal o o' && go D.zero (i + 1) (j + 1) ->
            true (* keep: the slack does not cross a match *)
        | _, Some (Ev o) when go (D.add k (running_time o)) i (j + 1) ->
            true (* pay-op *)
        | _, Some (Wait e) when go (D.add k e) i (j + 1) -> true (* del-delay *)
        | Some (Wait d), _ when D.leq d k && go (D.monus k d) (i + 1) j ->
            true (* use-delay *)
        | _ -> false)

  let allowance ~rigid running_time k s t =
    if has_strict s || has_strict t then
      if rigid && D.equal k D.zero then strict_allowance running_time s t
      else plain_allowance ~rigid running_time k (forget s) (forget t)
    else plain_allowance ~rigid running_time k s t

  let coverage running_time k s t =
    if has_strict s || has_strict t then
      if D.equal k D.zero then strict_coverage running_time s t
      else plain_coverage running_time k (forget s) (forget t)
    else plain_coverage running_time k s t

  let upper_bound_le ~rigid running_time p q =
    List.for_all
      (fun s ->
        List.exists (fun t -> allowance ~rigid running_time D.zero s t) q)
      p

  let lower_bound_le running_time p q =
    List.for_all
      (fun s -> List.exists (fun t -> coverage running_time D.zero t s) q)
      p
end
