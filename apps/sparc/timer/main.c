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

#define TIMER_DEVICE_OFFSET 0x300

/* GPTimer Config register fields */
#define GPTIMER_ENABLE (1 << 0)
#define GPTIMER_RESTART (1 << 1)
#define GPTIMER_LOAD (1 << 2)
#define GPTIMER_INT_ENABLE (1 << 3)
#define GPTIMER_INT_PENDING (1 << 4)
#define GPTIMER_CHAIN (1 << 5)      /* Not supported */
#define GPTIMER_DEBUG_HALT (1 << 6) /* Not supported */

/* Memory mapped register offsets */
#define SCALER_OFFSET 0x00
#define SCALER_RELOAD_OFFSET 0x04
#define CONFIG_OFFSET 0x08
#define COUNTER_OFFSET 0x00
#define COUNTER_RELOAD_OFFSET 0x04
#define TIMER_BASE 0x10

/* Default system clock. 40 MHz */
#define CPU_CLK (40 * 1000 * 1000)
/* scaller is set to 200 so we have a 200 KHz base freqency */
#define CLK_SCALLER 200
/* We set a 2 seconds delay */
#define TIMER_DELAY 2
/* The computed value for the timer */
#define CLK_COUNTER (TIMER_DELAY * (CPU_CLK / CLK_SCALLER))

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
  uint32_t timer_addr = (uint32_t)(&__TIMER_begin[TIMER_DEVICE_OFFSET]);
  os_status_t cr;
  os_mbx_msg_t msg = 0;
  os_task_id_t tmp_id;

  (void)argc;
  (void)argv;
  (void)argp;

  init_printf((void *)uart_addr, putc);

  io_write32(uart_addr + UART_CTRL_OFFSET, UART_CTRL_TE);

  io_write32(timer_addr + SCALER_OFFSET, CLK_SCALLER);
  io_write32(timer_addr + SCALER_RELOAD_OFFSET, CLK_SCALLER);

  io_write32(timer_addr + TIMER_BASE + COUNTER_OFFSET, CLK_COUNTER);
  io_write32(timer_addr + TIMER_BASE + COUNTER_RELOAD_OFFSET, CLK_COUNTER);
  io_write32(timer_addr + TIMER_BASE + CONFIG_OFFSET,
             (uint32_t)(GPTIMER_ENABLE | GPTIMER_INT_ENABLE | GPTIMER_LOAD |
                        GPTIMER_RESTART));

  printf("timer: init done\n");

  while (1) {
    /* wait for a mbx from the interrupt task */
    cr = wait(OS_MBX_MASK_ALL);

    if (cr == OS_SUCCESS) {

      /* receive the mbx */
      cr = mbx_recv(&tmp_id, &msg);

      if (cr == OS_SUCCESS) {
        printf("timer: mbx %d received from task %d\n", (int)msg, (int)tmp_id);

        /* process mbx from the interrupt task */
        if (tmp_id == OS_INTERRUPT_TASK_ID) {
          uint32_t config_reg =
              io_read32(timer_addr + TIMER_BASE + CONFIG_OFFSET);

          /* check the timer interrupt has not been already processed */
          if (config_reg & GPTIMER_INT_PENDING) {
            /* mark the timer as being processed */
            config_reg &= ~GPTIMER_INT_PENDING;

            io_write32(timer_addr + TIMER_BASE + CONFIG_OFFSET, config_reg);

            /* For now send a MBX to all permitted task */
            cr = mbx_send(OS_TASK_ID_ALL, msg);

            if (cr == OS_SUCCESS) {
              printf("timer: mbx %d sent to all tasks\n", (int)msg);
            } else {
              printf("timer: failed (cr = %d) to send mbx\n", (int)cr);
            }
          } else {
            printf("timer: no int pending ???\n");
          }
        } else {
        }
      } else {
        printf("timer: failed (cr = %d) to recv mbx\n", (int)cr);
      }
    } else {
      printf("timer: failed (cr = %d) to wait for mbx\n", (int)cr);
    }
  }
}
