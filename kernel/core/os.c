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

/* for os_arch_idle() and */
#include <os_arch.h>

/* for os_assert() */
#include <os_assert.h>

/* for OS_INTERRUPT_TASK_ID */
#include <os_task_id.h>

extern os_task_ro_t const os_task_ro[CONFIG_MAX_TASK_COUNT];

__attribute__((section(".bss"))) os_task_rw_t os_task_rw[CONFIG_MAX_TASK_COUNT];

static os_task_id_t os_task_current;

/**
 * Get the ID of the running task
 */
os_task_id_t os_sched_get_current_task_id(void) { return os_task_current; }

static inline void os_sched_set_current_task_id(os_task_id_t id) {
  os_task_current = id;
}

static os_task_id_t os_task_ready_list_head;

/**
 *
 */
static inline os_task_id_t os_sched_get_current_list_head(void) {
  return os_task_ready_list_head;
}

/**
 * Set the ID of the next running task
 */
static inline void os_sched_set_current_list_head(os_task_id_t id) {
  os_task_ready_list_head = id;
  if (id != OS_NO_TASK_ID) {
    os_task_rw[id].prev = OS_NO_TASK_ID;
  }
}

/**
 * insert a task in the ready list
 *
 * The ready list is a chained list of ready task ordered by priority.
 *
 */
static inline void os_sched_add_task_to_ready_list(os_task_id_t id) {
  os_task_id_t index_id = os_sched_get_current_list_head();

  os_assert((id >= OS_NO_TASK_ID) && (id < CONFIG_MAX_TASK_COUNT));

  if (index_id == OS_NO_TASK_ID) {
    /*
     * list is empty. Add the task at list head
     */
    os_task_rw[id].next = OS_NO_TASK_ID;
    os_task_rw[id].prev = OS_NO_TASK_ID;
    os_sched_set_current_list_head(id);
    return;
  }

  while (index_id != OS_NO_TASK_ID) {
    if (index_id == id) {

      /*
       * Already in the ready list
       */
      break;
    } else if (os_task_ro[id].priority > os_task_ro[index_id].priority) {

      os_task_id_t prev = os_task_rw[index_id].prev;

      os_task_rw[id].next = index_id;
      os_task_rw[index_id].prev = id;

      if (index_id == os_sched_get_current_list_head()) {
        os_sched_set_current_list_head(id);
        os_task_rw[id].prev = OS_NO_TASK_ID;
      } else {
        os_task_rw[id].prev = prev;
        if (prev != OS_NO_TASK_ID) {
          os_task_rw[prev].next = id;
        }
      }

      break;
    } else if (os_task_rw[index_id].next == OS_NO_TASK_ID) {

      os_task_rw[index_id].next = id;
      os_task_rw[id].prev = index_id;
      os_task_rw[id].next = OS_NO_TASK_ID;

      break;
    } else {
      index_id = os_task_rw[index_id].next;
    }
  }

  return;
}

/**
 * Remove a task from the ready list
 */
static inline void os_sched_remove_task_from_ready_list(os_task_id_t id) {
  os_task_id_t next = os_task_rw[id].next;

  os_assert(os_sched_get_current_list_head() != OS_NO_TASK_ID);

  if (id == os_sched_get_current_list_head()) {
    /*
     * We are removing the current running task.
     * So put the next task at list head.
     * Note: there could be no next task (OS_NO_TASK_ID)
     */
    os_sched_set_current_list_head(next);
  } else {
    os_task_id_t prev = os_task_rw[id].prev;

    /*
     * The task is not at the list head (it has a predecesor).
     * Link previous next to our next
     */
    os_task_rw[prev].next = next;

    if (next != OS_NO_TASK_ID) {
      /*
       * if we have a next, link next previous to our
       * previous.
       */
      os_task_rw[next].prev = prev;
    }
  }

  /*
   * reset our next and previous
   */
  os_task_rw[id].next = OS_NO_TASK_ID;
  os_task_rw[id].prev = OS_NO_TASK_ID;
}

/**
 * Schedule the task at the head ot the ready list.
 * If no task is present then put the processor to sleep while waiting
 * for an interrupt.
 */
static inline os_task_id_t os_sched_schedule(void) {
  os_task_id_t task_id;
  /*
   * Check interrupt status and put the INT task in ready list
   * if int is set.
   */
  if (os_arch_interrupt_is_pending()) {
    os_sched_add_task_to_ready_list(OS_INTERRUPT_TASK_ID);
  }

  while ((task_id = os_sched_get_current_list_head()) == OS_NO_TASK_ID) {
    /*
     * Put processor in idle mode and wait for interrupt.
     */
    os_arch_idle();

    /*
     * Check interrupt status and put int task in ready list
     * if int is set.
     */
    if (os_arch_interrupt_is_pending()) {
      os_sched_add_task_to_ready_list(OS_INTERRUPT_TASK_ID);
    }
  }

  os_sched_set_current_task_id(task_id);

  return os_sched_get_current_task_id();
}

