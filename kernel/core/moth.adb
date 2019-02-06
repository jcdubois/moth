
with os_arch;
with Moth.scheduler;
with Moth.Mailbox;

package body Moth with
   Spark_Mode     => On
is

   function os_ghost_mbx_are_well_formed return Boolean
   is (Moth.Mailbox.os_ghost_mbx_are_well_formed);

   function os_ghost_task_list_is_well_formed return Boolean
   is (Moth.Scheduler.os_ghost_task_list_is_well_formed);

   function os_ghost_current_task_is_ready return Boolean
   is (Moth.Scheduler.os_ghost_current_task_is_ready);

   procedure init (task_id : out os_task_id_param_t) is
   begin
      --  Init the console if any
      os_arch.cons_init;

      --  Init the MMU
      os_arch.space_init;

      --  Init all mailboxes
      Moth.Mailbox.init;

      --  Init the task list.
      Moth.Scheduler.init (task_id);

   end init;

end Moth;
