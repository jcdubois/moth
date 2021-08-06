--
--  Copyright (c) 2020 Jean-Christophe Dubois All rights reserved.
--
--  This program is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; either version 2, or (at your option) any
--  later version.
--
--  This program is distributed in the hope that it will be useful, but WITHOUT
--  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
--  FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
--  for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  675 Mass Ave, Cambridge, MA 02139, USA.
--
--  @file moth-scheduler.adb
--  @author Jean-Christophe Dubois (jcd@tribudubois.net)
--  @brief Moth Scheduler subsystem
--

with Interfaces;   use Interfaces;
with Interfaces.C; use Interfaces.C;

with Ada.Containers;
use type Ada.Containers.Count_Type;

with os_arch;
with Moth.Config;

separate (Moth)
package body Scheduler with
   SPARK_Mode => on
is

   OS_INTERRUPT_TASK_ID : constant := 0;

   -----------------
   -- Private API --
   -----------------

   -----------------------
   -- Private variables --
   -----------------------

   -----------------------
   -- ready_task --
   -----------------------

   ready_task : array (os_task_id_param_t) of Boolean;

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
   --  This variable holds the ID of the first task in the ready list (the next
   --  one that will be elected).
   --  Note: Its value could be OS_TASK_ID_NONE if no task is ready.

   task_list_head : os_task_id_t;

   --------------
   -- mbx_mask --
   --------------

   mbx_mask : array (os_task_id_param_t) of os_mbx_mask_t;

   ------------------
   -- current_task --
   ------------------

   current_task : os_task_id_param_t;

   ----------------------
   --  Ghost functions --
   ----------------------

   -------------------
   -- task_is_ready --
   -------------------

   function task_is_ready (task_id : os_task_id_param_t) return Boolean
   is
     (ready_task (task_id));

   ---------------------------
   -- current_task_is_ready --
   ---------------------------

   function current_task_is_ready return Boolean
   is
     (task_is_ready (current_task));

   ------------------------------
   -- task_list_is_well_formed --
   ------------------------------

   function task_list_is_well_formed return Boolean
   is
     (if task_list_head = OS_TASK_ID_NONE then
       (for all id in os_task_id_param_t =>
          (ready_task (id) = False
           and next_task (id) = OS_TASK_ID_NONE
           and prev_task (id) = OS_TASK_ID_NONE))
      else
       (task_list_head /= OS_TASK_ID_NONE and then
        ready_task (task_list_head) = True and then
        prev_task (task_list_head) = OS_TASK_ID_NONE and then
        (for all id in os_task_id_param_t =>
           (if ready_task (id) = False then
              (next_task (id) = OS_TASK_ID_NONE
               and prev_task (id) = OS_TASK_ID_NONE)
            else
              (next_task (id) /= id 
               and prev_task (id) /= id
               and (if next_task (id) /= OS_TASK_ID_NONE then
                      (ready_task (next_task (id)) = True
                       and next_task (id) /= prev_task (id)
                       and Moth.Config.get_task_priority (id) >= 
                           Moth.Config.get_task_priority (next_task (id))))
               and (if prev_task (id) /= OS_TASK_ID_NONE then
                      (ready_task (prev_task (id)) = True
                       and next_task (id) /= prev_task (id)
                       and Moth.Config.get_task_priority (id) <= 
                           Moth.Config.get_task_priority (prev_task (id))))
                      )))));

   ----------------------------
   -- add_task_to_ready_list --
   ----------------------------

   procedure add_task_to_ready_list (task_id : os_task_id_param_t)
   with
      Refined_Post => ready_task = (ready_task'Old with delta
                                                            task_id => True)
                      and then task_list_is_well_formed
   is
      index_id : os_task_id_t := task_list_head;
   begin

      if (not ready_task (task_id)) then

         if index_id = OS_TASK_ID_NONE then

            ready_task (task_id) := True;

            --  task_id is now the only element of the ready_list.
            task_list_head := task_id;

         else

            while index_id /= OS_TASK_ID_NONE loop

               if Moth.Config.get_task_priority (task_id) >
                 Moth.Config.get_task_priority (index_id)
               then
                  --  task_id is higher priority so it needs to be inserted
                  --  before index_id.
                  declare
                     prev_id : constant os_task_id_t := prev_task (index_id);
                  begin

                     prev_task (index_id) := task_id;
                     next_task (task_id)  := index_id;
                     ready_task (task_id) := True;

                     if prev_id = OS_TASK_ID_NONE then
                        task_list_head := task_id;
                     else
                        next_task (prev_id) := task_id;
                        prev_task (task_id) := prev_id;
                     end if;

                  end;

                  exit;
               elsif next_task (index_id) = OS_TASK_ID_NONE then
                  --  we are at the last element of the ready list.

                  --  We need to insert task_id at the end of the ready list
                  next_task (index_id) := task_id;
                  prev_task (task_id)  := index_id;

                  --  We don't need to update next_task as it is already set to
                  --  OS_TASK_ID_NONE
                  ready_task (task_id) := True;

                  exit;
               end if;

               index_id := next_task (index_id);
            end loop;

         end if;
      end if;

   end add_task_to_ready_list;

   ---------------------------------
   -- remove_task_from_ready_list --
   ---------------------------------

   procedure remove_task_from_ready_list (task_id : os_task_id_param_t)
   with
      Pre  => task_is_ready (task_id)
              and then task_list_is_well_formed,
      Post => ready_task = (ready_task'Old with delta task_id => False)
              and then task_list_is_well_formed
   is
      next_id  : constant os_task_id_t := next_task (task_id);
      prev_id  : constant os_task_id_t := prev_task (task_id);
   begin

      --  Disconnect task_id from the ready list
      next_task (task_id)  := OS_TASK_ID_NONE;
      prev_task (task_id)  := OS_TASK_ID_NONE;
      ready_task (task_id) := False;

      if task_id = task_list_head then

         --  Set the new list head (the next from the removed task)
         --  Note:
         task_list_head := next_id;

      end if;

      if prev_id /= OS_TASK_ID_NONE then

         --  link next from prev task to our next
         next_task (prev_id) := next_id;

      end if;

      if next_id /= OS_TASK_ID_NONE then

         --  link prev from next task to our prev
         prev_task (next_id) := prev_id;

      end if;
   end remove_task_from_ready_list;

   --------------
   -- schedule --
   --------------

   procedure schedule (task_id : out os_task_id_param_t)
   with
      Pre  => task_list_is_well_formed,
      Post => task_list_head = task_id
              and then task_is_ready (task_id)
              and then task_list_is_well_formed
   is
   begin
      --  Check interrupt status
      if (os_arch.interrupt_is_pending = 1) then
         --  Put interrupt task in ready list if int is set.
         add_task_to_ready_list (OS_INTERRUPT_TASK_ID);
      end if;

      while task_list_head = OS_TASK_ID_NONE loop

         --  No task is elected:
         --  Put processor in idle mode and wait for interrupt.
         os_arch.idle;

         --  Check interrupt status
         if (os_arch.interrupt_is_pending = 1) then
            --  Put interrupt task in ready list if int is set.
            add_task_to_ready_list (OS_INTERRUPT_TASK_ID);
         end if;
      end loop;

      task_id := task_list_head;

      --  Select the elected task as current task.
      current_task := task_id;

      --  Return the ID of the elected task to allow context switch at low
      --  (arch) level
   end schedule;

   ----------------
   -- Public API --
   ----------------

   -------------------------
   -- get_current_task_id --
   -------------------------

   function get_current_task_id return os_task_id_param_t
   is
     (current_task);

   ------------------
   -- get_mbx_mask --
   ------------------

   function get_mbx_mask (task_id : os_task_id_param_t) return os_mbx_mask_t
   is
     (mbx_mask (task_id));

   ----------
   -- wait --
   ----------

   procedure wait (task_id      : out os_task_id_param_t;
                   waiting_mask : in os_mbx_mask_t)
   is
      tmp_mask : os_mbx_mask_t;
   begin
      task_id := current_task;

      -- restrict the waiting mask to the permited tasks only.
      tmp_mask := waiting_mask and Moth.Config.get_mbx_permission (task_id);

      --  We remove the current task from the ready list.
      remove_task_from_ready_list (task_id);

      if tmp_mask /= 0 then
         mbx_mask (task_id) := tmp_mask;

         -- check to see if one of the waited event is already here.
         tmp_mask :=
           tmp_mask and Moth.Mailbox.os_mbx_get_posted_mask (task_id);

         if tmp_mask /= 0 then
            --  If waited event is already here, put the task back in the ready
            --  list (after tasks of same priority).
            add_task_to_ready_list (task_id);
         end if;
      elsif task_id /= OS_INTERRUPT_TASK_ID then
         --  This is an error/illegal case. There is nothing to wait for, so
         --  put the task back in the ready list.
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
      task_id := current_task;

      --  We remove the current task from the ready list.
      remove_task_from_ready_list (task_id);

      --  We insert it back after the other tasks with same priority.
      add_task_to_ready_list (task_id);

      --  Let's elect the new running task.
      schedule (task_id);
   end yield;

   ---------------
   -- task_exit --
   ---------------

   procedure task_exit (task_id : out os_task_id_param_t)
   is
   begin
      task_id := current_task;

      --  Remove the current task from the ready list.
      remove_task_from_ready_list (task_id);

      --  Let's elect the new running task.
      schedule (task_id);
   end task_exit;

   ----------
   -- init --
   ----------

   procedure init (task_id : out os_task_id_param_t)
   is
      prev_id : os_task_id_param_t := os_task_id_param_t'First;
   begin

      --  Init the MMU
      os_arch.space_init;

      --  Init the task list head to NONE
      task_list_head := OS_TASK_ID_NONE;

      --  Init the task entry for one task
      next_task := (others => OS_TASK_ID_NONE);
      prev_task := (others => OS_TASK_ID_NONE);

      --  All Mbx mask for tasks are 0
      mbx_mask := (others => 0);

      --  No task is in the ready list yet.
      ready_task := (others => False);

      for task_iterator in os_task_id_param_t loop

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

      --  Switch to this task context
      os_arch.space_switch (prev_id, task_id);
   end init;

end Scheduler;
