(** PlatformIO projects of devices programmed in Tempore.

    A project compiles a program ({!ArduinoEmit}) for the board and the tasks of
    a device manifest ({!ArduinoDevice}), with the board profile
    ({!ArduinoBoard}), the scaffold and the bindings of the application.

    {2 Files}

    - [platformio.ini]: the environment of the board
      ({!ArduinoBoard.platformio_ini}), with the build flag [-DTEMPORE_PROFILE]
      under [profile];
    - [src/tempore_arduino.h], [src/tempore_program.h],
      [src/tempore_program.cpp]: the compiled program;
    - [src/tempore_scaffold.h], [src/tempore_scaffold.cpp]: the scaffold, the
      same for every device: the clock ([esp_timer_get_time]), the log on the
      serial port, delays, the monitors, the profile and the halt of the tasks;
    - [src/tempore_m5_monitor.cpp], on a board with M5Unified and the capability
      ["display"]: the display of the events of the monitors on the screen, the
      banner of a violation under the policy [abort] and the line of the
      warnings under [warn];
    - [src/tempore_bindings.h]: for each operation [Op] the program performs,
      the macro [TEMPORE_PERFORMS_Op], the types [tempore_argument_Op] and
      [tempore_result_Op] of its argument and result, and the declaration of its
      binding function; and the declaration of the safe-state hook; the binding
      file and the sources of the packages include it;
    - [src/tempore_operations.cpp]: the function [tempore_op_Op] of each
      operation [Op] the program performs, which calls the binding function
      [binding_Op] ({!ArduinoNames.binding}) and checks its running time against
      the bounds of the operation, and the array [tempore_operation_monitors] of
      the monitors of the operations;
    - [src/main.cpp]: the configuration, the safe state, which calls the
      safe-state functions of the packages and then the safe-state hook of the
      application, the array [tempore_task_monitors] of the monitors of the
      periodic tasks, [setup()], which initialises the board, calls the
      initialisation functions of the packages, starts the display of the events
      of the monitors on a board with a screen, creates a FreeRTOS task for each
      task of the manifest and starts the profile, and [loop()], which deletes
      its own task;
    - the sources of the packages ({!ArduinoPackage}) and the binding file of
      the manifest, in [src/];
    - [host/]: the stubs of Arduino, FreeRTOS, the timer of the ESP32, [Wire]
      and M5Unified, the model of the display of M5Unified
      ([tempore_m5_display.cpp]), the I2C buses with their device models
      ([tempore_i2c_model.h]), the world of the simulation ([tempore_world.h]),
      the discrete-event simulator [tempore_simulator.cpp], and the host models
      of the packages and of the manifest, with which the sources of [src/]
      build and run on the host ({!host_build_command}).

    {2 Tasks}

    A periodic task of period [P] calls the initial function, if any, once, and
    then its function at every release, from the tick at which it starts, with
    [vTaskDelayUntil]; the running time of each call is checked against [P]. A
    free task calls its function once and is deleted when it returns, or, if it
    is repeated, calls it again each time it returns. Each task first checks
    whether the tasks are halted, and stops if they are.

    {2 Time}

    A delay of [q] time units waits [q] times the time unit of the manifest,
    rounded to the nearest microsecond: the whole milliseconds by [vTaskDelay]
    and the rest by [delayMicroseconds]. The bounds of the running time of an
    operation are converted to microseconds outwards: a lower end that is not a
    whole number of microseconds is rounded down and closed, an upper end
    rounded up and closed, so that the monitor never rejects a running time
    within the declared bounds.

    {2 Monitors}

    Under the policy [Abort], a running time outside the bounds of its
    operation, a step of a periodic task that takes its period or longer, and a
    run-time error log their cause, call the safe-state hook once and halt the
    tasks; under [Warn] the first two are logged and the tasks go on, and under
    [Off] they are not checked. A run-time error halts the tasks under every
    policy.

    {2 Profile}

    With the build flag [TEMPORE_PROFILE], the monitors collect the least, mean
    and greatest running time of the calls of each operation and of the steps of
    each periodic task, the least and greatest interval between the starts of
    consecutive steps and the number of overruns, since start-up, and a task of
    the lowest priority logs them as a table every [TEMPORE_PROFILE_INTERVAL_MS]
    milliseconds (default 5000). The statistics are updated in a critical
    section after the clock is read, and the table is printed by a task of its
    own, outside the calls and steps it times; unlike the trace of
    [TEMPORE_TRACE], which logs each event, the profile does not lengthen the
    times it measures. *)

