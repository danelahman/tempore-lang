module Base (D : Delay.S) = struct
  type event = Ev of string | Wait of D.t
  type trace = event list
  type traces = trace list

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

  let compare = List.compare compare_trace
  let equal p q = compare p q = 0
  let hash_event = function Ev o -> String.hash o | Wait n -> D.hash n
  let hash_trace = Hashing.list hash_event
  let hash = Hashing.list hash_trace

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

  let concat s t = normalise (s @ t)
  let of_list ts = List.sort_uniq compare_trace (List.map normalise ts)

  let product p q =
    List.sort_uniq compare_trace
      (List.concat_map (fun s -> List.map (fun t -> concat s t) q) p)

  let union p q = List.sort_uniq compare_trace (p @ q)
  let of_delay n = [ normalise [ Wait n ] ]

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
         (List.filter_map (function Ev o -> Some o | Wait _ -> None))
         p)

  let show_event = function Ev o -> o | Wait n -> D.show n

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

  (** [of_regex lit r] is the set of traces the star-free regular expression
      [r], without [&], [~] or [_], denotes; [lit] is the literal it is part of.
  *)
  let rec of_regex lit = function
    | Letter name -> [ [ Ev name ] ]
    | Tick n -> of_delay (delay_of_lit lit (Int n))
    | Frac q -> of_delay (delay_of_lit lit (Rat q))
    | Seq (r, s) -> binary lit product r s
    | Union (r, s) -> binary lit union r s
    | Star _ -> unsupported lit "repetition `*`"
    | Inter _ -> unsupported lit "intersection `&`"
    | Compl _ -> unsupported lit "complement `~`"
    | Any -> unsupported lit "the wildcard `_`"
    | Delays (lo, hi) ->
        unsupported lit
          ("the interval of delays `" ^ show_interval Rational.show lo hi ^ "`")

  (* The operands are read left to right, so the leftmost unsupported form is
     the one reported. *)
  and binary lit combine r s =
    let p = of_regex lit r in
    let q = of_regex lit s in
    combine p q

  and unsupported lit form =
    invalid_lit lit
      "sets of traces are built from operation names and delays with `;` and \
       `|` only, without %s"
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

  let of_lit ~number:n = function
    | Braces r as lit -> of_regex lit r
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

  (* Each rule advances in [s] or [t], so the search terminates. The [when]
     guards are the backtracking: a failing guard falls through to the next
     rule. *)
  let allowance running_time =
    decide (fun go k i j s t ->
        match (s, t) with
        | None, _ -> true (* nil *)
        | Some (Ev o), Some (Ev o')
          when String.equal o o' && go D.zero (i + 1) (j + 1) ->
            true (* keep: the budget does not cross a match *)
        | _, Some (Ev _) when go k i (j + 1) -> true (* skip-op *)
        | _, Some (Wait e) when go (D.add k e) i (j + 1) ->
            true (* bank-delay *)
        | Some (Wait d), _ when D.leq d k && go (D.monus k d) (i + 1) j ->
            true (* use-delay *)
        | Some (Ev o), _
          when D.leq (running_time o) k
               && go (D.monus k (running_time o)) (i + 1) j ->
            true (* use-op *)
        | _ -> false)

  let coverage running_time =
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

  let upper_bound_le running_time p q =
    List.for_all
      (fun s -> List.exists (fun t -> allowance running_time D.zero s t) q)
      p

  let lower_bound_le running_time p q =
    List.for_all
      (fun s -> List.exists (fun t -> coverage running_time D.zero t s) q)
      p
end
