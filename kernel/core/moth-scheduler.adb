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

   package body M is

      function idle_lt (Left, Right : os_task_id_param_t) return Boolean is
        (Left < Right);

      function ready_equal (Left, Right : os_task_id_param_t) return Boolean is
        (Left = Right);

      function os_ghost_task_list_is_well_formed return Boolean is
        (
      --  each list needs to have a length lower or equal to OS_MAX_TASK_CNT
      (Length (Model.Idle) <= OS_MAX_TASK_CNT)
         and then (Length (Model.Ready) <= OS_MAX_TASK_CNT)
      --  the sum of length of both list needs to be OS_MAX_TASK_CNT

         and then
         (Length (Model.Idle) + Length (Model.Ready) = OS_MAX_TASK_CNT)
      --  A task is either in one list or in the other.

         and then
         (for all id in os_task_id_param_t =>
            ((Contains (Model.Idle, id) and not Contains (Model.Ready, id))
             or else
             (Contains (Model.Ready, id) and not Contains (Model.Idle, id))))
      --  a task is never it own prev or its own next

         and then
         (for all id in os_task_id_param_t =>
            (next_task (id) /= id and prev_task (id) /= id))
      --  All tasks part of the idle list have no next and no prev

         and then
         (for all id of Model.Idle =>
            (next_task (id) = OS_TASK_ID_NONE and
             prev_task (id) = OS_TASK_ID_NONE))
      --  A task should only be once in the ready list

         and then
         (for all id of Model.Ready =>
            (Find (Model.Ready, id) = Reverse_Find (Model.Ready, id)))
         and then
         (if Is_Empty (Model.Ready) then
      --  If the Ready list is empty, there is no task list head
      (task_list_head = OS_TASK_ID_NONE)
          else
      --  If the ready list is not empty there is a task list head

            ((task_list_head = First_Element (Model.Ready))
             and then (prev_task (task_list_head) = OS_TASK_ID_NONE)))
      --  the task list head task has the higher priority

         and then
         (for all id of Model.Ready =>
            (Moth.Config.get_task_priority (task_list_head) >=
             Moth.Config.get_task_priority (id)))
      --  tasks are ordered by priority in the ready list

         and then
         (for all id of Model.Ready =>
            (if (id = First_Element (Model.Ready)) then
      --  it is the task list head

               ((id = task_list_head) and
                (prev_task (id) = OS_TASK_ID_NONE) and
                (if (Length (Model.Ready) = 1) then
      --  if only one task, no next task

                   (next_task (id) = OS_TASK_ID_NONE)
                 else
      --  More than one task in the list

                   (((next_task (id) in os_task_id_param_t) and
                     (next_task (id) =
                      Element
                        (Model.Ready,
                         Next (Model.Ready, First (Model.Ready)))))
                    and then
      --  task list head has higher priority

                    ((for all id2 of Model.Ready =>
                        (Moth.Config.get_task_priority (id) >=
                         Moth.Config.get_task_priority (id2))) and
      --  The previous of next is the task

                     (prev_task (next_task (id)) = id) and
      -- next has lower priority

                     (Moth.Config.get_task_priority (next_task (id)) <=
                      Moth.Config.get_task_priority (id))))))
             elsif (id = Last_Element (Model.Ready)) then
      -- it is the last element

               (((next_task (id) = OS_TASK_ID_NONE) and
                 (prev_task (id) in os_task_id_param_t) and
      --  prev task is previous element of ready list

                 (prev_task (id) =
                  Element
                    (Model.Ready, Previous (Model.Ready, Last (Model.Ready)))))
                and then
      --  task list tail has lower priority

                ((for all id2 of Model.Ready =>
                    (Moth.Config.get_task_priority (id) <=
                     Moth.Config.get_task_priority (id2))) and
      --  The next of previous is the task

                 (next_task (prev_task (id)) = id) and
      --  Previous task has higher priority

                 (Moth.Config.get_task_priority (prev_task (id)) >=
                  Moth.Config.get_task_priority (id))))
             else
      -- There is a next

               (((next_task (id) in os_task_id_param_t) and
      --  The next is next task in ready list

                 (next_task (id) =
                  Element
                    (Model.Ready,
                     Next (Model.Ready, Find (Model.Ready, id)))) and
      -- there is a prev

                 (prev_task (id) in os_task_id_param_t) and
      --  The prev is prev task in ready list

                 (prev_task (id) =
                  Element
                    (Model.Ready,
                     Previous (Model.Ready, Find (Model.Ready, id)))) and
      -- Next cannot be prev

                 (next_task (id) /= prev_task (id)) and
      -- Next cannot be list head

                 (next_task (id) /= task_list_head) and
      --  next cannot be first element of the list

                 (next_task (id) /= First_Element (Model.Ready)) and
      --  prev cannot be last element of the list

                 (prev_task (id) /= Last_Element (Model.Ready)))
                and then
                ((prev_task (next_task (id)) = id) and
                 (next_task (prev_task (id)) = id) and
      --  previous task priority is higher or equal

                 (Moth.Config.get_task_priority (prev_task (id)) >=
                  Moth.Config.get_task_priority (id)) and
      --  next task priority is lower or equal

                 (Moth.Config.get_task_priority (next_task (id)) <=
                  Moth.Config.get_task_priority (id)) and
      --  previous task priority is higher or equal to next task

                 (Moth.Config.get_task_priority (prev_task (id)) >=
                  Moth.Config.get_task_priority (next_task (id))))))));

      procedure init is
      begin

         Clear (Model.Ready);

         Clear (Model.Idle);

         for task_id in os_task_id_param_t loop
            Insert (Model.Idle, task_id);
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

   function task_is_ready (task_id : os_task_id_param_t) return Boolean is
     (Contains (M.Model.Ready, task_id) and
      not Contains (M.Model.Idle, task_id));

   ---------------------------
   -- current_task_is_ready --
   ---------------------------

   function current_task_is_ready return Boolean is
     (task_is_ready (current_task));

   ------------------------------
   -- task_list_is_well_formed --
   ------------------------------

   function task_list_is_well_formed return Boolean is
     (M.os_ghost_task_list_is_well_formed);

   ----------------------------
   -- add_task_to_ready_list --
   ----------------------------

   procedure add_task_to_ready_list (task_id : os_task_id_param_t) is
      index_id : os_task_id_t := task_list_head;
   begin

      if index_id = OS_TASK_ID_NONE then
         --  No task in the ready list. Add this task at list head
         pragma Assert (Is_Empty (Model.Ready));
         pragma Assert (Contains (Model.Idle, task_id));
         --  next_task and prev_task are already set to OS_TASK_ID_NONE.
         pragma Assert (next_task (task_id) = OS_TASK_ID_NONE);
         pragma Assert (prev_task (task_id) = OS_TASK_ID_NONE);

         Delete (Model.Idle, task_id);
         Prepend (Model.Ready, task_id);

         --  task_id is now the only element of the ready_list.
         task_list_head := task_id;

         --  next_task and prev_task are already set to OS_TASK_ID_NONE.
         pragma Assert (next_task (task_id) = OS_TASK_ID_NONE);
         pragma Assert (prev_task (task_id) = OS_TASK_ID_NONE);

      else
         pragma Assert (Contains (Model.Ready, index_id));
         while index_id /= OS_TASK_ID_NONE loop
            pragma Loop_Invariant (task_list_is_well_formed);
            pragma Loop_Invariant (Model = Model'Loop_Entry);
            pragma Loop_Invariant (next_task = next_task'Loop_Entry);
            pragma Loop_Invariant (Contains (Model.Ready, index_id));
            --  pragma assert (Contains (Model.Ready, index_id)); At any step
            --  in the loop index_id needs to be ready.
            if task_id = index_id then

               --  task_id is already in the ready list
               pragma Assert (Contains (Model.Ready, task_id));
               --  So it should not be in the idle list
               pragma Assert (not Contains (Model.Idle, task_id));
               --  Nothing to do, task_id is already in the ready list

               exit;
            elsif Moth.Config.get_task_priority (task_id) >
              Moth.Config.get_task_priority (index_id)
            then
               --  task_id is higher priority so it needs to be inserted before
               --  index_id.
               declare
                  prev_id : constant os_task_id_t := prev_task (index_id);
               begin

                  pragma Assert (not Contains (Model.Ready, task_id));
                  pragma Assert (Contains (Model.Idle, task_id));
                  pragma Assert (not Contains (Model.Idle, index_id));
                  pragma Assert (Contains (Model.Ready, index_id));

                  Delete (Model.Idle, task_id);
                  Insert (Model.Ready, Find (Model.Ready, index_id), task_id);

                  prev_task (index_id) := task_id;
                  next_task (task_id)  := index_id;

                  if prev_id = OS_TASK_ID_NONE then
                     pragma Assert (index_id = task_list_head);
                     pragma Assert (First_Element (Model.Ready) = task_id);
                     task_list_head := task_id;
                  else
                     next_task (prev_id) := task_id;
                     prev_task (task_id) := prev_id;
                  end if;

                  exit;
               end;
            elsif next_task (index_id) = OS_TASK_ID_NONE then
               --  we are at the last element of the ready list.

               pragma Assert (Last_Element (Model.Ready) = index_id);
               --  task_id was not part of the Ready list
               pragma Assert (not Contains (Model.Ready, task_id));
               --  task_id was part of the Idle list
               pragma Assert (Contains (Model.Idle, task_id));

               --  Let's delete task_id from the idle list.
               Delete (Model.Idle, task_id);
               --  and add it to the ready list.
               Append (Model.Ready, task_id);

               --  We need to insert task_id at the end of the ready list
               next_task (index_id) := task_id;
               prev_task (task_id)  := index_id;

               --  We don't need to update next_task as it is already set to
               --  OS_TASK_ID_NONE
               pragma Assert (next_task (task_id) = OS_TASK_ID_NONE);

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

   procedure remove_task_from_ready_list (task_id : os_task_id_param_t) with
      Pre => task_is_ready (task_id)
      and then M.os_ghost_task_list_is_well_formed,
      Post => not task_is_ready (task_id)
      and then M.os_ghost_task_list_is_well_formed
   is
      next_id  : constant os_task_id_t := next_task (task_id);
      prev_id  : constant os_task_id_t := prev_task (task_id);
      position : M.ready_list_t.Cursor := Find (Model.Ready, task_id) with
         Ghost;
   begin

      --  First element if the ready list is task_list_head
      pragma Assert (First_Element (Model.Ready) = task_list_head);
      --  task_id is at position
      pragma Assert (Element (Model.Ready, position) = task_id);
      --  task_id is only once in the ready list
      pragma Assert
        (Element (Model.Ready, Reverse_Find (Model.Ready, task_id)) = task_id);

      --  All tasks part of the idle list have no next and no prev
      pragma Assert
        (for all id of Model.Idle =>
           (next_task (id) = OS_TASK_ID_NONE
            and then prev_task (id) = OS_TASK_ID_NONE));

      --  Disconnect task_id from the ready list
      next_task (task_id) := OS_TASK_ID_NONE;
      prev_task (task_id) := OS_TASK_ID_NONE;

      pragma Assert
        (for all id in os_task_id_param_t =>
           ((Contains (Model.Idle, id) and then not Contains (Model.Ready, id))
            or else
            (Contains (Model.Ready, id)
             and then not Contains (Model.Idle, id))));

      --  A task should only be once in the ready list
      pragma Assert
        (for all id of Model.Ready =>
           (Find (Model.Ready, id) = Reverse_Find (Model.Ready, id)));

      pragma Assert
        (if Is_Empty (Model.Ready) then task_list_head = OS_TASK_ID_NONE
         else
           (task_list_head /= OS_TASK_ID_NONE
            and then Contains (Model.Ready, task_list_head)
            and then
            (for all id of Model.Ready =>
               (Moth.Config.get_task_priority (task_list_head) >=
                Moth.Config.get_task_priority (id)))));

      --  the sum of length of both list needs to be OS_MAW_TASK_CNT
      pragma Assert
        (Length (Model.Idle) + Length (Model.Ready) = OS_MAX_TASK_CNT);

      if task_id = task_list_head then

         pragma Assert (Length (Model.Ready) >= 1);

         pragma Assert (task_id = First_Element (Model.Ready));

         pragma Assert
           (for all id of Model.Ready =>
              (Moth.Config.get_task_priority (task_id) >=
               Moth.Config.get_task_priority (id)));

         --  Set the new list head (the next from the removed task)
         --  Note: next_id could be set to OS_TASK_ID_NONE
         task_list_head := next_id;

         if next_id /= OS_TASK_ID_NONE then

            --  prev task of next_id is task_id
            pragma Assert (prev_task (next_id) = task_id);

            --  next_id is part of the ready list
            pragma Assert (Contains (Model.Ready, next_id));

            --  priority of previous head is higher than next_id
            pragma Assert
              (Moth.Config.get_task_priority (task_id) >=
               Moth.Config.get_task_priority (next_id));

            --  The ready list has at lest 2 tasks
            pragma Assert (Length (Model.Ready) > 1);

            --  next_id is the second task of the ready list
            pragma Assert
              (next_id =
               Element (Model.Ready, Next (Model.Ready, First (Model.Ready))));

            --  next_id is at the computed position in the ready list
            pragma Assert
              (next_id = Element (Model.Ready, Next (Model.Ready, position)));

            Delete_First (Model.Ready);
            Insert (Model.Idle, task_id);

            --  the sum of length of both list needs to be OS_MAW_TASK_CNT
            pragma Assert
              (Length (Model.Idle) + Length (Model.Ready) = OS_MAX_TASK_CNT);

            --  The ready list has at least one task
            pragma Assert (not Is_Empty (Model.Ready));

            pragma Assert
              (for all id of Model.Ready =>
                 (Moth.Config.get_task_priority (task_id) >=
                  Moth.Config.get_task_priority (id)));

            -- new list head is next_id
            pragma Assert (task_list_head = next_id);

            pragma Assert
              (for all id of Model.Ready =>
                 (Moth.Config.get_task_priority (next_id) >=
                  Moth.Config.get_task_priority (id)));

            pragma Assert (Contains (Model.Idle, task_id));
            pragma Assert (not Contains (Model.Ready, task_id));

            --  a task is either in one list or in the other
            pragma Assert
              (for all id in os_task_id_param_t =>
                 ((Contains (Model.Idle, id)
                   and then not Contains (Model.Ready, id))
                  or else
                  (Contains (Model.Ready, id)
                   and then not Contains (Model.Idle, id))));

            --  A task should only be once in the ready list
            pragma Assert
              (for all id of Model.Ready =>
                 (Find (Model.Ready, id) = Reverse_Find (Model.Ready, id)));

            --  The new list head is the first element of ready list
            pragma Assert (First_Element (Model.Ready) = task_list_head);
            pragma Assert (Contains (Model.Ready, task_list_head));

            --  The new list head [next_id] should have no prev
            prev_task (task_list_head) := OS_TASK_ID_NONE;

            pragma Assert (prev_task (task_list_head) = OS_TASK_ID_NONE);

            --  All tasks part of the idle list have no next and no prev
            pragma Assert
              (for all id of Model.Idle =>
                 (next_task (id) = OS_TASK_ID_NONE
                  and then prev_task (id) = OS_TASK_ID_NONE));

            pragma Assert
              (First (Model.Ready) = Find (Model.ready, task_list_head));

            pragma Assert
              (if Length (Model.Ready) = 1 then
                 (next_task (task_list_head) = OS_TASK_ID_NONE)
               else
                 (next_task (task_list_head) /= OS_TASK_ID_NONE
                  and then next_task (task_list_head) in os_task_id_param_t
                  and then next_task (task_list_head) /= task_list_head
                  and then prev_task (next_task (task_list_head)) =
                    task_list_head
                  and then Contains (Model.Ready, next_task (task_list_head))
                  and then next_task (task_list_head) =
                    Element
                      (Model.Ready,
                       Next (Model.Ready, Find (Model.Ready, task_list_head)))
                  and then next_task (task_list_head) =
                    Element
                      (Model.Ready,
                       Next
                         (Model.Ready,
                          Reverse_Find (Model.Ready, task_list_head)))
                  and then next_task (task_list_head) =
                    Element
                      (Model.Ready, Next (Model.Ready, First (Model.Ready)))));

         else
            pragma Assert (Length (Model.Ready) = 1);

            Delete_First (Model.Ready);
            Insert (Model.Idle, task_id);

            --  the sum of length of both list needs to be OS_MAW_TASK_CNT
            pragma Assert
              (Length (Model.Idle) + Length (Model.Ready) = OS_MAX_TASK_CNT);

            pragma Assert (Is_Empty (Model.Ready));
            pragma Assert (Length (Model.Idle) = OS_MAX_TASK_CNT);
            pragma Assert (Contains (Model.Idle, task_id));

            pragma Assert
              (for all id in os_task_id_param_t =>
                 (Contains (Model.Idle, id)
                  and then not Contains (Model.Ready, id)));

            pragma Assert (task_list_head = OS_TASK_ID_NONE);
            pragma Assert (next_id = OS_TASK_ID_NONE);

            --  All tasks part of the idle list have no next and no prev
            pragma Assert
              (for all id of Model.Idle =>
                 (next_task (id) = OS_TASK_ID_NONE
                  and then prev_task (id) = OS_TASK_ID_NONE));

         end if;

         pragma Assert
           (for all id in os_task_id_param_t =>
              ((Contains (Model.Idle, id)
                and then not Contains (Model.Ready, id))
               or else
               (Contains (Model.Ready, id)
                and then not Contains (Model.Idle, id))));

         --  A task should only be once in the ready list
         pragma Assert
           (for all id of Model.Ready =>
              (Find (Model.Ready, id) = Reverse_Find (Model.Ready, id)));

         pragma Assert
           (if Is_Empty (Model.Ready) then task_list_head = OS_TASK_ID_NONE
            else
              (task_list_head /= OS_TASK_ID_NONE
               and then Contains (Model.Ready, task_list_head)
               and then
               (for all id of Model.Ready =>
                  (Moth.Config.get_task_priority (task_list_head) >=
                   Moth.Config.get_task_priority (id)))));

         --  All tasks part of the idle list have no next and no prev
         pragma Assert
           (for all id of Model.Idle =>
              (next_task (id) = OS_TASK_ID_NONE
               and then prev_task (id) = OS_TASK_ID_NONE));

      else
         --  The list is not empty and the task is not at the list head.
         pragma Assert
           (for all id of Model.ready =>
              Moth.Config.get_task_priority (task_list_head) >=
              Moth.Config.get_task_priority (id));
         pragma Assert
           (for all id of Model.ready => next_task (id) /= task_list_head);
         pragma Assert (prev_task (task_list_head) = OS_TASK_ID_NONE);
         pragma Assert (prev_id /= OS_TASK_ID_NONE);
         pragma Assert (Contains (Model.Ready, prev_id));
         pragma Assert (Contains (Model.Ready, task_list_head));
         pragma Assert (next_id /= task_list_head);
         pragma Assert (not Contains (Model.Idle, prev_id));
         pragma Assert (not Contains (Model.Idle, task_list_head));
         pragma Assert (Length (Model.Idle) <= (OS_MAX_TASK_CNT - 2));

         --  prev_id has to be the previous element from task_id
         pragma Assert
           (prev_id = Element (Model.Ready, Previous (Model.Ready, position)));

         --  link next from prev task to our next
         next_task (prev_id) := next_id;

         if next_id /= OS_TASK_ID_NONE then

            --  All tasks part of the idle list have no next and no prev
            pragma Assert
              (for all id of Model.Idle =>
                 (next_task (id) = OS_TASK_ID_NONE
                  and then prev_task (id) = OS_TASK_ID_NONE));

            --  prev_id has to be the next element from task_id
            pragma Assert
              (next_id = Element (Model.Ready, Next (Model.Ready, position)));

            pragma Assert (next_task (task_id) = OS_TASK_ID_NONE);
            pragma Assert (prev_task (task_id) = OS_TASK_ID_NONE);

            pragma Assert (not Contains (Model.Idle, task_id));
            pragma Assert (Contains (Model.Ready, task_id));
            pragma Assert (Contains (Model.Ready, next_id));

            pragma Assert
              (for all id in os_task_id_param_t =>
                 ((Contains (Model.Idle, id)
                   and then not Contains (Model.Ready, id))
                  or else
                  (Contains (Model.Ready, id)
                   and then not Contains (Model.Idle, id))));

            --  A task should only be once in the ready list
            pragma Assert
              (for all id of Model.Ready =>
                 (Find (Model.Ready, id) = Reverse_Find (Model.Ready, id)));

            Delete (Model.Ready, position);
            Insert (Model.Idle, task_id);

            --  the sum of length of both list needs to be OS_MAW_TASK_CNT
            pragma Assert
              (Length (Model.Idle) + Length (Model.Ready) = OS_MAX_TASK_CNT);

            pragma Assert (Contains (Model.Idle, task_id));
            pragma Assert (not Contains (Model.Ready, task_id));

            --  All tasks part of the idle list have no next and no prev
            pragma Assert
              (for all id of Model.Idle =>
                 (next_task (id) = OS_TASK_ID_NONE
                  and then prev_task (id) = OS_TASK_ID_NONE));

            pragma Assert
              (for all id in os_task_id_param_t =>
                 ((Contains (Model.Idle, id)
                   and then not Contains (Model.Ready, id))
                  or else
                  (Contains (Model.Ready, id)
                   and then not Contains (Model.Idle, id))));

            --  A task should only be once in the ready list
            pragma Assert
              (for all id of Model.Ready =>
                 (Find (Model.Ready, id) = Reverse_Find (Model.Ready, id)));

            pragma Assert (prev_task (task_list_head) = OS_TASK_ID_NONE);

            --  link prev from next task to our prev
            prev_task (next_id) := prev_id;

            pragma Assert (prev_task (task_list_head) = OS_TASK_ID_NONE);
            pragma Assert (Contains (Model.Ready, task_list_head));

            pragma Assert
              (if Is_Empty (Model.Ready) then task_list_head = OS_TASK_ID_NONE
               else
                 (task_list_head /= OS_TASK_ID_NONE
                  and then Contains (Model.Ready, task_list_head)
                  and then
                  (for all id of Model.Ready =>
                     (Moth.Config.get_task_priority (task_list_head) >=
                      Moth.Config.get_task_priority (id)))));

            --  All tasks part of the idle list have no next and no prev
            pragma Assert
              (for all id of Model.Idle =>
                 (next_task (id) = OS_TASK_ID_NONE
                  and then prev_task (id) = OS_TASK_ID_NONE));

         else
            -- no next_id
            pragma Assert (next_id = OS_TASK_ID_NONE);
            --  task_id is the last element of ready list
            pragma Assert (Last_Element (Model.Ready) = task_id);

            Delete_Last (Model.Ready);
            Insert (Model.Idle, task_id);

            --  the sum of length of both list needs to be OS_MAW_TASK_CNT
            pragma Assert
              (Length (Model.Idle) + Length (Model.Ready) = OS_MAX_TASK_CNT);

            pragma Assert (Contains (Model.Idle, task_id));
            pragma Assert (not Contains (Model.Ready, task_id));

            pragma Assert
              (for all id in os_task_id_param_t =>
                 ((Contains (Model.Idle, id)
                   and then not Contains (Model.Ready, id))
                  or else
                  (Contains (Model.Ready, id)
                   and then not Contains (Model.Idle, id))));

            --  A task should only be once in the ready list
            pragma Assert
              (for all id of Model.Ready =>
                 (Find (Model.Ready, id) = Reverse_Find (Model.Ready, id)));

            --  so prev_id has now to be the last element of the ready list
            pragma Assert (prev_id = Last_Element (Model.Ready));

            pragma Assert
              (if Is_Empty (Model.Ready) then task_list_head = OS_TASK_ID_NONE
               else
                 (task_list_head /= OS_TASK_ID_NONE
                  and then Contains (Model.Ready, task_list_head)
                  and then
                  (for all id of Model.Ready =>
                     (Moth.Config.get_task_priority (task_list_head) >=
                      Moth.Config.get_task_priority (id)))));

            --  All tasks part of the idle list have no next and no prev
            pragma Assert
              (for all id of Model.Idle =>
                 (next_task (id) = OS_TASK_ID_NONE
                  and then prev_task (id) = OS_TASK_ID_NONE));

         end if;

         pragma Assert (prev_task (task_list_head) = OS_TASK_ID_NONE);
         pragma Assert (Contains (Model.Ready, task_list_head));
         pragma Assert (Contains (Model.Ready, prev_id));

         pragma Assert
           (for all id in os_task_id_param_t =>
              ((Contains (Model.Idle, id)
                and then not Contains (Model.Ready, id))
               or else
               (Contains (Model.Ready, id)
                and then not Contains (Model.Idle, id))));

         --  A task should only be once in the ready list
         pragma Assert
           (for all id of Model.Ready =>
              (Find (Model.Ready, id) = Reverse_Find (Model.Ready, id)));

         pragma Assert
           (if Is_Empty (Model.Ready) then task_list_head = OS_TASK_ID_NONE
            else
              (task_list_head /= OS_TASK_ID_NONE
               and then Contains (Model.Ready, task_list_head)
               and then
               (for all id of Model.Ready =>
                  (Moth.Config.get_task_priority (task_list_head) >=
                   Moth.Config.get_task_priority (id)))));

         --  All tasks part of the idle list have no next and no prev
         pragma Assert
           (for all id of Model.Idle =>
              (next_task (id) = OS_TASK_ID_NONE
               and then prev_task (id) = OS_TASK_ID_NONE));

      end if;

      pragma Assert (Length (Model.Idle) <= OS_MAX_TASK_CNT);
      pragma Assert (Length (Model.Ready) <= OS_MAX_TASK_CNT);
      --  the sum of length of both list needs to be OS_MAW_TASK_CNT
      pragma Assert
        (Length (Model.Idle) + Length (Model.Ready) = OS_MAX_TASK_CNT);

      --  A task is either in one list or in the other.
      pragma Assert
        (for all id in os_task_id_param_t =>
           ((Contains (Model.Idle, id) and then not Contains (Model.Ready, id))
            or else
            (Contains (Model.Ready, id)
             and then not Contains (Model.Idle, id))));

      --  A task should only be once in the ready list
      pragma Assert
        (for all id of Model.Ready =>
           (Find (Model.Ready, id) = Reverse_Find (Model.Ready, id)));

      --  If the ready list is not empty there is a task list head
      pragma Assert
        (if Is_Empty (Model.Ready) then task_list_head = OS_TASK_ID_NONE
         else
           (task_list_head /= OS_TASK_ID_NONE
            and then Contains (Model.Ready, task_list_head)
            and then
            (for all id of Model.Ready =>
               (Moth.Config.get_task_priority (task_list_head) >=
                Moth.Config.get_task_priority (id)))));

      --  All tasks part of the idle list have no next and no prev
      pragma Assert
        (for all id of Model.Idle =>
           (next_task (id) = OS_TASK_ID_NONE
            and then prev_task (id) = OS_TASK_ID_NONE));

      --  tasks are ordered by priority in the ready list
      pragma Assert
         (for all id of Model.Ready =>
            (if (id = First_Element (Model.Ready)) then
      --  it is the task list head

               ((id = task_list_head) and
                (prev_task (id) = OS_TASK_ID_NONE) and
                (if (Length (Model.Ready) = 1) then
      --  if only one task, no next task

                   (next_task (id) = OS_TASK_ID_NONE)
                 else
      --  More than one task in the list

                   (((next_task (id) in os_task_id_param_t) and
                     (next_task (id) =
                      Element
                        (Model.Ready,
                         Next (Model.Ready, First (Model.Ready)))))
                    and then
      --  task list head has higher priority

                    ((for all id2 of Model.Ready =>
                        (Moth.Config.get_task_priority (id) >=
                         Moth.Config.get_task_priority (id2))) and
      --  The previous of next is the task

                     (prev_task (next_task (id)) = id) and
      -- next has lower priority

                     (Moth.Config.get_task_priority (next_task (id)) <=
                      Moth.Config.get_task_priority (id))))))
             elsif (id = Last_Element (Model.Ready)) then
      -- it is the last element

               (((next_task (id) = OS_TASK_ID_NONE) and
                 (prev_task (id) in os_task_id_param_t) and
      --  prev task is previous element of ready list

                 (prev_task (id) =
                  Element
                    (Model.Ready, Previous (Model.Ready, Last (Model.Ready)))))
                and then
      --  task list tail has lower priority

                ((for all id2 of Model.Ready =>
                    (Moth.Config.get_task_priority (id) <=
                     Moth.Config.get_task_priority (id2))) and
      --  The next of previous is the task

                 (next_task (prev_task (id)) = id) and
      --  Previous task has higher priority

                 (Moth.Config.get_task_priority (prev_task (id)) >=
                  Moth.Config.get_task_priority (id))))
             else
      -- There is a next

               (((next_task (id) in os_task_id_param_t) and
      --  The next is next task in ready list

                 (next_task (id) =
                  Element
                    (Model.Ready,
                     Next (Model.Ready, Find (Model.Ready, id)))) and
      -- there is a prev

                 (prev_task (id) in os_task_id_param_t) and
      --  The prev is prev task in ready list

                 (prev_task (id) =
                  Element
                    (Model.Ready,
                     Previous (Model.Ready, Find (Model.Ready, id)))) and
      -- Next cannot be prev

                 (next_task (id) /= prev_task (id)) and
      -- Next cannot be list head

                 (next_task (id) /= task_list_head) and
      --  next cannot be first element of the list

                 (next_task (id) /= First_Element (Model.Ready)) and
      --  prev cannot be last element of the list

                 (prev_task (id) /= Last_Element (Model.Ready)))
                and then
                ((prev_task (next_task (id)) = id) and
                 (next_task (prev_task (id)) = id) and
      --  previous task priority is higher or equal

                 (Moth.Config.get_task_priority (prev_task (id)) >=
                  Moth.Config.get_task_priority (id)) and
      --  next task priority is lower or equal

                 (Moth.Config.get_task_priority (next_task (id)) <=
                  Moth.Config.get_task_priority (id)) and
      --  previous task priority is higher or equal to next task

                 (Moth.Config.get_task_priority (prev_task (id)) >=
                  Moth.Config.get_task_priority (next_task (id)))))));

   end remove_task_from_ready_list;

   --------------
   -- schedule --
   --------------

   procedure schedule (task_id : out os_task_id_param_t) with
      Pre  => task_list_is_well_formed,
      Post => task_is_ready (task_id) and then task_list_head = task_id
      and then task_list_is_well_formed
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

   function get_current_task_id return os_task_id_param_t is (current_task);

   ------------------
   -- get_mbx_mask --
   ------------------

   function get_mbx_mask (task_id : os_task_id_param_t) return os_mbx_mask_t is
     (mbx_mask (task_id));

   ----------
   -- wait --
   ----------

   procedure wait
     (task_id : out os_task_id_param_t; waiting_mask : in os_mbx_mask_t)
   is
      tmp_mask : os_mbx_mask_t;
   begin
      task_id := current_task;

      tmp_mask := waiting_mask and Moth.Config.get_mbx_permission (task_id);

      --  We remove the current task from the ready list.
      remove_task_from_ready_list (task_id);

      if tmp_mask /= 0 then
         mbx_mask (task_id) := tmp_mask;

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

   procedure yield (task_id : out os_task_id_param_t) is
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

   procedure task_exit (task_id : out os_task_id_param_t) is
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

   procedure init (task_id : out os_task_id_param_t) is
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

      M.init;

      pragma Assert
        (for all id in os_task_id_param_t =>
           (Contains (Model.Idle, id)
            and then not Contains (Model.Ready, id)));

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
