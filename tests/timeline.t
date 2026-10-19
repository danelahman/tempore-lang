The timelines of runs printed by --timeline: the delays, the calls of
operations performed by their default implementations, with the events of
these below them, each with its grade, and the resources boxed, with their
grades, and unboxed, each row with the grade accumulated before it.

A reading boxed by a handler and passed to the continuation of the call it
handles, named after the variable it is bound to; the handled operation and its
continuation are not shown.

  $ ../tempore --grades time-interval-rational --timeline ../examples/introduction/sensor_reading.tpe
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
  
  Timeline
  Run  Start       Event          Grade
  1    [0, 0]      delay          [0.1, 0.1]
  1    [0.1, 0.1]  box reading    [5, 10)
  1    [0.1, 0.1]  Compute        [6, 8]
  1                · delay        [7, 7]
  1    [6.1, 8.1]  unbox reading
  1    [6.1, 8.1]  AngleOf        (0, 1]
  1                · delay        [0.5, 0.5]
  1    (6.1, 9.1]  SetAngle       (1, 2)
  1                · delay        [1.5, 1.5]
  Run 1 returned () at (7.1, 11.1).
  

Values boxed for time intervals.

  $ ../tempore --grades time-interval --timeline ../examples/time/intervals.tpe
  === Run 1 ===
  return 2
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
  1    [3, 3]  unbox r
  Run 1 returned 2 at [3, 3].
  
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
  2    [3, 3]  unbox r
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
  3    [3, 3]  unbox r
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
  4    [3, 3]  unbox r
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
  5    [3, 3]  unbox r
  5    [3, 3]  unbox x'
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
  6    [4, 4]  unbox r
  Run 6 returned 1 at [4, 4].
  

