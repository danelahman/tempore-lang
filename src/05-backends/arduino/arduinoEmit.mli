(** Compilation of the fragment of {!ArduinoFragment} to C++.

    The code is C++17 without heap allocation, exceptions or run-time type
    information, over the runtime header [tempore_arduino.h]. Grades are erased.

    {2 Values}

    A natural number is a [uint32_t]: subtraction is truncated at zero, and
    division and the remainder by zero call [tempore_fault] with the message of
    the interpreter; addition and multiplication are taken modulo 2{^ 32}. A
    float is a single-precision [float], a boolean a [bool], a string constant a
    [const char *] and the unit value [tempore_unit{}]. A tuple is a struct with
    the members [c0], [c1], ...; a value of a datatype is a struct with a tag,
    the enumeration of the constructors in the order of their labels, and the
    union [arg] of the arguments of the constructors. Each struct without a
    string or function component has a function [tempore_compare] that orders
    its values as the comparison primitives do.

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

    {2 Closures}

    Closures are compiled by defunctionalisation (Reynolds, "Definitional
    interpreters for higher-order programming languages", 1972). A value of a
    function type is a struct with a tag, the position of its function among the
    anonymous functions of that type in the program, and the union [env] of
    their environments [e0], [e1], ..., each a tuple of the values of the free
    variables of the function; a function [make_e0], [make_e1], ... of the
    struct creates a closure. The body of each anonymous function is a C++
    function of the variables of its environment and its argument. An
    application is a call of the application of the closures of its type, a C++
    function that calls the function of the tag of the closure. A struct whose
    environments contain, directly or through other structs, a closure of its
    own type is rejected. A closure in the result of a [run] is printed as
    [<fun>].

    {2 Handlers}

    A tail-resumptive handler is compiled by specialisation to direct calls of
    its cases. Each operation case is a C++ function of the parameters of the
    handler and the argument of the operation, whose result is the value the
    continuation is resumed with; the return case, unless it returns its input,
    is a C++ function of the parameters of the handler and the result of the
    handled computation, applied to that result. As in the interpreter, the
    handlers are deep and a case runs outside its handler: an operation
    performed in the body of a [handle], and in the functions it calls,
    transitively, calls the case of the innermost handler of the operation in
    the context of the handlers outside that handler, or the external function
    of the operation if no handler around it handles it.

    A function, the body of an anonymous function and the application of the
    closures of a function type are compiled once for each instance of their
    types and each context of the handlers that their operations reach, the
    values of the parameters of those handlers following their own parameters.
    The operations of a closure are thus handled by the handlers around its
    application, as in the interpreter. The cases of a handler are compiled once
    for each instance of the types of its parameters and its cases, and each
    context outside it. An operation handled by a case is not a call of its
    external function, and is not monitored on a device; the operations of the
    case are.

    {2 Names}

    Variables, datatypes and constructors are named by
    {!ArduinoNames.identifier}; the tuple types, the temporaries and the other
    names the compiler introduces start with [tempore_]. *)

type compiled = {
  files : (string * string) list;  (** the files, each with its name *)
  entries : (Language.Ast.variable * string) list;
      (** the entry points, each with the name of its C++ function *)
  operation_types : (Language.Ast.operation * (string * string)) list;
      (** the operations performed outside all handlers, each with the C++ types
          of its argument and its result *)
}
(** A compiled program. *)

val compile :
  ?host_runs:bool -> source:string -> ArduinoFragment.program -> compiled
(** [compile ~host_runs ~source program] is the files of the C++ compilation of
    [program], of the source file named [source], each with its name: the
    runtime header [tempore_arduino.h], the header [tempore_program.h] and the
    source [tempore_program.cpp]. The entry points, declared in the header, are
    the instances of the top-level functions of the program's sources among its
    entry points ({!ArduinoFragment.program}) whose types have no type
    variables; the other instances are [static]. Only the units reached from the
    entry points, and from the [run] commands if they are compiled, are
    compiled, and the operations declared are those they perform outside all
    handlers.

    If [host_runs] (default [false]), the [run] commands of [program] are
    compiled too, to the functions [tempore_run1], [tempore_run2], ..., and a
    fourth file [tempore_host_main.cpp] defines a [main] that executes them in
    order and prints the result of each as the command-line interpreter prints
    it, without the final state of its resources: a header [=== Run n ===], the
    line [return v] and an empty line. It also defines [tempore_fault], which
    reports a run-time error on the standard error as the interpreter reports it
    and ends the program with exit code 3, that of a failed run, a
    [tempore_delay] that returns at once, and functions for the operations
    performed outside all handlers that report a run-time error. *)
