#include <moth.h>

os_status_t mbx_recv(os_task_id_t *src_id, os_mbx_msg_t *msg) {
  os_status_t status;

  asm volatile("ta 0x03\n"
               "nop\n"
               : "=r"(status)
               :
               : "memory");

  return status;
}
