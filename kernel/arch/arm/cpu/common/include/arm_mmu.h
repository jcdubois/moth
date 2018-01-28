/**
 * Copyright (c) 2018 Jean-Christophe Dubois
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

#ifndef __MOTH_ARM_MMU_H__
#define __MOTH_ARM_MMU_H__

#include <types.h>

#ifdef __cplusplus
extern "C"
{
#endif

/**
 * @{
 * @name Level 1 PTD field
 */
#define MM_LVL1_INVALID        0x0 /**< Invalid */
#define MM_LVL1_TABLE          0x1 /**< Page Table Descriptor */
#define MM_LVL1_SECTION        0x2 /**< Section Entry */
#define MM_LVL1_TABLE_PXN      (1 << 2)
#define MM_LVL1_TABLE_PX       (0 << 2)
#define MM_LVL1_TABLE_NS       (1 << 3)
#define MM_LVL1_TABLE_S        (0 << 3)
/** @} */

/**
 * @{
 * @name LVL2 entry descriptor field
 */
/** @} */

/**
 * @{
 * @name Level 2 PTE fields
*/
#define MM_LVL2_INVALID        0x0 /**< Invalid */
#define MM_LVL2_SMALL          0x1 /**< Small page Descriptor */
#define MM_LVL2_LARGE          0x2 /**< Large page Descriptor */
#define MM_LVL2_SMALL_XN       (1 << 0)
#define MM_LVL2_SMALL_X        (0 << 0)
#define MM_LVL2_BUFFERABLE     (1 << 2)
#define MM_LVL2_NON_BUFFERABLE (0 << 2)
#define MM_LVL2_CACHEABLE      (1 << 3)
#define MM_LVL2_NOCACHE        (0 << 3)
#define MM_LVL2_AP_USER_ACCESS (1 << 5)
#define MM_LVL2_AP_SUP_ACCESS  (0 << 5)
#define MM_LVL2_AP_RO          (1 << 9)
#define MM_LVL2_AP_RW          (0 << 9)
#define MM_LVL2_SHARABLE       (1 << 10)
#define MM_LVL2_NON_SHARABLE   (0 << 10)
#define MM_LVL2_NON_GLOBAL     (1 << 11)
#define MM_LVL2_GLOBAL         (0 << 11)
#define MM_LVL2_LARGE_XN       (1 << 15)
#define MM_LVL2_LARGE_X        (0 << 15)
/** @} */

/**
 * @{
 * @name MMU levels utils
 */

#define MM_LVL2_ENTRIES_NBR 256 /**< Number of entries in 2nd level table */
#define MM_LVL2_PAGE_SIZE   (4 * 1024) /**< 4 KiloBytes */

#define MM_LVL1_ENTRIES_NBR 4096 /**< Number of entries in 1st level table */
#define MM_LVL1_PAGE_SIZE   (MM_LVL2_ENTRIES_NBR * MM_LVL2_PAGE_SIZE) /**< 1 MegaByte */

/** @} */

void os_arch_mmu_table_init(void);

uint32_t os_arch_mmu_get_ctx_table(void);

#ifdef __cplusplus
}
#endif

#endif /* !__MOTH_ARM_MMU_H__ */
