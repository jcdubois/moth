
package body Moth.Config with
   Spark_Mode     => On,
   Refined_State => (State => (os_task_ro))
is
   subtype os_virtual_address_t is types.uint32_t;

   subtype os_size_t is types.uint32_t;

   type os_task_section_t is record
      virtual_address : os_virtual_address_t;
      size            : os_size_t;
   end record;
   pragma Convention (C_Pass_By_Copy, os_task_section_t);

   type os_task_ro_t is record
      priority       : os_priority_t;
      mbx_permission : os_mbx_mask_t;
      text           : os_task_section_t;
      bss            : os_task_section_t;
      stack          : os_task_section_t;
   end record;
   pragma Convention (C_Pass_By_Copy, os_task_ro_t);

   ----------------
   -- os_task_ro --
   ----------------

   os_task_ro : constant array (os_task_id_param_t) of os_task_ro_t;
   pragma Import (C, os_task_ro, "os_task_ro");

   ------------------------
   -- get_mbx_permission --
   ------------------------

   function get_mbx_permission
      (task_id : os_task_id_param_t) return os_mbx_mask_t is
      (os_task_ro (task_id).mbx_permission);

   -----------------------
   -- get_task_priority --
   -----------------------

   function get_task_priority
     (task_id : os_task_id_param_t) return os_priority_t is
     (os_task_ro (task_id).priority);

end Moth.Config;
