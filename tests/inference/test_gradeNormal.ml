(* Unit tests of [GradeExp], [GradeNormal] and [Reach], at the identity grade
   system over each grade of [GradeRegistry.grade_modules]. *)

module Grade = Grades.Grade
module GradeSystem = Grades.GradeSystem
module GradeExp = Inference.GradeExp
module GradeNormal = Inference.GradeNormal
module Reach = Inference.Reach
open TestSupport.Checks

let show_option show = function Some v -> "Some " ^ show v | None -> "None"

let show_ints used =
  "[" ^ String.concat "; " (List.map string_of_int used) ^ "]"

let show_used = show_option show_ints
let show_bool = string_of_bool

let bounds =
  {
    Grade.running_time =
      (fun _ ->
        Grades.Rational.(Grade.Closed (of_int 1), Grade.Closed (of_int 2)));
    operations = [];
  }

module Suite (G : Grade.S) = struct
  module GS = GradeSystem.Identity (G)
  module X = GradeExp.Make (GS)
  module N = GradeNormal.Make (X)

  (* [delay k] is the grade of the delay of the literal [k]. *)
  let delay k = G.of_delay (Option.get (G.Delay.read (Grade.Int k)))
  let hyp lhs rhs info = { GradeNormal.lhs; rhs; info }
  let rho_hyps rho_hyps = { N.no_hyps with rho_hyps }
  let eps_hyps eps_hyps = { N.no_hyps with eps_hyps }
  let x_var = X.Rho_var.fresh_indexed ()
  let y_var = X.Rho_var.fresh_indexed ()
  let z_var = X.Rho_var.fresh_indexed ()
  let w_var = X.Rho_var.fresh_indexed ()
  let x, y, z, w = X.Rho.(var x_var, var y_var, var z_var, var w_var)
  let a_var = X.Eps_var.fresh_indexed ()
  let b_var = X.Eps_var.fresh_indexed ()
  let c_var = X.Eps_var.fresh_indexed ()
  let d_var = X.Eps_var.fresh_indexed ()
  let a, b, c, d = X.Eps.(var a_var, var b_var, var c_var, var d_var)
  let ( * ) = X.Rho.mul
  let ( + ) = X.Rho.join
  let ( *. ) = X.Eps.mul
  let ( +. ) = X.Eps.join
  let n k = X.Rho.const (delay k)
  let en k = X.Eps.const (delay k)
  let top = X.Rho.top
  let map = X.Rho.map
  let rho_name = GradeExp.Rho_var.string_of
  let eps_name = GradeExp.Eps_var.string_of
  let show_rho = X.Rho.to_string
  let show_eps = X.Eps.to_string
  let unit_is_top = G.equal bounds G.one G.top

  (* Whether delays are graded by the unit, as for the security levels. *)
  let ticks_are_unit = G.equal bounds (delay 1) G.one

  (* [same name expected actual] compares resource expressions syntactically. *)
  let same name ~expected actual =
    check name
      (X.Rho.equal bounds expected actual)
      ("expected " ^ show_rho expected ^ ", got " ^ show_rho actual)

  let nf rho = N.Rho.read_back (N.Rho.normal bounds rho)
  let decide_rho hyps rho rho' = N.Rho.decide_leq bounds hyps rho rho'
  let decided_rho hyps rho rho' = Option.is_some (decide_rho hyps rho rho')

  let decided_eps hyps eps eps' =
    Option.is_some (N.Eps.decide_leq bounds hyps eps eps')

  let expressions =
    [
      expect "value of a closed expression" (show_option G.show)
        ~expected:(Some (G.join (G.mul (delay 2) (delay 3)) (delay 1)))
        (X.Rho.value ((n 2 * n 3) + n 1));
      expect "value of an open expression" (show_option G.show) ~expected:None
        (X.Rho.value (x * n 1));
      check "value of an image"
        (match X.Rho.value (X.Rho_map (X.Eps.mul (en 1) (en 2))) with
        | Some v -> G.equal bounds v (delay 3)
        | None -> false)
        "expected the value 3";
      check "free resource variables"
        (X.Rho_var.Set.equal
           (X.Rho.free_rho_vars ((x * map a) + y))
           (X.Rho_var.Set.of_list [ x_var; y_var ]))
        "expected {x, y}";
      check "free effect variables"
        (X.Eps_var.Set.equal
           (X.Rho.free_eps_vars ((x * map a) + y))
           (X.Eps_var.Set.singleton a_var))
        "expected {a}";
      same "substitution"
        ~expected:(y * z * map b)
        (X.Rho.subst
           {
             X.rho_subst = X.Rho_var.Map.singleton x_var (y * z);
             eps_subst = X.Eps_var.Map.singleton a_var b;
           }
           (x * map a));
      expect "printing" Fun.id
        ~expected:
          (Printf.sprintf "%s · (%s ⊔ %s)" (rho_name x_var) (rho_name y_var)
             (rho_name z_var))
        (show_rho (x * (y + z)));
      expect "printing products flat" Fun.id
        ~expected:
          (Printf.sprintf "%s · %s · %s" (rho_name x_var) (rho_name y_var)
             (rho_name z_var))
        (show_rho (x * (y * z)));
      expect "printing an image" Fun.id
        ~expected:
          (Printf.sprintf "∣%s ⊔ %s∣ ⊔ %s" (eps_name a_var) (eps_name b_var)
             (rho_name x_var))
        (show_rho (map (a +. b) + x));
    ]

  let normal_forms =
    [
      same "unit dropped" ~expected:x (nf (x * n 0));
      same "constants multiplied" ~expected:(n 5) (nf (n 2 * n 3));
      same "the unit is the empty product" ~expected:X.Rho.unit (nf (n 0));
      same "product distributed over a join"
        ~expected:((x * y) + (x * z))
        (nf (x * (y + z)));
      same "repeats merged" ~expected:x (nf (x + x));
      same "products sorted when commutative"
        ~expected:(if G.commutative then x * y else y * x)
        (nf (y * x));
      same "constants in front when commutative"
        ~expected:
          (if ticks_are_unit then x
           else if G.commutative then n 2 * x
           else x * n 2)
        (nf (x * n 2));
      same "the top absorbs a join" ~expected:top (nf (x + top));
      same "an image is a product of images"
        ~expected:(map a * map b)
        (nf (map (a *. b)));
      same "the image of a constant" ~expected:(n 2) (nf (map (en 2)));
      expect "fold_sum folds a group varying in one slot" string_of_int
        ~expected:1
        (List.length
           (N.Rho.fold_sum bounds (N.Rho.normal bounds ((n 1 * x) + (n 2 * x)))));
      same "fold_sum joins the varying slot"
        ~expected:
          (if ticks_are_unit then x
           else X.Rho.const (G.join (delay 1) (delay 2)) * x)
        (N.Rho.read_back
           (N.Rho.fold_sum bounds (N.Rho.normal bounds ((n 1 * x) + (n 2 * x)))));
    ]

  let decisions =
    let chain = rho_hyps [ hyp x y 1; hyp y z 2 ] in
    let crossed = eps_hyps [ hyp c b 1; hyp d a 2 ] in
    [
      check "reflexivity" (decided_rho N.no_hyps x x) "x ≾ x not decided";
      check "below a join"
        (decided_rho N.no_hyps x (x + y))
        "x ≾ x ⊔ y not decided";
      check "joins commute"
        (decided_rho N.no_hyps (x + y) (y + x))
        "x ⊔ y ≾ y ⊔ x not decided";
      expect "products commute only when commutative" show_bool
        ~expected:G.commutative
        (decided_rho N.no_hyps (x * y) (y * x));
      expect "the unit is below a variable only when least" show_bool
        ~expected:G.unit_least
        (decided_rho N.no_hyps X.Rho.unit x);
      check "below the top" (decided_rho N.no_hyps x top) "x ≾ ⊤ not decided";
      expect "a factor dropped on the left only when the unit is the top"
        show_bool ~expected:(G.leq bounds G.top G.one)
        (decided_rho N.no_hyps (x * y) x);
      expect "a factor added on the right only when the unit is least" show_bool
        ~expected:G.unit_least
        (decided_rho N.no_hyps x (x * y));
      expect "constants compared by the grade" show_bool
        ~expected:(G.leq bounds (delay 2) (delay 3))
        (decided_rho N.no_hyps (n 2) (n 3));
      expect "hypotheses chained" show_used
        ~expected:(Some [ 1; 2 ])
        (decide_rho chain x z);
      expect "no hypotheses, no chain" show_used ~expected:None
        (decide_rho N.no_hyps x z);
      expect "a chain is not reversed" show_used ~expected:None
        (decide_rho chain z x);
      expect "crossed factors match only when commutative" show_bool
        ~expected:G.commutative
        (decided_eps crossed (c *. d) (a *. b));
      check "crossed factors without hypotheses"
        (not (decided_eps N.no_hyps (c *. d) (a *. b)))
        "c · d ≾ a · b decided at no hypotheses";
      check "factors in order match"
        (decided_eps crossed (d *. c) (a *. b))
        "d · c ≾ a · b not decided";
      expect "crossed resource factors" show_bool ~expected:G.commutative
        (decided_rho (rho_hyps [ hyp z y 1; hyp w x 2 ]) (z * w) (x * y));
      expect "crossed images" show_bool ~expected:G.commutative
        (decided_rho
           (rho_hyps [ hyp z (map a) 1; hyp (map b) x 2 ])
           (z * map b)
           (x * map a));
      expect "an effect hypothesis carried to the images" show_used
        ~expected:(Some [ 7 ])
        (decide_rho (eps_hyps [ hyp a b 7 ]) (map a) (map b));
      expect "chains mixing resource and effect hypotheses" show_used
        ~expected:(Some [ 1; 2 ])
        (decide_rho
           { N.rho_hyps = [ hyp x (map a) 1 ]; eps_hyps = [ hyp a b 2 ] }
           x (map b));
      check "a product hypothesis used"
        (decided_rho (rho_hyps [ hyp (x * y) z 1 ]) (x * y) z)
        "x · y ≾ z not decided from itself";
      check "a product hypothesis not used by the atomic fragment"
        (Option.is_none
           (N.Rho.decide_leq_atomic bounds
              (rho_hyps [ hyp (x * y) z 1 ])
              (x * y) z))
        "x · y ≾ z decided from a non-atomic hypothesis";
      expect "a chain through a product" show_used
        ~expected:(Some [ 1; 2 ])
        (decide_rho (rho_hyps [ hyp x (y * z) 1; hyp (y * z) w 2 ]) x w);
      expect "a chain from a product" show_used
        ~expected:(Some [ 1; 2 ])
        (decide_rho (rho_hyps [ hyp (x * y) z 1; hyp z w 2 ]) (x * y) w);
      expect "a factor below its product only when the unit is least" show_bool
        ~expected:G.unit_least
        (decided_rho (rho_hyps [ hyp (x * y) z 1 ]) x z);
      check "a factor below its product, the unit below the other factor"
        (decided_rho (rho_hyps [ hyp X.Rho.unit y 1; hyp (x * y) z 2 ]) x z)
        "x ≾ z not decided from 1 ≾ y and x · y ≾ z";
      expect "an effect chain through a product carried to the images" show_used
        ~expected:(Some [ 1; 2 ])
        (decide_rho
           (eps_hyps [ hyp a (b *. c) 1; hyp (b *. c) d 2 ])
           (map a) (map d));
    ]
    @
    if G.name = "time-upper-bound" then
      [
        check "crossed constant"
          (decided_eps (eps_hyps [ hyp (en 3) b 1 ]) (en 3 *. a) (a *. b))
          "3 · a ≾ a · b not decided";
        check "crossed constant without hypotheses"
          (not (decided_eps N.no_hyps (en 3 *. a) (a *. b)))
          "3 · a ≾ a · b decided at no hypotheses";
      ]
    else if G.commutative && not unit_is_top then
      [
        check "the top matched crosswise"
          (decided_eps N.no_hyps (a *. b) (X.Eps.top *. a))
          "a · b ≾ ⊤ · a not decided";
        check "the top matched crosswise, converse"
          (not (decided_eps N.no_hyps (X.Eps.top *. a) (a *. b)))
          "⊤ · a ≾ a · b decided";
      ]
    else []

  let canonical_forms =
    let canon = N.Rho.canon bounds in
    [
      same "a product with the top"
        ~expected:
          (if G.unit_least then top
           else if unit_is_top then x
           else if G.commutative then top * x
           else x * top)
        (canon (x * top));
      check "an effect product with the top"
        (X.Eps.equal bounds
           (N.Eps.canon bounds (a *. X.Eps.top))
           (if G.unit_least then X.Eps.top
            else if unit_is_top then a
            else if G.commutative then X.Eps.top *. a
            else a *. X.Eps.top))
        (show_eps (N.Eps.canon bounds (a *. X.Eps.top)));
      same "an alternative below another pruned"
        ~expected:
          (if G.unit_least then x * y else if unit_is_top then x else x + (x * y))
        (canon (x + (x * y)));
      same "constants joined"
        ~expected:(X.Rho.const (G.join (delay 1) (delay 2)))
        (canon (n 1 + n 2));
    ]
    @
    if G.unit_least then
      [
        same "a product with the top absorbs a join" ~expected:top
          (canon ((x * top) + y));
        same "an image times the top" ~expected:top (canon (map a * top));
      ]
    else []

  let splits =
    let show_split show os =
      String.concat "; "
        (List.map
           (fun o ->
             show o.GradeNormal.lhs ^ " ≾ " ^ show o.rhs ^ " @"
             ^ string_of_int o.info)
           os)
    in
    let rho_split =
      N.Rho.canon_orderings bounds [ hyp (x + y) z 1; hyp z (x + y) 2 ]
    in
    let eps_split =
      N.Eps.canon_orderings bounds [ hyp (a +. b) c 1; hyp c (a +. b) 2 ]
    in
    let same_orderings equal expected actual =
      List.equal
        (fun o o' ->
          equal bounds o.GradeNormal.lhs o'.GradeNormal.lhs
          && equal bounds o.rhs o'.rhs && o.info = o'.info)
        expected actual
    in
    [
      check "a resource join on the left split"
        (same_orderings X.Rho.equal
           [ hyp x z 1; hyp y z 1; hyp z (x + y) 2 ]
           rho_split)
        (show_split show_rho rho_split);
      check "an effect join on the left split"
        (same_orderings X.Eps.equal
           [ hyp a c 1; hyp b c 1; hyp c (a +. b) 2 ]
           eps_split)
        (show_split show_eps eps_split);
    ]

  let closed_checks =
    let fails lhs rhs = not (G.leq bounds (delay lhs) (delay rhs)) in
    let above_unit = G.join G.one (delay 1) in
    let failure_info = function
      | Ok _ -> None
      | Error (failure : (_, int list) GradeNormal.ordering) ->
          Some failure.info
    in
    [
      expect "closed sides joined by a chain" show_used
        ~expected:(if fails 3 2 then Some [ 1; 2 ] else None)
        (failure_info
           (N.Rho.check_closed bounds [ hyp (n 3) x 1; hyp x (n 2) 2 ]));
      expect "closed sides joined by a long chain" show_used
        ~expected:(if fails 5 4 then Some [ 1; 3; 4; 2 ] else None)
        (failure_info
           (N.Eps.check_closed bounds
              [ hyp (en 5) a 1; hyp b (en 4) 2; hyp a c 3; hyp c b 4 ]));
      expect "a chain from a factor to its product" show_used
        ~expected:(if G.unit_least && fails 10 5 then Some [ 1; 2 ] else None)
        (failure_info
           (N.Eps.check_closed bounds
              [ hyp (en 10) b 1; hyp (a *. b) (en 5) 2 ]));
      expect "a chain from a constant factor" show_used
        ~expected:(if G.unit_least && fails 3 2 then Some [ 1 ] else None)
        (failure_info (N.Eps.check_closed bounds [ hyp (en 3 *. a) (en 2) 1 ]));
      expect "a chain from the constants around a variable" show_used
        ~expected:
          (if
             G.unit_least
             && (fails 2 5 || fails 3 5
                || not (G.leq bounds (G.mul (delay 2) (delay 3)) (delay 5)))
           then Some [ 1 ]
           else None)
        (failure_info
           (N.Eps.check_closed bounds [ hyp (en 2 *. a *. en 3) (en 5) 1 ]));
      expect "a chain from a resource factor" show_used
        ~expected:(if G.unit_least && fails 10 5 then Some [ 1; 2 ] else None)
        (failure_info
           (N.Rho.check_closed bounds
              [ hyp (n 10) (map b) 1; hyp (x * map b) (n 5) 2 ]));
      expect "a chain from a factor of an image" show_used
        ~expected:(if G.unit_least && fails 10 5 then Some [ 1; 2 ] else None)
        (failure_info
           (N.Rho.check_closed bounds
              [ hyp (n 10) (map b) 1; hyp (map (a *. b)) (n 5) 2 ]));
      expect "a factor above the unit by a hypothesis" show_bool
        ~expected:(fails 3 2)
        (Result.is_error
           (N.Eps.check_closed bounds
              [ hyp X.Eps.unit a 1; hyp (en 3 *. a) (en 2) 2 ]));
      expect "a factor above the unit by a chain through a constant" show_bool
        ~expected:
          (fails 3 2
          || G.leq bounds G.one (delay 3)
             && not (G.leq bounds above_unit (delay 2)))
        (Result.is_error
           (N.Eps.check_closed bounds
              [
                hyp X.Eps.unit (X.Eps.const above_unit) 1;
                hyp (X.Eps.const above_unit) a 2;
                hyp (en 3 *. a) (en 2) 3;
              ]));
      expect "a factor above the unit through the product of two" show_bool
        ~expected:(fails 3 2)
        (Result.is_error
           (N.Eps.check_closed bounds
              [
                hyp X.Eps.unit a 1;
                hyp X.Eps.unit d 2;
                hyp (a *. d) b 3;
                hyp (en 3 *. b) (en 2) 4;
              ]));
      expect "a factor below the unit is not above it" show_bool
        ~expected:(G.unit_least && fails 3 2)
        (Result.is_error
           (N.Eps.check_closed bounds
              [ hyp a X.Eps.unit 1; hyp (en 3 *. a) (en 2) 2 ]));
      expect "a factor is below its product only where the unit is least"
        show_bool
        ~expected:(not (G.unit_least && not (G.leq bounds G.top (delay 1))))
        (Result.is_ok
           (N.Eps.check_closed bounds
              [ hyp X.Eps.top b 1; hyp (a *. b) (en 1) 2 ]));
      expect "a chain that holds keeps the set" string_of_int ~expected:2
        (match N.Rho.check_closed bounds [ hyp (n 2) x 1; hyp x (n 2) 2 ] with
        | Ok kept -> List.length kept
        | Error _ -> -1);
      expect "a closed ordering that holds dropped" string_of_int ~expected:1
        (match
           N.Rho.check_closed bounds [ hyp (n 1) (n 1 + n 2) 1; hyp x y 2 ]
         with
        | Ok kept -> List.length kept
        | Error _ -> -1);
      expect "a closed ordering that fails" show_used
        ~expected:(if G.leq bounds G.top (delay 1) then None else Some [ 4 ])
        (failure_info
           (N.Rho.check_closed bounds [ hyp x y 3; hyp top (n 1) 4 ]));
      expect "an open ordering is not closed" (show_option show_bool)
        ~expected:None
        (N.Rho.closed_leq bounds x (n 1));
      check "a failure named by its sort"
        (match
           N.check_closed_hyps bounds
             { N.rho_hyps = [ hyp (n 3) x 1; hyp x (n 2) 2 ]; eps_hyps = [] }
         with
        | Error (N.Rho_failure _) -> fails 3 2
        | Error (N.Eps_failure _) -> false
        | Ok _ -> not (fails 3 2))
        "unexpected verdict of check_closed_hyps";
    ]

  let refutations =
    let refuted_by rho = Option.map G.show (N.Rho.refute_leq_unit bounds rho) in
    let three =
      if G.leq bounds (delay 3) G.one then None else Some (G.show (delay 3))
    in
    [
      expect "a constant factor above the unit" (show_option Fun.id)
        ~expected:three
        (refuted_by (x * n 3));
      expect "a variable is never refuted" (show_option Fun.id) ~expected:None
        (refuted_by x);
      expect "one refuted alternative refutes a join" (show_option Fun.id)
        ~expected:three
        (refuted_by (x + n 3));
      expect "an image refuted" (show_option Fun.id) ~expected:three
        (refuted_by (map (a *. en 3)));
    ]

  (* The closure of one tick, where the grade declares one: its laws, and
     [c⁺ ≾ a] entailed by [c ≾ a] and [a · a ≾ a]. *)
  let closures =
    let module E = Inference.Entail.Make (X) in
    let c = delay 1 in
    match G.plus c with
    | None -> []
    | Some plus ->
        let entail =
          E.make bounds (eps_hyps [ hyp (en 1) a 1; hyp (a *. a) a 2 ])
        in
        [
          check "a grade below its closure" (G.leq bounds c plus)
            ("not " ^ G.show c ^ " ≾ " ^ G.show plus);
          check "a closure absorbs its square"
            (G.leq bounds (G.mul plus plus) plus)
            ("not " ^ G.show plus ^ " · " ^ G.show plus ^ " ≾ " ^ G.show plus);
          check "a closure is its own closure"
            (Option.fold ~none:false
               ~some:(fun p -> G.equal bounds p plus)
               (G.plus plus))
            (G.show plus ^ " is not its own closure");
          check "a closure entailed below an idempotent upper bound"
            (E.Eps.follows entail (X.Eps.const plus) a)
            (G.show plus ^ " ≾ a not entailed");
          check "a closure entailed as a left multiplier"
            (E.Eps.follows
               (E.make bounds (eps_hyps [ hyp (en 1 *. a) a 1 ]))
               (X.Eps.const plus *. a)
               a)
            (G.show plus ^ " · a ≾ a not entailed");
          check "a closure entailed as a right multiplier"
            (E.Eps.follows
               (E.make bounds (eps_hyps [ hyp (a *. en 1) a 1 ]))
               (a *. X.Eps.const plus)
               a)
            ("a · " ^ G.show plus ^ " ≾ a not entailed");
        ]
        @ List.concat_map
            (fun d ->
              let shown = G.show d in
              [
                check
                  ("left induction at " ^ shown)
                  ((not (G.leq bounds (G.mul c d) d))
                  || G.leq bounds (G.mul plus d) d)
                  (G.show plus ^ " · " ^ shown ^ " not below " ^ shown);
                check
                  ("right induction at " ^ shown)
                  ((not (G.leq bounds (G.mul d c) d))
                  || G.leq bounds (G.mul d plus) d)
                  (shown ^ " · " ^ G.show plus ^ " not below " ^ shown);
              ])
            [
              G.one;
              c;
              delay 3;
              G.top;
              plus;
              G.join c (delay 3);
              G.mul plus (delay 3);
            ]

  (* The value of lowering [v] = [a] under lower bounds and cycles: where the
     grade gives one, every cycle and lower bound holds at it; at the time
     upper bounds and intervals, cycles of several shapes give the closure of a
     tick, the unit and a tick a step give the closure of a tick above the
     unit, and a cycle of no shape read gives no value. *)
  let lowering =
    let module V = Inference.Values.Make (X) in
    let sort = V.eps bounds a_var in
    let oracle =
      {
        Inference.Values.may_lower = (fun _ -> true);
        may_raise = (fun _ -> true);
      }
    in
    let value orderings =
      Option.map
        (fun (v : _ Inference.Values.value) -> v.value)
        (Inference.Values.lower sort oracle
           (List.mapi (fun i (lhs, rhs) -> hyp lhs rhs i) orderings))
    in
    let at x e =
      X.Eps.subst
        { X.empty_subst with eps_subst = X.Eps_var.Map.singleton a_var x }
        e
    in
    let holds orderings =
      match value orderings with
      | None -> true
      | Some x ->
          List.for_all
            (fun (lhs, rhs) ->
              Option.is_some
                (N.Eps.decide_leq bounds N.no_hyps (at x lhs) (at x rhs)))
            orderings
    in
    let mixed_linear = [ (en 1, a); (en 2 *. a, a); (a *. en 3, a) ]
    and square_linear = [ (en 1, a); (en 2 *. a, a); (a *. a, a) ]
    and tick = [ (en 0, a); (en 1 *. a, a) ]
    and other = [ (en 1, a); (en 1 *. a *. a, a) ] in
    let show = show_option show_eps in
    let named = G.name = "time-upper-bound" || G.name = "time-interval" in
    let closure g = Option.map X.Eps.const (G.plus g) in
    let same_grade name expected actual =
      check name
        (match (expected, Option.bind actual X.Eps.value) with
        | Some e, Some x -> G.equal bounds (Option.get (X.Eps.value e)) x
        | None, None -> Option.is_none actual
        | _ -> false)
        ("expected " ^ show expected ^ ", got " ^ show actual)
    in
    List.map
      (fun (name, orderings) ->
        check
          ("lowering holds: " ^ name)
          (holds orderings)
          ("value " ^ show (value orderings)))
      [
        ("left and right multipliers", mixed_linear);
        ("a square and a multiplier", square_linear);
        ("a tick a step", tick);
        ("a cycle of no shape read", other);
      ]
    @
    if named then
      [
        same_grade "left and right multipliers"
          (closure (delay 1))
          (value mixed_linear);
        same_grade "a square and a multiplier"
          (closure (delay 1))
          (value square_linear);
        same_grade "a tick a step"
          (Option.map
             (fun p -> X.Eps.const (G.join G.one (G.mul p G.one)))
             (G.plus (delay 1)))
          (value tick);
        same_grade "a cycle of no shape read" None (value other);
      ]
    else []

  let run () =
    List.map
      (fun c -> { c with name = G.name ^ ": " ^ c.name })
      (expressions @ normal_forms @ decisions @ canonical_forms @ splits
     @ closed_checks @ refutations @ closures @ lowering)
end

let variable_names =
  let module Rho_var = GradeExp.Rho_var in
  let module Eps_var = GradeExp.Eps_var in
  let rho_var = Rho_var.fresh_indexed () in
  let rho_var' = Rho_var.fresh_indexed () in
  let eps_var = Eps_var.fresh_indexed () in
  let subscripted letter name =
    String.starts_with ~prefix:letter name
    && String.length name > String.length letter
  in
  [
    check "resource variables named ρ with a subscript"
      (subscripted "ρ" (Rho_var.string_of rho_var))
      (Rho_var.string_of rho_var);
    check "effect variables named ε with a subscript"
      (subscripted "ε" (Eps_var.string_of eps_var))
      (Eps_var.string_of eps_var);
    check "fresh variables distinct"
      ((not (Rho_var.equal rho_var rho_var'))
      && Rho_var.string_of rho_var <> Rho_var.string_of rho_var')
      (Rho_var.string_of rho_var ^ " and " ^ Rho_var.string_of rho_var');
  ]

let reachability =
  let cycle = Reach.graph 4 [ (0, 1, "a"); (1, 2, "b"); (2, 0, "c") ] in
  let detour =
    Reach.graph 5
      [ (0, 2, "a"); (2, 3, "b"); (3, 1, "c"); (0, 4, "d"); (4, 1, "e") ]
  in
  let ties =
    Reach.graph 4
      [ (0, 2, "a"); (0, 1, "b"); (1, 3, "c"); (2, 3, "d"); (1, 3, "e") ]
  in
  let show_chain = show_option (String.concat ",") in
  [
    expect "reach: a chain of two edges" show_chain
      ~expected:(Some [ "a"; "b" ])
      (Reach.chain cycle 0 2);
    expect "reach: a chain round the cycle" show_chain
      ~expected:(Some [ "c"; "a" ])
      (Reach.chain cycle 2 1);
    expect "reach: the diagonal" show_chain ~expected:(Some [])
      (Reach.chain cycle 3 3);
    expect "reach: unreachable" show_chain ~expected:None
      (Reach.chain cycle 0 3);
    expect "reach: the shortest chain, not the one along the first edges"
      show_chain
      ~expected:(Some [ "d"; "e" ])
      (Reach.chain detour 0 1);
    expect "reach: ties broken by the order of the edges" show_chain
      ~expected:(Some [ "a"; "d" ])
      (Reach.chain ties 0 3);
    expect "reach: one search for every target" (String.concat ";")
      ~expected:[ ""; "b"; "a"; "a,d" ]
      (let from = Reach.chain ties 0 in
       List.map
         (fun j -> String.concat "," (Option.get (from j)))
         [ 0; 1; 2; 3 ]);
    expect "reach: the vertices reached" (String.concat ",")
      ~expected:[ "0"; "1"; "2" ]
      (List.filter_map
         (fun i ->
           if Reach.reached cycle [ 1 ] i then Some (string_of_int i) else None)
         [ 0; 1; 2; 3 ]);
  ]

let () =
  let checks =
    variable_names @ reachability
    @ List.concat_map
        (fun (_, (module G : Grade.S)) ->
          let module S = Suite (G) in
          S.run ())
        Grades.GradeRegistry.grade_modules
  in
  report checks
