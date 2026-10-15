(* A benchmark of the typechecking of the files of the examples and tests
   under the grades their headers name, with the packages of the examples, as
   checked by the solver tests. The standard library is loaded untimed. Each
   file is typechecked in fresh child processes, so that the tables the grades
   keep start empty; the table shows the median time of the first (cold) run,
   slowest file first, with the total. Run from the root of the repository:

     dune exec --profile release bench/typecheck/bench_typecheck.exe

   See bench/typecheck/README.md for a results table. *)

let now = Unix.gettimeofday
let processes = 3
let time_limit = 120
let slow = 2.

(* The time to typecheck the file in a child process, [None] if the child did
   not end normally or the file does not parse. *)
let in_child ~packages path grades =
  flush_all ();
  let input, output = Unix.pipe ~cloexec:true () in
  match Unix.fork () with
  | 0 ->
      Unix.close input;
      ignore (Unix.alarm time_limit);
      let (module P) = SolvePrograms.programs_of grades in
      ignore (P.definitions "");
      let start = now () in
      let verdicts = P.file ~packages path in
      let time = now () -. start in
      let channel = Unix.out_channel_of_descr output in
      if Option.is_some verdicts then Printf.fprintf channel "%h\n" time;
      close_out channel;
      Unix._exit 0
  | pid -> (
      Unix.close output;
      let channel = Unix.in_channel_of_descr input in
      let line = In_channel.input_line channel in
      close_in channel;
      match (snd (Unix.waitpid [] pid), line) with
      | Unix.WEXITED 0, Some time -> Some (float_of_string time)
      | _ -> None)

let median xs =
  let xs = List.sort Float.compare xs in
  List.nth xs (List.length xs / 2)

let measure (path, grades, packages) =
  let times =
    List.filter_map Fun.id
      (List.init processes (fun _ -> in_child ~packages path grades))
  in
  if times = [] then None else Some (path, grades, median times)

let () =
  let results =
    TestPrograms.corpus "." |> List.filter_map measure
    |> List.sort (fun (_, _, a) (_, _, b) -> Float.compare b a)
  in
  Printf.printf
    "Median over %d processes of the cold typechecking time; files over %.0f s \
     are marked.\n\n"
    processes slow;
  Printf.printf "| file | grades | time (s) | |\n|---|---|---:|---|\n";
  List.iter
    (fun (path, grades, time) ->
      let path =
        if String.starts_with ~prefix:"./" path then
          String.sub path 2 (String.length path - 2)
        else path
      in
      Printf.printf "| %s | %s | %.2f | %s |\n" path grades time
        (if time > slow then "slow" else ""))
    results;
  Printf.printf "\n%d files, total %.1f s, %d over %.0f s.\n"
    (List.length results)
    (List.fold_left (fun acc (_, _, t) -> acc +. t) 0. results)
    (List.length (List.filter (fun (_, _, t) -> t > slow) results))
    slow