/**
 * Get a mask of all the task that have one MBX pending in the task's FIFO.
 */
static inline os_mbx_mask_t os_mbx_get_posted_mask(os_task_id_t id) {
  uint8_t iterator;
  os_mbx_mask_t mbx_mask = 0;
  uint8_t mbx_entry;

  os_assert((id >= 0) && (id < CONFIG_MAX_TASK_COUNT));

  mbx_entry = os_task_rw[id].mbx.head;

  for (iterator = 0; iterator < os_task_rw[id].mbx.count; iterator++) {
    mbx_mask |= (1 << os_task_rw[id].mbx.entry[mbx_entry].sender_id);
    mbx_entry = (mbx_entry + 1) % CONFIG_TASK_MBX_COUNT;
  }

  return mbx_mask;
}

/**
 * Check if a MBX FIFO is empty.
 */
static inline uint8_t os_mbx_is_empty(os_task_id_t id) {
  os_assert((id >= 0) && (id < CONFIG_MAX_TASK_COUNT));

  if (os_task_rw[id].mbx.count == 0) {
    return 1;
  } else {
    return 0;
  }
}

/**
 * Check if a MBX FIFO is full.
 */
static inline uint8_t os_mbx_is_full(os_task_id_t id) {
  os_assert((id >= 0) && (id < CONFIG_MAX_TASK_COUNT));

  if (os_task_rw[id].mbx.count == CONFIG_TASK_MBX_COUNT) {
    return 1;
  } else {
    return 0;
  }
}

/**
 * Add a MBX message to a task mailbox.
 */
static inline void os_mbx_add_message(os_task_id_t dest_id, os_task_id_t src_id,
                                      os_mbx_msg_t mbx_msg) {
  uint8_t mbx_entry;

  os_assert((src_id >= 0) && (src_id < CONFIG_MAX_TASK_COUNT));
  os_assert((dest_id >= 0) && (dest_id < CONFIG_MAX_TASK_COUNT));

  mbx_entry = (os_task_rw[dest_id].mbx.head + os_task_rw[dest_id].mbx.count) %
              CONFIG_TASK_MBX_COUNT;

  os_task_rw[dest_id].mbx.entry[mbx_entry].sender_id = src_id;
  os_task_rw[dest_id].mbx.entry[mbx_entry].msg = mbx_msg;
  os_task_rw[dest_id].mbx.count++;
}

/**
 * Post a MBX to a target task FIFO
 */
os_status_t os_mbx_send(os_task_id_t dest_id, os_mbx_msg_t mbx_msg) {
  const os_task_id_t current = os_sched_get_current_task_id();

  os_assert((dest_id >= 0) && (dest_id < CONFIG_MAX_TASK_COUNT));

  if (os_task_ro[dest_id].mbx_permission & (1 << current)) {
    if (!os_mbx_is_full(dest_id)) {

      os_mbx_add_message(dest_id, current, mbx_msg);

      if (os_task_rw[dest_id].mbx_waiting_mask & (1 << current)) {

        os_sched_add_task_to_ready_list(dest_id);
      }

      return OS_SUCCESS;
    } else {
      return OS_ERROR_FIFO_FULL;
    }
  } else {
    return OS_ERROR_DENIED;
  }
}

/**
 * Retrieve the first available MBX for the running task.
 */
os_status_t os_mbx_receive(os_mbx_entry_t *entry) {
  const os_task_id_t current = os_sched_get_current_task_id();

  if (!os_mbx_is_empty(current)) {
    uint8_t mbx_entry = os_task_rw[current].mbx.head;
    uint8_t iterator;

    for (iterator = 0; iterator < os_task_rw[current].mbx.count; iterator++) {

      if (os_task_rw[current].mbx_waiting_mask &
          (1 << os_task_rw[current].mbx.entry[mbx_entry].sender_id)) {

        /*
         * This is the first expected MBX.
         * We should remove it from the FIFO and
         * compact the FIFO if required.
         */
        *entry = os_task_rw[current].mbx.entry[mbx_entry];

        os_task_rw[current].mbx.count -= 1;

        if (iterator == 0) {
          os_task_rw[current].mbx.head =
              (mbx_entry + 1) % CONFIG_TASK_MBX_COUNT;
        } else {
          for (; iterator < os_task_rw[current].mbx.count; iterator++) {
            uint8_t next_mbx_entry = (mbx_entry + 1) % CONFIG_TASK_MBX_COUNT;
            os_task_rw[current].mbx.entry[mbx_entry] =
                os_task_rw[current].mbx.entry[next_mbx_entry];
            mbx_entry = next_mbx_entry;
          }
        }

        os_task_rw[current].mbx.entry[mbx_entry].sender_id = OS_NO_TASK_ID;
        os_task_rw[current].mbx.entry[mbx_entry].msg = 0;

        return OS_SUCCESS;
      }

      mbx_entry = (mbx_entry + 1) % CONFIG_TASK_MBX_COUNT;
    }
    return OS_ERROR_RECEIVE;
  } else {
    return OS_ERROR_FIFO_EMPTY;
  }
}

