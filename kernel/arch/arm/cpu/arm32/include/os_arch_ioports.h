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

#ifndef __MOTH_SPARC_LEON3_IOPORTS_H__
#define __MOTH_SPARC_LEON3_IOPORTS_H__

#include <types.h>

#ifdef __cplusplus
extern "C" {
#endif

#define ASI_MMU_BYPASS 0x1c /* not sparc v8 compliant */

static inline void os_arch_io_write8(uint32_t addr, uint8_t data) {
  *(volatile uint8_t *)addr = data;
}

static inline void os_arch_io_write32(uint32_t addr, uint32_t data) {
  *(volatile uint32_t *)addr = data;
}

static inline uint8_t os_arch_io_read8(uint32_t addr) {
  return *(volatile uint8_t *)addr;
}

static inline uint32_t os_arch_io_read32(uint32_t addr) {
  return *(volatile uint32_t *)addr;
}

#ifdef __cplusplus
}
#endif

#endif /* __MOTH_SPARC_LEON3_IOPORTS_H__ */
