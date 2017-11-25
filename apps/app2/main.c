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

#define UART1_DEVICE_OFFSET 0x100
#define UART_STAT_REG_OFFSET 0x4
#define UART_DATA_REG_OFFSET 0x0

#define UART_STATUS_THE 0x00000004

extern uint8_t __uart_begin;

__attribute__((section(".text.entry"))) void entry(uint32_t task_id,
                                                   uint32_t arg2);

static void putc(void *opaque, char car) {

  uint8_t *uart_reg = (uint8_t *)opaque;

  while ((*(uint32_t *)(uart_reg + UART_STAT_REG_OFFSET) & UART_STATUS_THE) ==
         0) {
    continue;
  }

  *(uart_reg + UART_DATA_REG_OFFSET) = (uint8_t)car;
}

void entry(uint32_t task_id, uint32_t arg2) {
  init_printf(&__uart_begin + UART1_DEVICE_OFFSET, putc);

  printf("task %d: init done\n", (int)task_id);

  while (1) {
    printf("task %d: Before yield\n", (int)task_id);
    yield();
    printf("task %d: After yield\n", (int)task_id);
  }
}
