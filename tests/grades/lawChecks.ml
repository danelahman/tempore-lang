(* Named checks and the laws of the grades on samples, shared by the unit tests
   of the grades. *)

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

(* [order_laws (module G) ~context bounds samples] checks the laws of a
   preorder with a monotone product, a join and a top on [samples] under
   [bounds], described by [context] in the reports. *)
let order_laws (type a) (module G : Grade.S with type t = a) ~context bounds
    (samples : a list) =
  let name law = G.name ^ ": " ^ law in
  let leq = G.leq bounds in
  let equal = G.equal bounds in
  let show1 x = G.show x ^ " at " ^ context in
  let show2 (x, y) = G.show x ^ ", " ^ G.show y ^ " at " ^ context in
  let show3 (x, y, z) = show2 (x, y) ^ ", " ^ G.show z in
  let below = List.filter (fun (x, y) -> leq x y) (pairs samples) in
  let triples =
    List.concat_map (fun (x, y) -> List.map (fun z -> (x, y, z)) samples) below
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
         (pairs (List.filteri (fun i _ -> i < 8) samples)));
    all (name "top greatest") show1 (fun x -> leq x G.top) samples;
    all
      (name "equal is mutual leq")
      show2
      (fun (x, y) -> equal x y = (leq x y && leq y x))
      (pairs samples);
  ]
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
   distributes over the join on both sides, on the first eight of
   [samples]. *)
let algebra_laws (type a) (module G : Grade.S with type t = a) ~context bounds
    (samples : a list) =
  let name law = G.name ^ ": " ^ law in
  let equal = G.equal bounds in
  let show1 x = G.show x ^ " at " ^ context in
  let show3 (x, y, z) =
    G.show x ^ ", " ^ G.show y ^ ", " ^ G.show z ^ " at " ^ context
  in
  let some = List.filteri (fun i _ -> i < 8) samples in
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

(* [of_nat_laws (module G) bounds ?monotone] checks that [of_nat] is a monoid
   morphism under [bounds] and, if [monotone] is given, that it is monotone,
   or antitone if [monotone] is false. *)
let of_nat_laws (module G : Grade.S) bounds ?monotone () =
  let ns = pairs (List.init 5 Fun.id) in
  let show (m, n) = Printf.sprintf "%d, %d" m n in
  [
    all
      (G.name ^ ": of_nat a homomorphism")
      show
      (fun (m, n) ->
        G.equal bounds (G.of_nat (m + n)) (G.mul (G.of_nat m) (G.of_nat n)))
      ns;
    all
      (G.name ^ ": of_nat is the unit at 0")
      string_of_int
      (fun n -> G.equal bounds (G.of_nat n) G.one)
      [ 0 ];
  ]
  @
  match monotone with
  | None -> []
  | Some monotone ->
      [
        all
          (G.name ^ ": of_nat ordered")
          show
          (fun (m, n) ->
            G.leq bounds (G.of_nat m) (G.of_nat n)
            = if monotone then m <= n else m >= n)
          ns;
      ]
