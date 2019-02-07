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
--  @file moth-current.adb
--  @author Jean-Christophe Dubois (jcd@tribudubois.net)
--  @brief Moth current task id
--

package body Moth.Current with
   Spark_Mode     => On,
   Refined_State => (State  => (os_task_current))
is
   ---------------------
   -- os_task_current --
   ---------------------

   os_task_current : os_task_id_param_t;

   ----------------------------------------------------
   -- Set the id of the current running/elected task --
   ----------------------------------------------------

   procedure set_current_task_id (task_id : os_task_id_param_t) is
   begin
      os_task_current := task_id;
   end set_current_task_id;

   -------------------------
   -- get_Current_id --
   -------------------------

   function get_current_task_id return os_task_id_param_t is
      (os_task_current);

begin
   os_task_current := OS_TASK_ID_MIN;
end Moth.Current;
