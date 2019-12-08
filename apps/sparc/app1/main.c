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

#define UART1_DEVICE_OFFSET 0x100

#include <os_device_console_grlib.h>

extern uint8_t __UART_begin[UART1_DEVICE_OFFSET * 2];

static void putc(void *opaque, char car) {

  uint32_t uart_addr = (uint32_t)opaque;

  while ((io_read32(uart_addr + UART_STAT_OFFSET) & UART_STATUS_THE) == 0) {
    continue;
  }

  io_write8(uart_addr + UART_DATA_OFFSET, (uint8_t)car);
}

int main(int argc, char **argv, char **argp) {
  uint32_t uart_addr = (uint32_t)(&__UART_begin[UART1_DEVICE_OFFSET]);
  os_status_t cr;
  os_task_id_t tmp_id;
  os_mbx_msg_t msg;
  os_task_id_t task_id = getpid();

  (void)argc;
  (void)argv;
  (void)argp;

  init_printf((void *)uart_addr, putc);

  io_write32(uart_addr + UART_CTRL_OFFSET, UART_CTRL_TE);

  printf("task %d: init done\n", (int)task_id);

  while (1) {
    printf("task %d: waiting for mbx\n", (int)task_id);

    cr = wait(OS_MBX_MASK_ALL);

    if (cr == OS_SUCCESS) {
      cr = mbx_recv(&tmp_id, &msg);

      if (cr == OS_SUCCESS) {
        printf("task %d: mbx %d received from task %d\n", (int)task_id,
               (int)msg, (int)tmp_id);

        if (tmp_id == OS_TIMER_TASK_ID) {
          tmp_id = OS_APP3_TASK_ID;

          cr = mbx_send(tmp_id, msg);

          if (cr == OS_SUCCESS) {
            printf("task %d: mbx %d sent to task %d\n", (int)task_id, (int)msg,
                   (int)tmp_id);
          } else {
            printf("task %d: mbx_send failed, cr = %d\n", (int)task_id,
                   (int)cr);
          }
        }
      } else {
        printf("task %d: mbx_recv failed, cr = %d\n", (int)task_id, (int)cr);
      }
    } else {
      printf("task %d: wait failed, cr = %d\n", (int)task_id, (int)cr);
    }
  }
}
