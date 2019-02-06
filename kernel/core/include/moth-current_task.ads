
package Moth.Current_Task with
   Spark_Mode     => On,
   Abstract_State => State
is

   ----------------------------------------------------
   -- Set the id of the current running/elected task --
   ----------------------------------------------------

   procedure set_current_task_id
      (task_id : os_task_id_param_t) with
       Global => (Output => State);

   ----------------------------------------------------
   -- Get the id of the current running/elected task --
   ----------------------------------------------------

   function get_current_task_id return os_task_id_param_t with
       Global => (Input => State);
   pragma Export (C, get_current_task_id, "os_sched_get_current_task_id");

end Moth.Current_Task;
