(* Tests of the parameters of the address of the web interface: parsing,
   percent-decoding and repeated keys, the round trip of serialisation, and the
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

let link ?example ?grades ?backend () = { WebLink.example; grades; backend }

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
