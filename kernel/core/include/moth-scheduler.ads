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
--
--  @file moth-scheduler.ads
--  @author Jean-Christophe Dubois (jcd@tribudubois.net)
--  @brief Moth Scheduler subsystem
--

pragma Ada_2012;
pragma Style_Checks (Off);

with Moth.Config;

package Moth.Scheduler with
   SPARK_mode     => on,
   Abstract_State => State
is

   -------------------------------------
   -- Ghost variable for task's state --
   -------------------------------------

   os_ghost_task_list_ready : array (os_task_id_param_t) of Boolean with Ghost;

   ---------------------
   -- Ghost functions --
   ---------------------

   function os_ghost_task_list_is_well_formed return Boolean
   with
      Ghost => true;

   function os_ghost_current_task_is_ready return Boolean
   with 
      Ghost => true;

   function os_ghost_task_is_ready
                     (task_id : in os_task_id_param_t) return Boolean
   with
      Ghost => true;

   -------------------------------------
   -- Function needed in Moth.Mailbox --
   -------------------------------------

   procedure add_task_to_ready_list (task_id : in os_task_id_param_t)
   with
      Global => (In_Out => (State,
                            os_ghost_task_list_ready),
                 Input  => (Moth.Config.State)),
      Pre => os_ghost_task_list_is_well_formed,
      Post => os_ghost_task_list_ready =
                 os_ghost_task_list_ready'Old'Update (task_id => true) and then
              os_ghost_task_list_is_well_formed;

   -----------------------------------
   -- Moth public API for scheduler --
   -----------------------------------

   ----------
   -- wait --
   ----------

   procedure wait (task_id      : out os_task_id_param_t;
                   waiting_mask :     os_mbx_mask_t)
   with
      Pre => os_ghost_task_list_is_well_formed and
             os_ghost_mbx_are_well_formed and
             os_ghost_current_task_is_ready,
      Post => os_ghost_task_list_is_well_formed and
              os_ghost_task_is_ready (task_id);
   pragma Export (C, wait, "os_sched_wait");

   -----------
   -- yield --
   -----------

   procedure yield (task_id : out os_task_id_param_t)
   with
      Pre => os_ghost_task_list_is_well_formed and
             os_ghost_current_task_is_ready,
      Post => os_ghost_task_list_is_well_formed and
              os_ghost_task_is_ready (task_id);
   pragma Export (C, yield, "os_sched_yield");

   ----------
   -- fin --
   ----------

   procedure fin (task_id : out os_task_id_param_t)
   with
      Pre => os_ghost_task_list_is_well_formed and
             os_ghost_current_task_is_ready,
      Post => os_ghost_task_list_is_well_formed and
              os_ghost_task_is_ready (task_id);
   pragma Export (C, fin, "os_sched_exit");

   ---------------------------------
   -- Init function for scheduler --
   ---------------------------------

   procedure init (task_id : out os_task_id_param_t)
   with
      post => os_ghost_task_list_is_well_formed and
              os_ghost_task_is_ready (task_id);

end Moth.Scheduler;
