(* Tests of the choices the web interface remembers: the round trip of their
   encoding, the refusal of malformed encodings, and the removal of unknown
   grades, backends and inputs. Silent on success. *)

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
  }

let () =
  (* round trips *)
  List.iter
    (fun c ->
      if WebChoices.decode (WebChoices.encode c) <> Some c then
        fail "round trip: %s" (WebChoices.encode c))
    [
      choices;
      {
        WebChoices.use_stdlib = true;
        example = None;
        grade = None;
        backend = None;
        settings = [];
      };
    ];
  (* malformed encodings *)
  let encoded = WebChoices.encode choices in
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
  (* unknown grades, backends and inputs *)
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
  if WebChoices.sanitise choices <> choices then fail "known choices changed"

let () = TestSupport.Failures.finish ()
