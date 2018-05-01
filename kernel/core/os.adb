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

   type os_mbx_index_t is mod OS_MAX_MBX_ID;

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
      mbx              : os_mbx_t;
   end record;

   -----------------------
   -- Private variables --
   -----------------------

   -------------------------------------
   -- Ghost variable for task's state --
   -------------------------------------

   os_ghost_task_ready : array (os_task_id_param_t) of Boolean with Ghost;

   ----------------
   -- os_task_rw --
   ----------------

   os_task_rw : array (os_task_id_param_t) of os_task_rw_t;

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

   -------------------------------
   -- os_mbx_get_mbx_permission --
   -------------------------------
   --  Get the mbx permission for a given task

   function os_get_task_priority
     (task_id : os_task_id_param_t) return os_priority_t
   is (os_task_ro (task_id).priority);

   -----------------------------
   -- os_mbx_get_waiting_mask --
   -----------------------------
   --  Get a mask of task the given task is waiting mbx from

   function os_mbx_get_waiting_mask
     (task_id : os_task_id_param_t) return os_mbx_mask_t
   is (os_task_rw (task_id).mbx_waiting_mask);

   ---------------------
   -- os_mbx_is_empty --
   ---------------------
   --  Check if the mbx fifo of a given task is empty.

   function os_mbx_is_empty (task_id : os_task_id_param_t) return Boolean
   is (os_task_rw (task_id).mbx.count = os_mbx_count_t'First);

   --------------------
   -- os_mbx_is_full --
   --------------------
   --  Check if the mbx fifo of a given task is full.

   function os_mbx_is_full (task_id : os_task_id_param_t) return Boolean
   is (os_task_rw (task_id).mbx.count = os_mbx_count_t'Last);

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
      os_task_rw (task_id).mbx_waiting_mask := mask;
   end os_mbx_set_waiting_mask;

   -------------------------
   -- os_mbx_get_mbx_head --
   -------------------------
   --  Retrieve the mbx head index of the given task.

   function os_mbx_get_mbx_head
     (task_id : os_task_id_param_t) return os_mbx_index_t
   is (os_task_rw (task_id).mbx.head);

   -------------------------
   -- os_mbx_inc_mbx_head --
   -------------------------
   --  Increment the mbx head index of the given task.
   --  No contract, it will be inlined

   procedure os_mbx_inc_mbx_head (task_id : os_task_id_param_t)
   is
   begin
      os_task_rw (task_id).mbx.head :=
              os_mbx_index_t'Succ (os_mbx_get_mbx_head (task_id));
   end os_mbx_inc_mbx_head;

   --------------------------
   -- os_mbx_get_mbx_count --
   --------------------------
   --  Retrieve the mbx count of the given task.

   function os_mbx_get_mbx_count
     (task_id : os_task_id_param_t) return os_mbx_count_t
   is (os_task_rw (task_id).mbx.count);

   ---------------------------
   -- os_ghost_get_mbx_tail --
   ---------------------------
   --  Retrieve the mbx tail index of the given task.

   function os_ghost_get_mbx_tail
     (task_id : os_task_id_param_t) return os_mbx_index_t
   is (os_mbx_get_mbx_head (task_id) +
       os_mbx_count_t'Pred (os_mbx_get_mbx_count (task_id)))
   with
      Pre => not os_mbx_is_empty (task_id),
      Ghost => true;

   --------------------------
   -- os_mbx_inc_mbx_count --
   --------------------------
   --  Increment the mbx count of the given task.

   procedure os_mbx_inc_mbx_count (task_id : os_task_id_param_t)
   with
      Global => (In_Out => os_task_rw),
      Pre => (os_task_rw (task_id).mbx.count < os_mbx_count_t'Last),
      Post => (os_task_rw (task_id).mbx.count =
               os_task_rw (task_id).mbx.count'Old + 1)
   is
   begin
      os_task_rw (task_id).mbx.count :=
              os_mbx_count_t'Succ (os_mbx_get_mbx_count (task_id));
   end os_mbx_inc_mbx_count;

   --------------------------
   -- os_mbx_dec_mbx_count --
   --------------------------
   --  Decrement the mbx count of the given task.

   procedure os_mbx_dec_mbx_count (task_id : os_task_id_param_t)
   with
      Global => (In_Out => os_task_rw),
      Pre => (os_mbx_get_mbx_count (task_id) > os_mbx_count_t'First),
      Post => (os_task_rw (task_id).mbx.count =
               os_task_rw (task_id).mbx.count'Old - 1)
   is
   begin
      os_task_rw (task_id).mbx.count :=
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
      Global => (In_Out => os_task_rw),
      Pre => (os_ghost_task_mbx_are_well_formed (dest_id) and
              os_mbx_get_mbx_count (dest_id) < os_mbx_count_t'Last),
      Post => ((os_mbx_get_mbx_count (dest_id) =
                 os_task_rw (dest_id).mbx.count'Old + 1) and
              (os_task_rw (dest_id).mbx.mbx_array
                       (os_ghost_get_mbx_tail (dest_id))
                       .sender_id = src_id))
   is
      mbx_index : constant os_mbx_index_t := os_mbx_get_mbx_head (dest_id) +
        os_mbx_get_mbx_count (dest_id);
   begin
      os_task_rw (dest_id).mbx.mbx_array (mbx_index).sender_id :=
         src_id;
      os_task_rw (dest_id).mbx.mbx_array (mbx_index).msg := mbx_msg;
      os_mbx_inc_mbx_count (dest_id);
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
      Global => (In_Out => (os_task_ready_list_head, os_task_rw, os_ghost_task_ready),
                 Input => os_task_ro),
      Pre => os_ghost_task_list_is_well_formed,
      Post => os_ghost_task_list_is_well_formed and
              os_ghost_task_is_ready (task_id)
   is
      index_id : os_task_id_t := os_sched_get_current_list_head;
   begin

      if index_id = OS_TASK_ID_NONE then
         --  No task in the ready list. Add this task at list head
         os_task_rw (task_id).next := OS_TASK_ID_NONE;
         os_task_rw (task_id).prev := OS_TASK_ID_NONE;
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
                  prev_id : constant os_task_id_t := os_task_rw (index_id).prev;
               begin
                  os_task_rw (task_id).next  := index_id;
                  os_task_rw (index_id).prev := task_id;

                  if index_id = os_sched_get_current_list_head then
                     os_task_rw (task_id).prev := OS_TASK_ID_NONE;
                     os_sched_set_current_list_head (task_id);
                  else
                     os_task_rw (task_id).prev := prev_id;
                     if prev_id in os_task_id_param_t then
                        os_task_rw (prev_id).next := task_id;
                     end if;
                  end if;
                  exit;
               end;
            elsif os_task_rw (index_id).next = OS_TASK_ID_NONE then
               os_task_rw (index_id).next := task_id;
               os_task_rw (task_id).prev  := index_id;
               os_task_rw (task_id).next  := OS_TASK_ID_NONE;
               exit;
            else
               index_id := os_task_rw (index_id).next;
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
                            os_task_rw,
                            os_ghost_task_ready),
                 Input => (os_task_current,
                           os_task_ro)),
      Pre => os_ghost_task_list_is_well_formed and
             os_ghost_current_task_is_ready,
      Post => os_task_rw (task_id).prev = OS_TASK_ID_NONE and
              os_task_rw (task_id).next = OS_TASK_ID_NONE and
              os_ghost_task_list_is_well_formed and
              not os_ghost_task_is_ready (task_id)
   is
      next : constant os_task_id_t := os_task_rw (task_id).next;
   begin
      if task_id = os_sched_get_current_list_head then
         --  We are removing the current running task. So put the next task at
         --  list head. Note: there could be no next task (OS_TASK_ID_NONE)
         if next /= OS_TASK_ID_NONE then
            os_task_rw (next).prev := OS_TASK_ID_NONE;
         end if;
         os_sched_set_current_list_head (next);
      elsif os_sched_get_current_list_head /= OS_TASK_ID_NONE then
         --  The list is not empty and
         --  The task is not at the list head (it has a predecesor).
         --  Link previous next to our next
         declare
            prev : constant os_task_id_t := os_task_rw (task_id).prev;
         begin
            if prev /= OS_TASK_ID_NONE then
               os_task_rw (prev).next := next;
            end if;

            if next /= OS_TASK_ID_NONE then
               --  if we have a next, link next previous to our previous.
               os_task_rw (next).prev := prev;
            end if;
         end;
      end if;

      --  reset our next and previous
      os_task_rw (task_id).next := OS_TASK_ID_NONE;
      os_task_rw (task_id).prev := OS_TASK_ID_NONE;

      os_ghost_task_ready (task_id) := false;

   end os_sched_remove_task_from_ready_list;

   -----------------------
   -- os_sched_schedule --
   -----------------------

   procedure os_sched_schedule (task_id : out os_task_id_param_t)
   with
   Global => (In_Out => (os_task_ready_list_head, os_task_rw, os_ghost_task_ready),
              Output => os_task_current,
              Input => os_task_ro),
   Pre => os_ghost_task_list_is_well_formed,
   Post => os_ghost_task_list_is_well_formed and
           os_ghost_task_is_ready (task_id)
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

      --  Return the ID of the elected task to allow context switch at low
      --  (arch) level
   end os_sched_schedule;

   ---------------------------------
   -- os_mbx_get_mbx_entry_sender --
   ---------------------------------

   function os_mbx_get_mbx_entry_sender
     (task_id   : os_task_id_param_t;
      mbx_index : os_mbx_index_t) return os_task_id_param_t
   is (os_task_id_param_t (os_task_rw (task_id).mbx.mbx_array
           (mbx_index).sender_id))
   with
      Pre => os_task_rw (task_id).mbx.mbx_array
                  (mbx_index).sender_id in os_task_id_param_t;

   ----------------------------
   -- os_mbx_get_posted_mask --
   ----------------------------

   function os_mbx_get_posted_mask
     (task_id : os_task_id_param_t) return os_mbx_mask_t
   with
      Global => (Input => (os_task_rw)),
      Pre => os_ghost_task_mbx_are_well_formed (task_id)
   is
      mbx_mask  : os_mbx_mask_t := 0;
      mbx_index : os_mbx_index_t;
   begin

      if not os_mbx_is_empty (task_id) then
         mbx_index := os_mbx_get_mbx_head (task_id);
         for iterator in 1 .. os_mbx_get_mbx_count (task_id)
         loop
             mbx_mask :=
              mbx_mask or
              os_mbx_mask_t (Shift_Left
                (Unsigned_32'(1),
                 Natural (os_mbx_get_mbx_entry_sender (task_id, mbx_index))));
            mbx_index := os_mbx_index_t'Succ(mbx_index);
         end loop;
      end if;

      return mbx_mask;
   end os_mbx_get_posted_mask;

   --------------------------
   -- os_mbx_send_one_task --
   --------------------------

   procedure os_mbx_send_one_task
     (status  : out os_status_t;
      dest_id :     os_task_id_param_t;
      mbx_msg :     os_mbx_msg_t)
   with
      Global => (In_Out => (os_task_ready_list_head, os_task_rw, os_ghost_task_ready),
                Input => (os_task_ro, os_task_current)),
      Pre => os_ghost_task_list_is_well_formed and
             os_ghost_current_task_is_ready,
      Post => os_ghost_task_list_is_well_formed and
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
      mbx_msg :     os_mbx_msg_t)
   with
      Global => (In_Out => (os_task_ready_list_head, os_task_rw, os_ghost_task_ready),
                 Input => (os_task_ro, os_task_current)),
      Pre => os_ghost_task_list_is_well_formed and
             os_ghost_current_task_is_ready,
      Post => os_ghost_task_list_is_well_formed and
              os_ghost_current_task_is_ready
   is
      ret : os_status_t;
   begin
      status := OS_ERROR_DENIED;

      for iterator in os_task_rw'Range loop
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
      os_task_rw (task_id).mbx.mbx_array (mbx_index).sender_id :=
                                                               OS_TASK_ID_NONE;
      os_task_rw (task_id).mbx.mbx_array (mbx_index).msg := 0;
   end os_mbx_clear_mbx_entry;

   --------------------------
   -- os_mbx_set_mbx_entry --
   --------------------------
   --  No contract, it will be inlined

   procedure os_mbx_set_mbx_entry
     (task_id   : os_task_id_param_t;
      mbx_index : os_mbx_index_t;
      mbx_entry : os_mbx_entry_t)
   is
   begin
      os_task_rw (task_id).mbx.mbx_array (mbx_index) := mbx_entry;
   end os_mbx_set_mbx_entry;

   --------------------------
   -- os_mbx_get_mbx_entry --
   --------------------------

   function os_mbx_get_mbx_entry
     (task_id   : os_task_id_param_t;
      mbx_index : os_mbx_index_t) return os_mbx_entry_t
   is (os_task_rw (task_id).mbx.mbx_array (mbx_index));

   ---------------------------------
   -- os_mbx_is_waiting_mbx_entry --
   ---------------------------------

   function os_mbx_is_waiting_mbx_entry
     (task_id   : os_task_id_param_t;
      mbx_index : os_mbx_index_t) return Boolean
   is ((os_mbx_get_waiting_mask (task_id) and
        os_mbx_mask_t (Shift_Left
                (Unsigned_32'(1), Natural (os_mbx_get_mbx_entry_sender
                (task_id, mbx_index))))) /= 0)
   with
      Pre => not os_mbx_is_empty (task_id)
             and
                (for some index in 0 .. (os_mbx_get_mbx_count (task_id) - 1) =>
                          (os_mbx_get_mbx_head (task_id) + index) = mbx_index)
             and os_task_rw (task_id).mbx.mbx_array
                          (mbx_index).sender_id in os_task_id_param_t;

   ----------------------
   --  Ghost functions --
   ----------------------

   ------------------------------
   -- os_ghost_not_next_twice --
   ------------------------------
   --  A task_id should not be twice in next attribute

   function os_ghost_not_next_twice (task_id : os_task_id_t) return Boolean is
      (not
         (for some next_id in os_task_rw'Range =>
            os_task_rw (next_id).next = task_id
            and
               (for some next_id2 in next_id .. os_task_rw'Last =>
                  os_task_rw (next_id2).next = task_id)))
   with
      Ghost => true;

   ------------------------------
   -- os_ghost_not_prev_twice --
   ------------------------------
   --  A task_id should not be twice in prev attribute

   function os_ghost_not_prev_twice (task_id : os_task_id_t) return Boolean is
      (not
         (for some prev_id in os_task_rw'Range =>
            os_task_rw (prev_id).prev = task_id
            and
               (for some prev_id2 in prev_id .. os_task_rw'Last =>
                  os_task_rw (prev_id2).prev = task_id)))
   with
      Ghost => true;

   --------------------------------------------
   -- os_ghost_at_least_one_terminating_next --
   --------------------------------------------
   --  There should be at leat one task that has no next.
   --  The last element of the list has no next.
   --  If there is no first element then all no element has any next

   function os_ghost_at_least_one_terminating_next return Boolean is
      (for some task_id in os_task_rw'Range =>
         os_task_rw (task_id).next = OS_TASK_ID_NONE)
   with
      Ghost => true;

   --------------------------------------------
   -- os_ghost_at_least_one_terminating_prev --
   --------------------------------------------
   --  There should be at leat one task that has no prev.
   --  The first element of the list has no prev.
   --  If there is no first element then all no element has any prev

   function os_ghost_at_least_one_terminating_prev return Boolean is
      (for some task_id in os_task_rw'Range =>
         os_task_rw (task_id).prev = OS_TASK_ID_NONE)
   with
      Ghost => true;

   ----------------------------
   -- os_ghost_task_is_ready --
   ----------------------------

   function os_ghost_task_is_ready (task_id : os_task_id_param_t) return Boolean
   is (os_ghost_task_ready (task_id));

   ------------------------------------
   -- os_ghost_current_task_is_ready --
   ------------------------------------

   function os_ghost_current_task_is_ready return Boolean
   is (os_ghost_task_is_ready(os_sched_get_current_task_id));

   ---------------------------------------
   -- os_ghost_task_mbx_are_well_formed --
   ---------------------------------------
   --  MBX are circular FIFO (contained in an array) where head is the index
   --  of the fisrt element of the FIFO and count is the number of element
   --  stored in the FIFO.
   --  When an element of the FIFO is filled its sender_id field needs to be
   --  >= 0. When an element in the circular FIFO is empty, its sender_if field
   --  is -1 (OS_TASK_ID_NONE).
   --  So this condition makes sure that all non empty element of the circular
   --  FIFO have sender_id >= 0 and empty elements of the FIFO have sender_id
   --  = -1.

   function os_ghost_task_mbx_are_well_formed (task_id : os_task_id_param_t) return Boolean is
      (for all index in os_mbx_index_t'Range =>
         (if (((os_mbx_get_mbx_count (task_id) > 0) and
              (os_ghost_get_mbx_tail (task_id)
                        < os_mbx_get_mbx_head (task_id)) and
              ((index >= os_mbx_get_mbx_head (task_id)) or
               (index <= os_ghost_get_mbx_tail (task_id))))
          or
             ((os_mbx_get_mbx_count (task_id) > 0) and
              (index in os_mbx_get_mbx_head (task_id) ..
                        os_ghost_get_mbx_tail (task_id))))
          then os_task_rw (task_id).mbx.mbx_array (index).sender_id
                        in os_task_id_param_t
          else os_task_rw (task_id).mbx.mbx_array (index).sender_id
                        = OS_TASK_ID_NONE));

   ----------------------------------
   -- os_ghost_mbx_are_well_formed --
   ----------------------------------

   function os_ghost_mbx_are_well_formed return Boolean is
      (for all task_id in os_task_rw'Range =>
         os_ghost_task_mbx_are_well_formed (task_id));

   -------------------------------------------------
   -- os_ghost_head_list_task_has_higher_priority --
   -------------------------------------------------

   function os_ghost_head_list_task_has_higher_priority return Boolean is
      (os_sched_get_current_list_head /= OS_TASK_ID_NONE and
       os_ghost_task_is_ready (os_sched_get_current_list_head) and
         (for some task_id in os_task_rw'Range =>
            os_ghost_task_is_ready (task_id) and
            os_get_task_priority (task_id)
               <= os_get_task_priority (os_sched_get_current_list_head)))
   with
      Ghost => true;

   ---------------------------------------
   -- os_ghost_task_list_is_well_formed --
   ---------------------------------------

   function os_ghost_task_list_is_well_formed return Boolean is
      --  The mbx fifo of all tasks need to be well formed.
      (os_ghost_mbx_are_well_formed
       and
       (
        --  The list might be empty. This is legal.
        (os_sched_get_current_list_head = OS_TASK_ID_NONE and
         -- then all element are diconnected (not in a list)
         (for all task_id in os_task_rw'Range =>
            -- no next
            os_task_rw (task_id).next = OS_TASK_ID_NONE
            -- no prev
            and os_task_rw (task_id).prev = OS_TASK_ID_NONE
            -- and all tasks are in not ready state
            and not (os_ghost_task_is_ready (task_id))
         )
        )
       or
        --  If there is at least one task in the list.
        (os_sched_get_current_list_head /= OS_TASK_ID_NONE
        --  the first task of the list should not have any prev task.
         and os_task_rw (os_sched_get_current_list_head).prev
                                   = OS_TASK_ID_NONE
         -- the first task needs to be in ready state
         and os_ghost_task_is_ready (os_sched_get_current_list_head)
         -- there need to ba at least one terminating next.
         and os_ghost_at_least_one_terminating_next
         --  First element is well formed.
         --  Go through the list
         and
            (for all task_id in os_task_rw'Range =>
               --  a task cannot have itself as next.
               os_task_rw (task_id).next /= task_id
               --  a task cannot have itself as prev.
               and os_task_rw (task_id).prev /= task_id
               --  a task could not be next more than once
               and os_ghost_not_next_twice (task_id)
               --  a task could not be prev more than once
               and os_ghost_not_prev_twice (task_id)
               --  If there is a next
               and
                  -- If a task has a next then it is part of the ready list
                  (if os_task_rw (task_id).next /= OS_TASK_ID_NONE then
                     --  Its next needs to be in ready state
                     os_ghost_task_is_ready (os_task_rw (task_id).next)
                     --  It needs to be in ready state itself
                     and os_ghost_task_is_ready (task_id)
                     -- The next needs to have the actual task as prev
                     and os_task_rw (os_task_rw
                             (task_id).next).prev = task_id
                     --  prev and next need to be different
                     and os_task_rw (task_id).next
                                         /= os_task_rw (task_id).prev
                     -- It needs to be ordered on priority
                     and os_get_task_priority (os_task_rw (task_id).next)
                        <= os_get_task_priority (task_id))))
      ));

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
      waiting_mask :     os_mbx_mask_t)
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
            --  If waited event is already here, put back the task in the
            --  ready list (after tasks of same priority).
            os_sched_add_task_to_ready_list (task_id);
         end if;
      elsif task_id /= OS_INTERRUPT_TASK_ID then
         --  This is an error/illegal case. There is nothing to wait for,
         --  so put back the task in the ready list.
         os_sched_add_task_to_ready_list (task_id);
      end if;

      --  We determine the new task.
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
      prev_id : os_task_id_param_t := os_task_rw'First;
   begin
      os_arch_cons_init;

      os_arch_space_init;

      os_sched_set_current_list_head (OS_TASK_ID_NONE);

      for task_iterator in os_task_rw'Range loop
         os_arch_space_switch (prev_id, task_iterator);

         os_arch_context_create (task_iterator);

         for mbx_iterator in os_task_rw (task_iterator).mbx.mbx_array'Range loop
            os_mbx_clear_mbx_entry (task_iterator, mbx_iterator);
         end loop;

         os_task_rw (task_iterator).mbx.head := 0;
         os_task_rw (task_iterator).mbx.count := 0;
         os_task_rw (task_iterator).mbx_waiting_mask := 0;

         os_task_rw (task_iterator).next := OS_TASK_ID_NONE;
         os_task_rw (task_iterator).prev := OS_TASK_ID_NONE;

         prev_id := task_iterator;

         os_ghost_task_ready (task_iterator) := false;
      end loop;

      for task_iterator in os_task_rw'Range loop
         os_sched_add_task_to_ready_list (task_iterator);
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
      --  retrieve current task id
      current        : constant os_task_id_param_t := os_sched_get_current_task_id;
      mbx_index      : os_mbx_index_t;
      next_mbx_index : os_mbx_index_t;
   begin
      mbx_entry.sender_id := OS_TASK_ID_NONE;
      mbx_entry.msg       := 0;

      if os_mbx_is_empty (current) then
         --  mbx queue is empty, so we return with error
         status := OS_ERROR_FIFO_EMPTY;
      else
         --  initialize status to error in case we don't find a mbx.
         status := OS_ERROR_RECEIVE;

         --  Compute the first mbx_index for the loop
         mbx_index := os_mbx_get_mbx_head (current);

         --  go through received mbx for this task
         for iterator in 1 .. os_mbx_get_mbx_count (current) loop

            --  look into the mbx queue for a mbx that is waited for
            if os_mbx_is_waiting_mbx_entry (current, mbx_index) then

               --  copy the mbx into the task mbx entry
               mbx_entry := os_mbx_get_mbx_entry (current, mbx_index);

               if iterator = 1 then
                  --  if this was the first mbx, we just increase the mbx head
                  os_mbx_inc_mbx_head (current);
               elsif iterator < os_mbx_get_mbx_count (current) then
                  --  in other case, for now we "compact" the rest of the mbx
                  --  queue, so that there is no "hole" in it for the next mbx
                  --  search.
                  for iterator2 in os_mbx_count_t'Succ (iterator) ..
                          os_mbx_get_mbx_count (current)
                  loop
                     next_mbx_index := os_mbx_index_t'Succ (mbx_index);
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
            --  Compute the next mbx_index for the loop
            mbx_index := os_mbx_index_t'Succ(mbx_index);
         end loop;
      end if;
   end os_mbx_receive;

   -----------------
   -- os_mbx_send --
   -----------------

   procedure os_mbx_send
     (status  : out os_status_t;
      dest_id :     types.int8_t;
      mbx_msg :     os_mbx_msg_t)
   is
      -- dest_id comes from uncontroled C calls
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
