The timelines of runs printed by --timeline: the delays, the calls of
operations performed by their default implementations, with the events of
these below them, and the resources boxed and unboxed, each with its grade and
the grade accumulated before it.

A reading boxed by a handler and passed to the continuation of the call it
handles, named after the variable it is bound to; the handled operation and its
continuation are not shown.

  $ ../tempore --grades time-interval-rational --timeline ../examples/introduction/sensor_reading.tpe
  === Run 1 ===
  return ()
  State: [
    { resource_1 ↦
        fun op_var ↦
          handle
            let reading = return op_var in
            perform Compute () (op_var. return op_var);
            unbox reading as sample in
            let angle = perform AngleOf sample (op_var. return op_var) in
            perform SetAngle angle (op_var. return op_var)
          with sensor
        # (0, 0.5]
    },
    [0.1, 0.1],
    { resource_2 ↦ Sample 42 # [5, 10) },
    [7, 7],
    [0.5, 0.5],
    [1.5, 1.5]
  ]
  
  Timeline
  Run  Start       Event          Grade
  1    [0, 0]      delay          [0.1, 0.1]
  1    [0.1, 0.1]  box reading    [5, 10)
  1    [0.1, 0.1]  Compute        [6, 8]
  1                · delay        [7, 7]
  1    [6.1, 8.1]  unbox reading  [5, 10)
  1    [6.1, 8.1]  AngleOf        (0, 1]
  1                · delay        [0.5, 0.5]
  1    (6.1, 9.1]  SetAngle       (1, 2)
  1                · delay        [1.5, 1.5]
  Run 1 returned () at (7.1, 11.1).
  

Values boxed for time intervals.

  $ ../tempore --grades time-interval --timeline ../examples/time/intervals.tpe
  === Run 1 ===
  return 1
  State: [
    { resource_0 ↦ 1 # [1, 4] },
    [1, 1],
    [2, 2]
  ]
  
  Timeline
  Run  Start   Event    Grade
  1    [0, 0]  box r    [1, 4]
  1    [0, 0]  delay    [1, 1]
  1    [1, 1]  delay    [2, 2]
  1    [3, 3]  unbox r  [1, 4]
  Run 1 returned 1 at [3, 3].
  
  === Run 2 ===
  return 1
  State: [
    { resource_0 ↦ 1 # [1, 4] },
    [1, 1],
    [2, 2]
  ]
  
  Timeline
  Run  Start   Event    Grade
  2    [0, 0]  box r    [1, 4]
  2    [0, 0]  delay    [1, 1]
  2    [1, 1]  delay    [2, 2]
  2    [3, 3]  unbox r  [1, 4]
  Run 2 returned 1 at [3, 3].
  
  === Run 3 ===
  return 4
  State: [
    { resource_0 ↦ 1 # [1, 4] },
    [1, 1],
    [2, 2]
  ]
  
  Timeline
  Run  Start   Event    Grade
  3    [0, 0]  box r    [1, 4]
  3    [0, 0]  delay    [1, 1]
  3    [1, 1]  delay    [2, 2]
  3    [3, 3]  unbox r  [1, 4]
  Run 3 returned 4 at [3, 3].
  
  === Run 4 ===
  return 8
  State: [
    { resource_0 ↦ 1 # [1, 4] },
    [1, 1],
    [2, 2]
  ]
  
  Timeline
  Run  Start   Event    Grade
  4    [0, 0]  box r    [1, 4]
  4    [0, 0]  delay    [1, 1]
  4    [1, 1]  delay    [2, 2]
  4    [3, 3]  unbox r  [1, 4]
  Run 4 returned 8 at [3, 3].
  
  === Run 5 ===
  return 15
  State: [
    { resource_0 ↦ 7 # [2, 5], resource_1 ↦ 1 # [1, 4] },
    [1, 1],
    [2, 2]
  ]
  
  Timeline
  Run  Start   Event     Grade
  5    [0, 0]  box x'    [2, 5]
  5    [0, 0]  box r     [1, 4]
  5    [0, 0]  delay     [1, 1]
  5    [1, 1]  delay     [2, 2]
  5    [3, 3]  unbox r   [1, 4]
  5    [3, 3]  unbox x'  [2, 5]
  Run 5 returned 15 at [3, 3].
  
  === Run 6 ===
  return 1
  State: [
    { resource_0 ↦ 1 # [1, 4] },
    [4, 4]
  ]
  
  Timeline
  Run  Start   Event    Grade
  6    [0, 0]  box r    [1, 4]
  6    [0, 0]  delay    [4, 4]
  6    [4, 4]  unbox r  [1, 4]
  Run 6 returned 1 at [4, 4].
  

Nested handlers: their continuations are not shown.

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
  Run  Start  Event  Grade
  1    0      delay  3
  Run 1 returned 7 at 3.
  

Channels boxed at security levels, whose delays are unit grades.

  $ ../tempore --grades security-levels --timeline ../examples/levels/security.tpe
  === Run 1 ===
  return "weather: sunny"
  State: [
    { resource_0 ↦ Channel "public" # Low }
  ]
  
  Timeline
  Run  Start  Event       Grade
  1    Low    box c       Low
  1    Low    ReadPublic  Low
  1    Low    delay       Low
  1    Low    unbox c     Low
  1    Low    Post        Low
  Run 1 returned "weather: sunny" at Low.
  
  === Run 2 ===
  return "launch code: 0000"
  State: [
    { resource_0 ↦ Channel "classified" # High }
  ]
  
  Timeline
  Run  Start  Event       Grade
  2    Low    box c       High
  2    Low    ReadSecret  High
  2    High   unbox c     High
  2    High   Post        Low
  Run 2 returned "launch code: 0000" at High.
  

The ELISA protocol, interpreted.

  $ ../tempore --grades time-interval --timeline ../examples/opentrons/elisa.tpe
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
  Run  Start      Event             Grade
  1    [0, 0]     AddSample         [1, 3]
  1               · delay           [2, 2]
  1    [1, 3]     Dilute            [1, 2]
  1               · delay           [1, 1]
  1               · box antibody    [0, 20]
  1    [2, 5]     Wash              [2, 4]
  1               · delay           [3, 3]
  1    [4, 9]     Wash              [2, 4]
  1               · delay           [3, 3]
  1    [6, 13]    Wash              [2, 4]
  1               · delay           [3, 3]
  1    [8, 17]    unbox antibody    [0, 20]
  1    [8, 17]    Detect            [1, 3]
  1               · delay           [2, 2]
  1               · box incubating  [60, ∞)
  1    [9, 20]    delay             [60, 60]
  1    [69, 80]   unbox incubating  [60, ∞)
  1    [69, 80]   Wash              [2, 4]
  1               · delay           [3, 3]
  1    [71, 84]   Develop           [1, 2]
  1               · delay           [1, 1]
  1               · box developing  [15, 20]
  1    [72, 86]   delay             [15, 15]
  1    [87, 101]  unbox developing  [15, 20]
  1    [87, 101]  Stop              [0, 1]
  1    [87, 102]  Read              [1, 2]
  1               · delay           [1, 1]
  Run 1 returned 0 at [88, 104].
  

Default implementations that perform operations: each call one level below
the call whose default implementation performs it.

  $ ../tempore --timeline default_chain.tpe
  === Run 1 ===
  return 2
  State: [
    1,
    1,
    1
  ]
  
  Timeline
  Run  Start  Event        Grade
  1    0      Ask          3
  1           · delay      1
  1           · Load       2
  1           · · Store    1
  1           · · · delay  1
  1           · · Store    1
  1           · · · delay  1
  Run 1 returned 2 at 3.
  
  === Run 2 ===
  return ()
  State: [
    { resource_1 ↦
        fun op_var ↦
          handle
            return op_var
          with handler
               | return x ↦ return x
               | Report (msg, k) ↦
                          delay 1 (return ());
                          unbox k as cont_var in
                          cont_var ()
        # 1
    },
    1
  ]
  
  Timeline
  Run  Start  Event  Grade
  2    0      delay  1
  Run 2 returned () at 1.
  

--timeline is refused with --emit-opentrons, and --time-unit needs --bind.

  $ ../tempore --grades time-interval --timeline --emit-opentrons elisa.py ../examples/opentrons/elisa.tpe
  ../tempore: option '--timeline' cannot be used with '--emit-opentrons'.
  [2]

  $ ../tempore --grades time-interval --time-unit minutes ../examples/opentrons/elisa.tpe
  ../tempore: option '--time-unit' requires '--bind'.
  [2]
