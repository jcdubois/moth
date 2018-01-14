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

#ifndef __OS_DEVICE_CONSOLE_GRLIB_H__
#define __OS_DEVICE_CONSOLE_GRLIB_H__

#define UART_STATUS_DR 0x00000001  /**< Data Ready */
#define UART_STATUS_TSE 0x00000002 /**< TX Send Register Empty */
#define UART_STATUS_THE 0x00000004 /**< TX Hold Register Empty */
#define UART_STATUS_BR 0x00000008  /**< Break Error */
#define UART_STATUS_OE 0x00000010  /**< RX Overrun Error */
#define UART_STATUS_PE 0x00000020  /**< RX Parity Error */
#define UART_STATUS_FE 0x00000040  /**< RX Framing Error */
#define UART_STATUS_ERR 0x00000078 /**< Error Mask */

#define UART_CTRL_RE 0x00000001 /**< Receiver enable */
#define UART_CTRL_TE 0x00000002 /**< Transmitter enable */
#define UART_CTRL_RI 0x00000004 /**< Receiver interrupt enable */
#define UART_CTRL_TI 0x00000008 /**< Transmitter interrupt enable */
#define UART_CTRL_PS 0x00000010 /**< Parity select */
#define UART_CTRL_PE 0x00000020 /**< Parity enable */
#define UART_CTRL_FL 0x00000040 /**< Flow control enable */
#define UART_CTRL_LB 0x00000080 /**< Loop Back enable */

#define UART_DATA_OFFSET 0x0   /**< Data register offset */
#define UART_STAT_OFFSET 0x4   /**< Stat register offset */
#define UART_CTRL_OFFSET 0x8   /**< Control register offset */
#define UART_SCALER_OFFSET 0xc /**< Scaler register offset */

#endif /* ! __OS_DEVICE_CONSOLE_GRLIB_H__ */
