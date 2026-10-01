(** Constraint generation in checking mode.

    [generate_expression env e expected] is a constraint over the unknowns of
    [expected] and of [env] that holds exactly when [e] has, in [env], a subtype
    of the expected type. The expected type is an upper bound: it is the
    right-hand side of a subtyping or ordering atom wherever a rule meets it,
    and is passed on to the subterms otherwise. Every type or grade a rule
    leaves undetermined is a fresh unknown of an [Exists] scope around the
    rule's constraint; each handled operation's clause is generated under a
    [Forall_eps] of the clause's continuation effect.

    Each expected bound comes with the reason of the construct that set it; an
    atom against the bound carries that reason with the term as its subject.

    The context is a stack of bindings [x : A] and locks [⟨ρ⟩] of resource
    grades; a variable bound under locks [⟨ρ₁⟩ … ⟨ρₙ⟩] is used with the grade
    [ρ₁ · … · ρₙ] accumulated since its binding. A handler clause and a default
    implementation are generated under the lock [⟨⊤⟩], and so is the body of a
    recursive function, which uses the function itself under any locks.
    Top-level definitions and primitives are not in the context but in a table
    of schemes, and are used under any locks. *)

module Ast = Language.Ast
module Location = Utils.Location

module Make (C : Constraint.S) : sig
  type rho = C.rho
  (** Resource-grade expressions. *)

  type eps = C.eps
  (** Effect-grade expressions. *)

  type ty = C.ty
  (** Open value types. *)

  type comp_ty = C.comp_ty
  (** Open computation types. *)

  type reason = C.reason
  (** Reasons. *)

  (** {2 Program syntax} *)

  type program_rho = C.X.GS.R.t Ast.rho
  (** The resource grades of programs. *)

  type program_eps = C.X.GS.E.t Ast.eps
  (** The effect grades of programs. *)

  type program_ty = (program_rho, program_eps) Ast.ty
  (** The types of programs. *)

  type expression = (program_rho, program_eps) Ast.expression
  (** Expressions. *)

  type computation = (program_rho, program_eps) Ast.computation
  (** Computations. *)

  type abstraction = (program_rho, program_eps) Ast.abstraction
  (** Abstractions. *)

  (** {2 Environments} *)

  type ty_definition = {
    params : Ast.ty_param list;
    definition : (rho, eps) Ast.ty_def;
    strictly_positive : bool list;
        (** for each parameter, whether it occurs only strictly positively *)
  }
  (** A type definition, [TySum] for a variant type, [TyInline] for an alias. *)

  type op_signature = {
    param : ty;  (** the parameter type *)
    arity : ty;  (** the result type *)
    op_grade : eps;  (** the effect grade *)
    signature_at : Location.t;  (** the [operation] command *)
  }
  (** An operation signature. *)

  type env
  (** An environment: the context, the schemes of top-level definitions and
      primitives with the operations each may perform, the type definitions, the
      operation signatures and running-time bounds, and the default
      implementations of operations. *)

  val initial_env : env
  (** The environment of the built-in types [bool], [nat], [unit], [string],
      [float], [empty] and [list], and nothing else, in a program that declares
      no operations. *)

  val declare_operations :
    (string * Grades.Grade.running_time option) list -> env -> env
  (** [declare_operations declarations env] is [env] in a program whose
      operation declarations are [declarations], each an operation name with its
      running-time bounds if it declares them, the first declaration of a name
      counting. The operations it declares with running-time bounds, its atomic
      operations under the grades that read them, are the closed world of
      {!running_times}, whichever command is checked. *)

  val running_times : loc:Location.t -> env -> Grades.Grade.bounds
  (** [running_times ~loc env] are the running times of the program of [env]:
      its operations are those the program declares with running-time bounds
      ({!declare_operations}), and the running time of an event is its declared
      running-time bounds, or else those implied by the grade of a compound
      operation declared so far; the running time of any other event is a typing
      error at [loc]. *)

  val open_rho : env -> program_rho -> rho
  (** [open_rho env rho] is the program grade [rho] as an open expression.
      @raise Utils.Error.Error
        if a grade of [rho] read from the source is not
        {!Grades.Grade.S.inhabited} under the operations declared in [env]. *)

  val open_eps : env -> program_eps -> eps
  (** [open_eps env eps] is the program grade [eps] as an open expression.
      @raise Utils.Error.Error as {!open_rho}. *)

  val open_ty : env -> program_ty -> ty
  (** [open_ty env ty] is the program type [ty] as an open type.
      @raise Utils.Error.Error as {!open_rho}. *)

  val add_type_definitions :
    loc:Location.t ->
    env ->
    Ast.eternality
    * (Ast.ty_param list * Ast.ty_name * (program_rho, program_eps) Ast.ty_def)
      list ->
    env
  (** [add_type_definitions ~loc env (eternality, defs)] adds the mutually
      recursive definitions [defs], declared [noneternal] when [eternality] is
      [Noneternal], and records the polarities of their parameters, the greatest
      fixpoint.
      @raise Utils.Error.Error
        if an alias is declared [noneternal], a type is applied to the wrong
        number of arguments, or a type of [defs] occurs in one of them other
        than strictly positively: in the domain of a function type, in the input
        type of a handler type, in an argument of a type of [defs], or in an
        argument of another type at a parameter not strictly positive. *)

  val add_operation_signature :
    loc:Location.t ->
    env ->
    Ast.operation
    * program_ty
    * program_ty
    * program_eps
    * Grades.Grade.running_time option ->
    env
  (** [add_operation_signature ~loc env (op, param, arity, grade, bounds)] adds
      the signature of [op] and its running-time bounds, declared or implied by
      its grade.
      @raise Utils.Error.Error
        if the bounds are missing, superfluous or malformed for the grade, or
        the parameter or result type contains a function or handler type, the
        definitions of types being unfolded. *)

  val add_global :
    env ->
    Ast.variable ->
    defined_at:Location.t option ->
    performs:Ast.OpNameSet.t ->
    C.scheme ->
    env
  (** [add_global env x ~defined_at ~performs scheme] adds the top-level
      definition or primitive [x] of scheme [scheme], which may perform the
      operations [performs] ({!DefaultGraph.expression}). *)

  val load_primitive :
    env -> Ast.variable -> Language.Primitives.primitive -> env
  (** [load_primitive env x prim] adds the primitive [prim] as [x]. *)

  val add_operation_default :
    env -> Ast.operation -> DefaultGraph.default -> env
  (** [add_operation_default env op default] records [default] as the default
      implementation of [op]. *)

  val global_performs : env -> Ast.variable -> Ast.OpNameSet.t
  (** [global_performs env x] is the operations the top-level definition [x] may
      perform, none for a primitive or a variable not defined at the top level.
  *)

  val find_operation_default :
    env -> Ast.operation -> DefaultGraph.default option
  (** [find_operation_default env op] is the default implementation of [op]. *)

  val bind : env -> Ast.variable -> ty -> bound_at:Location.t -> env
  (** [bind env x ty ~bound_at] extends the context by [x : ty]. *)

  val bind_persistent : env -> Ast.variable -> ty -> bound_at:Location.t -> env
  (** [bind_persistent env x ty ~bound_at] extends the context by [x :[⊤] ty],
      used under any locks with an implicit unbox. *)

  val lock : env -> rho Reason.lock -> env
  (** [lock env l] extends the context by the lock [⟨l.grade⟩]. *)

  val find_type_definition : env -> Ast.ty_name -> ty_definition option
  (** [find_type_definition env name] is the definition of [name]. *)

  val datatype_constructors : env -> Ast.label -> (Ast.label * bool) list
  (** [datatype_constructors env lbl] is every constructor of the datatype of
      [lbl], each with whether it takes an argument; none if [lbl] is unknown.
  *)

  val is_noneternal : env -> Ast.ty_name -> bool
  (** [is_noneternal env name] is whether [name] is declared [noneternal]. *)

  val find_op_signature : env -> Ast.operation -> op_signature option
  (** [find_op_signature env op] is the signature of [op]. *)

  val op_bounds : env -> Grades.Grade.running_time Utils.StringMap.t
  (** [op_bounds env] is the running-time bounds of the operations, by surface
      name: the running times the grades' order reads. *)

  (** {2 Generation} *)

  type 'a expected = { bound : 'a; because : reason }
  (** An expected type or effect, an upper bound, with the reason of the
      construct that set it. *)

  val generate_expression : env -> expression -> ty expected -> C.t
  (** [generate_expression env e expected] is the constraint that [e] has a
      subtype of [expected.bound] in [env].
      @raise Utils.Error.Error
        on a constructor applied to the wrong number of arguments, an unbox of
        other than a variable, or a case for an unknown operation. *)

  val generate_computation :
    env -> computation -> ty expected -> eps expected -> C.t
  (** [generate_computation env c ty eps] is the constraint that [c] has, in
      [env], a subtype of [ty.bound] and an effect below [eps.bound].
      @raise Utils.Error.Error as {!generate_expression}. *)

  val generate_top_let :
    env -> loc:Location.t -> Ast.variable -> expression -> ty * C.t
  (** [generate_top_let env ~loc x e] is a fresh type unknown [α] and the
      constraint that the definition [let x = e] at [loc] has type [α], [α]
      being free in it: the type to generalise. The type and grade variables of
      the annotations of [e] are bound at the top of the constraint. *)

  val generate_run : env -> loc:Location.t -> computation -> comp_ty * C.t
  (** [generate_run env ~loc c] is a computation type [α ! ε] of fresh unknowns
      and the constraint that [c] at [loc] has it, [α] and [ε] being free in it
      and the type and grade variables of the annotations of [c] bound at its
      top. *)

  val generate_default :
    env -> loc:Location.t -> Ast.operation -> abstraction -> C.t
  (** [generate_default env ~loc op abs] is the constraint that [abs] at [loc]
      implements [op]: under the lock [⟨⊤⟩], a function from the operation's
      parameter to its result type, of effect below the grade of the
      running-time bounds of [op] where it has any and its grade otherwise. The
      type and grade variables of the annotations of [abs] are bound at its top.
      @raise Utils.Error.Error
        if [op] is unknown, has a default already, or is not atomic. *)

  val generate_default_effect :
    env -> loc:Location.t -> Ast.operation -> abstraction -> ty * C.t
  (** [generate_default_effect env ~loc op abs] is the type [param → arity # ε]
      of [abs] at [loc] as a default implementation of [op], [ε] a fresh
      unknown, and the constraint of {!generate_default} with [ε] in place of
      the bound on its effect.
      @raise Utils.Error.Error if [op] is unknown. *)

  val check_default_duration :
    env -> loc:Location.t -> Ast.operation -> C.X.GS.E.t -> unit
  (** [check_default_duration env ~loc op grade] checks that the running-time
      bounds implied by the effect [grade] of the default implementation of [op]
      at [loc] lie within the running-time bounds [op] declares, each end
      compared with its strictness. It holds where [op] declares no running-time
      bounds or [grade] implies none ({!Grades.Grade.S.implied_bounds}).
      @raise Utils.Error.Error if it does not hold. *)
end
