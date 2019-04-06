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

with Ada.Containers;
use type Ada.Containers.Count_Type;

with os_arch;
with Moth.Config;

separate (Moth) package body Scheduler
with
   SPARK_mode => on
is

   OS_INTERRUPT_TASK_ID : constant := 0;

   -----------------
   -- Private API --
   -----------------

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

   --------------
   -- mbx_mask --
   --------------

   mbx_mask : array (os_task_id_param_t) of os_mbx_mask_t;

   ------------------
   -- current_task --
   ------------------

   current_task : os_task_id_param_t;

   package body M is

      function idle_lt (Left, Right : os_task_id_param_t) return Boolean is
         (Left < Right);

      function os_ghost_task_list_is_well_formed return Boolean is
         ((Length (Model.Idle) <= OS_MAX_TASK_CNT) and then
          (Length (Model.Ready) <= OS_MAX_TASK_CNT) and then
          -- the sum of length of both list needs to be OS_MAW_TASK_CNT
          (Length (Model.Idle) + Length (Model.Ready) = OS_MAX_TASK_CNT) and then
          -- A task is either in one list or in the other.
          (for all task_id in os_task_id_param_t =>
              ((Contains (Model.Idle, task_id) and then
                not Contains (Model.Ready, task_id)) or else
               (Contains (Model.Ready, task_id) and then
                not Contains (Model.Idle, task_id) and then
                -- A task should only be once in the ready list
                Find (Model.Ready, task_id) =
                     Reverse_Find (Model.Ready, task_id)))) and then
          -- If the ready list is not empty there is a task list head
          (if Is_Empty (Model.Ready) then
              task_list_head = OS_TASK_ID_NONE
           else
              (task_list_head /= OS_TASK_ID_NONE and then
               Contains (Model.Ready, task_list_head) and then
               (for all task_id of Model.Ready =>
                   (Moth.Config.get_task_priority (task_list_head) >=
                      Moth.Config.get_task_priority (task_id))))) and then
          (for all task_id of Model.Ready =>
              (if task_id /= Last_Element (Model.Ready) then
                  (next_task (task_id) =
                                   Element (Model.Ready,
                                            Next (Model.Ready,
                                                  Find (Model.Ready,
                                                        task_id))) and then
                   Moth.Config.get_task_priority (next_task (task_id)) <=
                      Moth.Config.get_task_priority (task_id)))) and then
          -- All tasks part of the idle list have no next and no prev
          (for all task_id of Model.Idle =>
              (next_task (task_id) = OS_TASK_ID_NONE and then
               prev_task (task_id) = OS_TASK_ID_NONE)) and then
          -- tasks are ordered by priority in the ready list
          (for all task_id of Model.Ready =>
              (if task_id = First_Element (Model.Ready) then
                  (prev_task (task_id) = OS_TASK_ID_NONE and then
                   task_id = task_list_head and then
                   (if Length (Model.Ready) = 1 then
                       next_task (task_id) = OS_TASK_ID_NONE
                    else
                       (next_task (task_id) /= OS_TASK_ID_NONE and then
                        next_task (task_id) =
                                   Element (Model.Ready,
                                            Next (Model.Ready,
                                                  Find (Model.Ready,
                                                        task_id))) and then
                        next_task (task_id) /= task_id and then
                        next_task (task_id) /= task_list_head and then
                        Moth.Config.get_task_priority (next_task (task_id)) <=
                               Moth.Config.get_task_priority (task_id))))
               elsif task_id = Last_Element (Model.Ready) then
                  (next_task (task_id) = OS_TASK_ID_NONE and then
                   prev_task (task_id) /= OS_TASK_ID_NONE and then
                   prev_task (task_id) =
                              Element (Model.Ready,
                                       Previous (Model.Ready,
                                                 Find (Model.Ready,
                                                       task_id))) and then
                   prev_task (task_id) /= task_id and then
                   Moth.Config.get_task_priority (prev_task (task_id)) >=
                      Moth.Config.get_task_priority (task_id))
               else
                  (next_task (task_id) /= OS_TASK_ID_NONE and then
                   next_task (task_id) =
                              Element (Model.Ready,
                                       Next (Model.Ready,
                                             Find (Model.Ready,
                                                   task_id))) and then
                   prev_task (task_id) /= OS_TASK_ID_NONE and then
                   prev_task (task_id) =
                              Element (Model.Ready,
                                       Previous (Model.Ready,
                                                 Find (Model.Ready,
                                                       task_id))) and then
                   next_task (task_id) /= prev_task (task_id) and then
                   next_task (task_id) /= task_list_head and then
                   next_task (task_id) /= task_id and then
                   prev_task (task_id) /= task_id and then
                   prev_task (task_id) /= Last_Element (Model.Ready) and then
                   Moth.Config.get_task_priority (prev_task (task_id)) >=
                      Moth.Config.get_task_priority (task_id) and then
                   Moth.Config.get_task_priority (next_task (task_id)) <=
                      Moth.Config.get_task_priority (task_id)))));
               
      procedure init is
      begin

         Clear (Model.Ready);

         Clear (Model.Idle);

         for task_id in os_task_id_param_t loop
            Insert (Model.Idle, task_id);
            -- pragma Loop_Invariant (Integer (Length (Model.Idle))
                                            -- = Natural (task_id) + 1);
            -- pragma Loop_Invariant (for all id2 in OS_TASK_ID_MIN .. (task_id - 1)
                                      -- => Contains (Model.Idle, id2));
         end loop;

      end init;

   begin

      init;

   end M;

   ----------------------
   --  Ghost functions --
   ----------------------

   -------------------
   -- task_is_ready --
   -------------------

   function task_is_ready (task_id : os_task_id_param_t) return Boolean
   is (Contains (M.Model.Ready, task_id) and
       not Contains (M.Model.Idle, task_id));

   ---------------------------
   -- current_task_is_ready --
   ---------------------------

   function current_task_is_ready return Boolean
   is (task_is_ready (current_task));

   ------------------------------
   -- task_list_is_well_formed --
   ------------------------------

   function task_list_is_well_formed return Boolean is
      (M.os_ghost_task_list_is_well_formed);

   ----------------------------
   -- add_task_to_ready_list --
   ----------------------------

   procedure add_task_to_ready_list (task_id : os_task_id_param_t)
   is
      index_id : os_task_id_t := task_list_head;
   begin

      if index_id = OS_TASK_ID_NONE then
         --  No task in the ready list. Add this task at list head

         Delete (Model.Idle, task_id);
         Prepend (Model.Ready, task_id);

         task_list_head := task_id;

         -- task_id is now the only element of the ready_list
         -- next_task and prev_task are already set to OS_TAKS_ID_NONE

      else
         pragma assert (Contains (Model.Ready, index_id));
         while index_id /= OS_TASK_ID_NONE loop
            pragma Loop_Invariant (task_list_is_well_formed);
            pragma Loop_Invariant (Model = Model'Loop_Entry);
            pragma Loop_Invariant (next_task = next_task'Loop_Entry);
            pragma Loop_Invariant (Contains (Model.Ready, index_id));
            -- pragma assert (Contains (Model.Ready, index_id));
            -- At any step in the loop index_id needs to be ready
            if task_id = index_id then

               pragma assert (Contains (Model.Ready, task_id));

               exit;
            elsif Moth.Config.get_task_priority (task_id) >
                  Moth.Config.get_task_priority (index_id) then
               -- task_id is higher priority so it needs to be inserted before
               -- index_id
               declare
                  prev_id : constant os_task_id_t :=
                                            prev_task (index_id);
               begin

                  pragma assert (Contains (Model.Idle, task_id));

                  Delete (Model.Idle, task_id);
                  Insert (Model.Ready, Find (Model.Ready, index_id), task_id);

                  prev_task (index_id) := task_id;
                  next_task (task_id) := index_id;

                  if prev_id = OS_TASK_ID_NONE then
                     task_list_head := task_id;
                  else
                     next_task (prev_id) := task_id;
                     prev_task (task_id) := prev_id;
                  end if;

                  exit;
               end;
            elsif next_task (index_id) = OS_TASK_ID_NONE then
               -- we are at the last element of the ready list

               pragma assert (Contains (Model.Idle, task_id));

               Delete (Model.Idle, task_id);
               Append (Model.Ready, task_id);

               next_task (index_id) := task_id;
               prev_task (task_id)  := index_id;

               -- don't need to update next_task as it is already set to
               -- OS_TASK_ID_NONE

               exit;
            else
               index_id := next_task (index_id);
            end if;
         end loop;
      end if;

   end add_task_to_ready_list;

   ---------------------------------
   -- remove_task_from_ready_list --
   ---------------------------------

   procedure remove_task_from_ready_list
     (task_id : os_task_id_param_t)
   with
      Pre  => task_is_ready (task_id) and then
              M.os_ghost_task_list_is_well_formed,
      Post => Contains (M.Model.Idle, task_id) and then
              M.os_ghost_task_list_is_well_formed
   is
      next_id : constant os_task_id_t := next_task (task_id);
      prev_id : constant os_task_id_t := prev_task (task_id);
      position : M.ready_list_t.Cursor := Find (Model.Ready, task_id) with Ghost;
   begin

      pragma assert (First_Element (Model.Ready) = task_list_head);
      pragma assert (Element (Model.Ready, position) = task_id);

      next_task (task_id) := OS_TASK_ID_NONE;
      prev_task (task_id) := OS_TASK_ID_NONE;

      pragma assert (for all task_id in os_task_id_param_t =>
              ((Contains (Model.Idle, task_id) and then
                not Contains (Model.Ready, task_id)) or else
               (Contains (Model.Ready, task_id) and then
                not Contains (Model.Idle, task_id) and then
                -- A task should only be once in the ready list
                Find (Model.Ready, task_id) =
                     Reverse_Find (Model.Ready, task_id))));

      pragma assert (if Is_Empty (Model.Ready) then
                  task_list_head = OS_TASK_ID_NONE
               else
                  (task_list_head /= OS_TASK_ID_NONE and then
                   Contains (Model.Ready, task_list_head) and then
                   (for all task_id of Model.Ready =>
                       (Moth.Config.get_task_priority (task_list_head) >=
                          Moth.Config.get_task_priority (task_id)))));

      if task_id = task_list_head then

         pragma assert (task_id = First_Element (Model.Ready));

         -- Set the new list head (the next from the removed task)
         -- Note: next_id could be set to OS_TASK_ID_NONE
         task_list_head := next_id;

         if next_id /= OS_TASK_ID_NONE then

            pragma assert (next_id = Element (Model.Ready,
                                              Next (Model.Ready, position)));

            pragma assert (for all id of Model.Ready =>
                       (if task_id /= id then
                           (Moth.Config.get_task_priority (next_id) >=
                              Moth.Config.get_task_priority (id))));

            Delete (Model.Ready, position);
            Insert (Model.Idle, task_id);

            pragma assert (Contains (Model.Idle, task_id));
            pragma assert (not Contains (Model.Ready, task_id));

            pragma assert (for all task_id in os_task_id_param_t =>
              ((Contains (Model.Idle, task_id) and then
                not Contains (Model.Ready, task_id)) or else
               (Contains (Model.Ready, task_id) and then
                not Contains (Model.Idle, task_id) and then
                -- A task should only be once in the ready list
                Find (Model.Ready, task_id) =
                     Reverse_Find (Model.Ready, task_id))));

            pragma assert (First_Element (Model.Ready) = task_list_head);
            pragma assert (Contains (Model.Ready, next_id));
            pragma assert (Contains (Model.Ready, task_list_head));

            -- The new list head [next] has no prev
            prev_task (next_id) := OS_TASK_ID_NONE;

            pragma assert (prev_task (task_list_head) = OS_TASK_ID_NONE);

            pragma assert (if Is_Empty (Model.Ready) then
                  task_list_head = OS_TASK_ID_NONE
               else
                  (task_list_head /= OS_TASK_ID_NONE and then
                   Contains (Model.Ready, task_list_head) and then
                   (for all task_id of Model.Ready =>
                       (Moth.Config.get_task_priority (task_list_head) >=
                          Moth.Config.get_task_priority (task_id)))));
         else
            Delete (Model.Ready, position);
            Insert (Model.Idle, task_id);

            pragma assert (Contains (Model.Idle, task_id));
            pragma assert (not Contains (Model.Ready, task_id));

            pragma assert (for all task_id in os_task_id_param_t =>
              ((Contains (Model.Idle, task_id) and then
                not Contains (Model.Ready, task_id)) or else
               (Contains (Model.Ready, task_id) and then
                not Contains (Model.Idle, task_id) and then
                -- A task should only be once in the ready list
                Find (Model.Ready, task_id) =
                     Reverse_Find (Model.Ready, task_id))));

            pragma assert (task_list_head = OS_TASK_ID_NONE);
            pragma assert (next_id = OS_TASK_ID_NONE);
            pragma assert (Is_Empty (Model.Ready));

            pragma assert (if Is_Empty (Model.Ready) then
                  task_list_head = OS_TASK_ID_NONE
               else
                  (task_list_head /= OS_TASK_ID_NONE and then
                   Contains (Model.Ready, task_list_head) and then
                   (for all task_id of Model.Ready =>
                       (Moth.Config.get_task_priority (task_list_head) >=
                          Moth.Config.get_task_priority (task_id)))));
         end if;

         pragma assert (for all task_id in os_task_id_param_t =>
              ((Contains (Model.Idle, task_id) and then
                not Contains (Model.Ready, task_id)) or else
               (Contains (Model.Ready, task_id) and then
                not Contains (Model.Idle, task_id) and then
                -- A task should only be once in the ready list
                Find (Model.Ready, task_id) =
                     Reverse_Find (Model.Ready, task_id))));

         pragma assert (if Is_Empty (Model.Ready) then
              task_list_head = OS_TASK_ID_NONE
           else
              (task_list_head /= OS_TASK_ID_NONE and then
               Contains (Model.Ready, task_list_head) and then
               (for all task_id of Model.Ready =>
                   (Moth.Config.get_task_priority (task_list_head) >=
                      Moth.Config.get_task_priority (task_id)))));
      else
         --  The list is not empty and the task is not at the list head.

         pragma assert (for all id of Model.ready =>
                        Moth.Config.get_task_priority (task_list_head) >=
                           Moth.Config.get_task_priority (id));
         pragma assert (for all id of Model.ready =>
                        next_task (id) /= task_list_head);
         pragma assert (prev_task (task_list_head) = OS_TASK_ID_NONE);
         pragma assert (prev_id /= OS_TASK_ID_NONE);
         pragma assert (Contains (Model.Ready, prev_id));
         pragma assert (Contains (Model.Ready, task_list_head));
         pragma assert (next_id /= task_list_head);

         -- prev_id has to be the previous element from task_id
         pragma assert (prev_id = Element (Model.Ready, Previous (Model.Ready, position)));

         --  link next from prev task to our next
         next_task (prev_id) := next_id;

         if next_id /= OS_TASK_ID_NONE then

            pragma assert (Contains (Model.Ready, next_id));

            Delete (Model.Ready, position);
            Insert (Model.Idle, task_id);

            pragma assert (Contains (Model.Idle, task_id));
            pragma assert (not Contains (Model.Ready, task_id));

            pragma assert (for all task_id in os_task_id_param_t =>
              ((Contains (Model.Idle, task_id) and then
                not Contains (Model.Ready, task_id)) or else
               (Contains (Model.Ready, task_id) and then
                not Contains (Model.Idle, task_id) and then
                -- A task should only be once in the ready list
                Find (Model.Ready, task_id) =
                     Reverse_Find (Model.Ready, task_id))));

            pragma assert (prev_task (task_list_head) = OS_TASK_ID_NONE);
            --  link prev from next task to our prev
            prev_task (next_id) := prev_id;
            pragma assert (prev_task (task_list_head) = OS_TASK_ID_NONE);
            pragma assert (Contains (Model.Ready, task_list_head));

            pragma assert (if Is_Empty (Model.Ready) then
                  task_list_head = OS_TASK_ID_NONE
               else
                  (task_list_head /= OS_TASK_ID_NONE and then
                   Contains (Model.Ready, task_list_head) and then
                   (for all task_id of Model.Ready =>
                       (Moth.Config.get_task_priority (task_list_head) >=
                          Moth.Config.get_task_priority (task_id)))));
         else
            -- no next_id
            pragma assert (next_id = OS_TASK_ID_NONE);
            -- task_id is the last element of ready list
            pragma assert (Last_Element (Model.Ready) = task_id);

            Delete (Model.Ready, position);
            Insert (Model.Idle, task_id);

            pragma assert (Contains (Model.Idle, task_id));
            pragma assert (not Contains (Model.Ready, task_id));

            pragma assert (for all task_id in os_task_id_param_t =>
              ((Contains (Model.Idle, task_id) and then
                not Contains (Model.Ready, task_id)) or else
               (Contains (Model.Ready, task_id) and then
                not Contains (Model.Idle, task_id) and then
                -- A task should only be once in the ready list
                Find (Model.Ready, task_id) =
                     Reverse_Find (Model.Ready, task_id))));

            -- so prev_id has now to be the last element of the ready list
            pragma assert (prev_id = Last_Element (Model.Ready));

            pragma assert (if Is_Empty (Model.Ready) then
                  task_list_head = OS_TASK_ID_NONE
               else
                  (task_list_head /= OS_TASK_ID_NONE and then
                   Contains (Model.Ready, task_list_head) and then
                   (for all task_id of Model.Ready =>
                       (Moth.Config.get_task_priority (task_list_head) >=
                          Moth.Config.get_task_priority (task_id)))));
         end if;

         pragma assert (prev_task (task_list_head) = OS_TASK_ID_NONE);
         pragma assert (Contains (Model.Ready, task_list_head));
         pragma assert (Contains (Model.Ready, prev_id));

          pragma assert (for all task_id in os_task_id_param_t =>
              ((Contains (Model.Idle, task_id) and then
                not Contains (Model.Ready, task_id)) or else
               (Contains (Model.Ready, task_id) and then
                not Contains (Model.Idle, task_id) and then
                -- A task should only be once in the ready list
                Find (Model.Ready, task_id) =
                     Reverse_Find (Model.Ready, task_id))));

          pragma assert (if Is_Empty (Model.Ready) then
              task_list_head = OS_TASK_ID_NONE
           else
              (task_list_head /= OS_TASK_ID_NONE and then
               Contains (Model.Ready, task_list_head) and then
               (for all task_id of Model.Ready =>
                   (Moth.Config.get_task_priority (task_list_head) >=
                      Moth.Config.get_task_priority (task_id)))));
      end if;

          pragma assert (Length (Model.Idle) <= OS_MAX_TASK_CNT);
          pragma assert (Length (Model.Ready) <= OS_MAX_TASK_CNT);
          -- the sum of length of both list needs to be OS_MAW_TASK_CNT
          pragma assert (Length (Model.Idle) + Length (Model.Ready) = OS_MAX_TASK_CNT);

          -- A task is either in one list or in the other.
          pragma assert (for all task_id in os_task_id_param_t =>
              ((Contains (Model.Idle, task_id) and then
                not Contains (Model.Ready, task_id)) or else
               (Contains (Model.Ready, task_id) and then
                not Contains (Model.Idle, task_id) and then
                -- A task should only be once in the ready list
                Find (Model.Ready, task_id) =
                                   Reverse_Find (Model.Ready, task_id))));

          -- If the ready list is not empty there is a task list head
          pragma assert (if Is_Empty (Model.Ready) then
              task_list_head = OS_TASK_ID_NONE
           else
              (task_list_head /= OS_TASK_ID_NONE and then
               Contains (Model.Ready, task_list_head) and then
               (for all task_id of Model.Ready =>
                   (Moth.Config.get_task_priority (task_list_head) >=
                      Moth.Config.get_task_priority (task_id)))));

          -- All tasks part of the idle list have no next and no prev
          pragma assert (for all task_id of Model.Idle =>
              (next_task (task_id) = OS_TASK_ID_NONE and then
               prev_task (task_id) = OS_TASK_ID_NONE));

          -- tasks are ordered by priority in the ready list
          pragma assert (for all task_id of Model.Ready =>
              (if task_id = First_Element (Model.Ready) then
                  (prev_task (task_id) = OS_TASK_ID_NONE and then
                   task_id = task_list_head and then
                   (if Length (Model.Ready) = 1 then
                       next_task (task_id) = OS_TASK_ID_NONE
                    else
                       (next_task (task_id) /= OS_TASK_ID_NONE and then
                        next_task (task_id) =
                                   Element (Model.Ready,
                                            Next (Model.Ready,
                                                  Find (Model.Ready,
                                                        task_id))) and then
                        next_task (task_id) /= task_id and then
                        next_task (task_id) /= task_list_head and then
                        Moth.Config.get_task_priority (next_task (task_id)) <=
                               Moth.Config.get_task_priority (task_id))))
               elsif task_id = Last_Element (Model.Ready) then
                  (next_task (task_id) = OS_TASK_ID_NONE and then
                   prev_task (task_id) /= OS_TASK_ID_NONE and then
                   prev_task (task_id) =
                              Element (Model.Ready,
                                       Previous (Model.Ready,
                                                 Find (Model.Ready,
                                                       task_id))) and then
                   prev_task (task_id) /= task_id and then
                   Moth.Config.get_task_priority (prev_task (task_id)) >=
                      Moth.Config.get_task_priority (task_id))
               else
                  (next_task (task_id) /= OS_TASK_ID_NONE and then
                   next_task (task_id) =
                              Element (Model.Ready,
                                       Next (Model.Ready,
                                             Find (Model.Ready,
                                                   task_id))) and then
                   prev_task (task_id) /= OS_TASK_ID_NONE and then
                   prev_task (task_id) =
                              Element (Model.Ready,
                                       Previous (Model.Ready,
                                                 Find (Model.Ready,
                                                       task_id))) and then
                   next_task (task_id) /= prev_task (task_id) and then
                   next_task (task_id) /= task_list_head and then
                   next_task (task_id) /= task_id and then
                   prev_task (task_id) /= task_id and then
                   prev_task (task_id) /= Last_Element (Model.Ready) and then
                   Moth.Config.get_task_priority (prev_task (task_id)) >=
                      Moth.Config.get_task_priority (task_id) and then
                   Moth.Config.get_task_priority (next_task (task_id)) <=
                      Moth.Config.get_task_priority (task_id))));
               
   end remove_task_from_ready_list;

   --------------
   -- schedule --
   --------------

   procedure schedule (task_id : out os_task_id_param_t)
   with
      Pre => task_list_is_well_formed,
      Post => task_is_ready (task_id) and then
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

   function get_current_task_id return os_task_id_param_t is
      (current_task);

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
      task_id := current_task;

      tmp_mask := waiting_mask and Moth.Config.get_mbx_permission (task_id);

      --  We remove the current task from the ready list.
      remove_task_from_ready_list (task_id);

      if tmp_mask /= 0 then
         mbx_mask (task_id) := tmp_mask;

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

      -- All Mbx mask for tasks are 0
      mbx_mask := (others => 0);

      M.init;

      pragma assert (for all id in os_task_id_param_t =>
              (Contains (Model.Idle, id) and then
                not Contains (Model.Ready, id)));

      for task_iterator in os_task_id_param_t'Range loop

         pragma Loop_Invariant (task_list_is_well_formed);

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

end Scheduler;
