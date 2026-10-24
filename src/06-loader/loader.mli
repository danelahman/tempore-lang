(** Loading programs: parsing, desugaring, typechecking and running their
    commands.

    A program is loaded in two passes. First all its sources, the standard
    library included, are parsed, and the operation declarations are collected
    from them, the name and running-time bounds of each operation only
    ([Loader.declare]); the grades of every command are read over these
    operations, whether declared before or after the command. Then the sources
    are desugared, typechecked and run command by command, in order, so that an
    operation is still performed only after its declaration. *)

val declared_operations :
  ('a, 'b) SugaredAst.command list ->
  (string * Grades.Grade.running_time option) list
(** [declared_operations commands] is the operation declarations of [commands],
    in order, each the name of the operation with its running-time bounds if it
    declares them. Only these are read, so that an operation declared with a
    malformed or ill-typed signature is listed all the same. *)

val with_running_times :
  (module Grades.Grade.S with type t = 'e) ->
  filename:string ->
  (string * Grades.Grade.running_time) list ->
  ('r, 'e SugaredAst.grade Language.Ast.located) SugaredAst.command list ->
  ('r, 'e SugaredAst.grade Language.Ast.located) SugaredAst.command list
(** [with_running_times (module E) ~filename running_times commands] is
    [commands], parsed from the source [filename] under the effect grades [E],
    with the running-time bounds of each operation of [running_times] replaced:
    those of its [within], if it declares them, and else those of its grade, if
    it is the grade of its bounds ({!Grades.Grade.S.of_bounds}), by the grade of
    the new bounds. An operation whose grade bounds no durations, as under the
    operation counts, keeps its declaration.

    @raise Utils.Error.Error
      if [commands] declare no operation of [running_times], if the grade of an
      operation bounds durations but is not that of its bounds, or if the delays
      of [E] do not read a bound. *)

val grades_of_sources :
  grades:string ->
  (string * string) list ->
  (module Grades.Grade.S) * Grades.LevelLattice.t option
(** [grades_of_sources ~grades sources] is the grade [grades] of
    {!Grades.GradeRegistry.grade_modules} for the program made of [sources],
    each a file name and a text, with the lattice of levels the program
    declares: that of the first declaration of levels among [sources], over
    which a grade built on levels is built
    ({!Grades.GradeRegistry.over_levels}), and [None] if there is none. The
    parser checks that every other declaration declares the same lattice.

    @raise Utils.Error.Error
      if the first declaration is not a lattice
      ({!Grades.LevelLattice.of_chains}) or if the grade is not built on levels.
    @raise Invalid_argument if the grade is unknown. *)

val stdlib_filename : string
(** The file name the standard library's locations are reported under, since it
    is loaded from a string rather than from a file. *)

val stdlib_source : string
(** The standard library's source, independently of any backend, for callers
    that need to know what precedes a program's own source. *)

(** The loader of the programs of a backend. *)
module Loader (Backend : Backend.S) : sig
  (** The typechecker of the grade system of the backend. *)
  module TC : sig
    type scheme
    type state

    val definitions : state -> (Language.Ast.variable * scheme) list
    (** The top-level definitions of a state, with their schemes. *)

    val print_scheme : state -> scheme -> Format.formatter -> unit
    (** [print_scheme state scheme] prints [scheme]. *)

    val scheme_layout : state -> scheme -> Inference.Constraint.layout
    (** [scheme_layout state scheme] is [scheme] laid out in parts. *)

    val function_effect : state -> scheme -> Typechecker.function_effect
    (** [function_effect state scheme] is the effect of the outermost arrow of
        the type of [scheme] ({!Typechecker.Make.function_effect}). *)
  end

  type state = {
    desugarer : Desugarer.Make(Backend.Grades).state;
    references : Desugarer.References.env;
    backend : Backend.load_state;
    typechecker : TC.state;
  }
  (** The state of a program being loaded. *)

  type command =
    ( Backend.Grades.R.t SugaredAst.grade Language.Ast.located,
      Backend.Grades.E.t SugaredAst.grade Language.Ast.located )
    SugaredAst.command
  (** A parsed command. *)

  val declare : ('a, 'b) SugaredAst.command list list -> state -> state
  (** [declare sources state] is [state] in the program made of the parsed
      [sources], all of which are to be loaded into it: the grades of every
      command are read over the operations these sources declare
      ({!Typechecker.Make.declare_operations}), before or after the command. *)

  val initial_state : state
  (** The state with the primitives loaded and nothing else. *)

  type definition = {
    variable : Language.Ast.variable;
    at : Utils.Location.t;  (** the location of the defining command *)
    scheme : TC.scheme;
  }
  (** A top-level definition the typechecker has accepted. *)

  val load_commands_all :
    state -> command list -> state * Utils.Diagnostic.t list
  (** Load the parsed source of a program {!declare}d, reporting every typing
      error it contains rather than only the first. Desugaring stays fatal: an
      unknown name would only cascade. *)

  val load_commands : state -> command list -> state
  (** Load the parsed source of a program {!declare}d, the first error escaping
      as an exception. *)

  val parse_source :
    ?filename:string ->
    ?running_times:(string * Grades.Grade.running_time) list ->
    string ->
    command list
  (** [parse_source ?filename ?running_times source] is the commands of
      [source], whose locations are reported under [filename], with the
      running-time bounds of the operations of [running_times] replaced
      ({!with_running_times}). *)

  val parse_file : string -> command list
  (** [parse_file filename] is the commands of the file [filename]. *)

  val stdlib_source : string
  (** The source of the standard library. *)

  type 'link program = {
    library : state;  (** the state after the standard library *)
    library_definitions : definition list;
        (** the top-level definitions of the standard library *)
    loaded : state;  (** the state after every source *)
    diagnostics : Utils.Diagnostic.t list;
        (** those of the sources, in order *)
    definitions : definition list;
        (** the top-level definitions of the sources accepted before the first
            error of each *)
    links : 'link list;
        (** the links of the names of the sources to their definitions *)
    commands : Language.Ast.Graded(Backend.Grades).command list;
        (** the desugared commands the typechecker accepted, those of the
            standard library first, in order *)
    operations :
      (Language.Ast.operation
      * (Grades.Rational.t Grades.Grade.bound
        * Grades.Rational.t Grades.Grade.bound)
        option)
      list;
        (** the operations the accepted commands declare, in order, each with
            the bounds of its running time, if any: those it declares, or else
            those its grade implies ({!Grades.Grade.S.duration_bounds}); the
            upper end may be infinite *)
    compound_operations : Language.Ast.operation list;
        (** the operations the accepted commands declare whose grade is not that
            of an atomic operation ({!Grades.Grade.S.is_atomic}), in order *)
  }
  (** A program loaded by {!load_program}. *)

  val load_program :
    use_stdlib:bool -> command list list -> Desugarer.References.link program
  (** [load_program ~use_stdlib sources] loads the parsed [sources] in order,
      preceded by the standard library if [use_stdlib], all of them {!declare}d
      first. Every source is loaded even when an earlier one has errors, so that
      all of them are reported at once. An error in the standard library is
      fatal. *)
end
