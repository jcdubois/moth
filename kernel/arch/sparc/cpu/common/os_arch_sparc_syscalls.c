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
 * @file syscalls.c
 * @author Jean-Christophe Dubois (jcd@tribudubois.net)
 * @brief source file arch part of MOTH syscalls
 */

#include <os_arch.h>

/* for syslog() */
#include <syslog.h>

/* For various register offset in stack */
#include <sparc_context_offset.h>

/* for os_arch_context_switch() */
#include <os_arch_context.h>

# define SPARC_TRAP_SYSCALL_BASE	0x80

/**
 * Syscalls handlers.
 */

/**
 * Wait function handler.
 */
static void os_arch_sched_wait(void) {
  uint8_t *ctx = (uint8_t *)os_arch_stack_pointer;
  os_task_id_t current_task_id;
  os_task_id_t new_task_id;
  os_mbx_mask_t mbx_mask = (os_mbx_mask_t)(*(uint32_t *)(ctx - I0_OFFSET));

  syslog("%s: \n", __func__);

  current_task_id = os_sched_get_current_task_id();
  new_task_id = os_sched_wait(mbx_mask);

  *(uint32_t *)(ctx - I0_OFFSET) = OS_SUCCESS;
  *(uint32_t *)(ctx - PC_OFFSET) += 4; // skip "ta" instruction
  *(uint32_t *)(ctx - NPC_OFFSET) += 4;

  if (current_task_id != new_task_id) {
    os_arch_space_switch(current_task_id, new_task_id);
    os_arch_context_switch(current_task_id, new_task_id);
  }
}

/**
 * Yield function handler.
 * Release the processor and give another task the opportunity to run.
 */
static void os_arch_sched_yield(void) {
  uint8_t *ctx = (uint8_t *)os_arch_stack_pointer;
  os_task_id_t current_task_id;
  os_task_id_t new_task_id;

  syslog("%s: \n", __func__);

  current_task_id = os_sched_get_current_task_id();
  new_task_id = os_sched_yield();

  *(uint32_t *)(ctx - I0_OFFSET) = OS_SUCCESS;
  *(uint32_t *)(ctx - PC_OFFSET) += 4; // skip "ta" instruction
  *(uint32_t *)(ctx - NPC_OFFSET) += 4;

  if (current_task_id != new_task_id) {
    os_arch_space_switch(current_task_id, new_task_id);
    os_arch_context_switch(current_task_id, new_task_id);
  }
}

/**
 * Mailbox receive function handler.
 * We get the arguments from the stack and we call the os_mbx_receive function.
 */
static void os_arch_mbx_receive(void) {
  uint8_t *ctx = (uint8_t *)os_arch_stack_pointer;
  os_status_t status;
  os_mbx_entry_t *entry =
      (os_mbx_entry_t *)os_task_ro[os_sched_get_current_task_id()]
          .bss.virtual_address;

  syslog("%s: \n", __func__);

  status = os_mbx_receive(entry);

  *(uint32_t *)(ctx - I0_OFFSET) = (uint32_t)status;
  *(uint32_t *)(ctx - PC_OFFSET) += 4; // skip "ta" instruction
  *(uint32_t *)(ctx - NPC_OFFSET) += 4;
}

/**
 * Mailbox send function handler.
 * We get the arguments from the stack and we call the os_mbx_send function.
 */
static void os_arch_mbx_send(void) {
  uint8_t *ctx = (uint8_t *)os_arch_stack_pointer;
  os_status_t status;
  os_mbx_entry_t *entry =
      (os_mbx_entry_t *)os_task_ro[os_sched_get_current_task_id()]
          .bss.virtual_address;

  syslog("%s: \n", __func__);

  status = os_mbx_send(entry->sender_id, entry->msg);

  *(uint32_t *)(ctx - I0_OFFSET) = (uint32_t)status;
  *(uint32_t *)(ctx - PC_OFFSET) += 4; // skip "ta" instruction
  *(uint32_t *)(ctx - NPC_OFFSET) += 4;
}

/**
 * Exit function handler.
 * Handle the case when a task ends.
 */
static void os_arch_sched_exit(void) {
  os_task_id_t current_task_id;
  os_task_id_t new_task_id;

  syslog("%s: \n", __func__);

  current_task_id = os_sched_get_current_task_id();
  new_task_id = os_sched_exit();

  os_arch_context_create(current_task_id);

  if (current_task_id != new_task_id) {
    os_arch_space_switch(current_task_id, new_task_id);
    os_arch_context_switch(current_task_id, new_task_id);
  }
}

/**
 * Function called by interrupt pre-handler.
 * Call the correct handler for the given trap number.
 * @param trap_nb The number of the current trap. (cf SPARC V8 Manual, page 76)
 * @param stack_pointer Adress of the interrupted stack.
 * @see os_arch_stack_pointer
 */
void os_arch_trap_handler(uint32_t pc, uint32_t npc, uint32_t psr,
                          uint32_t trap_nb, uint32_t restore_counter,
                          uint32_t stack_pointer) {
  (void)restore_counter;
  (void)pc;
  (void)npc;
  (void)psr;

  os_arch_stack_pointer = stack_pointer;

  switch (trap_nb) {
  case (SPARC_TRAP_SYSCALL_BASE + 0):
    os_arch_sched_wait();
    break;
  case (SPARC_TRAP_SYSCALL_BASE + 1):
    os_arch_sched_yield();
    break;
  case (SPARC_TRAP_SYSCALL_BASE + 2):
    os_arch_mbx_send();
    break;
  case (SPARC_TRAP_SYSCALL_BASE + 3):
    os_arch_mbx_receive();
    break;
  case (SPARC_TRAP_SYSCALL_BASE + 4):
    os_arch_sched_exit();
    break;
  default:
    printf("[KERNEL] [ERROR] Unhandled trap: 0x%x %%PSR=%x %%PC=%x %%nPC=%x "
           "%%sp=0x%x\n",
           trap_nb, psr, pc, npc, stack_pointer);
    printf("%%psr : impl:0x%x ver:%x nzvc:%u%u%u%u EC:%u EF:%u PIL:0x%x S:%u "
           "PS:%u ET:%u CWP:%u\n\r",
           (psr >> 28) & 0xF, (psr >> 24) & 0xF, (psr >> 23) & 0x1,
           (psr >> 22) & 0x1c, (psr >> 21) & 0x1, (psr >> 20) & 0x1,
           (psr >> 23) & 0x1, (psr >> 12) & 0x1, (psr >> 8) & 0xF,
           (psr >> 7) & 0x1, (psr >> 6) & 0x1, (psr >> 5) & 0x1, psr & 0xF);
    // infinite loop
    while (1) {
      os_arch_idle();
    }
    break;
  }
}
