(* A benchmark of the four implementations of the regular trace grade, and of
   the cost-model regular trace grades over each: by automata
   ([RegularTraceGrade], "regex-upper-bound"), by plain derivatives of expressions
   over single letters ([RegularTraceGradePlain], "regex-upper-bound-plain"), by
   derivatives by letters of expressions over letter sets
   ([RegularTraceGradeDerivative.Concrete], "regex-upper-bound-derivatives"), and by
   symbolic derivatives by minterms ([RegularTraceGradeDerivative],
   "regex-upper-bound-symbolic"); the cost-model grades are "regex-cost-upper-bound"
   and the others, with the same suffixes. Consecutive implementations differ
   in one design choice each: the construction (automata or derivatives), the
   representation of letters (single letters or letter sets) and the letters
   derived by (letters or minterms). The workloads are the grade operations on
   families of grades of increasing size, and the typechecking of the programs
   that use the grades, the standard library included.

   Each measurement runs in a fresh child process, so that the tables of the
   derivatives start empty: it prepares its inputs untimed, then times the
   operation once (cold) and then repeatedly (warm, the mean of the repeated
   runs). The table shows the medians over several processes. Run from the root
   of the repository:

     dune exec --profile release bench/regular/bench_regular.exe

   See bench/regular/README.md for a results table and the total run time. *)

module Grade = Grades.Grade

let bounds = { Grade.cost = (fun _ -> (0, 0)); operations = [] }

(** {1 Measurement} *)

let now = Unix.gettimeofday
let processes = 5
let time_limit = 10
let warm_budget = 0.1
let patience = 10.

(* The mean time of [thunk] over repeated runs, until [warm_budget] seconds
   have passed. *)
let mean_time thunk =
  let start = now () in
  let rec go runs =
    thunk ();
    let elapsed = now () -. start in
    if elapsed >= warm_budget then elapsed /. float_of_int runs
    else go (runs + 1)
  in
  go 1

type sample = { cold : float; warm : float option }
type outcome = Sample of sample | Timeout | Failure

let report channel sample =
  match sample.warm with
  | Some warm -> Printf.fprintf channel "%h %h\n" sample.cold warm
  | None -> Printf.fprintf channel "%h\n" sample.cold

let read_sample line =
  match String.split_on_char ' ' line with
  | [ cold ] -> Some { cold = float_of_string cold; warm = None }
  | [ cold; warm ] ->
      Some { cold = float_of_string cold; warm = Some (float_of_string warm) }
  | _ -> None

(* The sample of the thunk [prepare ()] in a child process: timed once, and
   again repeatedly if the first run took less than a second. *)
let measure_in_child output prepare =
  ignore (Unix.alarm time_limit);
  let thunk = prepare () in
  let start = now () in
  thunk ();
  let cold = now () -. start in
  let warm = if cold < 1. then Some (mean_time thunk) else None in
  let channel = Unix.out_channel_of_descr output in
  report channel { cold; warm };
  close_out channel;
  Unix._exit 0

let in_child prepare =
  flush_all ();
  let input, output = Unix.pipe ~cloexec:true () in
  match Unix.fork () with
  | 0 ->
      Unix.close input;
      measure_in_child output prepare
  | pid -> (
      Unix.close output;
      let channel = Unix.in_channel_of_descr input in
      let line = In_channel.input_line channel in
      close_in channel;
      match (snd (Unix.waitpid [] pid), Option.bind line read_sample) with
      | Unix.WEXITED 0, Some sample -> Sample sample
      | Unix.WSIGNALED signal, _ when signal = Sys.sigalrm -> Timeout
      | _ -> Failure)

let median xs =
  let xs = List.sort Float.compare xs in
  List.nth xs (List.length xs / 2)

(* The medians of the samples of [prepare] over [processes] processes, or
   fewer once [patience] seconds have been spent in them; the first timeout or
   failure ends the measurement. *)
