module Location = Utils.Location

type ty_name = string

let bool_ty_name = "bool"
let nat_ty_name = "nat"
let unit_ty_name = "unit"
let string_ty_name = "string"
let float_ty_name = "float"
let list_ty_name = "list"
let empty_ty_name = "empty"

type 'a annotated = 'a Location.located = { it : 'a; at : Location.t }
type ty_param = string
type grade_param = string

(** A grade as written, over the grades ['g] a literal is read as. *)
type 'g grade =
  | GradeLit of 'g  (** a literal *)
  | GradeParam of grade_param  (** ['e] *)

type ('rho, 'eps) ty = ('rho, 'eps) plain_ty annotated

and ('rho, 'eps) plain_ty =
  | TyConst of Language.Const.ty
  | TyApply of ty_name annotated * ('rho, 'eps) ty list
      (** [(ty1, ty2, ..., tyn) type_name] *)
  | TyParam of ty_param  (** ['a] *)
  | TyArrow of ('rho, 'eps) ty * ('rho, 'eps) plain_comp_ty
      (** [ty1 -> ty2 ! eps] *)
  | TyTuple of ('rho, 'eps) ty list  (** [ty1 * ty2 * ... * tyn] *)
  | TyBox of 'rho * ('rho, 'eps) ty  (** [ [rho]ty ] *)
  | TyHandler of ('rho, 'eps) plain_comp_ty * ('rho, 'eps) plain_comp_ty

and ('rho, 'eps) plain_comp_ty =
  | CompTy of ('rho, 'eps) ty * 'eps  (** [ty ! eps] *)

type variable = string
type label = string
type operation = string

let nil_label = Language.Ast.nil_label_string
let cons_label = Language.Ast.cons_label_string

type ('rho, 'eps) pattern = ('rho, 'eps) plain_pattern annotated

and ('rho, 'eps) plain_pattern =
  | PVar of variable
  | PAnnotated of ('rho, 'eps) pattern * ('rho, 'eps) ty
  | PAs of ('rho, 'eps) pattern * variable annotated
  | PTuple of ('rho, 'eps) pattern list
  | PVariant of label annotated * ('rho, 'eps) pattern option
  | PConst of Language.Const.t
  | PSucc of ('rho, 'eps) pattern * Z.t
  | PNonbinding

type ('rho, 'eps) term = ('rho, 'eps) plain_term annotated

and ('rho, 'eps) plain_term =
  | Var of variable  (** variables *)
  | Const of Language.Const.t  (** integers, strings, booleans, and floats *)
  | Annotated of ('rho, 'eps) term * ('rho, 'eps) ty
  | Tuple of ('rho, 'eps) term list  (** [(t1, t2, ..., tn)] *)
  | Variant of label annotated * ('rho, 'eps) term option
      (** [Label] or [Label t] *)
  | Lambda of ('rho, 'eps) abstraction  (** [fun p1 p2 ... pn -> t] *)
  | PureLambda of ('rho, 'eps) abstraction  (** [fun p1 p2 ... pn -> t] *)
  | Function of ('rho, 'eps) abstraction list
      (** [function p1 -> t1 | ... | pn -> tn] *)
  | Let of ('rho, 'eps) pattern * ('rho, 'eps) term * ('rho, 'eps) term
      (** [let p = t1 in t2] *)
  | LetRec of variable annotated * ('rho, 'eps) term * ('rho, 'eps) term
      (** [let rec f = t1 in t2] *)
  | Match of ('rho, 'eps) term * ('rho, 'eps) abstraction list
      (** [match t with p1 -> t1 | ... | pn -> tn] *)
  | Conditional of ('rho, 'eps) term * ('rho, 'eps) term * ('rho, 'eps) term
      (** [if t then t1 else t2] *)
  | Apply of ('rho, 'eps) term * ('rho, 'eps) term  (** [t1 t2] *)
  | Delay of Grades.Rational.t  (** [delay q] **)
  | Box of 'rho * ('rho, 'eps) term * ('rho, 'eps) abstraction
      (** [box rho expr as v in n] *)
  | GenBox of 'rho * ('rho, 'eps) term  (** [box rho expr] *)
  | Unbox of ('rho, 'eps) term * ('rho, 'eps) abstraction
      (** [unbox expr as v in n] *)
  | GenUnbox of ('rho, 'eps) term  (** [unbox expr] *)
  | Perform of operation annotated * ('rho, 'eps) term  (** [perform op expr] *)
  | Handler of
      ('rho, 'eps) abstraction * (operation * ('rho, 'eps) abstraction) list
  | Continue of ('rho, 'eps) term * ('rho, 'eps) term
  | AnnotatedComp of ('rho, 'eps) term * ('rho, 'eps) ty * 'eps
      (** [fun p -> t : ty # eps]: the body of a function annotated with its
          computation type, result type and grade *)
  | Handle of ('rho, 'eps) term * ('rho, 'eps) term

and ('rho, 'eps) abstraction = ('rho, 'eps) pattern * ('rho, 'eps) term

and ('rho, 'eps) guarded_abstraction =
  ('rho, 'eps) pattern * ('rho, 'eps) term option * ('rho, 'eps) term

type ('rho, 'eps) ty_def =
  | TySum of (label annotated * ('rho, 'eps) ty option) list
      (** [Label1 of ty1 | Label2 of ty2 | ... | Labeln of tyn | Label' |
           Label''] *)
  | TyInline of ('rho, 'eps) ty  (** [ty] *)

type ('rho, 'eps) command = ('rho, 'eps) plain_command annotated

and ('rho, 'eps) plain_command =
  | TyDef of
      Language.Ast.eternality
      * (ty_param list * ty_name annotated * ('rho, 'eps) ty_def) list
      (** [type ('a...1) t1 = def1 and ... and ('a...n) tn = defn], optionally
          prefixed by [noneternal] *)
  | OpSig of
      (operation annotated
      * ('rho, 'eps) ty
      * ('rho, 'eps) ty
      * 'eps
      * Grades.Grade.runtime option)
      (** [operation op : t1 -> t2 # rho within (lo, hi)]; the runtime bounds
          are optional and only the grading monoids with costs use them *)
  | OpDefault of operation * ('rho, 'eps) abstraction
      (** [default Op p = t]; the implementation the operation falls back on
          when it reaches the top level unhandled *)
  | TopLet of variable annotated * ('rho, 'eps) term  (** [let x = t] *)
  | TopLetRec of variable annotated * ('rho, 'eps) term  (** [let rec f = t] *)
  | TopDo of ('rho, 'eps) term  (** [do t] *)
