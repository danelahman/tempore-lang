(* Tests of the reuse of the last successful check of the program: a check of
   unchanged inputs reused, a check of inputs changed in any component
   performed anew, and a failed check not kept. Silent on success. *)

let fail = TestSupport.Failures.fail

let declaration =
  {
    BackendRegistry.filename = "binding.tpe";
    text = "operation Wait : unit ~> unit # 1";
    running_times =
      [
        ( "Wait",
          ( Grades.Grade.Closed Grades.Rational.zero,
            Closed Grades.Rational.(of_int 2) ) );
      ];
  }

let key =
  {
    WebCheckCache.source = "run delay 1";
    grades = Grades.GradeRegistry.default_name;
    use_stdlib = true;
    declared = [ declaration ];
  }

(* The number of checks performed, each yielding [outcome] as its result. *)
let checks = ref 0

let check outcome () =
  incr checks;
  outcome

(* [cache] checked under [key] by a check yielding [outcome]: the result, and
   whether the check has been performed, against [reused]. *)
let expect name ~reused cache key outcome =
  let before = !checks in
  let result, reused', cache =
    WebCheckCache.checked cache key (check outcome)
  in
  let performed = !checks > before in
  if reused' <> reused then fail "%s: reused %b, not %b" name reused' reused;
  if performed = reused then
    fail "%s: check performed %b, not %b" name performed (not reused);
  (result, cache)

let () =
  (* a second check of unchanged inputs reused, its result that of the first *)
  let _, cache = expect "first" ~reused:false WebCheckCache.empty key (Ok 1) in
  let result, cache = expect "second" ~reused:true cache key (Ok 2) in
  if result <> Ok 1 then fail "second: not the result of the first";
  if WebCheckCache.find cache key <> Some 1 then fail "second: entry";
  (* a key equal in structure, not in identity, reused *)
  let copy =
    {
      key with
      source = String.concat "" [ "run "; "delay 1" ];
      declared = [ { declaration with text = String.cat declaration.text "" } ];
    }
  in
  ignore (expect "copy" ~reused:true cache copy (Ok 3));
  (* a change of any component checked anew, and the entry replaced *)
  let changed =
    [
      ("source", { key with source = "run delay 2" });
      ( "grades",
        {
          key with
          grades =
            fst
              (List.find
                 (fun (name, _) -> name <> key.grades)
                 Grades.GradeRegistry.grade_modules);
        } );
      ("use_stdlib", { key with use_stdlib = false });
      ("declarations", { key with declared = [] });
      ( "file name",
        { key with declared = [ { declaration with filename = "other.tpe" } ] }
      );
      ( "declaration text",
        {
          key with
          declared =
            [ { declaration with text = "operation Wait : unit ~> unit # 2" } ];
        } );
      ( "running times",
        {
          key with
          declared =
            [
              {
                declaration with
                running_times =
                  [
                    ( "Wait",
                      ( Grades.Grade.Closed Grades.Rational.zero,
                        Open Grades.Rational.(of_int 2) ) );
                  ];
              };
            ];
        } );
    ]
  in
  List.iter
    (fun (name, key') ->
      let result, cache' = expect name ~reused:false cache key' (Ok 4) in
      if result <> Ok 4 then fail "%s: not the result of the new check" name;
      if WebCheckCache.find cache' key' <> Some 4 then fail "%s: entry" name;
      if WebCheckCache.find cache' key <> None then
        fail "%s: the earlier entry kept" name;
      ignore (expect (name ^ ", again") ~reused:true cache' key' (Ok 5)))
    changed;
  (* a failed check not kept: the earlier entry stays, and the same inputs are
     checked again *)
  let failed = { key with source = "run delay" } in
  let result, cache' = expect "failed" ~reused:false cache failed (Error ()) in
  if result <> Error () then fail "failed: not the error";
  if WebCheckCache.find cache' key <> Some 1 then fail "failed: entry lost";
  ignore (expect "failed, again" ~reused:false cache' failed (Error ()));
  ignore (expect "failed, earlier" ~reused:true cache' key (Ok 6))

let () = TestSupport.Failures.finish ()
