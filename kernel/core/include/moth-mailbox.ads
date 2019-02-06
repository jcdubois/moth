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
--  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.  --
--  @file
--  @author Jean-Christophe Dubois (jcd@tribudubois.net)
--  @brief
--

pragma Ada_2012;
pragma Style_Checks (Off);

package Moth.Mailbox with
   SPARK_mode     => on,
   Abstract_State => State,
   Initializes    => State
is

   ----------------
   -- Public API --
   ----------------

   ------------------
   -- Public types --
   ------------------

   OS_MBX_MSG_SZ        : constant := OpenConf.CONFIG_MBX_SIZE;

   type os_mbx_msg_t is range 0 .. 2 ** OS_MBX_MSG_SZ - 1;
   for os_mbx_msg_t'Size use OS_MBX_MSG_SZ;

   type os_mbx_entry_t is record
      sender_id        : os_task_id_t;
      msg              : os_mbx_msg_t;
   end record;
   pragma Convention (C_Pass_By_Copy, os_mbx_entry_t);

   ----------------------
   -- Public variables --
   ----------------------

   ---------------------------
   -- os_task_list_mbx_mask --
   ---------------------------

   os_task_list_mbx_mask : array (os_task_id_param_t) of os_mbx_mask_t;

   ---------------------
   -- Ghost functions --
   ---------------------

   function os_ghost_mbx_are_well_formed return Boolean
   with
      Ghost => true;

   function os_mbx_get_posted_mask
     (task_id : os_task_id_param_t) return os_mbx_mask_t
   with
      Pre => os_ghost_mbx_are_well_formed;

   ---------------------------------
   -- Moth public API for Mailbox --
   ---------------------------------

   -----------------
   -- mbx_receive --
   -----------------

   procedure receive (status    : out os_status_t;
                      mbx_entry : out os_mbx_entry_t)
   with
      Pre => os_ghost_mbx_are_well_formed and
             os_ghost_current_task_is_ready,
      Post => os_ghost_mbx_are_well_formed and
              os_ghost_current_task_is_ready;
   pragma Export (C, receive, "os_mbx_receive");

   --------------
   -- mbx_send --
   --------------

   procedure send (status  : out os_status_t;
                   dest_id :     types.int8_t;
                   mbx_msg :     os_mbx_msg_t)
   with
      Pre => os_ghost_task_list_is_well_formed and
             os_ghost_mbx_are_well_formed and
             os_ghost_current_task_is_ready,
      Post => os_ghost_task_list_is_well_formed and
              os_ghost_mbx_are_well_formed and
              os_ghost_current_task_is_ready;
   pragma Export (C, send, "os_mbx_send");

   -------------------------------
   -- Init function for Mailbox --
   -------------------------------

   procedure init
   with
      Global => (Output => os_task_list_mbx_mask,
                 In_Out => State),
      Post => os_ghost_mbx_are_well_formed;

end Moth.Mailbox;
