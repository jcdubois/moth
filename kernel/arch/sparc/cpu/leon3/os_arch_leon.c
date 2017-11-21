
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

/* function prototypes for this file */
#include <os_arch.h>

/* for os_arch_io_read32() */
#include "os_arch_ioports.h"

/* for IRQMP_XXX macros */
#include "os_arch_irq.h"

void os_arch_idle(void) {
  /* For LEON3 or LEON4 */
  asm volatile("wr %g0, %asr19");
}

uint8_t os_arch_interrupt_is_pending(void) {
  uint32_t pending_irq = os_arch_io_read32(IRQMP_BASE + IRQMP_PENDING_OFFSET);

  return (pending_irq & IRQMP_IRQ_MASK) ? 1 : 0;
}
