/**
 * Copyright (c) 2017 Jean-Christophe Dubois
 * All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 * @file wait.c
 * @author Jean-Christophe Dubois (jcd@tribudubois.net)
 * @brief wait system call
 */

#include <moth.h>

os_status_t wait(os_mbx_mask_t mask) {
  os_status_t status;
  (void)mask;

  asm volatile("ta 0x00\n"
               "nop\n"
               : "=r"(status)
               :
               : "memory");

  return status;
}
