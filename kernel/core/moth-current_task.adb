package body Moth.Current_Task with
   Spark_Mode     => On,
   Refined_State => (State  => (os_task_current))
is
   ---------------------
   -- os_task_current --
   ---------------------

   os_task_current : os_task_id_param_t;

   ----------------------------------------------------
   -- Set the id of the current running/elected task --
   ----------------------------------------------------

   procedure set_current_task_id (task_id : os_task_id_param_t) is
   begin
      os_task_current := task_id;
   end set_current_task_id;

   -------------------------
   -- get_current_task_id --
   -------------------------

   function get_current_task_id return os_task_id_param_t is
      (os_task_current);

begin
   os_task_current := OS_TASK_ID_MIN;
end Moth.Current_Task;
