(* Unit tests of [GradeExp], [GradeNormal] and [Reach], at the identity grade
   system over each grade of [GradeRegistry.grade_modules]. *)

module Grade = Grades.Grade
module GradeSystem = Grades.GradeSystem
module GradeExp = Inference.GradeExp
module GradeNormal = Inference.GradeNormal
module Reach = Inference.Reach

type check = { name : string; passed : bool; detail : string }

let check name passed detail = { name; passed; detail }
let show_option show = function Some v -> "Some " ^ show v | None -> "None"

let show_ints used =
  "[" ^ String.concat "; " (List.map string_of_int used) ^ "]"

let show_used = show_option show_ints
let show_bool = string_of_bool

(* [expect name show ~expected actual] passes when the two agree. *)
let expect name show ~expected actual =
  check name (expected = actual)
    ("expected " ^ show expected ^ ", got " ^ show actual)

let bounds _ = (1, 2)

module Suite (G : Grade.S) = struct
  module GS = GradeSystem.Identity (G)
  module X = GradeExp.Make (GS)
  module N = GradeNormal.Make (X)

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
  let n = X.Rho.of_nat
  let en = X.Eps.of_nat
  let top = X.Rho.top
  let map = X.Rho.map
  let rho_name = GradeExp.Rho_var.string_of
  let eps_name = GradeExp.Eps_var.string_of
  let show_rho = X.Rho.to_string
  let show_eps = X.Eps.to_string
  let unit_is_top = G.equal bounds G.one G.top

  (* Whether ticks are graded by the unit, as for the security levels. *)
  let ticks_are_unit = G.equal bounds (G.of_nat 1) G.one

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
        ~expected:(Some (G.join (G.mul (G.of_nat 2) (G.of_nat 3)) (G.of_nat 1)))
        (X.Rho.value ((n 2 * n 3) + n 1));
      expect "value of an open expression" (show_option G.show) ~expected:None
        (X.Rho.value (x * n 1));
      check "value of an image"
        (match X.Rho.value (X.Rho_map (X.Eps.mul (en 1) (en 2))) with
        | Some v -> G.equal bounds v (G.of_nat 3)
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
           else X.Rho.const (G.join (G.of_nat 1) (G.of_nat 2)) * x)
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
        ~expected:(G.leq bounds (G.of_nat 2) (G.of_nat 3))
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
      check "a product hypothesis is not used"
        (not (decided_rho (rho_hyps [ hyp (x * y) z 1 ]) (x * y) z))
        "x · y ≾ z decided from a non-atomic hypothesis";
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
        ~expected:(X.Rho.const (G.join (G.of_nat 1) (G.of_nat 2)))
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
    let fails lhs rhs = not (G.leq bounds (G.of_nat lhs) (G.of_nat rhs)) in
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
        ~expected:(if G.leq bounds G.top (G.of_nat 1) then None else Some [ 4 ])
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
      if G.leq bounds (G.of_nat 3) G.one then None
      else Some (G.show (G.of_nat 3))
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

  let run () =
    List.map
      (fun c -> { c with name = G.name ^ ": " ^ c.name })
      (expressions @ normal_forms @ decisions @ canonical_forms @ splits
     @ closed_checks @ refutations)
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
  let closure =
    Reach.closure ~equal:Int.equal [ 1; 2; 3; 4 ]
      [ (1, 2, "a"); (2, 3, "b"); (3, 1, "c") ]
  in
  let show_chain = show_option (String.concat ",") in
  [
    expect "reach: a chain through a pivot" show_chain
      ~expected:(Some [ "a"; "b" ])
      (Reach.reach closure 1 3);
    expect "reach: a chain round the cycle" show_chain
      ~expected:(Some [ "c"; "a" ])
      (Reach.reach closure 3 2);
    expect "reach: the diagonal" show_chain ~expected:(Some [])
      (Reach.reach closure 4 4);
    expect "reach: unreachable" show_chain ~expected:None
      (Reach.reach closure 1 4);
    expect "reach: not a vertex" show_chain ~expected:None
      (Reach.reach closure 1 5);
    expect "reach: on a cycle" show_bool ~expected:true
      (Reach.on_cycle closure 1);
    expect "reach: off every cycle" show_bool ~expected:false
      (Reach.on_cycle closure 4);
    expect "reach: representative"
      (show_option (fun (r, there, back) ->
           string_of_int r ^ " " ^ String.concat "," there ^ " "
           ^ String.concat "," back))
      ~expected:(Some (3, [ "a"; "b" ], [ "c" ]))
      (Reach.representative closure [ 4; 3; 2; 1 ] 1);
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
  let failures = List.filter (fun c -> not c.passed) checks in
  List.iter (fun c -> Printf.printf "FAIL %s: %s\n" c.name c.detail) failures;
  Printf.printf "%d of %d checks passed\n"
    (List.length checks - List.length failures)
    (List.length checks);
  if failures <> [] then exit 1
