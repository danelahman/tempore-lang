(** Compilation of the fragment of {!ArduinoFragment} to C++.

    The code is C++17 without heap allocation, exceptions or run-time type
    information, over the runtime header {!runtime}. Grades are erased.

    {2 Values}

    A natural number is a [uint32_t]: subtraction is truncated at zero, and
    division and the remainder by zero call [tempore_fault] with the message of
    the interpreter; addition and multiplication are taken modulo 2{^ 32}. A
    float is a single-precision [float], a boolean a [bool], a string constant a
    [const char *] and the unit value [tempore_unit{}]. A tuple is a struct with
    the members [c0], [c1], ...; a value of a datatype is a struct with a tag,
    the enumeration of the constructors in the order of their labels, and the
    union [arg] of the arguments of the constructors. Each struct has a function
    [tempore_compare] that orders its values as the comparison primitives do.

    {2 Functions}

    Each instance of a top-level function, at the types of its quantified type
    variables, is a C++ function of all its curried parameters; each top-level
    constant a [static const] variable. A function that calls itself runs its
    body in a loop, a call of itself in tail position assigning its parameters
    and continuing the loop. A [match] is a chain of tests of its subject and
    declarations of the variables of the pattern taken; the last case is taken
    when none before it applies. An operation call is a call of the external
    function {!ArduinoNames.operation} of the operation, and [delay q] a call of
    [tempore_delay] with the numerator and the denominator of [q].

    {2 Names}

    Variables, datatypes and constructors are named by
    {!ArduinoNames.identifier}; the tuple types, the temporaries and the other
    names the compiler introduces start with [tempore_]. *)

val runtime : string
(** The source of the runtime header [tempore_arduino.h]. *)

val files :
  ?host_runs:bool ->
  source:string ->
  ArduinoFragment.program ->
  (string * string) list
(** [files ~host_runs ~source program] is the files of the C++ compilation of
    [program], of the source file named [source], each with its name: the
    runtime header [tempore_arduino.h], the header [tempore_program.h] and the
    source [tempore_program.cpp]. The entry points, declared in the header, are
    the instances of the top-level functions of the program's sources whose
    types have no type variables; the other instances are [static].

    If [host_runs] (default [false]), the [run] commands of [program] are
    compiled too, to the functions [tempore_run1], [tempore_run2], ..., and a
    fourth file [tempore_host_main.cpp] defines a [main] that executes them in
    order and prints the result of each as the command-line interpreter prints
    it, without the final state of its resources: a header [=== Run n ===], the
    line [return v] and an empty line. It also defines [tempore_fault], which
    reports a run-time error on the standard error as the interpreter reports it
    and ends the program with exit code 1, a [tempore_delay] that returns at
    once, and functions for the operations that report a run-time error. *)
