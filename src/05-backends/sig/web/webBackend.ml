module type S = sig
  include Backend.S

  val view_step_label : step_label -> 'a Vdom.vdom
  val view_run_state : run_state -> step_label option -> 'a Vdom.vdom
  val is_end_of_run_label : step_label -> bool
  val is_done : run_state -> bool

  val observe : run_state -> step_label -> Backend.observation option
  (** [observe state label] is what the step labelled [label] from [state] shows
      of the operations performed, the time passed and the resources boxed and
      unboxed, if anything. *)
end
