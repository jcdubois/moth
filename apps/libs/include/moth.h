#ifndef __MOTH_H__
#define __MOTH_H__

#include <os.h>

#ifdef __cplusplus
extern "C" {
#endif

os_status_t wait(os_mbx_mask_t mask);

os_status_t yield(void);

os_status_t mbx_send(os_task_id_t dest_id, os_mbx_msg_t msg);

os_status_t mbx_recv(os_task_id_t *src_id, os_mbx_msg_t *msg);

void exit(int reason);

os_task_id_t getpid(void);

int main(int argc, char **argv, char **argp);

#ifdef __cplusplus
}
#endif

#endif // __MOTH_H__