let measure prepare =
  let result samples =
    let warms = List.filter_map (fun s -> s.warm) samples in
    Sample
      {
        cold = median (List.map (fun s -> s.cold) samples);
        warm = (match warms with [] -> None | warms -> Some (median warms));
      }
  in
  let rec go samples spent n =
    if n = 0 || spent > patience then result samples
    else
      match in_child prepare with
      | Sample s -> go (s :: samples) (spent +. s.cold) (n - 1)
      | outcome -> outcome
  in
  go [] 0. processes

(** {1 Workloads} *)

type workload = {
  family : string;
  name : string;
  prepare : unit -> unit -> unit;
}

(* The brace literals of examples/regular/regular_traces.tpe and of
   tests/*regular*.tpe. *)
let corpus =
  [
    "{Open}";
    "{Read}";
    "{Write}";
    "{Close}";
    "{Auth}";
    "{Fetch}";
    "{Revoke}";
    "{Send}";
    "{Open; (Read | Write)*; Close}";
    "{Open; Read*; Close}";
    "{(Open; (Read | Write)*; Close | 1)*}";
    "{_*; Auth; _*}";
    "{~{_*; Revoke; _*}}";
    "{~(_*; Revoke; _*)}";
    "{3; _*}";
    "{Read*|Send}";
    "{Read*&~Send}";
    "{~~Read | Read**}";
    "{_&~Read|Read}";
    "{Read; 3; (Send | Write)* & ~{_; Read}}";
    "{(Send; 2)* & ~{_*; Send; Send; _*}}";
    "{Open; (Read | Write)*; Close | Open; Close}";
    "{(1; 1)* | 1; 1; 1}";
    "{Open; Close; Read}";
    "{Open; Read}";
    "{Fetch; 3}";
    "{0}";
    "3";
    "top";
  ]

let session = "Open; (Read | Write)*; Close"
let repeat n text = List.init n (Fun.const text)

(* The protocol [session] nested [d] times in the repetition of itself. *)
let rec nested d =
  if d = 0 then session
  else "Open; (Read | Write | " ^ nested (d - 1) ^ ")*; Close"

(* The words whose [n + 1]-th letter from the end is [a]. *)
let from_end a n = "_*; " ^ a ^ "; " ^ String.concat "; " (repeat n "_")
let names k = List.init k (fun i -> "Op" ^ string_of_int (i + 1))

module Workloads (G : Grade.S) = struct
  module Grammar = Parser.Grammar.Make (Grades.GradeSystem.Identity (G))

  let lit text =
    let lexbuf = Lexing.from_string ("box " ^ text ^ " ()") in
    match Grammar.payload (Parser.Lexer.tokens ()) lexbuf with
    | { it = SugaredAst.GenBox ({ it = SugaredAst.GradeLit rho; _ }, _); _ } ->
        rho
    | _ -> invalid_arg ("not a grade: " ^ text)

  let braces text = lit ("{" ^ text ^ "}")

  (* The workload timing [run] on the inputs [inputs ()], prepared untimed. *)
  let op family name inputs run =
    let prepare () =
      let x = inputs () in
      fun () -> ignore (Sys.opaque_identity (run x))
    in
    { family; name; prepare }

  let pairs xs = List.concat_map (fun x -> List.map (fun y -> (x, y)) xs) xs
  let on_pairs f rhos = List.map (fun (x, y) -> f x y) (pairs rhos)
  let leq = G.leq bounds
  let equal = G.equal bounds
  let power k rho = List.fold_left G.mul rho (repeat (k - 1) rho)

  let powers k rho =
    List.fold_left G.join rho (List.init (k - 1) (fun i -> power (i + 2) rho))

  let corpus_workloads =
    let family =
      "corpus (" ^ string_of_int (List.length corpus) ^ " literals)"
    in
    let grades () = List.map lit corpus in
    [
      op family "elaborate" Fun.id (fun () -> List.map lit corpus);
      op family "mul, all pairs" grades (on_pairs G.mul);
      op family "join, all pairs" grades (on_pairs G.join);
      op family "leq, all pairs" grades (on_pairs leq);
      op family "equal, all pairs" grades (on_pairs equal);
      op family "counterexample, all pairs" grades
        (on_pairs (G.counterexample bounds));
    ]

  (* [P] the session, [P*] its repetition and [J] the join of [P] to [P^k]. *)
  let protocol k =
    let family = Printf.sprintf "protocol P^k, k = %d" k in
    let p () = braces session in
    let star () = (braces session, braces ("(" ^ session ^ ")*")) in
    let prepared () =
      let p, s = star () in
      (power k p, powers k p, G.mul p s, s)
    in
    [
      op family "mul P^k" p (power k);
      op family "join J = P | ... | P^k" p (powers k);
      op family "leq P^k <= P*" prepared (fun (pk, _, _, s) -> leq pk s);
      op family "leq P; P* <= J (false)" prepared (fun (_, j, plus, _) ->
          leq plus j);
      op family "counterexample P; P*, J" prepared (fun (_, j, plus, _) ->
          G.counterexample bounds plus j);
      op family "equal J | P; P* = P; P*" prepared (fun (_, j, plus, _) ->
          equal (G.join j plus) plus);
    ]

  (* [N_d] the session nested [d] times. *)
  let nesting d =
    let family = Printf.sprintf "nested protocol N_d, d = %d" d in
    let both () = (braces (nested d), braces (nested (d + 1))) in
    let with_session () =
      let n = braces (nested d) in
      (n, G.join n (braces session))
    in
    [
      op family "elaborate N_d" Fun.id (fun () -> braces (nested d));
      op family "leq N_d <= N_d+1" both (fun (n, n') -> leq n n');
      op family "counterexample N_d+1, N_d" both (fun (n, n') ->
          G.counterexample bounds n' n);
      op family "equal N_d = N_d | P" with_session (fun (n, n') -> equal n n');
    ]

  (* [F] the words whose [n + 1]-th letter from the end is [A], [E] their
     complement, [E'] the same language written without complement, and [E2]
     the intersection of [E] with its analogue for [B]. *)
  let nth_from_end n =
    let family = Printf.sprintf "n-th letter from the end, n = %d" n in
    let e = "~(" ^ from_end "A" n ^ ")" in
    let e' =
      "_*; (_ & ~A); "
      ^ String.concat "; " (repeat n "_")
      ^ " | "
      ^ String.concat "; " (repeat n "(0 | _)")
    in
    let e2 = e ^ " & ~(" ^ from_end "B" n ^ ")" in
    let bc = "(B | C)*; A; " ^ String.concat "; " (repeat n "(B | C)") in
    let against text () = (braces text, braces e) in
    [
      op family "elaborate E" Fun.id (fun () -> braces e);
      op family "elaborate E2" Fun.id (fun () -> braces e2);
      op family "leq (B | C)* <= E" (against "(B | C)*") (fun (x, e) -> leq x e);
      op family "counterexample (B | C)*; A; (B | C)^n, E" (against bc)
        (fun (x, e) -> G.counterexample bounds x e);
      op family "leq C* <= E2"
        (fun () -> (braces "C*", braces e2))
        (fun (x, e2) -> leq x e2);
      op family "elaborate E', decide E = E'"
        (fun () -> braces e)
        (fun e -> equal e (braces e'));
    ]

  (* [W] any word over [k] names, [X] a word of them between two [Op1]. *)
  let alphabet k =
    let family = Printf.sprintf "alphabet of k = %d names" k in
    let all = "(" ^ String.concat " | " (names k) ^ ")*" in
    let inner = "(" ^ String.concat " | " (List.tl (names k)) ^ ")*" in
    let x = "Op1; " ^ inner ^ "; Op1" in
    let both () = (braces all, braces x) in
    [
      op family "elaborate W, X" Fun.id (fun () -> (braces all, braces x));
      op family "mul X W" both (fun (w, x) -> G.mul x w);
      op family "join X W" both (fun (w, x) -> G.join x w);
      op family "leq X <= W" both (fun (w, x) -> leq x w);
      op family "leq W <= X (false)" both (fun (w, x) -> leq w x);
      op family "counterexample W, X" both (fun (w, x) ->
          G.counterexample bounds w x);
      op family "equal W = W | X"
        (fun () ->
          let w, x = both () in
          (w, G.join w x))
        (fun (w, w') -> equal w w');
    ]

  (* [U] the word of [k] names, each once, and [V] its repetition: every name
     is told apart from the others, so that the minterms are the letters. *)
  let told_apart k =
    let family = Printf.sprintf "k = %d names told apart" k in
    let u = String.concat "; " (names k) in
    let both () = (braces u, braces ("(" ^ u ^ ")*")) in
    [
      op family "elaborate U, V" Fun.id both;
      op family "leq U <= V" both (fun (u, v) -> leq u v);
      op family "leq V <= U (false)" both (fun (u, v) -> leq v u);
      op family "counterexample V, U" both (fun (u, v) ->
          G.counterexample bounds v u);
      op family "equal V = 0 | U; V" both (fun (u, v) ->
          equal v (G.join G.one (G.mul u v)));
    ]

  let operations =
    corpus_workloads
    @ List.concat_map protocol [ 2; 8; 32 ]
    @ List.concat_map nesting [ 1; 3; 6 ]
    @ List.concat_map nth_from_end [ 4; 8; 12; 16 ]
    @ List.concat_map alphabet [ 8; 32; 128 ]
    @ List.concat_map told_apart [ 8; 32; 128 ]
end

(* The programs typechecked under the regular trace grade: the example and
   the tests of the grade. *)
let regular_programs =
  [
    "examples/regular/regular_traces.tpe";
    "tests/literals_regular.tpe";
    "tests/regular_auth.tpe";
    "tests/regular_protocol.tpe";
    "tests/regular_reject_auth.tpe";
    "tests/regular_reject_bounds.tpe";
    "tests/regular_reject_counterexample.tpe";
    "tests/regular_reject_protocol.tpe";
  ]

module Programs (G : Grade.S) = struct
  module Backend = CliInterpreter.Make (Grades.GradeSystem.Identity (G))
  module L = Loader.Loader (Backend)

  (* The standard library loaded, then the program [file], if any, with the
     diagnostics of its rejection collected. *)
  let typecheck file () =
    let stdlib =
      L.parse_source ~filename:Loader.stdlib_filename L.stdlib_source
    in
    let program = Option.map L.parse_file file in
    let state = L.declare (stdlib :: Option.to_list program) L.initial_state in
    let state = L.load_commands state stdlib in
    Option.iter
      (fun program -> ignore (L.load_commands_all state program))
      program

  let workload file =
    let name = Option.value file ~default:"standard library alone" in
    {
      family = "typechecking, " ^ G.name;
      name;
      prepare = (fun () -> typecheck file);
    }

  (* The standard library alone, then with each of [programs]. *)
  let workloads programs =
    workload None :: List.map (fun f -> workload (Some f)) programs
end

(** {1 Cost-model workloads} *)

(* The cost model declaring [operations], whose runtime bounds are [(1, 2)],
   [(2, 3)] or [(3, 4)] by the length of their names. *)
let cost_model operations =
  let cost name =
    let lo = 1 + (String.length name mod 3) in
    (lo, lo + 1)
  in
  { Grade.cost; operations }

let corpus_names =
  [ "Open"; "Read"; "Write"; "Close"; "Auth"; "Fetch"; "Revoke"; "Send" ]

(* The operations named by [cost_corpus], the runtime-bound declarations of
   examples/regular_costs/*.tpe and tests/regex_costs_*.tpe. *)
let cost_corpus_names =
  [
    "Coat";
    "Bake";
    "Inspect";
    "Seal";
    "Sample";
    "Send";
    "Calibrate";
    "Ping";
    "Log";
    "Fetch";
  ]

(* The one-sided box grades of examples/regular_costs/*.tpe and of
   tests/regex_costs_*.tpe, understood by every cost-model grade. *)
let cost_corpus =
  [
    "{Coat; 4}";
    "{Bake | 6}";
    "{(Bake; Inspect)*}";
    "{Ping; 3}";
    "{Ping | Log}";
    "{2; Send; 6}";
    "{Sample*; Send}";
    "{(Sample | 2)*}";
    "{(_ & ~Calibrate)*}";
    "{_ & ~Calibrate}";
    "{Log; 2*}";
    "{(_ & ~Fetch)*}";
    "{(Ping | Log)*}";
    "{6}";
    "top";
  ]

(* The two-sided box grades of examples/regular_costs/regular_costs_intervals.tpe
   and tests/regex_costs_interval*.tpe, understood only by the interval grade.
*)
let interval_cost_corpus =
  [
    "(4, 8)";
    "({Bake}, {Bake; (Inspect | 1)*})";
    "({Coat; 4; Seal}, {Coat; 8; Seal})";
    "({Ping}, {(Ping | 1)*})";
    "({Fetch}, {_ & ~1 & ~Fetch})";
  ]

(* Whether [name] contains [infix], to tell the interval grade, whose name
   contains "interval", from the lower and upper bounds. *)
let has_infix infix name =
  let n = String.length infix and m = String.length name in
  let rec go i = i + n <= m && (String.sub name i n = infix || go (i + 1)) in
  go 0

module CostWorkloads (G : Grade.S) = struct
  include Workloads (G)

  let costs =
    let corpus =
      if has_infix "interval" G.name then cost_corpus @ interval_cost_corpus
      else cost_corpus
    in
    let bounds = cost_model cost_corpus_names in
    let family =
      Printf.sprintf "%s: cost corpus (%d literals)" G.name (List.length corpus)
    in
    let grades () = List.map lit corpus in
    let on_pairs f rhos = List.map (fun (x, y) -> f bounds x y) (pairs rhos) in
    [
      op family "elaborate" Fun.id (fun () -> List.map lit corpus);
      op family "leq, all pairs" grades (on_pairs G.leq);
      op family "equal, all pairs" grades (on_pairs G.equal);
      op family "counterexample, all pairs" grades (on_pairs G.counterexample);
    ]

  (* [T] a delay of [n] ticks, [S] the runs of reads and writes each paced by
     two ticks, and [R] a delay of [n] ticks between a read and a write. *)
  let delays n =
    let bounds = cost_model corpus_names in
    let family = Printf.sprintf "%s: delays, n = %d" G.name n in
    let t = string_of_int n in
    let grades () =
      ( braces t,
        braces "(Read; 2 | Write; 2)*",
        braces ("Read; " ^ t ^ "; Write") )
    in
    [
      op family "leq T <= S" grades (fun (t, s, _) -> G.leq bounds t s);
      op family "leq S <= T (false)" grades (fun (t, s, _) -> G.leq bounds s t);
      op family "counterexample S, T" grades (fun (t, s, _) ->
          G.counterexample bounds s t);
      op family "leq R <= T" grades (fun (t, _, r) -> G.leq bounds r t);
      op family "equal T = T | R" grades (fun (t, _, r) ->
          G.equal bounds t (G.join t r));
    ]

  (* [W] any word over [k] declared names, [X] a word of them between two
     [Op1], and [Y] any two letters. *)
  let declared k =
    let bounds = cost_model (names k) in
    let family = Printf.sprintf "%s: %d declared names" G.name k in
    let all = "(" ^ String.concat " | " (names k) ^ ")*" in
    let inner = "(" ^ String.concat " | " (List.tl (names k)) ^ ")*" in
    let grades () =
      (braces all, braces ("Op1; " ^ inner ^ "; Op1"), (braces "_; _", lit "8"))
    in
    [
      op family "leq X <= W" grades (fun (w, x, _) -> G.leq bounds x w);
      op family "leq W <= X (false)" grades (fun (w, x, _) -> G.leq bounds w x);
      op family "counterexample W, X" grades (fun (w, x, _) ->
          G.counterexample bounds w x);
      op family "leq Y <= {8}" grades (fun (_, _, (y, eight)) ->
          G.leq bounds y eight);
      op family "inhabited X" grades (fun (_, x, _) -> G.inhabited bounds x);
    ]

  (* [E] the complement of "the [n]-th letter from the end is [A]" and [E2]
     its intersection with the analogous complement for [B], over a cost
     model declaring [A], [B] and [C]; scales the corpus's complement and
     intersection literals as [nth_from_end] does for the plain grade. *)
  let nth_from_end n =
    let bounds = cost_model [ "A"; "B"; "C" ] in
    let family =
      Printf.sprintf "%s: n-th letter from the end, n = %d" G.name n
    in
    let e = "~(" ^ from_end "A" n ^ ")" in
    let e2 = e ^ " & ~(" ^ from_end "B" n ^ ")" in
    let bc = "(B | C)*; A; " ^ String.concat "; " (repeat n "(B | C)") in
    let against text () = (braces text, braces e) in
    [
      op family "elaborate E, E2" Fun.id (fun () -> (braces e, braces e2));
      op family "leq (B | C)* <= E" (against "(B | C)*") (fun (x, e) ->
          G.leq bounds x e);
      op family "counterexample (B | C)*; A; (B | C)^n, E" (against bc)
        (fun (x, e) -> G.counterexample bounds x e);
      op family "leq C* <= E2"
        (fun () -> (braces "C*", braces e2))
        (fun (x, e2) -> G.leq bounds x e2);
    ]

  (* [n] stops at 8: automata already take seconds to elaborate [E2] there,
     and 12 pushes the interval grade's symbolic derivatives past 20 s. The
     delays of 1024 ticks exercise the runs of ticks as counters, and the 512
     declared names, of three costs, the classes of names of equal cost. *)
  let operations =
    costs
    @ List.concat_map delays [ 8; 32; 128; 1024 ]
    @ List.concat_map declared [ 8; 32; 128; 512 ]
    @ List.concat_map nth_from_end [ 4; 8 ]
end

(* The programs typechecked under the cost-model regular trace grades: the
   example, and the tests of each grade. *)
let cost_programs grade =
  List.filter Sys.file_exists
    (List.map
       (fun name -> "tests/regex_costs_" ^ grade ^ name ^ ".tpe")
       [ ""; "_reject"; "_runs"; "_runs_reject" ])

module Cost = Grades.RegularCostTraceGrades

(* The programs typechecked under the cost-model grade [grade], the example
   first. *)
let cost_files example grade =
  ("examples/regular_costs/regular_costs_" ^ example ^ ".tpe")
  :: cost_programs grade

(** The workloads of one implementation, over its grades [G], [Upper], [Lower]
    and [Interval], by family, in the order of the table. *)
module Implementation
    (G : Grade.S)
    (Upper : Grade.S)
    (Lower : Grade.S)
    (Interval : Grade.S) =
struct
  module Plain = Programs (G)
  module Ops = Workloads (G)
  module UpperPrograms = Programs (Upper)
  module LowerPrograms = Programs (Lower)
  module IntervalPrograms = Programs (Interval)
  module UpperOps = CostWorkloads (Upper)
  module LowerOps = CostWorkloads (Lower)
  module IntervalOps = CostWorkloads (Interval)

  let workloads =
    [
      Plain.workloads regular_programs;
      Ops.operations;
      UpperPrograms.workloads (cost_files "upper" "upper");
      LowerPrograms.workloads (cost_files "lower" "lower");
      IntervalPrograms.workloads (cost_files "intervals" "interval");
      UpperOps.operations;
      LowerOps.operations;
      IntervalOps.operations;
    ]
end

module Automata =
  Implementation (Grades.RegularTraceGrade) (Cost.Upper) (Cost.Lower)
    (Cost.Interval)

module Plain =
  Implementation (Grades.RegularTraceGradePlain) (Cost.Plain.Upper)
    (Cost.Plain.Lower)
    (Cost.Plain.Interval)

module Letters =
  Implementation
    (Grades.RegularTraceGradeDerivative.Concrete)
    (Cost.Concrete.Upper)
    (Cost.Concrete.Lower)
    (Cost.Concrete.Interval)

module Symbolic =
  Implementation (Grades.RegularTraceGradeDerivative) (Cost.Symbolic.Upper)
    (Cost.Symbolic.Lower)
    (Cost.Symbolic.Interval)

(** {1 The table} *)

let show_time seconds =
  if seconds < 1e-3 then Printf.sprintf "%.1f us" (seconds *. 1e6)
  else if seconds < 1. then Printf.sprintf "%.2f ms" (seconds *. 1e3)
  else Printf.sprintf "%.2f s" seconds

let show_cold = function
  | Sample s -> show_time s.cold
  | Timeout -> Printf.sprintf "> %d s" time_limit
  | Failure -> "failed"

let show_warm = function
  | Sample { warm = Some warm; _ } -> show_time warm
  | Sample { warm = None; _ } -> "-"
  | Timeout | Failure -> ""

(* The ratio of the cold times of [x] and [y], bounded if one of them timed
   out, and none if [y] took no measurable time. *)
let show_ratio x y =
  match (x, y) with
  | Sample x, Sample y when y.cold > 0. ->
      Printf.sprintf "%.2f" (x.cold /. y.cold)
  | Timeout, Sample y ->
      Printf.sprintf "> %.0f" (float_of_int time_limit /. y.cold)
  | Sample x, Timeout ->
      Printf.sprintf "< %.2g" (x.cold /. float_of_int time_limit)
  | _ -> ""

let columns =
  [
    "automata";
    "plain";
    "letters";
    "symbolic";
    "aut/plain";
    "plain/let";
    "let/symb";
    "aut. warm";
    "pl. warm";
    "let. warm";
    "sym. warm";
  ]

(* The text [s] as a Markdown table cell, its column separators escaped. *)
let cell s = String.concat "\\|" (String.split_on_char '|' s)

let print_row name cells =
  Printf.printf "| %-40s |%s\n%!" (cell name)
    (String.concat "" (List.map (Printf.sprintf " %10s |") cells))

(* The row of the workload [a] and its counterparts [p], [l] and [s] in the
   other implementations, in the order of [columns]. *)
let row (a : workload) p l s =
  let a' = measure a.prepare in
  let p' = measure p.prepare in
  let l' = measure l.prepare in
  let s' = measure s.prepare in
  let outcomes = [ a'; p'; l'; s' ] in
  print_row a.name
    (List.map show_cold outcomes
    @ [ show_ratio a' p'; show_ratio p' l'; show_ratio l' s' ]
    @ List.map show_warm outcomes)

(* The rows of the workloads of a family of each implementation, under the
   headings of their families. *)
let rec family_rows current = function
  | [], [], [], [] -> ()
  | (a : workload) :: a', p :: p', l :: l', s :: s' ->
      if a.family <> current then
        print_row ("**" ^ a.family ^ "**") (List.map (Fun.const "") columns);
      row a p l s;
      family_rows a.family (a', p', l', s')
  | _ -> invalid_arg "the workloads differ"

let rec tables = function
  | [], [], [], [] -> ()
  | a :: a', p :: p', l :: l', s :: s' ->
      family_rows "" (a, p, l, s);
      tables (a', p', l', s')
  | _ -> invalid_arg "the families differ"

let () =
  (match Sys.argv with [| _; root |] -> Sys.chdir root | _ -> ());
  Printf.printf
    "Median over %d processes (fewer past %.0f s); cold: first run in a fresh \
     process, warm: mean of repeated runs; ratios of the cold times: automata \
     / plain (construction), plain / letters (representation), letters / \
     symbolic (minterms).\n\n"
    processes patience;
  print_row "workload" columns;
  Printf.printf "|%s|%s\n" (String.make 42 '-')
    (String.concat "" (List.map (Fun.const "------------|") columns));
  tables
    (Automata.workloads, Plain.workloads, Letters.workloads, Symbolic.workloads)
