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

#ifndef __OS_DEVICE_CONSOLE_FREESCALE_H__
#define __OS_DEVICE_CONSOLE_FREESCALE_H__

#define IMX21_UTS   0xb4        /* UART Test Register on all other i.mx */
#define URTX0 0x40              /* Transmitter Register */

#define UTS_FRCPERR     (1<<13) /* Force parity error */
#define UTS_LOOP        (1<<12) /* Loop tx and rx */
#define UTS_TXEMPTY     (1<<6) /* TxFIFO empty */
#define UTS_RXEMPTY     (1<<5) /* RxFIFO empty */
#define UTS_TXFULL      (1<<4) /* TxFIFO full */
#define UTS_RXFULL      (1<<3) /* RxFIFO full */
#define UTS_SOFTRST     (1<<0) /* Software reset */

#endif /* ! __OS_DEVICE_CONSOLE_FREESCALE_H__ */
