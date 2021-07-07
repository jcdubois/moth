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

#define SPARC_TRAP_SYSCALL_BASE 0x80

/**
 * Syscalls handlers.
 */

uint32_t *os_arch_init(void) {
  os_task_id_t task_id;
  os_init(&task_id);
  return os_arch_context_restore(task_id);
}

/**
 * Wait function handler.
 */
static uint32_t *os_arch_sched_wait(uint32_t *ctx) {
  os_task_id_t current_task_id;
  os_task_id_t new_task_id;
  os_mbx_mask_t mbx_mask = (os_mbx_mask_t)(*(ctx - I0_OFFSET/4));

  syslog("%s: \n", __func__);

  current_task_id = os_sched_get_current_task_id();
  os_sched_wait(&new_task_id, mbx_mask);

  *(ctx - I0_OFFSET/4) = OS_SUCCESS;
  *(ctx - PC_OFFSET/4) += 4; // skip "ta" instruction
  *(ctx - NPC_OFFSET/4) += 4;

  if (current_task_id != new_task_id) {
    os_arch_context_save(current_task_id, ctx);
    os_arch_space_switch(current_task_id, new_task_id);
    ctx = os_arch_context_restore(new_task_id);
  }

  return ctx;
}

/**
 * Yield function handler.
 * Release the processor and give another task the opportunity to run.
 */
static uint32_t *os_arch_sched_yield(uint32_t *ctx) {
  os_task_id_t current_task_id;
  os_task_id_t new_task_id;

  syslog("%s: \n", __func__);

  current_task_id = os_sched_get_current_task_id();
  os_sched_yield(&new_task_id);

  *(ctx - I0_OFFSET/4) = OS_SUCCESS;
  *(ctx - PC_OFFSET/4) += 4; // skip "ta" instruction
  *(ctx - NPC_OFFSET/4) += 4;

  if (current_task_id != new_task_id) {
    os_arch_context_save(current_task_id, ctx);
    os_arch_space_switch(current_task_id, new_task_id);
    ctx = os_arch_context_restore(new_task_id);
  }

  return ctx;
}

/**
 * Mailbox receive function handler.
 * We get the arguments from the stack and we call the os_mbx_receive function.
 */
static uint32_t *os_arch_mbx_receive(uint32_t *ctx) {
  os_status_t status;
  os_mbx_entry_t *entry =
      (os_mbx_entry_t *)os_task_ro[os_sched_get_current_task_id()]
          .bss.virtual_address;

  syslog("%s: \n", __func__);

  /* cleanup the MBX before receiving it */
  entry->sender_id = OS_TASK_ID_NONE;
  entry->msg = 0;

  os_mbx_receive(&status, entry);

  *(ctx - I0_OFFSET/4) = (uint32_t)status;
  *(ctx - PC_OFFSET/4) += 4; // skip "ta" instruction
  *(ctx - NPC_OFFSET/4) += 4;

  return ctx;
}

/**
 * Mailbox send function handler.
 * We get the arguments from the stack and we call the os_mbx_send function.
 */
static uint32_t *os_arch_mbx_send(uint32_t *ctx) {
  os_status_t status;
  os_mbx_entry_t *entry =
      (os_mbx_entry_t *)os_task_ro[os_sched_get_current_task_id()]
          .bss.virtual_address;

  syslog("%s: \n", __func__);

  os_mbx_send(&status, entry->sender_id, entry->msg);

  /* cleanup the MBX after sending it */
  entry->sender_id = OS_TASK_ID_NONE;
  entry->msg = 0;

  *(ctx - I0_OFFSET/4) = (uint32_t)status;
  *(ctx - PC_OFFSET/4) += 4; // skip "ta" instruction
  *(ctx - NPC_OFFSET/4) += 4;

  return ctx;
}

/**
 * Exit function handler.
 * Handle the case when a task ends.
 */
static uint32_t *os_arch_sched_exit(uint32_t *ctx) {
  os_task_id_t current_task_id;
  os_task_id_t new_task_id;

  syslog("%s: \n", __func__);

  current_task_id = os_sched_get_current_task_id();
  os_sched_exit(&new_task_id);

  os_arch_context_create(current_task_id);

  if (current_task_id != new_task_id) {
    os_arch_context_save(current_task_id, ctx);
    os_arch_space_switch(current_task_id, new_task_id);
    ctx = os_arch_context_restore(new_task_id);
  } 

  return ctx;
}

/**
 * Function called by interrupt pre-handler.
 * Call the correct handler for the given trap number.
 * @param trap_nb The number of the current trap. (cf SPARC V8 Manual, page 76)
 * @param stack_pointer Adress of the interrupted stack.
 */
uint32_t *os_arch_trap_handler(uint32_t *pc, uint32_t *npc, uint32_t psr,
                               uint32_t trap_nb, uint32_t restore_counter,
                               uint32_t *stack_pointer) {
  (void)restore_counter;
  (void)pc;
  (void)npc;
  (void)psr;

  switch (trap_nb) {
  case (SPARC_TRAP_SYSCALL_BASE + 0):
    return os_arch_sched_wait(stack_pointer);
    break;
  case (SPARC_TRAP_SYSCALL_BASE + 1):
    return os_arch_sched_yield(stack_pointer);
    break;
  case (SPARC_TRAP_SYSCALL_BASE + 2):
    return os_arch_mbx_send(stack_pointer);
    break;
  case (SPARC_TRAP_SYSCALL_BASE + 3):
    return os_arch_mbx_receive(stack_pointer);
    break;
  case (SPARC_TRAP_SYSCALL_BASE + 4):
    return os_arch_sched_exit(stack_pointer);
    break;
  default:
    printf("[KERNEL] [ERROR] Unhandled trap: 0x%x %%PSR=%x %%PC=%p %%nPC=%p "
           "%%sp=0x%p\n",
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

/**
 * Function called by asm error handler.
 * @param trap_nb The number of the current trap. (cf SPARC V8 Manual, page 76)
 * @param stack_pointer Adress of the interrupted stack.
 */
uint32_t *os_arch_error_handler(uint32_t *pc, uint32_t *npc, uint32_t psr,
                                uint32_t trap_nb, uint32_t restore_counter,
                                uint32_t *stack_pointer) {
  (void)restore_counter;
  (void)pc;
  (void)npc;
  (void)psr;

  printf("[KERNEL] [ERROR] Unhandled trap: 0x%x %%PSR=%x %%PC=%p %%nPC=%p "
         "%%sp=0x%p\n",
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
}
