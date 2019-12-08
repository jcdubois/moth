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

/* for syslog() */
#include <syslog.h>

/* for memset() */
#include <string.h>

/* for os_task_rX[] */
#include <os.h>

#include <os_arch.h>

/**
 *
 */
void os_arch_context_create(os_task_id_t task_id) {
  (void)task_id;

  syslog("%s(task_id = %d)\n", __func__, (int)task_id);
}

/**
 *
 */
void os_arch_context_switch(os_task_id_t prev_id, os_task_id_t next_id) {
  (void)prev_id;
  (void)next_id;
  syslog("%s(prev_id = %d, next_id = %d)\n", __func__, (int)prev_id,
         (int)next_id);
}

void os_arch_context_set(os_task_id_t task_id) {
  (void)task_id;
  syslog("%s(task_id = %d)\n", __func__, (int)task_id);
}
