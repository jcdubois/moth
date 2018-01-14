/**
 * Copyright (c) 2017 Jean-Christophe Dubois
 * All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 * @file thread.c
 * @author Jean-Christophe Dubois (jcd@tribudubois.net)
 * @brief
 */

/* for syslog() */
#include <syslog.h>

/* for memset() */
#include <string.h>

/* for various register offset in stack */
#include <sparc_context_offset.h>

/* function prototype for this file */
#include <os_arch_context.h>

/* for os_task_rX[] */
#include <os.h>

#include <os_arch.h>

/**
 *
 */
void os_arch_context_create(os_task_id_t task_id) {
  char *ctx = (char *)os_task_ro[task_id].stack.virtual_address +
              os_task_ro[task_id].stack.size - 0x40;

  syslog("%s( task_id = %d )\n", __func__, (int)task_id);

  if (!os_task_ro[task_id].stack.size || !os_task_ro[task_id].bss.size ||
      !os_task_ro[task_id].text.size) {
    printf("%s: task %d has incorrect size for .text, .bss or .stack segment\n",
           __func__, (int)task_id);
    while (1) {
      os_arch_idle();
    }
  }

  memset((void *)os_task_ro[task_id].stack.virtual_address, 0,
         os_task_ro[task_id].stack.size);
  memset((void *)os_task_ro[task_id].bss.virtual_address, 0,
         os_task_ro[task_id].bss.size);

  /* Only 1 register window needed */
  *(uint32_t *)(ctx - RESTORE_CNT_OFFSET) = 1;
  *(uint32_t *)(ctx - PC_OFFSET) = os_task_ro[task_id].text.virtual_address;
  *(uint32_t *)(ctx - NPC_OFFSET) =
      os_task_ro[task_id].text.virtual_address + 4;
  *(uint32_t *)(ctx - I0_OFFSET) = (uint32_t)task_id;
  ;

  os_task_rw[task_id].stack_pointer = (uint32_t)ctx;
}

/**
 * Global variable for context switch in SPARC.
 * @see os_arch_context_switch()
 */
uint32_t os_arch_stack_pointer;

/**
 * Save interrupted stack pointer and set
 * stack pointer for the next context.
 * @see os_arch_stack_pointer
 */
void os_arch_context_switch(os_task_id_t prev_id, os_task_id_t next_id) {
  syslog("%s( task_id = %d )\n", __func__, (int)next_id);
  os_task_rw[prev_id].stack_pointer = os_arch_stack_pointer;
  os_arch_stack_pointer = os_task_rw[next_id].stack_pointer;
}

void os_arch_context_set(os_task_id_t task_id) {
  syslog("%s( task_id = %d )\n", __func__, (int)task_id);
  os_arch_stack_pointer = os_task_rw[task_id].stack_pointer;
}