type monitor = Abort | Warn | Off

(** The effect of a top-level function, as the typechecker infers it. *)
type function_effect =
  | Not_a_function
  | Effect_variable  (** an effect with a variable *)
  | Effect of {
      grade : string;  (** the grade, printed *)
      durations : Grades.Grade.durations;  (** the durations of the grade *)
    }

type input = {
  device : ArduinoDevice.t;
  monitor : monitor;
  source : string;  (** the name of the source file of the program *)
  definitions : (Language.Ast.variable * function_effect) list;
      (** the top-level definitions of the program's sources, in order, each
          with the effect of its type *)
  operations :
    (Language.Ast.operation
    * (Grades.Rational.t Grades.Grade.bound
      * Grades.Rational.t Grades.Grade.bound)
      option)
    list;
      (** the declared operations, each with the bounds of its running time, if
          any *)
  file_text : ArduinoDevice.name -> string;
      (** the text of a file the manifest names: its binding file or one of its
          host models *)
  profile : bool;
      (** whether the project is built with the profile ([TEMPORE_PROFILE]) *)
}
(** What a project is made from. *)

val files : input -> ArduinoFragment.program -> (string * string) list
(** [files input program] is the files of the project of [program], each with
    its path in the project.

    @raise Utils.Error.Error
      at the place of the manifest that does not fit the program: an unknown
      board, package or function, a package listed twice or requiring a
      capability the board lacks, a core beyond those of the board, a task
      function of the wrong type, the function of a repeated free task whose
      effect does not bound its durations below by a positive time, the function
      of a periodic task whose effect has a variable or does not bound its
      durations below the period (the upper end of
      {!Grades.Grade.S.duration_bounds} of the effect is below the period, or
      equal to it and open, so that the effect is below the durations from 0 to
      [P], [P] excluded), a periodic task with a state other than [unit] and no
      initial function, an operation performed that no package binds without a
      binding file, a binding function or the safe-state hook that the binding
      file does not mention, a binding function of a package that the binding
      file mentions, and a binding file or host model that is not a C++ file
      ending in .cpp or has the name of a file of a package or of another host
      model, or a package binding an operation that another package of the
      manifest binds.

    Under a grade system that does not bound durations
    ({!Grades.Grade.Untimed}), the durations of the functions of periodic and
    repeated free tasks are not checked: the period of a step is checked only by
    the monitor of the device, and a repeated free task is not shown to yield.
*)

val host_sources : (string * string) list -> string list
(** [host_sources files] is the paths of the C++ sources of the project [files]
    that its host build compiles: those of [src/] and of [host/]. *)

val host_build_command :
  ?profile:bool ->
  directory:string ->
  output:string ->
  (string * string) list ->
  string list
(** [host_build_command ~directory ~output files] is the command, as a list of
    its words, that compiles the project [files] written to [directory] for the
    host simulation into the executable [output], with [c++] under C++17 without
    the contraction of floating-point expressions into fused multiply-adds,
    [TEMPORE_HOST] and [TEMPORE_TRACE] defined, and threads; under [~profile]
    (default [false]), with [TEMPORE_PROFILE] in place of [TEMPORE_TRACE]. The
    executable takes the simulated duration in microseconds as its argument and
    prints the log of the device, with the events of the tasks traced, or under
    [~profile] with the profile every 5 simulated seconds and at the end of the
    simulation. *)
