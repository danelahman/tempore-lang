(* Tests of the choices the web interface remembers: the round trip of their
   encoding, the refusal of malformed encodings, and the removal of unknown
   grades, backends and inputs, and of resource grades not paired with the
   grades. Silent on success. *)

let fail = TestSupport.Failures.fail

let choices =
  {
    WebChoices.use_stdlib = false;
    example =
      Some
        {
          path = "examples/opentrons/a.tpe";
          group = "Opentrons: protocols";
          title = "A title: with colons, 12:3";
        };
    grade = Some Grades.GradeRegistry.default_name;
    backend = Some "opentrons";
    settings =
      [
        ( "opentrons",
          [
            ("binding", "line one\nline two: 7:\n\t\"quoted\" ü");
            ("time-unit", "minutes");
          ] );
        ("arduino", [ ("manifest", ""); ("monitor", "warn") ]);
        ("interpreter", []);
      ];
    resources = None;
  }

let proofing =
  {
    choices with
    grade = Some "time-interval";
    resources = Some "time-lower-bound";
  }

let () =
  (* round trips *)
  List.iter
    (fun c ->
      if WebChoices.decode (WebChoices.encode c) <> Some c then
        fail "round trip: %s" (WebChoices.encode c))
    [
      choices;
      proofing;
      {
        WebChoices.use_stdlib = true;
        example = None;
        grade = None;
        backend = None;
        settings = [];
        resources = None;
      };
    ];
  (* the resources written last, and only when selected *)
  let encoded = WebChoices.encode choices in
  if
    WebChoices.encode proofing
    <> WebChoices.encode { proofing with resources = None }
       ^ "1:116:time-lower-bound"
  then fail "the resources are not the last field";
  if WebChoices.decode (encoded ^ "1:1") <> None then
    fail "malformed resources accepted";
  (* malformed encodings *)
  List.iter
    (fun s ->
      if WebChoices.decode s <> None then fail "malformed accepted: %S" s)
    [
      "";
      "true";
      String.sub encoded 0 (String.length encoded - 1);
      encoded ^ "1:x";
      "4:true1:2";
      "4:true01:0";
      "4:true1:01:01:0-1:0";
      "garbage";
    ];
  (* unknown grade algebras, backends and inputs *)
  let unknown =
    WebChoices.sanitise
      {
        choices with
        grade = Some "no-such-grades";
        backend = Some "no-such-backend";
        settings =
          [
            ("no-such-backend", [ ("binding", "x") ]);
            ( "opentrons",
              [
                ("binding", "first");
                ("no-such-input", "x");
                ("time-unit", "fortnights");
                ("binding", "second");
                ("monitor", "off");
              ] );
            ("opentrons", [ ("binding", "repeated") ]);
          ];
      }
  in
  if unknown.grade <> None then fail "unknown grade kept";
  if unknown.backend <> None then fail "unknown backend kept";
  if
    unknown.settings
    <> [ ("opentrons", [ ("binding", "first"); ("monitor", "off") ]) ]
  then fail "unknown settings kept";
  if WebChoices.sanitise choices <> choices then fail "known choices changed";
  if WebChoices.sanitise proofing <> proofing then
    fail "paired resource grades changed";
  List.iter
    (fun (name, c) ->
      if (WebChoices.sanitise c).resources <> None then
        fail "resource grades kept: %s" name)
    [
      ("unknown grade", { proofing with grade = Some "no-such-grades" });
      ("no grade", { proofing with grade = None });
      ("unpaired", { proofing with grade = Some "time-interval-rational" });
      ("unknown", { proofing with resources = Some "no-such-grades" });
      ("the grades", { proofing with resources = Some "time-interval" });
    ]

let () = TestSupport.Failures.finish ()
