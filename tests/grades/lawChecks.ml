(* Named checks and the laws of the grades, of their declared flags, of
   semilattices and of the actions of semidirect products, on samples, shared
   by the unit tests of the grades. *)

module Grade = Grades.Grade

type check = { name : string; passed : bool; detail : string }

let check name passed detail = { name; passed; detail }

let expect name show ~expected actual =
  check name (expected = actual)
    ("expected " ^ show expected ^ ", got " ^ show actual)

(* [all name show p xs] checks [p] on every element of [xs], reporting the
   first failure by [show]. *)
let all name show p xs =
  match List.find_opt (fun x -> not (p x)) xs with
  | None -> check name true ""
  | Some x -> check name false ("fails on " ^ show x)

let implies a b = (not a) || b
let pairs xs = List.concat_map (fun x -> List.map (fun y -> (x, y)) xs) xs

let triples xs =
  List.concat_map (fun (x, y) -> List.map (fun z -> (x, y, z)) xs) (pairs xs)

(* [first width xs] is the first [width] elements of [xs]. *)
let first width xs = List.filteri (fun i _ -> i < width) xs

(* [order_laws (module G) ~context bounds samples] checks the laws of a
   preorder with a monotone product, a join and a top, and, unless
   [zero_product] is false, the zero-product law of the unit, on [samples]
   under [bounds], described by [context] in the reports; the leastness of the
   join on the pairs of the first [width] samples, and transitivity and
   monotonicity on the ordered pairs with a third among the first [thirds]
   samples, all by default. *)
let order_laws (type a) ?(width = 8) ?thirds ?(zero_product = true)
    (module G : Grade.S with type t = a) ~context bounds (samples : a list) =
  let name law = G.name ^ ": " ^ law in
  let leq = G.leq bounds in
  let equal = G.equal bounds in
  let show1 x = G.show x ^ " at " ^ context in
  let show2 (x, y) = G.show x ^ ", " ^ G.show y ^ " at " ^ context in
  let show3 (x, y, z) = show2 (x, y) ^ ", " ^ G.show z in
  let below = List.filter (fun (x, y) -> leq x y) (pairs samples) in
  let thirds =
    match thirds with Some thirds -> first thirds samples | None -> samples
  in
  let triples =
    List.concat_map (fun (x, y) -> List.map (fun z -> (x, y, z)) thirds) below
  in
  [
    all (name "reflexive") show1 (fun x -> leq x x) samples;
    all (name "transitive") show3
      (fun (x, y, z) -> implies (leq y z) (leq x z))
      triples;
    all (name "product monotone") show3
      (fun (x, y, z) ->
        leq (G.mul x z) (G.mul y z) && leq (G.mul z x) (G.mul z y))
      triples;
    all
      (name "join an upper bound")
      show2
      (fun (x, y) -> leq x (G.join x y) && leq y (G.join x y))
      (pairs samples);
    all (name "join least") show3
      (fun (x, y, z) -> implies (leq x z && leq y z) (leq (G.join x y) z))
      (List.concat_map
         (fun (x, y) -> List.map (fun z -> (x, y, z)) samples)
         (pairs (first width samples)));
    all (name "top greatest") show1 (fun x -> leq x G.top) samples;
    all
      (name "equal is mutual leq")
      show2
      (fun (x, y) -> equal x y = (leq x y && leq y x))
      (pairs samples);
  ]
  @ (if zero_product then
       [
         all (name "zero product") show2
           (fun (x, y) ->
             implies (leq (G.mul x y) G.one) (leq x G.one && leq y G.one))
           (pairs samples);
       ]
     else [])
  @
  if G.unit_least then
    [
      all (name "unit least") show1
        (fun x -> implies (G.inhabited bounds x) (leq G.one x))
        samples;
      all
        (name "top absorbing up to equality")
        show1
        (fun x -> equal (G.mul x G.top) G.top && equal (G.mul G.top x) G.top)
        samples;
    ]
  else []

(* [counterexample_laws (module G) ~offered ~context bounds samples] checks
   that the counterexamples on [samples] are witnesses of the failures of the
   order, and, where [offered], that every failure has one. *)
