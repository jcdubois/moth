with Interfaces;   use Interfaces;
with Interfaces.C; use Interfaces.C;
with os_arch;      use os_arch;

package body os
   with SPARK_mode
is

   -----------------
   -- Private API --
   -----------------

   -------------------
   -- Private types --
   -------------------

   OS_MAX_MBX_CNT      : constant := OpenConf.CONFIG_TASK_MBX_COUNT;

   type os_mbx_index_t is mod OS_MAX_MBX_CNT;

   subtype os_mbx_count_t is types.uint8_t range 0 .. OS_MAX_MBX_CNT;

   type os_mbx_t_array is array (os_mbx_index_t) of os_mbx_entry_t;

   type os_mbx_t is record
      head             : os_mbx_index_t;
      count            : os_mbx_count_t;
      mbx_array        : os_mbx_t_array;
   end record;

   type os_task_rw_t is record
      next             : os_task_id_t;
      prev             : os_task_id_t;
      mbx_waiting_mask : os_mbx_mask_t;
   end record;

   subtype os_recurs_cnt_t is types.int8_t
                         range OS_MIN_TASK_ID .. OS_MAX_TASK_CNT;

   -----------------------
   -- Private variables --
   -----------------------

   -------------------------------------
   -- Ghost variable for task's state --
   -------------------------------------

   os_ghost_task_ready : array (os_task_id_param_t) of Boolean with Ghost;

   ---------------------
   -- os_task_list_rw --
   ---------------------

   os_task_list_rw : array (os_task_id_param_t) of os_task_rw_t;

   ---------------------
   -- os_task_mbx_rw --
   ---------------------

   os_task_mbx_rw : array (os_task_id_param_t) of os_mbx_t;

   ---------------------
   -- os_task_current --
   ---------------------
   --  This variable holds the ID of the current elected task.

   os_task_current : os_task_id_param_t;

   -----------------------------
   -- os_task_ready_list_head --
   -----------------------------
   --  This variable holds the ID of the first task in the ready list (the
   --  next one that will be elected).
   --  Note: Its value could be OS_TASK_ID_NONE if no task is ready.

   os_task_ready_list_head : os_task_id_t;

   ----------------------------------
   -- Private functions/procedures --
   ----------------------------------

   ----------------------
   -- + os_mbx_index_t --
   ----------------------
   -- add operator overload for os_mbx_index_t

   function "+" (Left  : os_mbx_index_t;
                 Right : os_mbx_count_t) return os_mbx_index_t
   is (Left + os_mbx_index_t'Mod (Right));

   -------------------------------
   -- os_mbx_get_mbx_permission --
   -------------------------------
   --  Get the mbx permission for a given task

   function os_mbx_get_mbx_permission
      (task_id : os_task_id_param_t) return os_mbx_mask_t
   is (os_task_ro (task_id).mbx_permission);

   --------------------------
   -- os_get_task_priority --
   --------------------------
   --  Get the mbx priority for a given task

   function os_get_task_priority
     (task_id : os_task_id_param_t) return os_priority_t
   is (os_task_ro (task_id).priority);

   -----------------------------
   -- os_mbx_get_waiting_mask --
   -----------------------------
   --  Get a mask of task the given task is waiting mbx from

   function os_mbx_get_waiting_mask
     (task_id : os_task_id_param_t) return os_mbx_mask_t
   is (os_task_list_rw (task_id).mbx_waiting_mask);

   ---------------------
   -- os_mbx_is_empty --
   ---------------------
   --  Check if the mbx fifo of a given task is empty.

   function os_mbx_is_empty (task_id : os_task_id_param_t) return Boolean
   is (os_task_mbx_rw (task_id).count = os_mbx_count_t'First);

   --------------------
   -- os_mbx_is_full --
   --------------------
   --  Check if the mbx fifo of a given task is full.

   function os_mbx_is_full (task_id : os_task_id_param_t) return Boolean
   is (os_task_mbx_rw (task_id).count = os_mbx_count_t'Last);

   -----------------------------
   -- os_mbx_set_waiting_mask --
   -----------------------------
   --  Set a mask of task the given task is waiting mbx from
   --  No contract, it will be inlined

   procedure os_mbx_set_waiting_mask
     (task_id : os_task_id_param_t;
      mask    : os_mbx_mask_t)
   is
   begin
      os_task_list_rw (task_id).mbx_waiting_mask := mask;
   end os_mbx_set_waiting_mask;

   -------------------------
   -- os_mbx_get_mbx_head --
   -------------------------
   --  Retrieve the mbx head index of the given task.

   function os_mbx_get_mbx_head
     (task_id : os_task_id_param_t) return os_mbx_index_t
   is (os_task_mbx_rw (task_id).head);

   -------------------------
   -- os_mbx_inc_mbx_head --
   -------------------------
   --  Increment the mbx head index of the given task.
   --  No contract, it will be inlined

   procedure os_mbx_inc_mbx_head (task_id : os_task_id_param_t)
   is
   begin
      os_task_mbx_rw (task_id).head :=
              os_mbx_index_t'Succ (os_mbx_get_mbx_head (task_id));
   end os_mbx_inc_mbx_head;

   --------------------------
   -- os_mbx_get_mbx_count --
   --------------------------
   --  Retrieve the mbx count of the given task.

   function os_mbx_get_mbx_count
     (task_id : os_task_id_param_t) return os_mbx_count_t
   is (os_task_mbx_rw (task_id).count);

   -------------------------
   -- os_mbx_get_mbx_tail --
   -------------------------
   --  Retrieve the mbx tail index of the given task.

   function os_mbx_get_mbx_tail
     (task_id : os_task_id_param_t) return os_mbx_index_t
   is (os_mbx_get_mbx_head (task_id) +
       os_mbx_count_t'Pred (os_mbx_get_mbx_count (task_id)))
   with
      Global => (Input => os_task_mbx_rw),
      Pre => not os_mbx_is_empty (task_id);

   --------------------------
   -- os_mbx_inc_mbx_count --
   --------------------------
   --  Increment the mbx count of the given task.

   procedure os_mbx_inc_mbx_count (task_id : os_task_id_param_t)
   with
      Global => (In_Out => os_task_mbx_rw),
      Pre => (os_task_mbx_rw (task_id).count < os_mbx_count_t'Last),
      Post => os_task_mbx_rw = os_task_mbx_rw'Old'Update (task_id => os_task_mbx_rw'Old (task_id)'Update (count => os_task_mbx_rw'Old (task_id).count + 1))
   is
   begin
      os_task_mbx_rw (task_id).count :=
              os_mbx_count_t'Succ (os_mbx_get_mbx_count (task_id));
   end os_mbx_inc_mbx_count;

   --------------------------
   -- os_mbx_dec_mbx_count --
   --------------------------
   --  Decrement the mbx count of the given task.

   procedure os_mbx_dec_mbx_count (task_id : os_task_id_param_t)
   with
      Global => (In_Out => os_task_mbx_rw),
      Pre => (not os_mbx_is_empty (task_id)),
      Post => os_task_mbx_rw = os_task_mbx_rw'Old'Update (task_id => os_task_mbx_rw'Old (task_id)'Update (count => os_task_mbx_rw'Old (task_id).count - 1))
   is
   begin
      os_task_mbx_rw (task_id).count :=
              os_mbx_count_t'Pred (os_mbx_get_mbx_count (task_id));
   end os_mbx_dec_mbx_count;

   ------------------------
   -- os_mbx_add_message --
   ------------------------
   --  Add a mbx to the mbx fifo of a given task.

   procedure os_mbx_add_message
     (dest_id : os_task_id_param_t;
      src_id  : os_task_id_param_t;
      mbx_msg : os_mbx_msg_t)
   with
      Global => (In_Out => os_task_mbx_rw),
      Pre  => ((not os_mbx_is_full (dest_id)) and then
               os_ghost_mbx_are_well_formed),
      Post => ((not os_mbx_is_empty (dest_id)) and then
               (os_task_mbx_rw = os_task_mbx_rw'Old'Update (dest_id => os_task_mbx_rw'Old (dest_id)'Update (count => os_task_mbx_rw'Old (dest_id).count + 1, head => os_task_mbx_rw'Old (dest_id).head, mbx_array => os_task_mbx_rw'Old (dest_id).mbx_array'Update (os_mbx_get_mbx_tail (dest_id) => os_task_mbx_rw'Old (dest_id).mbx_array (os_mbx_get_mbx_tail (dest_id))'Update (sender_id => src_id, msg => mbx_msg))))) and then
               os_ghost_mbx_are_well_formed)
   is
      mbx_index : os_mbx_index_t;
   begin
      os_mbx_inc_mbx_count (dest_id);
      mbx_index := os_mbx_get_mbx_tail (dest_id);
      os_task_mbx_rw (dest_id).mbx_array (mbx_index).sender_id := src_id;
      os_task_mbx_rw (dest_id).mbx_array (mbx_index).msg := mbx_msg;
   end os_mbx_add_message;

   ----------------------------------
   -- os_sched_set_current_task_id --
   ----------------------------------
   --  No contract, it will be inlined

   procedure os_sched_set_current_task_id (task_id : os_task_id_param_t)
   is
   begin
      os_task_current := task_id;
   end os_sched_set_current_task_id;

   ------------------------------------
   -- os_sched_get_current_list_head --
   ------------------------------------

   function os_sched_get_current_list_head return os_task_id_t
   is (os_task_ready_list_head);

   ------------------------------------
   -- os_sched_set_current_list_head --
   ------------------------------------
   --  No contract, it will be inlined

   procedure os_sched_set_current_list_head (task_id : os_task_id_t)
   is
   begin
      os_task_ready_list_head := task_id;
   end os_sched_set_current_list_head;

   -------------------------------------
   -- os_sched_add_task_to_ready_list --
   -------------------------------------

   procedure os_sched_add_task_to_ready_list (task_id : os_task_id_param_t)
   with
      Global => (In_Out => (os_task_ready_list_head,
                            os_task_list_rw,
                            os_ghost_task_ready),
                 Input  => os_task_ro),
      Pre => os_ghost_task_list_is_well_formed,
      Post => os_ghost_task_list_is_well_formed and
              os_ghost_task_ready = os_ghost_task_ready'Old'Update (task_id => true)
   is
      index_id : os_task_id_t := os_sched_get_current_list_head;
   begin

      if index_id = OS_TASK_ID_NONE then
         --  No task in the ready list. Add this task at list head
         os_task_list_rw (task_id).next := OS_TASK_ID_NONE;
         os_task_list_rw (task_id).prev := OS_TASK_ID_NONE;
         os_sched_set_current_list_head (task_id);
      else
         while index_id /= OS_TASK_ID_NONE loop
            if index_id = task_id then
               --  Already in the ready list
               exit;
            elsif os_get_task_priority (task_id) >
               os_get_task_priority (index_id)
            then
               declare
                  prev_id : constant os_task_id_t := os_task_list_rw (index_id).prev;
               begin
                  os_task_list_rw (task_id).next  := index_id;
                  os_task_list_rw (index_id).prev := task_id;

                  if index_id = os_sched_get_current_list_head then
                     os_task_list_rw (task_id).prev := OS_TASK_ID_NONE;
                     os_sched_set_current_list_head (task_id);
                  else
                     os_task_list_rw (task_id).prev := prev_id;
                     if prev_id in os_task_id_param_t then
                        os_task_list_rw (prev_id).next := task_id;
                     end if;
                  end if;
                  exit;
               end;
            elsif os_task_list_rw (index_id).next = OS_TASK_ID_NONE then
               os_task_list_rw (index_id).next := task_id;
               os_task_list_rw (task_id).prev  := index_id;
               os_task_list_rw (task_id).next  := OS_TASK_ID_NONE;
               exit;
            else
               index_id := os_task_list_rw (index_id).next;
            end if;
         end loop;
      end if;

      os_ghost_task_ready (task_id) := true;
   end os_sched_add_task_to_ready_list;

   ------------------------------------------
   -- os_sched_remove_task_from_ready_list --
   ------------------------------------------

   procedure os_sched_remove_task_from_ready_list
     (task_id : os_task_id_param_t)
   with
      Global => (In_Out => (os_task_ready_list_head,
                            os_task_list_rw,
                            os_ghost_task_ready),
                 Input  => (os_task_ro)),
      Pre =>  os_ghost_task_list_is_well_formed,
      Post => os_ghost_task_ready = os_ghost_task_ready'Old'Update (task_id => false)
              and os_ghost_task_list_is_well_formed
   is
      next : constant os_task_id_t := os_task_list_rw (task_id).next;
   begin
      if task_id = os_sched_get_current_list_head then
         --  We are removing the current running task. So put the next task at
         --  list head. Note: there could be no next task (OS_TASK_ID_NONE)
         if next /= OS_TASK_ID_NONE then
            os_task_list_rw (next).prev := OS_TASK_ID_NONE;
         end if;
         os_sched_set_current_list_head (next);
      elsif os_sched_get_current_list_head /= OS_TASK_ID_NONE then
         --  The list is not empty and
         --  The task is not at the list head (it has a predecesor).
         --  Link previous next to our next
         declare
            prev : constant os_task_id_t := os_task_list_rw (task_id).prev;
         begin
            if prev /= OS_TASK_ID_NONE then
               os_task_list_rw (prev).next := next;
            end if;

            if next /= OS_TASK_ID_NONE then
               --  if we have a next, link next previous to our previous.
               os_task_list_rw (next).prev := prev;
            end if;
         end;
      end if;

      --  reset our next and previous
      os_task_list_rw (task_id).next := OS_TASK_ID_NONE;
      os_task_list_rw (task_id).prev := OS_TASK_ID_NONE;

      os_ghost_task_ready (task_id) := false;

   end os_sched_remove_task_from_ready_list;

   -----------------------
   -- os_sched_schedule --
   -----------------------

   procedure os_sched_schedule (task_id : out os_task_id_param_t)
   with
   Global => (In_Out => (os_task_ready_list_head,
                         os_task_list_rw,
                         os_ghost_task_ready),
              Output => os_task_current,
              Input  => os_task_ro),
   Pre => os_ghost_task_list_is_well_formed,
   Post => os_ghost_task_list_is_well_formed and then
           os_ghost_task_is_ready (task_id)
   is
   begin
      --  Check interrupt status
      if os_arch_interrupt_is_pending = 1 then
         --  Put interrupt task in ready list if int is set.
         os_sched_add_task_to_ready_list (OS_INTERRUPT_TASK_ID);
      end if;

      while os_sched_get_current_list_head = OS_TASK_ID_NONE loop

         pragma Loop_Invariant (os_ghost_task_list_is_well_formed);

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

      --  Return the ID of the elected task to allow context switch at low
      --  (arch) level
   end os_sched_schedule;

   ---------------------------------
   -- os_mbx_get_mbx_entry_sender --
   ---------------------------------

   function os_mbx_get_mbx_entry_sender
     (task_id   : os_task_id_param_t;
      index : os_mbx_count_t) return os_task_id_param_t
   is (os_task_id_param_t (os_task_mbx_rw (task_id).mbx_array
           (os_mbx_get_mbx_head (task_id) + index).sender_id))
   with
      Global => (Input => (os_task_mbx_rw)),
      Pre => os_task_mbx_rw (task_id).mbx_array
                  (os_mbx_get_mbx_head (task_id) + index).sender_id
                  in os_task_id_param_t;

   ----------------------------
   -- os_mbx_get_posted_mask --
   ----------------------------

   function os_mbx_get_posted_mask
     (task_id : os_task_id_param_t) return os_mbx_mask_t
   with
      Global => (Input => (os_task_mbx_rw)),
      Pre => os_ghost_mbx_are_well_formed
   is
      mbx_mask  : os_mbx_mask_t := 0;
   begin

      if not os_mbx_is_empty (task_id) then
         for iterator in 0 ..
                         os_mbx_count_t'Pred (os_mbx_get_mbx_count (task_id))
         loop

             mbx_mask :=
              mbx_mask or
              os_mbx_mask_t (Shift_Left
                (Unsigned_32'(1),
                 Natural (os_mbx_get_mbx_entry_sender (task_id, iterator))));

         end loop;
      end if;

      return mbx_mask;
   end os_mbx_get_posted_mask;

   --------------------------
   -- os_mbx_send_one_task --
   --------------------------

   procedure os_mbx_send_one_task
     (status  : out os_status_t;
      dest_id : in  os_task_id_param_t;
      mbx_msg : in  os_mbx_msg_t)
   with
      Global => (In_Out => (os_task_ready_list_head,
                            os_task_list_rw,
                            os_ghost_task_ready,
                            os_task_mbx_rw),
                 Input  => (os_task_ro,
                            os_task_current)),
      Pre => os_ghost_task_list_is_well_formed and
             os_ghost_mbx_are_well_formed and
             os_ghost_current_task_is_ready,
      Post => os_ghost_task_list_is_well_formed and
              os_ghost_mbx_are_well_formed and
              os_ghost_current_task_is_ready
   is
      current        : constant os_task_id_param_t := os_sched_get_current_task_id;
      mbx_permission : constant os_mbx_mask_t :=
        os_mbx_get_mbx_permission (dest_id) and
        os_mbx_mask_t (Shift_Left (Unsigned_32'(1), Natural (current)));
   begin
      if mbx_permission /= 0 then
         if os_mbx_is_full (dest_id) then
            status := OS_ERROR_FIFO_FULL;
         else
            os_mbx_add_message (dest_id, current, mbx_msg);
            if (os_mbx_get_waiting_mask (dest_id) and
               os_mbx_mask_t (Shift_Left (Unsigned_32'(1), Natural (current)))) /= 0 then
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
     (status  : out os_status_t;
      mbx_msg : in  os_mbx_msg_t)
   with
      Global => (In_Out => (os_task_ready_list_head,
                            os_task_list_rw,
                            os_ghost_task_ready,
                            os_task_mbx_rw),
                 Input  => (os_task_ro,
                            os_task_current)),
      Pre => os_ghost_task_list_is_well_formed and
             os_ghost_mbx_are_well_formed and
             os_ghost_current_task_is_ready,
      Post => os_ghost_task_list_is_well_formed and
              os_ghost_mbx_are_well_formed and
              os_ghost_current_task_is_ready
   is
      ret : os_status_t;
   begin
      status := OS_ERROR_DENIED;

      for iterator in os_task_list_rw'Range loop
         os_mbx_send_one_task (ret, iterator, mbx_msg);

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
   --  No contract, it will be inlined

   procedure os_mbx_clear_mbx_entry
     (task_id   : os_task_id_param_t;
      mbx_index : os_mbx_index_t)
   is
   begin
      os_task_mbx_rw (task_id).mbx_array (mbx_index).sender_id :=
                                                               OS_TASK_ID_NONE;
      os_task_mbx_rw (task_id).mbx_array (mbx_index).msg := 0;
   end os_mbx_clear_mbx_entry;

   --------------------------
   -- os_mbx_set_mbx_entry --
   --------------------------
   --  No contract, it will be inlined

   procedure os_mbx_set_mbx_entry
     (task_id   : os_task_id_param_t;
      index : os_mbx_count_t;
      mbx_entry : os_mbx_entry_t)
   is
   begin
      os_task_mbx_rw (task_id).mbx_array (os_mbx_get_mbx_head (task_id) + index) := mbx_entry;
   end os_mbx_set_mbx_entry;

   --------------------------
   -- os_mbx_get_mbx_entry --
   --------------------------

   function os_mbx_get_mbx_entry
     (task_id   : os_task_id_param_t;
      index : os_mbx_count_t) return os_mbx_entry_t
   is (os_task_mbx_rw (task_id).mbx_array (os_mbx_get_mbx_head (task_id) + index));

   ---------------------------------
   -- os_mbx_is_waiting_mbx_entry --
   ---------------------------------

   function os_mbx_is_waiting_mbx_entry
     (task_id   : os_task_id_param_t;
      index : os_mbx_count_t) return Boolean
   is ((os_mbx_get_waiting_mask (task_id) and
        os_mbx_mask_t (Shift_Left
                (Unsigned_32'(1), Natural (os_mbx_get_mbx_entry_sender
                (task_id, index))))) /= 0)
   with
      Global => (Input => (os_task_list_rw, os_task_mbx_rw)),
      Pre => not os_mbx_is_empty (task_id) and then
             os_ghost_mbx_are_well_formed and then
             index < os_mbx_get_mbx_count (task_id) and then
             os_mbx_get_mbx_entry_sender (task_id, index) in os_task_id_param_t;

   ----------------------
   --  Ghost functions --
   ----------------------

   ------------------------------
   -- os_ghost_not_next_twice --
   ------------------------------
   --  A task_id should not be twice in next attribute

   function os_ghost_not_next_twice (task_id : os_task_id_t) return Boolean is
      (not
         (for some next_id in os_task_list_rw'Range =>
            os_ghost_task_is_ready (next_id) and
            os_task_list_rw (next_id).next = task_id and
               (for some next_id2 in os_task_list_rw'Range =>
                  next_id2 /= next_id and
                  os_ghost_task_is_ready (next_id2) and
                  os_task_list_rw (next_id2).next = task_id)))
   with
      Ghost => true;

   ------------------------------
   -- os_ghost_not_prev_twice --
   ------------------------------
   --  A task_id should not be twice in prev attribute

   function os_ghost_not_prev_twice (task_id : os_task_id_t) return Boolean is
      (not
         (for some prev_id in os_task_list_rw'Range =>
            os_ghost_task_is_ready (prev_id) and
            os_task_list_rw (prev_id).prev = task_id and
               (for some prev_id2 in os_task_list_rw'Range =>
                  prev_id2 /= prev_id and
                  os_ghost_task_is_ready (prev_id2) and
                  os_task_list_rw (prev_id2).prev = task_id)))
   with
      Ghost => true;

   ----------------------------
   -- os_ghost_task_is_ready --
   ----------------------------

   function os_ghost_task_is_ready (task_id : os_task_id_param_t) return Boolean
   is (os_ghost_task_ready (task_id));

   --------------------------------------------
   -- os_ghost_at_least_one_terminating_next --
   --------------------------------------------
   --  There should be at leat one task that has no next.
   --  The last element of the list has no next.
   --  If there is no first element then all no element has any next

   function os_ghost_only_one_ready_terminating_next return Boolean is
      (not
         (for some task_id in os_task_list_rw'Range =>
            os_ghost_task_is_ready (task_id) and
            os_task_list_rw (task_id).next = OS_TASK_ID_NONE and
               (for some task_id2 in os_task_list_rw'Range =>
                  task_id2 /= task_id and
                  os_ghost_task_is_ready (task_id2) and
                  os_task_list_rw (task_id2).next = OS_TASK_ID_NONE)))
   with
      Ghost => true;

   ------------------------------------
   -- os_ghost_current_task_is_ready --
   ------------------------------------

   function os_ghost_current_task_is_ready return Boolean
   is (os_ghost_task_is_ready(os_sched_get_current_task_id));

   ---------------------------------------
   -- os_ghost_task_mbx_are_well_formed --
   ---------------------------------------
   --  mbx are circular FIFO (contained in an array) where head is the index
   --  of the fisrt element of the FIFO and count is the number of element
   --  stored in the FIFO.
   --  When an element of the FIFO is filled its sender_id field needs to be
   --  >= 0. When an element in the circular FIFO is empty, its sender_if field
   --  is -1 (OS_TASK_ID_NONE).
   --  So this condition makes sure that all non empty element of the circular
   --  FIFO have sender_id >= 0 and empty elements of the FIFO have sender_id
   --  = -1.
   --  Note: Here we have to duplicate the function code in the post condition
   --  in order to be able to support the pragma Inline_For_Proof required
   --  to help the prover in os_ghost_mbx_are_well_formed() function below.

   function os_ghost_task_mbx_are_well_formed (task_id : os_task_id_param_t) return Boolean is
      (for all index in os_mbx_index_t'Range =>
         (if (os_mbx_count_t(index) >= os_mbx_get_mbx_count (task_id))
          then (os_task_mbx_rw (task_id).mbx_array (os_mbx_get_mbx_head (task_id) + index).sender_id = OS_TASK_ID_NONE)
          else (os_task_mbx_rw (task_id).mbx_array (os_mbx_get_mbx_head (task_id) + index).sender_id in os_task_id_param_t)))
   with
      Ghost => true,
      Post => os_ghost_task_mbx_are_well_formed'Result =
         (for all index in os_mbx_index_t'Range =>
            (if (os_mbx_is_empty (task_id))
             then (os_task_mbx_rw (task_id).mbx_array (index).sender_id
                     = OS_TASK_ID_NONE)
             else (if (((os_mbx_get_mbx_tail (task_id)
                            < os_mbx_get_mbx_head (task_id)) and
                        ((index >= os_mbx_get_mbx_head (task_id)) or
                         (index <= os_mbx_get_mbx_tail (task_id)))) or else
                       (index in os_mbx_get_mbx_head (task_id) ..
                                 os_mbx_get_mbx_tail (task_id)))
                   then (os_task_mbx_rw (task_id).mbx_array (index).sender_id
                           in os_task_id_param_t)
                   else (os_task_mbx_rw (task_id).mbx_array (index).sender_id
                           = OS_TASK_ID_NONE))));

      pragma Annotate (GNATprove, Inline_For_Proof,
                       os_ghost_task_mbx_are_well_formed);

   ----------------------------------
   -- os_ghost_mbx_are_well_formed --
   ----------------------------------

   function os_ghost_mbx_are_well_formed return Boolean is
      (for all task_id in os_task_id_param_t'Range =>
         os_ghost_task_mbx_are_well_formed (task_id));

   -------------------------------------
   -- os_ghost_task_is_linked_to_head --
   -------------------------------------

   function os_ghost_task_is_linked_to_head (task_id : os_task_id_param_t; recursive_count : os_recurs_cnt_t) return Boolean is
      (if (recursive_count = OS_MAX_TASK_CNT) then
         (false)
       else
         (os_ghost_task_is_ready (task_id) and
          (if os_task_list_rw (task_id).prev = OS_TASK_ID_NONE then
             (os_sched_get_current_list_head = task_id)
           else
             (os_task_list_rw (task_id).prev /= task_id and
	      os_task_list_rw (task_id).prev /= os_task_list_rw (task_id).next and
	      os_task_list_rw (os_task_list_rw (task_id).prev).next = task_id and
	      os_ghost_not_prev_twice (task_id) and
	      os_get_task_priority (task_id) <= os_get_task_priority (os_task_list_rw (task_id).prev) and
	      os_ghost_task_is_linked_to_head (os_task_list_rw (task_id).prev, recursive_count + 1)))))
   with
      Ghost => true;
   pragma Annotate (GNATprove, Terminating, os_ghost_task_is_linked_to_head);

   --------------------------------------
   -- os_ghost_task_list_is_terminated --
   --------------------------------------

   function os_ghost_task_list_is_terminated (task_id : os_task_id_param_t; recursive_count : os_recurs_cnt_t) return Boolean is
      (if (recursive_count = OS_MAX_TASK_CNT) then
         (false)
       else
         (os_ghost_task_is_ready (task_id) and
          (if os_task_list_rw (task_id).next = OS_TASK_ID_NONE then
             (true)
	   else
	     (os_task_list_rw (task_id).next /= task_id and
	      os_task_list_rw (task_id).prev /= os_task_list_rw (task_id).next and
	      os_task_list_rw (os_task_list_rw (task_id).next).prev = task_id and
	      os_ghost_not_next_twice(task_id) and
	      os_get_task_priority (task_id) >= os_get_task_priority (os_task_list_rw (task_id).next) and
	      os_ghost_task_list_is_terminated (os_task_list_rw (task_id).next, recursive_count + 1)))))
   with
      Ghost => true;
   pragma Annotate (GNATprove, Terminating, os_ghost_task_list_is_terminated);

   ---------------------------------------
   -- os_ghost_task_list_is_well_formed --
   ---------------------------------------

   function os_ghost_task_list_is_well_formed return Boolean is
      --  The mbx fifo of all tasks need to be well formed.
      (if os_sched_get_current_list_head = OS_TASK_ID_NONE then
         (-- there is no ready task
          for all task_id in os_task_list_rw'Range =>
             (-- no next for all task
              os_task_list_rw (task_id).next = OS_TASK_ID_NONE and
              -- no prev for all task
              os_task_list_rw (task_id).prev = OS_TASK_ID_NONE and
              -- and all tasks are not in ready state
              not (os_ghost_task_is_ready (task_id))))
       else -- There is at least one task in the ready list
         (-- there need to be one and only one ready task without next
          os_ghost_only_one_ready_terminating_next and
          (for all task_id in os_task_list_rw'Range =>
             (if task_id = os_sched_get_current_list_head then
                (-- No prev for list head
                 os_task_list_rw (task_id).prev = OS_TASK_ID_NONE and
                 -- It has to be ready
                 os_ghost_task_is_ready (task_id) and
                 -- The list head has the highest priority of all ready tasks
		 os_ghost_task_list_is_terminated (task_id, OS_MIN_TASK_ID))
              elsif os_ghost_task_is_ready (task_id) then
                  (-- only list head has no pred
                   os_task_list_rw (task_id).prev /= OS_TASK_ID_NONE and then
                   (-- the list needs to be terminated
	            os_ghost_task_list_is_terminated(task_id, OS_MIN_TASK_ID) and
                    -- the ready task need to be connected to head
                    os_ghost_task_is_linked_to_head (task_id, OS_MIN_TASK_ID)))
              else -- this task is not in the ready list
                  (-- no next
                   os_task_list_rw (task_id).next = OS_TASK_ID_NONE and
                   -- no prev
                   os_task_list_rw (task_id).prev = OS_TASK_ID_NONE)))));

   ----------------
   -- Public API --
   ----------------

   ----------------------------------
   -- os_sched_get_current_task_id --
   ----------------------------------

   function os_sched_get_current_task_id return os_task_id_param_t
   is (os_task_current);

   -------------------
   -- os_sched_wait --
   -------------------

   procedure os_sched_wait
     (task_id      : out os_task_id_param_t;
      waiting_mask : in  os_mbx_mask_t)
   is
      tmp_mask : os_mbx_mask_t;
   begin
      task_id := os_sched_get_current_task_id;

      tmp_mask := waiting_mask and os_mbx_get_mbx_permission (task_id);

      --  We remove the current task from the ready list.
      os_sched_remove_task_from_ready_list (task_id);

      if tmp_mask /= 0 then
         os_mbx_set_waiting_mask (task_id, tmp_mask);

         tmp_mask := tmp_mask and os_mbx_get_posted_mask (task_id);

         if tmp_mask /= 0 then
            --  If waited event is already here, put the task back in the
            --  ready list (after tasks of same priority).
            os_sched_add_task_to_ready_list (task_id);
         end if;
      elsif task_id /= OS_INTERRUPT_TASK_ID then
         --  This is an error/illegal case. There is nothing to wait for,
         --  so put the task back in the ready list.
         os_sched_add_task_to_ready_list (task_id);
      end if;

      --  Let's elect the new running task.
      os_sched_schedule (task_id);
   end os_sched_wait;

   --------------------
   -- os_sched_yield --
   --------------------

   procedure os_sched_yield (task_id : out os_task_id_param_t)
   is
   begin
      task_id := os_sched_get_current_task_id;

      --  We remove the current task from the ready list.
      os_sched_remove_task_from_ready_list (task_id);

      --  We insert it back after the other tasks with same priority.
      os_sched_add_task_to_ready_list (task_id);

      --  We determine the new task.
      os_sched_schedule (task_id);
   end os_sched_yield;

   -------------------
   -- os_sched_exit --
   -------------------

   procedure os_sched_exit (task_id : out os_task_id_param_t)
   is
   begin
      task_id := os_sched_get_current_task_id;

      --  Remove the current task from the ready list.
      os_sched_remove_task_from_ready_list (task_id);

      --  We determine the new task.
      os_sched_schedule (task_id);
   end os_sched_exit;

   -------------
   -- os_init --
   -------------

   procedure os_init (task_id : out os_task_id_param_t)
   is
      prev_id : os_task_id_param_t := os_task_list_rw'First;
   begin
      --  Init the console if any
      os_arch_cons_init;

      --  Init the MMU
      os_arch_space_init;

      --  Init the task list head to NONE
      os_sched_set_current_list_head (OS_TASK_ID_NONE);

      for task_iterator in os_task_list_rw'Range loop
         --  Init the mbx for one task
         for mbx_iterator in os_task_mbx_rw (task_iterator).mbx_array'Range loop
            os_mbx_clear_mbx_entry (task_iterator, mbx_iterator);
         end loop;
         os_task_mbx_rw (task_iterator).head := os_mbx_index_t'First;
         os_task_mbx_rw (task_iterator).count := os_mbx_count_t'First;

         --  Init the task entry for one task
         os_task_list_rw (task_iterator).next := OS_TASK_ID_NONE;
         os_task_list_rw (task_iterator).prev := OS_TASK_ID_NONE;
         os_task_list_rw (task_iterator).mbx_waiting_mask := 0;

         --  This task is not ready
         os_ghost_task_ready (task_iterator) := false;
      end loop;

      for task_iterator in os_task_list_rw'Range loop
         --  Initialise the memory space for one task
         os_arch_space_switch (prev_id, task_iterator);

         --  create the run context (stak, ...) for this task
         os_arch_context_create (task_iterator);

         --  Add the task to the ready list
         os_sched_add_task_to_ready_list (task_iterator);

         prev_id := task_iterator;
      end loop;

      --  Select the task to run
      os_sched_schedule (task_id);

      --  Set the selected task as the current one
      os_arch_context_set (task_id);

      --  Switch to this task context
      os_arch_space_switch (prev_id, task_id);
   end os_init;

   -----------------------------
   -- os_mbx_remove_first_mbx --
   -----------------------------

   procedure os_mbx_remove_first_mbx
      (task_id    : in os_task_id_param_t)
   with
      Global => (In_Out => os_task_mbx_rw),
      Pre  => (not os_mbx_is_empty (task_id)) and os_ghost_mbx_are_well_formed,
      Post => (os_task_mbx_rw = os_task_mbx_rw'Old'Update (task_id => os_task_mbx_rw'Old (task_id)'Update (count => os_mbx_count_t'Pred (os_task_mbx_rw'Old (task_id).count), head => os_mbx_index_t'Succ (os_task_mbx_rw'Old (task_id).head), mbx_array => os_task_mbx_rw'Old (task_id).mbx_array'Update (os_mbx_index_t'Pred (os_mbx_get_mbx_head (task_id)) => (sender_id => OS_TASK_ID_NONE, msg => 0)))))
              and os_ghost_mbx_are_well_formed
   is
      mbx_index   : constant os_mbx_index_t := os_mbx_get_mbx_head (task_id);
   begin
      --  remove the first mbx from the mbx queue
      --  (by clearing the entry).
      os_mbx_clear_mbx_entry (task_id, mbx_index);

      --  We just increase the mbx head
      os_mbx_inc_mbx_head (task_id);

      --  decrement the mbx count
      os_mbx_dec_mbx_count (task_id);
   end os_mbx_remove_first_mbx;

   ----------------------------
   -- os_mbx_remove_last_mbx --
   ----------------------------

   procedure os_mbx_remove_last_mbx
      (task_id    : in os_task_id_param_t)
   with
      Global => (In_Out => os_task_mbx_rw),
      Pre  => (not os_mbx_is_empty (task_id)) and os_ghost_mbx_are_well_formed,
      Post => (os_task_mbx_rw = os_task_mbx_rw'Old'Update (task_id => os_task_mbx_rw'Old (task_id)'Update (count => os_mbx_count_t'Pred (os_task_mbx_rw'Old (task_id).count), head => os_task_mbx_rw'Old (task_id).head, mbx_array => os_task_mbx_rw'Old (task_id).mbx_array'Update (os_task_mbx_rw (task_id).head + os_task_mbx_rw (task_id).count => (sender_id => OS_TASK_ID_NONE, msg => 0)))))
              and os_ghost_mbx_are_well_formed
   is
      mbx_index   : constant os_mbx_index_t := os_mbx_get_mbx_tail (task_id);
   begin
      --  remove the last mbx from the mbx queue
      --  (by clearing the entry).
      os_mbx_clear_mbx_entry (task_id, mbx_index);

      --  decrement the mbx count
      os_mbx_dec_mbx_count (task_id);
   end os_mbx_remove_last_mbx;

   -----------------------
   -- os_mbx_shift_down --
   -----------------------

   procedure os_mbx_shift_down
      (task_id    : in os_task_id_param_t;
       index      : in os_mbx_count_t)
   with
      Global => (In_Out => os_task_mbx_rw),
      Pre => (not os_mbx_is_empty (task_id)) and
             os_ghost_mbx_are_well_formed and
             (index > 0) and
             (index < os_mbx_count_t'Pred (os_mbx_get_mbx_count (task_id))),
      Post => os_ghost_mbx_are_well_formed and
              os_task_mbx_rw (task_id).count = os_task_mbx_rw'Old (task_id).count and
              os_task_mbx_rw (task_id).head = os_task_mbx_rw'Old (task_id).head
   is begin
      for iterator in index ..
                      os_mbx_count_t'Pred (os_mbx_get_mbx_count (task_id)) loop
         pragma Loop_Invariant (os_ghost_mbx_are_well_formed);
         os_mbx_set_mbx_entry (task_id, iterator,
                               os_mbx_get_mbx_entry (task_id,
                                                     os_mbx_count_t'Succ (iterator)));
      end loop;
   end os_mbx_shift_down;

   --------------------
   -- os_mbx_receive --
   --------------------

   procedure os_mbx_receive
     (status    : out os_status_t;
      mbx_entry : out os_mbx_entry_t)
   is
      --  retrieve current task id
      current   : constant os_task_id_param_t := os_sched_get_current_task_id;
   begin
      mbx_entry.sender_id := OS_TASK_ID_NONE;
      mbx_entry.msg       := 0;

      if os_mbx_is_empty (current) then
         --  mbx queue is empty, so we return with error
         status := OS_ERROR_FIFO_EMPTY;
      else
         --  initialize status to error in case we don't find a mbx.
         status := OS_ERROR_RECEIVE;

         --  go through received mbx for the current task
         for iterator in 0 ..
                         os_mbx_count_t'Pred (os_mbx_get_mbx_count (current)) loop

            pragma Loop_Invariant (os_ghost_mbx_are_well_formed and
                                   (not os_mbx_is_empty (current)));

	    -- This Loop Invariant is a work arround. The prover is unable
	    -- to see that the code under the os_mbx_is_waiting_mbx_entry()
	    -- branch has no impact on the loop as the branch exits
	    -- unconditionnaly in all cases. This loop invariant allows the
	    -- prover to work but it should be removed later when the prover
	    -- supports branches with exit path.
            pragma Loop_Invariant (os_task_mbx_rw = os_task_mbx_rw'Loop_Entry);

            --  is this a mbx we are waiting for
            if os_mbx_is_waiting_mbx_entry (current, iterator) then

               --  copy the mbx into the task mbx entry
               mbx_entry := os_mbx_get_mbx_entry (current, iterator);

               if iterator = 0 then
                  --  This was the first mbx (aka mbx head )

                  --  Clear the first entry and increment the mbx head
                  os_mbx_remove_first_mbx (current);
               else
                  --  This was not the first MBX

                  --  Compact the mbx if necessary
                  if iterator <
                     os_mbx_count_t'Pred (os_mbx_get_mbx_count (current)) then
                     --  This is not the last MBX
                     --  For now we "compact" the rest of the mbx queue,
                     --  so that there is no "hole" in it for the next mbx
                     --  search.

                     os_mbx_shift_down (current, iterator);
                  end if;

                  --  remove the last mbx from the mbx queue
                  --  (by clearing the last entry and decreasing the
                  --  mbx count).
                  os_mbx_remove_last_mbx (current);
               end if;

               --  We found a matching mbx
               status := OS_SUCCESS;

               --  Exit the for loop as we found a mbx we were
               --  waiting for.
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
      dest_id : in  types.int8_t;
      mbx_msg : in  os_mbx_msg_t)
   is
      --  dest_id comes from uncontroled C calls (user space)
      --  We don't make assumptions on its value, so we are testing
      --  all cases.
   begin
      if dest_id = OS_TASK_ID_ALL then
         os_mbx_send_all_task (status, mbx_msg);
      elsif dest_id in os_task_id_param_t then
         os_mbx_send_one_task (status, dest_id, mbx_msg);
      else
         status := OS_ERROR_PARAM;
      end if;
   end os_mbx_send;

end os;