Nested handlers: their continuations are not shown.

  $ ../tempore --grades time-lower-bound --timeline ../examples/handlers/nested.tpe
  === Run 1 ===
  return 7
  State: [
    { resource_1 ↦ <fun> # 2, resource_3 ↦ <fun> # 3 },
    4
  ]
  
  Timeline
  Run  Start  Event  Grade
  1    0      delay  4
  Run 1 returned 7 at 4.
  

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
  1    Low    unbox c
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
  2    High   unbox c
  2    High   Post        Low
  Run 2 returned "launch code: 0000" at High.
  

The ELISA protocol, interpreted.

  $ ../tempore --grades time-interval --timeline ../examples/opentrons/elisa.tpe
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
  1    [8, 17]    unbox antibody
  1    [8, 17]    Detect            [1, 3]
  1               · delay           [2, 2]
  1               · box incubating  [60, ∞)
  1    [9, 20]    delay             [65, 65]
  1    [74, 85]   unbox incubating
  1    [74, 85]   Wash              [2, 4]
  1               · delay           [3, 3]
  1    [76, 89]   Develop           [1, 2]
  1               · delay           [1, 1]
  1               · box developing  [15, 20]
  1    [77, 91]   delay             [17, 17]
  1    [94, 108]  unbox developing
  1    [94, 108]  Stop              [0, 1]
  1    [94, 109]  Read              [1, 2]
  1               · delay           [2, 2]
  Run 1 returned 0 at [95, 111].
  

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
    { resource_1 ↦ <fun> # 1 },
    1
  ]
  
  Timeline
  Run  Start  Event  Grade
  2    0      delay  1
  Run 2 returned () at 1.
  

Long grades of event traces: accumulated grades keep their last events,
box grades their first; with --timeline-full, which implies --timeline, the
grades are printed in full. Only the timelines are shown.

  $ ../tempore --grades regex-timed-rigid-interval-rational-symbolic --timeline ../examples/opentrons/washes.tpe | sed -n '/^Timeline$/,/^Run 1 /p'
  Timeline
  Run  Start                                     Event           Grade
  1    {0}                                       box binding     {AddBeads; ![5, 10]; MagnetOn}
  1    {0}                                       AddBeads        {AddBeads}
  1                                              · delay         {!2}
  1    {AddBeads}                                delay           {!7}
  1    {AddBeads; !7}                            MagnetOn        {MagnetOn}
  1                                              · delay         {!1}
  1    {AddBeads; !7; MagnetOn}                  unbox binding
  1    {AddBeads; !7; MagnetOn}                  delay           {!3}
  1    {AddBeads; !7; MagnetOn; !3}              RemoveLiquid    {RemoveLiquid}
  1                                              · delay         {!2}
  1    {…; !7; MagnetOn; !3; RemoveLiquid}       box washed      [{(Wash; ChangeTip)^[1, ∞); Wash; !≥2; …}, {(Wash; ChangeTip)*; Wash; !≤3; …}]
  1    {…; !7; MagnetOn; !3; RemoveLiquid}       Wash            {Wash}
  1                                              · delay         {!1}
  1    {…; MagnetOn; !3; RemoveLiquid; Wash}     ChangeTip       {ChangeTip}
  1                                              · delay         {!1}
  1    {…; !3; RemoveLiquid; Wash; ChangeTip}    Wash            {Wash}
  1                                              · delay         {!1}
  1    {…; RemoveLiquid; Wash; ChangeTip; Wash}  delay           {!3}
  1    {…; Wash; ChangeTip; Wash; !3}            ChangeTip       {ChangeTip}
  1                                              · delay         {!1}
  1    {…; ChangeTip; Wash; !3; ChangeTip}       unbox washed
  1    {…; ChangeTip; Wash; !3; ChangeTip}       MagnetOff       {MagnetOff}
  1                                              · delay         {!1}
  1    {…; Wash; !3; ChangeTip; MagnetOff}       EluteDNA        {EluteDNA}
  1                                              · delay         {!1}
  1    {…; !3; ChangeTip; MagnetOff; EluteDNA}   delay           {!2}
  1    {…; ChangeTip; MagnetOff; EluteDNA; !2}   MagnetOn        {MagnetOn}
  1                                              · delay         {!1}
  1    {…; MagnetOff; EluteDNA; !2; MagnetOn}    box settling    {![2, 5]}
  1    {…; MagnetOff; EluteDNA; !2; MagnetOn}    delay           {!3}
  1    {…; EluteDNA; !2; MagnetOn; !3}           unbox settling
  1    {…; EluteDNA; !2; MagnetOn; !3}           Transfer        {Transfer}
  1                                              · delay         {!2}
  Run 1 returned () at {…; !2; MagnetOn; !3; Transfer}.

  $ ../tempore --grades regex-timed-rigid-interval-rational-symbolic --timeline-full ../examples/opentrons/washes.tpe | sed -n '/^Timeline$/,/^Run 1 /p'
  Timeline
  Run  Start                                                                                                                    Event           Grade
  1    {0}                                                                                                                      box binding     {AddBeads; ![5, 10]; MagnetOn}
  1    {0}                                                                                                                      AddBeads        {AddBeads}
  1                                                                                                                             · delay         {!2}
  1    {AddBeads}                                                                                                               delay           {!7}
  1    {AddBeads; !7}                                                                                                           MagnetOn        {MagnetOn}
  1                                                                                                                             · delay         {!1}
  1    {AddBeads; !7; MagnetOn}                                                                                                 unbox binding
  1    {AddBeads; !7; MagnetOn}                                                                                                 delay           {!3}
  1    {AddBeads; !7; MagnetOn; !3}                                                                                             RemoveLiquid    {RemoveLiquid}
  1                                                                                                                             · delay         {!2}
  1    {AddBeads; !7; MagnetOn; !3; RemoveLiquid}                                                                               box washed      [{(Wash; ChangeTip)^[1, ∞); Wash; !≥2; ChangeTip}, {(Wash; ChangeTip)*; Wash; !≤3; ChangeTip}]
  1    {AddBeads; !7; MagnetOn; !3; RemoveLiquid}                                                                               Wash            {Wash}
  1                                                                                                                             · delay         {!1}
  1    {AddBeads; !7; MagnetOn; !3; RemoveLiquid; Wash}                                                                         ChangeTip       {ChangeTip}
  1                                                                                                                             · delay         {!1}
  1    {AddBeads; !7; MagnetOn; !3; RemoveLiquid; Wash; ChangeTip}                                                              Wash            {Wash}
  1                                                                                                                             · delay         {!1}
  1    {AddBeads; !7; MagnetOn; !3; RemoveLiquid; Wash; ChangeTip; Wash}                                                        delay           {!3}
  1    {AddBeads; !7; MagnetOn; !3; RemoveLiquid; Wash; ChangeTip; Wash; !3}                                                    ChangeTip       {ChangeTip}
  1                                                                                                                             · delay         {!1}
  1    {AddBeads; !7; MagnetOn; !3; RemoveLiquid; Wash; ChangeTip; Wash; !3; ChangeTip}                                         unbox washed
  1    {AddBeads; !7; MagnetOn; !3; RemoveLiquid; Wash; ChangeTip; Wash; !3; ChangeTip}                                         MagnetOff       {MagnetOff}
  1                                                                                                                             · delay         {!1}
  1    {AddBeads; !7; MagnetOn; !3; RemoveLiquid; Wash; ChangeTip; Wash; !3; ChangeTip; MagnetOff}                              EluteDNA        {EluteDNA}
  1                                                                                                                             · delay         {!1}
  1    {AddBeads; !7; MagnetOn; !3; RemoveLiquid; Wash; ChangeTip; Wash; !3; ChangeTip; MagnetOff; EluteDNA}                    delay           {!2}
  1    {AddBeads; !7; MagnetOn; !3; RemoveLiquid; Wash; ChangeTip; Wash; !3; ChangeTip; MagnetOff; EluteDNA; !2}                MagnetOn        {MagnetOn}
  1                                                                                                                             · delay         {!1}
  1    {AddBeads; !7; MagnetOn; !3; RemoveLiquid; Wash; ChangeTip; Wash; !3; ChangeTip; MagnetOff; EluteDNA; !2; MagnetOn}      box settling    {![2, 5]}
  1    {AddBeads; !7; MagnetOn; !3; RemoveLiquid; Wash; ChangeTip; Wash; !3; ChangeTip; MagnetOff; EluteDNA; !2; MagnetOn}      delay           {!3}
  1    {AddBeads; !7; MagnetOn; !3; RemoveLiquid; Wash; ChangeTip; Wash; !3; ChangeTip; MagnetOff; EluteDNA; !2; MagnetOn; !3}  unbox settling
  1    {AddBeads; !7; MagnetOn; !3; RemoveLiquid; Wash; ChangeTip; Wash; !3; ChangeTip; MagnetOff; EluteDNA; !2; MagnetOn; !3}  Transfer        {Transfer}
  1                                                                                                                             · delay         {!2}
  Run 1 returned () at {AddBeads; !7; MagnetOn; !3; RemoveLiquid; Wash; ChangeTip; Wash; !3; ChangeTip; MagnetOff; EluteDNA; !2; MagnetOn; !3; Transfer}.

  $ ../tempore --grades traces-timed-interval --timeline ../examples/traces_timed_ops/3d_printing.tpe | sed -n '/^Timeline$/,/^Run [0-9][0-9]* /p'
  Timeline
  Run  Start                                                                     Event          Grade
  1    [{0}, {0}]                                                                MixEpoxy       [{MixEpoxy}, {MixEpoxy}]
  1                                                                              · delay        [{1}, {1}]
  1                                                                              · box glue     [{8}, {11}]
  1    [{MixEpoxy}, {MixEpoxy}]                                                  Heat           [{Heat}, {Heat}]
  1                                                                              · delay        [{1}, {1}]
  1    [{MixEpoxy; Heat}, {MixEpoxy; Heat}]                                      Extrude        [{Extrude}, {Extrude}]
  1                                                                              · delay        [{4}, {4}]
  1                                                                              · box p        [{2}, {2}]
  1    [{MixEpoxy; Heat; Extrude}, {MixEpoxy; Heat; Extrude}]                    Cool           [{Cool}, {Cool}]
  1                                                                              · delay        [{2}, {2}]
  1                                                                              · unbox p
  1    [{MixEpoxy; Heat; Extrude; Cool}, {MixEpoxy; Heat; Extrude; Cool}]        box printed    [{2}, {8}]
  1    [{MixEpoxy; Heat; Extrude; Cool}, {MixEpoxy; Heat; Extrude; Cool}]        delay          [{2}, {2}]
  1    [{MixEpoxy; Heat; Extrude; Cool; 2}, {MixEpoxy; Heat; Extrude; Cool; 2}]  unbox printed
  1    [{MixEpoxy; Heat; Extrude; Cool; 2}, {MixEpoxy; Heat; Extrude; Cool; 2}]  unbox glue
  1    [{MixEpoxy; Heat; Extrude; Cool; 2}, {MixEpoxy; Heat; Extrude; Cool; 2}]  Mount          [{Mount}, {Mount}]
  1                                                                              · delay        [{1}, {1}]
  Run 1 returned Mounted (Printed (Cooled (Extruded (Heated (Model "Sword"))))) at [{…; Heat; Extrude; Cool; 2; Mount}, {…; Heat; Extrude; Cool; 2; Mount}].
  Timeline
  Run  Start                                                 Event          Grade
  2    [{0}, {0}]                                            Heat           [{Heat}, {Heat}]
  2                                                          · delay        [{1}, {1}]
  2    [{Heat}, {Heat}]                                      Extrude        [{Extrude}, {Extrude}]
  2                                                          · delay        [{4}, {4}]
  2                                                          · box p        [{2}, {2}]
  2    [{Heat; Extrude}, {Heat; Extrude}]                    Cool           [{Cool}, {Cool}]
  2                                                          · delay        [{2}, {2}]
  2                                                          · unbox p
  2    [{Heat; Extrude; Cool}, {Heat; Extrude; Cool}]        box printed    [{2}, {8}]
  2    [{Heat; Extrude; Cool}, {Heat; Extrude; Cool}]        delay          [{4}, {4}]
  2    [{Heat; Extrude; Cool; 4}, {Heat; Extrude; Cool; 4}]  unbox printed
  Run 2 returned ("Sword #1", Printed (Cooled (Extruded (Heated (Model "Sword"))))) at [{Heat; Extrude; Cool; 4}, {Heat; Extrude; Cool; 4}].
  Timeline
  Run  Start       Event    Grade
  3    [{0}, {0}]  Heat     [{Heat}, {Heat}]
  3                · delay  [{1}, {1}]
  Run 3 returned Model "Sword" at [{Heat}, {Heat}].
  Timeline
  Run  Start  Event  Grade
  Run 4 returned Epoxy at [{0}, {0}].

  $ ../tempore --grades traces-timed-interval --timeline-full ../examples/traces_timed_ops/3d_printing.tpe | sed -n '/^Timeline$/,/^Run 1 /p'
  Timeline
  Run  Start                                                                     Event          Grade
  1    [{0}, {0}]                                                                MixEpoxy       [{MixEpoxy}, {MixEpoxy}]
  1                                                                              · delay        [{1}, {1}]
  1                                                                              · box glue     [{8}, {11}]
  1    [{MixEpoxy}, {MixEpoxy}]                                                  Heat           [{Heat}, {Heat}]
  1                                                                              · delay        [{1}, {1}]
  1    [{MixEpoxy; Heat}, {MixEpoxy; Heat}]                                      Extrude        [{Extrude}, {Extrude}]
  1                                                                              · delay        [{4}, {4}]
  1                                                                              · box p        [{2}, {2}]
  1    [{MixEpoxy; Heat; Extrude}, {MixEpoxy; Heat; Extrude}]                    Cool           [{Cool}, {Cool}]
  1                                                                              · delay        [{2}, {2}]
  1                                                                              · unbox p
  1    [{MixEpoxy; Heat; Extrude; Cool}, {MixEpoxy; Heat; Extrude; Cool}]        box printed    [{2}, {8}]
  1    [{MixEpoxy; Heat; Extrude; Cool}, {MixEpoxy; Heat; Extrude; Cool}]        delay          [{2}, {2}]
  1    [{MixEpoxy; Heat; Extrude; Cool; 2}, {MixEpoxy; Heat; Extrude; Cool; 2}]  unbox printed
  1    [{MixEpoxy; Heat; Extrude; Cool; 2}, {MixEpoxy; Heat; Extrude; Cool; 2}]  unbox glue
  1    [{MixEpoxy; Heat; Extrude; Cool; 2}, {MixEpoxy; Heat; Extrude; Cool; 2}]  Mount          [{Mount}, {Mount}]
  1                                                                              · delay        [{1}, {1}]
  Run 1 returned Mounted (Printed (Cooled (Extruded (Heated (Model "Sword"))))) at [{MixEpoxy; Heat; Extrude; Cool; 2; Mount}, {MixEpoxy; Heat; Extrude; Cool; 2; Mount}].
  Timeline
  Run  Start                                                 Event          Grade
  2    [{0}, {0}]                                            Heat           [{Heat}, {Heat}]
  2                                                          · delay        [{1}, {1}]
  2    [{Heat}, {Heat}]                                      Extrude        [{Extrude}, {Extrude}]
  2                                                          · delay        [{4}, {4}]
  2                                                          · box p        [{2}, {2}]
  2    [{Heat; Extrude}, {Heat; Extrude}]                    Cool           [{Cool}, {Cool}]
  2                                                          · delay        [{2}, {2}]
  2                                                          · unbox p
  2    [{Heat; Extrude; Cool}, {Heat; Extrude; Cool}]        box printed    [{2}, {8}]
  2    [{Heat; Extrude; Cool}, {Heat; Extrude; Cool}]        delay          [{4}, {4}]
  2    [{Heat; Extrude; Cool; 4}, {Heat; Extrude; Cool; 4}]  unbox printed
  Run 2 returned ("Sword #1", Printed (Cooled (Extruded (Heated (Model "Sword"))))) at [{Heat; Extrude; Cool; 4}, {Heat; Extrude; Cool; 4}].
  
  === Run 3 ===
  return (Model "Sword")
  State: [
    [{1}, {1}]
  ]
  
  Timeline
  Run  Start       Event    Grade
  3    [{0}, {0}]  Heat     [{Heat}, {Heat}]
  3                · delay  [{1}, {1}]
  Run 3 returned Model "Sword" at [{Heat}, {Heat}].
  
  === Run 4 ===
  return Epoxy
  State: []
  
  Timeline
  Run  Start  Event  Grade
  Run 4 returned Epoxy at [{0}, {0}].
  

--timeline and --timeline-full are refused with --emit-opentrons, and
--time-unit needs --bind.

  $ ../tempore --grades time-interval --timeline --emit-opentrons elisa.py ../examples/opentrons/elisa.tpe
  ../tempore: option '--timeline' cannot be used with '--emit-opentrons'.
  [2]

  $ ../tempore --grades time-interval --time-unit minutes ../examples/opentrons/elisa.tpe
  ../tempore: option '--time-unit' requires '--bind'.
  [2]

  $ ../tempore --grades time-interval --timeline-full --emit-opentrons elisa.py ../examples/opentrons/elisa.tpe
  ../tempore: option '--timeline-full' cannot be used with '--emit-opentrons'.
  [2]
