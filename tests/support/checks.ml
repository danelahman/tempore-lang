type check = { name : string; passed : bool; detail : string }

let check name passed detail = { name; passed; detail }

let expect name show ~expected actual =
  check name (expected = actual)
    ("expected " ^ show expected ^ ", got " ^ show actual)

let report checks =
  let failures = List.filter (fun c -> not c.passed) checks in
  List.iter (fun c -> Printf.printf "FAIL %s: %s\n" c.name c.detail) failures;
  Printf.printf "%d of %d checks passed\n"
    (List.length checks - List.length failures)
    (List.length checks);
  if failures <> [] then exit 1
