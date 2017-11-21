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

#ifndef __MOTH_SPARC_LEON3_CONF_H_
#define __MOTH_SPARC_LEON3_CONF_H_

#define SPARC_RAM_ADDR 0x40000000 /**< RAM base adress */

#define SPARC_PROC_FREQ 50000000U /**< Processor frequency (in Hz) */

#define WINDOWS_NBR 8 /**< Number of register windows */

#define ASI_MMU_BYPASS 0x1c /* not sparc v8 compliant */

#define SPARC_PARTITION_BASE_VADDR                                             \
  0x0 /**< Partition virtual base adress. Should always be 0x0 */

#endif /* ! __MOTH_SPARC_LEON3_CONF_H_ */
