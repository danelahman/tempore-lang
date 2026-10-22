(** What a run state shows at the end of a top-level [run] command. *)
type ending =
  | Ongoing  (** the state is not the end of a run *)
  | Returned  (** the run has returned a value *)
  | Failed
      (** the run has ended at an operation call without a handler or a default
          implementation, or at a computation that does not reduce *)

module type S = sig
  include Backend.S

  val view_run_state : run_state -> steps:step list -> run_num:int -> ending
  (** [view_run_state state ~steps ~run_num] prints [state], whose steps are
      [steps], as the end of the run [run_num] if it is the end of a run, and is
      how the run ended. *)

  val observe : run_state -> step -> Backend.observation list
  (** [observe state step] is what [step] from [state] shows of the operations
      performed, the delays and the resources boxed and unboxed, in order. *)
end
