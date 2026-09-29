(* Tests of the reported schemes: small programs on the standard library,
   report simplification, annotations, boxes and handlers, whose schemes are
   compared up to renaming with the expected ones at four grades, recursive
   definitions, compared at one, and annotated function types, printed as they
   are written. Silent on success. *)

module Ast = Language.Ast
module Grade = Grades.Grade
module GradeSystem = Grades.GradeSystem

let failures = ref []
let fail fmt = Format.kasprintf (fun msg -> failures := msg :: !failures) fmt
let verbose = Array.exists (( = ) "-v") Sys.argv

(* ------------------------------------------------------------------ *)
(* Programs                                                            *)
(* ------------------------------------------------------------------ *)

(* A scheme up to renaming: its type, the unknowns named in the order of
   their first occurrence, and the atoms of its qualifier, sorted. *)
type canonical = { ty : string; atoms : string list }

module Programs (G : Grade.S) = struct
  module GS = GradeSystem.Identity (G)
  module X = Inference.GradeExp.Make (GS)
  module C = Inference.Constraint.Make (X)
  module Gen = Inference.Generate.Make (C)
  module P = Inference.Program.Make (C)
  module D = Desugarer.Make (GS)
  module Grammar = Parser.Grammar.Make (GS)

  let parse ~name source =
    let lexbuf = Lexing.from_string source in
    lexbuf.lex_curr_p <- { lexbuf.lex_curr_p with pos_fname = name };
    Grammar.commands (Parser.Lexer.tokens ()) lexbuf

  let initial =
    List.fold_left
      (fun (desugarer, env) prim ->
        let x = Ast.Variable.fresh (Language.Primitives.primitive_name prim) in
        (D.load_primitive desugarer x prim, Gen.load_primitive env x prim))
      (D.initial_state, Gen.initial_env)
      Language.Primitives.primitives

  (* The commands executed in order: the state after, and the outcome of
     each top-level definition by name. *)
  let execute state cmds =
    List.fold_left
      (fun ((desugarer, env), outcomes) cmd ->
        let desugarer, cmd = D.desugar_command desugarer cmd in
        let env, (verdict : P.verdict), _ = P.execute env cmd in
        let outcomes =
          match (cmd.it, verdict.outcome) with
          | Ast.TopLet (x, _), outcome ->
              (Ast.Variable.string_of x, outcome) :: outcomes
          | _, _ -> outcomes
        in
        ((desugarer, env), outcomes))
      (state, []) cmds

  let with_stdlib =
    lazy (fst (execute initial (parse ~name:"stdlib.tpe" Loader.stdlib_source)))

  let flatten text =
    String.concat " "
      (List.filter (( <> ) "")
         (String.split_on_char ' '
            (String.map (function '\n' -> ' ' | c -> c) text)))

  let rec conjuncts = function
    | C.True -> []
    | C.And (c, d) -> conjuncts c @ conjuncts d
    | c -> [ c ]

  let canonical (scheme : C.scheme) =
    let names = C.names () in
    let ty = Format.asprintf "%t" (C.print_ty ~names scheme.ty) in
    let atoms =
      List.map
        (fun c -> flatten (Format.asprintf "%t" (C.print_inline ~names c)))
        (conjuncts scheme.qualifier)
    in
    { ty; atoms = List.sort String.compare atoms }

  (* The scheme of each definition of [source], after the standard library,
     or [None] where it is rejected; the program declares the operations of
     [source], the standard library declaring none. *)
  let schemes source =
    let cmds = parse ~name:"small" source in
    let desugarer, env = Lazy.force with_stdlib in
    let env = Gen.declare_operations (Loader.declared_operations cmds) env in
    let _, outcomes = execute (desugarer, env) cmds in
    List.rev_map
      (fun (name, outcome) ->
        match outcome with
        | P.Defined (_, scheme) ->
            if verbose then
              Format.eprintf "%s %s: %a@." G.name name
                (fun ppf s -> C.print_scheme s ppf)
                scheme;
            (name, Some (canonical scheme))
        | P.Accepted | P.Rejected _ -> (name, None))
      outcomes

  (* The printed argument type of each function defined in [source], or [None]
     where the definition is rejected or not a function. *)
  let argument_types source =
    let _, outcomes = execute initial (parse ~name:"annotations" source) in
    List.rev_map
      (fun (name, outcome) ->
        match outcome with
        | P.Defined (_, { C.ty = Ast.TyArrow (argument, _); _ }) ->
            (name, Some (Format.asprintf "%t" (C.print_ty argument)))
        | P.Defined _ | P.Accepted | P.Rejected _ -> (name, None))
      outcomes

  module S = Inference.Solver.Make (C)

  (* The scheme of [a → b] under [a <: b], generalised with the unknowns of
     [fixed] free in the environment: a fixed unknown is neither eliminated
     nor quantified. *)
  let fixed_unknowns () =
    let a = Ast.TyParamModule.fresh "a" and b = Ast.TyParamModule.fresh "b" in
    let pos = { Utils.Location.line = 1; column = 1; offset = 0 } in
    let loc = { Utils.Location.filename = "fixed"; start = pos; stop = pos } in
    let because = Inference.Reason.because loc Inference.Reason.Annotation in
    let ty =
      Ast.TyArrow (Ast.TyParam a, Ast.CompTy (Ast.TyParam b, X.Eps.unit))
    in
    let fixing params : C.free =
      { C.no_free with free_tys = Ast.TyParamSet.of_list params }
    in
    let context = P.context ~loc Gen.initial_env in
    match S.solve context (C.Sub (because, Ast.TyParam a, Ast.TyParam b)) with
    | S.Solved solution ->
        List.map
          (fun (label, fixed) ->
            let scheme = S.generalise ~fixed:(fixing fixed) ty solution in
            let names = C.names () in
            let fixed_name =
              List.map
                (fun p ->
                  Format.asprintf "%t" (C.print_ty ~names (Ast.TyParam p)))
                fixed
            in
            ( label,
              String.concat " "
                (fixed_name
                @ [
                    flatten
                      (Format.asprintf "%t" (C.print_scheme ~names scheme));
                  ]) ))
          [ ("none", []); ("argument", [ a ]); ("result", [ b ]) ]
    | S.Refuted _ | S.Stuck _ -> [ ("solved", "no solution") ]
