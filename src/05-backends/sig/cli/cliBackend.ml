module type S = sig
  include Backend.S

  val view_run_state : run_state -> run_num:int -> bool

  val observe : run_state -> step_label -> Backend.observation option
  (** [observe state label] is what the step labelled [label] from [state] shows
      of the operations performed, the time passed and the resources boxed and
      unboxed, if anything. *)
end
