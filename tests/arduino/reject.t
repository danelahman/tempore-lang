Constructs outside the fragment that the Arduino backend compiles are rejected
with a compilation error at the construct, and nothing is written.

  $ reject () { ../../tempore --emit-arduino rejected "$1"; echo "exit $?"; }
A function other than a top-level definition:
  $ cat > local.tpe <<'TPE'
  > let f x = let g y = y + x in g 1
  > TPE
  $ reject local.tpe
  File "local.tpe", line 1, characters 16-25:
  1 | let f x = let g y = y + x in g 1
                      ^^^^^^^^^
  Compilation error: The Arduino backend does not support functions other than top-level definitions
  exit 1

The application of a parameter:
  $ cat > parameter.tpe <<'TPE'
  > let apply g x = g x
  > TPE
  $ reject parameter.tpe
  File "parameter.tpe", line 1, characters 16-17:
  1 | let apply g x = g x
                      ^
  Compilation error: The Arduino backend does not support the application of a function other than a top-level definition
  exit 1

A partial application:
  $ cat > partial.tpe <<'TPE'
  > let add x y = x + y
  > let f x = let g = add x in (g, 3)
  > TPE
  $ reject partial.tpe
  File "partial.tpe", line 2, characters 28-29:
  2 | let f x = let g = add x in (g, 3)
                                  ^
  Compilation error: The Arduino backend does not support the partial application of `add`
  exit 1

A function used as a value:
  $ cat > value.tpe <<'TPE'
  > let id x = x
  > let f () = id
  > TPE
  $ reject value.tpe
  File "value.tpe", line 2, characters 11-13:
  2 | let f () = id
                 ^^
  Compilation error: The Arduino backend does not support the function `id` used as a value
  exit 1

A handler:
  $ cat > handler.tpe <<'TPE'
  > operation Ping : unit ~> unit # 1
  > let f () =
  >   handle perform Ping () with handler
  >   | x -> x
  >   | Ping () k -> delay 1; continue k with ()
  > TPE
  $ reject handler.tpe
  File "handler.tpe", lines 3-5, characters 2-44:
  3 |   handle perform Ping () with handler
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Compilation error: The Arduino backend does not support handlers
  exit 1

A list:
  $ cat > list.tpe <<'TPE'
  > let f x = [x; x]
  > TPE
  $ reject list.tpe
  File "list.tpe", line 1, characters 10-16:
  1 | let f x = [x; x]
                ^^^^^^
  Compilation error: The Arduino backend does not support lists
  exit 1

A string other than a constant argument of an operation:
  $ cat > string.tpe <<'TPE'
  > let f x = ("a", x)
  > TPE
  $ reject string.tpe
  File "string.tpe", line 1, characters 13-14:
  1 | let f x = ("a", x)
                   ^
  Compilation error: The Arduino backend does not support strings other than constant arguments of operations
  exit 1

A recursive call outside tail position:
  $ cat > nontail.tpe <<'TPE'
  > let rec fact n = match n with 0 -> 1 | k + 1 -> n * fact k
  > TPE
  $ reject nontail.tpe
  File "nontail.tpe", line 1, characters 52-58:
  1 | let rec fact n = match n with 0 -> 1 | k + 1 -> n * fact k
                                                          ^^^^^^
  Compilation error: The Arduino backend does not support the recursive call of `fact` outside a tail position
  exit 1

A datatype with type parameters:
  $ cat > parameters.tpe <<'TPE'
  > let f x = Some x
  > TPE
  $ reject parameters.tpe
  File "parameters.tpe", line 1, characters 10-16:
  1 | let f x = Some x
                ^^^^^^
  Compilation error: The Arduino backend does not support the type `option`, which has type parameters
  exit 1

A recursive datatype:
  $ cat > recursive.tpe <<'TPE'
  > type tree = Leaf | Node of tree * tree
  > let f x = Node (x, Leaf)
  > TPE
  $ reject recursive.tpe
  File "recursive.tpe", line 2, characters 10-24:
  2 | let f x = Node (x, Leaf)
                ^^^^^^^^^^^^^^
  Compilation error: The Arduino backend does not support the recursive type `tree`
  exit 1

A natural number literal of more than 32 bits:
  $ cat > literal.tpe <<'TPE'
  > let f x = x + 4294967296
  > TPE
  $ reject literal.tpe
  File "literal.tpe", line 1, characters 14-24:
  1 | let f x = x + 4294967296
                    ^^^^^^^^^^
  Compilation error: The Arduino backend does not support the natural number literal `4294967296`, which exceeds 32 bits
  exit 1

An integer literal outside 32 bits:
  $ cat > integer.tpe <<'TPE'
  > let f x = x -! -2147483649i
  > TPE
  $ reject integer.tpe
  File "integer.tpe", line 1, characters 15-27:
  1 | let f x = x -! -2147483649i
                     ^^^^^^^^^^^^
  Compilation error: The Arduino backend does not support the integer literal `-2147483649i`, which exceeds 32 bits
  exit 1

The primitive `to_string`:
  $ cat > to_string.tpe <<'TPE'
  > let f x = to_string x
  > TPE
  $ reject to_string.tpe
  File "to_string.tpe", line 1, characters 10-19:
  1 | let f x = to_string x
                ^^^^^^^^^
  Compilation error: The Arduino backend does not support `to_string`
  exit 1

  $ test -e _arduino || echo 'Nothing is written.'
  Nothing is written.

An operation whose result is a string:
  $ cat > string_result.tpe <<'TPE'
  > operation Name : unit ~> string # 1
  > let same () = let a = perform Name () in let b = perform Name () in a = b
  > TPE
  $ reject string_result.tpe
  File "string_result.tpe", line 2, characters 22-37:
  2 | let same () = let a = perform Name () in let b = perform Name () in a = b
                            ^^^^^^^^^^^^^^^
  Compilation error: The Arduino backend does not support the operation `Name`, whose result contains a string
  exit 1

A datatype whose constructors take strings:
  $ cat > string_data.tpe <<'TPE'
  > type t = Named of string | Anon
  > let f () = Anon
  > TPE
  $ reject string_data.tpe
  File "string_data.tpe", line 2, characters 11-15:
  2 | let f () = Anon
                 ^^^^
  Compilation error: The Arduino backend does not support the type `t`, whose constructors take strings
  exit 1
