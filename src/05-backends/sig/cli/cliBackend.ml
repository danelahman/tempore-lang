module type S = sig
  include Backend.S

  val view_run_state : run_state -> run_num:int -> bool

  val observe :
    bounds:Backend.bounds ->
    run_state ->
    step_label ->
    Backend.observation option
  (** [observe ~bounds state label] is what the step labelled [label] from
      [state] shows of the operations performed, the time passed and the
      resources boxed and unboxed, if anything, the resource grades ordered
      under the running times [bounds]. *)
end
