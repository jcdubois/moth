#include <moth.h>

os_status_t wait(os_mbx_mask_t mask) {
  os_status_t status;

  asm volatile("ta 0x00\n"
               "nop\n"
               : "=r"(status)
               :
               : "memory");

  return status;
}
