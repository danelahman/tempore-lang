Programs compiled to Python print the results of their runs as the interpreter
prints them. The interpreter also prints the final state of the resources of
each run, which is dropped before the comparison.

  $ strip_state () { awk '/^State:/ { skip = 1 } /^$/ { skip = 0 } !skip'; }
  $ parity () {
  >   ../../tempore "$1" 2>&1 | strip_state > interpreter.out
  >   ../../tempore --emit-opentrons "${1%.tpe}.py" "$1" > /dev/null &&
  >   python3 "_opentrons/protocols/${1%.tpe}.py" > python.out 2>&1
  >   diff interpreter.out python.out && cat python.out
  > }

  $ parity arithmetic.tpe
  === Run 1 ===
  return 14
  
  === Run 2 ===
  return 0
  
  === Run 3 ===
  return 5
  
  === Run 4 ===
  return (3, 2)
  
  === Run 5 ===
  return 3.75
  
  === Run 6 ===
  return 0.333333333333
  
  === Run 7 ===
  return 0.3
  
  === Run 8 ===
  return infinity
  
  === Run 9 ===
  return neg_infinity
  
  === Run 10 ===
  return nan
  
  === Run 11 ===
  return 1024.
  
  === Run 12 ===
  return nan
  
  === Run 13 ===
  return infinity
  
  === Run 14 ===
  return 300.
  
  === Run 15 ===
  return 3e-05
  
  === Run 16 ===
  return 1.23456789012e+14
  
  === Run 17 ===
  return -0.
  
  === Run 18 ===
  return (true, true, false, false, true, false)
  
  === Run 19 ===
  return (true, true, true)
  
  === Run 20 ===
  return (true, true, true)
  
  === Run 21 ===
  return (true, true, true, true)
  

  $ parity division_by_zero.tpe
  === Run 1 ===
  return 2
  
  Run-time error: Division by zero

  $ parity float_functions.tpe
  === Run 1 ===
  return (0., 3., 1e+20)
  
  === Run 2 ===
  return 9007199254740992
  
  === Run 3 ===
  return (1e+308, infinity)
  
  === Run 4 ===
  return (2, 3, 0, 100000000000000000000)
  
  === Run 5 ===
  return (0, 0, 0)
  
  === Run 6 ===
  return 0
  
  === Run 7 ===
  return 4294967295
  
  === Run 8 ===
  return (2., 1.41421356237, 0., -0., nan)
  
  === Run 9 ===
  return (infinity, nan)
  
  === Run 10 ===
  return (0.785398163397, -0.785398163397, 1.57079632679, nan)
  
  === Run 11 ===
  return (0.785398163397, 2.35619449019, -2.35619449019)
  
  === Run 12 ===
  return (0., 3.14159265359, -3.14159265359)
  
  === Run 13 ===
  return (1.57079632679, 0.785398163397, nan)
  

  $ parity nat_of_float_infinity.tpe
  === Run 1 ===
  return 1
  
  Run-time error: Conversion of infinity to a natural number

  $ parity integers.tpe
  === Run 1 ===
  return (3i, -3i, -3i, 0i, 0i, 31i, 1000i)
  
  === Run 2 ===
  return (4i, -3i, -24i, 5i, 0i)
  
  === Run 3 ===
  return (3i, -3i, -3i, 3i)
  
  === Run 4 ===
  return (1i, -1i, 1i, -1i)
  
  === Run 5 ===
  return (7i, 3i, 6i)
  
  === Run 6 ===
  return (true, true, false, -1i, 0i, -1i)
  
  === Run 7 ===
  return (Some -3i, -1i::0i::1i::[], "-12i")
  
  === Run 8 ===
  return (0i, 5i, 5, 0, 0)
  
  === Run 9 ===
  return (-3., 0., 1e+23)
  
  === Run 10 ===
  return (2i, -2i, 0i)
  
  === Run 11 ===
  return (100000000000000000000i, -100000000000000000000i, 0i)
  
  === Run 12 ===
  return (18446744073709551616i, 2147483648i, 0i)
  

  $ parity int_of_float_infinity.tpe
  === Run 1 ===
  return -1i
  
  Run-time error: Conversion of infinity to an integer

  $ parity int_division_by_zero.tpe
  === Run 1 ===
  return (-3i, -1i)
  
  Run-time error: Division by zero

  $ parity int_modulo_by_zero.tpe
  Run-time error: Modulo by zero

  $ parity strings.tpe
  === Run 1 ===
  return "plain"
  
  === Run 2 ===
  return "quote \" backslash \\ newline \n tab \t"
  
  === Run 3 ===
  return "caf\195\169"
  
  === Run 4 ===
  return "42"
  
  === Run 5 ===
  return "2.5"
  
  === Run 6 ===
  return "\"nested \\\"string\\\"\""
  
  === Run 7 ===
  return "(1, \"two\", 3., true)"
  
  === Run 8 ===
  return "1::2::3::[]"
  
  === Run 9 ===
  return "Node (Leaf, Some (1::2::[]), Node (Leaf, None, Leaf))"
  
  === Run 10 ===
  return "(1::2::3::4::5::6::7::8::9::10::11::12::13::14::15::16::17::18::19::20::21::22::23::24::25::26::27::28::29::30::[], \n 100::101::102::103::104::105::106::107::108::109::110::111::112::113::114::115::116::117::118::119::120::121::122::123::124::125::126::127::128::129::130::[])"
  
  === Run 11 ===
  return (1000::1001::1002::1003::1004::1005::1006::1007::1008::1009::1010::1011::1012::1013::1014::1015::1016::1017::1018::1019::1020::1021::1022::1023::1024::1025::1026::1027::1028::1029::1030::[], 
          "a long tuple wraps at the margin of the printer")
  
  === Run 12 ===
  return ((1, "one")::(2, "two")::(3, "three")::(4, "four")::(5, "five")::(
  6, "six")::(7, "seven")::[])
  
  === Run 13 ===
  return (Node (Node (Leaf, (1, 2), Leaf), (3, 4), Leaf))
  
  === Run 14 ===
  return ((Some 1)::None::[])
  
  === Run 15 ===
  return (Some ((Some (1, 2::[]))::[]))
  
  === Run 16 ===
  return ((1::2::[])::[]::(3::[])::[])
  

  $ parity lists.tpe
  === Run 1 ===
  return (1::2::3::4::5::6::7::8::9::10::[])
  
  === Run 2 ===
  return (2::4::6::8::10::[])
  
  === Run 3 ===
  return 5050
  
  === Run 4 ===
  return (1::2::3::4::[])
  
  === Run 5 ===
  return (2::4::6::8::10::12::14::16::18::20::[])
  
  === Run 6 ===
  return (3::2::1::[])
  
  === Run 7 ===
  return ((1, "a")::(2, "b")::(3, "c")::[])
  
  === Run 8 ===
  return (1::2::[], "a"::"b"::[])
  
  === Run 9 ===
  return (1::2::3::4::[])
  
  === Run 10 ===
  return (3, Some 2, None)
  
  === Run 11 ===
  return (Some "two")
  
  === Run 12 ===
  return (Some 1, Some (2::[]), None)
  
  === Run 13 ===
  return (true, false, true)
  
  === Run 14 ===
  return (1::3::[])
  
  === Run 15 ===
  return (2::4::[])
  
  === Run 16 ===
  return (0::1::4::9::16::25::[])
  
  === Run 17 ===
  return 12
  
  === Run 18 ===
  return 6
  
  === Run 19 ===
  return (3, 4, 1, 2, "x")
  

  $ parity adts.tpe
  === Run 1 ===
  return (1::3::4::5::7::8::9::[])
  
  === Run 2 ===
  return 3
  
  === Run 3 ===
  return (3.::7.::0.::[])
  
  === Run 4 ===
  return (Group ((Circle 1.)::(Rectangle (2., 3.))::[]))
  
  === Run 5 ===
  return (("zero", 0)::("one", 0)::("two more than", 0)::("two more than", 8)::[])
  
  === Run 6 ===
  return (("first zero", [])::("two or more", 1::2::2::3::[])::("one", 4::[])::(
  "empty", [])::("none after", 3::[])::[])
  
  === Run 7 ===
  return (2, Node (Leaf, 2, Leaf))
  
  === Run 8 ===
  return true
  
  === Run 9 ===
  return (true, true, true)
  

  $ parity recursion.tpe
  === Run 1 ===
  return 2432902008176640000
  
  === Run 2 ===
  return 610
  
  === Run 3 ===
  return 18446744073709551616
  
  === Run 4 ===
  return 13
  
  === Run 5 ===
  return 4
  
  === Run 6 ===
  return (10::8::6::4::2::[])
  
  === Run 7 ===
  return (6::2::27::[])
  

  $ parity sequence.tpe
  === Run 1 ===
  return (0, 150, 300)
  