let counterexample_laws (type a) (module G : Grade.S with type t = a) ~offered
    ~context bounds (samples : a list) =
  let leq = G.leq bounds in
  [
    all
      (G.name ^ ": counterexamples")
      (fun (x, y) -> G.show x ^ ", " ^ G.show y ^ " at " ^ context)
      (fun (x, y) ->
        match G.counterexample bounds x y with
        | None -> implies offered (leq x y)
        | Some e -> (not (leq x y)) && leq e x && not (leq e y))
      (pairs samples);
  ]

(* [laws (module G) ~context bounds samples] checks the laws of the order on
   [samples] under [bounds], with a counterexample to every failure. *)
let laws (type a) (module G : Grade.S with type t = a) ~context bounds
    (samples : a list) =
  order_laws (module G) ~context bounds samples
  @ counterexample_laws (module G) ~offered:true ~context bounds samples

(* [algebra_laws (module G) ~context bounds samples] checks, up to equality
   under [bounds], that the product is associative with its unit and
   distributes over the join on both sides, on the first [width] of
   [samples]. *)
let algebra_laws (type a) ?(width = 8) (module G : Grade.S with type t = a)
    ~context bounds (samples : a list) =
  let name law = G.name ^ ": " ^ law in
  let equal = G.equal bounds in
  let show1 x = G.show x ^ " at " ^ context in
  let show3 (x, y, z) =
    G.show x ^ ", " ^ G.show y ^ ", " ^ G.show z ^ " at " ^ context
  in
  let some = first width samples in
  [
    all (name "unit") show1
      (fun x -> equal (G.mul G.one x) x && equal (G.mul x G.one) x)
      samples;
    all
      (name "product associative")
      show3
      (fun (x, y, z) -> equal (G.mul x (G.mul y z)) (G.mul (G.mul x y) z))
      (triples some);
    all
      (name "product distributes over join on the left")
      show3
      (fun (x, y, z) ->
        equal (G.mul x (G.join y z)) (G.join (G.mul x y) (G.mul x z)))
      (triples some);
    all
      (name "product distributes over join on the right")
      show3
      (fun (x, y, z) ->
        equal (G.mul (G.join y z) x) (G.join (G.mul y x) (G.mul z x)))
      (triples some);
  ]

module Delay = Grades.Delay
module Rational = Grades.Rational

(* The literals of the sample delays: the integers [0] to [4] and fractions. *)
let delay_lits =
  List.init 5 (fun n -> Grade.Int n)
  @ List.map
      (fun (n, d) -> Grade.Rat (Rational.make n d))
      [ (1, 2); (1, 3); (3, 2); (5, 6); (7, 4) ]

(* [value lit] is the number of the numeric literal [lit]. *)
let value = function
  | Grade.Int n -> Rational.of_int n
  | Grade.Rat q -> q
  | _ -> invalid_arg "LawChecks.value"

let show_lit lit = Rational.show (value lit)

(* [delays (module D)] is the sample literals that [D] reads, with their
   delays. *)
let delays (type d) (module D : Delay.S with type t = d) =
  List.filter_map
    (fun lit -> Option.map (fun d -> (lit, d)) (D.read lit))
    delay_lits

(* [delay_laws ~name (module D)] checks the laws of {!Delay.S} on the sample
   literals and their delays: the monoid laws, [read] a partial monoid
   morphism on a submonoid, an integral fraction read as its integer and a
   negative literal as none, and [equal] agreeing with [compare] and [hash]. *)
