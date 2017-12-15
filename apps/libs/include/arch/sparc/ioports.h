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

#ifndef __MOTH_SPARC_APPS_IOPORTS_H__
#define __MOTH_SPARC_APPS_IOPORTS_H__

#include <types.h>

#ifdef __cplusplus
extern "C"
{
#endif

static inline void io_write8(uint32_t addr, uint8_t data) {
  asm volatile("stb %0, [%1];\n"
               : /* no output */
               : "r"(data), "r"(addr)
               : "memory");
}

static inline void io_write32(uint32_t addr, uint32_t data) {
  asm volatile("st %0, [%1];\n"
               : /* no output */
               : "r"(data), "r"(addr)
               : "memory");
}

static inline uint8_t io_read8(uint32_t addr) {
  uint8_t value = 0;

  asm volatile("ldub [%1], %0;\n"
               : "=r"(value)
               : "r"(addr)
               : "memory");
  return value;
}

static inline uint32_t io_read32(uint32_t addr) {
  uint32_t value = 0;

  asm volatile("ld [%1], %0;\n"
               : "=r"(value)
               : "r"(addr)
               : "memory");
  return value;
}

#ifdef __cplusplus
}
#endif

#endif /* __MOTH_SPARC_APPS_IOPORTS_H__ */
