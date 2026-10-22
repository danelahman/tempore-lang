Programs with operations, handlers, default implementations and delays,
compiled to Python, print the results of their runs as the interpreter prints
them, without the final state of the resources of each run. A run that ends at
an unhandled operation call prints its continuation, whose source the Python
program does not keep, as <continuation>; the interpreter's continuation is
replaced by it before the comparison.

  $ normalise () {
  >   awk '/^State:/ { skip = 1 } /^$/ { skip = 0 } !skip' |
  >   awk '/^perform / { sub(/ \(op_var\..*/, " (<continuation>)"); print; skip = 1; next }
  >        /^$/ { skip = 0 } !skip'
  > }
  $ parity () {
  >   ../../tempore --grades "$1" "$2" 2>&1 | normalise > interpreter.out
  >   ../../tempore --grades "$1" --emit-opentrons program.py "$2" > /dev/null &&
  >   python3 _opentrons/protocols/program.py > python.out 2>&1
  >   diff interpreter.out python.out && cat python.out
  > }

The handler examples.

  $ parity time-lower-bound ../../examples/handlers/lower_bound.tpe
  === Run 1 ===
  return 48
  
  === Run 2 ===
  return 23
  
  === Run 3 (unhandled operation) ===
  perform Set 42 (<continuation>)
  

As the interpreter, the Python program ends with exit code 3 when a run fails:

  $ ../../tempore ../../examples/handlers/lower_bound.tpe > /dev/null
  [3]
  $ python3 _opentrons/protocols/program.py > /dev/null
  [3]
  $ parity time-lower-bound ../../examples/handlers/nested.tpe
  === Run 1 ===
  return 7
  
  $ parity time-upper-bound ../../examples/handlers/upper_bound.tpe
  === Run 1 ===
  return 45
  
  === Run 2 ===
  return 0
  
  === Run 3 ===
  return 46
  
  === Run 4 ===
  return 42
  
  $ parity time-lower-bound ../../examples/handlers/3d_printing.tpe
  === Run 1 ===
  return (Complete (UvCured (Cooled (Fresh (Model "Sword")))), 
          Complete (UvCured (Cooled (Fresh (Model "Hammer")))))
  
  $ parity traces-timed-interval ../../examples/traces_timed_ops/3d_printing.tpe
  === Run 1 ===
  return (Mounted (Printed (Cooled (Extruded (Heated (Model "Sword"))))))
  
  === Run 2 ===
  return ("Sword #1", Printed (Cooled (Extruded (Heated (Model "Sword")))))
  
  === Run 3 ===
  return (Model "Sword")
  
  === Run 4 ===
  return Epoxy
  

Continuations resumed twice, nested handlers forwarding operations to the outer
one, and deep handling of every call in the continuation.

  $ parity time-lower-bound handlers_resume.tpe
  === Run 1 ===
  return (3::2::2::1::2::1::1::0::[])
  
  === Run 2 ===
  return ((1, 1)::(1, 0)::(0, 1)::(0, 0)::[], 1::11::10::0::11::10::[])
  
  === Run 3 ===
  return ((1, 1::[])::(0, 0::[])::[])
  
  === Run 4 ===
  return (0, 4::3::2::1::0::[])
  
  === Run 5 ===
  return "done"
  

Continuations dropped, with the frames inside the handler.

  $ parity time-upper-bound handlers_drop.tpe
  === Run 1 ===
  return (Some 3)
  
  === Run 2 ===
  return None
  
  === Run 3 ===
  return (None, "after")
  
  === Run 4 ===
  return None
  
  === Run 5 ===
  return (Some 43)
  

Continuations that bind the same variable one inside the other, as the calls
of one function nested in each other give them.

  $ parity time-lower-bound handlers_shadowing.tpe
  === Run 1 ===
  return 2
  
  === Run 2 ===
  return 8
  

Default implementations: those declared above a run, run outside every
handler; and runs that end at an unhandled operation call.

  $ parity time-lower-bound defaults.tpe
  === Run 1 (unhandled operation) ===
  perform Measure 3 (<continuation>)
  
  === Run 2 (unhandled operation) ===
  perform Measure 3 (<continuation>)
  
  === Run 3 (unhandled operation) ===
  perform Log "calibrated" (<continuation>)
  
  === Run 4 ===
  return (Reading 8)
  
  === Run 5 ===
  return (Reading 9)
  
  === Run 6 ===
  return (Reading 105)
  
  === Run 7 ===
  return (Some (Reading 5))
  

Operations with running-time bounds and no binding functions: their runs end
at the unhandled call, or run the default implementation.

  $ parity traces-timed-interval-rational monitors.tpe
  === Run 1 (unhandled operation) ===
  perform CC 1 (<continuation>)
  
  === Run 2 (unhandled operation) ===
  perform OO 1 (<continuation>)
  
  === Run 3 (unhandled operation) ===
  perform CO 1 (<continuation>)
  
  === Run 4 (unhandled operation) ===
  perform OC 1 (<continuation>)
  
  === Run 5 ===
  return 2
  

A handler applied to 100000 calls, its continuation growing with them, runs in
Python without a bound on the depth of the stack.

  $ ../../tempore --emit-opentrons deep_effects.py effects_deep.tpe &&
  > python3 _opentrons/protocols/deep_effects.py
  Wrote _opentrons/protocols/deep_effects.py
  === Run 1 ===
  return 4999950000
  

