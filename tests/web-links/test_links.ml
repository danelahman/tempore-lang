(* Tests of the parameters of the address of the web interface: parsing,
   percent-decoding and repeated keys, the round trip of serialisation over
   random byte strings, the line numbers and the lines they name, and the
   choices the page opens with under parameters and remembered choices, with
   unknown examples, grades and backends ignored. Silent on success. *)

let failures = ref []
let fail fmt = Format.kasprintf (fun msg -> failures := msg :: !failures) fmt
let grades_a = Grades.GradeRegistry.default_name
let grades_b = fst (List.nth Grades.GradeRegistry.grade_modules 1)

let entry path group title grade backend =
  { WebLink.example = { WebChoices.path; group; title }; grade; backend }

let sensor =
  entry "examples/introduction/sensor.tpe" "Introduction" "Sensor" grades_a
    "interpreter"

let robot =
  entry "examples/arduino/bala2/balance.tpe" "Arduino devices" "Balancing robot"
    grades_b "arduino"

let elisa =
  entry "examples/opentrons/elisa.tpe" "Opentrons" "ELISA" grades_a "opentrons"

let catalogue =
  let entries = [ sensor; robot; elisa ] in
  {
    WebLink.find =
      (fun path ->
        List.find_opt (fun (e : WebLink.entry) -> e.example.path = path) entries);
    default_of =
      (fun key ->
        List.assoc_opt key [ ("arduino", robot); ("opentrons", elisa) ]);
  }

let defaults =
  {
    WebChoices.use_stdlib = true;
    example = Some sensor.example;
    grade = Some grades_a;
    backend = Some "interpreter";
    settings = [];
  }

let remembered =
  {
    WebChoices.use_stdlib = false;
    example = Some elisa.example;
    grade = Some grades_b;
    backend = Some "opentrons";
    settings =
      [
        ("opentrons", [ ("time-unit", "minutes") ]);
        ("arduino", [ ("monitor", "warn") ]);
      ];
  }

let link ?example ?grades ?backend ?line () =
  { WebLink.example; grades; backend; line }

let check_parse query expected =
  let parsed = WebLink.parse query in
  if parsed <> expected then fail "parse %S" query

let check_resolve name ?remembered:r query expected_choices expected_ignored =
  let parameters, _ = WebLink.parse query in
  let choices, ignored = WebLink.resolve catalogue ~defaults r parameters in
  if choices <> expected_choices then fail "resolve %s: choices" name;
  if ignored <> expected_ignored then fail "resolve %s: ignored" name

