(** The first-order fragment of Tempore that the Arduino backend compiles, and
    its typed intermediate representation.

    A program accepted by the typechecker is checked against the fragment
    definition by definition, starting from the top-level definitions of its
    sources and, if requested, its [run] commands, and continuing with the
    definitions of the program or of the standard library they use. The fragment
    consists of:

    - top-level functions, possibly curried, applied to all their arguments; the
      arguments of a curried application may be supplied through intermediate
      variables;
    - top-level constants, built from constants, tuples and constructors;
    - [let] and [do], [if] and [match], with patterns over tuples, constructors,
      constants and successors [n + k];
    - natural numbers, floats, booleans, the unit and tuples, and the
      constructors of datatypes without type parameters whose definitions are
      not recursive;
    - the primitives of arithmetic and comparison, comparisons at every type of
      the fragment;
    - recursive calls of a function to itself in tail position;
    - [box] and [unbox], whose grades are erased;
    - operation calls and [delay], compiled to calls of external functions;
      string constants are allowed in the arguments of operation calls only.

    Rejected are, among others, functions other than top-level definitions,
    functions used as values, partial applications, handlers, lists, strings
    elsewhere (also as results of operations and arguments of constructors),
    recursive calls outside tail position, and natural number literals of more
    than 32 bits. A rejection is a compilation {!Utils.Diagnostic.t} at the
    construct.

    Types are reconstructed by unification, with the top-level definitions
    generalised over the type variables of their types. A polymorphic definition
    is compiled once for each type it is used at. A type variable that no use
    determines is the unit type. *)

(** {1 Types} *)

type ty =
  | Nat
  | Int  (** an integer of 32 bits *)
  | Float
  | Bool
  | String
  | Tuple of ty list  (** the unit type is the empty tuple *)
  | Data of Language.Ast.ty_name
      (** a datatype without type parameters, not recursive *)
  | Meta of int  (** a type variable of the reconstruction *)

val compare_ty : ty -> ty -> int
(** A total order on types. *)

val substitute : (int -> ty option) -> ty -> ty
(** [substitute f ty] replaces each type variable [Meta i] of [ty] for which [f]
    gives a type by that type. *)

(** {1 Terms} *)

type global = {
  variable : Language.Ast.variable;  (** a top-level definition *)
  instance : ty list;
      (** the types of the quantified type variables of the definition *)
}
(** A use of a top-level definition at an instance of its type. *)

type value = { value : value_node; ty : ty }

and value_node =
  | Local of Language.Ast.variable
  | Global of global  (** a top-level constant *)
  | Constant of Language.Const.t
  | Tuple_value of value list
  | Construct of Language.Ast.label * value option

type pattern = { pattern : pattern_node; pattern_ty : ty }

and pattern_node =
  | PVar of Language.Ast.variable
  | PAs of pattern * Language.Ast.variable
  | PTuple of pattern list
  | PConstruct of Language.Ast.label * pattern option
  | PConstant of Language.Const.t
  | PSucc of pattern * Z.t  (** [p + k] *)
  | PAny

type callee =
  | Self  (** the function being defined, called in tail position *)
  | Function of global  (** a top-level function *)
  | Primitive of Language.Primitives.primitive

type computation = { computation : computation_node; result : ty }

and computation_node =
  | Return of value
  | Bind of pattern * computation * computation
  | Match of value * (pattern * computation) list
      (** the cases, in order; the last applies if none before it does *)
  | Call of callee * value list
      (** all the arguments of the function; the single argument of a primitive
      *)
  | Perform of Language.Ast.operation * value
  | Delay of Grades.Rational.t * computation

(** {1 Programs} *)

type body =
  | Function_body of {
      parameters : pattern list;
      body : computation;
      recursive : bool;  (** whether the body calls the function itself *)
    }
  | Constant_body of value

val map_computation : (ty -> ty) -> computation -> computation
(** [map_computation f c] is [c] with [f] applied to each of its types. *)

val map_body : (ty -> ty) -> body -> body
(** [map_body f b] is [b] with [f] applied to each of its types. *)

type definition = {
  variable : Language.Ast.variable;
  at : Utils.Location.t;
  in_sources : bool;
      (** whether the definition is in the program's sources rather than in the
          standard library *)
  quantified : int list;  (** the type variables the type is generalised over *)
  definition_body : body;
}

type datatype = {
  type_name : Language.Ast.ty_name;
  constructors : (Language.Ast.label * ty option) list;
      (** in the order {!Language.Ast.Label.compare} *)
  type_at : Utils.Location.t;  (** the location of the type definition *)
}

type operation = {
  operation : Language.Ast.operation;
  argument : ty;
  result_ty : ty;
}

type program = {
  definitions : definition list;  (** each after the definitions it uses *)
  runs : computation list;  (** the [run] commands, if requested, in order *)
  datatypes : datatype list;  (** those of the program and the library *)
  operations : operation list;  (** those the definitions and runs perform *)
}

val check :
  runs:bool ->
  library:('rho, 'eps) Language.Ast.command list ->
  ('rho, 'eps) Language.Ast.command list ->
  program
(** [check ~runs ~library sources] is the program of the desugared commands
    [library] of the standard library and [sources], accepted by the
    typechecker: the top-level definitions of [sources], with the [run] commands
    of [sources] if [runs], and the definitions they use.

    @raise Utils.Error.Error
      at the first construct outside the fragment, or at a use of a definition
      whose types cannot be reconstructed. *)
