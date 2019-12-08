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
#include <os_device_console_freescale.h>

/* for init_prinf() */
#include <stdio.h>

#include <os_arch_ioports.h>

static void os_arch_cons_write_char(void *uart, char a) {
  /* Wait until FIFO is full */
  while (os_arch_io_read32((uint32_t)uart + IMX21_UTS) & UTS_TXFULL)
    ;

  /* Send the character */
  os_arch_io_write32((uint32_t)uart + URTX0, (uint32_t)a);

  /* Wait until FIFO is empty */
  while (!(os_arch_io_read32((uint32_t)uart + IMX21_UTS) & UTS_TXEMPTY))
    ;
}

/**
 * UART initialization.
 */
void os_arch_cons_init(void) {
  init_printf((void *)CONFIG_FREESCALE_UART_ADDR, os_arch_cons_write_char);
}