let () =
  (* parsing *)
  check_parse "" (WebLink.empty, []);
  check_parse "?" (WebLink.empty, []);
  check_parse "?example=arduino/bala2/balance.tpe"
    (link ~example:"arduino/bala2/balance.tpe" (), []);
  check_parse "example=a%2Fb%20c+d.tpe&grades=g"
    (link ~example:"a/b c d.tpe" ~grades:"g" (), []);
  check_parse "?grades=first&grades=second&backend=b&backend=c"
    (link ~grades:"first" ~backend:"b" (), []);
  check_parse "?utm_source=x&example=e&fbclid=y&flag" (link ~example:"e" (), []);
  check_parse "?%65xample=e" (link ~example:"e" (), []);
  check_parse "?example=%zz&grades=&backend=%4"
    (WebLink.empty, [ WebLink.Example; Grades; Backend ]);
  check_parse "?grades&backend=b" (link ~backend:"b" (), [ WebLink.Grades ]);
  check_parse "?example=%C3%BC" (link ~example:"\xC3\xBC" (), []);
  (* serialisation *)
  if WebLink.serialise WebLink.empty <> "" then fail "serialise empty";
  if
    WebLink.serialise (link ~example:"arduino/bala2/balance.tpe" ())
    <> "?example=arduino/bala2/balance.tpe"
  then fail "serialise a path";
  if
    WebLink.serialise (link ~grades:"a b&c=d" ~backend:"x" ())
    <> "?grades=a%20b%26c%3Dd&backend=x"
  then fail "serialise reserved characters";
  List.iter
    (fun l ->
      if WebLink.parse (WebLink.serialise l) <> (l, []) then
        fail "round trip: %s" (WebLink.serialise l))
    [
      link ~example:"arduino/bala2/balance.tpe" ();
      link ~example:"a+b %/\xC3\xBC?#&=" ~grades:grades_b ~backend:"arduino" ();
      link ~backend:"opentrons" ();
    ];
  (* the round trip over random values: bytes of the reserved characters, of
     the percent sign, the plus sign and the space, of letters and digits, and
     arbitrary bytes, non-ASCII among them *)
  let random = Random.State.make [| 7 |] in
  let special = "&=#%+ ?/;:@!$'()*,[]\t\n" in
  let value () =
    String.init
      (1 + Random.State.int random 12)
      (fun _ ->
        match Random.State.int random 4 with
        | 0 -> special.[Random.State.int random (String.length special)]
        | 1 -> Char.chr (Char.code 'a' + Random.State.int random 26)
        | 2 -> Char.chr (Char.code '0' + Random.State.int random 10)
        | _ -> Char.chr (Random.State.int random 256))
  in
  let optional f = if Random.State.bool random then Some (f ()) else None in
  for _ = 1 to 2000 do
    let l =
      link ?example:(optional value) ?grades:(optional value)
        ?backend:(optional value)
        ?line:(optional (fun () -> 1 + Random.State.int random 100_000))
        ()
    in
    if WebLink.parse (WebLink.serialise l) <> (l, []) then
      fail "random round trip: %s" (WebLink.serialise l)
  done;
  (* an empty value is serialised, and read back as malformed *)
  List.iter
    (fun (l, p) ->
      if WebLink.parse (WebLink.serialise l) <> (WebLink.empty, [ p ]) then
        fail "empty value: %s" (WebLink.serialise l))
    [
      (link ~example:"" (), WebLink.Example);
      (link ~grades:"" (), WebLink.Grades);
      (link ~backend:"" (), WebLink.Backend);
    ];
  (* line numbers: positive decimal numbers, leading zeros allowed *)
  check_parse "?example=e&line=42" (link ~example:"e" ~line:42 (), []);
  check_parse "?example=e&line=007" (link ~example:"e" ~line:7 (), []);
  check_parse "?example=e&line=%34%32" (link ~example:"e" ~line:42 (), []);
  check_parse "?example=e&line=3&line=5" (link ~example:"e" ~line:3 (), []);
  check_parse "?example=e&line=x&line=5" (link ~example:"e" (), [ WebLink.Line ]);
  List.iter
    (fun value ->
      check_parse
        ("?example=e&line" ^ value)
        (link ~example:"e" (), [ WebLink.Line ]))
    [
      "=0";
      "=000";
      "=-1";
      "=1e3";
      "=0x10";
      "=1_000";
      "=+5";
      "=%2B5";
      "=5%20";
      "=4.2";
      "=";
      "";
      "=%3";
      "=99999999999999999999999";
    ];
  if WebLink.serialise (link ~example:"e" ~line:42 ()) <> "?example=e&line=42"
  then fail "serialise a line";
  (* the lines a source has *)
  let check_line source n expected =
    if WebLink.line_bytes source n <> expected then
      fail "line_bytes %S %d" source n
  in
  let source = "ab\n  cd\n\t\n" in
  check_line source 1 (Some (0, 2));
  check_line source 2 (Some (5, 7));
  check_line source 3 (Some (9, 9));
  check_line source 4 (Some (10, 10));
  check_line source 5 None;
  check_line source 0 None;
  check_line source (-1) None;
  check_line "" 1 (Some (0, 0));
  check_line "" 2 None;
  check_line "x" 1 (Some (0, 1));
  (* without parameters: the remembered choices, or else the defaults *)
  check_resolve "none" "" defaults [];
  check_resolve "none, remembered" ~remembered "" remembered [];
  (* an example: its own grades, backend and settings *)
  let robot_choices =
    {
      remembered with
      example = Some robot.example;
      grade = Some grades_b;
      backend = Some "arduino";
      settings = [ ("opentrons", [ ("time-unit", "minutes") ]) ];
    }
  in
  check_resolve "example" ~remembered "?example=arduino/bala2/balance.tpe"
    robot_choices [];
  check_resolve "example from the project root" ~remembered
    "?example=examples/arduino/bala2/balance.tpe" robot_choices [];
  check_resolve "example, no remembered choices"
    "?example=arduino/bala2/balance.tpe"
    {
      defaults with
      example = Some robot.example;
      grade = Some grades_b;
      backend = Some "arduino";
    }
    [];
  (* overrides of the example's grades and backend *)
  check_resolve "example, grades and backend" ~remembered
    ("?example=arduino/bala2/balance.tpe&backend=interpreter&grades=" ^ grades_a)
    { robot_choices with grade = Some grades_a; backend = Some "interpreter" }
    [];
  (* a backend alone: the remembered example of that backend kept, or else the
     backend's default example *)
  check_resolve "backend of the remembered example" ~remembered
    "?backend=opentrons" remembered [];
  check_resolve "backend of another example" ~remembered "?backend=arduino"
    robot_choices [];
  check_resolve "backend without a default example" ~remembered
    "?backend=interpreter"
    { remembered with backend = Some "interpreter" }
    [];
  check_resolve "grades alone" ~remembered ("?grades=" ^ grades_a)
    { remembered with grade = Some grades_a }
    [];
  (* unknown and malformed values ignored *)
  check_resolve "unknown example" ~remembered "?example=no/such.tpe" remembered
    [ WebLink.Example ];
  check_resolve "unknown grades and backend" ~remembered
    "?example=arduino/bala2/balance.tpe&grades=no-such&backend=no-such"
    robot_choices
    [ WebLink.Grades; Backend ];
  check_resolve "unknown example, known backend" ~remembered
    "?example=no/such.tpe&backend=arduino" robot_choices [ WebLink.Example ];
  (* a line, kept with a known example only *)
  check_resolve "example and line" ~remembered
    "?example=arduino/bala2/balance.tpe&line=42" robot_choices [];
  check_resolve "line alone" ~remembered "?line=42" remembered [ WebLink.Line ];
  check_resolve "line of an unknown example" ~remembered
    "?example=no/such.tpe&line=42" remembered [ WebLink.Example; Line ];
  check_resolve "line of a malformed example" ~remembered "?example=%zz&line=42"
    remembered [ WebLink.Line ];
  check_resolve "line with a backend alone" ~remembered
    "?backend=arduino&line=42" robot_choices [ WebLink.Line ];
  (* the parameters naming choices *)
  let check_of_choices name choices expected =
    if WebLink.of_choices catalogue choices <> expected then
      fail "of_choices %s" name
  in
  check_of_choices "the example's own" robot_choices
    (link ~example:"arduino/bala2/balance.tpe" ());
  check_of_choices "overridden"
    { robot_choices with grade = Some grades_a; backend = Some "interpreter" }
    (link ~example:"arduino/bala2/balance.tpe" ~grades:grades_a
       ~backend:"interpreter" ());
  check_of_choices "no example"
    { remembered with example = None }
    (link ~grades:grades_b ~backend:"opentrons" ());
  check_of_choices "unknown example"
    {
      remembered with
      example = Some { path = "examples/gone.tpe"; group = "G"; title = "T" };
    }
    (link ~grades:grades_b ~backend:"opentrons" ());
  (* opening the link of choices yields them again *)
  List.iter
    (fun (name, choices) ->
      let parameters = WebLink.of_choices catalogue choices in
      let reopened, ignored =
        WebLink.resolve catalogue ~defaults (Some remembered) parameters
      in
      if
        ignored <> []
        || reopened.example <> choices.example
        || reopened.grade <> choices.grade
        || reopened.backend <> choices.backend
      then fail "reopened %s" name)
    [
      ("robot", robot_choices);
      ("robot under other grades", { robot_choices with grade = Some grades_a });
      ("elisa", remembered);
    ]

let () =
  match List.rev !failures with
  | [] -> ()
  | failures ->
      List.iter prerr_endline failures;
      exit 1