end

let grade_module name =
  match List.assoc_opt name Grades.GradeRegistry.grade_modules with
  | Some g -> g
  | None -> failwith ("unknown grades " ^ name)

(* ------------------------------------------------------------------ *)
(* The programs, in the surface syntax                                 *)
(* ------------------------------------------------------------------ *)

(* The literal of [n] time steps, and the declarations of the operations:
   [Read] takes one step and returns a value that is not eternal; [Write]
   takes two to three steps, [Send] four to six. A time grade weighs an
   operation at the end of its bounds the grade's order reads. *)
let declarations ~traces ~upper =
  let op name result lo hi =
    if traces then
      Printf.sprintf "operation %s : unit ~> %s # {%s} within (%d, %d)" name
        result name lo hi
    else
      Printf.sprintf "operation %s : unit ~> %s # %d" name result
        (if upper then hi else lo)
  in
  [
    "noneternal type reading = Reading of nat";
    op "Read" "reading" 1 1;
    op "Write" "unit" 2 3;
    op "Send" "unit" 4 6;
  ]

(* The programs. Top-level definitions are values, so a closed computation
   is written as a function of an argument it ignores. *)
let programs ~lit =
  [
    (* The standard library. The comparison of [min] is passed in. *)
    "let id x = x";
    "let ignore _ = ()";
    "let fst (x, _) = x";
    "let snd (_, y) = y";
    "let not x = if x then false else true";
    "let absurd void = (match void with)";
    "let pipe x f = f x";
    "let compose f g x = f (g x)";
    "let min lt x y = if lt (x, y) then x else y";
    (* Report simplification *)
    "let reused_around_claim a f b = f (); unbox b as g in g a; a";
    "let claimed_after_call f b = f (); (fun m -> handle m () with (handler | \
     r -> () | Read p k -> unbox b as y in let a = perform Read p in unbox k \
     as k' in k' a))";
    (* Annotations *)
    "let id_bool (x : bool) = x";
    "let id_unit = (fun x -> x : unit -> unit)";
    "let compose_g f g x = f ((g : unit -> unit) x)";
    (* Boxes *)
    "let stale_call f = delay 1; f ()";
    Printf.sprintf
      "let boxed_call f = box %s f as g in delay 1; unbox g as g' in g' ()"
      (lit 1);
    "let handed_box_call b = delay 1; unbox b as g in g ()";
    Printf.sprintf "let boxing_an_argument x = box %s x as b in b" (lit 1);
    Printf.sprintf
      "let claim_early u = box %s () as x in delay 2; unbox x as y in y" (lit 3);
    Printf.sprintf
      "let claim_on_time u = box %s () as x in delay 3; unbox x as y in y"
      (lit 3);
    Printf.sprintf
      "let claim_late u = box %s () as x in delay 4; unbox x as y in y" (lit 3);
    "let inferred_grade b = delay 2; unbox b as y in y";
    "let kept_and_claimed b = (b, (fun u -> delay 2; unbox b as y in y))";
    Printf.sprintf
      "let escaping_early u = let mk = fun v -> box %s () as x in x in let r = \
       mk () in delay 1; unbox r as y in y"
      (lit 2);
    Printf.sprintf
      "let escaping_on_time u = let mk = fun v -> box %s () as x in x in let r \
       = mk () in delay 2; unbox r as y in y"
      (lit 2);
    Printf.sprintf
      "let escaping_late u = let mk = fun v -> box %s () as x in x in let r = \
       mk () in delay 4; unbox r as y in y"
      (lit 2);
    "let branches c b = if c then (delay 1; unbox b as y in y) else (delay 3; \
     unbox b as y in y)";
    Printf.sprintf
      "let read_licensed p = box %s () as x in let r = perform Read p in unbox \
       x as y in y"
      (lit 2);
    Printf.sprintf
      "let write_licensed p = box %s () as x in let r = perform Write p in \
       unbox x as y in y"
      (lit 2);
    Printf.sprintf
      "let send_licensed p = box %s () as x in let r = perform Send p in unbox \
       x as y in y"
      (lit 2);
    "let nested b = delay 1; unbox b as c in delay 2; unbox c as z in z";
    Printf.sprintf
      "let nesting u = box %s () as x in box %s x as y in delay 1; unbox y as \
       x' in delay 2; unbox x' as z in z"
      (lit 2) (lit 1);
    Printf.sprintf
      "let claimed_in_clause_unit m = box %s () as x in handle m () with \
       (handler | r -> () | Read p k -> unbox x as y in let a = perform Read p \
       in unbox k as k' in k' a)"
      (lit 0);
    Printf.sprintf
      "let claimed_in_clause_one m = box %s () as x in handle m () with \
       (handler | r -> () | Read p k -> unbox x as y in let a = perform Read p \
       in unbox k as k' in k' a)"
      (lit 1);
    "let handed_to_clause m b = handle m () with (handler | r -> () | Read p k \
     -> unbox b as y in let a = perform Read p in unbox k as k' in k' a)";
    (* Handlers *)
    "let relay m = handle m () with (handler | x -> () | Read p k -> let a = \
     perform Read p in unbox k as k' in let h = fun x -> x in let g = h (fun u \
     -> k' a) in let g' = h g in g' ())";
    "let relay_boxed m = handle m () with (handler | x -> () | Read p k -> let \
     h = fun x -> x in let k1 = h k in let k2 = h k1 in let a = perform Read p \
     in unbox k2 as k' in k' a)";
    "let discard m = handle m () with (handler | x -> () | Read p k -> ())";
    "let resume_twice m = handle m () with (handler | x -> () | Read p k -> \
     let a = perform Read p in unbox k as k' in k' a; k' a)";
  ]

(* ------------------------------------------------------------------ *)
(* Expected schemes                                                    *)
(* ------------------------------------------------------------------ *)

type expected = Typed of canonical | Untypable

let typed ?(atoms = []) ty =
  Typed { ty; atoms = List.sort String.compare atoms }

(* How the expected schemes read at one grade. *)
type grade = {
  least : bool;  (** whether the unit is the least grade *)
  u : string;  (** the unit *)
  top : string;  (** the top *)
  lit : int -> string;  (** [n] time steps *)
  join_1_3 : string;  (** the join of one and three steps *)
  op : string -> int -> int -> string;
      (** the grade of an operation taking the given steps at least and at most
      *)
}

(* The expected outcome of each program. Where the product of effects
   commutes, its factors are listed by the creation of their unknowns, an
   order that is immaterial there. *)
let expected g =
  let u = g.u and lit = g.lit in
  let where_least e = if g.least then e else Untypable
  and where_top e = if g.least then Untypable else e in
  (* A variable used after a call owes a var-rule disjunction, met by the
     grade where the unit is the top. *)
  let after_call atoms = if g.least then atoms else [] in
  [
    ("id", typed "α → α");
    ("ignore", typed "α → unit");
    ("fst", typed "α × β → α");
    ("snd", typed "α × β → β");
    ("not", typed "bool → bool");
    (* An empty match has a scrutinee of type [empty]. *)
    ("absurd", typed "empty → α # ε₀");
    ("pipe", typed "α → ((α → β # ε₀) → β # ε₀)");
    (* [g]'s effect, then [f]'s; [f] is used after [g x] has run, so [g]'s
       effect is bounded by the unit, and is the unit where the unit is
       least. *)
    ( "compose",
      typed
        (if g.least then "(α → β # ε₀) → (γ → α) → (γ → β # ε₀)"
         else "(α → β # ε₀) → (γ → α # ε₁) → (γ → β # ε₁ · ε₀)") );
    ( "min",
      typed
        ~atoms:
          ([ "α <: γ"; "β <: γ" ]
          @ after_call
              [
                Printf.sprintf "Et(α) ∨ ∣ε₀∣ ≾ %s" u;
                Printf.sprintf "Et(β) ∨ ∣ε₀∣ ≾ %s" u;
              ])
        "(α × β → bool # ε₀) → α → (β → γ # ε₀)" );
    (* Of the two disjunctions owed by [a], after [f] and after [f] and [g],
       the second entails the first where the unit is least. *)
    ( "reused_around_claim",
      typed
        ~atoms:(after_call [ Printf.sprintf "Et(α) ∨ ∣ε₀∣ · ∣ε₁∣ ≾ %s" u ])
        "α → (unit → β # ε₀) → ([∣ε₀∣](α → γ # ε₁) → α # ε₀ · ε₁)" );
    (* The box is claimed after [f] and behind the clause's lock: its grade
       [∣ε₀∣ · ⊤] is the top where the unit is least, the top absorbing the
       product, and [∣ε₀∣] where the unit is the top. *)
    ( "claimed_after_call",
      typed
        (Printf.sprintf
           "(unit → α # ε₀) → ([%s]β → ((unit → γ # ε₁) → unit # ε₁) # ε₀)"
           (if g.least then g.top else "∣ε₀∣")) );
    ("id_bool", typed "bool → bool");
    ("id_unit", typed "unit → unit");
    ("compose_g", typed "(unit → α # ε₀) → (unit → unit) → (unit → α # ε₀)");
    ( "stale_call",
      where_top (typed (Printf.sprintf "(unit → α # ε₀) → α # %s · ε₀" (lit 1)))
    );
    ( "boxed_call",
      where_top (typed (Printf.sprintf "(unit → α # ε₀) → α # %s · ε₀" (lit 1)))
    );
    ( "handed_box_call",
      typed (Printf.sprintf "[%s](unit → α # ε₀) → α # %s · ε₀" (lit 1) (lit 1))
    );
    ( "boxing_an_argument",
      typed
        ~atoms:(if g.least then [ "Et(α)" ] else [])
        (Printf.sprintf "α → [%s]α" (lit 1)) );
    (* A lease is claimable up to its grade, a promise from it on. *)
    ("claim_early", where_least (typed (Printf.sprintf "α → unit # %s" (lit 2))));
    ("claim_on_time", typed (Printf.sprintf "α → unit # %s" (lit 3)));
    ("claim_late", where_top (typed (Printf.sprintf "α → unit # %s" (lit 4))));
    ("inferred_grade", typed (Printf.sprintf "[%s]α → α # %s" (lit 2) (lit 2)));
    ( "kept_and_claimed",
      typed (Printf.sprintf "[%s ⊔ ρ₀]α → [ρ₀]α × (β → α # %s)" (lit 2) (lit 2))
    );
    ( "escaping_early",
      where_least (typed (Printf.sprintf "α → unit # %s" (lit 1))) );
    ("escaping_on_time", typed (Printf.sprintf "α → unit # %s" (lit 2)));
    ("escaping_late", where_top (typed (Printf.sprintf "α → unit # %s" (lit 4))));
    ( "branches",
      typed ~atoms:[ "α <: β" ]
        (Printf.sprintf "bool → ([%s]α → β # %s)" g.join_1_3 g.join_1_3) );
    (* A promise of two steps is due after [Write] or [Send], a lease of two
       steps covers [Read] only. *)
    ( "read_licensed",
      where_least (typed (Printf.sprintf "unit → unit # %s" (g.op "Read" 1 1)))
    );
    ( "write_licensed",
      where_top (typed (Printf.sprintf "unit → unit # %s" (g.op "Write" 2 3)))
    );
    ( "send_licensed",
      where_top (typed (Printf.sprintf "unit → unit # %s" (g.op "Send" 4 6))) );
    ( "nested",
      typed (Printf.sprintf "[%s][%s]α → α # %s" (lit 1) (lit 2) (lit 3)) );
    ("nesting", where_top (typed (Printf.sprintf "α → unit # %s" (lit 3))));
    (* A clause sees the context behind the lock of the top. *)
    ("claimed_in_clause_unit", where_top (typed "(unit → α # ε₀) → unit # ε₀"));
    ("claimed_in_clause_one", Untypable);
    ( "handed_to_clause",
      typed (Printf.sprintf "(unit → α # ε₀) → ([%s]β → unit # ε₀)" g.top) );
    ("relay", typed "(unit → α # ε₀) → unit # ε₀");
    ("relay_boxed", typed "(unit → α # ε₀) → unit # ε₀");
    (* Dropping the continuation needs the unit least, resuming it twice the
       unit the top. *)
    ("discard", where_least (typed "(unit → α # ε₀) → unit # ε₀"));
    ("resume_twice", where_top (typed "(unit → α # ε₀) → unit # ε₀"));
  ]

(* ------------------------------------------------------------------ *)
(* Checks                                                              *)
(* ------------------------------------------------------------------ *)

let four_grades =
  [
    "time-lower-bound";
    "time-upper-bound";
    "traces-lower-bound";
    "traces-upper-bound";
  ]

let print_expected ppf = function
  | Untypable -> Format.pp_print_string ppf "untypable"
  | Typed { ty; atoms = [] } -> Format.pp_print_string ppf ty
  | Typed { ty; atoms } ->
      Format.fprintf ppf "%s ⇒ %s" (String.concat " ∧ " atoms) ty

(* Each expected outcome compared with the scheme of its definition. *)
let compare_schemes grades actual expected =
  List.iter
    (fun (name, expected) ->
      let actual =
        match List.assoc_opt name actual with
        | Some (Some scheme) -> Typed scheme
        | Some None | None -> Untypable
      in
      if actual <> expected then
        fail "%s (%s): expected %a, got %a" name grades print_expected expected
          print_expected actual)
    expected

let check grades =
  let (module G) = grade_module grades in
  let module T = Programs (G) in
  let traces = String.starts_with ~prefix:"traces" grades in
  let lit n = if traces then Printf.sprintf "{%d}" n else string_of_int n in
  let g =
    {
      least = G.unit_least;
      u = G.show G.one;
      top = G.show G.top;
      lit;
      join_1_3 = G.show (G.join (G.of_nat 1) (G.of_nat 3));
      op =
        (fun name lo hi ->
          if traces then Printf.sprintf "{%s}" name
          else string_of_int (if G.unit_least then hi else lo));
    }
  in
  let source =
    String.concat "\n" (declarations ~traces ~upper:G.unit_least @ programs ~lit)
  in
  compare_schemes grades (T.schemes source) (expected g)

(* Without fixed unknowns, the result is sent to its lower bound, the
   argument; a fixed argument is kept, the result sent to it; a fixed result
   is kept with its lower bound, the argument quantified. The fixed unknowns
   are printed first, named [α]. *)
let check_fixed () =
  let (module G) = grade_module "time-lower-bound" in
  let module T = Programs (G) in
  List.iter
    (fun ((label, actual), expected) ->
      if actual <> expected then
        fail "fixed %s: expected %s, got %s" label expected actual)
    (List.combine (T.fixed_unknowns ())
       [ "∀ α. α → α"; "α α → α"; "α ∀ β. β <: α ⇒ β → α" ])

(* Recursive definitions that call a boxed function after the recursive
   call. The effects of the calls are bounded below alone and occur in no
   type, so they are sent to their lower bounds and leave no hypothesis. A
   right fold uses the accumulator after the partial application [f x]; the
   var-rule disjunction on the effect of [f x] follows from the ordering that
   bounds the product of the two effects of [f] by the unit, by the step from
   a factor to the product, and is dropped. *)
let recursive_programs =
  [
    "let rec iter_after (g : [top](unit -> unit # 1)) (n : nat) : unit # top = \
     match n with | 0 -> () | m + 1 -> iter_after g m; unbox g as h in h ()";
    "let rec iter_twice (g : [top](unit -> unit # 1)) (n : nat) : unit # top = \
     match n with | 0 -> () | m + 1 -> iter_twice g m; unbox g as h in h (); \
     unbox g as h2 in h2 ()";
    "let rec map_boxed (f : [top](nat -> nat # 1)) (xs : nat list) : nat list \
     # top = match xs with | [] -> [] | x :: rest -> let ys = map_boxed f rest \
     in unbox f as h in let y = h x in y :: ys";
    "let rec fold_after f xs acc = match xs with | [] -> acc | x :: xs -> let \
     acc2 = fold_after f xs acc in f x acc2";
  ]

let check_recursive () =
  let grades = "time-upper-bound" in
  let (module G) = grade_module grades in
  let module T = Programs (G) in
  compare_schemes grades
    (T.schemes (String.concat "\n" recursive_programs))
    [
      ("iter_after", typed "[∞](unit → unit # 1) → (nat → unit # ∞)");
      ("iter_twice", typed "[∞](unit → unit # 1) → (nat → unit # ∞)");
      ("map_boxed", typed "[∞](nat → nat # 1) → (nat list → nat list # ∞)");
      ( "fold_after",
        typed
          ~atoms:[ "γ <: β"; "δ <: β"; "ε₁ · ε₀ ≾ 0" ]
          "(α → (β → γ # ε₀) # ε₁) → α list → δ → β" );
    ]

(* Annotated types, each with its type as printed. The precedences are, by
   decreasing strength, type-constructor application, the box, products and
   arrows; an arrow's effect grade belongs to the innermost arrow, and an
   arrow without one has the unit, which is not printed. A codomain that is a
   function type is parenthesised where either arrow shows its effect. *)
let annotations =
  [
    ("nat -> (nat -> nat # 1) # 2", "nat → (nat → nat # 1) # 2");
    ( "(nat -> nat # 1) -> (nat -> (bool -> nat # 2)) # 3",
      "(nat → nat # 1) → (nat → (bool → nat # 2)) # 3" );
    ("nat -> nat -> nat # 1", "nat → (nat → nat # 1)");
    ("nat -> (nat -> nat) # 1", "nat → (nat → nat) # 1");
    ("(nat -> nat) -> nat -> nat", "(nat → nat) → nat → nat");
    ("[2]nat -> nat", "[2]nat → nat");
    ("[2](nat -> nat)", "[2](nat → nat)");
    ( "nat -> [2](nat -> (nat -> bool # 1)) # 1",
      "nat → [2](nat → (nat → bool # 1)) # 1" );
    ("[2]nat list", "[2]nat list");
    ("([2]nat) list", "([2]nat) list");
    ("[2][3]nat", "[2][3]nat");
    ("[2]nat * bool -> nat", "[2]nat × bool → nat");
    ("[2](nat * bool)", "[2](nat × bool)");
    ("(nat * nat) * nat", "(nat × nat) × nat");
    ("nat * nat -> (nat * nat -> nat # 1)", "nat × nat → (nat × nat → nat # 1)");
  ]

let check_round_trip () =
  let (module G) = grade_module "time-upper-bound" in
  let module T = Programs (G) in
  let name i = Printf.sprintf "annotated_%d" i in
  let actual =
    T.argument_types
      (String.concat "\n"
         (List.mapi
            (fun i (annotation, _) ->
              Printf.sprintf "let %s (g : %s) = g" (name i) annotation)
            annotations))
  in
  List.iteri
    (fun i (annotation, expected) ->
      match List.assoc_opt (name i) actual with
      | Some (Some printed) when printed = expected -> ()
      | Some (Some printed) ->
          fail "annotation %s: expected %s, got %s" annotation expected printed
      | Some None | None -> fail "annotation %s: rejected" annotation)
    annotations

let () =
  List.iter check four_grades;
  check_fixed ();
  check_recursive ();
  check_round_trip ();
  match List.rev !failures with
  | [] -> ()
  | failures ->
      List.iter prerr_endline failures;
      exit 1
