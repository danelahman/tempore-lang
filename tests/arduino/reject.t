Constructs outside the fragment that the Arduino backend compiles are rejected
with a compilation error at the construct, and nothing is written.

  $ reject () { ../../tempore --emit-arduino rejected "$1"; echo "exit $?"; }
A local recursive function:
  $ cat > local.tpe <<'TPE'
  > let f x =
  >   let rec g (y : nat) = match y with | 0 -> x | m + 1 -> g m in
  >   g 3
  > TPE
  $ reject local.tpe
  File "local.tpe", line 2, characters 12-60:
  2 |   let rec g (y : nat) = match y with | 0 -> x | m + 1 -> g m in
                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Compilation error: The Arduino backend does not support local recursive functions
  exit 1

A closure whose environment contains a closure of its own type, whose struct
would contain itself:
  $ cat > own_type.tpe <<'TPE'
  > let f (k : nat) =
  >   let g = fun (x : nat) -> x + k in
  >   let h = fun (x : nat) -> g x in
  >   h 1
  > TPE
  $ reject own_type.tpe
  File "own_type.tpe", line 3, characters 10-30:
  3 |   let h = fun (x : nat) -> g x in
                ^^^^^^^^^^^^^^^^^^^^
  Compilation error: The Arduino backend does not support a closure whose environment contains a closure of its own type
  exit 1

A closure stored in a datatype:
  $ cat > stored.tpe <<'TPE'
  > type action = Act of (nat -> nat)
  > let f (k : nat) = Act (fun (x : nat) -> x + k)
  > TPE
  $ reject stored.tpe
  File "stored.tpe", line 2, characters 18-46:
  2 | let f (k : nat) = Act (fun (x : nat) -> x + k)
                        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  Compilation error: The Arduino backend does not support the type `action`, whose constructors take functions
  exit 1

A recursive call inside a closure, which is not in tail position of the
function:
  $ cat > self.tpe <<'TPE'
  > let rec count (n : nat) =
  >   match n with
  >   | 0 -> 0
  >   | m + 1 -> let g = fun () -> count m in g ()
  > TPE
  $ reject self.tpe
  File "self.tpe", line 4, characters 31-38:
  4 |   | m + 1 -> let g = fun () -> count m in g ()
                                     ^^^^^^^
  Compilation error: The Arduino backend does not support the recursive call of `count` outside a tail position
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

A handler that is not tail-resumptive is rejected at the occurrence of the
continuation of a case outside a resumption in tail position, or at the end
of a branch of a case that does not resume it. Cases that do not resume
their continuation, which the typechecker accepts under upper bounds of
time, are compiled under those grades:

  $ reject_upper () { ../../tempore --grades time-upper-bound --emit-arduino rejected "$1"; echo "exit $?"; }

A handler whose case resumes its continuation twice, so that the first
resumption is not in tail position:
  $ cat > twice.tpe <<'TPE'
  > operation Ping : unit ~> nat ! 0
  > let twice =
  >   handler
  >   | x -> x
  >   | Ping () k -> let a = continue k with 1 in continue k with a
  > TPE
  $ reject twice.tpe
  File "twice.tpe", line 5, characters 34-35:
  5 |   | Ping () k -> let a = continue k with 1 in continue k with a
                                        ^
  Compilation error: The continuation `k` of the case of `Ping` is resumed outside tail position, so the handler cannot be compiled to direct calls
  exit 1

A handler whose case does not resume its continuation:
  $ cat > never.tpe <<'TPE'
  > operation Ping : unit ~> nat ! 0
  > let abort =
  >   handler
  >   | x -> x
  >   | Ping () k -> 0
  > TPE
  $ reject_upper never.tpe
  File "never.tpe", line 5, characters 17-18:
  5 |   | Ping () k -> 0
                       ^
  Compilation error: The case of `Ping` ends here without resuming its continuation `k`, so the handler cannot be compiled to direct calls
  exit 1

A handler whose case computes after the resumption:
  $ cat > after.tpe <<'TPE'
  > operation Ping : unit ~> nat ! 0
  > let after =
  >   handler
  >   | x -> x
  >   | Ping () k -> let r = continue k with 1 in r + 1
  > TPE
  $ reject after.tpe
  File "after.tpe", line 5, characters 34-35:
  5 |   | Ping () k -> let r = continue k with 1 in r + 1
                                        ^
  Compilation error: The continuation `k` of the case of `Ping` is resumed outside tail position, so the handler cannot be compiled to direct calls
  exit 1

