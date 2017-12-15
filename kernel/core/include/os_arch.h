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

#ifndef __OS_ARCH_H_
#define __OS_ARCH_H_

#include <os.h>

#ifdef __cplusplus
extern "C"
{
#endif

uint8_t os_arch_interrupt_is_pending(void);

void os_arch_idle(void);

void os_arch_context_create(os_task_id_t task_id);

void os_arch_context_switch(os_task_id_t prev_id, os_task_id_t next_id);

void os_arch_context_set(os_task_id_t task_id);

void os_arch_space_init(void);

void os_arch_space_switch(os_task_id_t old_context_id,
                          os_task_id_t new_context_id);

void os_arch_cons_init(void);

#ifdef __cplusplus
}
#endif

#endif // __OS_ARCH_H_
