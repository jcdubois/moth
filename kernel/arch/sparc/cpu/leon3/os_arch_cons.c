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

/* for function prototypes for this file */
#include <os_arch_cons.h>

/* for os_arch_io_writeX() */
#include <os_arch_ioports.h>

#if defined(CONFIG_VERBOSE_MODE)

/* for openlog() */
#include <syslog.h>

static void os_arch_cons_write_char(void *opaque, char a) {
  while ((os_arch_io_read32(UART1 + UART_STAT_OFFSET) & UART_STATUS_THE) == 0) {
    continue;
  }

  os_arch_io_write8(UART1 + UART_DATA_OFFSET, (uint8_t)a);
}

/**
 * UART initialization.
 * Keep default baud rate value (38400).
 */
void os_arch_cons_init(void) {
  /* Initialize port */
  os_arch_io_write32(UART1 + UART_CTRL_OFFSET,
                     UART_CTRL_TE); /* transmit enable */

  /* Initialize log framework */
  openlog(os_arch_cons_write_char);
}

#else  // CONFIG_VERBOSE_MODE
void os_arch_cons_init(void) {}
#endif // CONFIG_VERBOSE_MODE
