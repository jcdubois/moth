#include "tinyprintf.h"
#include "moth.h"

#define UART1 0x100
#define UART_STAT_OFFSET 0x4
#define UART_DATA_OFFSET 0x0

#define UART_STATUS_THE 0x00000004

extern uint8_t __uart_begin;

static void putc (void *opaque, char car)
{
  uint8_t *uart_reg = (uint8_t *)opaque;

  while ((*(uint32_t *)(uart_reg + UART_STAT_OFFSET) & UART_STATUS_THE) == 0) {
    continue;
  }

  *(uart_reg + UART_DATA_OFFSET) = (uint8_t)car;
}

__attribute__((section(".text.entry")))
void entry(uint32_t task_id, uint32_t arg2)
{
  init_printf(&__uart_begin + UART1, putc);

  printf("task %d: init done\n", (int)task_id);

  while(1) {
    printf("task %d: Before yield\n", (int)task_id);
    yield();
    printf("task %d: After yield\n", (int)task_id);
  }
}
