(* A benchmark of the regular grades: the regular trace languages, the regex
   grades with banked delays and the timed regex grades. The grade operations
   are timed on families of grades of increasing size and on corpora of the
   literals of the examples and tests, and the typechecking on the examples and
   tests whose headers name the grade, the standard library included.

   The tables fall into three sections.
   - Whole time steps, four implementations of the regular trace languages and
     of the regex grades with banked delays over them, by the suffixes of their
     names: automata ("-letter-automata"), plain derivatives
     ("-letter-derivatives"), letters ("-symbolic-by-letters") and symbolic
     ("-symbolic"). The ratio automata / plain sets minimal automata over
     single letters, decided by a breadth-first search of a product, against
     expressions over single letters, decided by a depth-first search of
     their derivatives; plain / letters sets single letters against letter
     sets, the decision procedures being the same; letters / symbolic sets
     derivatives by single letters, depth-first with breadth-first
     counterexamples, against gap derivatives by minterms, with Dijkstra
     counterexamples and equality by bisimulation, and, for the grades with
     banked delays, a closure stepped alongside a depth-first search against
     a closure reader within a breadth-first one.
   - Rational delays, two implementations of the same grades: automata
     ("-rational-automata"), minimal symbolic automata over letter and delay
     sets decided by a product, and symbolic ("-rational-symbolic"), symbolic
     expressions decided by gap derivatives; the ratio sets the two
     representations and their decision procedures against each other.
   - The timed regex grades, of one implementation: whole time steps, rational
     lengths, and the finite timed regex grades on the literals of the
     case-study corpus they read, as a parity check.

   The typechecking of the timed regex grades, whose programs need the
   packages of the Arduino backend, is timed by bench/typecheck.

   Each measurement runs in a fresh child process, so that the tables of the
   grades start empty: it prepares its inputs untimed and times the operation
   once (cold); a typechecking is then timed repeatedly (warm, the mean of the
   repeated runs). The tables show the medians over several processes. Run from
   the root of the repository:

     dune exec --profile release bench/regular/bench_regular.exe

   With [--quick], each family is timed at its least size only. See
   bench/regular/README.md for the results and the total run time. *)

module Grade = Grades.Grade
module Q = Grades.Rational

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

(* The sample of the thunk [prepare ()] in a child process: timed once, and,
   if [warm], again repeatedly if the first run took less than a second. *)
let measure_in_child ~warm output prepare =
  ignore (Unix.alarm time_limit);
  let thunk = prepare () in
  let start = now () in
  thunk ();
  let cold = now () -. start in
  let warm = if warm && cold < 1. then Some (mean_time thunk) else None in
  let channel = Unix.out_channel_of_descr output in
  report channel { cold; warm };
  close_out channel;
  Unix._exit 0

let in_child ~warm prepare =
  flush_all ();
  let input, output = Unix.pipe ~cloexec:true () in
  match Unix.fork () with
  | 0 ->
      Unix.close input;
      measure_in_child ~warm output prepare
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

(* The medians of the samples of [prepare] over [processes] processes, each
   stopped after [time_limit] seconds, or fewer once [patience] seconds have
   been spent in them; the first timeout or failure ends the measurement. *)
let measure ~warm prepare =
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
      match in_child ~warm prepare with
      | Sample s -> go (s :: samples) (spent +. s.cold) (n - 1)
      | outcome -> outcome
  in
  go [] 0. processes

(* [isolated f] is [f ()], computed in a child process and passed back
   marshalled, so that the tables of the grades of this process stay empty. *)
let isolated f =
  flush_all ();
  let input, output = Unix.pipe ~cloexec:true () in
  match Unix.fork () with
  | 0 ->
      Unix.close input;
      let channel = Unix.out_channel_of_descr output in
      Marshal.to_channel channel (f ()) [];
      close_out channel;
      Unix._exit 0
  | pid ->
      Unix.close output;
      let channel = Unix.in_channel_of_descr input in
      let result = Marshal.from_channel channel in
      close_in channel;
      ignore (Unix.waitpid [] pid);
      result

(** {1 Running times} *)

let no_bounds =
  {
    Grade.running_time = (fun _ -> (Closed Q.zero, Closed Q.zero));
    operations = [];
  }

(* The running times [table] of the operations it names, in order. *)
let bounds_of table =
  let index = Hashtbl.of_seq (List.to_seq table) in
  { Grade.running_time = Hashtbl.find index; operations = List.map fst table }

(* The running times of the operations [names], the [i]-th of them taking the
   [(i mod k)]-th of the [k] running-time bounds [ends]. *)
let model ends names =
  let k = List.length ends in
  bounds_of (List.mapi (fun i n -> (n, List.nth ends (i mod k))) names)

let q = Q.of_int

let whole_ends =
  Grade.
    [
      (Open (q 0), Closed (q 2));
      (Closed (q 2), Closed (q 3));
      (Open (q 2), Closed (q 4));
    ]

let rational_ends =
  Grade.
    [
      (Open (q 0), Closed (Q.make 1 2));
      (Closed (Q.make 1 2), Open (Q.make 3 2));
      (Open (q 1), Closed (Q.make 5 2));
    ]

(* The grade named [name] of the registry, hidden implementations included. *)
let grade name = TestPrograms.grade_module name

(* The operations the file [path] declares with running-time bounds, and those
   of the packages of the Arduino backend its header names, at the bounds of
   the board it names, read under the grades of its header. *)
let declared_running_times path =
  let grades = TestSupport.Header.grades path in
  let module G = (val grade grades) in
  let module L =
    Loader.Loader (CliInterpreter.Make (Grades.GradeSystem.Identity (G))) in
  let sources =
    List.map
      (fun (filename, text, running_times) ->
        L.parse_source ~filename ~running_times text)
      (TestPrograms.packages ~grades path)
    @ [ L.parse_file path ]
  in
  List.concat_map Loader.declared_operations sources
  |> List.filter_map (fun (n, b) -> Option.map (fun b -> (n, b)) b)

(* The running times of the operations declared by [files], each operation at
   the bounds of the first file that declares it. *)
let file_bounds files =
  let first acc (n, b) = if List.mem_assoc n acc then acc else (n, b) :: acc in
  bounds_of
    (isolated (fun () ->
         List.rev
           (List.fold_left first []
              (List.concat_map declared_running_times files))))

