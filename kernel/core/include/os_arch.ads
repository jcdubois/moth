pragma Ada_2012;
pragma Style_Checks (Off);

with Interfaces.C; use Interfaces.C;
with types;
with os;

package os_arch is

  --*
  -- * Copyright (c) 2017 Jean-Christophe Dubois
  -- * All rights reserved.
  -- *
  -- * This program is free software; you can redistribute it and/or modify
  -- * it under the terms of the GNU General Public License as published by
  -- * the Free Software Foundation; either version 2, or (at your option)
  -- * any later version.
  -- *
  -- * This program is distributed in the hope that it will be useful,
  -- * but WITHOUT ANY WARRANTY; without even the implied warranty of
  -- * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  -- * GNU General Public License for more details.
  -- *
  -- * You should have received a copy of the GNU General Public License
  -- * along with this program; if not, write to the Free Software
  -- * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
  -- *
  -- * @file
  -- * @author Jean-Christophe Dubois (jcd@tribudubois.net)
  -- * @brief
  --  

   function os_arch_interrupt_is_pending return boolean;  -- kernel/core/include/os_arch.h:34
   pragma Import (C, os_arch_interrupt_is_pending, "os_arch_interrupt_is_pending");

   procedure os_arch_idle;  -- kernel/core/include/os_arch.h:36
   pragma Import (C, os_arch_idle, "os_arch_idle");

   procedure os_arch_context_create (task_id : os.os_task_id_t);  -- kernel/core/include/os_arch.h:38
   pragma Import (C, os_arch_context_create, "os_arch_context_create");

   procedure os_arch_context_switch (prev_id : os.os_task_id_t; next_id : os.os_task_id_t);  -- kernel/core/include/os_arch.h:40
   pragma Import (C, os_arch_context_switch, "os_arch_context_switch");

   procedure os_arch_context_set (task_id : os.os_task_id_t);  -- kernel/core/include/os_arch.h:42
   pragma Import (C, os_arch_context_set, "os_arch_context_set");

   procedure os_arch_space_init;  -- kernel/core/include/os_arch.h:44
   pragma Import (C, os_arch_space_init, "os_arch_space_init");

   procedure os_arch_space_switch (old_context_id : os.os_task_id_t; new_context_id : os.os_task_id_t);  -- kernel/core/include/os_arch.h:46
   pragma Import (C, os_arch_space_switch, "os_arch_space_switch");

   procedure os_arch_cons_init;  -- kernel/core/include/os_arch.h:49
   pragma Import (C, os_arch_cons_init, "os_arch_cons_init");

end os_arch;
