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
  

  $ parity_close float_functions.tpe
  === Run 1 ===
  return (3., 2)
  
  === Run 2 ===
  return (4000000000., 1000000000)
  
  === Run 3 ===
  return (0, 0, 0)
  
  === Run 4 ===
  return 0
  
  === Run 5 ===
  return ((2., 1.3258177042), (1.41421353817, 1.10714876652))
  
  === Run 6 ===
  return ((nan, -0.785398185253), (infinity, 1.5707962513))
  
  === Run 7 ===
  return (-0., nan)
  
  === Run 8 ===
  return (0.785398185253, 2.35619449615, -2.35619449615)
  
  === Run 9 ===
  return (0., 3.14159250259, -3.14159274101)
  
  === Run 10 ===
  return (1.57079637051, 0.785398185253, nan)
  

  $ parity nat_of_float_infinity.tpe
  === Run 1 ===
  return 1
  
  Run-time error: Conversion of infinity to a natural number

Natural numbers are of 32 bits in C++, so that the conversion of a float of
2^32 or above to a natural number is reduced modulo 2^32, where the
interpreter keeps it whole.

  $ compile nat_of_float_modulo.tpe && ./nat_of_float_modulo.host
  === Run 1 ===
  return (0, 1410065408, 4294967040)
  

  $ parity integers.tpe
  === Run 1 ===
  return (9i, 5i, 14i, 3i, 1i, -7i)
  
  === Run 2 ===
  return (-5i, -9i, -14i, -3i, -1i, 7i)
  
  === Run 3 ===
  return (5i, 9i, -14i, -3i, 1i, -7i)
  
  === Run 4 ===
  return (-9i, -5i, 14i, 3i, -1i, 7i)
  
  === Run 5 ===
  return (0, 1, 2)
  
  === Run 6 ===
  return (true, true, false, false, false, true)
  
  === Run 7 ===
  return (false, true, false, true, true, false)
  
  === Run 8 ===
  return (7i, 0, 7)
  
  === Run 9 ===
  return ((2i, 2.), (-2i, -2.), (0i, 0.))
  
  === Run 10 ===
  return (2147483647i, -2147483648i)
  

  $ parity int_division_by_zero.tpe
  === Run 1 ===
  return -3i
  
  Run-time error: Division by zero

  $ parity int_modulo_by_zero.tpe
  === Run 1 ===
  return -1i
  
  Run-time error: Modulo by zero

  $ parity int_of_float_infinity.tpe
  === Run 1 ===
  return -1i
  
  Run-time error: Conversion of infinity to an integer

Integers are of 32 bits in C++, in two's complement: their arithmetic and the
conversions of natural numbers and floats to integers are reduced modulo 2^32
into [-2^31, 2^31), where the interpreter keeps them whole.

  $ compile int_wrap.tpe && ./int_wrap.host
  === Run 1 ===
  return (-2147483648i, -2147483648i, 2147483647i, -2147483647i, -2147483647i, 0i)
  
  === Run 2 ===
  return (-2147483646i, -2147483646i, 0i, -2147483648i, -2147483648i, 0i)
  
  === Run 3 ===
  return (-1i, -2147483648i)
  
  === Run 4 ===
  return (-2147483648i, 2147483392i, 1410065408i)
  
