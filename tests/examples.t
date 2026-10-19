Every example under examples/, run by the command of its header: under its
grades, with the packages and the board it names, if any. The resource states
of the runs of the Arduino examples are omitted, since their floating-point
components depend on the elementary functions of the C library; the Arduino
tests show those runs in detail.

  $ . ./helpers.sh
  $ for f in $(find ../examples -name '*.tpe' | LC_ALL=C sort)
  > do
  >   echo "======================================================================"
  >   echo $f
  >   echo "======================================================================"
  >   case $f in
  >     ../examples/arduino/*) ../tempore $(support/header_options.exe $f) $f | strip_state;;
  >     *) ../tempore $(support/header_options.exe $f) $f;;
  >   esac
  >   :  # this command is here to suppress potential non-zero exit codes in the output
  > done
  ======================================================================
  ../examples/arduino/bala2-controller/controller.tpe
  ======================================================================
  === Run 1 ===
  return (false, 0., false, Blank)
  
  ======================================================================
  ../examples/arduino/bala2-regex/balance_regex.tpe
  ======================================================================
  === Run 1 ===
  return (2.8812, 0., 0., 0., 0.)
  
  === Run 2 ===
  return ((0.0274756773391, -3.32667600333, 0.14970042015, 0., 0.), 
          0.301752548292)
  
  === Run 3 ===
  return ((89.6343246251, 0., 0., 0., 0.), 0.)
  
  ======================================================================
  ../examples/arduino/bala2-remote/balance_remote.tpe
  ======================================================================
  === Run 1 ===
  return (2.8812, 0., 0., 0., 0.)
  
  ======================================================================
  ../examples/arduino/bala2/balance.tpe
  ======================================================================
  === Run 1 ===
  return (2.8812, 0., 0., 0., 0.)
  
  ======================================================================
  ../examples/arduino/calibrated/calibrated.tpe
  ======================================================================
  === Run 1 ===
  return (0., 0.)
  
  === Run 2 ===
  return ()
  
  ======================================================================
  ../examples/arduino/fall/fall.tpe
  ======================================================================
  === Run 1 ===
  return 0
  
  ======================================================================
  ../examples/arduino/level/level.tpe
  ======================================================================
  === Run 1 ===
  return (NoReference, 0, 100, false)
  
  === Run 2 ===
  return (Offsets (0., -0.))
  
  ======================================================================
  ../examples/arduino/peak/peak.tpe
  ======================================================================
  === Run 1 ===
  return 2.7
  
  === Run 2 ===
  return ()
  
  ======================================================================
  ../examples/arduino/starter/starter.tpe
  ======================================================================
  === Run 1 ===
  return ((0, 0, 0, 1, 0), (1, 0))
  
  === Run 2 ===
  return ((0, 1, 1, 0, 0), (1, 2))
  
  ======================================================================
  ../examples/arduino/steps/steps.tpe
  ======================================================================
  === Run 1 ===
  return (2, 5, 2875, 400)
  
  ======================================================================
  ../examples/arduino/tilt/tilt.tpe
  ======================================================================
  === Run 1 ===
  return 0.
  
  === Run 2 ===
  return ()
  
  ======================================================================
  ../examples/arduino/wheels/wheels.tpe
  ======================================================================
  === Run 1 ===
  return 2.94
  
  === Run 2 ===
  return (0., 0.)
  
  ======================================================================
  ../examples/basics/basic_unbox.tpe
  ======================================================================
  File "../examples/basics/basic_unbox.tpe", lines 24-25, characters 4-9:
  24 |     unbox boxed as (l, r) in
           ^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `boxed` is unboxed with grade `4` accumulated since it was bound, which is not below its box grade `5`
    File "../examples/basics/basic_unbox.tpe", line 22, characters 15-20:
    22 |     box 5 x as boxed in
                        ^^^^^
    `boxed` is bound here
    File "../examples/basics/basic_unbox.tpe", line 23, characters 4-11:
    23 |     delay 4;                     (* <- insufficient delay *)
             ^^^^^^^
    grade `4` accumulates here (delay)
    Note: the resource inequality `4 >= 5` does not hold
  
  File "../examples/basics/basic_unbox.tpe", line 34, characters 17-28:
  34 |     let (l, r) = unbox boxed in
                        ^^^^^^^^^^^
  Typing error: Variable `boxed` is unboxed with grade `4` accumulated since it was bound, which is not below its box grade `5`
    File "../examples/basics/basic_unbox.tpe", line 32, characters 8-13:
    32 |     let boxed = box 5 x in
                 ^^^^^
    `boxed` is bound here
    File "../examples/basics/basic_unbox.tpe", line 33, characters 4-11:
    33 |     delay 4;                       (* <- insufficient delay *)
             ^^^^^^^
    grade `4` accumulates here (delay)
    Note: the resource inequality `4 >= 5` does not hold
  ======================================================================
  ../examples/basics/delay.tpe
  ======================================================================
  === Run 1 ===
  return 0
  State: []
  
  === Run 2 ===
  return 0
  State: [
    3
  ]
  
  === Run 3 ===
  return 1
  State: [
    9,
    2,
    3
  ]
  
  === Run 4 ===
  return 11
  State: [
    5
  ]
  
  === Run 5 ===
  return 11
  State: [
    10,
    5
  ]
  
  === Run 6 ===
  return ()
  State: [
    24,
    23,
    42
  ]
  
  === Run 7 ===
  return 11
  State: [
    5,
    { resource_0 ↦ 11 # 3 },
    3
  ]
  
  === Run 8 ===
  return 42
  State: [
    { resource_0 ↦ 42 # 3 },
    5
  ]
  
  === Run 9 ===
  return (142, "test")
  State: [
    2,
    10,
    { resource_0 ↦ (43, 99, "test") # 3 },
    3
  ]
  
  ======================================================================
  ../examples/basics/eternal_types.tpe
  ======================================================================
  === Run 1 ===
  return 5
  State: [
    1
  ]
  
  === Run 2 ===
  return (Stamp 1)
  State: [
    1
  ]
  
  === Run 3 ===
  return Tag
  State: [
    1
  ]
  
  === Run 4 ===
  return 5
  State: [
    2
  ]
  
  === Run 5 ===
  return (fun () ↦ return ())
  State: []
  
  === Run 6 ===
  return 2
  State: [
    { resource_1 ↦ <fun> # 1 }
  ]
  
  === Run 7 ===
  return (Stamp 42)
  State: [
    3
  ]
  
  === Run 8 ===
  return (Ticket Token)
  State: []
  
  ======================================================================
  ../examples/basics/fold_over_boxes.tpe
  ======================================================================
  === Run 1 ===
  return 55
  State: [
    { resource_0 ↦ 25 # 3,
      resource_1 ↦ 16 # 3,
      resource_2 ↦ 9 # 3,
      resource_3 ↦ 4 # 3,
      resource_4 ↦ 1 # 3,
      resource_5 ↦ <fun> # 10,
      resource_6 ↦ <fun> # 10,
      resource_7 ↦ <fun> # 10,
      resource_8 ↦ <fun> # 10,
      resource_9 ↦ <fun> # 10,
      resource_10 ↦ <fun> # 10
    },
    12
  ]
  
  ======================================================================
  ../examples/basics/nat.tpe
  ======================================================================
  === Run 1 ===
  return 42
  State: []
  
  ======================================================================
  ../examples/basics/operations.tpe
  ======================================================================
  ======================================================================
  ../examples/basics/recursion.tpe
  ======================================================================
  === Run 1 ===
  return (3628800, 55, 120)
  State: []
  
  ======================================================================
  ../examples/basics/toplevel.tpe
  ======================================================================
  === Run 1 ===
  return ((Right 5)::(Left "test")::[])
  State: []
  
  ======================================================================
  ../examples/counts/rate_limits.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: []
  
  === Run 2 ===
  return (Token "bob")
  State: [
    { resource_0 ↦ Token "bob" # (Request, 2) }
  ]
  
  ======================================================================
  ../examples/handlers/3d_printing.tpe
  ======================================================================
  === Run 1 ===
  return (Complete (UvCured (Cooled (Fresh (Model "Sword")))), 
          Complete (UvCured (Cooled (Fresh (Model "Hammer")))))
  State: [
    { resource_1 ↦ <fun> # 7 },
    9,
    { resource_2 ↦ Fresh (Model "Sword") # 5, resource_4 ↦ <fun> # 7 },
    9,
    { resource_5 ↦ Fresh (Model "Hammer") # 5, resource_7 ↦ <fun> # 5 },
    6,
    { resource_9 ↦ <fun> # 5 },
    6
  ]
  
  ======================================================================
  ../examples/handlers/lower_bound.tpe
  ======================================================================
  === Run 1 ===
  return 48
  State: [
    { resource_1 ↦ <fun> # 71 },
    80
  ]
  
  === Run 2 ===
  return 23
  State: [
    { resource_1 ↦ <fun> # 71 },
    74
  ]
  
  === Run 3 (unhandled operation) ===
  perform Set 42 (op_var.
    (return op_var;
     let y = perform Get () (op_var. return op_var) in
     let b = (+) 45 in
     b y))
  
  ======================================================================
  ../examples/handlers/nested.tpe
  ======================================================================
  === Run 1 ===
  return 7
  State: [
    { resource_1 ↦ <fun> # 2, resource_3 ↦ <fun> # 3 },
    4
  ]
  
  ======================================================================
  ../examples/handlers/nested_reject.tpe
  ======================================================================
  File "../examples/handlers/nested_reject.tpe", lines 29-31, characters 13-24:
  29 |            | Op2 q k' ->
                    ^^^^^^^^^^^
  Typing error: For every grade `ε_Op2` the continuation `k'` may have, the case for `Op2` must have a grade matching `3 · ε_Op2`, but its grade `4` does not
    File "../examples/handlers/nested_reject.tpe", line 13, characters 0-32:
    13 | operation Op2 : unit ~> unit # 3
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    operation `Op2` is declared here
    File "../examples/handlers/nested_reject.tpe", line 29, characters 19-21:
    29 |            | Op2 q k' ->
                            ^^
    `k'` may have any grade `ε_Op2`
    Note: the effect inequality `∀ε_Op2. 4 >= 3 · ε_Op2` does not hold: for `ε_Op2 = 2` it becomes `4 >= 5`
  ======================================================================
  ../examples/handlers/upper_bound.tpe
  ======================================================================
  === Run 1 ===
  return 45
  State: [
    { resource_1 ↦ <fun> # 71 },
    10
  ]
  
  === Run 2 ===
  return 0
  State: [
    { resource_1 ↦ <fun> # 71 }
  ]
  
  === Run 3 ===
  return 46
  State: [
    { resource_1 ↦ <fun> # 71 }
  ]
  
  === Run 4 ===
  return 42
  State: [
    { resource_1 ↦ <fun> # 71 },
    10
  ]
  
  ======================================================================
  ../examples/introduction/sensor_reading.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    { resource_1 ↦ <fun> # (0, 0.5] },
    [0.1, 0.1],
    { resource_2 ↦ Sample 42 # [5, 10) },
    [7, 7],
    [0.5, 0.5],
    [1.5, 1.5]
  ]
  
  ======================================================================
  ../examples/introduction/stale_calibration.tpe
  ======================================================================
  === Run 1 (unhandled operation) ===
  perform Calibrate () (op_var.
    (let calibration = return op_var in
     perform HighwayMode () (op_var. return op_var);
     let reading = perform Scan () (op_var. return op_var) in
     unbox calibration as offset in
     unbox reading as sample in
     let angle = perform AngleOf sample (op_var. return op_var) in
     perform SetOffsetAngle (offset, angle) (op_var. return op_var)))
  
  ======================================================================
  ../examples/levels/flow.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: []
  
  === Run 2 ===
  return ()
  State: [
    { resource_0 ↦ "draft" # (Low, (Board, Low)) }
  ]
  
  ======================================================================
  ../examples/levels/security.tpe
  ======================================================================
  === Run 1 ===
  return "weather: sunny"
  State: [
    { resource_0 ↦ Channel "public" # Low }
  ]
  
  === Run 2 ===
  return "launch code: 0000"
  State: [
    { resource_0 ↦ Channel "classified" # High }
  ]
  
  ======================================================================
  ../examples/levels/staged_release.tpe
  ======================================================================
  === Run 1 ===
  return (Stage ((Host "web-1")::[], 
                 Stage ((Host "web-2")::(Host "web-3")::[], 
                        Stage ((Host "db-1")::(Host "db-2")::[], Empty))))
  State: []
  
  === Run 2 ===
  return 7
  State: []
  
  === Run 3 ===
  return (Completed 5, 
          (Built 7)::(Approved 7)::(Observed 0)::(Installed (Host "web-1"))::(Observed 0)::(Installed (Host "web-2"))::(Installed (Host "web-3"))::(Observed 0)::(Installed (Host "db-1"))::(Installed (Host "db-2"))::(Retried (Host "db-2"))::(Observed 0)::(Observed 0)::(Observed 0)::[])
  State: [
    { resource_0 ↦ probe_with_two_retries # (0, High) },
    (8, Low),
    { resource_2 ↦ <fun> # (0, Low) },
    (1, Low),
    { resource_3 ↦ Release (Artefact ("api", 7)) # (8, Low),
      resource_5 ↦ <fun> # (0, Low)
    },
    (12, Low),
    { resource_7 ↦ <fun> # (0, Low), resource_9 ↦ <fun> # (4, Low) },
    (4, Low),
    { resource_11 ↦ <fun> # (0, Low), resource_13 ↦ <fun> # (1, Low) },
    (1, Low),
    { resource_14 ↦ Release (Artefact ("api", 7)) # (10, Low) },
    (12, Low),
    { resource_16 ↦ <fun> # (0, Low), resource_18 ↦ <fun> # (4, Low) },
    (4, Low),
    { resource_20 ↦ <fun> # (0, Low), resource_22 ↦ <fun> # (1, Low) },
    (1, Low),
    { resource_24 ↦ <fun> # (4, Low) },
    (4, Low),
    { resource_26 ↦ <fun> # (0, Low), resource_28 ↦ <fun> # (1, Low) },
    (1, Low),
    { resource_29 ↦ Release (Artefact ("api", 7)) # (10, Low) },
    (12, Low),
    { resource_31 ↦ <fun> # (0, Low), resource_33 ↦ <fun> # (4, Low) },
    (4, Low),
    { resource_35 ↦ <fun> # (0, Low), resource_37 ↦ <fun> # (1, Low) },
    (1, Low),
    { resource_39 ↦ <fun> # (4, Low) },
    (4, Low),
    { resource_41 ↦ <fun> # (0, Low), resource_43 ↦ <fun> # (1, Low) },
    (1, Low),
    { resource_45 ↦ <fun> # (0, Low) },
    (3, Low),
    { resource_47 ↦ <fun> # (1, Low) },
    (1, Low),
    { resource_48 ↦ Release (Artefact ("api", 7)) # (10, Low) },
    (12, Low),
    { resource_50 ↦ <fun> # (0, Low) },
    (12, Low),
    { resource_52 ↦ <fun> # (0, Low) },
    (12, Low),
    { resource_54 ↦ <fun> # (0, Low) }
  ]
  
  === Run 4 ===
  return (HostFailed (Host "db-2", 5), 
          (Built 7)::(Approved 7)::(Observed 0)::(Installed (Host "web-1"))::(Observed 0)::(Installed (Host "web-2"))::(Installed (Host "web-3"))::(Observed 0)::(Installed (Host "db-1"))::(Installed (Host "db-2"))::(Reverted (Host "db-2"))::(Reverted (Host "db-1"))::(Reverted (Host "web-3"))::(Reverted (Host "web-2"))::(Reverted (Host "web-1"))::[])
  State: [
    { resource_0 ↦ probe_without_retries # (0, High) },
    (8, Low),
    { resource_2 ↦ <fun> # (0, Low) },
    (1, Low),
    { resource_3 ↦ Release (Artefact ("api", 7)) # (8, Low),
      resource_5 ↦ <fun> # (0, Low)
    },
    (12, Low),
    { resource_7 ↦ <fun> # (0, Low), resource_9 ↦ <fun> # (4, Low) },
    (4, Low),
    { resource_11 ↦ <fun> # (0, Low) },
    (1, Low),
    { resource_12 ↦ Release (Artefact ("api", 7)) # (10, Low) },
    (12, Low),
    { resource_14 ↦ <fun> # (0, Low), resource_16 ↦ <fun> # (4, Low) },
    (4, Low),
    { resource_18 ↦ <fun> # (0, Low) },
    (1, Low),
    { resource_20 ↦ <fun> # (4, Low) },
    (4, Low),
    { resource_22 ↦ <fun> # (0, Low) },
    (1, Low),
    { resource_23 ↦ Release (Artefact ("api", 7)) # (10, Low) },
    (12, Low),
    { resource_25 ↦ <fun> # (0, Low), resource_27 ↦ <fun> # (4, Low) },
    (4, Low),
    { resource_29 ↦ <fun> # (0, Low) },
    (1, Low),
    { resource_31 ↦ <fun> # (4, Low) },
    (4, Low),
    { resource_33 ↦ <fun> # (0, Low) },
    (1, Low),
    (3, Low),
    { resource_35 ↦ <fun> # (0, Low) },
    (3, Low),
    { resource_37 ↦ <fun> # (0, Low) },
    (3, Low),
    { resource_39 ↦ <fun> # (0, Low) },
    (3, Low),
    { resource_41 ↦ <fun> # (0, Low) },
    (3, Low),
    { resource_43 ↦ <fun> # (0, Low) }
  ]
  
  === Run 5 ===
  return (ErrorsObserved (1, 1), 
          (Built 7)::(Approved 7)::(Observed 0)::(Installed (Host "cache-1"))::(Observed 1)::(Reverted (Host "cache-1"))::[])
  State: [
    { resource_0 ↦ probe_with_two_retries # (0, High) },
    (8, Low),
    { resource_2 ↦ <fun> # (0, Low) },
    (1, Low),
    { resource_3 ↦ Release (Artefact ("api", 7)) # (8, Low),
      resource_5 ↦ <fun> # (0, Low)
    },
    (12, Low),
    { resource_7 ↦ <fun> # (0, Low), resource_9 ↦ <fun> # (4, Low) },
    (4, Low),
    { resource_11 ↦ <fun> # (0, Low), resource_13 ↦ <fun> # (1, Low) },
    (1, Low),
    { resource_14 ↦ Release (Artefact ("api", 7)) # (10, Low) },
    (12, Low),
    { resource_16 ↦ <fun> # (0, Low) },
    (3, Low),
    { resource_18 ↦ <fun> # (0, Low) }
  ]
  
  === Run 6 ===
  return (Completed 2, 
          (Built 7)::(Approved 7)::(Observed 0)::(Installed (Host "web-1"))::(Observed 0)::(Installed (Host "db-3"))::(Retried (Host "db-3"))::(Retried (Host "db-3"))::(Reverted (Host "db-3"))::(Reverted (Host "web-1"))::(HotfixFetched 8)::(Built 8)::(Approved 8)::(Observed 0)::(Installed (Host "web-1"))::(Observed 0)::(Installed (Host "db-3"))::(Observed 0)::(Observed 0)::(Observed 0)::[])
  State: [
    { resource_0 ↦ probe_with_two_retries # (0, High) },
    (8, Low),
    { resource_2 ↦ <fun> # (0, Low) },
    (1, Low),
    { resource_3 ↦ Release (Artefact ("api", 7)) # (8, Low),
      resource_5 ↦ <fun> # (0, Low)
    },
    (12, Low),
    { resource_7 ↦ <fun> # (0, Low), resource_9 ↦ <fun> # (4, Low) },
    (4, Low),
    { resource_11 ↦ <fun> # (0, Low), resource_13 ↦ <fun> # (1, Low) },
    (1, Low),
    { resource_14 ↦ Release (Artefact ("api", 7)) # (10, Low) },
    (12, Low),
    { resource_16 ↦ <fun> # (0, Low), resource_18 ↦ <fun> # (4, Low) },
    (4, Low),
    { resource_20 ↦ <fun> # (0, Low), resource_22 ↦ <fun> # (1, Low) },
    (1, Low),
    { resource_24 ↦ <fun> # (0, Low) },
    (3, Low),
    { resource_26 ↦ <fun> # (1, Low) },
    (1, Low),
    { resource_28 ↦ <fun> # (0, Low) },
    (3, Low),
    { resource_30 ↦ <fun> # (1, Low) },
    (1, Low),
    (3, Low),
    { resource_32 ↦ <fun> # (0, Low) },
    (3, Low),
    { resource_34 ↦ <fun> # (0, Low) },
    (3, Low),
    { resource_36 ↦ <fun> # (0, Low),
      resource_37 ↦ probe_with_two_retries # (0, High)
    },
    (8, Low),
    { resource_39 ↦ <fun> # (0, Low) },
    (1, Low),
    { resource_40 ↦ Release (Artefact ("hotfix", 8)) # (8, Low),
      resource_42 ↦ <fun> # (0, Low)
    },
    (12, Low),
    { resource_44 ↦ <fun> # (0, Low), resource_46 ↦ <fun> # (4, Low) },
    (4, Low),
    { resource_48 ↦ <fun> # (0, Low), resource_50 ↦ <fun> # (1, Low) },
    (1, Low),
    { resource_51 ↦ Release (Artefact ("hotfix", 8)) # (10, Low) },
    (12, Low),
    { resource_53 ↦ <fun> # (0, Low), resource_55 ↦ <fun> # (4, Low) },
    (4, Low),
    { resource_57 ↦ <fun> # (0, Low), resource_59 ↦ <fun> # (1, Low) },
    (1, Low),
    { resource_60 ↦ Release (Artefact ("hotfix", 8)) # (10, Low) },
    (12, Low),
    { resource_62 ↦ <fun> # (0, Low) },
    (12, Low),
    { resource_64 ↦ <fun> # (0, Low) },
    (12, Low),
    { resource_66 ↦ <fun> # (0, Low) }
  ]
  
  === Run 7 ===
  return (HostFailed (Host "db-3", 2))
  State: [
    { resource_0 ↦ probe_with_two_retries # (0, High) },
    (8, Low),
    (1, Low),
    { resource_1 ↦ Release (Artefact ("api", 7)) # (8, Low) },
    (12, Low),
    { resource_3 ↦ <fun> # (4, Low) },
    (4, Low),
    { resource_5 ↦ <fun> # (1, Low) },
    (1, Low),
    { resource_6 ↦ Release (Artefact ("api", 7)) # (10, Low) },
    (12, Low),
    { resource_8 ↦ <fun> # (4, Low) },
    (4, Low),
    { resource_10 ↦ <fun> # (1, Low) },
    (1, Low),
    (3, Low),
    { resource_12 ↦ <fun> # (1, Low) },
    (1, Low),
    (3, Low),
    { resource_14 ↦ <fun> # (1, Low) },
    (1, Low),
    (3, Low),
    (3, Low)
  ]
  
  === Run 8 ===
  return (Completed 5, "release notes")
  State: [
    { resource_0 ↦ "release notes" # (17, Low),
      resource_1 ↦ probe_with_two_retries # (0, High)
    },
    (8, Low),
    (1, Low),
    { resource_2 ↦ Release (Artefact ("api", 7)) # (8, Low) },
    (12, Low),
    { resource_4 ↦ <fun> # (4, Low) },
    (4, Low),
    { resource_6 ↦ <fun> # (1, Low) },
    (1, Low),
    { resource_7 ↦ Release (Artefact ("api", 7)) # (10, Low) },
    (12, Low),
    { resource_9 ↦ <fun> # (4, Low) },
    (4, Low),
    { resource_11 ↦ <fun> # (1, Low) },
    (1, Low),
    { resource_13 ↦ <fun> # (4, Low) },
    (4, Low),
    { resource_15 ↦ <fun> # (1, Low) },
    (1, Low),
    { resource_16 ↦ Release (Artefact ("api", 7)) # (10, Low) },
    (12, Low),
    { resource_18 ↦ <fun> # (4, Low) },
    (4, Low),
    { resource_20 ↦ <fun> # (1, Low) },
    (1, Low),
    { resource_22 ↦ <fun> # (4, Low) },
    (4, Low),
    { resource_24 ↦ <fun> # (1, Low) },
    (1, Low),
    (3, Low),
    { resource_26 ↦ <fun> # (1, Low) },
    (1, Low),
    { resource_27 ↦ Release (Artefact ("api", 7)) # (10, Low) },
    (12, Low),
    (12, Low),
    (12, Low)
  ]
  
  ======================================================================
  ../examples/levels/time_lower.tpe
  ======================================================================
  === Run 1 ===
  return (Report "quarterly figures")
  State: [
    (3, Low),
    { resource_0 ↦ Report "quarterly figures" # (3, Low) },
    (4, Low),
    (1, Low)
  ]
  
  === Run 2 ===
  return (Report "quarterly figures")
  State: [
    (3, Low),
    { resource_0 ↦ Report "quarterly figures" # (3, Low) },
    (3, Low),
    (2, Low),
    (1, Low)
  ]
  
  ======================================================================
  ../examples/levels/time_upper.tpe
  ======================================================================
  === Run 1 ===
  return "rows"
  State: [
    (1, Low),
    { resource_0 ↦ Token "alice" # (5, Low) },
    (3, Low),
    (1, Low)
  ]
  
  === Run 2 ===
  return "rows"
  State: [
    { resource_0 ↦ Token "bob" # (∞, Low) },
    (100, Low),
    (1, Low)
  ]
  
  ======================================================================
  ../examples/opentrons/beads.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    [2, 2],
    [5, 5],
    { resource_0 ↦ "beads" # [3, ∞) },
    [4, 4],
    [1, 1],
    [2, 2],
    [1, 1],
    { resource_1 ↦ "beads" # [2, 3] },
    [2, 2],
    [1, 1],
    [2, 2],
    { resource_2 ↦ "beads" # [3, ∞) },
    [3, 3],
    [2, 2]
  ]
  
  ======================================================================
  ../examples/opentrons/beads_reject.tpe
  ======================================================================
  File "../examples/opentrons/beads_reject.tpe", lines 36-37, characters 2-24:
  36 |   unbox drying as dried in
         ^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `drying` is unboxed with grade `[4, 5]` accumulated since it was bound, which is not below its box grade `[2, 3]`
    File "../examples/opentrons/beads_reject.tpe", line 33, characters 6-12:
    33 |   let drying = perform FinalWash beads in
               ^^^^^^
    `drying` is bound here
    File "../examples/opentrons/beads_reject.tpe", line 34, characters 2-9:
    34 |   delay 4;
           ^^^^^^^
    grade `[4, 4]` accumulates here (delay)
    File "../examples/opentrons/beads_reject.tpe", line 35, characters 2-25:
    35 |   perform MagnetOff beads;
           ^^^^^^^^^^^^^^^^^^^^^^^
    grade `[0, 1]` accumulates here (operation `MagnetOff`)
    Note: the resource inequality `[4, 5] <= [2, 3]` does not hold
  ======================================================================
  ../examples/opentrons/binding.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    2,
    1,
    3,
    1,
    2,
    1,
    2,
    1,
    2,
    1,
    3,
    2,
    1
  ]
  
  ======================================================================
  ../examples/opentrons/binding_reject.tpe
  ======================================================================
  File "../examples/opentrons/binding_reject.tpe", lines 42-47, characters 25-12:
  42 | let binding_late_wash () : unit # (Mix, [1, 2], [2, 5], [0, 5]) =
                                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{AddBeads; Mix; 2; FillWashPlate} · (Mix, [0, 0], [2, 5], [0, 5])`, which does not match its annotated grade `(Mix, [1, 2], [2, 5], [0, 5])`
    Note: the effect inequality `{AddBeads; Mix; 2; FillWashPlate} · (Mix, [0, 0], [2, 5], [0, 5]) <= (Mix, [1, 2], [2, 5], [0, 5])` does not hold
  ======================================================================
  ../examples/opentrons/cleanup.tpe
  ======================================================================
  === Run 1 ===
  return "beads"
  State: [
    { resource_1 ↦ <fun> # {AddBeads; [5, 10]; MagnetOn} },
    {!2},
    {!7},
    {!1},
    { resource_2 ↦ "beads" # {[3, 5]} },
    {!4},
    {!1},
    { resource_3 ↦ "beads" # {(AddEthanol; 1; RemoveEthanol)^2; [2, 3]},
      resource_5 ↦ <fun> # {AddEthanol; 1; RemoveEthanol}
    },
    {!1},
    {!1},
    {!2},
    { resource_7 ↦ <fun> # {AddEthanol; 1; RemoveEthanol} },
    {!1},
    {!1},
    {!2},
    {!3},
    { resource_9 ↦
        <fun>
        # {MagnetOff; AddBuffer; [2, 5]; MagnetOn; [3, 5]; Transfer}
    },
    {!1},
    {!1},
    {!3},
    {!1},
    {!4},
    {!2}
  ]
  
  ======================================================================
  ../examples/opentrons/cleanup_reject.tpe
  ======================================================================
  File "../examples/opentrons/cleanup_reject.tpe", line 40, characters 6-24:
  40 |       continue k with ()
             ^^^^^^^^^^^^^^^^^^
  Typing error: Variable `k` is unboxed with grade `{RemoveEthanol; !1; AddEthanol}` accumulated since it was bound, which is not below its box grade `{AddEthanol; 1; RemoveEthanol}`
    File "../examples/opentrons/cleanup_reject.tpe", line 36, characters 19-20:
    36 |   | EthanolWash () k ->
                            ^
    `k` is bound here
    File "../examples/opentrons/cleanup_reject.tpe", line 37, characters 6-30:
    37 |       perform RemoveEthanol ();
               ^^^^^^^^^^^^^^^^^^^^^^^^
    grade `{RemoveEthanol}` accumulates here (operation `RemoveEthanol`)
    File "../examples/opentrons/cleanup_reject.tpe", line 38, characters 6-13:
    38 |       delay 1;
               ^^^^^^^
    grade `{!1}` accumulates here (delay)
    File "../examples/opentrons/cleanup_reject.tpe", line 39, characters 6-27:
    39 |       perform AddEthanol ();
               ^^^^^^^^^^^^^^^^^^^^^
    grade `{AddEthanol}` accumulates here (operation `AddEthanol`)
    Note: the resource inequality `{RemoveEthanol; !1; AddEthanol} <= {AddEthanol; 1; RemoveEthanol}` does not hold
  ======================================================================
  ../examples/opentrons/contamination.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    (4, Low),
    { resource_0 ↦ Reagent "master mix" # (30, High) },
    (1, Low),
    { resource_1 ↦ Tip # (∞, Low) },
    (1, Low),
    (1, Low),
    (1, Low),
    { resource_2 ↦ Tip # (∞, Low) },
    (1, Low),
    (1, Low),
    { resource_3 ↦ Tip # (∞, Low) },
    (1, Low),
    (1, Low),
    { resource_4 ↦ Tip # (∞, Low) },
    (1, Low),
    (1, Low),
    { resource_5 ↦ Tip # (∞, Low) },
    (1, Low),
    (1, Low),
    (1, Low),
    (1, Low),
    (1, Low),
    { resource_6 ↦ Tip # (∞, Low) },
    (1, Low),
    (1, Low),
    { resource_7 ↦ Tip # (∞, Low) },
    (1, Low),
    (1, Low),
    { resource_8 ↦ Tip # (∞, Low) },
    (1, Low),
    (1, Low),
    { resource_9 ↦ Tip # (∞, Low) },
    (1, Low)
  ]
  
  ======================================================================
  ../examples/opentrons/contamination_reject.tpe
  ======================================================================
  File "../examples/opentrons/contamination_reject.tpe", lines 43-44, characters 2-25:
  43 |   unbox article_tip as t in
         ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `article_tip` is unboxed with grade `(1, High)` accumulated since it was bound, which is not below its box grade `(∞, Low)`
    File "../examples/opentrons/contamination_reject.tpe", line 40, characters 6-17:
    40 |   let article_tip = new_tip () in
               ^^^^^^^^^^^
    `article_tip` is bound here
    File "../examples/opentrons/contamination_reject.tpe", line 42, characters 2-27:
    42 |   perform AddArticle (t, 1);
           ^^^^^^^^^^^^^^^^^^^^^^^^^
    grade `(1, High)` accumulates here (operation `AddArticle`)
    File "../examples/opentrons/contamination_reject.tpe", lines 41-44, characters 2-25:
    41 |   unbox article_tip as t in
           ^^^^^^^^^^^^^^^^^^^^^^^^^
    the inequality goes through the unboxing of `article_tip` here
    File "../examples/opentrons/contamination_reject.tpe", line 40, characters 20-27:
    40 |   let article_tip = new_tip () in
                             ^^^^^^^
    the inequality goes through the type of `new_tip` here
    Note: the resource inequality `(1, High) <= (∞, Low)` does not hold
  ======================================================================
  ../examples/opentrons/elisa.tpe
  ======================================================================
  === Run 1 ===
  return 0
  State: [
    [2, 2],
    [1, 1],
    { resource_0 ↦ Reagent "detection antibody" # [0, 20] },
    [3, 3],
    [3, 3],
    [3, 3],
    [2, 2],
    { resource_1 ↦ "plate" # [60, ∞) },
    [65, 65],
    [3, 3],
    [1, 1],
    { resource_2 ↦ Developed "plate" # [15, 20] },
    [17, 17],
    [2, 2]
  ]
  
  ======================================================================
  ../examples/opentrons/elisa_reject.tpe
  ======================================================================
  File "../examples/opentrons/elisa_reject.tpe", lines 34-35, characters 2-24:
  34 |   unbox incubating as incubated in
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `incubating` is unboxed with grade `[30, 30]` accumulated since it was bound, which is not below its box grade `[60, ∞)`
    File "../examples/opentrons/elisa_reject.tpe", line 32, characters 6-16:
    32 |   let incubating = perform Detect (plate, antibody) in
               ^^^^^^^^^^
    `incubating` is bound here
    File "../examples/opentrons/elisa_reject.tpe", line 33, characters 2-10:
    33 |   delay 30;
           ^^^^^^^^
    grade `[30, 30]` accumulates here (delay)
    Note: the resource inequality `[30, 30] <= [60, ∞)` does not hold
  ======================================================================
  ../examples/opentrons/enzyme.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    1,
    1,
    4,
    1,
    1,
    1,
    1,
    4,
    1,
    1,
    1,
    1,
    4,
    1,
    1,
    1,
    1,
    4,
    1,
    1
  ]
  
  ======================================================================
  ../examples/opentrons/enzyme_reject.tpe
  ======================================================================
  File "../examples/opentrons/enzyme_reject.tpe", line 45, characters 2-7:
  45 |   round 1;
         ^^^^^
  Typing error: The effect inequality `(Cold, Cold, (Out, [0, 7])) · (Cold, Cold, (Out, [0, 7])) · (Cold, Cold, (Out, [0, 7])) · (Cold, Cold, (Out, [0, 7])) · (Cold, Cold, (Out, [0, 7])) <= (Cold, Cold, (Out, [0, 30]))` does not hold
    File "../examples/opentrons/enzyme_reject.tpe", lines 28-33, characters 0-25:
    28 | let round (plate : nat) : unit # (Cold, Cold, (Out, [0, 7])) =
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    `round` is defined here
    File "../examples/opentrons/enzyme_reject.tpe", lines 44-49, characters 19-9:
    44 | let set_up_five () : unit # (Cold, Cold, (Out, [0, 30])) =
                            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    the inequality goes through the annotation here
  ======================================================================
  ../examples/opentrons/purification.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    {!1.5},
    { resource_0 ↦ "beads" # {[5, 10]}, resource_1 ↦ "samples" # {[0, 40]} },
    {!7.5},
    {!0.5},
    { resource_2 ↦ "beads" # {[3, 5]} },
    {!4},
    {!1.5},
    { resource_3 ↦ "beads" # {AddEthanol; ![0.5, 1.5]} },
    {!0.75},
    {!1},
    {!1.5},
    { resource_4 ↦ "beads" # {AddEthanol; ![0.5, 1.5]; RemoveEthanol} },
    {!0.75},
    {!0.75},
    {!1.5},
    {!0.75},
    { resource_5 ↦ "beads" # {[3, 5]; MagnetOff} },
    {!3.5},
    {!0.5},
    {!1.5},
    { resource_6 ↦ "beads" # {[2, 5]; MagnetOn; [2, 5]} },
    {!3},
    {!0.5},
    {!2.5},
    { resource_7 ↦ <fun> # {Transfer} },
    {!1.5},
    { resource_8 ↦ "beads" # {[2, 5]} },
    {!3.5},
    {!1.5}
  ]
  
  ======================================================================
  ../examples/opentrons/purification_reject.tpe
  ======================================================================
  File "../examples/opentrons/purification_reject.tpe", lines 132-138, characters 2-30:
  132 |   unbox warm as warm_samples in
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `warm` is unboxed with grade `{!10; MagnetOn; !5; RemoveSupernatant; AddEthanol; !1; RemoveEthanol; AddEthanol; !0.75; RemoveEthanol; RemoveResidualEthanol; !5; MagnetOff; EluteDNA; !3; MagnetOn; !2.5}` accumulated since it was bound, which is not below its box grade `{[0, 40]}`
    File "../examples/opentrons/purification_reject.tpe", line 127, characters 25-29:
    127 |   box [0, 40] samples as warm in
                                   ^^^^
    `warm` is bound here
    File "../examples/opentrons/purification_reject.tpe", lines 129-130, characters 4-75:
    129 |     collect
              ^^^^^^^
    grade `{!10; MagnetOn; !5; RemoveSupernatant; AddEthanol; !1; RemoveEthanol; AddEthanol; !0.75; RemoveEthanol; RemoveResidualEthanol; !5; MagnetOff; EluteDNA; !3; MagnetOn; !2.5}` accumulates here (this computation)
    Note: the resource inequality `{!10; MagnetOn; !5; RemoveSupernatant; AddEthanol; !1; RemoveEthanol; AddEthanol; !0.75; RemoveEthanol; RemoveResidualEthanol; !5; MagnetOff; EluteDNA; !3; MagnetOn; !2.5} <= {[0, 40]}` does not hold
  
  File "../examples/opentrons/purification_reject.tpe", line 151, characters 34-44:
  151 |   let collected = collect (elute (final_wash (clear (separate binding)))) in
                                          ^^^^^^^^^^
  Typing error: The resource inequality `{AddEthanol; ![0.5, 1.5]; RemoveEthanol} <= {AddEthanol; ![0.5, 1.5]}` does not hold
    File "../examples/opentrons/purification_reject.tpe", lines 76-82, characters 0-31:
    76 | let final_wash (rinsing : [{AddEthanol; ![1/2, 3/2]; RemoveEthanol}]beads) =
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    `final_wash` is defined here
    File "../examples/opentrons/purification_reject.tpe", line 151, characters 46-51:
    151 |   let collected = collect (elute (final_wash (clear (separate binding)))) in
                                                        ^^^^^
    the inequality goes through the type of `clear` here
  
  File "../examples/opentrons/purification_reject.tpe", lines 171-173, characters 2-52:
  171 |   unbox soaking as beads in
          ^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `soaking` is unboxed with grade `{AddEthanol; MagnetOff; !0.5}` accumulated since it was bound, which is not below its box grade `{AddEthanol; ![0.5, 1.5]}`
    File "../examples/opentrons/purification_reject.tpe", line 167, characters 21-28:
    167 | let wash_off_magnet (soaking : [{AddEthanol; ![1/2, 3/2]}]beads) =
                               ^^^^^^^
    `soaking` is bound here
    File "../examples/opentrons/purification_reject.tpe", line 168, characters 2-23:
    168 |   perform AddEthanol ();
            ^^^^^^^^^^^^^^^^^^^^^
    grade `{AddEthanol}` accumulates here (operation `AddEthanol`)
    File "../examples/opentrons/purification_reject.tpe", line 169, characters 2-22:
    169 |   perform MagnetOff ();
            ^^^^^^^^^^^^^^^^^^^^
    grade `{MagnetOff}` accumulates here (operation `MagnetOff`)
    File "../examples/opentrons/purification_reject.tpe", line 170, characters 2-11:
    170 |   delay 1/2;
            ^^^^^^^^^
    grade `{!0.5}` accumulates here (delay)
    Note: the resource inequality `{AddEthanol; MagnetOff; !0.5} <= {AddEthanol; ![0.5, 1.5]}` does not hold
  ======================================================================
  ../examples/opentrons/reagents.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    [6, 6],
    { resource_0 ↦ Reagent "amplicon tagment mix" # [0, 30] },
    [2, 2],
    [1, 1],
    [2, 2],
    [6, 6],
    { resource_1 ↦ Reagent "neutralize tagment buffer" # [0, 30] },
    [6, 6],
    [2, 2]
  ]
  
  ======================================================================
  ../examples/opentrons/reagents_reject.tpe
  ======================================================================
  File "../examples/opentrons/reagents_reject.tpe", line 42, characters 23-63:
  42 |   let neutralization = perform Thaw "neutralize tagment buffer" in
                              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: The resource inequality `[35, 37] <= [0, 30]` does not hold
    Note: while matching `[[0, 30]]reagent` against `[[35, 37]]reagent`
  ======================================================================
  ../examples/opentrons/staggered.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    [1, 1],
    { resource_0 ↦ 1 # [12, 20] },
    [14, 14],
    [1, 1],
    { resource_1 ↦ 2 # [12, 20] },
    [2, 2],
    [13, 13],
    [1, 1],
    { resource_2 ↦ 3 # [12, 20] },
    [2, 2],
    [13, 13],
    [1, 1],
    { resource_3 ↦ 4 # [12, 20] },
    [2, 2],
    [14, 14],
    [2, 2]
  ]
  
  ======================================================================
  ../examples/opentrons/staggered_reject.tpe
  ======================================================================
  File "../examples/opentrons/staggered_reject.tpe", lines 37-38, characters 6-38:
  37 |       unbox fixing as previous in
             ^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `fixing` is unboxed with grade `[7, 9]` accumulated since it was bound, which is not below its box grade `[12, 20]`
    File "../examples/opentrons/staggered_reject.tpe", line 30, characters 42-48:
    30 | let rec stagger (columns : column list) ((fixing : [[12, 20]]column), (fixed : column)) : unit # [0, ∞) =
                                                   ^^^^^^
    `fixing` is bound here
    File "../examples/opentrons/staggered_reject.tpe", line 31, characters 2-21:
    31 |   perform Rinse fixed;
           ^^^^^^^^^^^^^^^^^^^
    grade `[1, 2]` accumulates here (operation `Rinse`)
    File "../examples/opentrons/staggered_reject.tpe", line 35, characters 6-13:
    35 |       delay 5;
               ^^^^^^^
    grade `[5, 5]` accumulates here (delay)
    File "../examples/opentrons/staggered_reject.tpe", line 36, characters 20-38:
    36 |       let started = perform Fix column in
                             ^^^^^^^^^^^^^^^^^^
    grade `[1, 2]` accumulates here (operation `Fix`)
    Note: the resource inequality `[7, 9] <= [12, 20]` does not hold
  ======================================================================
  ../examples/opentrons/stopread.tpe
  ======================================================================
  === Run 1 ===
  return (0, 0)
  State: [
    { resource_1 ↦ <fun> # [1, 2] },
    [2, 2],
    { resource_2 ↦ Plate "plate 1" # [0, 30], resource_4 ↦ <fun> # [1, 2] },
    [2, 2],
    { resource_5 ↦ Plate "plate 2" # [0, 30], resource_7 ↦ <fun> # [1, 2] },
    [1, 1],
    { resource_9 ↦ <fun> # [1, 2] },
    [1, 1]
  ]
  
  ======================================================================
  ../examples/opentrons/stopread_reject.tpe
  ======================================================================
  File "../examples/opentrons/stopread_reject.tpe", lines 45-49, characters 2-8:
  45 |   unbox first as first_plate in
         ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: Variable `first` is unboxed with grade `[31, 32]` accumulated since it was bound, which is not below its box grade `[0, 30]`
    File "../examples/opentrons/stopread_reject.tpe", line 42, characters 6-11:
    42 |   let first = perform Stop "plate 1" in
               ^^^^^
    `first` is bound here
    File "../examples/opentrons/stopread_reject.tpe", line 43, characters 2-10:
    43 |   delay 30;
           ^^^^^^^^
    grade `[30, 30]` accumulates here (delay)
    File "../examples/opentrons/stopread_reject.tpe", line 44, characters 15-37:
    44 |   let second = perform Stop "plate 2" in
                        ^^^^^^^^^^^^^^^^^^^^^^
    grade `[1, 2]` accumulates here (operation `Stop`)
    Note: the resource inequality `[31, 32] <= [0, 30]` does not hold
  ======================================================================
  ../examples/opentrons/washes.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    { resource_0 ↦ "beads" # {AddBeads; ![5, 10]; MagnetOn} },
    {!2},
    {!7},
    {!1},
    {!3},
    {!2},
    { resource_1 ↦
        "beads"
        # [{(Wash; ChangeTip)^[1, ∞); Wash; !≥2; ChangeTip}, {(Wash; ChangeTip)*; Wash; !≤3; ChangeTip}]
    },
    {!1},
    {!1},
    {!1},
    {!3},
    {!1},
    {!1},
    {!1},
    {!2},
    {!1},
    { resource_2 ↦ "eluates" # {![2, 5]} },
    {!3},
    {!2}
  ]
  
  ======================================================================
  ../examples/opentrons/washes_reject.tpe
  ======================================================================
  File "../examples/opentrons/washes_reject.tpe", lines 33-38, characters 4-31:
  33 |     : unit # {(Wash; ChangeTip)*} =
           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Typing error: This function's body has grade `{(Wash; (Wash; ChangeTip)*)?}`, which does not match its annotated grade `{(Wash; ChangeTip)*}`
    Note: the effect inequality `{(Wash; (Wash; ChangeTip)*)?} <= {(Wash; ChangeTip)*}` does not hold
    Note: the grade `[{Wash}, {(Wash; (Wash; ChangeTip)*)?}]` is below `{(Wash; (Wash; ChangeTip)*)?}` but not below `{(Wash; ChangeTip)*}`
  ======================================================================
  ../examples/regular/upper_bounds.tpe
  ======================================================================
  === Run 1 ===
  return "settled"
  State: [
    { resource_0 ↦ "settled" # {3; _*} },
    {4}
  ]
  
  ======================================================================
  ../examples/regular/upper_bounds_rational.tpe
  ======================================================================
  === Run 1 ===
  return "settled"
  State: [
    { resource_0 ↦ "settled" # {(1, ∞) & ~1*} },
    {0.5},
    {1.25}
  ]
  
  ======================================================================
  ../examples/regular_timed_ops/intervals.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    [{1}, {1}],
    [{4}, {4}],
    [{1}, {1}],
    [{2}, {2}]
  ]
  
  ======================================================================
  ../examples/regular_timed_ops/intervals_rational.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    [{0.75}, {0.75}],
    [{0.6}, {0.6}],
    [{0.75}, {0.75}]
  ]
  
  ======================================================================
  ../examples/regular_timed_ops/lower_bounds.tpe
  ======================================================================
  === Run 1 ===
  return (Part "gear")
  State: [
    { resource_0 ↦ Part "gear" # {Coat; 4} },
    {1},
    {4},
    {2}
  ]
  
  ======================================================================
  ../examples/regular_timed_ops/mail_session.tpe
  ======================================================================
  === Run 1 ===
  return (Checkpoint 5, 2)
  State: [
    { resource_0 ↦ Checkpoint 5 # {Login; (Fetch | Store)*; Logout} },
    {3},
    {1},
    {1},
    {1},
    {1},
    {1},
    {1},
    {1}
  ]
  
  === Run 2 ===
  return (Message (1, "Agenda", false))
  State: [
    {3},
    {1},
    {1}
  ]
  
  === Run 3 ===
  return 3
  State: [
    { resource_1 ↦ <fun> # {Login; (Fetch | Store)*; Logout} },
    {3},
    {1},
    {1},
    {1},
    {1},
    {1},
    {1}
  ]
  
  === Run 4 ===
  return 1
  State: [
    {1},
    {1},
    {1},
    {1}
  ]
  
  ======================================================================
  ../examples/regular_timed_ops/upper_bounds.tpe
  ======================================================================
  === Run 1 ===
  return (Reading 0)
  State: [
    { resource_0 ↦ Reading 0 # {2; Send; 6} },
    {2},
    {2},
    {5}
  ]
  
  ======================================================================
  ../examples/regular_timed_ops/upper_bounds_rational.tpe
  ======================================================================
  === Run 1 ===
  return (Reading 0)
  State: [
    { resource_0 ↦ Reading 0 # {[0, 1.5]; Send; 5.5} },
    {0.8},
    {1.5},
    {5}
  ]
  
  ======================================================================
  ../examples/regular_timed_rigid/intervals_rational.tpe
  ======================================================================
  === Run 1 ===
  return (Sample 3)
  State: [
    {!0.6},
    { resource_0 ↦
        3
        # [{(≥0; ReadImu; ReadClock)^3; ≥0}, {(≤2.5; ReadImu; ReadClock)*}]
    },
    {!1.75},
    {!0.6},
    {!0.02},
    {!2.25},
    {!0.6},
    {!0.02},
    {!1.5},
    {!0.6},
    {!0.02}
  ]
  
  ======================================================================
  ../examples/regular_timed_rigid/upper_bounds_rational.tpe
  ======================================================================
  === Run 1 ===
  return (4, Stamp 1200)
  State: [
    { resource_0 ↦ 4 # {Beep; ReadClock; ≤750} },
    {!≤0.1},
    {!≤0.02},
    {!≤312.5},
    {!≤0.6}
  ]
  
  ======================================================================
  ../examples/semidirect/mode_switch_costs.tpe
  ======================================================================
  === Run 1 ===
  return 5
  State: []
  
  === Run 2 (unhandled operation) ===
  perform Sample () (op_var.
    (let x = return op_var in
     perform RadioOn () (op_var. return op_var);
     perform Send x (op_var. return op_var);
     perform RadioOff () (op_var. return op_var);
     perform Sleep () (op_var. return op_var)))
  
  ======================================================================
  ../examples/semidirect/resource_levels.tpe
  ======================================================================
  === Run 1 (unhandled operation) ===
  perform Open "a" (op_var.
    ((let i = return op_var in
      let o = perform Open "a.bak" (op_var. return op_var) in
      let s = perform Read i (op_var. return op_var) in
      perform Write (o, s) (op_var. return op_var);
      perform Close o (op_var. return op_var);
      perform Close i (op_var. return op_var));
     copy ("b", "b.bak")))
  
  ======================================================================
  ../examples/semidirect/windowed_schedules.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    1,
    3,
    1,
    5,
    1,
    3,
    1,
    5,
    1,
    3,
    1,
    5
  ]
  
  === Run 2 ===
  return ()
  State: [
    1,
    { resource_0 ↦ 21 # [3, 5] },
    4,
    1
  ]
  
  ======================================================================
  ../examples/time/3d_printing.tpe
  ======================================================================
  === Run 1 ===
  return (Complete (UvCured (Cooled (Fresh (Model "Sword")))), 
          Complete (UvCured (Cooled (Fresh (Model "Hammer")))))
  State: [
    8,
    { resource_0 ↦ Fresh (Model "Sword") # 5 },
    8,
    { resource_1 ↦ Fresh (Model "Hammer") # 5 },
    6,
    6
  ]
  
  === Run 2 ===
  return (Complete (UvCured (Cooled (Fresh (Model "Sword")))), 
          Complete (UvCured (Cooled (Fresh (Model "Hammer")))))
  State: [
    8,
    { resource_0 ↦ Fresh (Model "Sword") # 5 },
    8,
    { resource_1 ↦ Fresh (Model "Hammer") # 5 },
    6,
    6
  ]
  
  === Run 3 ===
  return (Complete (UvCured (Cooled (Fresh (Model "Sword")))), 
          Complete (UvCured (Cooled (Fresh (Model "Hammer")))))
  State: [
    8,
    { resource_0 ↦ Fresh (Model "Sword") # 5 },
    8,
    { resource_1 ↦ Fresh (Model "Hammer") # 5 },
    6,
    6
  ]
  
  === Run 4 ===
  return (Complete (UvCured (Cooled (Fresh (Model "Sword")))), 
          Complete (UvCured (Cooled (Fresh (Model "Hammer")))))
  State: [
    8,
    { resource_0 ↦ Fresh (Model "Sword") # 5 },
    8,
    { resource_1 ↦ Fresh (Model "Hammer") # 5 },
    6,
    6
  ]
  
  ======================================================================
  ../examples/time/intervals.tpe
  ======================================================================
  === Run 1 ===
  return 2
  State: [
    { resource_0 ↦ 1 # [1, 4] },
    [1, 1],
    [2, 2]
  ]
  
  === Run 2 ===
  return 1
  State: [
    { resource_0 ↦ 1 # [1, 4] },
    [1, 1],
    [2, 2]
  ]
  
  === Run 3 ===
  return 4
  State: [
    { resource_0 ↦ 1 # [1, 4] },
    [1, 1],
    [2, 2]
  ]
  
  === Run 4 ===
  return 8
  State: [
    { resource_0 ↦ 1 # [1, 4] },
    [1, 1],
    [2, 2]
  ]
  
  === Run 5 ===
  return 15
  State: [
    { resource_0 ↦ 7 # [2, 5], resource_1 ↦ 1 # [1, 4] },
    [1, 1],
    [2, 2]
  ]
  
  === Run 6 ===
  return 1
  State: [
    { resource_0 ↦ 1 # [1, 4] },
    [4, 4]
  ]
  
  ======================================================================
  ../examples/time/intervals_rational.tpe
  ======================================================================
  === Run 1 ===
  return 500
  State: [
    { resource_0 ↦ 500 # [4, 6] },
    [4.25, 4.25],
    [0.375, 0.375]
  ]
  
  === Run 2 ===
  return 25
  State: [
    { resource_0 ↦ 25 # (4, 6] },
    [4.5, 4.5],
    [0.375, 0.375]
  ]
  
  === Run 3 ===
  return 72
  State: [
    { resource_0 ↦ 72 # [1, 1] },
    [1/3, 1/3],
    [1/3, 1/3],
    [1/3, 1/3]
  ]
  
  ======================================================================
  ../examples/time/upper_bounds.tpe
  ======================================================================
  === Run 1 ===
  return 1
  State: [
    { resource_0 ↦ 1 # 3 },
    1,
    2
  ]
  
  === Run 2 ===
  return 1
  State: [
    { resource_0 ↦ 1 # 3 },
    2
  ]
  
  ======================================================================
  ../examples/traces/upper_bounds.tpe
  ======================================================================
  === Run 1 ===
  return "closed"
  State: [
    { resource_0 ↦ "closed" # {3 | 4} },
    {3}
  ]
  
  ======================================================================
  ../examples/traces/upper_bounds_rational.tpe
  ======================================================================
  === Run 1 ===
  return "ready"
  State: [
    { resource_0 ↦ "ready" # {1.5 | 2.5} },
    {1.5}
  ]
  
  ======================================================================
  ../examples/traces_timed_ops/3d_printing.tpe
  ======================================================================
  === Run 1 ===
  return (Mounted (Printed (Cooled (Extruded (Heated (Model "Sword"))))))
  State: [
    [{1}, {1}],
    { resource_0 ↦ Epoxy # [{8}, {11}],
      resource_2 ↦ <fun> # [{Heat; Extrude; Cool}, {Heat; Extrude; Cool}]
    },
    [{1}, {1}],
    [{4}, {4}],
    { resource_3 ↦ Extruded (Heated (Model "Sword")) # [{2}, {2}] },
    [{2}, {2}],
    { resource_4 ↦
        Printed (Cooled (Extruded (Heated (Model "Sword"))))
        # [{2}, {8}]
    },
    [{2}, {2}],
    [{1}, {1}]
  ]
  
  === Run 2 ===
  return ("Sword #1", Printed (Cooled (Extruded (Heated (Model "Sword")))))
  State: [
    { resource_1 ↦ <fun> # [{Heat; Extrude; Cool}, {Heat; Extrude; Cool}] },
    [{1}, {1}],
    [{4}, {4}],
    { resource_2 ↦ Extruded (Heated (Model "Sword")) # [{2}, {2}] },
    [{2}, {2}],
    { resource_3 ↦
        Printed (Cooled (Extruded (Heated (Model "Sword"))))
        # [{2}, {8}]
    },
    [{4}, {4}]
  ]
  
  === Run 3 ===
  return (Model "Sword")
  State: [
    [{1}, {1}]
  ]
  
  === Run 4 ===
  return Epoxy
  State: []
  
  ======================================================================
  ../examples/traces_timed_ops/intervals.tpe
  ======================================================================
  === Run 1 ===
  return (Mounted (Printed (Cooled (Extruded (Heated (Model "Sword"))))))
  State: [
    [{1}, {1}],
    { resource_0 ↦ Epoxy # [{8}, {11}],
      resource_2 ↦ <fun> # [{Heat; Extrude; Cool}, {Heat; Extrude; Cool}]
    },
    [{1}, {1}],
    [{4}, {4}],
    { resource_3 ↦ Extruded (Heated (Model "Sword")) # [{2}, {2}] },
    [{2}, {2}],
    { resource_4 ↦
        Printed (Cooled (Extruded (Heated (Model "Sword"))))
        # [{2}, {8}]
    },
    [{2}, {2}],
    [{1}, {1}]
  ]
  
  ======================================================================
  ../examples/traces_timed_ops/intervals_rational.tpe
  ======================================================================
  === Run 1 ===
  return ()
  State: [
    [{0.75}, {0.75}],
    [{0.5}, {0.5}],
    [{1.75}, {1.75}]
  ]
  
  ======================================================================
  ../examples/traces_timed_ops/lower_bounds.tpe
  ======================================================================
  === Run 1 ===
  return (Mounted (Printed (Cooled (Extruded (Heated (Model "Sword"))))))
  State: [
    {1},
    { resource_0 ↦ Epoxy # {8}, resource_2 ↦ <fun> # {Heat; Extrude; Cool} },
    {1},
    {4},
    { resource_3 ↦ Extruded (Heated (Model "Sword")) # {2} },
    {2},
    { resource_4 ↦ Printed (Cooled (Extruded (Heated (Model "Sword")))) # {2} },
    {2},
    {1}
  ]
  
  ======================================================================
  ../examples/traces_timed_ops/upper_bounds.tpe
  ======================================================================
  === Run 1 ===
  return (Receipt "telemetry")
  State: [
    { resource_0 ↦ Receipt "telemetry" # {7},
      resource_2 ↦ <fun> # {Tx | Tx; Tx}
    },
    {2},
    {2}
  ]
  
