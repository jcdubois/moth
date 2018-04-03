
pragma Ada_2012;
pragma Style_Checks (Off);

with types;
with OpenConf;

with Interfaces.C; use Interfaces.C;

package os with
   SPARK_mode
is

   OS_INTERRUPT_TASK_ID : constant := 0;

   OS_TASK_ID_NONE     : constant := -1;
   OS_TASK_ID_ALL      : constant := -2;

   OS_MBX_MASK_ALL     : constant := 16#ffffffff#;

   OS_SUCCESS          : constant := 0;
   OS_ERROR_FIFO_FULL  : constant := -1;
   OS_ERROR_FIFO_EMPTY : constant := -2;
   OS_ERROR_DENIED     : constant := -3;
   OS_ERROR_RECEIVE    : constant := -4;
   OS_ERROR_PARAM      : constant := -5;
   OS_ERROR_MAX        : constant := OS_ERROR_PARAM;

   OS_MAX_TASK_CNT     : constant := OpenConf.CONFIG_MAX_TASK_COUNT;
   OS_MAX_TASK_ID      : constant := OpenConf.CONFIG_MAX_TASK_COUNT - 1;
   OS_MAX_MBX_CNT      : constant := OpenConf.CONFIG_TASK_MBX_COUNT;
   OS_MAX_MBX_ID       : constant := OpenConf.CONFIG_TASK_MBX_COUNT - 1;

   OS_MBX_MSG_SZ       : constant := OpenConf.CONFIG_MBX_SIZE;

  --
  --  Copyright (c) 2017 Jean-Christophe Dubois
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
  --  @file
  --  @author Jean-Christophe Dubois (jcd@tribudubois.net)
  --  @brief
  --

   subtype os_mbx_mask_t is types.uint32_t;

   subtype os_task_id_t is types.int8_t
                           range OS_TASK_ID_NONE .. OS_MAX_TASK_ID;

   subtype os_task_id_param_t is os_task_id_t
                           range 0 .. OS_MAX_TASK_ID;

   subtype os_status_t is types.int32_t
                           range OS_ERROR_MAX .. OS_SUCCESS;

   subtype os_mbx_index_t is types.uint8_t
                           range 0 .. OS_MAX_MBX_ID;

   subtype os_mbx_count_t is types.uint8_t
                           range 0 .. OS_MAX_MBX_CNT;

   subtype os_size_t is types.uint32_t;

   subtype os_priority_t is types.uint8_t;

   type os_mbx_msg_t is mod 2 ** OS_MBX_MSG_SZ;
   for os_mbx_msg_t'Size use OS_MBX_MSG_SZ;

   subtype os_virtual_address_t is types.uint32_t;

   type os_mbx_entry_t is record
      sender_id        : aliased os_task_id_t;
      msg              : aliased os_mbx_msg_t;
   end record;
   pragma Convention (C_Pass_By_Copy, os_mbx_entry_t);

   type os_mbx_t_array is
           array (0 .. OS_MAX_MBX_ID) of aliased os_mbx_entry_t;

   type os_mbx_t is record
      head             : aliased os_mbx_index_t;
      count            : aliased os_mbx_count_t;
      mbx_array        : aliased os_mbx_t_array;
   end record;
   pragma Convention (C_Pass_By_Copy, os_mbx_t);

   type os_task_section_t is record
      virtual_address  : aliased os_virtual_address_t;
      size             : aliased os_size_t;
   end record;
   pragma Convention (C_Pass_By_Copy, os_task_section_t);

   type os_task_ro_t is record
      priority         : aliased os_priority_t;
      mbx_permission   : aliased os_mbx_mask_t;
      text             : aliased os_task_section_t;
      bss              : aliased os_task_section_t;
      stack            : aliased os_task_section_t;
   end record;
   pragma Convention (C_Pass_By_Copy, os_task_ro_t);

   type os_task_rw_t is record
      next             : aliased os_task_id_t;
      prev             : aliased os_task_id_t;
      stack_pointer    : aliased os_virtual_address_t;
      mbx_waiting_mask : aliased os_mbx_mask_t;
      mbx              : aliased os_mbx_t;
   end record;
   pragma Convention (C_Pass_By_Copy, os_task_rw_t);

   os_task_ro : aliased constant array (0 .. OS_MAX_TASK_ID) of aliased os_task_ro_t;
   pragma Import (C, os_task_ro, "os_task_ro");

   os_task_rw : aliased array (0 .. OS_MAX_TASK_ID) of aliased os_task_rw_t;
   pragma Export (C, os_task_rw, "os_task_rw");

   os_ghost_initialized : Boolean := false
   with
      Ghost => true;

   function os_ghost_task_next_is_not_self return boolean is
      (not (for some task_id in 0 .. OS_MAX_TASK_ID =>
                  os_task_rw (task_id).next = os_task_id_param_t (task_id)))
   with
      Ghost => true;

   function os_ghost_task_prev_is_not_self return boolean is
      (not (for some task_id in 0 .. OS_MAX_TASK_ID =>
                  os_task_rw (task_id).prev = os_task_id_param_t (task_id)))
   with
      Ghost => true;

   function os_ghost_task_prev_and_next_different return boolean is
      (not (for some task_id in 0 .. OS_MAX_TASK_ID =>
         os_task_rw (task_id).prev /= OS_TASK_ID_NONE and then
         os_task_rw (task_id).prev = os_task_rw (task_id).next))
   with
      Ghost => true;

   function os_ghost_task_is_not_twice_in_next return boolean is
      (not (for some task_id in 0 .. (OS_MAX_TASK_ID - 1) =>
         os_task_rw (task_id).next /= OS_TASK_ID_NONE and then
         (for some next_id in (task_id + 1) .. OS_MAX_TASK_ID =>
            os_task_rw (task_id).next = os_task_rw (next_id).next)))
   with
      Ghost => true;

   function os_ghost_task_is_not_twice_in_prev return boolean is
      (not (for some task_id in 0 .. (OS_MAX_TASK_ID - 1) =>
         os_task_rw (task_id).prev /= OS_TASK_ID_NONE and then
         (for some prev_id in (task_id + 1) .. OS_MAX_TASK_ID =>
            os_task_rw (task_id).prev = os_task_rw (prev_id).prev)))
   with
      Ghost => true;

   function os_ghost_task_link_is_bidirectionnal return boolean is
      (for all task_id in 0 .. OS_MAX_TASK_ID =>
         (case os_task_rw (task_id).next is
            when OS_TASK_ID_NONE => os_task_rw (task_id).next = OS_TASK_ID_NONE,
            when others => os_task_rw (Natural (os_task_rw (task_id).next)).prev = os_task_id_param_t (task_id)))
   with
      Ghost => true;

   function os_ghost_task_list_is_well_formed return Boolean
   with
      Ghost => true,
      Post =>
         --  task cannot have itself as next
         os_ghost_task_list_is_well_formed'Result =
                 os_ghost_task_next_is_not_self and then
         --  task cannot have itself as prev
         os_ghost_task_list_is_well_formed'Result =
                 os_ghost_task_prev_is_not_self and then
         --  task cannot be twice as next
         os_ghost_task_list_is_well_formed'Result =
                 os_ghost_task_is_not_twice_in_next and then
         --  task cannot be twice as prev
         os_ghost_task_list_is_well_formed'Result =
                 os_ghost_task_is_not_twice_in_prev and then
         --  task cannot have next and prev pointing to the same task
         os_ghost_task_list_is_well_formed'Result =
                 os_ghost_task_prev_and_next_different and then
         --  If a task has a next, then next task has the task as prev
         os_ghost_task_list_is_well_formed'Result =
                 os_ghost_task_link_is_bidirectionnal;
   pragma Annotate (GNATprove, Terminating, os_ghost_task_list_is_well_formed);

   function os_ghost_task_is_ready (task_id : os_task_id_param_t) return Boolean
   with
      Ghost => true,
      Pre => os_ghost_task_list_is_well_formed;

   function os_ghost_current_task_is_ready return Boolean
   with
      Ghost => true,
      Pre => os_ghost_task_list_is_well_formed;

   function os_ghost_mbx_is_present
                (task_id   : os_task_id_param_t;
                 mbx_index : os_mbx_index_t) return Boolean
   with
      Ghost => true,
      Post => true;

   function os_sched_get_current_task_id return os_task_id_param_t;
   pragma Export (C, os_sched_get_current_task_id, "os_sched_get_current_task_id");

   procedure os_sched_wait (task_id      : out os_task_id_param_t;
                            waiting_mask :     os_mbx_mask_t)
   with
      Pre => os_ghost_initialized and then
             os_ghost_task_list_is_well_formed and then
             os_ghost_current_task_is_ready,
      Post => os_ghost_initialized and then
              os_ghost_task_list_is_well_formed and then
              os_ghost_task_is_ready (task_id);
   pragma Export (C, os_sched_wait, "os_sched_wait");

   procedure os_sched_yield (task_id : out os_task_id_param_t)
   with
      Pre => os_ghost_initialized and then
             os_ghost_task_list_is_well_formed and then
             os_ghost_current_task_is_ready,
      Post => os_ghost_initialized and then
              os_ghost_task_list_is_well_formed and then
              os_ghost_task_is_ready (task_id);
   pragma Export (C, os_sched_yield, "os_sched_yield");

   procedure os_sched_exit (task_id : out os_task_id_param_t)
   with
      Pre => os_ghost_initialized and then
             os_ghost_task_list_is_well_formed and then
             os_ghost_current_task_is_ready,
      Post => os_ghost_initialized and then
              os_ghost_task_list_is_well_formed and then
              os_ghost_task_is_ready (task_id);
   pragma Export (C, os_sched_exit, "os_sched_exit");

   procedure os_init (task_id : out os_task_id_param_t)
   with
      Pre => os_ghost_initialized = false,
      Post => os_ghost_initialized and then
              os_ghost_task_list_is_well_formed and then
              os_ghost_task_is_ready (task_id);
   pragma Export (C, os_init, "os_init");

   procedure os_mbx_receive (status    : out os_status_t;
                             mbx_entry : out os_mbx_entry_t)
   with
      Pre => os_ghost_initialized and then
             os_ghost_task_list_is_well_formed and then
             os_ghost_current_task_is_ready,
      Post => os_ghost_initialized and then
              os_ghost_task_list_is_well_formed and then
              os_ghost_current_task_is_ready;
   pragma Export (C, os_mbx_receive, "os_mbx_receive");

   procedure os_mbx_send (status  : out os_status_t;
                          dest_id :     types.int8_t;
                          mbx_msg :     os_mbx_msg_t)
   with
      Pre => os_ghost_initialized and then
             os_ghost_task_list_is_well_formed and then
             os_ghost_current_task_is_ready,
      Post => os_ghost_initialized and then
              os_ghost_task_list_is_well_formed and then
              os_ghost_current_task_is_ready;
   pragma Export (C, os_mbx_send, "os_mbx_send");

   ---------------------
   -- os_task_current --
   ---------------------
   --  This variable holds the ID of the current elected task.

   os_task_current : os_task_id_param_t;

   -----------------------------
   -- os_task_ready_list_head --
   -----------------------------
   --  This variable holds the ID of the first task in the ready list (the next
   --  ne that will be elected). Note: Its value could be OS_TASK_ID_NONE if no
   --  task is ready.

   os_task_ready_list_head : os_task_id_t;