(** {1 Workloads} *)

type workload = {
  family : string;
  name : string;
  prepare : unit -> unit -> unit;
}

let quick = Array.mem "--quick" Sys.argv

(* The sizes [ns] of a family, only the least under [--quick]. *)
let sizes = function n :: _ when quick -> [ n ] | ns -> ns
let repeat n text = List.init n (Fun.const text)
let names k = List.init k (fun i -> "Op" ^ string_of_int (i + 1))
let union texts = "(" ^ String.concat " | " texts ^ ")"

(* The words whose [n + 1]-th letter from the end is [a]. *)
let from_end a n = "_*; " ^ a ^ "; " ^ String.concat "; " (repeat n "_")

module Literals (G : Grade.S) = struct
  module Grammar = Parser.Grammar.Make (Grades.GradeSystem.Identity (G))

  let lit text =
    let lexbuf = Lexing.from_string ("box " ^ text ^ " ()") in
    match Grammar.payload (Parser.Lexer.tokens ()) lexbuf with
    | { it = SugaredAst.GenBox ({ it = SugaredAst.GradeLit rho; _ }, _); _ } ->
        rho
    | _ -> invalid_arg ("not a grade: " ^ text)

  let braces text = lit ("{" ^ text ^ "}")

  let reads text =
    match lit text with _ -> true | exception Utils.Error.Error _ -> false
end

(* The literals of [texts] that the grade named [name] reads. *)
let readable name texts =
  isolated (fun () ->
      let module G = (val grade name) in
      let module L = Literals (G) in
      List.filter L.reads texts)

module Operations (G : Grade.S) = struct
  include Literals (G)

  (* The workload timing [run] on the inputs [inputs ()], prepared untimed. *)
  let op family name inputs run =
    let prepare () =
      let x = inputs () in
      fun () -> ignore (Sys.opaque_identity (run x))
    in
    { family; name; prepare }

  let pairwise f rhos = List.concat_map (fun x -> List.map (f x) rhos) rhos
  let power k rho = List.fold_left G.mul rho (repeat (k - 1) rho)

  (* The rows of a corpus [texts]: its elaboration, then each of [rows] on the
     grades of the corpus. *)
  let corpus family texts rows =
    let family = Printf.sprintf "%s (%d literals)" family (List.length texts) in
    let grades () = List.map lit texts in
    op family "elaborate" Fun.id (fun () -> List.map lit texts)
    :: List.map (fun (name, run) -> op family name grades run) rows

  let order_rows bounds =
    [
      ("leq, all pairs", fun gs -> ignore (pairwise (G.leq bounds) gs));
      ("equal, all pairs", fun gs -> ignore (pairwise (G.equal bounds) gs));
      ( "counterexample, all pairs",
        fun gs -> ignore (pairwise (G.counterexample bounds) gs) );
    ]

  let inhabited_row bounds =
    ("inhabited, each", fun gs -> ignore (List.map (G.inhabited bounds) gs))

  let show_row = ("show, each", fun gs -> ignore (List.map G.show gs))
end

(** {2 Regular trace languages} *)