Values nested deeper than a bound are built from temporaries, as Python limits
the nesting of parentheses in an expression.

  $ parity nesting.tpe
  === Run 1 ===
  return (0::1::2::3::4::5::6::7::8::9::10::11::12::13::14::15::16::17::18::19::20::21::22::23::24::25::26::27::28::29::30::31::32::33::34::35::36::37::38::39::40::41::42::43::44::45::46::47::48::49::50::51::52::53::54::55::56::57::58::59::60::61::62::63::64::65::66::67::68::69::70::71::72::73::74::75::76::77::78::79::80::81::82::83::84::85::86::87::88::89::90::91::92::93::94::95::96::97::98::99::100::101::102::103::104::105::106::107::108::109::110::111::112::113::114::115::116::117::118::119::[])
  
  === Run 2 ===
  return (((((((((((((((((((((((((((((((((((((((((((((((((1, 2), 3), 4), 5), 6), 
                                                     7), 8), 9), 10), 11), 12), 
                                               13), 14), 15), 16), 17), 18), 19), 
                                        20), 21), 22), 23), 24), 25), 26), 27), 
                                28), 29), 30), 31), 32), 33), 34), 35), 36), 37), 
                      38), 39), 40), 41), 42), 43), 44), 45), 46), 47), 48), 49), 
          50)
  
  === Run 3 ===
  return 119
  

Recursion 100000 deep, beyond the reach of the interpreter in a test, runs in
Python without a bound on the depth of the stack.

  $ ../../tempore --emit-opentrons deep.py deep.tpe &&
  > python3 _opentrons/protocols/deep.py
  Wrote _opentrons/protocols/deep.py
  === Run 1 ===
  return 100000
  
  === Run 2 ===
  return 5000050000
  
  === Run 3 ===
  return 100000
  
  === Run 4 ===
  return 10000100000
  