private

   procedure os_sched_schedule
                (task_id : out os_task_id_param_t)
   with
      Global => (In_Out => (os_task_ready_list_head, os_task_rw),
                 Output => os_task_current,
                 Input => os_task_ro),
      Pre => os_ghost_task_list_is_well_formed,
      Post => os_ghost_task_list_is_well_formed and then
              os_ghost_task_is_ready (task_id);

   function os_mbx_get_posted_mask
                (task_id : os_task_id_param_t) return os_mbx_mask_t
   with
      Global => (Input => os_task_rw);

   procedure os_mbx_send_one_task
                (status  : out os_status_t;
                 dest_id :     os_task_id_param_t;
                 mbx_msg :     os_mbx_msg_t)
   with
      Global => (In_Out => (os_task_ready_list_head, os_task_rw, os_task_current),
                 Input => os_task_ro),
      Pre => os_ghost_task_list_is_well_formed and then
             os_ghost_current_task_is_ready,
      Post => os_ghost_task_list_is_well_formed and then
              os_ghost_current_task_is_ready;

   procedure os_mbx_send_all_task
                (status  : out os_status_t;
                 mbx_msg :     os_mbx_msg_t)
   with
      Global => (In_Out => (os_task_ready_list_head, os_task_rw),
                 Output => os_task_current,
                 Input => os_task_ro),
      Pre => os_ghost_task_list_is_well_formed and then
             os_ghost_current_task_is_ready,
      Post => os_ghost_task_list_is_well_formed and then
              os_ghost_current_task_is_ready;

   function os_mbx_is_waiting_mbx_entry
                (task_id   : os_task_id_param_t;
                 mbx_index : os_mbx_index_t) return Boolean
   with
      Global => (Input => os_task_rw);

end os;
