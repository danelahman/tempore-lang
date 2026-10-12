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
    stack of frames, so that the depth of the Python stack does not grow with
    the program's recursion. A function's body is a sequence of statements that
    returns the effect tree of the body: a match is a chain of tests of its
    subject and bindings of the pattern's variables. Continuations of [do] are
    lifted out of their function to definitions at the level of its body, each
    taking as parameters the variables it uses that other lifted definitions
    bind, so that the nesting of the Python source follows that of the functions
    and cases of the program and not the length of its sequences.

    {2 Names}

    Each variable is named by {!OpentronsNames.identifier}; a primitive by the
    runtime function implementing it with the interpreter's semantics. Only the
    top-level definitions the [run] commands use are compiled
    ({!OpentronsReach.reachable}). *)

val runtime : string
(** The source of the runtime. *)

type compiled = {
  definitions : string;
      (** the Python source of the definitions of the program *)
  runs : string list;
      (** the names of the functions that return the computation of each [run]
          command, in order *)
}
(** A compiled program. *)

val compile : ('rho, 'eps) Language.Ast.command list -> compiled
(** [compile commands] compiles the desugared [commands], accepted by the
    typechecker, of a program, the standard library's included. *)

val plain_program : ('rho, 'eps) Language.Ast.command list -> string
(** [plain_program commands] is a Python program of the runtime and the compiled
    [commands] that executes the [run] commands in order and prints the value of
    each as the command-line interpreter prints it, without the final state of
    its resources: a header [=== Run n ===], the line [return v] and an empty
    line. A run-time error is reported on the standard error as the interpreter
    reports it, and ends the program with exit code 1. *)