let delay_laws (type d) ~name (module D : Delay.S with type t = d) =
  let name law = name ^ ": " ^ law in
  let samples = delays (module D) in
  let ds = List.map snd samples in
  let show_d = D.show in
  let show2 (d, e) = D.show d ^ ", " ^ D.show e in
  let show3 (d, e, f) = show2 (d, e) ^ ", " ^ D.show f in
  let same d e =
    match (d, e) with
    | Some d, Some e -> D.equal d e
    | None, None -> true
    | _ -> false
  in
  [
    check (name "0 reads as zero")
      (same (D.read (Grade.Int 0)) (Some D.zero))
      "read 0";
    all (name "zero a unit") show_d
      (fun d -> D.equal (D.add D.zero d) d && D.equal (D.add d D.zero) d)
      ds;
    all (name "add associative") show3
      (fun (d, e, f) -> D.equal (D.add d (D.add e f)) (D.add (D.add d e) f))
      (triples ds);
    all
      (name "read a homomorphism on its domain")
      (fun ((q, _), (r, _)) -> show_lit q ^ ", " ^ show_lit r)
      (fun ((q, d), (r, e)) ->
        same
          (D.read (Grade.rational_lit (Rational.add (value q) (value r))))
          (Some (D.add d e)))
      (pairs samples);
    all
      (name "an integral fraction reads as its integer")
      string_of_int
      (fun n ->
        same (D.read (Grade.Rat (Rational.of_int n))) (D.read (Grade.Int n)))
      (List.init 5 Fun.id);
    all
      (name "a negative literal reads as none")
      show_lit
      (fun lit -> Option.is_none (D.read lit))
      [ Grade.Int (-1); Grade.Rat (Rational.make (-1) 2) ];
    all
      (name "equal agrees with compare and hash")
      show2
      (fun (d, e) ->
        D.equal d e = (D.compare d e = 0)
        && implies (D.equal d e) (D.hash d = D.hash e))
      (pairs ds);
  ]

(* [ordered_delay_laws ~name (module D)] checks, besides {!delay_laws}, the
   laws of {!Delay.ORDERED} on the sample delays: [leq] a total preorder, [add]
   monotone, [zero] least and some witness above it, [read] monotone, and [min]
   and [max] the lesser and the greater. *)
let ordered_delay_laws (type d) ~name (module D : Delay.ORDERED with type t = d)
    =
  let law l = name ^ ": " ^ l in
  let samples = delays (module D) in
  let ds = List.map snd samples in
  let show2 (d, e) = D.show d ^ ", " ^ D.show e in
  let show3 (d, e, f) = show2 (d, e) ^ ", " ^ D.show f in
  let same d e = D.leq d e && D.leq e d in
  delay_laws ~name (module D)
  @ [
      all (law "leq total") show2
        (fun (d, e) -> D.leq d e || D.leq e d)
        (pairs ds);
      all
        (law "equal is mutual leq")
        show2
        (fun (d, e) -> D.equal d e = (D.leq d e && D.leq e d))
        (pairs ds);
      all (law "leq transitive") show3
        (fun (d, e, f) -> implies (D.leq d e && D.leq e f) (D.leq d f))
        (triples ds);
      all (law "add monotone") show3
        (fun (d, e, f) ->
          implies (D.leq d e)
            (D.leq (D.add d f) (D.add e f) && D.leq (D.add f d) (D.add f e)))
        (triples ds);
      all (law "zero least") D.show (fun d -> D.leq D.zero d) ds;
      all
        (law "a witness above zero")
        (fun cs -> String.concat ", " (List.map D.show cs))
        (fun cs ->
          List.exists
            (fun w -> not (D.leq w D.zero))
            (fst (D.witnesses ~degree:1 cs)))
        [ []; ds ];
      all (law "read monotone")
        (fun ((q, _), (r, _)) -> show_lit q ^ ", " ^ show_lit r)
        (fun ((q, d), (r, e)) ->
          implies (Rational.compare (value q) (value r) <= 0) (D.leq d e))
        (pairs samples);
      all (law "min and max") show2
        (fun (d, e) ->
          let lo = D.min d e and hi = D.max d e in
          (D.equal lo d || D.equal lo e)
          && (D.equal hi d || D.equal hi e)
          && D.leq lo d && D.leq lo e && D.leq d hi && D.leq e hi
          && same lo (if D.leq d e then d else e))
        (pairs ds);
    ]

(* [monus_delay_laws ~name (module D)] checks, besides {!ordered_delay_laws},
   the laws of {!Delay.MONUS} on the sample delays: [add] commutative, the
   residuation [d ≤ e + f ⇔ d ∸ e ≤ f], and the natural order,
   [e ≤ d ⇒ e + (d ∸ e) = d]. *)
