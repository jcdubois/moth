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

/* prototype function for this file */
#include <os.h>

__attribute__((section(".rodata")))
os_task_ro_t const os_task_ro[CONFIG_MAX_TASK_COUNT] = {
#if 1
    {/* app1 */
     1,
     0,
     {0x40800000, 1 * 0x1000},
     {0x40804000, 1 * 0x1000},
     {0x40806000, 1 * 0x1000}},
    {/* app2 */
     1,
     0,
     {0x40800000, 1 * 0x1000},
     {0x40804000, 1 * 0x1000},
     {0x40806000, 1 * 0x1000}},
    {/* app3 */
     1,
     0,
     {0x40800000, 1 * 0x1000},
     {0x40804000, 1 * 0x1000},
     {0x40806000, 1 * 0x1000}},
    {/* app4 */
     1,
     0,
     {0x40800000, 1 * 0x1000},
     {0x40804000, 1 * 0x1000},
     {0x40806000, 1 * 0x1000}}};
#else
};
#endif
