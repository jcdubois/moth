pragma Ada_2005;
pragma Style_Checks (Off);

with Interfaces.C; use Interfaces.C;
with Interfaces.C.Extensions;

package types is

   c_NULL : constant := (0);  --  kernel/core/include/types.h:45

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

   subtype uint8_t is unsigned_char;  -- kernel/core/include/types.h:32

   subtype uint16_t is unsigned_short;  -- kernel/core/include/types.h:33

   subtype uint32_t is unsigned;  -- kernel/core/include/types.h:34

   subtype uint64_t is Extensions.unsigned_long_long;  -- kernel/core/include/types.h:35

   subtype int8_t is signed_char;  -- kernel/core/include/types.h:37
   -- subtype int8_t is Integer;  -- kernel/core/include/types.h:37

   subtype int16_t is short;  -- kernel/core/include/types.h:38

   subtype int32_t is int;  -- kernel/core/include/types.h:39

   subtype int64_t is Long_Long_Integer;  -- kernel/core/include/types.h:40

   subtype size_t is unsigned;  -- kernel/core/include/types.h:42

   subtype intptr_t is unsigned_long;  -- kernel/core/include/types.h:43

end types;