let monus_delay_laws (type d) ~name (module D : Delay.MONUS with type t = d) =
  let law l = name ^ ": " ^ l in
  let ds = List.map snd (delays (module D)) in
  let show2 (d, e) = D.show d ^ ", " ^ D.show e in
  let show3 (d, e, f) = show2 (d, e) ^ ", " ^ D.show f in
  ordered_delay_laws ~name (module D)
  @ [
      all (law "add commutative") show2
        (fun (d, e) -> D.equal (D.add d e) (D.add e d))
        (pairs ds);
      all (law "monus residuated") show3
        (fun (d, e, f) -> D.leq d (D.add e f) = D.leq (D.monus d e) f)
        (triples ds);
      all (law "the natural order") show2
        (fun (d, e) -> implies (D.leq e d) (D.equal (D.add e (D.monus d e)) d))
        (pairs ds);
    ]

(* [measured_delay_laws ~name (module D)] checks, besides {!monus_delay_laws},
   the laws of {!Delay.MEASURED} on the sample delays: [to_rational] a monoid
   morphism into the non-negative rationals, an order embedding and inverse to
   [read], and the monus the truncated difference of the measures. *)
let measured_delay_laws (type d) ~name
    (module D : Delay.MEASURED with type t = d) =
  let law l = name ^ ": " ^ l in
  let ds = List.map snd (delays (module D)) in
  let show2 (d, e) = D.show d ^ ", " ^ D.show e in
  let measure = D.to_rational in
  monus_delay_laws ~name (module D)
  @ [
      check
        (law "to_rational zero is 0")
        (Rational.equal (measure D.zero) Rational.zero)
        "to_rational zero";
      all
        (law "to_rational a homomorphism")
        show2
        (fun (d, e) ->
          Rational.equal
            (measure (D.add d e))
            (Rational.add (measure d) (measure e)))
        (pairs ds);
      all
        (law "to_rational an order embedding")
        show2
        (fun (d, e) ->
          D.leq d e = (Rational.compare (measure d) (measure e) <= 0))
        (pairs ds);
      all
        (law "to_rational inverse to read")
        D.show
        (fun d ->
          match D.read (Grade.rational_lit (measure d)) with
          | Some d' -> D.equal d d'
          | None -> false)
        ds;
      all
        (law "monus the truncated difference")
        show2
        (fun (d, e) ->
          let q = Rational.add (measure d) (Rational.neg (measure e)) in
          Rational.equal
            (measure (D.monus d e))
            (if Rational.sign q < 0 then Rational.zero else q))
        (pairs ds);
    ]

(* [stepped_delay_laws ~name (module D)] checks, besides
   {!measured_delay_laws}, the laws of {!Delay.STEPPED}: [steps] the monoid
   morphism from the natural numbers sending [1] to [step], with inverse
   [to_int], [read] defined exactly on the natural numbers, where it agrees
   with [steps], and the order that of the natural numbers. *)
let stepped_delay_laws (type d) ~name (module D : Delay.STEPPED with type t = d)
    =
  let law l = name ^ ": " ^ l in
  let ns = List.init 5 Fun.id in
  let show2 (m, n) = Printf.sprintf "%d, %d" m n in
  measured_delay_laws ~name (module D)
  @ [
      check (law "steps 0 is zero") (D.equal (D.steps 0) D.zero) "steps 0";
      check (law "steps 1 is step") (D.equal (D.steps 1) D.step) "steps 1";
      all
        (law "steps a homomorphism")
        show2
        (fun (m, n) ->
          D.equal (D.steps (m + n)) (D.add (D.steps m) (D.steps n)))
        (pairs ns);
      all
        (law "to_int inverse to steps")
        string_of_int
        (fun n ->
          D.to_int (D.steps n) = n
          && D.equal (D.steps (D.to_int (D.steps n))) (D.steps n))
        ns;
      all
        (law "the order of the natural numbers")
        show2
        (fun (m, n) -> D.leq (D.steps m) (D.steps n) = (m <= n))
        (pairs ns);
      all
        (law "read exactly the natural numbers")
        show_lit
        (fun lit ->
          match (D.read lit, Rational.to_int (value lit)) with
          | Some d, Some n -> n >= 0 && D.equal d (D.steps n)
          | None, Some n -> n < 0
          | Some _, None -> false
          | None, None -> true)
        (Grade.Int (-1) :: delay_lits);
    ]

(* [of_delay_laws (module G) bounds ?monotone] checks that [of_delay] is a
   monoid morphism under [bounds] on the sample delays of [G] and, if
   [monotone] is given, that it is monotone in the value of their literals, or
   antitone if [monotone] is false. *)
