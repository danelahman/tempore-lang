(** PlatformIO projects of devices programmed in Tempore.

    A project compiles a program ({!ArduinoEmit}) for the board and the tasks of
    a device manifest ({!ArduinoDevice}), with the board profile
    ({!ArduinoBoard}), the scaffold and the bindings of the application.

    {2 Files}

    - [platformio.ini]: the environment of the board
      ({!ArduinoBoard.platformio_ini});
    - [src/tempore_arduino.h], [src/tempore_program.h],
      [src/tempore_program.cpp]: the compiled program;
    - [src/tempore_scaffold.h], [src/tempore_scaffold.cpp]: the scaffold, the
      same for every device: the clock ([esp_timer_get_time]), the log on the
      serial port, delays, the monitors and the halt of the tasks;
    - [src/tempore_bindings.h]: the declarations of the binding functions and of
      the safe-state hook, which the binding file includes;
    - [src/tempore_operations.cpp]: the function [tempore_op_Op] of each
      operation [Op] the program performs, which calls the binding function
      [binding_Op] ({!ArduinoNames.binding}) and checks its running time against
      the bounds of the operation;
    - [src/main.cpp]: the configuration, [setup()], which initialises the board
      and creates a FreeRTOS task for each task of the manifest, and [loop()],
      which deletes its own task;
    - the binding file of the manifest, in [src/];
    - [host/]: the stubs of Arduino, FreeRTOS, the timer of the ESP32, [Wire]
      and M5Unified, and the discrete-event simulator [tempore_simulator.cpp],
      with which the sources of [src/] build and run on the host
      ({!host_build_command}).

    {2 Tasks}

    A periodic task of period [P] calls the initial function, if any, once, and
    then its function at every release, from the tick at which it starts, with
    [vTaskDelayUntil]; the running time of each call is checked against [P]. A
    free task calls its function once and is deleted when it returns. Each task
    first checks whether the tasks are halted, and stops if they are.

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
    policy. *)

type monitor = Abort | Warn | Off

(** The effect of a top-level function, as the typechecker infers it. *)
type function_effect =
  | Not_a_function
  | Effect_variable  (** an effect with a variable *)
  | Effect of {
      grade : string;  (** the grade, printed *)
      durations :
        (Grades.Rational.t Grades.Grade.bound
        * Grades.Rational.t Grades.Grade.bound)
        option;
          (** the interval of the durations of the grade, if it bounds them *)
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
  bindings : (string * string) option;
      (** the name and the text of the binding file of the manifest, if any *)
}
(** What a project is made from. *)

val files : input -> ArduinoFragment.program -> (string * string) list
(** [files input program] is the files of the project of [program], each with
    its path in the project.

    @raise Utils.Error.Error
      at the place of the manifest that does not fit the program: an unknown
      board, package or function, a core beyond those of the board, a task
      function of the wrong type, the function of a periodic task whose effect
      has a variable or does not bound its durations below the period (the
      upper end of {!Grades.Grade.S.duration_bounds} of the effect is below the
      period, or equal to it and open, so that the effect is below [[0, P)]), a
      periodic task with a state other than [unit] and no initial function, an
      operation performed without a binding file, and a binding function or the
      safe-state hook that the binding file does not mention. *)

val host_sources : (string * string) list -> string list
(** [host_sources files] is the paths of the C++ sources of the project [files]
    that its host build compiles: those of [src/] and the simulator. *)

val host_build_command :
  directory:string -> output:string -> (string * string) list -> string list
(** [host_build_command ~directory ~output files] is the command, as a list of
    its words, that compiles the project [files] written to [directory] for the
    host simulation into the executable [output], with [c++] under C++17,
    [TEMPORE_HOST] and [TEMPORE_TRACE] defined, and threads. The executable
    takes the simulated duration in microseconds as its argument and prints the
    log of the device, with the events of the tasks traced. *)
