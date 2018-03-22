pragma Ada_2012;
pragma Style_Checks (Off);
pragma SPARK_Mode;

with types;
with OpenConf;

package os is

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

   subtype os_task_id_param_t is types.int8_t;

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

   function os_sched_get_current_task_id return os_task_id_t;
   pragma Export (C, os_sched_get_current_task_id, "os_sched_get_current_task_id");

   function os_sched_wait (waiting_mask : os_mbx_mask_t) return os_task_id_t;
   pragma Export (C, os_sched_wait, "os_sched_wait");

   function os_sched_yield return os_task_id_t;
   pragma Export (C, os_sched_yield, "os_sched_yield");

   function os_sched_exit return os_task_id_t;
   pragma Export (C, os_sched_exit, "os_sched_exit");

   function os_init return os_task_id_t;
   pragma Export (C, os_init, "os_init");

   function os_mbx_receive (mbx_entry : out os_mbx_entry_t) return os_status_t;
   pragma Export (C, os_mbx_receive, "os_mbx_receive");

   function os_mbx_send (dest_id : os_task_id_param_t; mbx_msg : os_mbx_msg_t) return os_status_t;
   pragma Export (C, os_mbx_send, "os_mbx_send");

   os_task_ro : aliased array (0 .. OS_MAX_TASK_ID) of aliased os_task_ro_t;
   pragma Import (C, os_task_ro, "os_task_ro");

   os_task_rw : aliased array (0 .. OS_MAX_TASK_ID) of aliased os_task_rw_t;
   pragma Export (C, os_task_rw, "os_task_rw");

end os;