let of_delay_laws (module G : Grade.S) bounds ?monotone () =
  let samples = delays (module G.Delay) in
  let show ((q, _), (r, _)) = show_lit q ^ ", " ^ show_lit r in
  [
    check
      (G.name ^ ": of_delay is the unit at zero")
      (G.equal bounds (G.of_delay G.Delay.zero) G.one)
      "of_delay zero";
    all
      (G.name ^ ": of_delay a homomorphism")
      show
      (fun ((_, d), (_, e)) ->
        G.equal bounds
          (G.of_delay (G.Delay.add d e))
          (G.mul (G.of_delay d) (G.of_delay e)))
      (pairs samples);
  ]
  @
  match monotone with
  | None -> []
  | Some monotone ->
      [
        all
          (G.name ^ ": of_delay ordered")
          show
          (fun ((q, d), (r, e)) ->
            let c = Rational.compare (value q) (value r) in
            G.leq bounds (G.of_delay d) (G.of_delay e)
            = if monotone then c <= 0 else c >= 0)
          (pairs samples);
      ]

(* [of_bounds_laws (module G) bounds] checks the time shadow on the sample
   delays of [G] under [bounds]: the shadow of exact bounds [(d, d)] is the
   grade of [delay d], and the grade of a delay [d] with [lo ≤ d ≤ hi] is below
   the shadow of [(lo, hi)]. *)
let of_bounds_laws (module G : Grade.S) bounds =
  let samples = delays (module G.Delay) in
  let le (q, _) (r, _) = Rational.compare (value q) (value r) <= 0 in
  let within =
    List.filter
      (fun (lo, d, hi) -> le lo d && le d hi)
      (List.concat_map
         (fun (lo, hi) -> List.map (fun d -> (lo, d, hi)) samples)
         (pairs samples))
  in
  let show_bounds ((lo, _), (hi, _)) = show_lit lo ^ ", " ^ show_lit hi in
  [
    all
      (G.name ^ ": of_bounds of exact bounds is of_delay")
      (fun (q, _) -> show_lit q)
      (fun (_, d) -> G.equal bounds (G.of_bounds (d, d)) (G.of_delay d))
      samples;
    all
      (G.name ^ ": a delay within the bounds is below of_bounds")
      (fun (lo, (q, _), hi) -> show_lit q ^ " within " ^ show_bounds (lo, hi))
      (fun ((_, lo), (_, d), (_, hi)) ->
        G.leq bounds (G.of_delay d) (G.of_bounds (lo, hi)))
      within;
  ]

(* [declared_laws (module G) ~context bounds samples] checks, on [samples]
   under [bounds], the properties the declarations of [G] assert: that the
   product commutes up to equality if [G.commutative]; that [is_top] decides
   the equality with the top; and that equal representations under [compare]
   are equal grades with equal hashes. *)
let declared_laws (type a) (module G : Grade.S with type t = a) ~context bounds
    (samples : a list) =
  let name law = G.name ^ ": " ^ law in
  let equal = G.equal bounds in
  let show1 x = G.show x ^ " at " ^ context in
  let show2 (x, y) = G.show x ^ ", " ^ G.show y ^ " at " ^ context in
  [
    all
      (name "is_top decides the top")
      show1
      (fun x -> G.is_top bounds x = G.leq bounds G.top x)
      samples;
    all
      (name "compare compatible with equal and hash")
      show2
      (fun (x, y) ->
        implies (G.compare x y = 0) (equal x y && G.hash x = G.hash y))
      (pairs samples);
  ]
  @
  if G.commutative then
    [
      all
        (name "declared commutative")
        show2
        (fun (x, y) -> equal (G.mul x y) (G.mul y x))
        (pairs samples);
    ]
  else []

(* [flag_notes (module G) bounds samples] is the declared flags of [G] that are
   false while [samples] hold no refutation of the property under [bounds]: a
   unit that is least, or a product that commutes, on the samples. A false flag
   only withholds the use of the property, so these are notes, not
   failures. *)
