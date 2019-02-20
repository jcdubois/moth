--
--  Copyright (c) 2019 Jean-Christophe Dubois
--  All rights reserved.
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; either version 2, or (at your option)
--  any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; if not, write to the Free Software
--  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
--
--  @file moth-scheduler.adb
--  @author Jean-Christophe Dubois (jcd@tribudubois.net)
--  @brief Moth Scheduler subsystem
--

with Interfaces;   use Interfaces;
with Interfaces.C; use Interfaces.C;

with os_arch;
with Moth.Current;
with Moth.Mailbox;

package body Moth.Scheduler with
   SPARK_mode => on,
   Refined_State => (State => (task_list_head,
                               task_list_tail,
                               os_ghost_task_list_ready,
                               mbx_mask,
                               next_task,
                               prev_task))
is

   OS_INTERRUPT_TASK_ID : constant := 0;

   -----------------
   -- Private API --
   -----------------

   -------------------
   -- Private types --
   -------------------

   -- This specific type is used to make sure we exit from recursive
   -- loop in functions used for proof (Ghost)
   subtype os_recurs_cnt_t is types.int8_t
                         range OS_TASK_ID_MIN .. OS_MAX_TASK_CNT;

   -----------------------
   -- Private variables --
   -----------------------

   -----------------------
   -- next_task --
   -----------------------

   next_task : array (os_task_id_param_t) of os_task_id_t;

   -----------------------
   -- prev_task --
   -----------------------

   prev_task : array (os_task_id_param_t) of os_task_id_t;

   -----------------------------
   -- task_list_head --
   -----------------------------
   --  This variable holds the ID of the first task in the ready list (the
   --  next one that will be elected).
   --  Note: Its value could be OS_TASK_ID_NONE if no task is ready.

   task_list_head : os_task_id_t;

   -----------------------------
   -- task_list_tail --
   -----------------------------

   task_list_tail : os_task_id_t;

   --------------
   -- mbx_mask --
   --------------

   mbx_mask : array (os_task_id_param_t) of os_mbx_mask_t;

   -------------------------------------
   -- Ghost variable for task's state --
   -------------------------------------

   os_ghost_task_list_ready : array (os_task_id_param_t) of Boolean with Ghost;

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
            next_task (next_id) = task_id and
               (for some next_id2 in os_task_id_param_t'Range =>
                  next_id2 /= next_id and
                  os_ghost_task_list_ready (next_id2) and
                  next_task (next_id2) = task_id)))
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
            prev_task (prev_id) = task_id and
               (for some prev_id2 in os_task_id_param_t'Range =>
                  prev_id2 /= prev_id and
                  os_ghost_task_list_ready (prev_id2) and
                  prev_task (prev_id2) = task_id)))
   with
      Ghost => true;

   ----------------------------
   -- os_ghost_task_is_ready --
   ----------------------------

   function os_ghost_task_is_ready (task_id : os_task_id_param_t) return Boolean
   is (os_ghost_task_list_ready (task_id));

   ------------------------------------
   -- current_task_is_ready --
   ------------------------------------

   function current_task_is_ready return Boolean
   is (os_ghost_task_is_ready (Moth.Current.get_current_task_id));

   -------------------------------------
   -- os_ghost_task_is_linked_to_head --
   -------------------------------------

   function os_ghost_task_is_linked_to_head_recurs (task_id : os_task_id_param_t; recursive_count : os_recurs_cnt_t) return Boolean is
      (recursive_count < OS_MAX_TASK_CNT and then
       os_ghost_task_list_ready (task_id) and then
       os_ghost_not_prev_twice (task_id) and then
          (if prev_task (task_id) = OS_TASK_ID_NONE then
              (task_list_head = task_id)
           else
              (next_task (task_id) /= task_id and
               prev_task (task_id) /= task_id and
               prev_task (task_id) /= next_task (task_id) and
               next_task (prev_task (task_id)) = task_id and
               Moth.Config.get_task_priority (task_id) <= Moth.Config.get_task_priority (prev_task (task_id)) and
               os_ghost_task_is_linked_to_head_recurs (prev_task (task_id), recursive_count + 1))))
   with
      Ghost => true;
   pragma Annotate (GNATprove, Terminating, os_ghost_task_is_linked_to_head_recurs);

   function os_ghost_task_is_linked_to_head (task_id : os_task_id_param_t) return Boolean is
      (os_ghost_task_is_linked_to_head_recurs (task_id, OS_TASK_ID_MIN))
   with
      Ghost => true;

   --------------------------------------
   -- os_ghost_task_is_linked_to_tail --
   --------------------------------------

   function os_ghost_task_is_linked_to_tail_recurs (task_id : os_task_id_param_t; recursive_count : os_recurs_cnt_t) return Boolean is
      (recursive_count < OS_MAX_TASK_CNT and then
       os_ghost_task_list_ready (task_id) and then
       os_ghost_not_next_twice (task_id) and then
          (if next_task (task_id) = OS_TASK_ID_NONE then
              (task_list_tail = task_id)
           else
              (next_task (task_id) /= task_id and
               prev_task (task_id) /= task_id and
               prev_task (task_id) /= next_task (task_id) and
               prev_task (next_task (task_id)) = task_id and
               Moth.Config.get_task_priority (task_id) >= Moth.Config.get_task_priority (next_task (task_id)) and
               os_ghost_task_is_linked_to_tail_recurs (next_task (task_id), recursive_count + 1))))
   with
      Ghost => true;
   pragma Annotate (GNATprove, Terminating, os_ghost_task_is_linked_to_tail_recurs);

   function os_ghost_task_is_linked_to_tail (task_id : os_task_id_param_t) return Boolean is
      (os_ghost_task_is_linked_to_tail_recurs (task_id, OS_TASK_ID_MIN))
   with
      Ghost => true;

   ---------------------------------------
   -- task_list_is_well_formed --
   ---------------------------------------

   function task_list_is_well_formed return Boolean is
      (if task_list_head = OS_TASK_ID_NONE then
         (-- tail is empty like head
          task_list_tail = OS_TASK_ID_NONE and
          (-- there is no ready task
          for all task_id in os_task_id_param_t'Range =>
             (-- no next for all task
              next_task (task_id) = OS_TASK_ID_NONE and
              -- no prev for all task
              prev_task (task_id) = OS_TASK_ID_NONE and
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
                 next_task (task_id) = OS_TASK_ID_NONE and
                 -- no prev
                 prev_task (task_id) = OS_TASK_ID_NONE)))));

   ----------------------------------
   -- Private functions/procedures --
   ----------------------------------

   ----------------------------
   -- add_task_to_ready_list --
   ----------------------------

   procedure add_task_to_ready_list (task_id : os_task_id_param_t)
   with
      Refined_Post => os_ghost_task_list_ready =
                os_ghost_task_list_ready'Old'Update (task_id => true) and then
                task_list_is_well_formed
   is
      index_id : os_task_id_t := task_list_head;
   begin

      pragma assert (os_ghost_task_list_is_well_formed);
      pragma assert (task_list_is_well_formed);

      if index_id = OS_TASK_ID_NONE then
         -- list head is empty, so the added task needs not to be ready.
         pragma assert (not os_ghost_task_list_ready (task_id));
         pragma assert (task_list_tail = OS_TASK_ID_NONE);

         --  No task in the ready list. Add this task at list head
         next_task (task_id) := OS_TASK_ID_NONE;
         prev_task (task_id) := OS_TASK_ID_NONE;
         task_list_head := task_id;
         task_list_tail := task_id;
         os_ghost_task_list_ready (task_id) := true;

         pragma assert (task_list_is_well_formed);
      else
         -- index_id is list head, so its prec needs to be empty
         pragma assert (prev_task (index_id) = OS_TASK_ID_NONE);

         while index_id /= OS_TASK_ID_NONE loop
            pragma Loop_Invariant (task_list_is_well_formed);
            pragma Loop_Invariant (os_ghost_task_list_ready = os_ghost_task_list_ready'Loop_Entry);
            -- At any step in the loop index_id needs to be ready
            pragma assert (index_id /= OS_TASK_ID_NONE);
            pragma assert (os_ghost_task_list_ready (index_id));
            if index_id = task_id then
               pragma assert (os_ghost_task_list_ready (task_id));
               --  Already in the ready list, nothing to do
               exit;
            elsif Moth.Config.get_task_priority (task_id) >
                  Moth.Config.get_task_priority (index_id) then
               -- task_id is higher priority so it needs to be inserted before
               -- index_id
               declare
                  prev_id : constant os_task_id_t :=
                                            prev_task (index_id);
               begin
                  pragma assert (task_list_is_well_formed);

                  prev_task (index_id) := task_id;
                  prev_task (task_id) := prev_id;
                  next_task (task_id) := index_id;
                  os_ghost_task_list_ready (task_id) := true;
                  pragma assert (Moth.Config.get_task_priority (task_id) > Moth.Config.get_task_priority (index_id));

                  if prev_id = OS_TASK_ID_NONE then
                     pragma assert (index_id = task_list_head);
                     task_list_head := task_id;
                  else
                     pragma assert (index_id /= task_list_head);
                     pragma assert (Moth.Config.get_task_priority (prev_id) >= Moth.Config.get_task_priority (index_id));
                     pragma assert (Moth.Config.get_task_priority (task_id) >= Moth.Config.get_task_priority (index_id));
                     pragma assert (Moth.Config.get_task_priority (prev_id) >= Moth.Config.get_task_priority (task_id));
                     next_task (prev_id) := task_id;
                  end if;

                  pragma assert (task_list_is_well_formed);
                  exit;
               end;
            elsif next_task (index_id) = OS_TASK_ID_NONE then
               pragma assert (task_list_is_well_formed);
               pragma assert (task_list_tail = index_id);
               pragma assert (Moth.Config.get_task_priority (task_id) <= Moth.Config.get_task_priority (index_id));

               next_task (index_id) := task_id;
               prev_task (task_id)  := index_id;
               next_task (task_id)  := OS_TASK_ID_NONE;
               task_list_tail      := task_id;
               os_ghost_task_list_ready (task_id) := true;

               pragma assert (task_list_is_well_formed);
               exit;
            else
               pragma assert (task_list_is_well_formed);
               index_id := next_task (index_id);
            end if;
         end loop;
      end if;

      -- os_ghost_task_list_ready (task_id) := true;

      pragma assert (task_list_is_well_formed);
   end add_task_to_ready_list;

   ---------------------------------
   -- remove_task_from_ready_list --
   ---------------------------------

   procedure remove_task_from_ready_list
     (task_id : os_task_id_param_t)
   with
      Global => (In_Out => (task_list_head,
                            task_list_tail,
                            prev_task,
                            next_task,
                            os_ghost_task_list_ready),
                 Input  => (Moth.Config.State)),
      Pre =>  (os_ghost_task_list_ready (task_id) and then
               task_list_is_well_formed),
      Post => os_ghost_task_list_ready =
                     os_ghost_task_list_ready'Old'Update (task_id => false) and then
              task_list_is_well_formed
   is
      next_id : constant os_task_id_t := next_task (task_id);
      prev_id : constant os_task_id_t := prev_task (task_id);
   begin
      -- As there is a ready task, the list head cannot be empty
      -- pragma assert (task_list_head /= OS_TASK_ID_NONE);
      -- pragma assert (task_list_tail /= OS_TASK_ID_NONE);
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
      -- pragma assert (task_list_is_well_formed);
      -- pragma assert (os_ghost_task_list_ready (task_list_head));
      -- pragma assert (task_list_is_well_formed);
      -- pragma assert (os_ghost_task_list_ready (task_list_head));
      -- pragma assert (os_ghost_task_list_ready (task_list_tail));
      -- pragma assert (os_ghost_task_is_linked_to_tail (task_list_head));
      -- pragma assert (os_ghost_task_is_linked_to_head (task_list_tail));
      -- pragma assert (task_list_is_well_formed);

      next_task (task_id) := OS_TASK_ID_NONE;
      prev_task (task_id) := OS_TASK_ID_NONE;

      os_ghost_task_list_ready (task_id) := false;

      if task_id = task_list_tail then
         -- As task_id is the list tail, its next needs to be empty.
         pragma assert (next_id = OS_TASK_ID_NONE);

         -- Set the new list tail (the prev from the removed task)
         -- Note: prev could be set to OS_TASK_ID_NONE
         task_list_tail := prev_id;

         if prev_id /= OS_TASK_ID_NONE then
            -- prev is a valid task and needs to be ready
            pragma assert (os_ghost_task_list_ready (prev_id));

            -- The new list tail [prev] has no next
            next_task (prev_id) := OS_TASK_ID_NONE;

            -- pragma assert (os_ghost_task_is_linked_to_tail (prev_id));
         -- else
            -- pragma assert (for all id in os_task_id_param_t'Range =>
                           -- next_task (id) = OS_TASK_ID_NONE);
            -- pragma assert (for all id in os_task_id_param_t'Range =>
                           -- prev_task (id) = OS_TASK_ID_NONE);
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
         pragma assert (prev_task (next_id) = task_id);

         -- pragma assert (os_ghost_task_is_linked_to_tail (next_id));
         --  link prev from next task to our prev
         prev_task (next_id) := prev_id;

         -- pragma assert (os_ghost_task_is_linked_to_tail (next_id));
      end if;

      if task_id = task_list_head then
         -- As task_id is the list head, its prev needs to be empty.
         pragma assert (prev_id = OS_TASK_ID_NONE);

         -- Set the new list head (the next from the removed task)
         -- Note: next could be set to OS_TASK_ID_NONE
         task_list_head := next_id;

         if next_id /= OS_TASK_ID_NONE then
            -- next is a valid task and needs to be ready
            pragma assert (os_ghost_task_list_ready (next_id));
            pragma assert (task_list_tail /= OS_TASK_ID_NONE);

            -- The new list head [next] has no prev
            prev_task (next_id) := OS_TASK_ID_NONE;

            pragma assert (os_ghost_task_is_linked_to_tail (next_id));
            pragma assert (os_ghost_task_is_linked_to_head (next_id));
            pragma assert (os_ghost_task_is_linked_to_tail (task_list_head));
            pragma assert (os_ghost_task_is_linked_to_head (task_list_tail));
            pragma assert (task_list_is_well_formed);
         else
            -- The list is now empty. We can check all tasks are not ready
            -- and that they are not part of any ready list.
            pragma assert (task_list_head = OS_TASK_ID_NONE);
            pragma assert (task_list_tail = OS_TASK_ID_NONE);
            pragma assert (for all id in os_task_id_param_t'Range =>
                           next_task (id) = OS_TASK_ID_NONE);
            pragma assert (for all id in os_task_id_param_t'Range =>
                           prev_task (id) = OS_TASK_ID_NONE);
            pragma assert (for all id in os_task_id_param_t'Range =>
                           os_ghost_task_list_ready (id) = false);
            pragma assert (task_list_is_well_formed);
         end if;

         pragma assert (task_list_is_well_formed);
      else
         --  The list is not empty and the task is not at the list head.

         --  task_id need to have a valid prev as it is not at list head
         pragma assert (prev_id /= OS_TASK_ID_NONE);

         --  prev is valid and it needs to be ready
         pragma assert (os_ghost_task_list_ready (prev_id));

         --  link next from prev task to our next
         next_task (prev_id) := next_id;

         -- pragma assert (os_ghost_task_is_linked_to_tail (next_id));
         pragma assert (os_ghost_task_is_linked_to_tail (prev_id));
         pragma assert (os_ghost_task_is_linked_to_head (prev_id));
         pragma assert (task_list_is_well_formed);
      end if;

      pragma assert (task_list_is_well_formed);
   end remove_task_from_ready_list;

   --------------
   -- schedule --
   --------------

   procedure schedule (task_id : out os_task_id_param_t)
   with
   Global => (In_Out => (task_list_head,
                         task_list_tail,
                         next_task,
                         prev_task,
                         os_ghost_task_list_ready),
              Output => Moth.Current.State,
              Input  => (Moth.Config.State,
                         mbx_mask)),
   Pre => task_list_is_well_formed,
   Post => os_ghost_task_list_ready (task_id) and then
           task_list_head = task_id and then
           task_list_is_well_formed
   is
   begin
      --  Check interrupt status
      if os_arch.interrupt_is_pending = 1 then
         --  Put interrupt task in ready list if int is set.
         add_task_to_ready_list (OS_INTERRUPT_TASK_ID);
      end if;

      while task_list_head = OS_TASK_ID_NONE loop

         pragma Loop_Invariant (task_list_is_well_formed);

         --  No task is elected:
         --  Put processor in idle mode and wait for interrupt.
         os_arch.idle;

         --  Check interrupt status
         if os_arch.interrupt_is_pending = 1 then
            --  Put interrupt task in ready list if int is set.
            add_task_to_ready_list (OS_INTERRUPT_TASK_ID);
         end if;
      end loop;

      task_id := task_list_head;

      --  Select the elected task as current task.
      Moth.Current.set_current_task_id (task_id);

      --  Return the ID of the elected task to allow context switch at low
      --  (arch) level
   end schedule;

   ----------------
   -- Public API --
   ----------------

   ------------------
   -- get_mbx_mask --
   ------------------

   function get_mbx_mask (task_id : os_task_id_param_t) return os_mbx_mask_t is
      (mbx_mask (task_id));

   ----------
   -- wait --
   ----------

   procedure wait
     (task_id      : out os_task_id_param_t;
      waiting_mask : in  os_mbx_mask_t)
   is
      tmp_mask : os_mbx_mask_t;
   begin
      task_id := Moth.Current.get_current_task_id;

      tmp_mask := waiting_mask and Moth.Config.get_mbx_permission (task_id);

      --  We remove the current task from the ready list.
      remove_task_from_ready_list (task_id);

      if tmp_mask /= 0 then
         mbx_mask (task_id) := tmp_mask;

         pragma assert (os_ghost_mbx_are_well_formed);
         tmp_mask := tmp_mask and Moth.Mailbox.os_mbx_get_posted_mask (task_id);

         if tmp_mask /= 0 then
            --  If waited event is already here, put the task back in the
            --  ready list (after tasks of same priority).
            add_task_to_ready_list (task_id);
         end if;
      elsif task_id /= OS_INTERRUPT_TASK_ID then
         --  This is an error/illegal case. There is nothing to wait for,
         --  so put the task back in the ready list.
         add_task_to_ready_list (task_id);
      end if;

      --  Let's elect the new running task.
      schedule (task_id);
   end wait;

   -----------
   -- yield --
   -----------

   procedure yield (task_id : out os_task_id_param_t)
   is
   begin
      task_id := Moth.Current.get_current_task_id;

      --  We remove the current task from the ready list.
      remove_task_from_ready_list (task_id);

      --  We insert it back after the other tasks with same priority.
      add_task_to_ready_list (task_id);

      --  We determine the new task.
      schedule (task_id);
   end yield;

   ---------
   -- fin --
   ---------

   procedure task_exit (task_id : out os_task_id_param_t)
   is
   begin
      task_id := Moth.Current.get_current_task_id;

      --  Remove the current task from the ready list.
      remove_task_from_ready_list (task_id);

      --  We determine the new task.
      schedule (task_id);
   end task_exit;

   ----------
   -- init --
   ----------

   procedure Init_State
   with
      Refined_Global => (Output => (task_list_head,
                                    task_list_tail,
                                    os_ghost_task_list_ready,
                                    mbx_mask,
                                    next_task,
                                    prev_task)),
      Refined_Post => (task_list_head = OS_TASK_ID_NONE and
                       task_list_tail = OS_TASK_ID_NONE and
                       (for all task_id in os_task_id_param_t'Range =>
                          (next_task (task_id) = OS_TASK_ID_NONE and
                           prev_task (task_id) = OS_TASK_ID_NONE and
                           mbx_mask (task_id) = 0 and
                           os_ghost_task_list_ready (task_id) = False)))
   is
   begin
      --  Init the task list head to NONE
      task_list_head := OS_TASK_ID_NONE;
      task_list_tail := OS_TASK_ID_NONE;

      --  Init the task entry for one task
      next_task := (others => OS_TASK_ID_NONE);
      prev_task := (others => OS_TASK_ID_NONE);

      mbx_mask := (others => 0);

      --  This task list is not ready
      os_ghost_task_list_ready := (others => False);
   end;

   procedure init (task_id : out os_task_id_param_t)
   is
      prev_id : os_task_id_param_t := os_task_id_param_t'First;
   begin

      --  Init the MMU
      os_arch.space_init;

      -- Initialize our state variables
      Init_State;

      for task_iterator in os_task_id_param_t'Range loop
         --  Initialise the memory space for one task
         os_arch.space_switch (prev_id, task_iterator);

         --  create the run context (stak, ...) for this task
         os_arch.context_create (task_iterator);

         --  Add the task to the ready list
         add_task_to_ready_list (task_iterator);

         prev_id := task_iterator;
      end loop;

      --  Select the task to run
      schedule (task_id);

      --  Set the selected task as the current one
      os_arch.context_set (task_id);

      --  Switch to this task context
      os_arch.space_switch (prev_id, task_id);
   end init;

end Moth.Scheduler;
