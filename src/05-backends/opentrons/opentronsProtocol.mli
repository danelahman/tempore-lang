(** Opentrons protocols compiled from Tempore programs.

    A protocol is a single Python file: the [metadata] and [requirements] of the
    protocol, the runtime ({!OpentronsEmit.runtime}), the binding file, the
    compiled program ({!OpentronsEmit.compile}) and the function [run] that the
    Opentrons robot and simulator call. Run as a script, the file executes the
    program as {!OpentronsEmit.plain_program} does, without the binding.

    {2 Binding files}

    A binding file is Python source that defines the function [setup], which
    loads the labware, pipettes and modules of the protocol context it is given
    and returns a context object, and, for an operation [Op] of the program, a
    function [Op(ctx, arg)] that performs the operation on the context object
    and the argument and returns its result. It may declare the nominal duration
    of the action of a binding function by calling [tempore_elapse(seconds)]. It
    must not define names that begin with [tempore_] or [_tempore_], nor the
    names [metadata], [requirements] and [run], nor the names of the top-level
    definitions of the compiled program.

    The names a file defines are found by a line-based check, not by parsing
    Python: a line that starts at column 0 with [def NAME], [async def NAME] or
    [class NAME], an import ([import M], [import M as NAME],
    [from M import NAME] or [from M import X as NAME]), or an assignment
    [NAME = ...], [NAME: T = ...] or [NAME, NAME = ...] defines the names it
    binds. *)

type robot = Flex  (** the Opentrons Flex, robot type ["Flex"] *)

type options = {
  robot : robot;
  api_level : string;  (** the [apiLevel] requirement, e.g. ["2.30"] *)
  time_unit : Grades.Rational.t;
      (** the length in seconds of one unit of duration of the program *)
  monitor : Utils.Monitor.t;
      (** the policy of the monitors of running-time bounds: under [Abort] a
          call outside its bounds ends the protocol with an error, under [Warn]
          it is reported by a comment, and under [Off] calls are neither checked
          nor recorded *)
  name : string;  (** the [protocolName] of the metadata *)
  source : string;  (** the source file named by the metadata's description *)
}

val default_api_level : robot -> string
(** [default_api_level robot] is the latest [apiLevel] of [robot]: ["2.30"] for
    the Flex. *)

val protocol :
  options ->
  operations:
    (Language.Ast.operation
    * (Grades.Rational.t Grades.Grade.bound
      * Grades.Rational.t Grades.Grade.bound)
      option)
    list ->
  compound:Language.Ast.operation list ->
  binding_name:string ->
  binding:string ->
  ('rho, 'eps) Language.Ast.command list ->
  (string * string list, string list) result
(** [protocol options ~operations ~compound ~binding_name ~binding commands] is
    the source of the protocol of the desugared [commands], accepted by the
    typechecker, of a program whose declared operations are [operations], as for
    {!OpentronsEmit.compile}, those of them that are compound being [compound],
    with the binding file [binding], named [binding_name] in messages, and the
    warnings about it; or the errors that refuse it.

    The function [run(protocol)] calls [setup(protocol)], configures the runtime
    with the binding functions of the declared operations that the binding file
    defines, the virtual clock in simulation and the clock of the host on the
    robot, the time unit and monitor policy of [options], and [protocol.delay]
    for delays, then executes the [run] commands of the program in order: each
    is announced by a comment, each monitored call is commented as it completes,
    and the value of the run is commented at its end.

    The errors are the names the binding file must not define, a missing
    [setup], and each operation that the code of a [run] command may perform
    ({!OpentronsReach.run_operations}) that has no binding function and no
    default implementation declared above the run and that no handler in the
    run's code has a case for. Such an operation that a handler in the run's
    code does have a case for is a warning instead if it is atomic, since the
    check does not decide whether every call is inside such a handler, and
    neither an error nor a warning if it is compound, since a compound operation
    has neither a binding function nor a default implementation and is
    implemented by a handler only. *)
