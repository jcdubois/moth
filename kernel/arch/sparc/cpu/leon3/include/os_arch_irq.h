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

#ifndef __MOTH_SPARC_LEON3_IRQ_H__
#define __MOTH_SPARC_LEON3_IRQ_H__

#define IRQMP_BASE        0x80000200   /**< Leon3 IRQMP IO adress */

#define IRQMP_LEVEL_OFFSET     0x00U   /**< Level register offset */
#define IRQMP_PENDING_OFFSET   0x04U   /**< Pending register offset */
#define IRQMP_CLEAR_OFFSET     0x0CU   /**< Clear register offset */
#define IRQMP_STATUS_OFFSET    0x10U   /**< Status register offset */
#define IRQMP_BROADCAST_OFFSET 0x14U   /**< Broadcast register offset */
#define IRQMP_MASK_OFFSET      0x40U   /**< Mask register offset */
#define IRQMP_FORCE_OFFSET     0x80U   /**< Force register offset */
#define IRQMP_EXTENDED_OFFSET  0xC0U   /**< Extended register offset */

#define IRQMP_IRQ_MASK 0x0000FFFE

#endif /* __MOTH_SPARC_LEON3_IRQ_H__ */
