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

#ifndef __MOTH_OS_H__
#define __MOTH_OS_H__

#include <types.h>

#ifdef __cplusplus
extern "C"
{
#endif

typedef uint32_t os_mbx_mask_t;

typedef int8_t os_task_id_t;

typedef int32_t os_status_t;

#if defined(CONFIG_MBX_MSG_SIZE_1)
typedef uint8_t os_mbx_msg_t;
#elif defined(CONFIG_MBX_MSG_SIZE_2)
typedef uint16_t os_mbx_msg_t;
#elif defined(CONFIG_MBX_MSG_SIZE_4)
typedef uint32_t os_mbx_msg_t;
#else
typedef uint64_t os_mbx_msg_t;
#endif

typedef uint32_t os_virtual_address_t;

typedef struct {
  os_task_id_t sender_id;
  os_mbx_msg_t msg;
} os_mbx_entry_t;

typedef struct {
  uint8_t head;
  uint8_t count;
  os_mbx_entry_t mbx_array[CONFIG_TASK_MBX_COUNT];
} os_mbx_t;

typedef struct {
  os_virtual_address_t virtual_address;
  uint32_t size;
} os_task_section_t;

typedef struct {
  uint8_t priority;
  os_mbx_mask_t mbx_permission;
  os_task_section_t text;
  os_task_section_t bss;
  os_task_section_t stack;
} os_task_ro_t;

typedef struct {
  os_task_id_t next;
  os_task_id_t prev;
  os_virtual_address_t stack_pointer;
  os_mbx_mask_t mbx_waiting_mask;
  os_mbx_t mbx;
} os_task_rw_t;

#define OS_TASK_ID_NONE -1
#define OS_TASK_ID_ALL -2

#define OS_MBX_MASK_ALL 0xffffffff

#define OS_SUCCESS 0
#define OS_ERROR_FIFO_FULL -1
#define OS_ERROR_FIFO_EMPTY -2
#define OS_ERROR_DENIED -3
#define OS_ERROR_RECEIVE -4
#define OS_ERROR_PARAM -5

os_task_id_t os_sched_get_current_task_id(void);
os_task_id_t os_sched_wait(os_mbx_mask_t waiting_mask);
os_task_id_t os_sched_yield(void);
os_task_id_t os_sched_exit(void);
os_task_id_t os_init(void);
os_status_t os_mbx_receive(os_mbx_entry_t *);
os_status_t os_mbx_send(os_task_id_t dest_id, os_mbx_msg_t mbx_msg);

extern os_task_ro_t const os_task_ro[CONFIG_MAX_TASK_COUNT];
extern os_task_rw_t os_task_rw[CONFIG_MAX_TASK_COUNT];

#ifdef __cplusplus
}
#endif

#endif // __MOTH_OS_H__
