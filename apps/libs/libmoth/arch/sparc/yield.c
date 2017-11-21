#include <moth.h>

os_status_t yield(void) {
  os_status_t status;

  asm volatile("ta 0x01\n"
               "nop\n"
               : "=r"(status)
               :
               : "memory");

  return status;
}