let flag_notes (type a) (module G : Grade.S with type t = a) bounds
    (samples : a list) =
  let equal = G.equal bounds in
  (if
     (not G.unit_least)
     && List.for_all
          (fun x -> implies (G.inhabited bounds x) (G.leq bounds G.one x))
          samples
   then [ G.name ^ ": unit_least is false, and the unit is least on samples" ]
   else [])
  @
  if
    (not G.commutative)
    && List.for_all
         (fun (x, y) -> equal (G.mul x y) (G.mul y x))
         (pairs samples)
  then
    [ G.name ^ ": commutative is false, and the product commutes on samples" ]
  else []

module Constructions = Grades.GradeConstructions

(* [semilattice_laws (module N) ~width samples] checks the laws of a
   join-semilattice with a least and a greatest element on [samples]: [leq] a
   preorder, the join a least upper bound, [bottom] least and [top] greatest,
   and equal representations under [compare] equal elements with equal
   hashes; transitivity and leastness of the join on the pairs of the first
   [width] samples. *)
let semilattice_laws (type a) ?(width = 8)
    (module N : Constructions.SEMILATTICE with type t = a) (samples : a list) =
  let name law = N.name ^ ": " ^ law in
  let show2 (x, y) = N.show x ^ ", " ^ N.show y in
  let show3 (x, y, z) = show2 (x, y) ^ ", " ^ N.show z in
  let some_triples =
    List.concat_map
      (fun (x, y) -> List.map (fun z -> (x, y, z)) samples)
      (pairs (first width samples))
  in
  [
    all (name "reflexive") N.show (fun x -> N.leq x x) samples;
    all (name "transitive") show3
      (fun (x, y, z) -> implies (N.leq x y && N.leq y z) (N.leq x z))
      some_triples;
    all (name "bottom least") N.show (fun x -> N.leq N.bottom x) samples;
    all (name "top greatest") N.show (fun x -> N.leq x N.top) samples;
    all
      (name "join an upper bound")
      show2
      (fun (x, y) -> N.leq x (N.join x y) && N.leq y (N.join x y))
      (pairs samples);
    all (name "join least") show3
      (fun (x, y, z) -> implies (N.leq x z && N.leq y z) (N.leq (N.join x y) z))
      some_triples;
    all
      (name "compare compatible with the order and hash")
      show2
      (fun (x, y) ->
        implies
          (N.compare x y = 0)
          (N.leq x y && N.leq y x && N.hash x = N.hash y))
      (pairs samples);
  ]

(* An action of the grades ['m] on a join-semilattice ['n], with the
   operations of both that the laws of an action involve. *)
type ('m, 'n) action = {
  label : string;
  one : 'm;
  mul : 'm -> 'm -> 'm;
  join : 'm -> 'm -> 'm;
  leq : 'm -> 'm -> bool;
  bottom : 'n;
  join_n : 'n -> 'n -> 'n;
  leq_n : 'n -> 'n -> bool;
  act : 'm -> 'n -> 'n;
  show_m : 'm -> string;
  show_n : 'n -> string;
}

(* [action_of_components (module M) (module N) act bounds] is the action [act]
   of the grade [M] on the semilattice [N], [M] ordered under [bounds]. *)
let action_of_components (type m n) (module M : Grade.S with type t = m)
    (module N : Constructions.SEMILATTICE with type t = n) act bounds =
  {
    label = M.name ^ " on " ^ N.name;
    one = M.one;
    mul = M.mul;
    join = M.join;
    leq = M.leq bounds;
    bottom = N.bottom;
    join_n = N.join;
    leq_n = N.leq;
    act;
    show_m = M.show;
    show_n = N.show;
  }

(* [action_of_semidirect (module G) bounds] is the action of a semidirect
   product [G] of a grade and a semilattice, read off its operations:
   [act m n] is the second component of [(m, ⊥) · (1, n)], and the operations
   of the components those of the pairs [(m, ⊥)] and [(1, n)]. *)
let action_of_semidirect (type m n) (module G : Grade.S with type t = m * n)
    bounds =
  let one, bottom = G.one in
  let first f m m' = fst (f (m, bottom) (m', bottom)) in
  let second f n n' = snd (f (one, n) (one, n')) in
  {
    label = G.name;
    one;
    mul = first G.mul;
    join = first G.join;
    leq = (fun m m' -> G.leq bounds (m, bottom) (m', bottom));
    bottom;
    join_n = second G.join;
    leq_n = (fun n n' -> G.leq bounds (one, n) (one, n'));
    act = (fun m n -> snd (G.mul (m, bottom) (one, n)));
    show_m = (fun m -> G.show (m, bottom));
    show_n = (fun n -> G.show (one, n));
  }

