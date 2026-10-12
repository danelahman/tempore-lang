The timelines of runs printed by --timeline: the delays, the calls of
operations performed by their default implementations with their durations,
and the resources boxed and unboxed with their box grades.

Values boxed for time intervals, the times plain numbers.

  $ ../tempore --grades time-interval --timeline ../examples/time/intervals.tpe
  === Run 1 ===
  return 1
  State: [
    { resource_0 ↦ 1 # [1, 4] },
    [1, 1],
    [2, 2]
  ]
  
  Timeline
  Run  Start  Event    Time  Grade
  1    0      box r          [1, 4]
  1    0      delay    1
  1    1      delay    2
  1    3      unbox r        [1, 4]
  Run 1 returned 1 at 3.
  
  === Run 2 ===
  return 1
  State: [
    { resource_0 ↦ 1 # [1, 4] },
    [1, 1],
    [2, 2]
  ]
  
  Timeline
  Run  Start  Event    Time  Grade
  2    3      box r          [1, 4]
  2    3      delay    1
  2    4      delay    2
  2    6      unbox r        [1, 4]
  Run 2 returned 1 at 6.
  
  === Run 3 ===
  return 4
  State: [
    { resource_0 ↦ 1 # [1, 4] },
    [1, 1],
    [2, 2]
  ]
  
  Timeline
  Run  Start  Event    Time  Grade
  3    6      box r          [1, 4]
  3    6      delay    1
  3    7      delay    2
  3    9      unbox r        [1, 4]
  Run 3 returned 4 at 9.
  
  === Run 4 ===
  return 8
  State: [
    { resource_0 ↦ 1 # [1, 4] },
    [1, 1],
    [2, 2]
  ]
  
  Timeline
  Run  Start  Event    Time  Grade
  4    9      box r          [1, 4]
  4    9      delay    1
  4    10     delay    2
  4    12     unbox r        [1, 4]
  Run 4 returned 8 at 12.
  
  === Run 5 ===
  return 15
  State: [
    { resource_0 ↦ 7 # [2, 5], resource_1 ↦ 1 # [1, 4] },
    [1, 1],
    [2, 2]
  ]
  
  Timeline
  Run  Start  Event     Time  Grade
  5    12     box x'          [2, 5]
  5    12     box r           [1, 4]
  5    12     delay     1
  5    13     delay     2
  5    15     unbox r         [1, 4]
  5    15     unbox x'        [2, 5]
  Run 5 returned 15 at 15.
  
  === Run 6 ===
  return 1
  State: [
    { resource_0 ↦ 1 # [1, 4] },
    [4, 4]
  ]
  
  Timeline
  Run  Start  Event    Time  Grade
  6    15     box r          [1, 4]
  6    15     delay    4
  6    19     unbox r        [1, 4]
  Run 6 returned 1 at 19.
  

Continuations boxed by nested handlers, named after their operations.

  $ ../tempore --grades time-lower-bound --timeline ../examples/handlers/nested.tpe
  === Run 1 ===
  return 7
  State: [
    { resource_1 ↦ fun op_var ↦ handle
                                  return op_var;
                                  return 7
                                with h # 2,
      resource_3 ↦
        fun op_var ↦
          handle
            return op_var;
            return ()
          with handler
               | return y ↦ return y
               | Op2 (q, k') ↦
                       delay 3 (return ());
                       unbox k' as cont_var in
                       cont_var ()
        # 3
    },
    3
  ]
  
  Timeline
  Run  Start  Event            Time  Grade
  1    0      box k of Op1           2
  1    0      box k' of Op2          3
  1    0      delay            3
  1    3      unbox k' of Op2        3
  1    3      unbox k of Op1         2
  Run 1 returned 7 at 3.
  

Channels boxed at security levels, whose delays are unit grades.

  $ ../tempore --grades security-levels --timeline ../examples/levels/security.tpe
  === Run 1 ===
  return "weather: sunny"
  State: [
    { resource_0 ↦ Channel "public" # Low }
  ]
  
  Timeline
  Run  Start  Event       Time  Grade
  1    0      box c             Low
  1    0      ReadPublic  0
  1    0      delay       3
  1    3      unbox c           Low
  1    3      Post        0
  Run 1 returned "weather: sunny" at 3.
  
  === Run 2 ===
  return "launch code: 0000"
  State: [
    { resource_0 ↦ Channel "classified" # High }
  ]
  
  Timeline
  Run  Start  Event       Time  Grade
  2    3      box c             High
  2    3      ReadSecret  0
  2    3      unbox c           High
  2    3      Post        0
  Run 2 returned "launch code: 0000" at 3.
  

The ELISA protocol, interpreted, its times in minutes.

  $ ../tempore --grades time-interval --timeline --time-unit minutes ../examples/opentrons/elisa.tpe
  === Run 1 ===
  return 0
  State: [
    [2, 2],
    [1, 1],
    { resource_0 ↦ "detection antibody" # [0, 20] },
    [3, 3],
    [3, 3],
    [3, 3],
    [2, 2],
    { resource_1 ↦ "plate" # [60, ∞) },
    [60, 60],
    [3, 3],
    [1, 1],
    { resource_2 ↦ "plate" # [15, 20] },
    [15, 15],
    [1, 1]
  ]
  
  Timeline
  Run  Start   Event             Time    Grade
  1    0 min   AddSample         2 min
  1    2 min   Dilute            1 min
  1    3 min   · box antibody            [0, 20]
  1    3 min   Wash              3 min
  1    6 min   Wash              3 min
  1    9 min   Wash              3 min
  1    12 min  unbox antibody            [0, 20]
  1    12 min  Detect            2 min
  1    14 min  · box incubating          [60, ∞)
  1    14 min  delay             60 min
  1    74 min  unbox incubating          [60, ∞)
  1    74 min  Wash              3 min
  1    77 min  Develop           1 min
  1    78 min  · box developing          [15, 20]
  1    78 min  delay             15 min
  1    93 min  unbox developing          [15, 20]
  1    93 min  Stop              0 min
  1    93 min  Read              1 min
  Run 1 returned 0 at 94 min.
  

--timeline is refused with --emit-opentrons, and --time-unit needs --bind or
--timeline.

  $ ../tempore --grades time-interval --timeline --emit-opentrons elisa.py ../examples/opentrons/elisa.tpe
  ../tempore: option '--timeline' cannot be used with '--emit-opentrons'.
  [2]

  $ ../tempore --grades time-interval --time-unit minutes ../examples/opentrons/elisa.tpe
  ../tempore: option '--time-unit' requires '--bind' or '--timeline'.
  [2]