/**
 * Release the processor to give a chance to run to other tasks.
 */
os_task_id_t os_sched_yield(void) {
  const os_task_id_t current = os_sched_get_current_task_id();

  os_assert((current >= 0) && (current < CONFIG_MAX_TASK_COUNT));

  /*
   * We remove the current task from the head of the ready list
   */
  os_sched_remove_task_from_ready_list(current);

  /*
   * We insert the current task in the ready list after the task
   * having the same priority
   */
  os_sched_add_task_to_ready_list(current);

  return os_sched_schedule();
}

/**
 * End a tasks.
 */
os_task_id_t os_sched_exit(void) {
  const os_task_id_t current = os_sched_get_current_task_id();

  os_assert((current >= 0) && (current < CONFIG_MAX_TASK_COUNT));

  /*
   * We remove the current task from the head of the ready list
   */
  os_sched_remove_task_from_ready_list(current);

  return os_sched_schedule();
}

/**
 * Wait for a MBX from a selected set of tasks.
 */
os_task_id_t os_sched_wait(os_mbx_mask_t waiting_mask) {
  const os_task_id_t current = os_sched_get_current_task_id();

  os_assert((current >= 0) && (current < CONFIG_MAX_TASK_COUNT));
  os_assert(waiting_mask > 0);

  /*
   * We check that the expected mbx source are allowed
   * TODO: Is it expected that the calling task asked for
   * forbiden sources.
   */
  waiting_mask &= os_task_ro[current].mbx_permission;

  os_sched_remove_task_from_ready_list(current);

  if (waiting_mask) {
    os_task_rw[current].mbx_waiting_mask = waiting_mask;

    waiting_mask &= os_mbx_get_posted_mask(current);

    if (waiting_mask) {
      /*
       * We received mbx from at least one of the
       * expected source. So put back the task in the
       * ready list.
       */
      os_sched_add_task_to_ready_list(current);
    } else {
      /*
       * The task is waiting for a MBX. It should stay
       * out of the ready list for now.
       */
    }
  } else {
    /*
     * Put back the task in the ready list as there is nothing
     * to wait for.
     */
    os_sched_add_task_to_ready_list(current);
  }

  return os_sched_schedule();
}

/**
 * Initialize the MOTH structures.
 */
os_task_id_t os_init(void) {
  os_task_id_t task_id, prev_id;

  /*
   * Initialize the debug port if any
   */
  os_arch_cons_init();

  /*
   * Initialize the virtal address space
   */
  os_arch_space_init();

  /*
   * Reset the current task to no task
   */
  os_sched_set_current_list_head(OS_NO_TASK_ID);

  /* Add all existing tasks to the ready list */
  for (task_id = 0, prev_id = 0; task_id < CONFIG_MAX_TASK_COUNT;
       prev_id = task_id, task_id++) {
    uint8_t iterator;

    os_arch_space_switch(prev_id, task_id);

    /*
     * Create the task context
     */
    os_arch_context_create(task_id);

    /*
     * Reset all MBX entries
     */
    for (iterator = 0; iterator < CONFIG_TASK_MBX_COUNT; iterator++) {
      os_task_rw[task_id].mbx.entry[iterator].sender_id = OS_NO_TASK_ID;
    }

    /*
     * Reset task chaining
     */
    os_task_rw[task_id].next = OS_NO_TASK_ID;
    os_task_rw[task_id].prev = OS_NO_TASK_ID;

    /*
     * Add task to ready list
     * Note: All tasks run once at init time to initiaize and
     * decide what to do.
     */
    os_sched_add_task_to_ready_list(task_id);
  }

  /* schedule the task with the highest prioriy */
  task_id = os_sched_schedule();

  /*
   * Select the task that should run
   */
  os_arch_context_set(task_id);

  /*
   * Switch the MMU to the selected task
   */
  os_arch_space_switch(0, task_id);

  return task_id;
}