The monitors of binding functions on the virtual clock: a call is checked
against the bounds of its operation, each end closed or open; outside them it
aborts the run under the policy abort, and is reported and recorded under warn.
Delays and declared durations advance the clock, scaled by the time unit.

  $ ../../tempore --grades traces-timed-interval-rational --emit-opentrons monitors.py monitors.tpe &&
  > python3 monitor_driver.py _opentrons/protocols/monitors.py
  Wrote _opentrons/protocols/monitors.py
  Policy abort:
    CC [2, 4], 1 s: aborts: Operation `CC` took 1 s, outside its running-time bounds [2, 4] s
    CC [2, 4], 2 s: returns 2
    CC [2, 4], 3 s: returns 2
    CC [2, 4], 4 s: returns 2
    CC [2, 4], 5 s: aborts: Operation `CC` took 5 s, outside its running-time bounds [2, 4] s
    OO (2, 4), 1 s: aborts: Operation `OO` took 1 s, outside its running-time bounds (2, 4) s
    OO (2, 4), 2 s: aborts: Operation `OO` took 2 s, outside its running-time bounds (2, 4) s
    OO (2, 4), 3 s: returns 2
    OO (2, 4), 4 s: aborts: Operation `OO` took 4 s, outside its running-time bounds (2, 4) s
    OO (2, 4), 5 s: aborts: Operation `OO` took 5 s, outside its running-time bounds (2, 4) s
    CO [2, 4), 1 s: aborts: Operation `CO` took 1 s, outside its running-time bounds [2, 4) s
    CO [2, 4), 2 s: returns 2
    CO [2, 4), 3 s: returns 2
    CO [2, 4), 4 s: aborts: Operation `CO` took 4 s, outside its running-time bounds [2, 4) s
    CO [2, 4), 5 s: aborts: Operation `CO` took 5 s, outside its running-time bounds [2, 4) s
    OC (2, 4], 1 s: aborts: Operation `OC` took 1 s, outside its running-time bounds (2, 4] s
    OC (2, 4], 2 s: aborts: Operation `OC` took 2 s, outside its running-time bounds (2, 4] s
    OC (2, 4], 3 s: returns 2
    OC (2, 4], 4 s: returns 2
    OC (2, 4], 5 s: aborts: Operation `OC` took 5 s, outside its running-time bounds (2, 4] s
  Policy warn:
    CC [2, 4], 1 s: returns 2
      reported: Operation `CC` took 1 s, outside its running-time bounds [2, 4] s
    CC [2, 4], 2 s: returns 2
    CC [2, 4], 3 s: returns 2
    CC [2, 4], 4 s: returns 2
    CC [2, 4], 5 s: returns 2
      reported: Operation `CC` took 5 s, outside its running-time bounds [2, 4] s
    OO (2, 4), 1 s: returns 2
      reported: Operation `OO` took 1 s, outside its running-time bounds (2, 4) s
    OO (2, 4), 2 s: returns 2
      reported: Operation `OO` took 2 s, outside its running-time bounds (2, 4) s
    OO (2, 4), 3 s: returns 2
    OO (2, 4), 4 s: returns 2
      reported: Operation `OO` took 4 s, outside its running-time bounds (2, 4) s
    OO (2, 4), 5 s: returns 2
      reported: Operation `OO` took 5 s, outside its running-time bounds (2, 4) s
    CO [2, 4), 1 s: returns 2
      reported: Operation `CO` took 1 s, outside its running-time bounds [2, 4) s
    CO [2, 4), 2 s: returns 2
    CO [2, 4), 3 s: returns 2
    CO [2, 4), 4 s: returns 2
      reported: Operation `CO` took 4 s, outside its running-time bounds [2, 4) s
    CO [2, 4), 5 s: returns 2
      reported: Operation `CO` took 5 s, outside its running-time bounds [2, 4) s
    OC (2, 4], 1 s: returns 2
      reported: Operation `OC` took 1 s, outside its running-time bounds (2, 4] s
    OC (2, 4], 2 s: returns 2
      reported: Operation `OC` took 2 s, outside its running-time bounds (2, 4] s
    OC (2, 4], 3 s: returns 2
    OC (2, 4], 4 s: returns 2
    OC (2, 4], 5 s: returns 2
      reported: Operation `OC` took 5 s, outside its running-time bounds (2, 4] s
  Policy off:
    CC, 5 s: returns 2, 0 monitored calls
  Exact durations:
    Wait, 0.5 s: returns 2
    Wait, 1.5 s: returns 2
    Wait, 1.500000001 s: aborts: Operation `Wait` took 1.500000001 s, outside its running-time bounds [0.5, 1.5] s
  Time unit of 60 s:
    CC, 150 s: returns 2
    CC, 100 s: aborts: Operation `CC` took 100 s, outside its running-time bounds [120, 240] s
  Timeline:
    At 0 s: operation `CC` took 3 s, within its running-time bounds [2, 4] s
    At 3 s: operation `OO` took 5 s, outside its running-time bounds (2, 4) s
    At 8 s: operation `CO` took 2 s, within its running-time bounds [2, 4) s
    At 10 s: operation `OC` took 4 s, within its running-time bounds (2, 4] s
    clock at the end: 16.75 s
  Delays and the default of Wait, time unit 60 s:
    returns 2 at 165 s, 0 monitored calls

The bounds of a compound operation are those its grade implies, read over the
bounds of the operations it names, compound ones included.

  $ cat > compound.tpe <<'TPE'
  > operation A : unit ~> unit ! {A} within [1, 2]
  > operation B : unit ~> unit ! {A; A}
  > operation C : unit ~> unit ! {B; A}
  > run return ()
  > TPE
  $ ../../tempore --grades traces-timed-upper-bound --emit-opentrons compound.py compound.tpe &&
  > grep -o '"C": tempore_Bounds([^)]*)[^)]*)[^)]*)' _opentrons/protocols/compound.py
  Wrote _opentrons/protocols/compound.py
  "C": tempore_Bounds(tempore_Fraction(3, 1), True, tempore_Fraction(6, 1), True)
