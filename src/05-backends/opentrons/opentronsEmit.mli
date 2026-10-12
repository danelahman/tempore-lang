(** Compilation of Tempore programs to Python.

    A program compiles to Python definitions over a runtime, {!runtime}, that is
    included verbatim before them. Grades are erased: [box] binds the value it
    boxes and [unbox] binds the value it unboxes.

    {2 Values}

    A natural number is an [int], a float a [float], a string a [str], a boolean
    a [bool] and a tuple a [tuple], the unit value [()]. A value of a
    constructor is [Con(tag, arg)], where [tag] numbers the label in the order
    of labels the comparison primitives use and [arg] is [None] for a constant
    constructor; the lists are built from the constructors [[]] and [::]. A
    function is a Python function from its argument to a computation, and a
    handler is [Handler(ret, clauses)], its return case and its operation cases,
    by operation name.

    {2 Computations}

    A computation is a Python expression for its effect tree: [Ret(v)],
    [Bind(c, k)], [App(f, v)], [Perform(op, v, k)], [Handle(c, h)] or
    [Delay(q, c)], where [q] is the exact duration as a [Fraction]. The
    runtime's abstract machine [execute] runs an effect tree with an explicit
    stack of frames, split at the handlers into segments, so that the depth of
    the Python stack does not grow with the program's recursion and a
    continuation, captured by sharing the persistent stack, may be dropped or
    resumed more than once. Handlers are deep, as in the interpreter. A
    function's body is a sequence of statements that returns the effect tree of
    the body: a match is a chain of tests of its subject and bindings of the
    pattern's variables. Continuations of [do] are lifted out of their function
    to definitions at the level of its body, each taking as parameters the
    variables it uses that other lifted definitions bind, so that the nesting of
    the Python source follows that of the functions and cases of the program and
    not the length of its sequences.

    {2 Names}

    Each variable is named by {!OpentronsNames.identifier}; a primitive by the
    runtime function implementing it with the interpreter's semantics. Only the
    top-level definitions the [run] commands use are compiled
    ({!OpentronsReach.reachable}).

    {2 Operations}

    An operation call that no handler handles calls the binding function of the
    operation, if the runtime has one, monitored against the bounds of the
    running time of the operation if it has any other than [\[0, ∞)]; otherwise
    it runs the default implementation of the operation declared above the [run]
    command, outside every handler; otherwise the run ends at the call. A
    [delay q] delays for [q] units of the program, converted to seconds by the
    runtime's time unit. *)

val runtime : string
(** The source of the runtime. Its global names, and those of the definitions
    the compiler introduces at the top level of the module, begin with
    [tempore_] or [_tempore_]; the top-level definitions of the program are
    named by {!OpentronsNames.identifier}. *)

val python_string : string -> string
(** [python_string s] is a Python string literal, in ASCII, of the UTF-8 string
    [s]; a byte not part of a well-formed UTF-8 sequence is the lone surrogate
    that the [surrogateescape] error handler encodes back to it. *)

val fraction : Grades.Rational.t -> string
(** [fraction q] is a Python expression of the exact rational [q], a [Fraction].
*)

val compile :
  operations:
    (Language.Ast.operation
    * (Grades.Rational.t Grades.Grade.bound
      * Grades.Rational.t Grades.Grade.bound)
      option)
    list ->
  ('rho, 'eps) Language.Ast.command list ->
  string
(** [compile ~operations commands] is the Python source of the compiled
    desugared [commands], accepted by the typechecker, of a program, the
    standard library's included, whose declared operations are [operations],
    each with the bounds of its running time if it has any, the upper end
    possibly infinite. It declares the bounds other than [\[0, ∞)] to the
    runtime, defines the program's top-level definitions and default
    implementations, and binds [tempore_RUNS] to the tuple of its [run]
    commands, each a [tempore_Run] of the function returning its computation and
    the default implementations declared above it. *)

val plain_program :
  operations:
    (Language.Ast.operation
    * (Grades.Rational.t Grades.Grade.bound
      * Grades.Rational.t Grades.Grade.bound)
      option)
    list ->
  ('rho, 'eps) Language.Ast.command list ->
  string
(** [plain_program ~operations commands] is a Python program of the runtime and
    the {!compile}d [commands] that, run as a script, executes the [run]
    commands in order on a virtual clock, without binding functions, and prints
    the outcome of each as the command-line interpreter prints it, without the
    final state of its resources: a header [=== Run n ===], the line [return v]
    and an empty line, or for a run that ends at an unhandled operation call the
    header [=== Run n (unhandled operation) ===], the call with its continuation
    printed as [<continuation>] and an empty line. A run-time error is reported
    on the standard error as the interpreter reports it, and ends the program
    with exit code 1. Imported as a module, it executes nothing. *)
