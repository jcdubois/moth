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

#include <os_arch_cons.h>

#define TIMER1_DEVICE_OFFSET 0x300

/* GPTimer Config register fields */
#define GPTIMER_ENABLE      (1 << 0)
#define GPTIMER_RESTART     (1 << 1)
#define GPTIMER_LOAD        (1 << 2)
#define GPTIMER_INT_ENABLE  (1 << 3)
#define GPTIMER_INT_PENDING (1 << 4)
#define GPTIMER_CHAIN       (1 << 5) /* Not supported */
#define GPTIMER_DEBUG_HALT  (1 << 6) /* Not supported */

/* Memory mapped register offsets */
#define SCALER_OFFSET         0x00
#define SCALER_RELOAD_OFFSET  0x04
#define CONFIG_OFFSET         0x08
#define COUNTER_OFFSET        0x00
#define COUNTER_RELOAD_OFFSET 0x04
#define TIMER_BASE            0x10

extern uint8_t __UART_begin[UART1_DEVICE_OFFSET * 2];
extern uint8_t __TIMER_begin[UART1_DEVICE_OFFSET * 4];

static void putc(void *opaque, char car) {

  uint32_t uart_addr = (uint32_t)opaque;

  while ((io_read32(uart_addr + UART_STAT_OFFSET) & UART_STATUS_THE) == 0) {
    continue;
  }

  io_write8(uart_addr + UART_DATA_OFFSET, (uint8_t)car);
}

int main(int argc, char **argv, char **argp) {
  uint32_t uart_addr = (uint32_t)(&__UART_begin[UART1_DEVICE_OFFSET]);
  uint32_t timer_addr = (uint32_t)(&__TIMER_begin[TIMER1_DEVICE_OFFSET]);
  os_status_t cr;
  os_mbx_msg_t msg = 0;
  os_task_id_t task_id = getpid();
  os_task_id_t tmp_id;

  (void)argc;
  (void)argv;
  (void)argp;

  init_printf((void *)uart_addr, putc);

  io_write32(uart_addr + UART_CTRL_OFFSET, UART_CTRL_TE);

  /* proc frequency is 40 MHz. By default scaller is set to 256 */
  /* We set it to 200 to get a 200 KHz base freqency */
  io_write32(timer_addr + SCALER_OFFSET, 200);

  io_write32(timer_addr + SCALER_RELOAD_OFFSET, 200);

  /* We set the counter to expire every 5 sec. So the value should be 1000000 */
  io_write32(timer_addr + TIMER_BASE + COUNTER_OFFSET, 200000 * 5);

  io_write32(timer_addr + TIMER_BASE + COUNTER_RELOAD_OFFSET, 200000 * 5);

  io_write32(timer_addr + TIMER_BASE + CONFIG_OFFSET, (uint32_t)(GPTIMER_ENABLE | GPTIMER_INT_ENABLE | GPTIMER_LOAD | GPTIMER_RESTART));

  printf("task %d: init done\n", (int)task_id);

  while (1) {
    cr = wait(OS_MBX_MASK_ALL);

    if (cr == OS_SUCCESS) {
      printf("task %d: wait OK\n", (int)task_id);

      cr = mbx_recv(&tmp_id, &msg);

      if (cr == OS_SUCCESS) {
        printf("task %d: mbx received from task %d\n", (int)task_id,
               (int)tmp_id);

        if (tmp_id == OS_INTERRUPT_TASK_ID) {
          tmp_id = OS_APP3_TASK_ID;

          cr = mbx_send(OS_TASK_ID_ALL, msg);
        } else {
        }
      } else {
        printf("task %d: failed (cr = %d) to recv mbx\n", (int)task_id, (int)cr);
      }
    } else {
      printf("task %d: failed (cr = %d) to wait for mbx\n", (int)task_id, (int)cr);
    }
  }
}
