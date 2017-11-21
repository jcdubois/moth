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

#ifndef __MOTH_SPARC_PSR_H__
#define __MOTH_SPARC_PSR_H__

#include "sparc_psr_reg.h"

static inline unsigned int psr_get(void) {
  unsigned int psr;
  asm volatile("rd %%psr, %0\n"
               : "=r"(psr)
               : /* no inputs */
               : "memory");

  return psr;
}

static inline void psr_set(unsigned int new_psr) {
  asm volatile("wr %0, 0x0, %%psr\n"
               "nop\n"
               "nop\n"
               "nop\n"
               : /* no outputs */
               : "r"(new_psr)
               : "memory", "cc");
}

static inline void psr_enable_traps(void) {
  psr_set(psr_get() | PSR_ET);
}

static inline void psr_disable_traps(void) {
  psr_set(psr_get() & ~PSR_ET);
}

static inline void psr_disable_interupt(void) {
  psr_set(psr_get() | PSR_PIL_MASK);
}

static inline void psr_enable_interupt(void) {
  psr_set(psr_get() & ~PSR_PIL_MASK);
}

#endif /* __MOTH_SPARC_PSR_H__ */
