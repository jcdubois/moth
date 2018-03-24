pragma SPARK_Mode;

with Interfaces;   use Interfaces;
with Interfaces.C; use Interfaces.C;
with os_arch;      use os_arch;
with types;        use types;

package body os is

   -----------------
   -- Private API --
   -----------------

   ---------------------
   -- os_task_current --
   ---------------------
   --  This variable holds the ID of the current elected task.
   --  Note: Its value could be OS_TASK_ID_NONE if no task is elected.

   os_task_current : os_task_id_t;

   -----------------------------
   -- os_task_ready_list_head --
   -----------------------------
   --  This variable holds the ID of the first task in the ready list (the
   --  next ne that will be elected).
   --  Note: Its value could be OS_TASK_ID_NONE if no task is ready.

   os_task_ready_list_head : os_task_id_t;

   -------------------------------
   -- os_mbx_get_mbx_permission --
   -------------------------------
   --  Get the mbx permission for a given task

   function os_mbx_get_mbx_permission
     (task_id : os_task_id_param_t) return os_mbx_mask_t
   is
   begin
      return os_task_ro (Natural (task_id)).mbx_permission;
   end os_mbx_get_mbx_permission;

   -----------------------------
   -- os_mbx_get_waiting_mask --
   -----------------------------
   --  Get a mask of task the given task is waiting mbx from

   function os_mbx_get_waiting_mask
     (task_id : os_task_id_param_t) return os_mbx_mask_t
   is
   begin
      return os_task_rw (Natural (task_id)).mbx_waiting_mask;
   end os_mbx_get_waiting_mask;

   -----------------------------
   -- os_mbx_set_waiting_mask --
   -----------------------------
   --  Set a mask of task the given task is waiting mbx from

   procedure os_mbx_set_waiting_mask
     (task_id : os_task_id_param_t;
      mask    : os_mbx_mask_t)
   is
   begin
      os_task_rw (Natural (task_id)).mbx_waiting_mask := mask;
   end os_mbx_set_waiting_mask;

   -------------------------
   -- os_mbx_inc_mbx_head --
   -------------------------
   --  Increment the mbx head index of the given task.

   procedure os_mbx_inc_mbx_head (task_id : os_task_id_param_t)
   is
   begin
      os_task_rw (Natural (task_id)).mbx.head :=
        (os_task_rw (Natural (task_id)).mbx.head + 1) mod OS_MAX_MBX_CNT;
   end os_mbx_inc_mbx_head;

   -------------------------
   -- os_mbx_get_mbx_head --
   -------------------------
   --  Retrieve the mbx head index of the given task.

   function os_mbx_get_mbx_head
     (task_id : os_task_id_param_t) return os_mbx_index_t
   is
   begin
      return os_task_rw (Natural (task_id)).mbx.head;
   end os_mbx_get_mbx_head;

   --------------------------
   -- os_mbx_get_mbx_count --
   --------------------------
   --  Retrieve the mbx count of the given task.

   function os_mbx_get_mbx_count
     (task_id : os_task_id_param_t) return os_mbx_count_t
   is
   begin
      return os_task_rw (Natural (task_id)).mbx.count;
   end os_mbx_get_mbx_count;

   --------------------------
   -- os_mbx_inc_mbx_count --
   --------------------------
   --  Increment the mbx count of the given task.

   procedure os_mbx_inc_mbx_count (task_id : os_task_id_param_t)
      with Pre => os_task_rw (Natural (task_id)).mbx.count < OS_MAX_MBX_CNT
   is
   begin
      os_task_rw (Natural (task_id)).mbx.count :=
        os_task_rw (Natural (task_id)).mbx.count + 1;
   end os_mbx_inc_mbx_count;

   --------------------------
   -- os_mbx_dec_mbx_count --
   --------------------------
   --  Derement the mbx count of the given task.

   procedure os_mbx_dec_mbx_count (task_id : os_task_id_param_t)
      with Pre => os_task_rw (Natural (task_id)).mbx.count > 0
   is
   begin
      os_task_rw (Natural (task_id)).mbx.count :=
        os_task_rw (Natural (task_id)).mbx.count - 1;
   end os_mbx_dec_mbx_count;

   ---------------------
   -- os_mbx_is_empty --
   ---------------------
   --  check if the mbx fifo of a given task is empty.

   function os_mbx_is_empty (task_id : os_task_id_param_t) return Boolean
   is
   begin
      return (os_mbx_get_mbx_count (task_id) = 0);
   end os_mbx_is_empty;

   --------------------
   -- os_mbx_is_full --
   --------------------
   --  check if the mbx fifo of a given task is full.

   function os_mbx_is_full (task_id : os_task_id_param_t) return Boolean
   is
   begin
      return (os_mbx_get_mbx_count (task_id) = OS_MAX_MBX_CNT);
   end os_mbx_is_full;

   ------------------------
   -- os_mbx_add_message --
   ------------------------
   --  Add a mbx to the mbx fifo of a given task.

   procedure os_mbx_add_message
     (dest_id : os_task_id_param_t;
      src_id  : os_task_id_param_t;
      mbx_msg : os_mbx_msg_t)
   is
      mbx_index : Natural;
   begin
      mbx_index :=
        Natural
          (os_mbx_get_mbx_head (dest_id) + os_mbx_get_mbx_count (dest_id)) mod
        OS_MAX_MBX_CNT;

      os_task_rw (Natural (dest_id)).mbx.mbx_array (mbx_index).sender_id :=
        src_id;
      os_task_rw (Natural (dest_id)).mbx.mbx_array (mbx_index).msg := mbx_msg;
      os_mbx_inc_mbx_count (dest_id);
   end os_mbx_add_message;

   ----------------------------------
   -- os_sched_set_current_task_id --
   ----------------------------------

   procedure os_sched_set_current_task_id (task_id : os_task_id_param_t) is
   begin
      os_task_current := task_id;
   end os_sched_set_current_task_id;

   ------------------------------------
   -- os_sched_get_current_list_head --
   ------------------------------------

   function os_sched_get_current_list_head return os_task_id_t is
   begin
      return os_task_ready_list_head;
   end os_sched_get_current_list_head;

   ------------------------------------
   -- os_sched_set_current_list_head --
   ------------------------------------

   procedure os_sched_set_current_list_head (task_id : os_task_id_t) is
   begin
      os_task_ready_list_head := task_id;

      if task_id >= 0 then
         os_task_rw (Natural (task_id)).prev := OS_TASK_ID_NONE;
      end if;
   end os_sched_set_current_list_head;

   -------------------------------------
   -- os_sched_add_task_to_ready_list --
   -------------------------------------

   procedure os_sched_add_task_to_ready_list (task_id : os_task_id_param_t)
   is
      index_id : os_task_id_t;
      prev_id  : os_task_id_t;
   begin
      index_id := os_sched_get_current_list_head;

      if index_id = OS_TASK_ID_NONE then
         --  No task in the ready list. Add this task at list head
         os_task_rw (Natural (task_id)).next := OS_TASK_ID_NONE;
         os_sched_set_current_list_head (task_id);
      else
         while index_id /= OS_TASK_ID_NONE loop
            if index_id = task_id then
               --  Already in the ready list
               exit;
            elsif os_task_ro (Natural (task_id)).priority >
              os_task_ro (Natural (index_id)).priority
            then
               prev_id := os_task_rw (Natural (index_id)).prev;
               os_task_rw (Natural (task_id)).next  := index_id;
               os_task_rw (Natural (index_id)).prev := task_id;

               if index_id = os_sched_get_current_list_head then
                  os_sched_set_current_list_head (task_id);
                  os_task_rw (Natural (task_id)).prev := OS_TASK_ID_NONE;
               else
                  os_task_rw (Natural (task_id)).prev := prev_id;
                  if prev_id /= OS_TASK_ID_NONE then
                     os_task_rw (Natural (prev_id)).next := task_id;
                  end if;
               end if;
               exit;
            elsif os_task_rw (Natural (index_id)).next = OS_TASK_ID_NONE then
               os_task_rw (Natural (index_id)).next := task_id;
               os_task_rw (Natural (task_id)).prev  := index_id;
               os_task_rw (Natural (task_id)).next  := OS_TASK_ID_NONE;
               exit;
            else
               index_id := os_task_rw (Natural (index_id)).next;
            end if;
         end loop;
      end if;
   end os_sched_add_task_to_ready_list;

   ------------------------------------------
   -- os_sched_remove_task_from_ready_list --
   ------------------------------------------

   procedure os_sched_remove_task_from_ready_list (task_id : os_task_id_param_t)
   is
      next : os_task_id_t;
      prev : os_task_id_t;
   begin
      next := os_task_rw (Natural (task_id)).next;

      if task_id = os_sched_get_current_list_head then
         --  We are removing the current running task.
         --  So put the next task at list head.
         --  Note: there could be no next task (OS_TASK_ID_NONE)
         os_sched_set_current_list_head (next);
      else
         --  The task is not at the list head (it has a predecesor).
         --  Link previous next to our next
         prev := os_task_rw (Natural (task_id)).prev;
         os_task_rw (Natural (prev)).next := next;

         if next /= OS_TASK_ID_NONE then
            --  if we have a next, link next previous to our previous.
            os_task_rw (Natural (next)).prev := prev;
         end if;
      end if;

      --  reset our next and previous
      os_task_rw (Natural (task_id)).next := OS_TASK_ID_NONE;
      os_task_rw (Natural (task_id)).prev := OS_TASK_ID_NONE;
   end os_sched_remove_task_from_ready_list;

   -----------------------
   -- os_sched_schedule --
   -----------------------

   procedure os_sched_schedule
      (task_id : out os_task_id_param_t)
   is
   begin
      --  Check interrupt status
      if os_arch_interrupt_is_pending = 1 then
         --  Put interrupt task in ready list if int is set.
         os_sched_add_task_to_ready_list (OS_INTERRUPT_TASK_ID);
      end if;

      while os_sched_get_current_list_head = OS_TASK_ID_NONE loop
         --  No task is elected:
         --  Put processor in idle mode and wait for interrupt.
         os_arch_idle;

         --  Check interrupt status
         if os_arch_interrupt_is_pending = 1 then
            --  Put interrupt task in ready list if int is set.
            os_sched_add_task_to_ready_list (OS_INTERRUPT_TASK_ID);
         end if;
      end loop;

      task_id := os_sched_get_current_list_head;

      --  Select the elected task as current task.
      os_sched_set_current_task_id (task_id);

      --  Return the ID of the elected task to allow context switch
      --  at low (arch) level
   end os_sched_schedule;

   ---------------------------------
   -- os_mbx_get_mbx_entry_sender --
   ---------------------------------

   function os_mbx_get_mbx_entry_sender
     (task_id   : os_task_id_param_t;
      mbx_index : os_mbx_index_t) return os_task_id_param_t
   is
   begin
      return os_task_rw (Natural (task_id)).mbx.mbx_array (Natural (mbx_index))
          .sender_id;
   end os_mbx_get_mbx_entry_sender;

   ----------------------------
   -- os_mbx_get_posted_mask --
   ----------------------------

   function os_mbx_get_posted_mask
     (task_id : os_task_id_param_t) return os_mbx_mask_t
      with Pre => task_id >= 0
   is
      mbx_mask  : os_mbx_mask_t;
      mbx_index : os_mbx_index_t;
   begin
      mbx_mask  := 0;
      mbx_index := os_mbx_get_mbx_head (task_id);

      for iterator in 0 .. (os_mbx_get_mbx_count (task_id) - 1) loop
         mbx_mask :=
           mbx_mask or
           os_mbx_mask_t
             (2**Natural (os_mbx_get_mbx_entry_sender (task_id, mbx_index)));
         mbx_index := (mbx_index + 1) mod OS_MAX_MBX_CNT;
      end loop;

      return mbx_mask;
   end os_mbx_get_posted_mask;

   --------------------------
   -- os_mbx_send_one_task --
   --------------------------

   procedure os_mbx_send_one_task
     (status  : out os_status_t;
      dest_id : os_task_id_param_t;
      mbx_msg : os_mbx_msg_t)
      with Pre => os_sched_get_current_task_id >= 0
   is
      current        : os_task_id_param_t;
      mbx_permission : os_mbx_mask_t;
      waiting_mask   : os_mbx_mask_t;
   begin
      current := os_sched_get_current_task_id;

      mbx_permission :=
        os_mbx_get_mbx_permission (dest_id) and
        os_mbx_mask_t (2**Natural (current));
      if mbx_permission /= 0 then
         if os_mbx_is_full (dest_id) then
            status := OS_ERROR_FIFO_FULL;
         else
            os_mbx_add_message (dest_id, current, mbx_msg);
            waiting_mask :=
              os_mbx_get_waiting_mask (dest_id) and
              os_mbx_mask_t (2**Natural (current));
            if waiting_mask /= 0 then
               os_sched_add_task_to_ready_list (dest_id);
            end if;

            status := OS_SUCCESS;
         end if;
      else
         status := OS_ERROR_DENIED;
      end if;
   end os_mbx_send_one_task;

   --------------------------
   -- os_mbx_send_all_task --
   --------------------------

   procedure os_mbx_send_all_task
     (status : out os_status_t;
      mbx_msg : os_mbx_msg_t)
      with Pre => os_sched_get_current_task_id >= 0
   is
      ret    : os_status_t;
   begin
      status := OS_ERROR_DENIED;

      for iterator in 0 .. OS_MAX_TASK_ID loop
         os_mbx_send_one_task (ret, os_task_id_param_t (iterator), mbx_msg);

         if ret = OS_ERROR_FIFO_FULL then
            status := ret;
         else
            if status /= OS_ERROR_FIFO_FULL then
               if ret = OS_SUCCESS then
                  status := OS_SUCCESS;
               end if;
            end if;
         end if;
      end loop;
   end os_mbx_send_all_task;

   ----------------------------
   -- os_mbx_clear_mbx_entry --
   ----------------------------

   procedure os_mbx_clear_mbx_entry
     (task_id   : os_task_id_param_t;
      mbx_index : os_mbx_index_t)
   is
   begin
      os_task_rw (Natural (task_id)).mbx.mbx_array (Natural (mbx_index))
        .sender_id :=
        OS_TASK_ID_NONE;
      os_task_rw (Natural (task_id)).mbx.mbx_array (Natural (mbx_index)).msg :=
        0;
   end os_mbx_clear_mbx_entry;

   --------------------------
   -- os_mbx_set_mbx_entry --
   --------------------------

   procedure os_mbx_set_mbx_entry
     (task_id   : os_task_id_param_t;
      mbx_index : os_mbx_index_t;
      mbx_entry : os_mbx_entry_t)
   is
   begin
      os_task_rw (Natural (task_id)).mbx.mbx_array (Natural (mbx_index)) :=
        mbx_entry;
   end os_mbx_set_mbx_entry;

   --------------------------
   -- os_mbx_get_mbx_entry --
   --------------------------

   function os_mbx_get_mbx_entry
     (task_id   : os_task_id_param_t;
      mbx_index : os_mbx_index_t) return os_mbx_entry_t
   is
   begin
      return os_task_rw (Natural (task_id)).mbx.mbx_array
          (Natural (mbx_index));
   end os_mbx_get_mbx_entry;

   ---------------------------------
   -- os_mbx_is_waiting_mbx_entry --
   ---------------------------------

   function os_mbx_is_waiting_mbx_entry
     (task_id   : os_task_id_param_t;
      mbx_index : os_mbx_index_t) return Boolean
   is
   begin
      return
        (os_mbx_get_waiting_mask (task_id) and
         os_mbx_mask_t
           (2**Natural (os_mbx_get_mbx_entry_sender (task_id, mbx_index)))) /=
        0;
   end os_mbx_is_waiting_mbx_entry;

   ----------------
   -- Public API --
   ----------------

   ----------------------------------
   -- os_sched_get_current_task_id --
   ----------------------------------

   function os_sched_get_current_task_id return os_task_id_t is
   begin
      return os_task_current;
   end os_sched_get_current_task_id;

   -------------------
   -- os_sched_wait --
   -------------------

   procedure os_sched_wait
     (task_id      : out os_task_id_param_t;
      waiting_mask : os_mbx_mask_t)
   is
      tmp_mask : os_mbx_mask_t;
   begin
      task_id := os_sched_get_current_task_id;

      tmp_mask := waiting_mask and os_mbx_get_mbx_permission (task_id);

      os_sched_remove_task_from_ready_list (task_id);

      if tmp_mask /= 0 then
         os_mbx_set_waiting_mask (task_id, tmp_mask);

         tmp_mask := tmp_mask and os_mbx_get_posted_mask (task_id);

         if tmp_mask /= 0 then
            os_sched_add_task_to_ready_list (task_id);
         end if;
      elsif task_id /= OS_INTERRUPT_TASK_ID then
         os_sched_add_task_to_ready_list (task_id);
      end if;

      os_sched_schedule (task_id);
   end os_sched_wait;

   --------------------
   -- os_sched_yield --
   --------------------

   procedure os_sched_yield
     (task_id  : out os_task_id_param_t)
   is
   begin
      task_id := os_sched_get_current_task_id;

      os_sched_remove_task_from_ready_list (task_id);

      os_sched_add_task_to_ready_list (task_id);

      os_sched_schedule (task_id);
   end os_sched_yield;

   -------------------
   -- os_sched_exit --
   -------------------

   procedure os_sched_exit
     (task_id  : out os_task_id_param_t)
   is
   begin
      task_id := os_sched_get_current_task_id;

      os_sched_remove_task_from_ready_list (task_id);

      os_sched_schedule (task_id);
   end os_sched_exit;

   -------------
   -- os_init --
   -------------

   procedure os_init
     (task_id  : out os_task_id_param_t)
   is
      prev_id : os_task_id_t;
   begin
      os_arch_cons_init;

      os_arch_space_init;

      os_sched_set_current_list_head (OS_TASK_ID_NONE);

      prev_id := 0;

      for task_iterator in 0 .. OS_MAX_TASK_ID loop
         os_arch_space_switch (prev_id, os_task_id_t (task_iterator));

         os_arch_context_create (os_task_id_t (task_iterator));

         for mbx_iterator in 0 .. OS_MAX_MBX_ID loop
            os_task_rw (task_iterator).mbx.mbx_array (mbx_iterator)
              .sender_id :=
              OS_TASK_ID_NONE;
         end loop;

         os_task_rw (task_iterator).next := OS_TASK_ID_NONE;
         os_task_rw (task_iterator).prev := OS_TASK_ID_NONE;

         os_sched_add_task_to_ready_list (os_task_id_t (task_iterator));
         prev_id := os_task_id_t (task_iterator);

      end loop;

      os_sched_schedule (task_id);

      os_arch_context_set (task_id);

      os_arch_space_switch (prev_id, task_id);
   end os_init;

   --------------------
   -- os_mbx_receive --
   --------------------

   procedure os_mbx_receive
     (status    : out os_status_t;
      mbx_entry : out os_mbx_entry_t)
   is
      current        : os_task_id_t;
      mbx_index      : os_mbx_index_t;
      next_mbx_index : os_mbx_index_t;
   begin
      mbx_entry.sender_id := OS_TASK_ID_NONE;
      mbx_entry.msg       := 0;

      --  retrieve current task id
      current := os_sched_get_current_task_id;

      if os_mbx_is_empty (current) then
         --  mbx queue is empty, so we return with error
	 status := OS_ERROR_FIFO_EMPTY;
      else
         --  initialize status to error in case we don't find a mbx.
         status := OS_ERROR_RECEIVE;

         --  go through received mbx for this task
         for iterator in 0 .. (os_mbx_get_mbx_count (current) - 1) loop

            --  Compute the mbx_index for the loop
            mbx_index :=
              (os_mbx_get_mbx_head (current) + iterator) mod OS_MAX_MBX_CNT;

            --  look into the mbx queue for a mbx that is waited for
            if os_mbx_is_waiting_mbx_entry (current, mbx_index) then

               --  copy the mbx into the task mbx entry
               mbx_entry := os_mbx_get_mbx_entry (current, mbx_index);

               if iterator = 0 then
                  --  if this was the first mbx, we just increase the mbx head
                  os_mbx_inc_mbx_head (current);
               else
                  --  in other case, for now we "compact" the rest of the
                  --  mbx queue, so that there is no "hole" in it for the next
                  --  mbx search.
                  for iterator2 in
                    (iterator + 1) .. (os_mbx_get_mbx_count (current) - 1)
                  loop
                     next_mbx_index := (mbx_index + 1) mod OS_MAX_MBX_CNT;
                     os_mbx_set_mbx_entry
                       (current,
                        mbx_index,
                        os_mbx_get_mbx_entry (current, next_mbx_index));
                     mbx_index := next_mbx_index;
                  end loop;
               end if;

               --  remove the mbx from the mbx queue (by clearing the entry).
               os_mbx_clear_mbx_entry (current, mbx_index);

               --  decrement the mbx count
               os_mbx_dec_mbx_count (current);

               --  We found a matching mbx
               status := OS_SUCCESS;
	       exit;
            end if;
         end loop;
      end if;
   end os_mbx_receive;

   -----------------
   -- os_mbx_send --
   -----------------

   procedure os_mbx_send
     (status  : out os_status_t;
      dest_id : types.int8_t;
      mbx_msg : os_mbx_msg_t)
   is
   begin
      if dest_id = OS_TASK_ID_ALL then
         os_mbx_send_all_task (status, mbx_msg);
      elsif ((dest_id >= 0) and (dest_id < OS_MAX_TASK_CNT)) then
         os_mbx_send_one_task (status, os_task_id_param_t (dest_id), mbx_msg);
      else
         status := OS_ERROR_PARAM;
      end if;
   end os_mbx_send;

end os;
