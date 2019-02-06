
package Moth.Config with
   Spark_Mode     => On,
   Abstract_State => State
is

   subtype os_priority_t is types.uint8_t;

   ---------------------------------------------
   -- Get the MBX permission for a given task --
   ---------------------------------------------

   function get_mbx_permission
      (task_id : os_task_id_param_t) return os_mbx_mask_t with
       Global => (Input => State);

   ---------------------------------------
   -- Get the priority for a given task --
   ---------------------------------------

   function get_task_priority
     (task_id : os_task_id_param_t) return os_priority_t with
      Global => (Input => State);

end Moth.Config;