(* [acted (module G) bounds] is the semilattice of the second components of a
   semidirect product [G], ordered and joined as the pairs [(1, n)] under
   [bounds]. *)
let acted (type m n) (module G : Grade.S with type t = m * n) bounds =
  let one, bottom = G.one in
  (module struct
    type t = n

    let name = G.name ^ ": second component"
    let bottom = bottom
    let top = snd G.top
    let join n n' = snd (G.join (one, n) (one, n'))
    let leq n n' = G.leq bounds (one, n) (one, n')
    let compare n n' = G.compare (one, n) (one, n')
    let hash n = G.hash (one, n)
    let of_lit lit = snd (G.of_lit lit)
    let show n = G.show (one, n)
  end : Constructions.SEMILATTICE
    with type t = n)

(* [action_laws a ms ns] checks the laws A1–A5 of the action [a] of the grades
   [ms] on the elements [ns], equality on the elements being mutual order:
   the unit acts trivially (A1), the action of a product is the composite of
   the actions (A2), each action preserves the bottom and the joins (A3), the
   action of a join is the join of the actions (A4), and the action is
   monotone in both arguments (A5). *)
let action_laws a ms ns =
  let name law = a.label ^ ": " ^ law in
  let equal n n' = a.leq_n n n' && a.leq_n n' n in
  let show_mmn (m, m', n) =
    a.show_m m ^ ", " ^ a.show_m m' ^ " on " ^ a.show_n n
  in
  let show_mnn (m, n, n') =
    a.show_m m ^ " on " ^ a.show_n n ^ ", " ^ a.show_n n'
  in
  let mmn =
    List.concat_map
      (fun (m, m') -> List.map (fun n -> (m, m', n)) ns)
      (pairs ms)
  in
  let mnn =
    List.concat_map
      (fun m -> List.map (fun (n, n') -> (m, n, n')) (pairs ns))
      ms
  in
  [
    all
      (name "A1 unit acts trivially")
      a.show_n
      (fun n -> equal (a.act a.one n) n)
      ns;
    all
      (name "A2 action of a product")
      show_mmn
      (fun (m, m', n) -> equal (a.act (a.mul m m') n) (a.act m (a.act m' n)))
      mmn;
    all
      (name "A3 bottom preserved")
      a.show_m
      (fun m -> equal (a.act m a.bottom) a.bottom)
      ms;
    all
      (name "A3 joins preserved")
      show_mnn
      (fun (m, n, n') ->
        equal (a.act m (a.join_n n n')) (a.join_n (a.act m n) (a.act m n')))
      mnn;
    all
      (name "A4 action of a join")
      show_mmn
      (fun (m, m', n) ->
        equal (a.act (a.join m m') n) (a.join_n (a.act m n) (a.act m' n)))
      mmn;
    all
      (name "A5 monotone in the grade")
      show_mmn
      (fun (m, m', n) ->
        implies (a.leq m m') (a.leq_n (a.act m n) (a.act m' n)))
      mmn;
    all
      (name "A5 monotone in the element")
      show_mnn
      (fun (m, n, n') ->
        implies (a.leq_n n n') (a.leq_n (a.act m n) (a.act m n')))
      mnn;
  ]

(* [semidirect_laws (module G) a bounds samples] checks that the product of
   [G] is [(m, n) · (m', n') = (m · m', n ⊔ act m n')] for the action [a] of
   its components, up to equality under [bounds], on the pairs of
   [samples]. *)
let semidirect_laws (type m n) (module G : Grade.S with type t = m * n)
    (a : (m, n) action) bounds (samples : (m * n) list) =
  [
    all
      (G.name ^ ": product of the semidirect product")
      (fun (x, y) -> G.show x ^ ", " ^ G.show y)
      (fun (((m, n) as x), ((m', n') as y)) ->
        G.equal bounds (G.mul x y) (a.mul m m', a.join_n n (a.act m n')))
      (pairs samples);
  ]
