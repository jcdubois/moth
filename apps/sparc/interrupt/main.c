/**
 * Copyright 2017 Jean-Christophe Dubois
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *  1. Redistributions of source code must retain the above copyright notice,
 *     this list of conditions and the following disclaimer.
 *
 *  2. Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 *  3. Neither the name of the copyright holder nor the names of its
 *     contributors may be used to endorse or promote products derived from
 *     this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *
 * @file
 * @author Jean-Christophe Dubois (jcd@tribudubois.net)
 * @brief
 */

#include <moth.h>

#include <stdio.h>

#include <os_task_id.h>

#include <ioports.h>

#include <os_arch_irq.h>

#define UART1_DEVICE_OFFSET 0x100

#include <os_arch_cons.h>

extern uint8_t __UART_begin[UART1_DEVICE_OFFSET * 2];
extern uint8_t __PIC_begin[UART1_DEVICE_OFFSET * 3];

static void putc(void *opaque, char car) {

  uint32_t uart_addr = (uint32_t)opaque;

  while ((io_read32(uart_addr + UART_STAT_OFFSET) & UART_STATUS_THE) == 0) {
    continue;
  }

  io_write8(uart_addr + UART_DATA_OFFSET, (uint8_t)car);
}

static os_task_id_t interrupt_dest[14] = {
  OS_TASK_ID_NONE, // interrupt 0
  OS_TASK_ID_NONE, // interrupt 1
  OS_TASK_ID_NONE, // interrupt 2
  OS_TASK_ID_NONE, // interrupt 3
  OS_TASK_ID_NONE, // interrupt 4
  OS_TASK_ID_NONE, // interrupt 5
  OS_TIMER_TASK_ID, // interrupt 6
  OS_TASK_ID_NONE, // interrupt 7
  OS_TIMER_TASK_ID, // interrupt 8
  OS_TASK_ID_NONE, // interrupt 9
  OS_TASK_ID_NONE, // interrupt 10
  OS_TASK_ID_NONE, // interrupt 11
  OS_TASK_ID_NONE, // interrupt 12
  OS_TASK_ID_NONE, // interrupt 13
};

static os_task_id_t get_interrupt_dest_id(uint8_t interrupt) { 
  if (interrupt >= 32) {
    return OS_TASK_ID_NONE;
  } else {
    return interrupt_dest[interrupt];
  }
}

int main(int argc, char **argv, char **argp) {
  uint32_t uart_addr = (uint32_t)(&__UART_begin[UART1_DEVICE_OFFSET]);
  uint32_t pic_addr = (uint32_t)(&__PIC_begin[0x200]);
  os_status_t cr;
  os_mbx_msg_t msg = 0;
  int i;

  (void)argc;
  (void)argv;
  (void)argp;

  init_printf((void *)uart_addr, putc);

  io_write32(uart_addr + UART_CTRL_OFFSET, UART_CTRL_TE);

  /*
   * we don't need to enable the interrupts as we don't want to be
   * interrupted
   */

  io_write32(pic_addr + IRQMP_MASK_OFFSET, 0xFFFFFFFF);

  printf("interrupt: init done\n");

  while (1) {
    uint32_t irq_pending = io_read32(pic_addr + IRQMP_PENDING_OFFSET);

    if (irq_pending) {
      printf("interrupt: pending mask = 0x%08x\n", irq_pending);

      for (i = 0; i < 14; i++) {
        if ((1 << i) & irq_pending) {
          os_task_id_t dest_id = get_interrupt_dest_id(i);

          if (dest_id != OS_TASK_ID_NONE) {
            /* send a mailbox to the waiting task */
            cr = mbx_send(dest_id, msg);

            if (cr == OS_SUCCESS) {
              printf("interrupt: mbx %d sent to task %d\n", (int)msg, (int)dest_id);
            } else {
              printf("interrupt: failed (cr = %d) to send mbx to task %d\n",
                     (int)cr, (int)dest_id);
            }

	    msg++;

          } else {
            printf("interrupt: no task to send interrupt %d to\n",
                   i);
          }
        }
      }

      /* clear all interrupts we processed */
      io_write32(pic_addr + IRQMP_CLEAR_OFFSET, irq_pending);

    } else {
      printf("interrupt: no irq pending\n");
    }

    /* wait for next interrupt */
    wait(OS_MBX_MASK_ALL);
  }
}
