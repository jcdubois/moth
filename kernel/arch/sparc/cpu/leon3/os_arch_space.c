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

/* for MMU_xxx macros */
#include <sparc_mmu.h>

/* for function prototypes for this file */
#include <os_arch.h>

/**
 * Switch adress space in MMU (context register).
 */
void os_arch_space_switch(os_task_id_t old_context_id,
                          os_task_id_t new_context_id) {
  /* ignore old context id */
  (void)old_context_id;

  syslog("%s( task_id = %d )\n", __func__, (int)new_context_id);

  asm volatile("sta %0, [%1] %2;\n"
               : /* no output */
               : "r"(new_context_id), "r"(MMU_CTX_REG), "i"(ASI_M_MMUREGS)
               : "memory");
}

/**
 * Initilize MMU tables.
 */
void os_arch_space_init(void) {

  syslog("%s\n", __func__);

  /*
   * This function is called with MMU disabled and physical = logical mapping.
   */

  /*
   * Call the os_arch_mmu_table_init() function to adjust the MMU table
   * as required.
   */
  os_arch_mmu_table_init();

  /*
   * flush all memory before enabling MMU
   */
  asm volatile("flush\n"
               "nop\n"
               "nop\n"
               "nop\n"
               "nop\n"
               "nop;\n"
               :
               :
               : "memory");

  syslog("%s: MMU table is fixed\n", __func__);

  /* set context table (context table register) */
  asm volatile("sta %0, [%1] %2;\n"
               : /* no output */
               : "r"(os_arch_mmu_get_ctx_table() >> 4), "r"(MMU_CTXTBL_PTR),
                 "i"(ASI_M_MMUREGS)
               : "memory");

  syslog("%s: CTR is set\n", __func__);

  /*
   * Set context number. We switch to context 0 which is as good as any
   * other one (and it should exist) as they should all map the kernel
   * the same way (which is our present mode)..
   */
  os_arch_space_switch(0, 0);

  syslog("%s: Switching to context 0 done\n", __func__);

  /* Enable the MMU (control register) */
  asm volatile("sta %0, [%1] %2;\n"
               : /* no output */
               : "r"(MMU_CTRL_REG_ENABLE), "r"(MMU_CTRL_REG), "i"(ASI_M_MMUREGS)
               : "memory");

  syslog("%s: MMU enabling done\n", __func__);

  /*
   * From there we are in virtual memmory mode. It just so happen that for
   * The kernel we are in identity mapping (logical = physical).
   */

  /*
   * Note: From here the MMU table is protected from any modification as the
   * activated MMU table is disabling access to the MMU table through
   * virtual memory.
   */

  syslog("%s: ctx nbr=%u\n", __func__, CONFIG_MAX_TASK_COUNT);
}
