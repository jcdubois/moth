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
 * @file yield.c
 * @author Jean-Christophe Dubois (jcd@tribudubois.net)
 * @brief yield system call
 */

#include <moth.h>

__attribute__((section(".text.entry"))) void entry(uint32_t task_id);

static os_task_id_t __os_task_id;

void exit(int reason) {
  (void)reason;

  asm volatile("ta 0x04\n"
               "nop\n"
               :
               :
               : "memory");
}

void entry(uint32_t task_id) {

  __os_task_id = (os_task_id_t)task_id;

  exit(main(0, NULL, NULL));
}

os_task_id_t getpid(void) { return __os_task_id; }
