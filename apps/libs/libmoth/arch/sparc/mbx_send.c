#include <moth.h>

os_status_t mbx_send(os_task_id_t dest_id, os_mbx_msg_t msg) {
  os_status_t status;

  asm volatile("ta 0x02\n"
               "nop\n"
               : "=r"(status)
               :
               : "memory");

  return status;
}