(* The brace literals of the files whose headers name the regular trace
   languages, examples/regular_trace_languages/upper_bounds.tpe and
   tests/*regular*.tpe, those of their diagnostics included. *)
let regular_corpus =
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
    "{Auth; _*}";
    "{(_ & ~Revoke)*}";
    "{~(_ & ~Auth)*}";
    "{Open; Read; (skip | Write); Close}";
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
    "{Read; [1, 3]; Send}";
    "{Read; (1, 4); Send}";
    "{Read; [2, ∞)}";
    "{(1 | 2); (0, 2]}";
    "{skip}";
    "{Read | skip}";
    "{Read?; skip}";
    "{Read*}";
    "{1 | Read; Read*}";
    "3";
    "top";
  ]

let session = "Open; (Read | Write)*; Close"

(* The protocol [session] nested [d] times in the repetition of itself. *)
let rec nested d =
  if d = 0 then session
  else "Open; (Read | Write | " ^ nested (d - 1) ^ ")*; Close"

module Regular (G : Grade.S) = struct
  include Operations (G)

  let leq = G.leq no_bounds
  let equal = G.equal no_bounds
  let counterexample = G.counterexample no_bounds

  let powers k rho =
    List.fold_left G.join rho (List.init (k - 1) (fun i -> power (i + 2) rho))

  let corpus_rows =
    corpus "corpus" regular_corpus
      ([
         ("mul, all pairs", fun gs -> ignore (pairwise G.mul gs));
         ("join, all pairs", fun gs -> ignore (pairwise G.join gs));
       ]
      @ order_rows no_bounds @ [ show_row ])

  (* [P] the session, [P*] its repetition and [J] the join of [P] to [P^k]. *)
  let protocol k =
    let family = Printf.sprintf "protocol P^k, k = %d" k in
    let p () = braces session in
    let prepared () =
      let p = braces session and s = braces ("(" ^ session ^ ")*") in
      (power k p, powers k p, G.mul p s, s)
    in
    [
      op family "mul P^k" p (power k);
      op family "join J = P | ... | P^k" p (powers k);
      op family "leq P^k <= P*" prepared (fun (pk, _, _, s) -> leq pk s);
      op family "leq P; P* <= J (false)" prepared (fun (_, j, plus, _) ->
          leq plus j);
      op family "counterexample P; P*, J" prepared (fun (_, j, plus, _) ->
          counterexample plus j);
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
          counterexample n' n);
      op family "equal N_d = N_d | P" with_session (fun (n, n') -> equal n n');
    ]

  (* [E] the words whose [n + 1]-th letter from the end is not [A], [E'] the
     same language written without complement, and [E2] the intersection of
     [E] with its analogue for [B]. *)
  let nth_from_end n =
    let family = Printf.sprintf "n-th letter from the end, n = %d" n in
    let e = "~(" ^ from_end "A" n ^ ")" in
    let e' =
      "_*; (_ & ~A); "
      ^ String.concat "; " (repeat n "_")
      ^ " | "
      ^ String.concat "; " (repeat n "(skip | _)")
    in
    let e2 = e ^ " & ~(" ^ from_end "B" n ^ ")" in
    let bc = "(B | C)*; A; " ^ String.concat "; " (repeat n "(B | C)") in
    let against text () = (braces text, braces e) in
    [
      op family "elaborate E" Fun.id (fun () -> braces e);
      op family "elaborate E2" Fun.id (fun () -> braces e2);
      op family "leq (B | C)* <= E" (against "(B | C)*") (fun (x, e) -> leq x e);
      op family "counterexample (B | C)*; A; (B | C)^n, E" (against bc)
        (fun (x, e) -> counterexample x e);
      op family "leq C* <= E2"
        (fun () -> (braces "C*", braces e2))
        (fun (x, e2) -> leq x e2);
      op family "elaborate E', decide E = E'"
        (fun () -> braces e)
        (fun e -> equal e (braces e'));
    ]
    @
    if n = 8 || n = 12 then [ op family "show E2" (fun () -> braces e2) G.show ]
    else []

  (* [W] any word over [k] names, [X] a word of them between two [Op1]. *)
  let alphabet k =
    let family = Printf.sprintf "alphabet of k = %d names" k in
    let all = union (names k) ^ "*" in
    let x = "Op1; " ^ union (List.tl (names k)) ^ "*; Op1" in
    let both () = (braces all, braces x) in
    [
      op family "elaborate W, X" Fun.id both;
      op family "mul X W" both (fun (w, x) -> G.mul x w);
      op family "join X W" both (fun (w, x) -> G.join x w);
      op family "leq X <= W" both (fun (w, x) -> leq x w);
      op family "leq W <= X (false)" both (fun (w, x) -> leq w x);
      op family "counterexample W, X" both (fun (w, x) -> counterexample w x);
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
      op family "counterexample V, U" both (fun (u, v) -> counterexample v u);
      op family "equal V = skip | U; V" both (fun (u, v) ->
          equal v (G.join G.one (G.mul u v)));
    ]

  (* [G] the repetitions of the delays [a] and [b], [H] the same language
     written as [a*; b*], and [G'] the repetitions of [a] and [b + 1], whose
     least delay that [G] lacks is [b + 1]: long sums of whole delays. *)
  let gaps (a, b) =
    let family = Printf.sprintf "gaps, (a | b)*, a = %d, b = %d" a b in
    let g = Printf.sprintf "(%d | %d)*" a b
    and h = Printf.sprintf "%d*; %d*" a b
    and g' = Printf.sprintf "(%d | %d)*" a (b + 1) in
    let grades () = (braces g, braces h, braces g') in
    [
      op family "elaborate G" Fun.id (fun () -> braces g);
      op family "leq a*; b* <= G" grades (fun (g, h, _) -> leq h g);
      op family "equal G = a*; b*" grades (fun (g, h, _) -> equal g h);
      op family "leq (a | b + 1)* <= G (false)" grades (fun (g, _, g') ->
          leq g' g);
      op family "counterexample (a | b + 1)*, G" grades (fun (g, _, g') ->
          counterexample g' g);
    ]

  let operations =
    corpus_rows
    @ List.concat_map protocol (sizes [ 8; 32 ])
    @ List.concat_map nesting (sizes [ 3; 6 ])
    @ List.concat_map nth_from_end (sizes [ 4; 8; 12; 16 ])
    @ List.concat_map alphabet (sizes [ 8; 32; 128 ])
    @ List.concat_map told_apart (sizes [ 32; 128 ])
    @ List.concat_map gaps (sizes [ (100, 101); (1000, 1001); (97, 89) ])
end

(** {2 Regex grades with banked delays} *)

(* The files of the one-sided and of the interval literals of the banked
   corpora below, whose declarations give the running times. *)
let banked_files =
  [
    "examples/banked_regex/lower_bounds.tpe";
    "examples/banked_regex/upper_bounds.tpe";
    "examples/banked_regex/intervals.tpe";
    "examples/banked_regex/mail_session.tpe";
    "tests/banked_regex_upper.tpe";
    "tests/banked_regex_upper_open.tpe";
    "tests/banked_regex_upper_ticks.tpe";
    "tests/banked_regex_lower.tpe";
    "tests/banked_regex_lower_ticks_reject.tpe";
    "tests/banked_regex_interval.tpe";
    "tests/banked_regex_interval_no_common_run_reject.tpe";
  ]

(* The one-sided literals of [banked_files], read by every regex grade with
   banked delays over whole time steps. *)
let banked_corpus =
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
    "{_ & ~1 & ~Sample & ~Send & ~Calibrate}";
    "{Log; 2*}";
    "{(_ & ~Fetch)*}";
    "{_ & ~1 & ~Fetch}";
    "{(Ping | Log)*}";
    "{1*; Ping}";
    "{Ping; (_ & ~1 & ~Ping)}";
    "{Login; (Fetch | Store)*; Logout}";
    "{(Fetch; Store)*}";
    "{Fetch*; Store*}";
    "{3}";
    "{6}";
    "{20}";
    "top";
  ]

(* The interval literals of [banked_files], the last three of which admit no
   run. *)
let banked_interval_corpus =
  [
    "[2, 4]";
    "[3, 4]";
    "[4, 8]";
    "[{Bake}, {Bake; (Inspect | 1)*}]";
    "[{Bake}, {Bake; Inspect*}]";
    "[{Coat; 4; Seal}, {Coat; 8; Seal}]";
    "[{Ping}, {(Ping | 1)*}]";
    "[{Fetch}, {_ & ~1 & ~Fetch}]";
    "[{Fetch}, {Store*}]";
    "[{4; Fetch*}, {Store; 1}]";
  ]

(* The files of the rational banked corpora below. *)
let banked_rational_files =
  [
    "examples/banked_regex/upper_bounds_rational.tpe";
    "examples/banked_regex/intervals_rational.tpe";
    "tests/banked_regex_rational_upper.tpe";
    "tests/banked_regex_rational_upper_open.tpe";
    "tests/banked_regex_rational_lower.tpe";
    "tests/banked_regex_rational_interval.tpe";
    "tests/banked_regex_rational_interval_no_common_run_reject.tpe";
    "tests/banked_regex_rational_interval_reject.tpe";
  ]

(* The one-sided literals of [banked_rational_files]. *)
let banked_rational_corpus =
  [
    "{Sample}";
    "{Sample; 1/2}";
    "{Sample; [1/2, ∞)}";
    "{(Sample; [0, 1/3])*}";
    "{(Sample; 1/3)*}";
    "{[0, 3/2]; Send; 11/2}";
    "{[0, 1); Send; [0, 1/4]}";
    "{[0, ∞); Send}";
    "{Send; [0, 2)}";
    "{Send; ([0, 1] & ~1)}";
    "{(_ & ~Calibrate)*}";
    "{(_ & ~Sample)*}";
    "{~1}";
    "{~[0, 1/2) & [0, 1]}";
    "{[0, 1/2)}";
    "{[0, 5/2)}";
    "{(1/4, ∞)}";
    "{1/4}";
    "{3/4}";
    "{2}";
    "{11/4}";
    "{11/2}";
    "top";
  ]

(* The interval literals of [banked_rational_files], the last two of which
   admit no run. *)
let banked_rational_interval_corpus =
  [
    "[1/2, 3/2]";
    "[3/4, 2]";
    "[{1}, {~1}]";
    "[{Send}, {(Send | [0, 1/4])*}]";
    "[{Sample}, {(Sample; [0, 1/3])*}]";
    "[{Sample; 1/5}, {Sample; (0, 1/4]; Compress}]";
    "[{(2, 3)}, {[0, 2]}]";
    "[{5/2}, {Sample; 1/2}]";
  ]

(* The workloads of a regex grade with banked delays [G], over the running
   times [ends] of the synthetic families, the one-sided [corpus] and, for an
   interval grade, [intervals], with the running times of [files]. *)
module Banked
    (G : Grade.S)
    (C : sig
      val ends : Grade.running_time list
      val files : string list
      val corpus : string list
      val intervals : string list
      val interval : bool
    end) =
struct
  include Operations (G)

  let corpus_rows () =
    let bounds = file_bounds C.files in
    corpus "corpus"
      (if C.interval then C.corpus @ C.intervals else C.corpus)
      (order_rows bounds @ [ inhabited_row bounds; show_row ])

  (* [T] a delay of [n] time steps, [S] the runs of reads and writes each
     followed by two, and [R] a delay of [n] between a read and a write. *)
  let delays n =
    let bounds = model C.ends [ "Read"; "Write" ] in
    let family = Printf.sprintf "delays, n = %d" n in
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

  (* [W] any word over [k] declared names of three running times, [X] a word
     of them between two [Op1], and [Y] any two operations. *)
  let declared k =
    let bounds = model C.ends (names k) in
    let family = Printf.sprintf "k = %d declared names" k in
    let all = union (names k) ^ "*" in
    let x = "Op1; " ^ union (List.tl (names k)) ^ "*; Op1" in
    let grades () = (braces all, braces x, braces "_; _", lit "8") in
    [
      op family "leq X <= W" grades (fun (w, x, _, _) -> G.leq bounds x w);
      op family "leq W <= X (false)" grades (fun (w, x, _, _) ->
          G.leq bounds w x);
      op family "counterexample W, X" grades (fun (w, x, _, _) ->
          G.counterexample bounds w x);
      op family "leq Y <= {8}" grades (fun (_, _, y, eight) ->
          G.leq bounds y eight);
      op family "inhabited X" grades (fun (_, x, _, _) -> G.inhabited bounds x);
    ]

  (* [E] the complement of "the [n + 1]-th letter from the end is [A]" and
     [E2] its intersection with the analogous complement for [B]. *)
  let nth_from_end n =
    let bounds = model C.ends [ "A"; "B"; "C" ] in
    let family = Printf.sprintf "n-th letter from the end, n = %d" n in
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

  (* The consistency of intervals of [n] reads [R]: [C] has a run meeting
     both ends, no run meets both ends of [I], whose upper end permits no
     [B], and the durations of the ends of [T] are apart. *)
  let consistency (n, (c, i, t)) =
    let bounds = model C.ends [ "R"; "B" ] in
    let family = Printf.sprintf "interval consistency, n = %d" n in
    let interval text () = lit text in
    [
      op family "inhabited C" (interval c) (G.inhabited bounds);
      op family "vacuous I (no common run)" (interval i) (G.vacuous bounds);
      op family "vacuous T (durations apart)" (interval t) (G.vacuous bounds);
    ]
end

(* The intervals [C], [I] and [T] of [n] reads over whole time steps. *)
let whole_consistency n =
  ( Printf.sprintf "[{(R; 1)^%d; B}, {(R | 1)*; B}]" n,
    Printf.sprintf "[{R^%d; B}, {R*}]" n,
    Printf.sprintf "[{(R; 4)^%d}, {(R; 1)^%d}]" n n )

(* The intervals [C], [I] and [T] of [n] reads over rational delays. *)
let rational_consistency n =
  ( Printf.sprintf "[{(R; 1/2)^%d; B}, {(R | [0, 1/2])*; B}]" n,
    Printf.sprintf "[{R^%d; B}, {R*}]" n,
    Printf.sprintf "[{(R; 4)^%d}, {(R; 1/2)^%d}]" n n )

(* The workloads of the regex grade with banked delays [G] over whole time
   steps; the consistency of intervals is timed for an interval grade. *)
let banked_operations ~interval (module G : Grade.S) =
  let module W =
    Banked
      (G)
      (struct
        let ends = whole_ends
        let files = banked_files
        let corpus = banked_corpus
        let intervals = banked_interval_corpus
        let interval = interval
      end)
  in
  W.corpus_rows ()
  @ List.concat_map W.delays (sizes [ 8; 128; 1024 ])
  @ List.concat_map W.declared (sizes [ 8; 128; 512 ])
  @ List.concat_map W.nth_from_end (sizes [ 4; 8 ])
  @
  if interval then
    List.concat_map W.consistency
      (List.map (fun n -> (n, whole_consistency n)) (sizes [ 10; 100 ]))
  else []

(* The workloads of the rational regex grade with banked delays [G]: the
   corpus, and for the upper bound and the interval the delays and declared
   names over fractional running times with open ends. *)
let banked_rational_operations ~one_sided ~interval (module G : Grade.S) =
  let module W =
    Banked
      (G)
      (struct
        let ends = rational_ends
        let files = banked_rational_files
        let corpus = banked_rational_corpus
        let intervals = banked_rational_interval_corpus
        let interval = interval
      end)
  in
  W.corpus_rows ()
  @ (if one_sided then []
     else
       List.concat_map W.delays (sizes [ 8; 128; 1024 ])
       @ List.concat_map W.declared (sizes [ 8; 128; 512 ]))
  @
  if interval then
    List.concat_map W.consistency
      (List.map (fun n -> (n, rational_consistency n)) (sizes [ 10; 100 ]))
  else []

(** {2 Regular trace languages over rational delays} *)

(* The brace literals of the files whose headers name the rational regular
   trace languages: examples/introduction/stale_calibration.tpe,
   examples/regular_trace_languages/upper_bounds_rational.tpe and
   tests/regex_rational*.tpe. *)
let rational_corpus =
  [
    "{Read}";
    "{Sample}";
    "{Send}";
    "{Configure; SelfTest}";
    "{~(_*; Configure; (_ & ~SelfTest)*)}";
    "{_*}";
    "{Read; (0, 1/2); Report}";
    "{(Read; (1/4, 1/2])*}";
    "{Sample; [0, 1); Send}";
    "{(Sample; (0, 1/2])*}";
    "{_ & ~Reset}";
    "{~1}";
    "{(3/4)*}";
    "{(1/2)*}";
    "{(1, ∞) & ~1*}";
    "{[1, ∞)}";
    "top";
  ]

(* Grades whose sets of delays have long finite parts before their periodic
   tails (see the costs stated in the interface of [DelaySet]): sums and
   repetitions of large nearly coprime constants, and a point with a narrow
   interval; and grades of the same shape whose sets stay small. Each with a
   delay below it. *)
let delay_sets =
  [
    ("(100 | 101)*", "201");
    ("(300 | 301)*", "601");
    ("(1000 | 1001)*", "2001");
    ("97*; 89*", "186");
    ("997*; 991*", "1988");
    ("(1 | (10, 10.001))*", "1");
    ("(1/97 | 1/89)*", "1");
    ("~((300 | 301)*)", "1/2");
    ("[1, 1.001]*", "500");
  ]

module RationalRegular (G : Grade.S) = struct
  include Operations (G)

  (* [G] the grade and [d] the delay below it. *)
  let delay_set (g, d) =
    let family = "delay set {" ^ g ^ "}" in
    let grades () = (braces g, lit d) in
    [
      op family "elaborate G" Fun.id (fun () -> braces g);
      op family
        ("leq " ^ d ^ " <= G")
        grades
        (fun (g, d) -> G.leq no_bounds d g);
      op family ("equal G = G | " ^ d) grades (fun (g, d) ->
          G.equal no_bounds g (G.join g d));
      op family ("counterexample G, " ^ d) grades (fun (g, d) ->
          G.counterexample no_bounds g d);
    ]

  let operations =
    corpus "corpus" rational_corpus (order_rows no_bounds @ [ show_row ])
    @ List.concat_map delay_set
        (if quick then [ List.hd delay_sets ] else delay_sets)
end

(** {2 Timed regex grades} *)

(* The case-study corpus: literals of the case studies, each of its file,
   whose declarations and packages give the running times. *)
let case_studies =
  [
    ( "examples/arduino/bala2-radio-robot/robot.tpe",
      [
        "{(ReadEncoders | Setpoints)*}";
        "{(Reading; idle 10)*}";
        "{(ReportStatus; CheckAtRest; (Reading; idle 10)*; ReportStatus; \
         ShowTextAt; (ShowNumberAt | skip); idle 500; ShowTextAt)*; \
         ReportStatus; CheckAtRest; (Reading; idle 10)*}";
        "{LatestTilt; ([0, 1) & ~(ReceiveMessage | Move))}";
        "{(ReceiveMessage; ReportStatus; idle 400)^[1, 500]}";
      ] );
    ( "examples/arduino/bala2-radio-controller/controller.tpe",
      [
        "{(SendStart; idle 25/2)^80}";
        "{≥0 & ~SendStop}";
        "{SendStart; idle 25/2; ReceiveMessage; (SendStart; idle 25/2; \
         ReceiveMessage)*}";
        "{(ReadImu; ReadTouch; (SendDrive | SendBeat); (ShowTextAt | \
         ShowNumberAt | DrawLevel | ShowColourTextAt | skip); idle 21/2; \
         ReceiveMessage)*; (ReadImu; ReadTouch | skip)}";
      ] );
    ( "examples/arduino/starter/starter.tpe",
      [
        "{ShowColourTextAt; [1000, ∞)}";
        "{ShowColourTextAt; [1500, 3000]}";
        "{Beep; ReadClock; [0, 1000]}";
        "{(skip | idle 2.5; ReadImu; ReadClock)^200}";
        "{Beep; ReadClock; (idle [0, 2.5]; ReadImu; ReadClock)*}";
        "{(ReadTouch; (ShowColourTextAt; [0, 6000] | Beep; ShowColourTextAt; \
         ShowColourTextAt; ShowTextAt; [0, 495] | 50))*}";
      ] );
    ( "examples/arduino/fall/fall.tpe",
      [
        "{(idle 10; ReadImu)^10}";
        "{ShowNumberAt; DrawBar; [1000, 1029]}";
        "{ShowColourTextAt; ShowColourTextAt; Beep; [10000, 30000]}";
        "[{100}, {(idle [9.5, 10.5]; ReadImu)^10}]";
      ] );
    ( "examples/arduino/level/level.tpe",
      [
        "{(ReadImu; 10)^3; ReadImu; CheckAtRest; Beep}";
        "{(ReadImu | ReadTouch)*; (ConfigureImu; CheckAtRest | skip)}";
      ] );
    ( "examples/arduino/wheels/wheels.tpe",
      [
        "{SetMotors; [100, 101]; ReadEncoders}";
        "{idle 79/4; ReadEncoders}";
        "{SetMotors; (idle [19, 21]; ReadEncoders)*}";
      ] );
    ( "examples/opentrons/washes.tpe",
      [
        "{(Wash; ChangeTip)*}";
        "{AddBeads; idle [5, 10]; MagnetOn}";
        "[{(Wash; ChangeTip)^[1, ∞); Wash; idle 2; ChangeTip}, {(Wash; \
         ChangeTip)*; Wash; idle [2, 3]; ChangeTip}]";
      ] );
    ( "examples/opentrons/purification.tpe",
      [
        "[5, 10]";
        "{AddEthanol; idle [1/2, 3/2]; RemoveEthanol}";
        "{[2, 5]; MagnetOn; [2, 5]}";
      ] );
    ( "examples/opentrons/cleanup.tpe",
      [
        "{AddBeads; [5, 10]; MagnetOn}";
        "{(AddEthanol; 1; RemoveEthanol)^2; [2, 3]}";
      ] );
    ( "examples/timed_regex/intervals_rational.tpe",
      [ "[{(≥0; ReadImu; ReadClock)^3; ≥0}, {(2.5; ReadImu; ReadClock)*}]" ] );
    ( "examples/timed_regex/upper_bounds_rational.tpe",
      [ "{Beep; [0, 40]; ReadClock}" ] );
  ]

let case_study_corpus = List.concat_map snd case_studies

(* The window of the calibration of examples/arduino/bala2-radio-robot/robot.tpe,
   kept out of [case_studies]: comparing a grade of unbounded durations with
   it takes seconds. *)
let calibration_window = "[{≥1000 & ~Move}, {≤600000 & ~Move}]"

module Timed (G : Grade.S) = struct
  include Operations (G)

  (* The corpus [texts] under the running times of the case studies. *)
  let corpus_rows family texts =
    let bounds = file_bounds (List.map fst case_studies) in
    corpus family texts
      (order_rows bounds
      @ [
          ( "duration_bounds, each",
            fun gs -> ignore (List.map (G.duration_bounds bounds) gs) );
          inhabited_row bounds;
          show_row;
        ])

  (* [W] the calibration window, against the samples of the robot, [S], and
     the readings of its encoders and setpoints, [E], both of unbounded
     durations. *)
  let window_rows () =
    let bounds = file_bounds (List.map fst case_studies) in
    let family = "calibration window W = " ^ calibration_window in
    let grades () =
      ( lit calibration_window,
        braces "(Reading; idle 10)*",
        braces "(ReadEncoders | Setpoints)*" )
    in
    [
      op family "duration_bounds W" grades (fun (w, _, _) ->
          G.duration_bounds bounds w);
      op family "inhabited W" grades (fun (w, _, _) -> G.inhabited bounds w);
      op family "leq S <= W (false)" grades (fun (w, s, _) -> G.leq bounds s w);
      op family "leq E <= W (false)" grades (fun (w, _, e) -> G.leq bounds e w);
    ]

  (* [W] [n] operations [A] each followed by an idle wait of 25/2, against
     time spans of 27/2 and of 12 after each, and against any word of [A],
     [B] and time spans of 14: bounded repetitions as counts. *)
  let repetitions n =
    let bounds =
      bounds_of
        Grade.
          [
            ("A", (Open (q 0), Closed (q 1)));
            ("B", (Closed (q 1), Closed (q 2)));
          ]
    in
    let family = Printf.sprintf "bounded repetitions, n = %d" n in
    let grades () =
      ( braces (Printf.sprintf "(A; idle 25/2)^%d" n),
        braces (Printf.sprintf "(A; ≤27/2)^%d" n),
        braces (Printf.sprintf "(A; ≤12)^%d" n),
        braces "(A | B | ≤14)*" )
    in
    [
      op family "leq W <= (A; ≤27/2)^n" grades (fun (w, s, _, _) ->
          G.leq bounds w s);
      op family "leq W <= (A; ≤12)^n (false)" grades (fun (w, _, s, _) ->
          G.leq bounds w s);
      op family "counterexample W, (A; ≤12)^n" grades (fun (w, _, s, _) ->
          G.counterexample bounds w s);
      op family "leq W <= (A | B | ≤14)*" grades (fun (w, _, _, s) ->
          G.leq bounds w s);
    ]

  (* [L] the words whose [n + 2]-th and [n + 1]-th operations from the end
     are [A], against [R], those whose [n + 1]-th is [A], and [R'], those
     whose [n + 1]-th is [B]: the nondeterminism of the reader. *)
  let nth_from_end n =
    let bounds =
      bounds_of
        Grade.
          [
            ("A", (Open (q 0), Closed (q 1))); ("B", (Open (q 0), Closed (q 1)));
          ]
    in
    let family = Printf.sprintf "n-th operation from the end, n = %d" n in
    let grades () =
      ( braces (Printf.sprintf "(A | B)*; A; A; (A | B)^%d" n),
        braces (Printf.sprintf "(A | B)*; A; (A | B)^%d" n),
        braces (Printf.sprintf "(A | B)*; B; (A | B)^%d" n) )
    in
    [
      op family "leq L <= R" grades (fun (l, r, _) -> G.leq bounds l r);
      op family "leq L <= R' (false)" grades (fun (l, _, r') ->
          G.leq bounds l r');
      op family "counterexample L, R'" grades (fun (l, _, r') ->
          G.counterexample bounds l r');
    ]

  let reading_bounds =
    bounds_of
      Grade.
        [
          ("Move", (Open (q 0), Closed (Q.make 7 10)));
          ("Reading", (Open (q 0), Closed (Q.make 13 20)));
        ]

  (* [A] [k] readings each followed by an idle wait of 10, whose greatest
     length is [L], against a time span of length [L] without [Move], in
     which every item of [A] fits. *)
  let absorbed_upper k =
    let family = Printf.sprintf "time spans absorbing items, k = %d" k in
    let l = Q.show (Q.make (213 * k) 20) in
    let grades () =
      ( braces (Printf.sprintf "(Reading; idle 10)^%d" k),
        braces ("≤" ^ l ^ " & ~Move"),
        braces ("<" ^ l ^ " & ~Move") )
    in
    [
      op family "duration_bounds A" grades (fun (a, _, _) ->
          G.duration_bounds reading_bounds a);
      op family "leq A <= ≤L & ~Move" grades (fun (a, s, _) ->
          G.leq reading_bounds a s);
      op family "leq A <= <L & ~Move (false)" grades (fun (a, _, s) ->
          G.leq reading_bounds a s);
      op family "counterexample A, <L & ~Move" grades (fun (a, _, s) ->
          G.counterexample reading_bounds a s);
    ]

  let absorbed_lower k =
    let family = Printf.sprintf "time spans absorbing items, k = %d" k in
    let grades () =
      (braces (Printf.sprintf "(Reading; idle 10)^%d" k), braces "≥1000 & ~Move")
    in
    [
      op family "duration_bounds A" grades (fun (a, _) ->
          G.duration_bounds reading_bounds a);
      op family "leq A <= ≥1000 & ~Move" grades (fun (a, s) ->
          G.leq reading_bounds a s);
      op family "counterexample A, ≥1000 & ~Move" grades (fun (a, s) ->
          G.counterexample reading_bounds a s);
    ]

  (* [X] a word of [k] declared names of three running times between two
     [Op1], against a time span without [Op1] between two [Op1], [S], and
     against the words of the names and time spans of 3: classes of names. *)
  let declared k =
    let bounds = model whole_ends (names k) in
    let family = Printf.sprintf "k = %d declared names" k in
    let others = List.tl (names k) in
    let grades () =
      ( braces ("Op1; " ^ union others ^ "*; Op1"),
        braces "Op1; (≥0 & ~Op1); Op1",
        braces ("Op1; " ^ union (others @ [ "≤3" ]) ^ "*; Op1") )
    in
    [
      op family "leq X <= S" grades (fun (x, s, _) -> G.leq bounds x s);
      op family "leq X <= Op1; (Op2 | ... | ≤3)*; Op1" grades (fun (x, _, y) ->
          G.leq bounds x y);
      op family "leq S <= X (false)" grades (fun (x, s, _) -> G.leq bounds s x);
      op family "counterexample S, X" grades (fun (x, s, _) ->
          G.counterexample bounds s x);
    ]

  (* The consistency of intervals of [n] reads [R]: [C] has a run meeting
     both ends, with idle waits between 9.5 and 10.5; no run meets both ends
     of [I], whose last operations differ; and the durations of the ends of
     [T] are apart. *)
  let consistency n =
    let bounds =
      bounds_of
        Grade.
          [
            ("B", (Open (q 0), Closed (Q.make 1 2)));
            ("R", (Open (q 0), Closed (Q.make 1 2)));
          ]
    in
    let family = Printf.sprintf "interval consistency, n = %d" n in
    let interval text () = lit text in
    [
      op family "inhabited C"
        (interval
           (Printf.sprintf "[{%d}, {(idle [9.5, 10.5]; R)^%d}]" (10 * n) n))
        (G.inhabited bounds);
      op family "vacuous I (no common run)"
        (interval
           (Printf.sprintf "[{(R; ≥0)^%d; B}, {(R; idle ≤1)^%d; R}]" n n))
        (G.vacuous bounds);
      op family "vacuous T (durations apart)"
        (interval (Printf.sprintf "[{(R; idle 10)^%d}, {(R; idle 9)^%d}]" n n))
        (G.vacuous bounds);
    ]
end

(* The timed regex workloads, by grade: the case-study corpus and the
   consistency of intervals under the rational interval grade, the bounded
   repetitions and the time spans under the rational bounds, and the
   nondeterminism of the reader and the declared names over whole time
   steps. *)
let timed_interval_rational (module G : Grade.S) =
  let module W = Timed (G) in
  W.corpus_rows "case-study corpus" case_study_corpus
  @ W.window_rows ()
  @ List.concat_map W.consistency (sizes [ 10; 40; 160; 640 ])

let timed_upper_rational (module G : Grade.S) =
  let module W = Timed (G) in
  List.concat_map W.repetitions (sizes [ 20; 80; 320; 1280 ])
  @ List.concat_map W.absorbed_upper (sizes [ 10; 100; 1000 ])

let timed_lower_rational (module G : Grade.S) =
  let module W = Timed (G) in
  List.concat_map W.absorbed_lower (sizes [ 10; 100; 1000 ])

let timed_upper (module G : Grade.S) =
  let module W = Timed (G) in
  List.concat_map W.nth_from_end (sizes [ 4; 8; 12; 16 ])
  @ List.concat_map W.declared (sizes [ 32; 512 ])

(* The literals [texts] of the case-study corpus under a finite grade. *)
let timed_finite texts (module G : Grade.S) =
  let module W = Timed (G) in
  W.corpus_rows "star-free case-study corpus" texts

(** {1 Typechecking} *)

module Programs (G : Grade.S) = struct
  module Backend = CliInterpreter.Make (Grades.GradeSystem.Identity (G))
  module L = Loader.Loader (Backend)

  (* The standard library loaded, then the program [file], if any, with the
     diagnostics of its rejection collected, up to the first error if it does
     not parse. *)
  let typecheck file () =
    let stdlib =
      L.parse_source ~filename:Loader.stdlib_filename L.stdlib_source
    in
    try
      let program = Option.map L.parse_file file in
      let state =
        L.declare (stdlib :: Option.to_list program) L.initial_state
      in
      let state = L.load_commands state stdlib in
      Option.iter
        (fun program -> ignore (L.load_commands_all state program))
        program
    with Utils.Error.Error _ -> ()

  let workload family file =
    let name = Option.value file ~default:"standard library alone" in
    { family; name; prepare = (fun () -> typecheck file) }

  (* The standard library alone, then with each of [files]. *)
  let workloads family files =
    workload family None :: List.map (fun f -> workload family (Some f)) files
end

let typechecking family files (module G : Grade.S) =
  let module P = Programs (G) in
  P.workloads family files

(* The examples and tests whose headers name the grade [name]. *)
let programs name =
  TestPrograms.tpe_files "examples"
  @ TestPrograms.tpe_files ~recursive:false "tests"
  |> List.filter (fun path -> TestSupport.Header.grades path = name)

(** {1 Sections} *)

(* A grade of each column, the typechecking of [programs] under them, and
   their [operations]. *)
type group = {
  label : string;
  grades : string list;
  programs : string list;
  operations : (module Grade.S) -> workload list;
}

type column = { title : string; short : string }

type section = {
  heading : string;
  columns : column list;
  ratios : string list;
  groups : group list;
}

let automata = { title = "automata"; short = "aut." }
let plain = { title = "plain"; short = "pl." }
let letters = { title = "letters"; short = "let." }
let symbolic = { title = "symbolic"; short = "sym." }
let timed = { title = "time"; short = "" }

let whole_suffixes =
  [
    "-letter-automata";
    "-letter-derivatives";
    "-symbolic-by-letters";
    "-symbolic";
  ]

(* The group of the grade [base] in each implementation of [suffixes], whose
   programs are those of the implementation named [base ^ "-symbolic"]. *)
let implemented suffixes base operations =
  {
    label = base;
    grades = List.map (fun s -> base ^ s) suffixes;
    programs = programs (base ^ "-symbolic");
    operations;
  }

let whole_section () =
  let group = implemented whole_suffixes in
  {
    heading = "Whole time steps";
    columns = [ automata; plain; letters; symbolic ];
    ratios = [ "aut/plain"; "plain/let"; "let/symb" ];
    groups =
      [
        group "regular-trace-languages" (fun (module G) ->
            let module W = Regular (G) in
            W.operations);
        group "banked-regex-lower-bound" (banked_operations ~interval:false);
        group "banked-regex-upper-bound" (banked_operations ~interval:false);
        group "banked-regex-interval" (banked_operations ~interval:true);
      ];
  }

let rational_section () =
  let group base =
    implemented [ "-automata"; "-symbolic" ] (base ^ "-rational")
  in
  {
    heading = "Rational delays";
    columns = [ automata; symbolic ];
    ratios = [ "aut/symb" ];
    groups =
      [
        group "regular-trace-languages" (fun (module G) ->
            let module W = RationalRegular (G) in
            W.operations);
        group "banked-regex-lower-bound"
          (banked_rational_operations ~one_sided:true ~interval:false);
        group "banked-regex-upper-bound"
          (banked_rational_operations ~one_sided:false ~interval:false);
        group "banked-regex-interval"
          (banked_rational_operations ~one_sided:false ~interval:true);
      ];
  }

let timed_section () =
  let group name operations =
    { label = name; grades = [ name ]; programs = []; operations }
  in
  let star_free =
    readable "timed-regex-finite-interval-rational" case_study_corpus
  in
  {
    heading = "Timed regex grades";
    columns = [ timed ];
    ratios = [];
    groups =
      [
        group "timed-regex-interval-rational" timed_interval_rational;
        group "timed-regex-upper-bound-rational" timed_upper_rational;
        group "timed-regex-lower-bound-rational" timed_lower_rational;
        group "timed-regex-upper-bound" timed_upper;
        group "timed-regex-finite-interval-rational" (timed_finite star_free);
      ];
  }

(** {1 Tables} *)

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

(* The ratios of the consecutive elements of [outcomes]. *)
let rec ratios = function
  | x :: (y :: _ as rest) -> show_ratio x y :: ratios rest
  | [ _ ] | [] -> []

(* The text [s] as a Markdown table cell, its column separators escaped. *)
let cell s = String.concat "\\|" (String.split_on_char '|' s)

(* [pad width s] is [s] followed by spaces up to [width] characters of
   UTF-8. *)
let pad width s =
  let length =
    String.fold_left
      (fun n c -> if Char.code c land 0xC0 = 0x80 then n else n + 1)
      0 s
  in
  s ^ String.make (max 0 (width - length)) ' '

let print_row name cells =
  Printf.printf "| %s |%s\n%!"
    (pad 40 (cell name))
    (String.concat "" (List.map (Printf.sprintf " %10s |") cells))

let print_header cells =
  print_row "workload" cells;
  Printf.printf "|%s|%s\n" (String.make 42 '-')
    (String.concat "" (List.map (Fun.const "------------|") cells))

(* The cells of the header of a table of [section], with the warm times if
   [warm]. *)
let header_cells ~warm section =
  List.map (fun c -> c.title) section.columns
  @ section.ratios
  @ if warm then List.map (fun c -> c.short ^ " warm") section.columns else []

(* [transpose rows] is the list of the columns of [rows], of equal lengths. *)
let rec transpose = function
  | [] | [] :: _ -> []
  | rows -> List.map List.hd rows :: transpose (List.map List.tl rows)

(* The rows of the workloads [columns] of a group, one list per column of
   the same workloads, under the headings of their families, each prefixed
   by [prefix]. *)
let print_rows ~warm ~width prefix columns =
  if
    List.exists
      (fun c -> List.length c <> List.length (List.hd columns))
      columns
  then invalid_arg "the workloads of the columns differ";
  List.fold_left
    (fun current (row : workload list) ->
      let w = List.hd row in
      if w.family <> current then
        print_row
          ("**" ^ prefix w.family ^ "**")
          (List.init width (Fun.const ""));
      let outcomes = List.map (fun w -> measure ~warm w.prepare) row in
      print_row w.name
        (List.map show_cold outcomes
        @ ratios outcomes
        @ if warm then List.map show_warm outcomes else []);
      w.family)
    "" (transpose columns)
  |> ignore

let print_section section =
  Printf.printf "\n%s\n" section.heading;
  let typechecked = List.filter (fun g -> g.programs <> []) section.groups in
  if typechecked <> [] then begin
    Printf.printf "\nTypechecking:\n\n";
    let cells = header_cells ~warm:true section in
    print_header cells;
    List.iter
      (fun g ->
        let family = "typechecking, " ^ g.label in
        print_rows ~warm:true ~width:(List.length cells) Fun.id
          (List.map
             (fun name -> typechecking family g.programs (grade name))
             g.grades))
      typechecked
  end;
  Printf.printf "\nGrade operations:\n\n";
  let cells = header_cells ~warm:false section in
  print_header cells;
  List.iter
    (fun g ->
      print_rows ~warm:false ~width:(List.length cells)
        (fun family -> g.label ^ ": " ^ family)
        (List.map (fun name -> g.operations (grade name)) g.grades))
    section.groups

let () =
  (match List.filter (( <> ) "--quick") (List.tl (Array.to_list Sys.argv)) with
  | [ root ] -> Sys.chdir root
  | _ -> ());
  let start = now () in
  Printf.printf
    "Median over %d processes (fewer past %.0f s), each stopped after %d s; \
     cold: first run in a fresh process; warm: mean of repeated runs, for the \
     typechecking; ratios of the cold times of consecutive columns.\n"
    processes patience time_limit;
  List.iter
    (fun section -> print_section (section ()))
    [ whole_section; rational_section; timed_section ];
  let total = int_of_float (now () -. start) in
  Printf.printf "\nTotal run time: %d min %d s\n" (total / 60) (total mod 60)
