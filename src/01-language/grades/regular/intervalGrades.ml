open Grade
module I = IntervalRegex
module Ops = I.Ops

let extremum = function
  | Closed q -> I.Finite (q, true)
  | Open q -> I.Finite (q, false)
  | Unbounded -> I.Infinite

let end_of = function
  | I.Finite (q, true) -> Closed q
  | I.Finite (q, false) -> Open q
  | I.Infinite -> Unbounded

module type DELAYS = sig
  module Delay : Delay.MEASURED

  val whole : bool
end

module type NAMES = sig
  val prefix : string
  val suffix : string
  val finite : bool
end

module Make (D : DELAYS) (N : NAMES) = struct
  module Steps = struct
    let whole = D.whole
  end

  module CU = IntervalClosure.Make (I.Upper) (Steps)
  module CL = IntervalClosure.Make (I.Lower) (Steps)

  (* {1 Worlds} *)

  (* [running_time ~lower bounds name] is the end of the running-time bounds
     of [name], the lower one if [lower], closed over whole time steps. *)
  let running_time ~lower bounds name =
    let b = bounds.running_time name in
    let lo, hi = if D.whole then close_running_time D.Delay.adjacent b else b in
    extremum (if lower then lo else hi)

  (* The worlds of the comparisons of a program, by the end read and the
     names the grades compared mention: these names, and of the other
     declared operations, which the grades do not tell apart, the least name
     of each running time. *)
  let worlds =
    Memo.last (fun bounds ->
        let table = Hashtbl.create 16 in
        fun ~lower mentioned ->
          match Hashtbl.find_opt table (lower, mentioned) with
          | Some w -> w
          | None ->
              let time = running_time ~lower bounds in
              let others =
                List.filter
                  (fun n -> not (List.mem n mentioned))
                  (List.sort_uniq String.compare bounds.operations)
              in
              let representatives =
                List.fold_left
                  (fun acc n ->
                    let c = time n in
                    if
                      List.exists
                        (fun (_, c') -> DelaySet.equal_extremum c c')
                        acc
                    then acc
                    else (n, c) :: acc)
                  [] others
              in
              let w =
                IntervalClosure.world
                  (List.sort
                     (fun (n, _) (n', _) -> String.compare n n')
                     (List.map (fun n -> (n, time n)) mentioned
                     @ representatives))
              in
              Hashtbl.add table (lower, mentioned) w;
              w)

  let world ~lower bounds names =
    worlds bounds ~lower (List.sort_uniq String.compare (List.concat names))

  (* [no_time] is running-time bounds at which every operation takes no time,
     for inhabitation. *)
  let no_time bounds =
    {
      bounds with
      running_time = (fun _ -> (Closed Rational.zero, Closed Rational.zero));
    }

  let to_durations lo hi =
    match (lo, hi) with
    | Some f, Some s -> Some (end_of f, end_of s)
    | _ -> None

  let numeric = function
    | Int n -> Some (Rational.of_int n)
    | Rat q -> Some q
    | _ -> None

  (* {1 One-sided grades} *)

  module Side
      (E : I.S)
      (C : sig
        val leq : IntervalClosure.world -> E.t -> E.t -> bool

        val counterexample :
          IntervalClosure.world ->
          E.t ->
          E.t ->
          IntervalClosure.concrete list option

        val max_weight : IntervalClosure.world -> E.t -> I.cut option
        val min_weight : IntervalClosure.world -> E.t -> I.cut option
        val inhabited : IntervalClosure.world -> E.t -> bool
      end)
      (S : sig
        val infix : string
        val top_cut : I.cut
        val lower : bool
      end) =
  struct
    type t = E.t

    module Delay = D.Delay

    let name = N.prefix ^ S.infix ^ N.suffix
    let one = E.eps
    let mul = E.concat
    let join r s = E.union [ r; s ]
    let top = E.stretch Ops.all S.top_cut
    let leq_symbol = "<="
    let compare = E.compare
    let hash = E.hash

    let compared bounds rhos =
      world ~lower:S.lower bounds (List.map E.names rhos)

    let trivial r s = E.equal r s || E.equal s top
    let leq bounds r s = trivial r s || C.leq (compared bounds [ r; s ]) r s
    let equal bounds r s = leq bounds r s && leq bounds s r
    let is_top bounds r = E.equal r top || leq bounds top r

    let of_word w =
      List.fold_right
        (fun c acc ->
          E.concat
            (match c with
            | IntervalClosure.Name n -> E.op (Ops.name n)
            | IntervalClosure.Length (s, d) -> E.stretch s (I.Finite (d, true)))
            acc)
        w E.eps

    let counterexample bounds r s =
      if trivial r s then None
      else Option.map of_word (C.counterexample (compared bounds [ r; s ]) r s)

    let unit_least = false
    let plus _ = None
    let commutative = false
    let needs_op_bounds = true
    let duration_ends = if S.lower then Lower_end else Upper_end

    let of_delay d =
      let q = Delay.to_rational d in
      if Rational.sign q = 0 then E.eps
      else E.stretch Ops.empty (I.Finite (q, true))

    let events = E.names

    (* An end alone is decided with every operation taking no time. *)
    let vacuous bounds r =
      unless_inhabited (C.inhabited (compared (no_time bounds) [ r ]) r)

    let inhabited bounds r = inhabited_of vacuous bounds r

    let min_weight bounds r =
      C.min_weight (world ~lower:true bounds [ E.names r ]) r

    let max_weight bounds r =
      C.max_weight (world ~lower:false bounds [ E.names r ]) r

    let duration_bounds bounds r =
      to_durations (min_weight bounds r) (max_weight bounds r)

    (* [read lit r] is the expression of the contents [r] of the literal
       [lit], unless it has a negative delay or is the empty language. *)
    let read lit r =
      check_delays lit r;
      let e = E.of_regex ~whole:D.whole ~finite:N.finite lit r in
      if E.equal e E.empty then
        invalid_lit lit
          "this regular expression denotes the empty language, but grades are \
           non-empty"
      else e

    let of_lit = function
      | Top -> top
      | Braces r as lit -> read lit r
      | Int n as lit -> read lit (Tick n)
      | Rat q as lit -> read lit (Frac q)
      | lit ->
          invalid_lit lit
            "grades are brace literals `{...}`, numbers and `⊤`, not %s"
            (describe_lit lit)

    let accepts = reads_lit of_lit
    let is_atomic n r = E.equal r (E.op (Ops.name n))
    let show r = "{" ^ E.show r ^ "}"
    let witnesses ~degree:_ _bounds = sampled mul
  end

  module UpperSide =
    Side (I.Upper) (CU)
      (struct
        let infix = "upper-bound"
        let top_cut = I.Infinite
        let lower = false
      end)

  module LowerSide =
    Side (I.Lower) (CL)
      (struct
        let infix = "lower-bound"
        let top_cut = I.Finite (Rational.zero, true)
        let lower = true
      end)

  (* The time shadows: the budget up to the upper end of the running-time
     bounds, and the budget from their lower end. *)
  let upper_shadow hi =
    match hi with
    | Unbounded -> UpperSide.top
    | Closed d | Open d ->
        let q = D.Delay.to_rational d in
        let c =
          match hi with
          | Open _ when D.whole ->
              I.Finite (Rational.sub q (Rational.of_int 1), true)
          | Open _ -> I.Finite (q, false)
          | _ -> I.Finite (q, true)
        in
        I.Upper.stretch Ops.all c

  let lower_shadow lo =
    match lo with
    | Unbounded -> LowerSide.top
    | Closed d | Open d ->
        let q = D.Delay.to_rational d in
        let c =
          match lo with
          | Open _ when D.whole ->
              I.Finite (Rational.add q (Rational.of_int 1), true)
          | Open _ -> I.Finite (q, false)
          | _ -> I.Finite (q, true)
        in
        I.Lower.stretch Ops.all c

  module Upper = struct
    include UpperSide

    let of_bounds (_lo, hi) = upper_shadow hi
  end

  module Lower = struct
    include LowerSide

    let of_bounds (lo, _hi) = lower_shadow lo
  end

  (* {1 Intervals} *)

  module Interval = struct
    type t = Lower.t * Upper.t

    module Delay = D.Delay

    let name = N.prefix ^ "interval" ^ N.suffix
    let one = (Lower.one, Upper.one)
    let mul (l, u) (l', u') = (Lower.mul l l', Upper.mul u u')
    let join (l, u) (l', u') = (Lower.join l l', Upper.join u u')
    let top = (Lower.top, Upper.top)
    let leq_symbol = "<="

    (* Componentwise, the upper bounds first. *)
    let leq bounds (l, u) (l', u') =
      Upper.leq bounds u u' && Lower.leq bounds l l'

    let equal bounds (l, u) (l', u') =
      Upper.equal bounds u u' && Lower.equal bounds l l'

    let is_top bounds (l, u) = Lower.is_top bounds l && Upper.is_top bounds u

    let compare (l, u) (l', u') =
      match Lower.compare l l' with 0 -> Upper.compare u u' | c -> c

    let hash (l, u) = Hashing.combine (Lower.hash l) (Upper.hash u)

    (* {2 Run consistency} *)

    (* [joint_world bounds names] is the world of a consistency check: the
       [names] mentioned, and of the other declared operations the least
       name of each pair of ends of running times, each with both ends. *)
    let joint_world bounds names =
      let ends n =
        (running_time ~lower:true bounds n, running_time ~lower:false bounds n)
      in
      let same (l, h) (l', h') =
        DelaySet.equal_extremum l l' && DelaySet.equal_extremum h h'
      in
      let others =
        List.fold_left
          (fun acc n ->
            let e = ends n in
            if List.mem n names || List.exists (fun (_, e') -> same e e') acc
            then acc
            else (n, e) :: acc)
          []
          (List.sort_uniq String.compare bounds.operations)
      in
      IntervalConsistency.world
        (List.sort
           (fun (n, _) (n', _) -> String.compare n n')
           (List.map (fun n -> (n, ends n)) names @ others))

    let interval_world bounds (l, u) =
      joint_world bounds
        (List.sort_uniq String.compare (I.Lower.names l @ I.Upper.names u))

    (* [witness bounds (l, u)] is a run fitting a word of [l] and a word of
       [u] at the running times of [bounds], if there is one
       ({!IntervalConsistency}). *)
    let witness bounds (l, u) =
      IntervalConsistency.witness ~whole:D.whole
        (interval_world bounds (l, u))
        ~lower:(CL.graph l) ~upper:(CU.graph u)

    let consistency_found = Hashtbl.create 64

    (* [consistent bounds (l, u)] is whether some run fits a word of [l] and a
       word of [u] at the running times of [bounds], decided without reading
       off the run. *)
    let consistent bounds (l, u) =
      let world = interval_world bounds (l, u) in
      let key = (IntervalConsistency.id world, I.Lower.id l, I.Upper.id u) in
      match Hashtbl.find_opt consistency_found key with
      | Some c -> c
      | None ->
          let c =
            IntervalConsistency.consistent ~whole:D.whole world
              ~lower:(CL.graph l) ~upper:(CU.graph u)
          in
          Hashtbl.add consistency_found key c;
          c

    (* [too_long bounds (l, u)] is the reason no run meets both ends if the
       words of [l] last longer than those of [u]: the least duration of [l],
       its operations at the lower ends of their running times, above the
       greatest of [u], at the upper ends. *)
    let too_long bounds (l, u) =
      match (Lower.min_weight bounds l, Upper.max_weight bounds u) with
      | Some (I.Finite (a, at_a)), Some (I.Finite (b, at_b)) ->
          let c = Rational.compare a b in
          if c > 0 || (c = 0 && not (at_a && at_b)) then
            Some
              (Printf.sprintf
                 "its lower end lasts %s %s and its upper end %s %s"
                 (if at_a then "at least" else "more than")
                 (Rational.show a)
                 (if at_b then "at most" else "less than")
                 (Rational.show b))
          else None
      | _ -> None

    (* [joint_vacuous bounds (l, u)] is the reason no run meets both ends [l]
       and [u], each of which has a word, at the running times of [bounds]
       ({!Grade.no_common_run}): none if they share their skeleton or one is
       the top, the durations if they decide it, and otherwise the absence of
       a witness. *)
    let joint_vacuous bounds (l, u) =
      if
        Option.is_some (I.zip l u)
        || I.Lower.equal l Lower.top || I.Upper.equal u Upper.top
      then None
      else
        match too_long bounds (l, u) with
        | Some reason -> Some (no_common_run (Some reason))
        | None ->
            if consistent bounds (l, u) then None else Some (no_common_run None)

    let vacuous bounds (l, u) =
      match Lower.vacuous bounds l with
      | Some _ as reason -> reason
      | None -> (
          match Upper.vacuous bounds u with
          | Some _ as reason -> reason
          | None -> joint_vacuous bounds (l, u))

    let inhabited bounds rho = inhabited_of vacuous bounds rho

    (* The pair of a witness in one end with the other end of the lesser
       grade, if some run meets both its ends, and the lesser grade
       otherwise. *)
    let counterexample bounds (l, u) (l', u') =
      let consistent e =
        if Option.is_none (joint_vacuous bounds e) then e else (l, u)
      in
      Option.map consistent
        (match Lower.counterexample bounds l l' with
        | Some e -> Some (e, u)
        | None ->
            Option.map (fun e -> (l, e)) (Upper.counterexample bounds u u'))

    let unit_least = false
    let plus _ = None
    let commutative = false
    let needs_op_bounds = true
    let duration_ends = Both_ends

    let duration_bounds bounds (l, u) =
      to_durations (Lower.min_weight bounds l) (Upper.max_weight bounds u)

    let events (l, u) =
      List.sort_uniq String.compare (Lower.events l @ Upper.events u)

    let single = function Int _ | Rat _ | Braces _ -> true | _ -> false

    (* A numeric endpoint is the budget from it or up to it, [0] being [≥0]. *)
    let lower_end lit =
      match numeric lit with
      | Some q -> Lower.of_lit (Braces (Above (Closed q)))
      | None -> Lower.of_lit lit

    let upper_end lit =
      match numeric lit with
      | Some q -> Upper.of_lit (Braces (Below (Closed q)))
      | None -> Upper.of_lit lit

    let close ~lower a =
      match numeric a with
      | Some _ when D.whole -> close_integer ~lower a
      | Some q -> Braces (if lower then Above (Open q) else Below (Open q))
      | None -> a

    let of_lit = function
      | Top -> top
      | lit when single lit -> (Lower.of_lit lit, Upper.of_lit lit)
      | lit ->
          bounds_of_lit lit ~number:numeric ~close ~lower:lower_end
            ~upper:upper_end ~unbounded:Upper.top ~bounds:"regular expressions"

    let accepts = reads_lit of_lit
    let of_delay d = (Lower.of_delay d, Upper.of_delay d)
    let of_bounds (lo, hi) = (lower_shadow lo, upper_shadow hi)
    let is_atomic n (l, u) = Lower.is_atomic n l && Upper.is_atomic n u

    let show (l, u) =
      match I.zip l u with
      | Some s -> "{" ^ s ^ "}"
      | None ->
          show_bounds (Lower.show l)
            (if I.Upper.equal u Upper.top then None else Some (Upper.show u))

    let witnesses ~degree:_ _bounds = sampled mul
  end
end

module Whole = struct
  module Delay = Delay.Nat

  let whole = true
end

module Rationals = struct
  module Delay = Delay.Rational

  let whole = false
end

module Regex =
  Make
    (Whole)
    (struct
      let prefix = "regex-timed-rigid-"
      let suffix = "-symbolic"
      let finite = false
    end)

module RegexRational =
  Make
    (Rationals)
    (struct
      let prefix = "regex-timed-rigid-"
      let suffix = "-rational-symbolic"
      let finite = false
    end)

module Traces =
  Make
    (Whole)
    (struct
      let prefix = "traces-timed-rigid-"
      let suffix = ""
      let finite = true
    end)

module TracesRational =
  Make
    (Rationals)
    (struct
      let prefix = "traces-timed-rigid-"
      let suffix = "-rational"
      let finite = true
    end)
