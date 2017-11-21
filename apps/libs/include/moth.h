#ifndef __MOTH_H__
#define __MOTH_H__

#include <os.h>

os_status_t wait(os_mbx_mask_t mask);

os_status_t yield(void);

os_status_t mbx_send(os_task_id_t dest_id, os_mbx_msg_t msg);

os_status_t mbx_recv(os_task_id_t *src_id, os_mbx_msg_t *msg);

#endif
