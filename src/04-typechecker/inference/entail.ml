(* Entailment of grade orderings from hypotheses. *)

module Make (X : GradeExp.S) = struct
  module N = GradeNormal.Make (X)

  type 'a hyps = 'a N.hyps

  type 'a t = {
    bounds : Grades.Grade.bounds;
    rho_with : X.rho -> X.rho -> (X.rho, 'a) GradeNormal.ordering list;
        (* hypotheses that include those between two given sides *)
    eps_with : X.eps -> X.eps -> (X.eps, 'a) GradeNormal.ordering list;
    rho : (X.rho -> X.rho -> 'a list option) Lazy.t;
    eps : (X.eps -> X.eps -> 'a list option) Lazy.t;
    rho_atomic : (X.rho -> X.rho -> 'a list option) Lazy.t;
    eps_atomic : (X.eps -> X.eps -> 'a list option) Lazy.t;
  }

  let make bounds (hyps : _ hyps) =
    {
      bounds;
      rho_with = (fun _ _ -> hyps.rho_hyps);
      eps_with = (fun _ _ -> hyps.eps_hyps);
      rho = lazy (N.Rho.decide_leq bounds hyps);
      eps = lazy (N.Eps.decide_leq bounds hyps);
      rho_atomic = lazy (N.Rho.decide_leq_atomic bounds hyps);
      eps_atomic = lazy (N.Eps.decide_leq_atomic bounds hyps);
    }

  (* The first of [e] and [e'] that has a variable, by [some_var]. *)
  let either some_var e e' =
    match some_var e with Some _ as v -> v | None -> some_var e'

  let eps_var eps = X.Eps.fold_vars (fun v _ -> Some v) eps None

  let make_indexed bounds (index : _ N.index) =
    let hyps = index.hyps in
    let rho_var rho =
      X.Rho.fold_vars
        ~on_rho:(fun v _ -> Some (Either.Left v))
        ~on_eps:(fun v _ -> Some (Either.Right v))
        rho None
    in
    {
      bounds;
      rho_with =
        (fun e e' ->
          match either rho_var e e' with
          | Some (Either.Left v) -> index.rho_of v
          | Some (Either.Right v) -> index.rho_of_image v
          | None -> (Lazy.force hyps).rho_hyps);
      eps_with =
        (fun e e' ->
          match either eps_var e e' with
          | Some v -> index.eps_of v
          | None -> (Lazy.force hyps).eps_hyps);
      rho = lazy (N.Rho.decide_leq bounds (Lazy.force hyps));
      eps = lazy (N.Eps.decide_leq bounds (Lazy.force hyps));
      rho_atomic = lazy (N.Rho.decide_leq_atomic_indexed bounds index);
      eps_atomic = lazy (N.Eps.decide_leq_atomic_indexed bounds index);
    }

  module type SORT = sig
    type exp

    val closed : Grades.Grade.bounds -> exp -> exp -> bool option
    val derive : 'a t -> exp -> exp -> 'a list option
    val follows : 'a t -> exp -> exp -> bool
    val follows_atomic : 'a t -> exp -> exp -> bool
    val decided : Grades.Grade.bounds -> exp -> exp -> bool
    val valid : Grades.Grade.bounds -> exp -> exp -> bool
    val is_atom : exp -> bool
    val refute_leq_unit : Grades.Grade.bounds -> exp -> bool
  end

  (* The queries of one sort, from its normal forms, its expressions' equality
     and its part of an entailment. *)
  module Sort (S : sig
    include N.SORT

    val equal_exp : Grades.Grade.bounds -> exp -> exp -> bool
    val orderings : 'a t -> exp -> exp -> (exp, 'a) GradeNormal.ordering list
    val derivation : 'a t -> (exp -> exp -> 'a list option) Lazy.t
    val atomic_derivation : 'a t -> (exp -> exp -> 'a list option) Lazy.t
  end) : SORT with type exp = S.exp = struct
    type exp = S.exp

    let closed = S.closed_leq
    let derive t = Lazy.force (S.derivation t)

    let follows t e e' =
      closed t.bounds e e' = Some true || Option.is_some (derive t e e')

    let follows_atomic t e e' =
      List.exists
        (fun (o : _ GradeNormal.ordering) ->
          S.equal_exp t.bounds o.lhs e && S.equal_exp t.bounds o.rhs e')
        (S.orderings t e e')
      || closed t.bounds e e' = Some true
      || Option.is_some (Lazy.force (S.atomic_derivation t) e e')

    let decided bounds =
      let derive = S.decide_leq bounds N.no_hyps in
      fun e e' ->
        match closed bounds e e' with
        | Some leq -> leq
        | None -> Option.is_some (derive e e')

    let valid bounds =
      let decided = decided bounds in
      fun e e' -> S.equal_exp bounds e e' || decided e e'

    let is_atom = S.is_atom
    let refute_leq_unit bounds e = Option.is_some (S.refute_leq_unit bounds e)
  end

  module Rho = Sort (struct
    include N.Rho

    let equal_exp = X.Rho.equal
    let orderings t = t.rho_with
    let derivation t = t.rho
    let atomic_derivation t = t.rho_atomic
  end)

  module Eps = Sort (struct
    include N.Eps

    let equal_exp = X.Eps.equal
    let orderings t = t.eps_with
    let derivation t = t.eps
    let atomic_derivation t = t.eps_atomic
  end)

  type 'a closed_failure = 'a N.closed_failure =
    | Rho_failure of (X.rho, 'a list) GradeNormal.ordering
    | Eps_failure of (X.eps, 'a list) GradeNormal.ordering

  let check_closed = N.check_closed_hyps
end
