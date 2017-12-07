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
 * @file mbx_send.c
 * @author Jean-Christophe Dubois (jcd@tribudubois.net)
 * @brief mbx_send system call
 */

#include <moth.h>

extern os_mbx_entry_t __mbx_entry;

os_status_t mbx_send(os_task_id_t dest_id, os_mbx_msg_t msg) {
  os_status_t status;

  __mbx_entry.sender_id = dest_id;
  __mbx_entry.msg = msg;

  asm volatile("ta 0x02\n"
               "nop\n"
               : "=r"(status)
               :
               : "memory");

  return status;
}
