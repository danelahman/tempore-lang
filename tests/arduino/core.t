Programs compiled to C++ for the host print the results of their runs as the
interpreter prints them. The interpreter also prints the final state of the
resources of each run, which is dropped before the comparison. The generated
code compiles without warnings.

  $ strip_state () { awk '/^State:/ { skip = 1 } /^$/ { skip = 0 } !skip'; }
  $ compile () {
  >   ../../tempore --emit-arduino "${1%.tpe}" --host-runs "$1" > /dev/null &&
  >   c++ -std=c++17 -Wall -Wextra -Werror -O2 -o "${1%.tpe}.host" \
  >     "_arduino/projects/${1%.tpe}/tempore_program.cpp" \
  >     "_arduino/projects/${1%.tpe}/tempore_host_main.cpp"
  > }
  $ parity () {
  >   ../../tempore "$1" 2>&1 | strip_state > interpreter.out
  >   compile "$1" && "./${1%.tpe}.host" > cxx.out 2>&1
  >   diff interpreter.out cxx.out && cat cxx.out
  > }

Floats are single precision in C++ and double precision in the interpreter, so
the results with floats are compared up to a difference of 10^-4, relative to
numbers above 1, and their text otherwise.

  $ close () {
  >   paste -d '\n' "$1" "$2" | awk '
  >     function numbers(s, a,   n) {
  >       n = 0
  >       while (match(s, /-?[0-9]+(\.[0-9]*)?(e[-+]?[0-9]+)?/)) {
  >         a[++n] = substr(s, RSTART, RLENGTH) + 0
  >         s = substr(s, RSTART + RLENGTH)
  >       }
  >       return n
  >     }
  >     function text(s) {
  >       gsub(/-?[0-9]+(\.[0-9]*)?(e[-+]?[0-9]+)?/, "#", s)
  >       return s
  >     }
  >     NR % 2 == 1 { left = $0; next }
  >     {
  >       n = numbers(left, a); m = numbers($0, b)
  >       same = text(left) == text($0) && n == m
  >       for (i = 1; same && i <= n; i++) {
  >         d = a[i] - b[i]; if (d < 0) d = -d
  >         s = a[i] < 0 ? -a[i] : a[i]; if (s < 1) s = 1
  >         if (d > 1e-4 * s) same = 0
  >       }
  >       if (!same) { print "< " left; print "> " $0; status = 1 }
  >     }
  >     END { exit status }'
  > }
  $ parity_close () {
  >   ../../tempore "$1" 2>&1 | strip_state > interpreter.out
  >   compile "$1" && "./${1%.tpe}.host" > cxx.out 2>&1
  >   close interpreter.out cxx.out && cat cxx.out
  > }

  $ parity nat.tpe
  === Run 1 ===
  return (22, 85, 12, 0, 3, 2)
  
  === Run 2 ===
  return (22, 85, 0, 12, 0, 5)
  
  === Run 3 ===
  return (0, 10, 0, 4294967293)
  
  === Run 4 ===
  return (true, true, false, false, false, true)
  
  === Run 5 ===
  return (false, true, false, true, true, false)
  
  === Run 6 ===
  return 4294967294
  
  === Run 7 ===
  return (false, true, true)
  

  $ parity division_by_zero.tpe
  === Run 1 ===
  return 3
  
  Run-time error: Division by zero

  $ parity modulo_by_zero.tpe
  === Run 1 ===
  return 1
  
  Run-time error: Modulo by zero

  $ parity datatypes.tpe
  === Run 1 ===
  return (0, (Idle, Fault 3))
  
  === Run 2 ===
  return (Armed, Fault 0, Fault 1, Idle)
  
  === Run 3 ===
  return (1, 2, 3)
  
  === Run 4 ===
  return (107, 4, 5, 6)
  
  === Run 5 ===
  return (true, true, true, true, Fault 1)
  
  === Run 6 ===
  return (Group (Pair (Fault 1, Idle)))
  
  === Run 7 ===
  return (Rect (1.5, 2.5), Circle 0.5)
  

  $ parity loops.tpe
  === Run 1 ===
  return 1000000
  
  === Run 2 ===
  return 21
  
  === Run 3 ===
  return 498402
  
  === Run 4 ===
  return 111
  
  === Run 5 ===
  return 42
  

  $ parity polymorphism.tpe
  === Run 1 ===
  return ((2.5, 1), ((), true), ((3, 3), (3, 3)))
  
  === Run 2 ===
  return (1, 2.5, 0, 2, 2.5)
  

  $ parity_close floats.tpe
  === Run 1 ===
  return (3.5, -0.5, 3., 0.75, 2.25, -1.5)
  
  === Run 2 ===
  return (4., -2., 3., 0.333333343267, 1., -1.)
  
  === Run 3 ===
  return (false, false, true, true, false, true)
  
  === Run 4 ===
  return (0, 1, 2)
  
  === Run 5 ===
  return (infinity, neg_infinity, nan)
  
  === Run 6 ===
  return 300.
  

  $ parity_close pid.tpe
  === Run 1 ===
  return (5.25, (1., 2.))
  
  === Run 2 ===
  return 0.999988079071
  
