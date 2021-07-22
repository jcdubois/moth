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
 * @file
 * @author Jean-Christophe Dubois (jcd@tribudubois.net)
 * @brief
 */

/* for basic types */
#include <types.h>

/* for syslog() */
#include <syslog.h>

#include <arm_mmu.h>

/* for function prototypes for this file */
#include <os_arch.h>

#include <cpu_defines.h>

/**
 * Switch adress space in MMU (context register).
 */
void os_arch_space_switch(os_task_id_t old_context_id,
                          os_task_id_t new_context_id) {
  uint32_t *mmu_entry = os_arch_mmu_get_ctx_table();
  /* ignore old context id */
  (void)old_context_id;
  uint32_t contextidr = (new_context_id << 8) | (new_context_id & 0xff);
  uint32_t ttbr0 = mmu_entry[new_context_id] & ~0x0000003f;

  syslog("%s(task_id = %d)\n", __func__, (int)new_context_id);
  syslog("%s: ttbr0 = 0x%08x\n", __func__, ttbr0);
  syslog("%s: contextidr = 0x%08x\n", __func__, contextidr);

  asm volatile("mcr     p15, 0, %0, c2, c0, 0\n"
               "isb\n"
               "mcr     p15, 0, %1, c13, c0, 1\n"
               "isb\n"
               :
               : "r"(ttbr0), "r"(contextidr)
               :);
}

/**
 * Initilize MMU tables.
 */
void os_arch_space_init(void) {
  uint32_t temp;

  syslog("%s()\n", __func__);

  /*
   * This function is called with MMU disabled and physical = logical mapping.
   */

  /*
   * Call the os_arch_mmu_table_init() function to adjust the MMU table
   * as required.
   * Note: For ARM this is an empty function for now.
   */
  os_arch_mmu_table_init();

  syslog("%s: MMU table is fixed\n", __func__);

  // Set c3, Domain Access Control Register
  asm volatile("mov %0, #0x55\n" // Client for all domains
               "orr %0, %0, lsl #8\n"
               "orr %0, %0, lsl #16\n"
               "mcr p15, 0, %0, c3, c0, 0\n"
               : "=r"(temp)
               :
               :);

  // Set the MMU table register
  os_arch_space_switch(0, 0);

  syslog("%s: Switching to context 0 done\n", __func__);

  // Enable MMU, set flarg SCTLR_M_MASK at c1, the Control register
  asm volatile("mrc p15, 0, %0, c1, c0, 0\n"
               "orr %0, %0, %[flag]\n" // enabling MMU
               "mcr p15, 0, %0, c1, c0, 0\n"
               : "=r"(temp)
               : [ flag ] "I"(SCTLR_M_MASK)
               :);

  syslog("%s: MMU enabling done\n", __func__);
}