A handler whose case resumes its continuation in one branch only:
  $ cat > branch.tpe <<'TPE'
  > operation Ping : nat ~> nat ! 0
  > let branch =
  >   handler
  >   | x -> x
  >   | Ping n k -> if n = 0 then continue k with 1 else 0
  > TPE
  $ reject_upper branch.tpe
  File "branch.tpe", line 5, characters 53-54:
  5 |   | Ping n k -> if n = 0 then continue k with 1 else 0
                                                           ^
  Compilation error: The case of `Ping` ends here without resuming its continuation `k`, so the handler cannot be compiled to direct calls
  exit 1

A handler whose case resumes its continuation inside a handle:
  $ cat > inner.tpe <<'TPE'
  > operation Ping : unit ~> nat ! 0
  > let inner =
  >   handler
  >   | x -> x
  >   | Ping () k -> handle continue k with 1 with handler x -> x
  > TPE
  $ reject_upper inner.tpe
  File "inner.tpe", line 5, characters 33-34:
  5 |   | Ping () k -> handle continue k with 1 with handler x -> x
                                       ^
  Compilation error: The continuation `k` of the case of `Ping` is resumed outside tail position, so the handler cannot be compiled to direct calls
  exit 1

A handler whose case passes its continuation to a function:
  $ cat > passed.tpe <<'TPE'
  > operation Ping : unit ~> nat ! 0
  > let passed =
  >   handler
  >   | x -> x
  >   | Ping () k -> let resume c = continue c with 1 in resume k
  > TPE
  $ reject passed.tpe
  File "passed.tpe", line 5, characters 60-61:
  5 |   | Ping () k -> let resume c = continue c with 1 in resume k
                                                                  ^
  Compilation error: The continuation `k` of the case of `Ping` is used other than by its resumption in tail position, so the handler cannot be compiled to direct calls
  exit 1

A handler whose case stores its continuation in a tuple:
  $ cat > stored.tpe <<'TPE'
  > operation Ping : unit ~> nat ! 0
  > let stored =
  >   handler
  >   | x -> x
  >   | Ping () k -> let p = (k, 1) in let k2, n = p in continue k2 with n
  > TPE
  $ reject stored.tpe
  File "stored.tpe", line 5, characters 26-27:
  5 |   | Ping () k -> let p = (k, 1) in let k2, n = p in continue k2 with n
                                ^
  Compilation error: The continuation `k` of the case of `Ping` is used other than by its resumption in tail position, so the handler cannot be compiled to direct calls
  exit 1

A handler that is a parameter, not known at compilation:
  $ cat > handler_parameter.tpe <<'TPE'
  > operation Ping : unit ~> nat ! 0
  > let with_handler h = handle perform Ping () with h
  > TPE
  $ reject handler_parameter.tpe
  File "handler_parameter.tpe", line 2, characters 49-50:
  2 | let with_handler h = handle perform Ping () with h
                                                       ^
  Compilation error: The Arduino backend does not support the handler `h`, which is not known at compilation
  exit 1

A handler chosen at run time:
  $ cat > chosen.tpe <<'TPE'
  > operation Ping : unit ~> nat ! 0
  > let one = handler | x -> x | Ping () k -> continue k with 1
  > let two = handler | x -> x | Ping () k -> continue k with 2
  > let chosen b = handle perform Ping () with (if b then one else two)
  > TPE
  $ reject chosen.tpe
  File "chosen.tpe", line 4, characters 54-57:
  4 | let chosen b = handle perform Ping () with (if b then one else two)
                                                            ^^^
  Compilation error: The Arduino backend does not support the handler `one` used as a value
  exit 1

A handler stored in a tuple:
  $ cat > data.tpe <<'TPE'
  > operation Ping : unit ~> nat ! 0
  > let one = handler | x -> x | Ping () k -> continue k with 1
  > let pair () = (one, 1)
  > TPE
  $ reject data.tpe
  File "data.tpe", line 3, characters 15-18:
  3 | let pair () = (one, 1)
                     ^^^
  Compilation error: The Arduino backend does not support the handler `one` used as a value
  exit 1

A recursive call inside a handle, which is not in tail position:
  $ cat > recursive_handle.tpe <<'TPE'
  > operation Ping : unit ~> nat ! 0
  > let one = handler | x -> x | Ping () k -> continue k with 1
  > let rec loop (n : nat) : nat ! 0 =
  >   match n with 0 -> 0 | m + 1 -> handle loop m with one
  > TPE
  $ reject recursive_handle.tpe
  File "recursive_handle.tpe", line 4, characters 40-46:
  4 |   match n with 0 -> 0 | m + 1 -> handle loop m with one
                                              ^^^^^^
  Compilation error: The Arduino backend does not support the recursive call of `loop` outside a tail position
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
  > operation Name : unit ~> string ! 1
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
