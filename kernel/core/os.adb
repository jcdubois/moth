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

   -- Max mbx count is provided through configuration
   OS_MAX_MBX_CNT      : constant := OpenConf.CONFIG_TASK_MBX_COUNT;

   -- Type to define a mbx index
   type os_mbx_index_t is mod OS_MAX_MBX_CNT;

   -- Type to define the number of mbx in the task FIFO
   subtype os_mbx_count_t is types.uint8_t range 0 .. OS_MAX_MBX_CNT;

   -- Type to define the task FIFO
   type os_mbx_t_array is array (os_mbx_index_t) of os_mbx_entry_t;

   -- This structure allows to manage mbx for one task
   type os_mbx_t is record
      head             : os_mbx_index_t;
      count            : os_mbx_count_t;
      mbx_array        : os_mbx_t_array;
   end record;

   -- This specific type is used to make sure we exit from recursive
   -- loop in functions used for proof (Ghost)
   subtype os_recurs_cnt_t is types.int8_t
                         range OS_MIN_TASK_ID .. OS_MAX_TASK_CNT;

   -----------------------
   -- Private variables --
   -----------------------

   -------------------------------------
   -- Ghost variable for task's state --
   -------------------------------------

   os_ghost_task_list_ready : array (os_task_id_param_t) of Boolean with Ghost;

   -----------------------
   -- os_task_list_next --
   -----------------------

   os_task_list_next : array (os_task_id_param_t) of os_task_id_t;

   -----------------------
   -- os_task_list_prev --
   -----------------------

   os_task_list_prev : array (os_task_id_param_t) of os_task_id_t;

   ---------------------------
   -- os_task_list_mbx_mask --
   ---------------------------

   os_task_list_mbx_mask : array (os_task_id_param_t) of os_mbx_mask_t;

   ---------------------------
   -- os_task_list_mbx_fifo --
   ---------------------------

   os_task_list_mbx_fifo : array (os_task_id_param_t) of os_mbx_t;

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

   -----------------------------
   -- os_task_ready_list_head --
   -----------------------------

   os_task_ready_list_tail : os_task_id_t;

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

   ---------------------
   -- os_mbx_is_empty --
   ---------------------
   --  Check if the mbx fifo of a given task is empty.

   function os_mbx_is_empty (task_id : os_task_id_param_t) return Boolean
   is (os_task_list_mbx_fifo (task_id).count = os_mbx_count_t'First);

   --------------------
   -- os_mbx_is_full --
   --------------------
   --  Check if the mbx fifo of a given task is full.

   function os_mbx_is_full (task_id : os_task_id_param_t) return Boolean
   is (os_task_list_mbx_fifo (task_id).count = os_mbx_count_t'Last);

   -------------------------
   -- os_mbx_get_mbx_head --
   -------------------------
   --  Retrieve the mbx head index of the given task.

   function os_mbx_get_mbx_head
     (task_id : os_task_id_param_t) return os_mbx_index_t
   is (os_task_list_mbx_fifo (task_id).head);

   -------------------------
   -- os_mbx_inc_mbx_head --
   -------------------------
   --  Increment the mbx head index of the given task.
   --  No contract, it will be inlined

   procedure os_mbx_inc_mbx_head (task_id : os_task_id_param_t)
   is
   begin
      os_task_list_mbx_fifo (task_id).head :=
              os_mbx_index_t'Succ (os_mbx_get_mbx_head (task_id));
   end os_mbx_inc_mbx_head;

   --------------------------
   -- os_mbx_get_mbx_count --
   --------------------------
   --  Retrieve the mbx count of the given task.

   function os_mbx_get_mbx_count
     (task_id : os_task_id_param_t) return os_mbx_count_t
   is (os_task_list_mbx_fifo (task_id).count);

   -------------------------
   -- os_mbx_get_mbx_tail --
   -------------------------
   --  Retrieve the mbx tail index of the given task.

   function os_mbx_get_mbx_tail
     (task_id : os_task_id_param_t) return os_mbx_index_t
   is (os_mbx_get_mbx_head (task_id) +
       os_mbx_count_t'Pred (os_mbx_get_mbx_count (task_id)))
   with
      Global => (Input => os_task_list_mbx_fifo),
      Pre => not os_mbx_is_empty (task_id);

   --------------------------
   -- os_mbx_inc_mbx_count --
   --------------------------
   --  Increment the mbx count of the given task.

   procedure os_mbx_inc_mbx_count (task_id : os_task_id_param_t)
   with
      Global => (In_Out => os_task_list_mbx_fifo),
      Pre => (os_task_list_mbx_fifo (task_id).count < os_mbx_count_t'Last),
      Post => os_task_list_mbx_fifo = os_task_list_mbx_fifo'Old'Update (task_id => os_task_list_mbx_fifo'Old (task_id)'Update (count => os_task_list_mbx_fifo'Old (task_id).count + 1))
   is
   begin
      os_task_list_mbx_fifo (task_id).count :=
              os_mbx_count_t'Succ (os_mbx_get_mbx_count (task_id));
   end os_mbx_inc_mbx_count;

   --------------------------
   -- os_mbx_dec_mbx_count --
   --------------------------
   --  Decrement the mbx count of the given task.

   procedure os_mbx_dec_mbx_count (task_id : os_task_id_param_t)
   with
      Global => (In_Out => os_task_list_mbx_fifo),
      Pre => (not os_mbx_is_empty (task_id)),
      Post => os_task_list_mbx_fifo = os_task_list_mbx_fifo'Old'Update (task_id => os_task_list_mbx_fifo'Old (task_id)'Update (count => os_task_list_mbx_fifo'Old (task_id).count - 1))
   is
   begin
      os_task_list_mbx_fifo (task_id).count :=
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
      Global => (In_Out => os_task_list_mbx_fifo),
      Pre  => ((not os_mbx_is_full (dest_id)) and then
               os_ghost_mbx_are_well_formed),
      Post => ((not os_mbx_is_empty (dest_id)) and then
               (os_task_list_mbx_fifo = os_task_list_mbx_fifo'Old'Update (dest_id => os_task_list_mbx_fifo'Old (dest_id)'Update (count => os_task_list_mbx_fifo'Old (dest_id).count + 1, head => os_task_list_mbx_fifo'Old (dest_id).head, mbx_array => os_task_list_mbx_fifo'Old (dest_id).mbx_array'Update (os_mbx_get_mbx_tail (dest_id) => os_task_list_mbx_fifo'Old (dest_id).mbx_array (os_mbx_get_mbx_tail (dest_id))'Update (sender_id => src_id, msg => mbx_msg))))) and then
               os_ghost_mbx_are_well_formed)
   is
      mbx_index : os_mbx_index_t;
   begin
      os_mbx_inc_mbx_count (dest_id);
      mbx_index := os_mbx_get_mbx_tail (dest_id);
      os_task_list_mbx_fifo (dest_id).mbx_array (mbx_index).sender_id := src_id;
      os_task_list_mbx_fifo (dest_id).mbx_array (mbx_index).msg := mbx_msg;
   end os_mbx_add_message;

   -------------------------------------
   -- os_sched_add_task_to_ready_list --
   -------------------------------------

   procedure os_sched_add_task_to_ready_list (task_id : os_task_id_param_t)
   with
      Global => (In_Out => (os_task_ready_list_head,
                            os_task_ready_list_tail,
                            os_task_list_next,
                            os_task_list_prev,
                            os_ghost_task_list_ready),
                 Input  => os_task_ro),
      Pre => os_ghost_task_list_is_well_formed,
      Post => os_ghost_task_list_ready = os_ghost_task_list_ready'Old'Update (task_id => true) and then
              os_ghost_task_list_is_well_formed
   is
      index_id : os_task_id_t := os_task_ready_list_head;
   begin

      pragma assert (os_ghost_task_list_is_well_formed);

      if index_id = OS_TASK_ID_NONE then
         -- list head is empty, so the added task needs not to be ready.
         pragma assert (not os_ghost_task_list_ready (task_id));
         pragma assert (os_task_ready_list_tail = OS_TASK_ID_NONE);

         --  No task in the ready list. Add this task at list head
         os_task_list_next (task_id) := OS_TASK_ID_NONE;
         os_task_list_prev (task_id) := OS_TASK_ID_NONE;
         os_task_ready_list_head := task_id;
         os_task_ready_list_tail := task_id;
         os_ghost_task_list_ready (task_id) := true;

         pragma assert (os_ghost_task_list_is_well_formed);
      else
         -- index_id is list head, so its prec needs to be empty
         pragma assert (os_task_list_prev (index_id) = OS_TASK_ID_NONE);

         while index_id /= OS_TASK_ID_NONE loop
            pragma Loop_Invariant (os_ghost_task_list_is_well_formed);
            pragma Loop_Invariant (os_ghost_task_list_ready = os_ghost_task_list_ready'Loop_Entry);
            -- At any step in the loop index_id needs to be ready
            pragma assert (index_id /= OS_TASK_ID_NONE);
            pragma assert (os_ghost_task_list_ready (index_id));
            if index_id = task_id then
               pragma assert (os_ghost_task_list_ready (task_id));
               --  Already in the ready list, nothing to do
               exit;
            elsif os_get_task_priority (task_id) >
                  os_get_task_priority (index_id) then
               -- task_id is higher priority so it needs to be inserted before
               -- index_id
               declare
                  prev_id : constant os_task_id_t :=
                                            os_task_list_prev (index_id);
               begin
                  pragma assert (os_ghost_task_list_is_well_formed);

                  os_task_list_prev (index_id) := task_id;
                  os_task_list_prev (task_id) := prev_id;
                  os_task_list_next (task_id) := index_id;
                  os_ghost_task_list_ready (task_id) := true;
                  pragma assert (os_get_task_priority (task_id) > os_get_task_priority (index_id));

                  if prev_id = OS_TASK_ID_NONE then
                     pragma assert (index_id = os_task_ready_list_head);
                     os_task_ready_list_head := task_id;
                  else
                     pragma assert (index_id /= os_task_ready_list_head);
                     pragma assert (os_get_task_priority (prev_id) >= os_get_task_priority (index_id));
                     pragma assert (os_get_task_priority (task_id) >= os_get_task_priority (index_id));
                     pragma assert (os_get_task_priority (prev_id) >= os_get_task_priority (task_id));
                     os_task_list_next (prev_id) := task_id;
                  end if;

                  pragma assert (os_ghost_task_list_is_well_formed);
                  exit;
               end;
            elsif os_task_list_next (index_id) = OS_TASK_ID_NONE then
               pragma assert (os_ghost_task_list_is_well_formed);
               pragma assert (os_task_ready_list_tail = index_id);
               pragma assert (os_get_task_priority (task_id) <= os_get_task_priority (index_id));

               os_task_list_next (index_id) := task_id;
               os_task_list_prev (task_id)  := index_id;
               os_task_list_next (task_id)  := OS_TASK_ID_NONE;
               os_task_ready_list_tail      := task_id;
               os_ghost_task_list_ready (task_id) := true;

               pragma assert (os_ghost_task_list_is_well_formed);
               exit;
            else
               pragma assert (os_ghost_task_list_is_well_formed);
               index_id := os_task_list_next (index_id);
            end if;
         end loop;
      end if;

      -- os_ghost_task_list_ready (task_id) := true;

      pragma assert (os_ghost_task_list_is_well_formed);
   end os_sched_add_task_to_ready_list;

   ------------------------------------------
   -- os_sched_remove_task_from_ready_list --
   ------------------------------------------

   procedure os_sched_remove_task_from_ready_list
     (task_id : os_task_id_param_t)
   with
      Global => (In_Out => (os_task_ready_list_head,
                            os_task_ready_list_tail,
                            os_task_list_prev,
                            os_task_list_next,
                            os_ghost_task_list_ready),
                 Input  => (os_task_ro)),
      Pre =>  (os_ghost_task_list_ready (task_id) and then
               os_ghost_task_list_is_well_formed),
      Post => os_ghost_task_list_ready =
                     os_ghost_task_list_ready'Old'Update (task_id => false) and then
              os_ghost_task_list_is_well_formed
   is
      next_id : constant os_task_id_t := os_task_list_next (task_id);
      prev_id : constant os_task_id_t := os_task_list_prev (task_id);
   begin
      -- As there is a ready task, the list head cannot be empty
      -- pragma assert (os_task_ready_list_head /= OS_TASK_ID_NONE);
      -- pragma assert (os_task_ready_list_tail /= OS_TASK_ID_NONE);
      -- pragma assert (os_ghost_task_is_linked_to_tail (task_id));
      -- pragma assert (os_ghost_task_is_linked_to_head (task_id));
      if next_id /= OS_TASK_ID_NONE then
         pragma assert (os_ghost_task_is_linked_to_tail (next_id));
         pragma assert (os_ghost_task_is_linked_to_head (next_id));
      end if;
      -- if prev_id /= OS_TASK_ID_NONE then
         -- pragma assert (os_ghost_task_is_linked_to_tail (prev_id));
         -- pragma assert (os_ghost_task_is_linked_to_head (prev_id));
      -- end if;
      -- pragma assert (os_ghost_task_list_is_well_formed);
      -- pragma assert (os_ghost_task_list_ready (os_task_ready_list_head));
      -- pragma assert (os_ghost_task_list_is_well_formed);
      -- pragma assert (os_ghost_task_list_ready (os_task_ready_list_head));
      -- pragma assert (os_ghost_task_list_ready (os_task_ready_list_tail));
      -- pragma assert (os_ghost_task_is_linked_to_tail (os_task_ready_list_head));
      -- pragma assert (os_ghost_task_is_linked_to_head (os_task_ready_list_tail));
      -- pragma assert (os_ghost_task_list_is_well_formed);

      os_task_list_next (task_id) := OS_TASK_ID_NONE;
      os_task_list_prev (task_id) := OS_TASK_ID_NONE;

      os_ghost_task_list_ready (task_id) := false;

      if task_id = os_task_ready_list_tail then
         -- As task_id is the list tail, its next needs to be empty.
         pragma assert (next_id = OS_TASK_ID_NONE);

         -- Set the new list tail (the prev from the removed task)
         -- Note: prev could be set to OS_TASK_ID_NONE
         os_task_ready_list_tail := prev_id;

         if prev_id /= OS_TASK_ID_NONE then
            -- prev is a valid task and needs to be ready
            pragma assert (os_ghost_task_list_ready (prev_id));

            -- The new list tail [prev] has no next
            os_task_list_next (prev_id) := OS_TASK_ID_NONE;

            -- pragma assert (os_ghost_task_is_linked_to_tail (prev_id));
         -- else
            -- pragma assert (for all id in os_task_id_param_t'Range =>
                           -- os_task_list_next (id) = OS_TASK_ID_NONE);
            -- pragma assert (for all id in os_task_id_param_t'Range =>
                           -- os_task_list_prev (id) = OS_TASK_ID_NONE);
            -- pragma assert (for all id in os_task_id_param_t'Range =>
                           -- os_ghost_task_list_ready (id) = false);
         end if;
      else
         --  The list is not empty and the task is not at the list tail.

         --  task_id need to have a valid next as it is not at list tail
         pragma assert (next_id /= OS_TASK_ID_NONE);

         --  next is valid and it needs to be ready
         pragma assert (os_ghost_task_list_ready (next_id));

         --  for now the prev of next is task_id
         pragma assert (os_task_list_prev (next_id) = task_id);

         -- pragma assert (os_ghost_task_is_linked_to_tail (next_id));
         --  link prev from next task to our prev
         os_task_list_prev (next_id) := prev_id;

         -- pragma assert (os_ghost_task_is_linked_to_tail (next_id));
      end if;

      if task_id = os_task_ready_list_head then
         -- As task_id is the list head, its prev needs to be empty.
         pragma assert (prev_id = OS_TASK_ID_NONE);

         -- Set the new list head (the next from the removed task)
         -- Note: next could be set to OS_TASK_ID_NONE
         os_task_ready_list_head := next_id;

         if next_id /= OS_TASK_ID_NONE then
            -- next is a valid task and needs to be ready
            pragma assert (os_ghost_task_list_ready (next_id));
            pragma assert (os_task_ready_list_tail /= OS_TASK_ID_NONE);

            -- The new list head [next] has no prev
            os_task_list_prev (next_id) := OS_TASK_ID_NONE;

            pragma assert (os_ghost_task_is_linked_to_tail (next_id));
            pragma assert (os_ghost_task_is_linked_to_head (next_id));
            pragma assert (os_ghost_task_is_linked_to_tail (os_task_ready_list_head));
            pragma assert (os_ghost_task_is_linked_to_head (os_task_ready_list_tail));
            pragma assert (os_ghost_task_list_is_well_formed);
         else
            -- The list is now empty. We can check all tasks are not ready
            -- and that they are not part of any ready list.
            pragma assert (os_task_ready_list_head = OS_TASK_ID_NONE);
            pragma assert (os_task_ready_list_tail = OS_TASK_ID_NONE);
            pragma assert (for all id in os_task_id_param_t'Range =>
                           os_task_list_next (id) = OS_TASK_ID_NONE);
            pragma assert (for all id in os_task_id_param_t'Range =>
                           os_task_list_prev (id) = OS_TASK_ID_NONE);
            pragma assert (for all id in os_task_id_param_t'Range =>
                           os_ghost_task_list_ready (id) = false);
            pragma assert (os_ghost_task_list_is_well_formed);
         end if;

         pragma assert (os_ghost_task_list_is_well_formed);
      else
         --  The list is not empty and the task is not at the list head.

         --  task_id need to have a valid prev as it is not at list head
         pragma assert (prev_id /= OS_TASK_ID_NONE);

         --  prev is valid and it needs to be ready
         pragma assert (os_ghost_task_list_ready (prev_id));

         --  link next from prev task to our next
         os_task_list_next (prev_id) := next_id;

         -- pragma assert (os_ghost_task_is_linked_to_tail (next_id));
         pragma assert (os_ghost_task_is_linked_to_tail (prev_id));
         pragma assert (os_ghost_task_is_linked_to_head (prev_id));
         pragma assert (os_ghost_task_list_is_well_formed);
      end if;

      pragma assert (os_ghost_task_list_is_well_formed);
   end os_sched_remove_task_from_ready_list;

   -----------------------
   -- os_sched_schedule --
   -----------------------

   procedure os_sched_schedule (task_id : out os_task_id_param_t)
   with
   Global => (In_Out => (os_task_ready_list_head,
                         os_task_ready_list_tail,
                         os_task_list_next,
                         os_task_list_prev,
                         os_ghost_task_list_ready),
              Output => os_task_current,
              Input  => os_task_ro),
   Pre => os_ghost_task_list_is_well_formed,
   Post => os_ghost_task_list_ready (task_id) and then
           os_task_ready_list_head = task_id and then
           os_ghost_task_list_is_well_formed
   is
   begin
      --  Check interrupt status
      if os_arch_interrupt_is_pending = 1 then
         --  Put interrupt task in ready list if int is set.
         os_sched_add_task_to_ready_list (OS_INTERRUPT_TASK_ID);
      end if;

      while os_task_ready_list_head = OS_TASK_ID_NONE loop

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

      task_id := os_task_ready_list_head;

      --  Select the elected task as current task.
      os_task_current := task_id;

      --  Return the ID of the elected task to allow context switch at low
      --  (arch) level
   end os_sched_schedule;

   ---------------------------------
   -- os_mbx_get_mbx_entry_sender --
   ---------------------------------

   function os_mbx_get_mbx_entry_sender
     (task_id   : os_task_id_param_t;
      index : os_mbx_count_t) return os_task_id_param_t
   is (os_task_id_param_t (os_task_list_mbx_fifo (task_id).mbx_array
           (os_mbx_get_mbx_head (task_id) + index).sender_id))
   with
      Global => (Input => (os_task_list_mbx_fifo)),
      Pre => os_task_list_mbx_fifo (task_id).mbx_array
                  (os_mbx_get_mbx_head (task_id) + index).sender_id
                  in os_task_id_param_t;

   ----------------------------
   -- os_mbx_get_posted_mask --
   ----------------------------

   function os_mbx_get_posted_mask
     (task_id : os_task_id_param_t) return os_mbx_mask_t
   with
      Global => (Input => (os_task_list_mbx_fifo)),
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
                            os_task_ready_list_tail,
                            os_task_list_next,
                            os_task_list_prev,
                            os_ghost_task_list_ready,
                            os_task_list_mbx_fifo),
                 Input  => (os_task_ro,
                            os_task_current,
                            os_task_list_mbx_mask)),
      Pre => os_ghost_task_list_is_well_formed and
             os_ghost_mbx_are_well_formed and
             os_ghost_current_task_is_ready,
      Post => os_ghost_task_list_is_well_formed and
              os_ghost_mbx_are_well_formed and
              os_ghost_current_task_is_ready
   is
      current        : constant os_task_id_param_t := os_task_current;
      mbx_permission : constant os_mbx_mask_t :=
        os_mbx_get_mbx_permission (dest_id) and
        os_mbx_mask_t (Shift_Left (Unsigned_32'(1), Natural (current)));
   begin
      if mbx_permission /= 0 then
         if os_mbx_is_full (dest_id) then
            status := OS_ERROR_FIFO_FULL;
         else
            os_mbx_add_message (dest_id, current, mbx_msg);
            if (os_task_list_mbx_mask (dest_id) and
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
                            os_task_ready_list_tail,
                            os_task_list_next,
                            os_task_list_prev,
                            os_ghost_task_list_ready,
                            os_task_list_mbx_fifo),
                 Input  => (os_task_ro,
                            os_task_current,
                            os_task_list_mbx_mask)),
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

      for iterator in os_task_id_param_t'Range loop
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
      os_task_list_mbx_fifo (task_id).mbx_array (mbx_index).sender_id :=
                                                               OS_TASK_ID_NONE;
      os_task_list_mbx_fifo (task_id).mbx_array (mbx_index).msg := 0;
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
      os_task_list_mbx_fifo (task_id).mbx_array (os_mbx_get_mbx_head (task_id) + index) := mbx_entry;
   end os_mbx_set_mbx_entry;

   --------------------------
   -- os_mbx_get_mbx_entry --
   --------------------------

   function os_mbx_get_mbx_entry
     (task_id   : os_task_id_param_t;
      index : os_mbx_count_t) return os_mbx_entry_t
   is (os_task_list_mbx_fifo (task_id).mbx_array (os_mbx_get_mbx_head (task_id) + index));

   ---------------------------------
   -- os_mbx_is_waiting_mbx_entry --
   ---------------------------------

   function os_mbx_is_waiting_mbx_entry
     (task_id   : os_task_id_param_t;
      index : os_mbx_count_t) return Boolean
   is ((os_task_list_mbx_mask (task_id) and
        os_mbx_mask_t (Shift_Left
                (Unsigned_32'(1), Natural (os_mbx_get_mbx_entry_sender
                (task_id, index))))) /= 0)
   with
      Global => (Input => (os_task_list_mbx_mask, os_task_list_mbx_fifo)),
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
         (for some next_id in os_task_id_param_t'Range =>
            os_ghost_task_list_ready (next_id) and
            os_task_list_next (next_id) = task_id and
               (for some next_id2 in os_task_id_param_t'Range =>
                  next_id2 /= next_id and
                  os_ghost_task_list_ready (next_id2) and
                  os_task_list_next (next_id2) = task_id)))
   with
      Ghost => true;

   ------------------------------
   -- os_ghost_not_prev_twice --
   ------------------------------
   --  A task_id should not be twice in prev attribute

   function os_ghost_not_prev_twice (task_id : os_task_id_t) return Boolean is
      (not
         (for some prev_id in os_task_id_param_t'Range =>
            os_ghost_task_list_ready (prev_id) and
            os_task_list_prev (prev_id) = task_id and
               (for some prev_id2 in os_task_id_param_t'Range =>
                  prev_id2 /= prev_id and
                  os_ghost_task_list_ready (prev_id2) and
                  os_task_list_prev (prev_id2) = task_id)))
   with
      Ghost => true;

   ----------------------------
   -- os_ghost_task_is_ready --
   ----------------------------

   function os_ghost_task_is_ready (task_id : os_task_id_param_t) return Boolean
   is (os_ghost_task_list_ready (task_id));

   ------------------------------------
   -- os_ghost_current_task_is_ready --
   ------------------------------------

   function os_ghost_current_task_is_ready return Boolean
   is (os_ghost_task_is_ready (os_task_current));

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
          then (os_task_list_mbx_fifo (task_id).mbx_array (os_mbx_get_mbx_head (task_id) + index).sender_id = OS_TASK_ID_NONE)
          else (os_task_list_mbx_fifo (task_id).mbx_array (os_mbx_get_mbx_head (task_id) + index).sender_id in os_task_id_param_t)))
   with
      Ghost => true,
      Post => os_ghost_task_mbx_are_well_formed'Result =
         (for all index in os_mbx_index_t'Range =>
            (if (os_mbx_is_empty (task_id))
             then (os_task_list_mbx_fifo (task_id).mbx_array (index).sender_id
                     = OS_TASK_ID_NONE)
             else (if (((os_mbx_get_mbx_tail (task_id)
                            < os_mbx_get_mbx_head (task_id)) and
                        ((index >= os_mbx_get_mbx_head (task_id)) or
                         (index <= os_mbx_get_mbx_tail (task_id)))) or else
                       (index in os_mbx_get_mbx_head (task_id) ..
                                 os_mbx_get_mbx_tail (task_id)))
                   then (os_task_list_mbx_fifo (task_id).mbx_array (index).sender_id
                           in os_task_id_param_t)
                   else (os_task_list_mbx_fifo (task_id).mbx_array (index).sender_id
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

   function os_ghost_task_is_linked_to_head_recurs (task_id : os_task_id_param_t; recursive_count : os_recurs_cnt_t) return Boolean is
      (recursive_count < OS_MAX_TASK_CNT and then
       os_ghost_task_list_ready (task_id) and then
       os_ghost_not_prev_twice (task_id) and then
          (if os_task_list_prev (task_id) = OS_TASK_ID_NONE then
              (os_task_ready_list_head = task_id)
           else
              (os_task_list_next (task_id) /= task_id and
               os_task_list_prev (task_id) /= task_id and
               os_task_list_prev (task_id) /= os_task_list_next (task_id) and
               os_task_list_next (os_task_list_prev (task_id)) = task_id and
               os_get_task_priority (task_id) <= os_get_task_priority (os_task_list_prev (task_id)) and
               os_ghost_task_is_linked_to_head_recurs (os_task_list_prev (task_id), recursive_count + 1))))
   with
      Ghost => true;
   pragma Annotate (GNATprove, Terminating, os_ghost_task_is_linked_to_head_recurs);

   function os_ghost_task_is_linked_to_head (task_id : os_task_id_param_t) return Boolean is
      (os_ghost_task_is_linked_to_head_recurs (task_id, OS_MIN_TASK_ID));

   --------------------------------------
   -- os_ghost_task_is_linked_to_tail --
   --------------------------------------

   function os_ghost_task_is_linked_to_tail_recurs (task_id : os_task_id_param_t; recursive_count : os_recurs_cnt_t) return Boolean is
      (recursive_count < OS_MAX_TASK_CNT and then
       os_ghost_task_list_ready (task_id) and then
       os_ghost_not_next_twice (task_id) and then
          (if os_task_list_next (task_id) = OS_TASK_ID_NONE then
              (os_task_ready_list_tail = task_id)
           else
              (os_task_list_next (task_id) /= task_id and
               os_task_list_prev (task_id) /= task_id and
               os_task_list_prev (task_id) /= os_task_list_next (task_id) and
               os_task_list_prev (os_task_list_next (task_id)) = task_id and
               os_get_task_priority (task_id) >= os_get_task_priority (os_task_list_next (task_id)) and
               os_ghost_task_is_linked_to_tail_recurs (os_task_list_next (task_id), recursive_count + 1))))
   with
      Ghost => true;
   pragma Annotate (GNATprove, Terminating, os_ghost_task_is_linked_to_tail_recurs);

   function os_ghost_task_is_linked_to_tail (task_id : os_task_id_param_t) return Boolean is
      (os_ghost_task_is_linked_to_tail_recurs (task_id, OS_MIN_TASK_ID));

   ---------------------------------------
   -- os_ghost_task_list_is_well_formed --
   ---------------------------------------

   function os_ghost_task_list_is_well_formed return Boolean is
      --  The mbx fifo of all tasks need to be well formed.
      (if os_task_ready_list_head = OS_TASK_ID_NONE then
         (-- tail is empty like head
          os_task_ready_list_tail = OS_TASK_ID_NONE and
          (-- there is no ready task
          for all task_id in os_task_id_param_t'Range =>
             (-- no next for all task
              os_task_list_next (task_id) = OS_TASK_ID_NONE and
              -- no prev for all task
              os_task_list_prev (task_id) = OS_TASK_ID_NONE and
              -- and all tasks are not in ready state
              os_ghost_task_list_ready (task_id) = false)))
       else -- There is at least one task in the ready list
         (-- At least one task is ready.
          (for some task_id in os_task_id_param_t'Range =>
             (os_ghost_task_list_ready (task_id))) and then
          (for all task_id in os_task_id_param_t'Range =>
             (if os_ghost_task_list_ready (task_id) then
                -- This is a member of the ready task list
                (-- the ready task need to be connected to head
                 os_ghost_task_is_linked_to_head (task_id) and then
                 -- the ready task need to be connected to tail
                 os_ghost_task_is_linked_to_tail (task_id))
              else
                -- This task is not part of the ready list
                (os_ghost_task_list_ready (task_id) = false and
                 -- no next
                 os_task_list_next (task_id) = OS_TASK_ID_NONE and
                 -- no prev
                 os_task_list_prev (task_id) = OS_TASK_ID_NONE)))));

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
      task_id := os_task_current;

      tmp_mask := waiting_mask and os_mbx_get_mbx_permission (task_id);

      --  We remove the current task from the ready list.
      os_sched_remove_task_from_ready_list (task_id);

      if tmp_mask /= 0 then
         os_task_list_mbx_mask (task_id) := tmp_mask;

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
      task_id := os_task_current;

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
      task_id := os_task_current;

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
      prev_id : os_task_id_param_t := os_task_id_param_t'First;
   begin
      --  Init the console if any
      os_arch_cons_init;

      --  Init the MMU
      os_arch_space_init;

      --  Init the task list head to NONE
      os_task_ready_list_head := OS_TASK_ID_NONE;
      os_task_ready_list_tail := OS_TASK_ID_NONE;

      for task_iterator in os_task_id_param_t'Range loop
         --  Init the mbx for one task
         for mbx_iterator in os_mbx_index_t'Range loop
            os_mbx_clear_mbx_entry (task_iterator, mbx_iterator);
         end loop;
         os_task_list_mbx_fifo (task_iterator).head := os_mbx_index_t'First;
         os_task_list_mbx_fifo (task_iterator).count := os_mbx_count_t'First;

         --  Init the task entry for one task
         os_task_list_next (task_iterator) := OS_TASK_ID_NONE;
         os_task_list_prev (task_iterator) := OS_TASK_ID_NONE;

         os_task_list_mbx_mask (task_iterator) := 0;

         --  This task is not ready
         os_ghost_task_list_ready (task_iterator) := false;
      end loop;

      for task_iterator in os_task_id_param_t'Range loop
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
      Global => (In_Out => os_task_list_mbx_fifo),
      Pre  => (not os_mbx_is_empty (task_id)) and os_ghost_mbx_are_well_formed,
      Post => (os_task_list_mbx_fifo = os_task_list_mbx_fifo'Old'Update (task_id => os_task_list_mbx_fifo'Old (task_id)'Update (count => os_mbx_count_t'Pred (os_task_list_mbx_fifo'Old (task_id).count), head => os_mbx_index_t'Succ (os_task_list_mbx_fifo'Old (task_id).head), mbx_array => os_task_list_mbx_fifo'Old (task_id).mbx_array'Update (os_mbx_index_t'Pred (os_mbx_get_mbx_head (task_id)) => (sender_id => OS_TASK_ID_NONE, msg => 0)))))
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
      Global => (In_Out => os_task_list_mbx_fifo),
      Pre  => (not os_mbx_is_empty (task_id)) and os_ghost_mbx_are_well_formed,
      Post => (os_task_list_mbx_fifo = os_task_list_mbx_fifo'Old'Update (task_id => os_task_list_mbx_fifo'Old (task_id)'Update (count => os_mbx_count_t'Pred (os_task_list_mbx_fifo'Old (task_id).count), head => os_task_list_mbx_fifo'Old (task_id).head, mbx_array => os_task_list_mbx_fifo'Old (task_id).mbx_array'Update (os_task_list_mbx_fifo (task_id).head + os_task_list_mbx_fifo (task_id).count => (sender_id => OS_TASK_ID_NONE, msg => 0)))))
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
      Global => (In_Out => os_task_list_mbx_fifo),
      Pre => (not os_mbx_is_empty (task_id)) and
             os_ghost_mbx_are_well_formed and
             (index > 0) and
             (index < os_mbx_count_t'Pred (os_mbx_get_mbx_count (task_id))),
      Post => os_ghost_mbx_are_well_formed and
              os_task_list_mbx_fifo (task_id).count = os_task_list_mbx_fifo'Old (task_id).count and
              os_task_list_mbx_fifo (task_id).head = os_task_list_mbx_fifo'Old (task_id).head
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
      current   : constant os_task_id_param_t := os_task_current;
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
            pragma Loop_Invariant (os_task_list_mbx_fifo =
                                         os_task_list_mbx_fifo'Loop_Entry);

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
