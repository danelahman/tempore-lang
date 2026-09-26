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
    grades; a variable bound under locks [⟨ρ₁⟩ … ⟨ρₙ⟩] is used after the elapsed
    grade [ρ₁ · … · ρₙ]. A handler clause and a default implementation are
    generated under the lock [⟨⊤⟩]. Top-level definitions and primitives are not
    in the context but in a table of schemes, and are used at any time. *)

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

  val open_rho : program_rho -> rho
  (** [open_rho rho] is the program grade [rho] as an open expression.
      @raise Invalid_argument if [rho] has a parameter. *)

  val open_eps : program_eps -> eps
  (** [open_eps eps] is the program grade [eps] as an open expression.
      @raise Invalid_argument if [eps] has a parameter or a rigid grade. *)

  val open_ty : program_ty -> ty
  (** [open_ty ty] is the program type [ty] as an open type. *)

  (** {2 Environments} *)

  type ty_definition = {
    params : Ast.ty_param list;
    definition : (rho, eps) Ast.ty_def;
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
      primitives, the type definitions, the operation signatures and runtime
      bounds, and the operations with a default implementation. *)

  val initial_env : env
  (** The environment of the built-in types [bool], [int], [unit], [string],
      [float], [empty] and [list], and nothing else. *)

  val add_type_definitions :
    loc:Location.t ->
    env ->
    Ast.eternality
    * (Ast.ty_param list * Ast.ty_name * (program_rho, program_eps) Ast.ty_def)
      list ->
    env
  (** [add_type_definitions ~loc env (eternality, defs)] adds the mutually
      recursive definitions [defs], declared [noneternal] when [eternality] is
      [Noneternal].
      @raise Utils.Error.Error
        if an alias is declared [noneternal] or a type is applied to the wrong
        number of arguments. *)

  val add_operation_signature :
    loc:Location.t ->
    env ->
    Ast.operation * program_ty * program_ty * program_eps * (int * int) option ->
    env
  (** [add_operation_signature ~loc env (op, param, arity, grade, bounds)] adds
      the signature of [op] and its runtime bounds, declared or implied by its
      grade.
      @raise Utils.Error.Error
        if the bounds are missing, superfluous or malformed for the grade. *)

  val add_global :
    env -> Ast.variable -> defined_at:Location.t option -> C.scheme -> env
  (** [add_global env x ~defined_at scheme] adds the top-level definition or
      primitive [x] of scheme [scheme]. *)

  val load_primitive :
    env -> Ast.variable -> Language.Primitives.primitive -> env
  (** [load_primitive env x prim] adds the primitive [prim] as [x]. *)

  val add_operation_default : env -> Ast.operation -> env
  (** [add_operation_default env op] records that [op] has a default
      implementation. *)

  val bind : env -> Ast.variable -> ty -> bound_at:Location.t -> env
  (** [bind env x ty ~bound_at] extends the context by [x : ty]. *)

  val lock : env -> rho Reason.elapsed -> env
  (** [lock env elapsed] extends the context by the lock [⟨elapsed.grade⟩]. *)

  val find_type_definition : env -> Ast.ty_name -> ty_definition option
  (** [find_type_definition env name] is the definition of [name]. *)

  val is_noneternal : env -> Ast.ty_name -> bool
  (** [is_noneternal env name] is whether [name] is declared [noneternal]. *)

  val find_op_signature : env -> Ast.operation -> op_signature option
  (** [find_op_signature env op] is the signature of [op]. *)

  val op_bounds : env -> (int * int) Utils.StringMap.t
  (** [op_bounds env] is the runtime bounds of the operations, by surface name:
      the cost model of the grades' order. *)

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
      being free in it: the type to generalise. *)

  val generate_run : env -> loc:Location.t -> computation -> comp_ty * C.t
  (** [generate_run env ~loc c] is a computation type [α ! ε] of fresh unknowns
      and the constraint that [c] at [loc] has it, [α] and [ε] being free in it.
  *)

  val generate_default :
    env -> loc:Location.t -> Ast.operation -> abstraction -> C.t
  (** [generate_default env ~loc op abs] is the constraint that [abs] at [loc]
      implements [op]: under the lock [⟨⊤⟩], a function from the operation's
      parameter to its result type, of effect below the grade of the runtime
      bounds of [op] where it has any and its grade otherwise.
      @raise Utils.Error.Error
        if [op] is unknown, has a default already, or is not atomic. *)
end
